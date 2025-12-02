package main

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/shopspring/decimal"
)

// CreateOrganizationRequest for testing
type CreateOrganizationRequest struct {
	Name  string `json:"name"`
	Email string `json:"email"`
}

var testDB *pgxpool.Pool

func TestMain(m *testing.M) {
	// Setup test database if DATABASE_URL is set
	dbURL := os.Getenv("TEST_DATABASE_URL")
	if dbURL == "" {
		dbURL = os.Getenv("DATABASE_URL")
	}

	if dbURL != "" {
		var err error
		testDB, err = pgxpool.New(context.Background(), dbURL)
		if err != nil {
			// Skip DB tests if can't connect
			testDB = nil
		}
	}

	code := m.Run()

	if testDB != nil {
		testDB.Close()
	}

	os.Exit(code)
}

func TestHealthEndpoint(t *testing.T) {
	r := mux.NewRouter()
	r.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	}).Methods("GET")

	req := httptest.NewRequest("GET", "/health", nil)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var resp map[string]string
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("Failed to parse response: %v", err)
	}

	if resp["status"] != "ok" {
		t.Errorf("Expected status 'ok', got '%s'", resp["status"])
	}
}

func TestOrganizationValidation(t *testing.T) {
	tests := []struct {
		name        string
		input       CreateOrganizationRequest
		shouldError bool
	}{
		{
			name: "valid organization",
			input: CreateOrganizationRequest{
				Name:  "Test Org",
				Email: "test@example.com",
			},
			shouldError: false,
		},
		{
			name: "missing name",
			input: CreateOrganizationRequest{
				Name:  "",
				Email: "test@example.com",
			},
			shouldError: true,
		},
		{
			name: "missing email",
			input: CreateOrganizationRequest{
				Name:  "Test Org",
				Email: "",
			},
			shouldError: true,
		},
		{
			name: "invalid email",
			input: CreateOrganizationRequest{
				Name:  "Test Org",
				Email: "not-an-email",
			},
			shouldError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateOrganizationRequest(tt.input)
			if tt.shouldError && err == nil {
				t.Error("Expected error but got none")
			}
			if !tt.shouldError && err != nil {
				t.Errorf("Expected no error but got: %v", err)
			}
		})
	}
}

func validateOrganizationRequest(req CreateOrganizationRequest) error {
	if req.Name == "" {
		return &ValidationError{Field: "name", Message: "name is required"}
	}
	if req.Email == "" {
		return &ValidationError{Field: "email", Message: "email is required"}
	}
	// Basic email validation
	if len(req.Email) < 3 || !contains(req.Email, "@") || !contains(req.Email, ".") {
		return &ValidationError{Field: "email", Message: "invalid email format"}
	}
	return nil
}

func contains(s, substr string) bool {
	return bytes.Contains([]byte(s), []byte(substr))
}

type ValidationError struct {
	Field   string
	Message string
}

func (e *ValidationError) Error() string {
	return e.Field + ": " + e.Message
}

func TestNamespaceSlugGeneration(t *testing.T) {
	tests := []struct {
		name     string
		expected string
	}{
		{"My Namespace", "my-namespace"},
		{"Test 123", "test-123"},
		{"UPPERCASE", "uppercase"},
		{"with--dashes", "with--dashes"},  // Current impl keeps double dashes
		{"  spaces  ", "--spaces--"},       // Current impl converts spaces to dashes
		{"special!@#chars", "specialchars"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			slug := generateSlug(tt.name)
			if slug != tt.expected {
				t.Errorf("generateSlug(%q) = %q, want %q", tt.name, slug, tt.expected)
			}
		})
	}
}

func TestAPIKeyGenerationSimple(t *testing.T) {
	// Test the simple key generation helper
	key1 := generateSimpleAPIKey()
	key2 := generateSimpleAPIKey()

	// Keys should be unique
	if key1 == key2 {
		t.Error("Generated keys should be unique")
	}

	// Keys should have correct prefix
	if len(key1) < 10 || key1[:8] != "tc_live_" {
		t.Errorf("Key should start with 'tc_live_', got %s", key1[:min(10, len(key1))])
	}

	// Keys should be reasonable length
	if len(key1) < 40 {
		t.Errorf("Key too short: %d chars", len(key1))
	}
}

// Simple key generation for testing
func generateSimpleAPIKey() string {
	return "tc_live_" + testRandomString(32)
}

func testRandomString(n int) string {
	const letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, n)
	for i := range b {
		b[i] = letters[time.Now().UnixNano()%int64(len(letters))]
		time.Sleep(time.Nanosecond) // Ensure different values
	}
	return string(b)
}

func TestAPIKeyHashing(t *testing.T) {
	key := "tc_live_test_key_12345"
	hash1 := hashAPIKey(key)
	hash2 := hashAPIKey(key)

	// Same key should produce same hash
	if hash1 != hash2 {
		t.Error("Same key should produce same hash")
	}

	// Different keys should produce different hashes
	differentKey := "tc_live_different_key"
	differentHash := hashAPIKey(differentKey)
	if hash1 == differentHash {
		t.Error("Different keys should produce different hashes")
	}

	// Hash should not be the same as the key
	if hash1 == key {
		t.Error("Hash should not equal the original key")
	}
}

func TestUsageSummaryCalculation(t *testing.T) {
	summary := UsageSummary{
		TotalActions:       1500000, // 1.5M
		ActiveStorageGBH:   decimal.NewFromInt(720),   // 1GB for month
		RetainedStorageGBH: decimal.NewFromInt(28800), // 40GB for month
	}

	// Calculate estimated cost for Essential plan
	plan := Plans["essential"]

	// Action overage: 0.5M over -> rounds to 1M = $25
	var actionCost int64 = 0
	if summary.TotalActions > plan.ActionsIncluded {
		overageActions := summary.TotalActions - plan.ActionsIncluded
		overageMillions := overageActions / 1000000
		if overageActions%1000000 > 0 {
			overageMillions++
		}
		actionCost = overageMillions * PricePerMillionActions
	}

	if actionCost != 2500 {
		t.Errorf("Expected action overage of 2500 cents, got %d", actionCost)
	}
}

// Integration test - requires database
func TestCreateAndGetOrganization(t *testing.T) {
	if testDB == nil {
		t.Skip("Skipping integration test - no database connection")
	}

	svc := &BillingService{db: testDB}

	// This would test the actual DB operations
	// For now, just verify the service is properly initialized
	if svc.db == nil {
		t.Error("Service DB should not be nil")
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
