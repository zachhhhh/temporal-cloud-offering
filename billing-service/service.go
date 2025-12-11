package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/shopspring/decimal"
	"github.com/stripe/stripe-go/v76"
	checkoutsession "github.com/stripe/stripe-go/v76/checkout/session"
	"github.com/stripe/stripe-go/v76/customer"
	"github.com/stripe/stripe-go/v76/subscription"
	"github.com/stripe/stripe-go/v76/webhook"
	"go.temporal.io/api/workflowservice/v1"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/protobuf/types/known/durationpb"
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
	var stripeCustomerID *string
	err = s.db.QueryRow(r.Context(),
		`SELECT id, name, slug, stripe_customer_id, created_at FROM organizations WHERE id = $1`, id).
		Scan(&org.ID, &org.Name, &org.Slug, &stripeCustomerID, &org.CreatedAt)
	if err != nil {
		http.Error(w, "Organization not found", http.StatusNotFound)
		return
	}
	if stripeCustomerID != nil {
		org.StripeCustomerID = *stripeCustomerID
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
		if priceID == "" {
			http.Error(w, "Stripe price not configured for plan", http.StatusBadRequest)
			return
		}
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

	go s.provisionNamespace(r.Context(), ns)

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
	if webhookSecret == "" {
		http.Error(w, "Stripe webhook secret not configured", http.StatusInternalServerError)
		return
	}

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
	default:
		log.Printf("Unhandled Stripe webhook type: %s", event.Type)
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

// provisionNamespace calls the Temporal cluster to register a namespace and updates status in DB.
func (s *BillingService) provisionNamespace(ctx context.Context, ns Namespace) {
	endpoint := os.Getenv("TEMPORAL_GRPC_ENDPOINT")
	if endpoint == "" {
		endpoint = "localhost:7233"
	}

	dialCtx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()

	conn, err := grpc.DialContext(dialCtx, endpoint, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Printf("Namespace provision dial failed for %s: %v", ns.TemporalNamespace, err)
		s.db.Exec(context.Background(), `UPDATE namespaces SET status = 'failed' WHERE id = $1`, ns.ID)
		return
	}
	defer conn.Close()

	client := workflowservice.NewWorkflowServiceClient(conn)
	retention := durationpb.New(time.Duration(ns.RetentionDays) * 24 * time.Hour)

	_, err = client.RegisterNamespace(ctx, &workflowservice.RegisterNamespaceRequest{
		Namespace:                        ns.TemporalNamespace,
		WorkflowExecutionRetentionPeriod: retention,
	})
	if err != nil {
		log.Printf("Namespace provision failed for %s: %v", ns.TemporalNamespace, err)
		s.db.Exec(context.Background(), `UPDATE namespaces SET status = 'failed', updated_at = NOW() WHERE id = $1`, ns.ID)
		return
	}

	_, _ = s.db.Exec(context.Background(),
		`UPDATE namespaces SET status = 'active', updated_at = NOW() WHERE id = $1`, ns.ID)
	log.Printf("Provisioned namespace %s for org %s", ns.TemporalNamespace, ns.OrganizationID.String())
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
	// Prefer environment overrides (e.g., STRIPE_PRICE_ESSENTIAL)
	envKey := fmt.Sprintf("STRIPE_PRICE_%s", strings.ToUpper(plan))
	if price := os.Getenv(envKey); price != "" {
		return price
	}

	// Fallback to static placeholders for dev
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

// CheckoutRequest represents a Stripe checkout request
type CheckoutRequest struct {
	OrganizationID string `json:"organization_id"`
	PlanID         string `json:"plan_id"`
	SuccessURL     string `json:"success_url"`
	CancelURL      string `json:"cancel_url"`
}

// CreateCheckoutSession creates a Stripe checkout session for subscription
func (s *BillingService) CreateCheckoutSession(w http.ResponseWriter, r *http.Request) {
	var req CheckoutRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Map plan ID to Stripe price ID
	priceID := os.Getenv("STRIPE_PRICE_" + req.PlanID)
	if priceID == "" {
		// Use default price IDs based on plan
		switch req.PlanID {
		case "essential":
			priceID = os.Getenv("STRIPE_PRICE_ESSENTIAL")
		case "business":
			priceID = os.Getenv("STRIPE_PRICE_BUSINESS")
		default:
			http.Error(w, "Invalid plan ID", http.StatusBadRequest)
			return
		}
	}

	if priceID == "" {
		http.Error(w, "Stripe price not configured for this plan", http.StatusInternalServerError)
		return
	}

	// Get or create Stripe customer
	var stripeCustomerID string
	orgID, err := uuid.Parse(req.OrganizationID)
	if err == nil {
		var org Organization
		err = s.db.QueryRow(r.Context(),
			"SELECT stripe_customer_id FROM organizations WHERE id = $1",
			orgID,
		).Scan(&org.StripeCustomerID)
		if err == nil && org.StripeCustomerID != "" {
			stripeCustomerID = org.StripeCustomerID
		}
	}

	// Create Stripe checkout session
	params := &stripe.CheckoutSessionParams{
		Mode: stripe.String(string(stripe.CheckoutSessionModeSubscription)),
		LineItems: []*stripe.CheckoutSessionLineItemParams{
			{
				Price:    stripe.String(priceID),
				Quantity: stripe.Int64(1),
			},
		},
		SuccessURL: stripe.String(req.SuccessURL),
		CancelURL:  stripe.String(req.CancelURL),
	}

	if stripeCustomerID != "" {
		params.Customer = stripe.String(stripeCustomerID)
	}

	// Add metadata
	params.Metadata = map[string]string{
		"organization_id": req.OrganizationID,
		"plan_id":         req.PlanID,
	}

	checkoutSession, err := checkoutsession.New(params)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to create checkout session: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"url":        checkoutSession.URL,
		"session_id": checkoutSession.ID,
	})
}

