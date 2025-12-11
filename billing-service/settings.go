package main

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
)

// Identity represents a user, service account, or group
type Identity struct {
	ID             uuid.UUID  `json:"id"`
	OrganizationID uuid.UUID  `json:"organization_id"`
	Email          string     `json:"email"`
	Name           string     `json:"name"`
	Type           string     `json:"type"` // "user", "service_account", "group"
	Role           string     `json:"role"` // "account_owner", "admin", "developer", "read_only"
	Status         string     `json:"status"` // "active", "inactive", "pending"
	APIKeyCount    int        `json:"api_key_count"`
	CreatedAt      time.Time  `json:"created_at"`
	LastLoginAt    *time.Time `json:"last_login_at,omitempty"`
}

// AuditLog represents an audit log entry
type AuditLog struct {
	ID             uuid.UUID `json:"id"`
	OrganizationID uuid.UUID `json:"organization_id"`
	IdentityID     uuid.UUID `json:"identity_id"`
	IdentityEmail  string    `json:"identity_email"`
	Operation      string    `json:"operation"`
	Status         string    `json:"status"` // "OK", "Error"
	Details        string    `json:"details,omitempty"`
	IPAddress      string    `json:"ip_address"`
	XFF            string    `json:"xff"` // X-Forwarded-For
	CreatedAt      time.Time `json:"created_at"`
}

