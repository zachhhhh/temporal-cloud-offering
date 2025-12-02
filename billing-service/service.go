package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/shopspring/decimal"
	"github.com/stripe/stripe-go/v76"
	"github.com/stripe/stripe-go/v76/customer"
	"github.com/stripe/stripe-go/v76/subscription"
	"github.com/stripe/stripe-go/v76/webhook"
)

type BillingService struct {
	db *pgxpool.Pool
}

func NewBillingService(db *pgxpool.Pool) *BillingService {
	return &BillingService{db: db}
}

// Organization represents a customer organization
type Organization struct {
	ID               uuid.UUID `json:"id"`
	Name             string    `json:"name"`
	Slug             string    `json:"slug"`
	StripeCustomerID string    `json:"stripe_customer_id,omitempty"`
	CreatedAt        time.Time `json:"created_at"`
}

// Subscription represents a billing subscription
type Subscription struct {
	ID                   uuid.UUID       `json:"id"`
	OrganizationID       uuid.UUID       `json:"organization_id"`
	StripeSubscriptionID string          `json:"stripe_subscription_id,omitempty"`
	Plan                 string          `json:"plan"`
	Status               string          `json:"status"`
	ActionsIncluded      int64           `json:"actions_included"`
	ActiveStorageGB      decimal.Decimal `json:"active_storage_gb"`
	RetainedStorageGB    decimal.Decimal `json:"retained_storage_gb"`
	CurrentPeriodStart   time.Time       `json:"current_period_start"`
	CurrentPeriodEnd     time.Time       `json:"current_period_end"`
}

// UsageSummary represents usage for a period
type UsageSummary struct {
	OrganizationID     uuid.UUID       `json:"organization_id"`
	PeriodStart        time.Time       `json:"period_start"`
	PeriodEnd          time.Time       `json:"period_end"`
	TotalActions       int64           `json:"total_actions"`
	ActiveStorageGBH   decimal.Decimal `json:"active_storage_gbh"`
	RetainedStorageGBH decimal.Decimal `json:"retained_storage_gbh"`
	EstimatedCostCents int64           `json:"estimated_cost_cents"`
}

// Invoice represents a billing invoice
type Invoice struct {
	ID             uuid.UUID `json:"id"`
	OrganizationID uuid.UUID `json:"organization_id"`
	InvoiceNumber  string    `json:"invoice_number"`
	PeriodStart    time.Time `json:"period_start"`
	PeriodEnd      time.Time `json:"period_end"`
	SubtotalCents  int64     `json:"subtotal_cents"`
	TotalCents     int64     `json:"total_cents"`
	Status         string    `json:"status"`
}

// Namespace represents a Temporal namespace
type Namespace struct {
	ID                uuid.UUID `json:"id"`
	OrganizationID    uuid.UUID `json:"organization_id"`
	Name              string    `json:"name"`
	TemporalNamespace string    `json:"temporal_namespace"`
	Region            string    `json:"region"`
	Status            string    `json:"status"`
	RetentionDays     int       `json:"retention_days"`
	CreatedAt         time.Time `json:"created_at"`
}