// PlanResponse represents a pricing plan for API response
type PlanResponse struct {
	ID                string   `json:"id"`
	Name              string   `json:"name"`
	Description       string   `json:"description"`
	BasePriceCents    int64    `json:"base_price_cents"`
	BasePriceDisplay  string   `json:"base_price_display"`
	ActionsIncluded   int64    `json:"actions_included"`
	ActiveStorageGB   float64  `json:"active_storage_gb"`
	RetainedStorageGB float64  `json:"retained_storage_gb"`
	Features          []string `json:"features"`
}

// GetPlans returns all available pricing plans - matching temporal.io/pricing
func (s *BillingService) GetPlans(w http.ResponseWriter, r *http.Request) {
	plans := []PlanResponse{
		{
			ID:                "essential",
			Name:              "Essential",
			Description:       "For basic workflows",
			BasePriceCents:    10000,
			BasePriceDisplay:  "Starting at $100/mo",
			ActionsIncluded:   1000000,
			ActiveStorageGB:   1,
			RetainedStorageGB: 40,
			Features: []string{
				"1M Actions included",
				"1 GB Active Storage",
				"40 GB Retained Storage",
				"99.9% SLA, 99.99% HA Options",
				"Multi-Cloud & Multi-Region",
				"User Roles & API Keys",
				"Audit Logging",
				"1 Business Day P0 Response",
			},
		},
		{
			ID:                "business",
			Name:              "Business",
			Description:       "For teams scaling Temporal",
			BasePriceCents:    50000,
			BasePriceDisplay:  "Starting at $500/mo",
			ActionsIncluded:   2500000,
			ActiveStorageGB:   2.5,
			RetainedStorageGB: 100,
			Features: []string{
				"2.5M Actions included",
				"2.5 GB Active Storage",
				"100 GB Retained Storage",
				"Everything in Essentials",
				"SAML SSO Included",
				"SCIM Add-on",
				"2 Business Hours P0 Response",
				"Workflow Troubleshooting",
			},
		},
		{
			ID:                "enterprise",
			Name:              "Enterprise",
			Description:       "For enterprise and mission critical",
			BasePriceCents:    0,
			BasePriceDisplay:  "Contact Sales",
			ActionsIncluded:   10000000,
			ActiveStorageGB:   10,
			RetainedStorageGB: 400,
			Features: []string{
				"10M Actions included",
				"10 GB Active Storage",
				"400 GB Retained Storage",
				"Everything in Business",
				"SCIM Included",
				"24/7, 30 Minute P0 Response",
				"Technical Onboarding",
				"Design Review",
			},
		},
		{
			ID:                "mission_critical",
			Name:              "Mission Critical",
			Description:       "For mission critical workloads",
			BasePriceCents:    0,
			BasePriceDisplay:  "Contact Sales",
			ActionsIncluded:   10000000,
			ActiveStorageGB:   10,
			RetainedStorageGB: 400,
			Features: []string{
				"10M+ Actions",
				"10+ GB Active Storage",
				"400+ GB Retained Storage",
				"Everything in Enterprise",
				"Designated Support Engineer",
				"Worker Tuning",
				"Cost Reviews",
				"Security Reviews",
			},
		},
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(plans)
}

// MagicLinkRequest represents a magic link request
type MagicLinkRequest struct {
	Email string `json:"email"`
}

// SendMagicLink sends a magic link email for passwordless authentication
func (s *BillingService) SendMagicLink(w http.ResponseWriter, r *http.Request) {
	var req MagicLinkRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error": "invalid request"}`, http.StatusBadRequest)
		return
	}

	if req.Email == "" || !strings.Contains(req.Email, "@") {
		http.Error(w, `{"error": "invalid email"}`, http.StatusBadRequest)
		return
	}

	// Generate a secure token
	tokenBytes := make([]byte, 32)
	if _, err := rand.Read(tokenBytes); err != nil {
		http.Error(w, `{"error": "internal error"}`, http.StatusInternalServerError)
		return
	}
	token := hex.EncodeToString(tokenBytes)

	// Store token in database with expiration (15 minutes)
	expiresAt := time.Now().Add(15 * time.Minute)
	_, err := s.db.Exec(r.Context(),
		`INSERT INTO magic_links (email, token, expires_at, created_at) 
		 VALUES ($1, $2, $3, NOW())
		 ON CONFLICT (email) DO UPDATE SET token = $2, expires_at = $3, created_at = NOW()`,
		req.Email, token, expiresAt)
	if err != nil {
		// Table might not exist, create it
		s.db.Exec(r.Context(),
			`CREATE TABLE IF NOT EXISTS magic_links (
				email VARCHAR(255) PRIMARY KEY,
				token VARCHAR(255) NOT NULL,
				expires_at TIMESTAMPTZ NOT NULL,
				created_at TIMESTAMPTZ DEFAULT NOW()
			)`)
		// Retry insert
		_, err = s.db.Exec(r.Context(),
			`INSERT INTO magic_links (email, token, expires_at, created_at) 
			 VALUES ($1, $2, $3, NOW())
			 ON CONFLICT (email) DO UPDATE SET token = $2, expires_at = $3, created_at = NOW()`,
			req.Email, token, expiresAt)
		if err != nil {
			http.Error(w, `{"error": "failed to create magic link"}`, http.StatusInternalServerError)
			return
		}
	}

	// Build magic link URL
	baseURL := os.Getenv("APP_URL")
	if baseURL == "" {
		baseURL = "https://temporal-cloud-marketing.pages.dev"
	}
	magicLink := fmt.Sprintf("%s/api/auth/verify?token=%s&email=%s", baseURL, token, req.Email)

	// Send email using Resend API
	resendKey := os.Getenv("RESEND_API_KEY")
	if resendKey != "" {
		emailBody := fmt.Sprintf(`{
			"from": "Temporal Cloud <noreply@temporal.io>",
			"to": ["%s"],
			"subject": "Sign in to Temporal Cloud",
			"html": "<h2>Sign in to Temporal Cloud</h2><p>Click the link below to sign in:</p><p><a href='%s'>Sign in to Temporal Cloud</a></p><p>This link expires in 15 minutes.</p><p>If you didn't request this, you can safely ignore this email.</p>"
		}`, req.Email, magicLink)

		emailReq, _ := http.NewRequest("POST", "https://api.resend.com/emails", strings.NewReader(emailBody))
		emailReq.Header.Set("Authorization", "Bearer "+resendKey)
		emailReq.Header.Set("Content-Type", "application/json")

		client := &http.Client{Timeout: 10 * time.Second}
		resp, err := client.Do(emailReq)
		if err != nil || resp.StatusCode >= 400 {
			// Log error but don't expose to user
			fmt.Printf("Failed to send email: %v\n", err)
		}
	} else {
		// No email service configured - log the link for testing
		fmt.Printf("Magic link for %s: %s\n", req.Email, magicLink)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message": "If this email is registered, you will receive a sign-in link.",
	})
}

