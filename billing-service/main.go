package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/cors"
	"github.com/stripe/stripe-go/v76"
)

func main() {
	// Initialize Stripe
	stripe.Key = os.Getenv("STRIPE_SECRET_KEY")

	// Connect to database
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://temporal:temporal@localhost:5432/billing?sslmode=disable"
	}

	pool, err := pgxpool.New(context.Background(), dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer pool.Close()

	// Create service
	svc := NewBillingService(pool)

	// Create auth middleware
	authMiddleware := NewAuthMiddleware(pool)

	// Setup router
	r := mux.NewRouter()

	// Health check (no auth)
	r.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "ok", "service": "billing"})
	}).Methods("GET")

	// Metrics endpoint (no auth)
	r.HandleFunc("/metrics", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("# HELP billing_requests_total Total billing requests\n"))
		w.Write([]byte("# TYPE billing_requests_total counter\n"))
		w.Write([]byte("billing_requests_total 0\n"))
	}).Methods("GET")

	// Stripe webhook (no auth - uses Stripe signature verification)
	r.HandleFunc("/webhooks/stripe", svc.HandleStripeWebhook).Methods("POST")

	// API routes (with optional auth based on environment)
	api := r.PathPrefix("/api/v1").Subrouter()

	// Enable auth in production
	if os.Getenv("ENABLE_AUTH") == "true" {
		api.Use(authMiddleware.Authenticate)
	}

	// Organization endpoints
	api.HandleFunc("/organizations", svc.CreateOrganization).Methods("POST")
	api.HandleFunc("/organizations/{id}", svc.GetOrganization).Methods("GET")

	// Subscription endpoints
	api.HandleFunc("/organizations/{org_id}/subscription", svc.GetSubscription).Methods("GET")
	api.HandleFunc("/organizations/{org_id}/subscription", svc.UpdateSubscription).Methods("PUT")

	// Usage endpoints
	api.HandleFunc("/organizations/{org_id}/usage", svc.GetUsage).Methods("GET")
	api.HandleFunc("/organizations/{org_id}/usage/current", svc.GetCurrentUsage).Methods("GET")

	// Invoice endpoints
	api.HandleFunc("/organizations/{org_id}/invoices", svc.ListInvoices).Methods("GET")
	api.HandleFunc("/invoices/{id}", svc.GetInvoice).Methods("GET")

	// Namespace endpoints
	api.HandleFunc("/organizations/{org_id}/namespaces", svc.ListNamespaces).Methods("GET")
	api.HandleFunc("/organizations/{org_id}/namespaces", svc.CreateNamespace).Methods("POST")

	// API Key management endpoints
	api.HandleFunc("/organizations/{org_id}/api-keys", svc.ListAPIKeys).Methods("GET")
	api.HandleFunc("/organizations/{org_id}/api-keys", svc.CreateAPIKey).Methods("POST")
	api.HandleFunc("/api-keys/{key_id}", svc.DeleteAPIKey).Methods("DELETE")

	// CORS configuration
	c := cors.New(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Authorization", "Content-Type", "X-API-Key"},
		AllowCredentials: true,
	})

	handler := c.Handler(r)

	// Start server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8082"
	}

	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      handler,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
	}

	// Graceful shutdown
	go func() {
		log.Printf("Billing service listening on port %s", port)
		if err := srv.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatalf("Server error: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	srv.Shutdown(ctx)
	log.Println("Server shutdown complete")
}
