package main

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/shopspring/decimal"
	"github.com/stripe/stripe-go/v76"
	"github.com/stripe/stripe-go/v76/invoice"
	"github.com/stripe/stripe-go/v76/invoiceitem"
)

// Pricing constants (in cents)
const (
	// Actions pricing: $25-50 per million (using $25 for base tier)
	PricePerMillionActions = 2500 // $25.00 in cents

	// Active storage: $0.042 per GB-hour
	PricePerActiveStorageGBH = 4.2 // cents

	// Retained storage: $0.00105 per GB-hour
	PricePerRetainedStorageGBH = 0.105 // cents
)

// Plan defines a subscription plan
type Plan struct {
	ID                string
	Name              string
	BasePriceCents    int64
	ActionsIncluded   int64
	ActiveStorageGB   decimal.Decimal
	RetainedStorageGB decimal.Decimal
	StripePriceID     string
}

// Plans defines available subscription plans
var Plans = map[string]Plan{
	"free": {
		ID:                "free",
		Name:              "Free",
		BasePriceCents:    0,
		ActionsIncluded:   100000,
		ActiveStorageGB:   decimal.NewFromFloat(0.1),
		RetainedStorageGB: decimal.NewFromInt(4),
		StripePriceID:     "",
	},
	"essential": {
		ID:                "essential",
		Name:              "Essential",
		BasePriceCents:    10000, // $100/month
		ActionsIncluded:   1000000,
		ActiveStorageGB:   decimal.NewFromInt(1),
		RetainedStorageGB: decimal.NewFromInt(40),
		StripePriceID:     "price_essential_monthly",
	},
	"business": {
		ID:                "business",
		Name:              "Business",
		BasePriceCents:    50000, // $500/month
		ActionsIncluded:   2500000,
		ActiveStorageGB:   decimal.NewFromFloat(2.5),
		RetainedStorageGB: decimal.NewFromInt(100),
		StripePriceID:     "price_business_monthly",
	},
	"enterprise": {
		ID:                "enterprise",
		Name:              "Enterprise",
		BasePriceCents:    0, // Custom pricing
		ActionsIncluded:   10000000,
		ActiveStorageGB:   decimal.NewFromInt(10),
		RetainedStorageGB: decimal.NewFromInt(400),
		StripePriceID:     "price_enterprise_monthly",
	},
}

// UsageMeter handles usage-based billing calculations
type UsageMeter struct {
	db *pgxpool.Pool
}

// NewUsageMeter creates a new usage meter
func NewUsageMeter(db *pgxpool.Pool) *UsageMeter {
	return &UsageMeter{db: db}
}

