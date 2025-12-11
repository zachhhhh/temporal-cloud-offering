package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/prometheus/common/model"
)

func main() {
	prometheusURL := os.Getenv("PROMETHEUS_URL")
	if prometheusURL == "" {
		prometheusURL = "http://localhost:9090"
	}

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://temporal:temporal@localhost:5432/billing?sslmode=disable"
	}

	interval := os.Getenv("COLLECTION_INTERVAL")
	if interval == "" {
		interval = "60s"
	}
	collectionInterval, _ := time.ParseDuration(interval)

	runOnce := strings.EqualFold(os.Getenv("RUN_ONCE"), "true")

	pool, err := pgxpool.New(context.Background(), dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer pool.Close()

	if err := ensureUsageSchema(pool); err != nil {
		log.Fatalf("Failed to ensure usage schema: %v", err)
	}

	collector := &UsageCollector{
		prometheusURL: prometheusURL,
		db:            pool,
		httpClient:    &http.Client{Timeout: 30 * time.Second},
	}

	if !runOnce {
		// Start HTTP server for health checks
		go func() {
			http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
				json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
			})
			http.HandleFunc("/metrics", func(w http.ResponseWriter, r *http.Request) {
				w.Write([]byte("# HELP usage_collector_runs Total collection runs\n"))
			})
			log.Println("Usage collector HTTP server listening on :8083")
			http.ListenAndServe(":8083", nil)
		}()
	}

	log.Printf("Starting usage collector (interval: %s, runOnce=%v)", collectionInterval, runOnce)

	// Initial collection
	collector.Collect(context.Background())

	if runOnce {
		log.Println("RUN_ONCE set, exiting after single collection")
		return
	}

	ticker := time.NewTicker(collectionInterval)
	defer ticker.Stop()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	for {
		select {
		case <-ticker.C:
			collector.Collect(context.Background())
		case <-quit:
			log.Println("Shutting down usage collector")
			return
		}
	}
}

type UsageCollector struct {
	prometheusURL string
	db            *pgxpool.Pool
	httpClient    *http.Client
}

// Collect gathers metrics from Prometheus and stores in billing DB
func (c *UsageCollector) Collect(ctx context.Context) {
	log.Println("Collecting usage metrics...")

	// Get all namespaces we're tracking
	namespaces, err := c.getTrackedNamespaces(ctx)
	if err != nil {
		log.Printf("Failed to get namespaces: %v", err)
		return
	}

	for _, ns := range namespaces {
		usage, err := c.collectNamespaceUsage(ctx, ns.TemporalNamespace)
		if err != nil {
			log.Printf("Failed to collect usage for namespace %s: %v", ns.TemporalNamespace, err)
			continue
		}

		err = c.storeUsage(ctx, ns.OrganizationID, ns.TemporalNamespace, usage)
		if err != nil {
			log.Printf("Failed to store usage for namespace %s: %v", ns.TemporalNamespace, err)
		}
	}

	// Aggregate hourly
	c.aggregateHourly(ctx)

	log.Println("Usage collection complete")
}

type TrackedNamespace struct {
	OrganizationID    uuid.UUID
	TemporalNamespace string
}

