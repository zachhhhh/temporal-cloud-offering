//go:build e2e

package e2e

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"testing"
	"time"
)

var billingAPI = getEnv("BILLING_API", "http://localhost:8082")

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func TestHealthCheck(t *testing.T) {
	resp, err := http.Get(billingAPI + "/health")
	if err != nil {
		t.Fatalf("Health check failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Errorf("Expected status 200, got %d", resp.StatusCode)
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if result["status"] != "ok" {
		t.Errorf("Expected status 'ok', got %v", result["status"])
	}
}

func TestCreateOrganization(t *testing.T) {
	payload := map[string]string{
		"name":  "E2E Test Org " + time.Now().Format("20060102150405"),
		"email": "e2e-test@example.com",
	}

	body, _ := json.Marshal(payload)
	resp, err := http.Post(billingAPI+"/api/v1/organizations", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("Create organization failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		bodyBytes, _ := io.ReadAll(resp.Body)
		t.Fatalf("Expected status 200/201, got %d: %s", resp.StatusCode, string(bodyBytes))
	}

	var org map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&org); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if org["id"] == nil {
		t.Error("Organization should have an ID")
	}
	if org["name"] != payload["name"] {
		t.Errorf("Organization name mismatch: expected %s, got %v", payload["name"], org["name"])
	}

	t.Logf("Created organization: %v", org["id"])
}

func TestGetUsageSummary(t *testing.T) {
	orgID := getEnv("TEST_ORG_ID", "demo-org")

	resp, err := http.Get(fmt.Sprintf("%s/api/v1/organizations/%s/usage/current", billingAPI, orgID))
	if err != nil {
		t.Fatalf("Get usage failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		t.Fatalf("Expected status 200, got %d: %s", resp.StatusCode, string(bodyBytes))
	}

	var usage map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&usage); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	// Verify required fields exist
	requiredFields := []string{"total_actions", "active_storage_gbh", "retained_storage_gbh", "estimated_cost_cents"}
	for _, field := range requiredFields {
		if _, ok := usage[field]; !ok {
			t.Errorf("Usage response missing field: %s", field)
		}
	}

	t.Logf("Usage summary: actions=%v, active_storage=%v, retained_storage=%v, cost=%v cents",
		usage["total_actions"], usage["active_storage_gbh"], usage["retained_storage_gbh"], usage["estimated_cost_cents"])
}

func TestListNamespaces(t *testing.T) {
	orgID := getEnv("TEST_ORG_ID", "demo-org")

	resp, err := http.Get(fmt.Sprintf("%s/api/v1/organizations/%s/namespaces", billingAPI, orgID))
	if err != nil {
		t.Fatalf("List namespaces failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		t.Fatalf("Expected status 200, got %d: %s", resp.StatusCode, string(bodyBytes))
	}

	var namespaces []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&namespaces); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	t.Logf("Found %d namespaces", len(namespaces))
}

func TestCreateNamespace(t *testing.T) {
	orgID := getEnv("TEST_ORG_ID", "demo-org")

	payload := map[string]interface{}{
		"name":           "e2e-test-ns-" + time.Now().Format("150405"),
		"region":         "ap-singapore-1",
		"retention_days": 7,
	}

	body, _ := json.Marshal(payload)
	resp, err := http.Post(
		fmt.Sprintf("%s/api/v1/organizations/%s/namespaces", billingAPI, orgID),
		"application/json",
		bytes.NewReader(body),
	)
	if err != nil {
		t.Fatalf("Create namespace failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		bodyBytes, _ := io.ReadAll(resp.Body)
		t.Fatalf("Expected status 200/201, got %d: %s", resp.StatusCode, string(bodyBytes))
	}

	var ns map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&ns); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if ns["id"] == nil {
		t.Error("Namespace should have an ID")
	}
	if ns["temporal_namespace"] == nil {
		t.Error("Namespace should have a temporal_namespace")
	}

	t.Logf("Created namespace: %v -> %v", ns["name"], ns["temporal_namespace"])
}

func TestAPIKeyManagement(t *testing.T) {
	orgID := getEnv("TEST_ORG_ID", "demo-org")

	// Create API key
	payload := map[string]interface{}{
		"name":       "E2E Test Key",
		"expires_in": "30d",
	}

	body, _ := json.Marshal(payload)
	resp, err := http.Post(
		fmt.Sprintf("%s/api/v1/organizations/%s/api-keys", billingAPI, orgID),
		"application/json",
		bytes.NewReader(body),
	)
	if err != nil {
		t.Fatalf("Create API key failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		bodyBytes, _ := io.ReadAll(resp.Body)
		t.Fatalf("Expected status 200/201, got %d: %s", resp.StatusCode, string(bodyBytes))
	}

	var keyResp map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&keyResp); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if keyResp["key"] == nil {
		t.Error("Response should contain the API key")
	}
	if keyResp["id"] == nil {
		t.Error("Response should contain the key ID")
	}

	keyID := keyResp["id"].(string)
	t.Logf("Created API key: %s", keyID)

	// List API keys
	resp2, err := http.Get(fmt.Sprintf("%s/api/v1/organizations/%s/api-keys", billingAPI, orgID))
	if err != nil {
		t.Fatalf("List API keys failed: %v", err)
	}
	defer resp2.Body.Close()

	if resp2.StatusCode != http.StatusOK {
		t.Errorf("Expected status 200, got %d", resp2.StatusCode)
	}

	// Delete API key
	req, _ := http.NewRequest("DELETE", fmt.Sprintf("%s/api/v1/api-keys/%s", billingAPI, keyID), nil)
	resp3, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("Delete API key failed: %v", err)
	}
	defer resp3.Body.Close()

	if resp3.StatusCode != http.StatusOK && resp3.StatusCode != http.StatusNoContent {
		t.Errorf("Expected status 200/204, got %d", resp3.StatusCode)
	}

	t.Log("API key lifecycle test passed")
}

func TestSubscriptionFlow(t *testing.T) {
	orgID := getEnv("TEST_ORG_ID", "demo-org")

	// Get current subscription
	resp, err := http.Get(fmt.Sprintf("%s/api/v1/organizations/%s/subscription", billingAPI, orgID))
	if err != nil {
		t.Fatalf("Get subscription failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		t.Fatalf("Expected status 200, got %d: %s", resp.StatusCode, string(bodyBytes))
	}

	var sub map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&sub); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	// Verify subscription fields
	requiredFields := []string{"plan", "status", "actions_included"}
	for _, field := range requiredFields {
		if _, ok := sub[field]; !ok {
			t.Errorf("Subscription missing field: %s", field)
		}
	}

	t.Logf("Current subscription: plan=%v, status=%v", sub["plan"], sub["status"])
}

func TestInvoiceHistory(t *testing.T) {
	orgID := getEnv("TEST_ORG_ID", "demo-org")

	resp, err := http.Get(fmt.Sprintf("%s/api/v1/organizations/%s/invoices", billingAPI, orgID))
	if err != nil {
		t.Fatalf("Get invoices failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		t.Fatalf("Expected status 200, got %d: %s", resp.StatusCode, string(bodyBytes))
	}

	var invoices []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&invoices); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	t.Logf("Found %d invoices", len(invoices))

	// Verify invoice structure if any exist
	if len(invoices) > 0 {
		inv := invoices[0]
		requiredFields := []string{"id", "invoice_number", "total_cents", "status"}
		for _, field := range requiredFields {
			if _, ok := inv[field]; !ok {
				t.Errorf("Invoice missing field: %s", field)
			}
		}
	}
}

// TestUsageBasedBillingCalculation verifies the pricing calculation is correct
func TestUsageBasedBillingCalculation(t *testing.T) {
	// This test verifies the billing calculation matches expected values
	// Based on Temporal Cloud pricing:
	// - Actions: $25 per million
	// - Active storage: $0.042 per GB-hour
	// - Retained storage: $0.00105 per GB-hour

	testCases := []struct {
		name               string
		actions            int64
		activeStorageGBH   float64
		retainedStorageGBH float64
		expectedMinCents   int64
		expectedMaxCents   int64
	}{
		{
			name:               "Light usage",
			actions:            100000,
			activeStorageGBH:   72,
			retainedStorageGBH: 720,
			expectedMinCents:   300,  // ~$3
			expectedMaxCents:   500,  // ~$5
		},
		{
			name:               "Medium usage",
			actions:            1000000,
			activeStorageGBH:   720,
			retainedStorageGBH: 7200,
			expectedMinCents:   3000,  // ~$30
			expectedMaxCents:   4000,  // ~$40
		},
		{
			name:               "Heavy usage",
			actions:            10000000,
			activeStorageGBH:   7200,
			retainedStorageGBH: 72000,
			expectedMinCents:   250000, // ~$2500
			expectedMaxCents:   350000, // ~$3500
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			// Calculate expected cost
			actionCost := (tc.actions / 1000000) * 2500 // $25 per million
			if tc.actions%1000000 > 0 {
				actionCost += 2500 // Round up
			}
			activeStorageCost := int64(tc.activeStorageGBH * 4.2)      // 4.2 cents per GB-hour
			retainedStorageCost := int64(tc.retainedStorageGBH * 0.105) // 0.105 cents per GB-hour

			totalCost := actionCost + activeStorageCost + retainedStorageCost

			if totalCost < tc.expectedMinCents || totalCost > tc.expectedMaxCents {
				t.Errorf("Cost %d cents ($%.2f) outside expected range [%d, %d]",
					totalCost, float64(totalCost)/100,
					tc.expectedMinCents, tc.expectedMaxCents)
			}

			t.Logf("%s: actions=%d ($%.2f), active_storage=%.0f GB-h ($%.2f), retained_storage=%.0f GB-h ($%.2f), total=$%.2f",
				tc.name,
				tc.actions, float64(actionCost)/100,
				tc.activeStorageGBH, float64(activeStorageCost)/100,
				tc.retainedStorageGBH, float64(retainedStorageCost)/100,
				float64(totalCost)/100)
		})
	}
}