// CreateOrganization creates a new organization with Stripe customer
func (s *BillingService) CreateOrganization(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name  string `json:"name"`
		Email string `json:"email"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Create Stripe customer
	params := &stripe.CustomerParams{
		Name:  stripe.String(req.Name),
		Email: stripe.String(req.Email),
	}
	cust, err := customer.New(params)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to create Stripe customer: %v", err), http.StatusInternalServerError)
		return
	}

	// Create organization in DB
	org := Organization{
		ID:               uuid.New(),
		Name:             req.Name,
		Slug:             generateSlug(req.Name),
		StripeCustomerID: cust.ID,
		CreatedAt:        time.Now(),
	}

	_, err = s.db.Exec(r.Context(),
		`INSERT INTO organizations (id, name, slug, stripe_customer_id, created_at) VALUES ($1, $2, $3, $4, $5)`,
		org.ID, org.Name, org.Slug, org.StripeCustomerID, org.CreatedAt)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Create default subscription (free tier)
	now := time.Now()
	periodEnd := now.AddDate(0, 1, 0) // 1 month from now
	_, err = s.db.Exec(r.Context(),
		`INSERT INTO subscriptions (organization_id, plan, status, actions_included, active_storage_gb, retained_storage_gb, current_period_start, current_period_end)
		 VALUES ($1, 'free', 'active', 100000, 0.1, 4, $2, $3)`,
		org.ID, now, periodEnd)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(org)
}

// GetOrganization retrieves an organization
func (s *BillingService) GetOrganization(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, err := uuid.Parse(vars["id"])
	if err != nil {
		http.Error(w, "Invalid organization ID", http.StatusBadRequest)
		return
	}

	var org Organization
	err = s.db.QueryRow(r.Context(),
		`SELECT id, name, slug, stripe_customer_id, created_at FROM organizations WHERE id = $1`, id).
		Scan(&org.ID, &org.Name, &org.Slug, &org.StripeCustomerID, &org.CreatedAt)
	if err != nil {
		http.Error(w, "Organization not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(org)
}

// GetSubscription retrieves the subscription for an organization
func (s *BillingService) GetSubscription(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	orgID, err := uuid.Parse(vars["org_id"])
	if err != nil {
		http.Error(w, `{"error": "Invalid organization ID"}`, http.StatusBadRequest)
		return
	}

	var sub Subscription
	var stripeSubID *string
	var periodStart, periodEnd *time.Time
	err = s.db.QueryRow(r.Context(),
		`SELECT id, organization_id, stripe_subscription_id, plan, status, actions_included, 
		        active_storage_gb, retained_storage_gb, current_period_start, current_period_end
		 FROM subscriptions WHERE organization_id = $1`, orgID).
		Scan(&sub.ID, &sub.OrganizationID, &stripeSubID, &sub.Plan, &sub.Status,
			&sub.ActionsIncluded, &sub.ActiveStorageGB, &sub.RetainedStorageGB,
			&periodStart, &periodEnd)
	if err != nil {
		http.Error(w, `{"error": "Subscription not found"}`, http.StatusNotFound)
		return
	}

	// Handle nullable fields
	if stripeSubID != nil {
		sub.StripeSubscriptionID = *stripeSubID
	}
	if periodStart != nil {
		sub.CurrentPeriodStart = *periodStart
	} else {
		// Default to current month
		now := time.Now()
		sub.CurrentPeriodStart = time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
	}
	if periodEnd != nil {
		sub.CurrentPeriodEnd = *periodEnd
	} else {
		sub.CurrentPeriodEnd = sub.CurrentPeriodStart.AddDate(0, 1, 0)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(sub)
}

// UpdateSubscription upgrades/downgrades a subscription
func (s *BillingService) UpdateSubscription(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	orgID, err := uuid.Parse(vars["org_id"])
	if err != nil {
		http.Error(w, "Invalid organization ID", http.StatusBadRequest)
		return
	}

	var req struct {
		Plan string `json:"plan"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Get plan limits
	limits := getPlanLimits(req.Plan)

	// Get organization's Stripe customer ID
	var stripeCustomerID string
	err = s.db.QueryRow(r.Context(),
		`SELECT stripe_customer_id FROM organizations WHERE id = $1`, orgID).
		Scan(&stripeCustomerID)
	if err != nil {
		http.Error(w, "Organization not found", http.StatusNotFound)
		return
	}

	// Create/update Stripe subscription if not free
	var stripeSubID string
	if req.Plan != "free" {
		priceID := getPlanPriceID(req.Plan)
		params := &stripe.SubscriptionParams{
			Customer: stripe.String(stripeCustomerID),
			Items: []*stripe.SubscriptionItemsParams{
				{Price: stripe.String(priceID)},
			},
		}
		sub, err := subscription.New(params)
		if err != nil {
			http.Error(w, fmt.Sprintf("Failed to create Stripe subscription: %v", err), http.StatusInternalServerError)
			return
		}
		stripeSubID = sub.ID
	}

	// Update subscription in DB
	_, err = s.db.Exec(r.Context(),
		`UPDATE subscriptions SET plan = $1, stripe_subscription_id = $2, 
		 actions_included = $3, active_storage_gb = $4, retained_storage_gb = $5,
		 updated_at = NOW()
		 WHERE organization_id = $6`,
		req.Plan, stripeSubID, limits.ActionsIncluded, limits.ActiveStorageGB, limits.RetainedStorageGB, orgID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "updated"})
}

