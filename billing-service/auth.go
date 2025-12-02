package main

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// APIKey represents an API key for authentication
type APIKey struct {
	ID             uuid.UUID  `json:"id"`
	OrganizationID uuid.UUID  `json:"organization_id"`
	Name           string     `json:"name"`
	KeyPrefix      string     `json:"key_prefix"`
	KeyHash        string     `json:"-"`
	Scopes         []string   `json:"scopes"`
	ExpiresAt      *time.Time `json:"expires_at,omitempty"`
	LastUsedAt     *time.Time `json:"last_used_at,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
}

// AuthMiddleware provides API key authentication
type AuthMiddleware struct {
	db *pgxpool.Pool
}

// NewAuthMiddleware creates a new auth middleware
func NewAuthMiddleware(db *pgxpool.Pool) *AuthMiddleware {
	return &AuthMiddleware{db: db}
}

// Authenticate validates the API key and returns the organization ID
func (m *AuthMiddleware) Authenticate(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Skip auth for health checks and public endpoints
		if r.URL.Path == "/health" || r.URL.Path == "/metrics" || r.URL.Path == "/webhooks/stripe" {
			next.ServeHTTP(w, r)
			return
		}

		// Get API key from header
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			// Also check X-API-Key header
			authHeader = r.Header.Get("X-API-Key")
		}

		if authHeader == "" {
			http.Error(w, `{"error": "missing API key"}`, http.StatusUnauthorized)
			return
		}

		// Parse Bearer token or raw key
		apiKey := authHeader
		if strings.HasPrefix(authHeader, "Bearer ") {
			apiKey = strings.TrimPrefix(authHeader, "Bearer ")
		}

		// Validate API key
		orgID, err := m.validateAPIKey(r.Context(), apiKey)
		if err != nil {
			http.Error(w, `{"error": "invalid API key"}`, http.StatusUnauthorized)
			return
		}

		// Add organization ID to context
		ctx := context.WithValue(r.Context(), "organization_id", orgID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// validateAPIKey checks if the API key is valid and returns the organization ID
func (m *AuthMiddleware) validateAPIKey(ctx context.Context, key string) (uuid.UUID, error) {
	// API key format: tc_live_<prefix>_<secret>
	parts := strings.Split(key, "_")
	if len(parts) < 4 || parts[0] != "tc" {
		return uuid.Nil, fmt.Errorf("invalid key format")
	}

	prefix := parts[2]
	keyHash := hashAPIKey(key)

	var orgID uuid.UUID
	var expiresAt *time.Time

	err := m.db.QueryRow(ctx,
		`SELECT organization_id, expires_at FROM api_keys WHERE key_prefix = $1 AND key_hash = $2`,
		prefix, keyHash).Scan(&orgID, &expiresAt)
	if err != nil {
		return uuid.Nil, err
	}

	// Check expiration
	if expiresAt != nil && expiresAt.Before(time.Now()) {
		return uuid.Nil, fmt.Errorf("key expired")
	}

	// Update last used
	go func() {
		m.db.Exec(context.Background(),
			`UPDATE api_keys SET last_used_at = NOW() WHERE key_prefix = $1`, prefix)
	}()

	return orgID, nil
}

// GenerateAPIKey creates a new API key for an organization
func GenerateAPIKey(db *pgxpool.Pool, orgID uuid.UUID, name string, scopes []string, expiresAt *time.Time) (string, *APIKey, error) {
	// Generate random bytes for the key
	randomBytes := make([]byte, 32)
	if _, err := rand.Read(randomBytes); err != nil {
		return "", nil, err
	}

	// Create key components
	prefix := hex.EncodeToString(randomBytes[:4])
	secret := hex.EncodeToString(randomBytes[4:])
	fullKey := fmt.Sprintf("tc_live_%s_%s", prefix, secret)
	keyHash := hashAPIKey(fullKey)

	apiKey := &APIKey{
		ID:             uuid.New(),
		OrganizationID: orgID,
		Name:           name,
		KeyPrefix:      prefix,
		KeyHash:        keyHash,
		Scopes:         scopes,
		ExpiresAt:      expiresAt,
		CreatedAt:      time.Now(),
	}

	_, err := db.Exec(context.Background(),
		`INSERT INTO api_keys (id, organization_id, name, key_prefix, key_hash, scopes, expires_at, created_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		apiKey.ID, apiKey.OrganizationID, apiKey.Name, apiKey.KeyPrefix, apiKey.KeyHash, apiKey.Scopes, apiKey.ExpiresAt, apiKey.CreatedAt)
	if err != nil {
		return "", nil, err
	}

	return fullKey, apiKey, nil
}

// hashAPIKey creates a SHA-256 hash of the API key
func hashAPIKey(key string) string {
	hash := sha256.Sum256([]byte(key))
	return hex.EncodeToString(hash[:])
}

// GetOrganizationFromContext extracts the organization ID from the request context
func GetOrganizationFromContext(ctx context.Context) uuid.UUID {
	orgID, ok := ctx.Value("organization_id").(uuid.UUID)
	if !ok {
		return uuid.Nil
	}
	return orgID
}
