package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/gorilla/mux"
	"github.com/stripe/stripe-go/v76"
)

func TestCheckoutSessionEndpoint(t *testing.T) {
	// Skip if no Stripe key configured
	stripeKey := os.Getenv("STRIPE_SECRET_KEY")
	if stripeKey == "" {
		t.Skip("Skipping checkout test - STRIPE_SECRET_KEY not set")
	}

	// Initialize Stripe
	stripe.Key = stripeKey

	// Create service with nil DB (we won't hit DB in this test)
	svc := &BillingService{db: nil}

	r := mux.NewRouter()
	r.HandleFunc("/api/v1/stripe/checkout", svc.CreateCheckoutSession).Methods("POST")

	tests := []struct {
		name           string
		request        CheckoutRequest
		expectedStatus int
	}{
		{
			name: "valid essential plan checkout",
			request: CheckoutRequest{
				OrganizationID: "test-org-123",
				PlanID:         "essential",
				SuccessURL:     "https://example.com/success",
				CancelURL:      "https://example.com/cancel",
			},
			expectedStatus: http.StatusOK,
		},
		{
			name: "valid business plan checkout",
			request: CheckoutRequest{
				OrganizationID: "test-org-456",
				PlanID:         "business",
				SuccessURL:     "https://example.com/success",
				CancelURL:      "https://example.com/cancel",
			},
			expectedStatus: http.StatusOK,
		},
		{
			name: "invalid plan ID",
			request: CheckoutRequest{
				OrganizationID: "test-org-789",
				PlanID:         "invalid-plan",
				SuccessURL:     "https://example.com/success",
				CancelURL:      "https://example.com/cancel",
			},
			expectedStatus: http.StatusBadRequest,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			body, _ := json.Marshal(tt.request)
			req := httptest.NewRequest("POST", "/api/v1/stripe/checkout", bytes.NewReader(body))
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()

			r.ServeHTTP(w, req)

			if w.Code != tt.expectedStatus {
				t.Errorf("Expected status %d, got %d. Body: %s", tt.expectedStatus, w.Code, w.Body.String())
			}

			if tt.expectedStatus == http.StatusOK {
				var resp map[string]string
				if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
					t.Fatalf("Failed to parse response: %v", err)
				}
				if resp["url"] == "" {
					t.Error("Expected checkout URL in response")
				}
				if resp["session_id"] == "" {
					t.Error("Expected session_id in response")
				}
			}
		})
	}
}

func TestCheckoutRequestValidation(t *testing.T) {
	tests := []struct {
		name        string
		request     CheckoutRequest
		shouldError bool
	}{
		{
			name: "valid request",
			request: CheckoutRequest{
				OrganizationID: "org-123",
				PlanID:         "essential",
				SuccessURL:     "https://example.com/success",
				CancelURL:      "https://example.com/cancel",
			},
			shouldError: false,
		},
		{
			name: "missing plan ID",
			request: CheckoutRequest{
				OrganizationID: "org-123",
				PlanID:         "",
				SuccessURL:     "https://example.com/success",
				CancelURL:      "https://example.com/cancel",
			},
			shouldError: true,
		},
		{
			name: "missing success URL",
			request: CheckoutRequest{
				OrganizationID: "org-123",
				PlanID:         "essential",
				SuccessURL:     "",
				CancelURL:      "https://example.com/cancel",
			},
			shouldError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateCheckoutRequest(tt.request)
			if tt.shouldError && err == nil {
				t.Error("Expected error but got none")
			}
			if !tt.shouldError && err != nil {
				t.Errorf("Expected no error but got: %v", err)
			}
		})
	}
}

func validateCheckoutRequest(req CheckoutRequest) error {
	if req.PlanID == "" {
		return &ValidationError{Field: "plan_id", Message: "plan_id is required"}
	}
	if req.SuccessURL == "" {
		return &ValidationError{Field: "success_url", Message: "success_url is required"}
	}
	if req.CancelURL == "" {
		return &ValidationError{Field: "cancel_url", Message: "cancel_url is required"}
	}
	return nil
}