// CalculateMonthlyBill calculates the bill for an organization for a given month
func (m *UsageMeter) CalculateMonthlyBill(ctx context.Context, orgID uuid.UUID, periodStart, periodEnd time.Time) (*MonthlyBill, error) {
	// Get subscription
	var planName string
	err := m.db.QueryRow(ctx,
		`SELECT plan FROM subscriptions WHERE organization_id = $1`, orgID).Scan(&planName)
	if err != nil {
		return nil, fmt.Errorf("failed to get subscription: %w", err)
	}

	plan, ok := Plans[planName]
	if !ok {
		plan = Plans["free"]
	}

	// Get usage aggregates for the period
	var totalActions int64
	var activeStorageGBH, retainedStorageGBH decimal.Decimal

	err = m.db.QueryRow(ctx,
		`SELECT COALESCE(SUM(total_actions), 0), 
		        COALESCE(SUM(active_storage_gbh), 0), 
		        COALESCE(SUM(retained_storage_gbh), 0)
		 FROM usage_aggregates 
		 WHERE organization_id = $1 AND period_start >= $2 AND period_end <= $3`,
		orgID, periodStart, periodEnd).
		Scan(&totalActions, &activeStorageGBH, &retainedStorageGBH)
	if err != nil {
		return nil, fmt.Errorf("failed to get usage: %w", err)
	}

	bill := &MonthlyBill{
		OrganizationID: orgID,
		PeriodStart:    periodStart,
		PeriodEnd:      periodEnd,
		Plan:           plan.Name,
		BaseCostCents:  plan.BasePriceCents,
	}

	// Calculate overage for actions
	if totalActions > plan.ActionsIncluded {
		overageActions := totalActions - plan.ActionsIncluded
		overageMillions := overageActions / 1000000
		if overageActions%1000000 > 0 {
			overageMillions++ // Round up
		}
		bill.ActionOverageCents = overageMillions * PricePerMillionActions
		bill.ActionsUsed = totalActions
		bill.ActionsIncluded = plan.ActionsIncluded
	}

	// Calculate storage costs (always charged, no included amount for overage)
	activeStorageCost := activeStorageGBH.Mul(decimal.NewFromFloat(PricePerActiveStorageGBH))
	retainedStorageCost := retainedStorageGBH.Mul(decimal.NewFromFloat(PricePerRetainedStorageGBH))

	bill.ActiveStorageCents = activeStorageCost.IntPart()
	bill.RetainedStorageCents = retainedStorageCost.IntPart()
	bill.ActiveStorageGBH = activeStorageGBH
	bill.RetainedStorageGBH = retainedStorageGBH

	// Calculate total
	bill.TotalCents = bill.BaseCostCents + bill.ActionOverageCents + bill.ActiveStorageCents + bill.RetainedStorageCents

	return bill, nil
}

// MonthlyBill represents a calculated monthly bill
type MonthlyBill struct {
	OrganizationID      uuid.UUID       `json:"organization_id"`
	PeriodStart         time.Time       `json:"period_start"`
	PeriodEnd           time.Time       `json:"period_end"`
	Plan                string          `json:"plan"`
	BaseCostCents       int64           `json:"base_cost_cents"`
	ActionsUsed         int64           `json:"actions_used"`
	ActionsIncluded     int64           `json:"actions_included"`
	ActionOverageCents  int64           `json:"action_overage_cents"`
	ActiveStorageGBH    decimal.Decimal `json:"active_storage_gbh"`
	ActiveStorageCents  int64           `json:"active_storage_cents"`
	RetainedStorageGBH  decimal.Decimal `json:"retained_storage_gbh"`
	RetainedStorageCents int64          `json:"retained_storage_cents"`
	TotalCents          int64           `json:"total_cents"`
}