func (c *UsageCollector) getTrackedNamespaces(ctx context.Context) ([]TrackedNamespace, error) {
	rows, err := c.db.Query(ctx,
		`SELECT organization_id, temporal_namespace FROM namespaces WHERE status = 'active'`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var namespaces []TrackedNamespace
	for rows.Next() {
		var ns TrackedNamespace
		if err := rows.Scan(&ns.OrganizationID, &ns.TemporalNamespace); err != nil {
			continue
		}
		namespaces = append(namespaces, ns)
	}
	return namespaces, nil
}

type NamespaceUsage struct {
	ActionCount          int64
	ActiveStorageBytes   int64
	RetainedStorageBytes int64
	WorkflowStarted      int64
	ActivityStarted      int64
	TimerStarted         int64
	SignalSent           int64
}

func (c *UsageCollector) collectNamespaceUsage(ctx context.Context, namespace string) (*NamespaceUsage, error) {
	usage := &NamespaceUsage{}

	// Query workflow task completions (actions)
	workflowTasks, err := c.queryPrometheus(ctx, fmt.Sprintf(
		`sum(increase(workflow_task_completed_total{namespace="%s"}[1h]))`, namespace))
	if err == nil {
		usage.ActionCount += int64(workflowTasks)
	}

	// Query activity task completions
	activityTasks, err := c.queryPrometheus(ctx, fmt.Sprintf(
		`sum(increase(activity_task_completed_total{namespace="%s"}[1h]))`, namespace))
	if err == nil {
		usage.ActionCount += int64(activityTasks)
		usage.ActivityStarted = int64(activityTasks)
	}

	// Query workflow started
	workflowStarted, err := c.queryPrometheus(ctx, fmt.Sprintf(
		`sum(increase(workflow_started_total{namespace="%s"}[1h]))`, namespace))
	if err == nil {
		usage.WorkflowStarted = int64(workflowStarted)
	}

	// Query timer started
	timerStarted, err := c.queryPrometheus(ctx, fmt.Sprintf(
		`sum(increase(timer_started_total{namespace="%s"}[1h]))`, namespace))
	if err == nil {
		usage.TimerStarted = int64(timerStarted)
		usage.ActionCount += int64(timerStarted)
	}

	// Query signal sent
	signalSent, err := c.queryPrometheus(ctx, fmt.Sprintf(
		`sum(increase(signal_sent_total{namespace="%s"}[1h]))`, namespace))
	if err == nil {
		usage.SignalSent = int64(signalSent)
		usage.ActionCount += int64(signalSent)
	}

	// Query history size (active storage)
	historySize, err := c.queryPrometheus(ctx, fmt.Sprintf(
		`sum(history_size_bytes{namespace="%s"})`, namespace))
	if err == nil {
		usage.ActiveStorageBytes = int64(historySize)
	}

	// Query retained storage size if metric exists (best-effort)
	retainedSize, err := c.queryPrometheus(ctx, fmt.Sprintf(
		`sum(history_size_retained_bytes{namespace="%s"})`, namespace))
	if err == nil && retainedSize > 0 {
		usage.RetainedStorageBytes = int64(retainedSize)
	}

	return usage, nil
}

func (c *UsageCollector) queryPrometheus(ctx context.Context, query string) (float64, error) {
	url := fmt.Sprintf("%s/api/v1/query?query=%s", c.prometheusURL, query)

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return 0, err
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	var result struct {
		Status string `json:"status"`
		Data   struct {
			ResultType string `json:"resultType"`
			Result     []struct {
				Metric model.Metric     `json:"metric"`
				Value  model.SamplePair `json:"value"`
			} `json:"result"`
		} `json:"data"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return 0, err
	}

	if result.Status != "success" || len(result.Data.Result) == 0 {
		return 0, nil
	}

	return float64(result.Data.Result[0].Value.Value), nil
}

func (c *UsageCollector) storeUsage(ctx context.Context, orgID uuid.UUID, namespace string, usage *NamespaceUsage) error {
	_, err := c.db.Exec(ctx,
		`INSERT INTO usage_records (organization_id, namespace_id, recorded_at, action_count, 
		 active_storage_bytes, retained_storage_bytes, workflow_started, activity_started, 
		 timer_started, signal_sent)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
		orgID, namespace, time.Now(), usage.ActionCount, usage.ActiveStorageBytes,
		usage.RetainedStorageBytes, usage.WorkflowStarted, usage.ActivityStarted,
		usage.TimerStarted, usage.SignalSent)
	return err
}

func (c *UsageCollector) aggregateHourly(ctx context.Context) {
	// Aggregate raw records into hourly summaries
	now := time.Now().UTC()
	hourStart := time.Date(now.Year(), now.Month(), now.Day(), now.Hour()-1, 0, 0, 0, time.UTC)
	hourEnd := hourStart.Add(time.Hour)

	_, err := c.db.Exec(ctx, `
		INSERT INTO usage_aggregates (organization_id, namespace_id, period_start, period_end, 
		                              total_actions, active_storage_gbh, retained_storage_gbh)
		SELECT 
			organization_id,
			namespace_id,
			$1 as period_start,
			$2 as period_end,
			SUM(action_count) as total_actions,
			SUM(active_storage_bytes) / 1073741824.0 as active_storage_gbh,
			SUM(retained_storage_bytes) / 1073741824.0 as retained_storage_gbh
		FROM usage_records
		WHERE recorded_at >= $1 AND recorded_at < $2
		GROUP BY organization_id, namespace_id
		ON CONFLICT DO NOTHING`,
		hourStart, hourEnd)

	if err != nil {
		log.Printf("Failed to aggregate hourly usage: %v", err)
	}
}

// ensureUsageSchema creates usage tables if they do not exist. It does not touch billing or Temporal tables.
func ensureUsageSchema(pool *pgxpool.Pool) error {
	ctx := context.Background()
	stmts := []string{
		`CREATE EXTENSION IF NOT EXISTS "pgcrypto";`,
		`CREATE TABLE IF NOT EXISTS usage_records (
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			organization_id UUID NOT NULL,
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
			id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
			organization_id UUID NOT NULL,
			namespace_id VARCHAR(255),
			period_start TIMESTAMPTZ NOT NULL,
			period_end TIMESTAMPTZ NOT NULL,
			total_actions BIGINT DEFAULT 0,
			active_storage_gbh DECIMAL(20,6) DEFAULT 0,
			retained_storage_gbh DECIMAL(20,6) DEFAULT 0,
			created_at TIMESTAMPTZ DEFAULT NOW()
		);`,
	}
	for _, stmt := range stmts {
		if _, err := pool.Exec(ctx, stmt); err != nil {
			return fmt.Errorf("failed to ensure usage tables: %w", err)
		}
	}
	return nil
}
