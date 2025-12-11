package bootstrap

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

// RunMigrations applies idempotent schema required for the billing service.
// This intentionally mirrors deploy/init-db.sql but uses IF NOT EXISTS so it
// can be safely run on start without touching upstream Temporal tables.
func RunMigrations(pool *pgxpool.Pool) error {
	ctx := context.Background()

	statements := []string{
		`CREATE EXTENSION IF NOT EXISTS "pgcrypto";`,
		`CREATE TABLE IF NOT EXISTS organizations (
			id UUID PRIMARY KEY,
			name VARCHAR(255) NOT NULL,
			slug VARCHAR(255) UNIQUE NOT NULL,
			stripe_customer_id VARCHAR(255),
			created_at TIMESTAMPTZ DEFAULT NOW(),
			updated_at TIMESTAMPTZ DEFAULT NOW()
		);`,
		`CREATE TABLE IF NOT EXISTS subscriptions (
			id UUID PRIMARY KEY,
			organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
			stripe_subscription_id VARCHAR(255),
			plan VARCHAR(50) NOT NULL DEFAULT 'free',
			status VARCHAR(50) NOT NULL DEFAULT 'active',
			actions_included BIGINT DEFAULT 100000,
			active_storage_gb DECIMAL(10,2) DEFAULT 0.1,
			retained_storage_gb DECIMAL(10,2) DEFAULT 4,
			current_period_start TIMESTAMPTZ,
			current_period_end TIMESTAMPTZ,
			created_at TIMESTAMPTZ DEFAULT NOW(),
			updated_at TIMESTAMPTZ DEFAULT NOW()
		);`,
		`CREATE TABLE IF NOT EXISTS namespaces (
			id UUID PRIMARY KEY,
			organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
			name VARCHAR(255) NOT NULL,
			temporal_namespace VARCHAR(255) UNIQUE NOT NULL,
			region VARCHAR(50) DEFAULT 'us-east-1',
			status VARCHAR(50) DEFAULT 'provisioning',
			retention_days INT DEFAULT 7,
			created_at TIMESTAMPTZ DEFAULT NOW(),
			updated_at TIMESTAMPTZ DEFAULT NOW()
		);`,
		`CREATE TABLE IF NOT EXISTS usage_records (
			id UUID PRIMARY KEY,
			organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
			namespace_id VARCHAR(255) NOT NULL,
			recorded_at TIMESTAMPTZ NOT NULL,
			action_count BIGINT DEFAULT 0,
			active_storage_bytes BIGINT DEFAULT 0,
			retained_storage_bytes BIGINT DEFAULT 0,
			workflow_started BIGINT DEFAULT 0,
			activity_started BIGINT DEFAULT 0,
			timer_started BIGINT DEFAULT 0,
			signal_sent BIGINT DEFAULT 0,
			created_at TIMESTAMPTZ DEFAULT NOW()
		);`,
		`CREATE TABLE IF NOT EXISTS usage_aggregates (
			id UUID PRIMARY KEY,
			organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
			namespace_id VARCHAR(255),
			period_start TIMESTAMPTZ NOT NULL,
			period_end TIMESTAMPTZ NOT NULL,
			total_actions BIGINT DEFAULT 0,
			active_storage_gbh DECIMAL(20,6) DEFAULT 0,
			retained_storage_gbh DECIMAL(20,6) DEFAULT 0,
			created_at TIMESTAMPTZ DEFAULT NOW()
		);`,
		`CREATE TABLE IF NOT EXISTS invoices (
			id UUID PRIMARY KEY,
			organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
			stripe_invoice_id VARCHAR(255),
			invoice_number VARCHAR(50) NOT NULL,
			period_start TIMESTAMPTZ NOT NULL,
			period_end TIMESTAMPTZ NOT NULL,
			subtotal_cents BIGINT DEFAULT 0,
			tax_cents BIGINT DEFAULT 0,
			total_cents BIGINT DEFAULT 0,
			status VARCHAR(50) DEFAULT 'draft',
			line_items JSONB,
			paid_at TIMESTAMPTZ,
			due_at TIMESTAMPTZ,
			created_at TIMESTAMPTZ DEFAULT NOW()
		);`,
		`CREATE TABLE IF NOT EXISTS credits (
			id UUID PRIMARY KEY,
			organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
			amount_cents BIGINT NOT NULL,
			remaining_cents BIGINT NOT NULL,
			description VARCHAR(255),
			expires_at TIMESTAMPTZ,
			created_at TIMESTAMPTZ DEFAULT NOW()
		);`,
		`CREATE TABLE IF NOT EXISTS api_keys (
			id UUID PRIMARY KEY,
			organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
			name VARCHAR(255) NOT NULL,
			key_hash VARCHAR(255) NOT NULL,
			key_prefix VARCHAR(20) NOT NULL,
			scopes TEXT[],
			expires_at TIMESTAMPTZ,
			last_used_at TIMESTAMPTZ,
			created_at TIMESTAMPTZ DEFAULT NOW()
		);`,
		`CREATE TABLE IF NOT EXISTS magic_links (
			email VARCHAR(255) PRIMARY KEY,
			token VARCHAR(255) NOT NULL,
			expires_at TIMESTAMPTZ NOT NULL,
			created_at TIMESTAMPTZ DEFAULT NOW()
		);`,
		`CREATE TABLE IF NOT EXISTS identities (
			id UUID PRIMARY KEY,
			organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
			email VARCHAR(255) NOT NULL,
			name VARCHAR(255),
			type VARCHAR(50) NOT NULL DEFAULT 'user',
			role VARCHAR(50) NOT NULL DEFAULT 'developer',
			status VARCHAR(50) NOT NULL DEFAULT 'pending',
			last_login_at TIMESTAMPTZ,
			created_at TIMESTAMPTZ DEFAULT NOW(),
			updated_at TIMESTAMPTZ DEFAULT NOW()
		);`,
		`CREATE TABLE IF NOT EXISTS audit_logs (
			id UUID PRIMARY KEY,
			organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
			identity_id UUID,
			identity_email VARCHAR(255),
			operation VARCHAR(255) NOT NULL,
			status VARCHAR(50) NOT NULL DEFAULT 'OK',
			details TEXT,
			ip_address VARCHAR(50),
			xff VARCHAR(255),
			created_at TIMESTAMPTZ DEFAULT NOW()
		);`,
	}

	for _, stmt := range statements {
		if _, err := pool.Exec(ctx, stmt); err != nil {
			return fmt.Errorf("migration failed: %w", err)
		}
	}

	indexes := []string{
		`CREATE INDEX IF NOT EXISTS idx_usage_org_time ON usage_records(organization_id, recorded_at);`,
		`CREATE INDEX IF NOT EXISTS idx_usage_namespace ON usage_records(namespace_id, recorded_at);`,
		`CREATE INDEX IF NOT EXISTS idx_aggregates_org_period ON usage_aggregates(organization_id, period_start);`,
		`CREATE INDEX IF NOT EXISTS idx_invoices_org ON invoices(organization_id, created_at);`,
		`CREATE INDEX IF NOT EXISTS idx_api_keys_org ON api_keys(organization_id);`,
		`CREATE INDEX IF NOT EXISTS idx_namespaces_org ON namespaces(organization_id);`,
		`CREATE INDEX IF NOT EXISTS idx_identities_org ON identities(organization_id);`,
		`CREATE INDEX IF NOT EXISTS idx_identities_type ON identities(organization_id, type);`,
		`CREATE INDEX IF NOT EXISTS idx_audit_logs_org ON audit_logs(organization_id, created_at);`,
	}

	for _, stmt := range indexes {
		// Ignore errors for indexes - they may fail if tables don't exist yet
		// or if indexes already exist
		pool.Exec(ctx, stmt)
	}

	// Add missing columns to existing tables (for upgrades)
	alterStatements := []string{
		`ALTER TABLE api_keys ADD COLUMN IF NOT EXISTS key_hash VARCHAR(255)`,
	}
	for _, stmt := range alterStatements {
		pool.Exec(ctx, stmt)
	}

	return nil
}