// VerifyMagicLink verifies a magic link token and logs the user in
func (s *BillingService) VerifyMagicLink(w http.ResponseWriter, r *http.Request) {
	token := r.URL.Query().Get("token")
	email := r.URL.Query().Get("email")

	if token == "" || email == "" {
		http.Redirect(w, r, "/login?error=invalid_link", http.StatusFound)
		return
	}

	// Verify token
	var storedToken string
	var expiresAt time.Time
	err := s.db.QueryRow(r.Context(),
		`SELECT token, expires_at FROM magic_links WHERE email = $1`,
		email).Scan(&storedToken, &expiresAt)
	if err != nil {
		http.Redirect(w, r, "/login?error=invalid_link", http.StatusFound)
		return
	}

	if storedToken != token {
		http.Redirect(w, r, "/login?error=invalid_link", http.StatusFound)
		return
	}

	if time.Now().After(expiresAt) {
		http.Redirect(w, r, "/login?error=link_expired", http.StatusFound)
		return
	}

	// Delete used token
	s.db.Exec(r.Context(), `DELETE FROM magic_links WHERE email = $1`, email)

	// Create auth cookie
	userData := map[string]string{
		"email":    email,
		"name":     strings.Split(email, "@")[0],
		"provider": "email",
	}
	userDataJSON, _ := json.Marshal(userData)

	http.SetCookie(w, &http.Cookie{
		Name:     "auth",
		Value:    string(userDataJSON),
		Path:     "/",
		MaxAge:   60 * 60 * 24 * 7, // 7 days
		Secure:   true,
		SameSite: http.SameSiteLaxMode,
	})

	http.Redirect(w, r, "/dashboard", http.StatusFound)
}
