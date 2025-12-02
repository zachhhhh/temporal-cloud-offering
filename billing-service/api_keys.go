package main

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
)

// CreateAPIKeyRequest is the request body for creating an API key
type CreateAPIKeyRequest struct {
	Name      string   `json:"name"`
	Scopes    []string `json:"scopes"`
	ExpiresIn string   `json:"expires_in,omitempty"` // e.g., "30d", "90d", "1y"
}

// CreateAPIKeyResponse is the response for creating an API key
type CreateAPIKeyResponse struct {
	ID     uuid.UUID `json:"id"`
	Key    string    `json:"key"` // Only returned once!
	APIKey *APIKey   `json:"api_key"`
}

// CreateAPIKey creates a new API key for an organization
func (s *BillingService) CreateAPIKey(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	orgID, err := uuid.Parse(vars["org_id"])
	if err != nil {
		http.Error(w, `{"error": "invalid organization ID"}`, http.StatusBadRequest)
		return
	}

	var req CreateAPIKeyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error": "invalid request body"}`, http.StatusBadRequest)
		return
	}

	if req.Name == "" {
		http.Error(w, `{"error": "name is required"}`, http.StatusBadRequest)
		return
	}

	// Parse expiration
	var expiresAt *time.Time
	if req.ExpiresIn != "" {
		var duration time.Duration
		switch req.ExpiresIn {
		case "30d":
			duration = 30 * 24 * time.Hour
		case "90d":
			duration = 90 * 24 * time.Hour
		case "1y":
			duration = 365 * 24 * time.Hour
		default:
			duration, err = time.ParseDuration(req.ExpiresIn)
			if err != nil {
				http.Error(w, `{"error": "invalid expires_in format"}`, http.StatusBadRequest)
				return
			}
		}
		t := time.Now().Add(duration)
		expiresAt = &t
	}

	// Default scopes
	if len(req.Scopes) == 0 {
		req.Scopes = []string{"read", "write"}
	}

	// Generate the key
	key, apiKey, err := GenerateAPIKey(s.db, orgID, req.Name, req.Scopes, expiresAt)
	if err != nil {
		http.Error(w, `{"error": "failed to create API key"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(CreateAPIKeyResponse{
		ID:     apiKey.ID,
		Key:    key,
		APIKey: apiKey,
	})
}

// ListAPIKeys lists all API keys for an organization
func (s *BillingService) ListAPIKeys(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	orgID, err := uuid.Parse(vars["org_id"])
	if err != nil {
		http.Error(w, `{"error": "invalid organization ID"}`, http.StatusBadRequest)
		return
	}

	rows, err := s.db.Query(r.Context(),
		`SELECT id, organization_id, name, key_prefix, scopes, expires_at, last_used_at, created_at
		 FROM api_keys WHERE organization_id = $1 ORDER BY created_at DESC`, orgID)
	if err != nil {
		http.Error(w, `{"error": "failed to list API keys"}`, http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var keys []APIKey
	for rows.Next() {
		var key APIKey
		if err := rows.Scan(&key.ID, &key.OrganizationID, &key.Name, &key.KeyPrefix,
			&key.Scopes, &key.ExpiresAt, &key.LastUsedAt, &key.CreatedAt); err != nil {
			continue
		}
		keys = append(keys, key)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(keys)
}

// DeleteAPIKey deletes an API key
func (s *BillingService) DeleteAPIKey(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	keyID, err := uuid.Parse(vars["key_id"])
	if err != nil {
		http.Error(w, `{"error": "invalid key ID"}`, http.StatusBadRequest)
		return
	}

	result, err := s.db.Exec(r.Context(),
		`DELETE FROM api_keys WHERE id = $1`, keyID)
	if err != nil {
		http.Error(w, `{"error": "failed to delete API key"}`, http.StatusInternalServerError)
		return
	}

	if result.RowsAffected() == 0 {
		http.Error(w, `{"error": "API key not found"}`, http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