// GetUsage retrieves usage for a period
func (s *BillingService) GetUsage(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	orgID, err := uuid.Parse(vars["org_id"])
	if err != nil {
		http.Error(w, "Invalid organization ID", http.StatusBadRequest)
		return
	}

	// Parse date range
	startStr := r.URL.Query().Get("start")
	endStr := r.URL.Query().Get("end")

	var start, end time.Time
	if startStr != "" {
		start, _ = time.Parse(time.RFC3339, startStr)
	} else {
		start = time.Now().AddDate(0, -1, 0)
	}
	if endStr != "" {
		end, _ = time.Parse(time.RFC3339, endStr)
	} else {
		end = time.Now()
	}

	var summary UsageSummary
	err = s.db.QueryRow(r.Context(),
		`SELECT COALESCE(SUM(total_actions), 0), COALESCE(SUM(active_storage_gbh), 0), COALESCE(SUM(retained_storage_gbh), 0)
		 FROM usage_aggregates WHERE organization_id = $1 AND period_start >= $2 AND period_end <= $3`,
		orgID, start, end).
		Scan(&summary.TotalActions, &summary.ActiveStorageGBH, &summary.RetainedStorageGBH)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	summary.OrganizationID = orgID
	summary.PeriodStart = start
	summary.PeriodEnd = end
	summary.EstimatedCostCents = calculateCost(summary)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(summary)
}

// GetCurrentUsage retrieves current billing period usage
func (s *BillingService) GetCurrentUsage(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	orgID, err := uuid.Parse(vars["org_id"])
	if err != nil {
		http.Error(w, "Invalid organization ID", http.StatusBadRequest)
		return
	}

	// Get current period from subscription
	var periodStart, periodEnd time.Time
	err = s.db.QueryRow(r.Context(),
		`SELECT current_period_start, current_period_end FROM subscriptions WHERE organization_id = $1`, orgID).
		Scan(&periodStart, &periodEnd)
	if err != nil {
		// Default to current month
		now := time.Now()
		periodStart = time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
		periodEnd = periodStart.AddDate(0, 1, 0)
	}

	var summary UsageSummary
	err = s.db.QueryRow(r.Context(),
		`SELECT COALESCE(SUM(total_actions), 0), COALESCE(SUM(active_storage_gbh), 0), COALESCE(SUM(retained_storage_gbh), 0)
		 FROM usage_aggregates WHERE organization_id = $1 AND period_start >= $2 AND period_end <= $3`,
		orgID, periodStart, periodEnd).
		Scan(&summary.TotalActions, &summary.ActiveStorageGBH, &summary.RetainedStorageGBH)
	if err != nil {
		summary = UsageSummary{}
	}

	summary.OrganizationID = orgID
	summary.PeriodStart = periodStart
	summary.PeriodEnd = periodEnd
	summary.EstimatedCostCents = calculateCost(summary)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(summary)
}

