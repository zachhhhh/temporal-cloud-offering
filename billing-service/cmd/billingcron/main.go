package main

import (
	"context"
	"log"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stripe/stripe-go/v76"
	"github.com/temporalio/temporal-cloud-offering/billing-service/internal/bootstrap"
)

// billingcron triggers monthly billing once. Intended to be run by a CronJob.
func main() {
	stripe.Key = os.Getenv("STRIPE_SECRET_KEY")

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://temporal:temporal@localhost:5432/billing?sslmode=disable"
	}

	pool, err := pgxpool.New(context.Background(), dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer pool.Close()

	if err := bootstrap.RunMigrations(pool); err != nil {
		log.Fatalf("Database migration failed: %v", err)
	}

	meter := NewUsageMeter(pool)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()

	if err := meter.RunMonthlyBilling(ctx); err != nil {
		log.Fatalf("Monthly billing failed: %v", err)
	}

	log.Printf("Monthly billing completed successfully")
}
