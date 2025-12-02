package main

import (
	"testing"

	"github.com/shopspring/decimal"
)

func TestPricingConstants(t *testing.T) {
	// Verify pricing matches Temporal Cloud pricing
	// https://temporal.io/pricing

	// Actions: $25 per million
	if PricePerMillionActions != 2500 {
		t.Errorf("Expected $25/million actions (2500 cents), got %d", PricePerMillionActions)
	}

	// Active storage: $0.042 per GB-hour
	if PricePerActiveStorageGBH != 4.2 {
		t.Errorf("Expected $0.042/GB-hour (4.2 cents), got %f", PricePerActiveStorageGBH)
	}

	// Retained storage: $0.00105 per GB-hour
	if PricePerRetainedStorageGBH != 0.105 {
		t.Errorf("Expected $0.00105/GB-hour (0.105 cents), got %f", PricePerRetainedStorageGBH)
	}
}

func TestPlanLimits(t *testing.T) {
	tests := []struct {
		plan              string
		expectedActions   int64
		expectedActiveGB  float64
		expectedRetainedGB int64
		expectedBaseCents int64
	}{
		{"free", 100000, 0.1, 4, 0},
		{"essential", 1000000, 1.0, 40, 10000},
		{"business", 2500000, 2.5, 100, 50000},
		{"enterprise", 10000000, 10.0, 400, 0},
	}

	for _, tt := range tests {
		t.Run(tt.plan, func(t *testing.T) {
			plan, ok := Plans[tt.plan]
			if !ok {
				t.Fatalf("Plan %s not found", tt.plan)
			}

			if plan.ActionsIncluded != tt.expectedActions {
				t.Errorf("Plan %s: expected %d actions, got %d", tt.plan, tt.expectedActions, plan.ActionsIncluded)
			}

			expectedActiveGB := decimal.NewFromFloat(tt.expectedActiveGB)
			if !plan.ActiveStorageGB.Equal(expectedActiveGB) {
				t.Errorf("Plan %s: expected %s active GB, got %s", tt.plan, expectedActiveGB, plan.ActiveStorageGB)
			}

			expectedRetainedGB := decimal.NewFromInt(tt.expectedRetainedGB)
			if !plan.RetainedStorageGB.Equal(expectedRetainedGB) {
				t.Errorf("Plan %s: expected %s retained GB, got %s", tt.plan, expectedRetainedGB, plan.RetainedStorageGB)
			}

			if plan.BasePriceCents != tt.expectedBaseCents {
				t.Errorf("Plan %s: expected %d base cents, got %d", tt.plan, tt.expectedBaseCents, plan.BasePriceCents)
			}
		})
	}
}

func TestActionOverageCalculation(t *testing.T) {
	tests := []struct {
		name            string
		actionsUsed     int64
		actionsIncluded int64
		expectedCents   int64
	}{
		{"no overage", 500000, 1000000, 0},
		{"exactly at limit", 1000000, 1000000, 0},
		{"1 action over", 1000001, 1000000, 2500},      // Rounds up to 1M overage
		{"500k over", 1500000, 1000000, 2500},          // 0.5M rounds up to 1M = $25
		{"1M over", 2000000, 1000000, 2500},            // 1M = $25
		{"1.5M over", 2500000, 1000000, 5000},          // 1.5M rounds up to 2M = $50
		{"10M over", 11000000, 1000000, 25000},         // 10M = $250
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var overageCents int64 = 0
			if tt.actionsUsed > tt.actionsIncluded {
				overageActions := tt.actionsUsed - tt.actionsIncluded
				overageMillions := overageActions / 1000000
				if overageActions%1000000 > 0 {
					overageMillions++ // Round up
				}
				overageCents = overageMillions * PricePerMillionActions
			}

			if overageCents != tt.expectedCents {
				t.Errorf("%s: expected %d cents, got %d cents", tt.name, tt.expectedCents, overageCents)
			}
		})
	}
}

func TestActiveStorageCostCalculation(t *testing.T) {
	tests := []struct {
		name          string
		gbHours       float64
		expectedCents int64
	}{
		{"zero usage", 0, 0},
		{"1 GB-hour", 1, 4},                    // 1 * 4.2 = 4.2 -> 4 cents
		{"10 GB-hours", 10, 42},                // 10 * 4.2 = 42 cents
		{"100 GB-hours", 100, 420},             // 100 * 4.2 = $4.20
		{"720 GB-hours (1GB for month)", 720, 3024}, // 720 * 4.2 = $30.24
		{"7200 GB-hours (10GB for month)", 7200, 30240}, // 7200 * 4.2 = $302.40
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gbh := decimal.NewFromFloat(tt.gbHours)
			cost := gbh.Mul(decimal.NewFromFloat(PricePerActiveStorageGBH))
			costCents := cost.IntPart()

			if costCents != tt.expectedCents {
				t.Errorf("%s: expected %d cents, got %d cents (raw: %s)", tt.name, tt.expectedCents, costCents, cost.String())
			}
		})
	}
}

func TestRetainedStorageCostCalculation(t *testing.T) {
	tests := []struct {
		name          string
		gbHours       float64
		expectedCents int64
	}{
		{"zero usage", 0, 0},
		{"1 GB-hour", 1, 0},                     // 1 * 0.105 = 0.105 -> 0 cents
		{"10 GB-hours", 10, 1},                  // 10 * 0.105 = 1.05 -> 1 cent
		{"100 GB-hours", 100, 10},               // 100 * 0.105 = 10.5 -> 10 cents
		{"720 GB-hours (1GB for month)", 720, 75},   // 720 * 0.105 = 75.6 -> 75 cents
		{"7200 GB-hours (10GB for month)", 7200, 756}, // 7200 * 0.105 = $7.56
		{"72000 GB-hours (100GB for month)", 72000, 7560}, // 72000 * 0.105 = $75.60
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gbh := decimal.NewFromFloat(tt.gbHours)
			cost := gbh.Mul(decimal.NewFromFloat(PricePerRetainedStorageGBH))
			costCents := cost.IntPart()

			if costCents != tt.expectedCents {
				t.Errorf("%s: expected %d cents, got %d cents (raw: %s)", tt.name, tt.expectedCents, costCents, cost.String())
			}
		})
	}
}