// ListInvoices lists invoices for an organization
func (s *BillingService) ListInvoices(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	orgID, err := uuid.Parse(vars["org_id"])
	if err != nil {
		http.Error(w, "Invalid organization ID", http.StatusBadRequest)
		return
	}

	rows, err := s.db.Query(r.Context(),
		`SELECT id, organization_id, invoice_number, period_start, period_end, subtotal_cents, total_cents, status
		 FROM invoices WHERE organization_id = $1 ORDER BY created_at DESC LIMIT 50`, orgID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	invoices := make([]Invoice, 0) // Initialize as empty slice, not nil
	for rows.Next() {
		var inv Invoice
		rows.Scan(&inv.ID, &inv.OrganizationID, &inv.InvoiceNumber, &inv.PeriodStart, &inv.PeriodEnd,
			&inv.SubtotalCents, &inv.TotalCents, &inv.Status)
		invoices = append(invoices, inv)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(invoices)
}

// GetInvoice retrieves a specific invoice
func (s *BillingService) GetInvoice(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, err := uuid.Parse(vars["id"])
	if err != nil {
		http.Error(w, "Invalid invoice ID", http.StatusBadRequest)
		return
	}

	var inv Invoice
	err = s.db.QueryRow(r.Context(),
		`SELECT id, organization_id, invoice_number, period_start, period_end, subtotal_cents, total_cents, status
		 FROM invoices WHERE id = $1`, id).
		Scan(&inv.ID, &inv.OrganizationID, &inv.InvoiceNumber, &inv.PeriodStart, &inv.PeriodEnd,
			&inv.SubtotalCents, &inv.TotalCents, &inv.Status)
	if err != nil {
		http.Error(w, "Invoice not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(inv)
}

// ListNamespaces lists namespaces for an organization
func (s *BillingService) ListNamespaces(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	orgID, err := uuid.Parse(vars["org_id"])
	if err != nil {
		http.Error(w, "Invalid organization ID", http.StatusBadRequest)
		return
	}

	rows, err := s.db.Query(r.Context(),
		`SELECT id, organization_id, name, temporal_namespace, region, status, retention_days, created_at
		 FROM namespaces WHERE organization_id = $1`, orgID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var namespaces []Namespace
	for rows.Next() {
		var ns Namespace
		rows.Scan(&ns.ID, &ns.OrganizationID, &ns.Name, &ns.TemporalNamespace, &ns.Region, &ns.Status, &ns.RetentionDays, &ns.CreatedAt)
		namespaces = append(namespaces, ns)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(namespaces)
}

// CreateNamespace creates a new namespace
func (s *BillingService) CreateNamespace(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	orgID, err := uuid.Parse(vars["org_id"])
	if err != nil {
		http.Error(w, "Invalid organization ID", http.StatusBadRequest)
		return
	}

	var req struct {
		Name          string `json:"name"`
		Region        string `json:"region"`
		RetentionDays int    `json:"retention_days"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if req.RetentionDays == 0 {
		req.RetentionDays = 7
	}
	if req.Region == "" {
		req.Region = "us-east-1"
	}

	ns := Namespace{
		ID:                uuid.New(),
		OrganizationID:    orgID,
		Name:              req.Name,
		TemporalNamespace: fmt.Sprintf("%s.%s", orgID.String()[:8], req.Name),
		Region:            req.Region,
		Status:            "provisioning",
		RetentionDays:     req.RetentionDays,
		CreatedAt:         time.Now(),
	}

	_, err = s.db.Exec(r.Context(),
		`INSERT INTO namespaces (id, organization_id, name, temporal_namespace, region, status, retention_days, created_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		ns.ID, ns.OrganizationID, ns.Name, ns.TemporalNamespace, ns.Region, ns.Status, ns.RetentionDays, ns.CreatedAt)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// TODO: Actually provision namespace on Temporal cluster via cloud-sdk-go

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(ns)
}

// HandleStripeWebhook handles Stripe webhook events
func (s *BillingService) HandleStripeWebhook(w http.ResponseWriter, r *http.Request) {
	payload, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	webhookSecret := os.Getenv("STRIPE_WEBHOOK_SECRET")
	event, err := webhook.ConstructEvent(payload, r.Header.Get("Stripe-Signature"), webhookSecret)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	switch event.Type {
	case "invoice.paid":
		var inv stripe.Invoice
		json.Unmarshal(event.Data.Raw, &inv)
		s.handleInvoicePaid(r.Context(), &inv)

	case "invoice.payment_failed":
		var inv stripe.Invoice
		json.Unmarshal(event.Data.Raw, &inv)
		s.handlePaymentFailed(r.Context(), &inv)

	case "customer.subscription.updated":
		var sub stripe.Subscription
		json.Unmarshal(event.Data.Raw, &sub)
		s.handleSubscriptionUpdated(r.Context(), &sub)
	}

	w.WriteHeader(http.StatusOK)
}

func (s *BillingService) handleInvoicePaid(ctx context.Context, inv *stripe.Invoice) {
	// Update invoice status in DB
	s.db.Exec(ctx,
		`UPDATE invoices SET status = 'paid', paid_at = NOW() WHERE stripe_invoice_id = $1`,
		inv.ID)
}

func (s *BillingService) handlePaymentFailed(ctx context.Context, inv *stripe.Invoice) {
	// Update invoice status
	s.db.Exec(ctx,
		`UPDATE invoices SET status = 'payment_failed' WHERE stripe_invoice_id = $1`,
		inv.ID)
	// TODO: Send notification, potentially suspend service
}

func (s *BillingService) handleSubscriptionUpdated(ctx context.Context, sub *stripe.Subscription) {
	// Update subscription status
	s.db.Exec(ctx,
		`UPDATE subscriptions SET status = $1, current_period_start = $2, current_period_end = $3
		 WHERE stripe_subscription_id = $4`,
		sub.Status, time.Unix(sub.CurrentPeriodStart, 0), time.Unix(sub.CurrentPeriodEnd, 0), sub.ID)
}

// Helper functions

type PlanLimits struct {
	ActionsIncluded   int64
	ActiveStorageGB   decimal.Decimal
	RetainedStorageGB decimal.Decimal
	BasePriceCents    int64
}

func getPlanLimits(plan string) PlanLimits {
	limits := map[string]PlanLimits{
		"free":       {100000, decimal.NewFromFloat(0.1), decimal.NewFromInt(4), 0},
		"essential":  {1000000, decimal.NewFromInt(1), decimal.NewFromInt(40), 10000},
		"business":   {2500000, decimal.NewFromFloat(2.5), decimal.NewFromInt(100), 50000},
		"enterprise": {10000000, decimal.NewFromInt(10), decimal.NewFromInt(400), 0}, // Custom pricing
	}
	if l, ok := limits[plan]; ok {
		return l
	}
	return limits["free"]
}

func getPlanPriceID(plan string) string {
	// These would be actual Stripe price IDs
	prices := map[string]string{
		"essential":  "price_essential_monthly",
		"business":   "price_business_monthly",
		"enterprise": "price_enterprise_monthly",
	}
	return prices[plan]
}

func calculateCost(usage UsageSummary) int64 {
	var cost int64

	// Actions: $25-50 per million (using $25 for simplicity)
	actionMillions := usage.TotalActions / 1000000
	cost += actionMillions * 2500 // $25 in cents

	// Active storage: $0.042/GBh
	activeStorageCost := usage.ActiveStorageGBH.Mul(decimal.NewFromFloat(4.2)).IntPart()
	cost += activeStorageCost

	// Retained storage: $0.00105/GBh
	retainedStorageCost := usage.RetainedStorageGBH.Mul(decimal.NewFromFloat(0.105)).IntPart()
	cost += retainedStorageCost

	return cost
}

func generateSlug(name string) string {
	// Simple slug generation
	slug := ""
	for _, c := range name {
		if (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') {
			slug += string(c)
		} else if c >= 'A' && c <= 'Z' {
			slug += string(c + 32)
		} else if c == ' ' || c == '-' {
			slug += "-"
		}
	}
	return slug
}