// GenerateStripeInvoice creates a Stripe invoice for the monthly bill
func (m *UsageMeter) GenerateStripeInvoice(ctx context.Context, bill *MonthlyBill) error {
	// Get Stripe customer ID
	var stripeCustomerID string
	err := m.db.QueryRow(ctx,
		`SELECT stripe_customer_id FROM organizations WHERE id = $1`, bill.OrganizationID).
		Scan(&stripeCustomerID)
	if err != nil {
		return fmt.Errorf("failed to get Stripe customer: %w", err)
	}

	if stripeCustomerID == "" {
		return fmt.Errorf("organization has no Stripe customer ID")
	}

	// Create invoice items
	if bill.BaseCostCents > 0 {
		_, err = invoiceitem.New(&stripe.InvoiceItemParams{
			Customer:    stripe.String(stripeCustomerID),
			Amount:      stripe.Int64(bill.BaseCostCents),
			Currency:    stripe.String("usd"),
			Description: stripe.String(fmt.Sprintf("%s Plan - %s", bill.Plan, bill.PeriodStart.Format("January 2006"))),
		})
		if err != nil {
			return fmt.Errorf("failed to create base invoice item: %w", err)
		}
	}

	if bill.ActionOverageCents > 0 {
		_, err = invoiceitem.New(&stripe.InvoiceItemParams{
			Customer:    stripe.String(stripeCustomerID),
			Amount:      stripe.Int64(bill.ActionOverageCents),
			Currency:    stripe.String("usd"),
			Description: stripe.String(fmt.Sprintf("Action Overage (%d actions)", bill.ActionsUsed-bill.ActionsIncluded)),
		})
		if err != nil {
			return fmt.Errorf("failed to create action overage item: %w", err)
		}
	}

	if bill.ActiveStorageCents > 0 {
		_, err = invoiceitem.New(&stripe.InvoiceItemParams{
			Customer:    stripe.String(stripeCustomerID),
			Amount:      stripe.Int64(bill.ActiveStorageCents),
			Currency:    stripe.String("usd"),
			Description: stripe.String(fmt.Sprintf("Active Storage (%s GB-hours)", bill.ActiveStorageGBH.StringFixed(2))),
		})
		if err != nil {
			return fmt.Errorf("failed to create active storage item: %w", err)
		}
	}

	if bill.RetainedStorageCents > 0 {
		_, err = invoiceitem.New(&stripe.InvoiceItemParams{
			Customer:    stripe.String(stripeCustomerID),
			Amount:      stripe.Int64(bill.RetainedStorageCents),
			Currency:    stripe.String("usd"),
			Description: stripe.String(fmt.Sprintf("Retained Storage (%s GB-hours)", bill.RetainedStorageGBH.StringFixed(2))),
		})
		if err != nil {
			return fmt.Errorf("failed to create retained storage item: %w", err)
		}
	}

	// Create and finalize invoice
	inv, err := invoice.New(&stripe.InvoiceParams{
		Customer:         stripe.String(stripeCustomerID),
		AutoAdvance:      stripe.Bool(true),
		CollectionMethod: stripe.String("charge_automatically"),
	})
	if err != nil {
		return fmt.Errorf("failed to create invoice: %w", err)
	}

	// Store invoice in database
	invoiceNumber := fmt.Sprintf("INV-%s-%s", bill.OrganizationID.String()[:8], bill.PeriodStart.Format("200601"))
	_, err = m.db.Exec(ctx,
		`INSERT INTO invoices (organization_id, stripe_invoice_id, invoice_number, period_start, period_end, 
		                       subtotal_cents, total_cents, status, line_items)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending', $8)`,
		bill.OrganizationID, inv.ID, invoiceNumber, bill.PeriodStart, bill.PeriodEnd,
		bill.TotalCents, bill.TotalCents, bill)
	if err != nil {
		log.Printf("Failed to store invoice in database: %v", err)
	}

	return nil
}

// RunMonthlyBilling runs billing for all organizations
func (m *UsageMeter) RunMonthlyBilling(ctx context.Context) error {
	// Calculate period (previous month)
	now := time.Now().UTC()
	periodEnd := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
	periodStart := periodEnd.AddDate(0, -1, 0)

	log.Printf("Running monthly billing for period %s to %s", periodStart.Format("2006-01-02"), periodEnd.Format("2006-01-02"))

	// Get all active organizations
	rows, err := m.db.Query(ctx,
		`SELECT o.id FROM organizations o 
		 JOIN subscriptions s ON s.organization_id = o.id 
		 WHERE s.status = 'active' AND s.plan != 'free'`)
	if err != nil {
		return fmt.Errorf("failed to get organizations: %w", err)
	}
	defer rows.Close()

	var processed, failed int
	for rows.Next() {
		var orgID uuid.UUID
		if err := rows.Scan(&orgID); err != nil {
			continue
		}

		bill, err := m.CalculateMonthlyBill(ctx, orgID, periodStart, periodEnd)
		if err != nil {
			log.Printf("Failed to calculate bill for org %s: %v", orgID, err)
			failed++
			continue
		}

		if bill.TotalCents > 0 {
			if err := m.GenerateStripeInvoice(ctx, bill); err != nil {
				log.Printf("Failed to generate invoice for org %s: %v", orgID, err)
				failed++
				continue
			}
		}

		processed++
	}

	log.Printf("Monthly billing complete: %d processed, %d failed", processed, failed)
	return nil
}