func TestMonthlyBillScenarios(t *testing.T) {
	// Test realistic monthly billing scenarios
	tests := []struct {
		name               string
		plan               string
		actions            int64
		activeStorageGBH   float64
		retainedStorageGBH float64
		expectedTotal      int64 // in cents
	}{
		{
			name:               "Free tier - minimal usage",
			plan:               "free",
			actions:            50000,
			activeStorageGBH:   72,   // 0.1GB for 720 hours
			retainedStorageGBH: 2880, // 4GB for 720 hours
			expectedTotal:      605,  // 0 base + 0 overage + 302 active + 302 retained
		},
		{
			name:               "Essential - within limits",
			plan:               "essential",
			actions:            800000,
			activeStorageGBH:   720,   // 1GB for month
			retainedStorageGBH: 28800, // 40GB for month
			expectedTotal:      16048, // $100 base + 0 overage + $30.24 active + $30.24 retained
		},
		{
			name:               "Essential - with action overage",
			plan:               "essential",
			actions:            2500000, // 1.5M over limit
			activeStorageGBH:   720,
			retainedStorageGBH: 28800,
			expectedTotal:      21048, // $100 base + $50 overage (2M) + $30.24 active + $30.24 retained
		},
		{
			name:               "Business - heavy usage",
			plan:               "business",
			actions:            5000000, // 2.5M over limit
			activeStorageGBH:   3600,    // 5GB for month
			retainedStorageGBH: 144000,  // 200GB for month
			expectedTotal:      87740,   // $500 base + $75 overage (3M) + $151.20 active + $151.20 retained
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			plan := Plans[tt.plan]

			// Calculate base cost
			baseCost := plan.BasePriceCents

			// Calculate action overage
			var actionOverage int64 = 0
			if tt.actions > plan.ActionsIncluded {
				overageActions := tt.actions - plan.ActionsIncluded
				overageMillions := overageActions / 1000000
				if overageActions%1000000 > 0 {
					overageMillions++
				}
				actionOverage = overageMillions * PricePerMillionActions
			}

			// Calculate storage costs
			activeGBH := decimal.NewFromFloat(tt.activeStorageGBH)
			activeCost := activeGBH.Mul(decimal.NewFromFloat(PricePerActiveStorageGBH)).IntPart()

			retainedGBH := decimal.NewFromFloat(tt.retainedStorageGBH)
			retainedCost := retainedGBH.Mul(decimal.NewFromFloat(PricePerRetainedStorageGBH)).IntPart()

			total := baseCost + actionOverage + activeCost + retainedCost

			// Allow 1% tolerance for rounding
			tolerance := tt.expectedTotal / 100
			if tolerance < 10 {
				tolerance = 10
			}

			diff := total - tt.expectedTotal
			if diff < 0 {
				diff = -diff
			}

			if diff > tolerance {
				t.Errorf("%s: expected ~%d cents ($%.2f), got %d cents ($%.2f)\n"+
					"  Base: %d, Action Overage: %d, Active Storage: %d, Retained Storage: %d",
					tt.name, tt.expectedTotal, float64(tt.expectedTotal)/100,
					total, float64(total)/100,
					baseCost, actionOverage, activeCost, retainedCost)
			}
		})
	}
}

func TestEdgeCases(t *testing.T) {
	t.Run("zero usage", func(t *testing.T) {
		plan := Plans["essential"]
		total := plan.BasePriceCents // Just base cost
		if total != 10000 {
			t.Errorf("Zero usage should be $100 base, got %d cents", total)
		}
	})

	t.Run("exactly at action limit", func(t *testing.T) {
		plan := Plans["essential"]
		actions := plan.ActionsIncluded // Exactly 1M

		var overage int64 = 0
		if actions > plan.ActionsIncluded {
			overage = ((actions - plan.ActionsIncluded + 999999) / 1000000) * PricePerMillionActions
		}

		if overage != 0 {
			t.Errorf("At exactly action limit, overage should be 0, got %d", overage)
		}
	})

	t.Run("one action over limit", func(t *testing.T) {
		plan := Plans["essential"]
		actions := plan.ActionsIncluded + 1 // 1M + 1

		overageActions := actions - plan.ActionsIncluded
		overageMillions := overageActions / 1000000
		if overageActions%1000000 > 0 {
			overageMillions++
		}
		overage := overageMillions * PricePerMillionActions

		// Should round up to 1M overage = $25
		if overage != 2500 {
			t.Errorf("1 action over should cost $25 (2500 cents), got %d", overage)
		}
	})

	t.Run("large numbers don't overflow", func(t *testing.T) {
		// 1 billion actions
		actions := int64(1000000000)
		included := int64(1000000)

		overageActions := actions - included
		overageMillions := overageActions / 1000000
		if overageActions%1000000 > 0 {
			overageMillions++
		}
		overage := overageMillions * PricePerMillionActions

		// 999M overage = $24,975
		expected := int64(999 * 2500)
		if overage != expected {
			t.Errorf("Large action count: expected %d, got %d", expected, overage)
		}
	})
}