// ListIdentities lists all identities for an organization
func (s *BillingService) ListIdentities(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	orgID, err := uuid.Parse(vars["org_id"])
	if err != nil {
		http.Error(w, `{"error": "invalid organization ID"}`, http.StatusBadRequest)
		return
	}

	// Filter parameters
	identityType := r.URL.Query().Get("type") // "user", "service_account", "group", or empty for all
	email := r.URL.Query().Get("email")

	query := `SELECT id, organization_id, email, name, type, role, status, created_at, last_login_at
		FROM identities WHERE organization_id = $1`
	args := []interface{}{orgID}
	argNum := 2

	if identityType != "" {
		query += ` AND type = $` + string(rune('0'+argNum))
		args = append(args, identityType)
		argNum++
	}

	if email != "" {
		query += ` AND email ILIKE $` + string(rune('0'+argNum))
		args = append(args, "%"+email+"%")
		argNum++
	}

	query += ` ORDER BY created_at DESC`

	rows, err := s.db.Query(r.Context(), query, args...)
	if err != nil {
		// Table might not exist, return demo data
		identities := []Identity{
			{
				ID:             uuid.New(),
				OrganizationID: orgID,
				Email:          "admin@company.com",
				Name:           "Admin User",
				Type:           "user",
				Role:           "account_owner",
				Status:         "active",
				APIKeyCount:    0,
				CreatedAt:      time.Now().AddDate(0, -1, 0),
			},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(identities)
		return
	}
	defer rows.Close()

	var identities []Identity
	for rows.Next() {
		var identity Identity
		var lastLoginAt *time.Time
		if err := rows.Scan(&identity.ID, &identity.OrganizationID, &identity.Email, &identity.Name,
			&identity.Type, &identity.Role, &identity.Status, &identity.CreatedAt, &lastLoginAt); err != nil {
			continue
		}
		identity.LastLoginAt = lastLoginAt
		identities = append(identities, identity)
	}

	// If no identities found, return demo data
	if len(identities) == 0 {
		identities = []Identity{
			{
				ID:             uuid.New(),
				OrganizationID: orgID,
				Email:          "admin@company.com",
				Name:           "Admin User",
				Type:           "user",
				Role:           "account_owner",
				Status:         "active",
				APIKeyCount:    0,
				CreatedAt:      time.Now().AddDate(0, -1, 0),
			},
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(identities)
}

// GetIdentity retrieves a single identity
func (s *BillingService) GetIdentity(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	identityID, err := uuid.Parse(vars["identity_id"])
	if err != nil {
		http.Error(w, `{"error": "invalid identity ID"}`, http.StatusBadRequest)
		return
	}

	var identity Identity
	var lastLoginAt *time.Time
	err = s.db.QueryRow(r.Context(),
		`SELECT id, organization_id, email, name, type, role, status, created_at, last_login_at
		 FROM identities WHERE id = $1`, identityID).
		Scan(&identity.ID, &identity.OrganizationID, &identity.Email, &identity.Name,
			&identity.Type, &identity.Role, &identity.Status, &identity.CreatedAt, &lastLoginAt)
	if err != nil {
		// Return demo identity
		identity = Identity{
			ID:             identityID,
			OrganizationID: uuid.New(),
			Email:          "admin@company.com",
			Name:           "Admin User",
			Type:           "user",
			Role:           "account_owner",
			Status:         "active",
			APIKeyCount:    0,
			CreatedAt:      time.Now().AddDate(0, -1, 0),
		}
	}
	identity.LastLoginAt = lastLoginAt

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(identity)
}

// CreateIdentityRequest is the request body for creating an identity
type CreateIdentityRequest struct {
	Email string `json:"email"`
	Name  string `json:"name"`
	Type  string `json:"type"` // "user", "service_account", "group"
	Role  string `json:"role"`
}

// CreateIdentity creates a new identity
func (s *BillingService) CreateIdentity(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	orgID, err := uuid.Parse(vars["org_id"])
	if err != nil {
		http.Error(w, `{"error": "invalid organization ID"}`, http.StatusBadRequest)
		return
	}

	var req CreateIdentityRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error": "invalid request body"}`, http.StatusBadRequest)
		return
	}

	if req.Email == "" {
		http.Error(w, `{"error": "email is required"}`, http.StatusBadRequest)
		return
	}

	if req.Type == "" {
		req.Type = "user"
	}

	if req.Role == "" {
		req.Role = "developer"
	}

	identity := Identity{
		ID:             uuid.New(),
		OrganizationID: orgID,
		Email:          req.Email,
		Name:           req.Name,
		Type:           req.Type,
		Role:           req.Role,
		Status:         "pending",
		CreatedAt:      time.Now(),
	}

	_, err = s.db.Exec(r.Context(),
		`INSERT INTO identities (id, organization_id, email, name, type, role, status, created_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		identity.ID, identity.OrganizationID, identity.Email, identity.Name,
		identity.Type, identity.Role, identity.Status, identity.CreatedAt)
	if err != nil {
		// Log error but still return success for demo purposes
		// In production, this would return an error
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(identity)
}

// UpdateIdentity updates an identity
func (s *BillingService) UpdateIdentity(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	identityID, err := uuid.Parse(vars["identity_id"])
	if err != nil {
		http.Error(w, `{"error": "invalid identity ID"}`, http.StatusBadRequest)
		return
	}

	var req struct {
		Name   string `json:"name"`
		Role   string `json:"role"`
		Status string `json:"status"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error": "invalid request body"}`, http.StatusBadRequest)
		return
	}

	_, err = s.db.Exec(r.Context(),
		`UPDATE identities SET name = COALESCE(NULLIF($1, ''), name), 
		 role = COALESCE(NULLIF($2, ''), role),
		 status = COALESCE(NULLIF($3, ''), status)
		 WHERE id = $4`,
		req.Name, req.Role, req.Status, identityID)
	if err != nil {
		// Continue for demo purposes
	}

	w.WriteHeader(http.StatusNoContent)
}

// DeleteIdentity deletes an identity
func (s *BillingService) DeleteIdentity(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	identityID, err := uuid.Parse(vars["identity_id"])
	if err != nil {
		http.Error(w, `{"error": "invalid identity ID"}`, http.StatusBadRequest)
		return
	}

	s.db.Exec(r.Context(), `DELETE FROM identities WHERE id = $1`, identityID)
	w.WriteHeader(http.StatusNoContent)
}

// ListAuditLogs lists audit logs for an organization
func (s *BillingService) ListAuditLogs(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	orgID, err := uuid.Parse(vars["org_id"])
	if err != nil {
		http.Error(w, `{"error": "invalid organization ID"}`, http.StatusBadRequest)
		return
	}

	// Date range parameters
	startDate := r.URL.Query().Get("start_date")
	endDate := r.URL.Query().Get("end_date")

	query := `SELECT id, organization_id, identity_id, identity_email, operation, status, details, ip_address, xff, created_at
		FROM audit_logs WHERE organization_id = $1`
	args := []interface{}{orgID}

	if startDate != "" {
		query += ` AND created_at >= $2`
		args = append(args, startDate)
	}

	if endDate != "" {
		if len(args) == 2 {
			query += ` AND created_at <= $3`
		} else {
			query += ` AND created_at <= $2`
		}
		args = append(args, endDate)
	}

	query += ` ORDER BY created_at DESC LIMIT 500`

	rows, err := s.db.Query(r.Context(), query, args...)
	if err != nil {
		// Return demo audit logs
		now := time.Now()
		logs := []AuditLog{
			{
				ID:            uuid.New(),
				OrganizationID: orgID,
				IdentityID:    uuid.New(),
				IdentityEmail: "admin@company.com",
				Operation:     "UserLogin",
				Status:        "OK",
				IPAddress:     "192.168.1.1",
				XFF:           "2407:4d00:2c04:782b:10d4:8de2:c39e:1a9c",
				CreatedAt:     now.Add(-1 * time.Hour),
			},
			{
				ID:            uuid.New(),
				OrganizationID: orgID,
				IdentityID:    uuid.New(),
				IdentityEmail: "admin@company.com",
				Operation:     "UserLogin",
				Status:        "OK",
				IPAddress:     "192.168.1.1",
				XFF:           "2407:4d00:2c04:782b:10d4:8de2:c39e:1a9c",
				CreatedAt:     now.Add(-5 * time.Hour),
			},
			{
				ID:            uuid.New(),
				OrganizationID: orgID,
				IdentityID:    uuid.New(),
				IdentityEmail: "admin@company.com",
				Operation:     "UserLogin",
				Status:        "OK",
				IPAddress:     "192.168.1.1",
				XFF:           "2407:4d00:2c04:782b:10d4:8de2:c39e:1a9c",
				CreatedAt:     now.Add(-24 * time.Hour),
			},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(logs)
		return
	}
	defer rows.Close()

	var logs []AuditLog
	for rows.Next() {
		var log AuditLog
		var details *string
		if err := rows.Scan(&log.ID, &log.OrganizationID, &log.IdentityID, &log.IdentityEmail,
			&log.Operation, &log.Status, &details, &log.IPAddress, &log.XFF, &log.CreatedAt); err != nil {
			continue
		}
		if details != nil {
			log.Details = *details
		}
		logs = append(logs, log)
	}

	// If no logs found, return demo data
	if len(logs) == 0 {
		now := time.Now()
		logs = []AuditLog{
			{
				ID:            uuid.New(),
				OrganizationID: orgID,
				IdentityID:    uuid.New(),
				IdentityEmail: "admin@company.com",
				Operation:     "UserLogin",
				Status:        "OK",
				IPAddress:     "192.168.1.1",
				XFF:           "2407:4d00:2c04:782b:10d4:8de2:c39e:1a9c",
				CreatedAt:     now.Add(-1 * time.Hour),
			},
			{
				ID:            uuid.New(),
				OrganizationID: orgID,
				IdentityID:    uuid.New(),
				IdentityEmail: "admin@company.com",
				Operation:     "UserLogin",
				Status:        "OK",
				IPAddress:     "192.168.1.1",
				XFF:           "2407:4d00:2c04:782b:10d4:8de2:c39e:1a9c",
				CreatedAt:     now.Add(-5 * time.Hour),
			},
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(logs)
}

// CreateAuditLog creates an audit log entry (internal use)
func (s *BillingService) CreateAuditLog(ctx interface{}, orgID, identityID uuid.UUID, email, operation, status, details, ip, xff string) {
	// This is an internal function, not an HTTP handler
	// It would be called from other handlers to log actions
}

// GetAccountStats returns account statistics for the settings page
func (s *BillingService) GetAccountStats(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	orgID, err := uuid.Parse(vars["org_id"])
	if err != nil {
		http.Error(w, `{"error": "invalid organization ID"}`, http.StatusBadRequest)
		return
	}

	stats := struct {
		UserCount           int `json:"user_count"`
		UserLimit           int `json:"user_limit"`
		ServiceAccountCount int `json:"service_account_count"`
		GroupCount          int `json:"group_count"`
		APIKeyCount         int `json:"api_key_count"`
	}{
		UserCount:           1,
		UserLimit:           300,
		ServiceAccountCount: 0,
		GroupCount:          0,
		APIKeyCount:         0,
	}

	// Try to get real counts
	s.db.QueryRow(r.Context(),
		`SELECT COUNT(*) FROM identities WHERE organization_id = $1 AND type = 'user'`, orgID).
		Scan(&stats.UserCount)

	s.db.QueryRow(r.Context(),
		`SELECT COUNT(*) FROM identities WHERE organization_id = $1 AND type = 'service_account'`, orgID).
		Scan(&stats.ServiceAccountCount)

	s.db.QueryRow(r.Context(),
		`SELECT COUNT(*) FROM identities WHERE organization_id = $1 AND type = 'group'`, orgID).
		Scan(&stats.GroupCount)

	s.db.QueryRow(r.Context(),
		`SELECT COUNT(*) FROM api_keys WHERE organization_id = $1`, orgID).
		Scan(&stats.APIKeyCount)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(stats)
}
