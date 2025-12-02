package chaos_test

import (
	"context"
	"fmt"
	"os/exec"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"go.temporal.io/sdk/client"
	"go.temporal.io/sdk/temporal"
	"go.temporal.io/sdk/worker"
	"go.temporal.io/sdk/workflow"
)

const (
	temporalAddress = "localhost:7233"
	taskQueue       = "chaos-test-queue"
)

// LongRunningWorkflow - workflow that survives restarts
func LongRunningWorkflow(ctx workflow.Context, steps int) ([]string, error) {
	var results []string

	for i := 0; i < steps; i++ {
		// Each step is a checkpoint
		workflow.Sleep(ctx, 500*time.Millisecond)
		results = append(results, fmt.Sprintf("step-%d-complete", i))

		// Call activity
		ao := workflow.ActivityOptions{
			StartToCloseTimeout: 30 * time.Second,
			RetryPolicy: &temporal.RetryPolicy{
				MaximumAttempts: 10,
			},
		}
		ctx := workflow.WithActivityOptions(ctx, ao)

		var actResult string
		err := workflow.ExecuteActivity(ctx, ChaosActivity, i).Get(ctx, &actResult)
		if err != nil {
			return results, err
		}
		results = append(results, actResult)
	}

	return results, nil
}

func ChaosActivity(ctx context.Context, step int) (string, error) {
	// Simulate work
	time.Sleep(200 * time.Millisecond)
	return fmt.Sprintf("activity-%d-done", step), nil
}

// TestWorkerFailover - test workflow continues after worker restart
func TestWorkerFailover(t *testing.T) {
	c, err := client.Dial(client.Options{HostPort: temporalAddress})
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer c.Close()

	// Start first worker
	w1 := worker.New(c, taskQueue, worker.Options{})
	w1.RegisterWorkflow(LongRunningWorkflow)
	w1.RegisterActivity(ChaosActivity)
	if err := w1.Start(); err != nil {
		t.Fatalf("Failed to start worker: %v", err)
	}

	// Start workflow
	workflowID := fmt.Sprintf("chaos-failover-%d", time.Now().UnixNano())
	we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:        workflowID,
		TaskQueue: taskQueue,
	}, LongRunningWorkflow, 5)
	if err != nil {
		t.Fatalf("Failed to start workflow: %v", err)
	}

	t.Logf("Started workflow: %s", workflowID)

	// Wait for some progress
	time.Sleep(2 * time.Second)

	// Stop first worker (simulating crash)
	t.Log("Stopping worker 1 (simulating crash)...")
	w1.Stop()

	// Start second worker
	t.Log("Starting worker 2...")
	w2 := worker.New(c, taskQueue, worker.Options{})
	w2.RegisterWorkflow(LongRunningWorkflow)
	w2.RegisterActivity(ChaosActivity)
	if err := w2.Start(); err != nil {
		t.Fatalf("Failed to start worker 2: %v", err)
	}
	defer w2.Stop()

	// Wait for workflow to complete
	var results []string
	err = we.Get(context.Background(), &results)
	if err != nil {
		t.Fatalf("Workflow failed: %v", err)
	}

	t.Logf("✅ Workflow completed after failover with %d results", len(results))
	for _, r := range results {
		t.Logf("  - %s", r)
	}
}

// TestDatabaseReconnect - test recovery after database blip
func TestDatabaseReconnect(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping database reconnect test in short mode")
	}

	c, err := client.Dial(client.Options{HostPort: temporalAddress})
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer c.Close()

	w := worker.New(c, taskQueue, worker.Options{})
	w.RegisterWorkflow(LongRunningWorkflow)
	w.RegisterActivity(ChaosActivity)
	if err := w.Start(); err != nil {
		t.Fatalf("Failed to start worker: %v", err)
	}
	defer w.Stop()

	// Start workflow
	workflowID := fmt.Sprintf("chaos-db-%d", time.Now().UnixNano())
	we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:        workflowID,
		TaskQueue: taskQueue,
	}, LongRunningWorkflow, 10)
	if err != nil {
		t.Fatalf("Failed to start workflow: %v", err)
	}

	// Wait for some progress
	time.Sleep(2 * time.Second)

	// Pause PostgreSQL briefly (simulating network blip)
	t.Log("Pausing PostgreSQL for 5 seconds...")
	exec.Command("docker", "pause", "temporal-postgres").Run()
	time.Sleep(5 * time.Second)
	exec.Command("docker", "unpause", "temporal-postgres").Run()
	t.Log("PostgreSQL resumed")

	// Workflow should still complete
	var results []string
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	err = we.Get(ctx, &results)
	if err != nil {
		t.Fatalf("Workflow failed after DB pause: %v", err)
	}

	t.Logf("✅ Workflow completed after database pause with %d results", len(results))
}

// TestConcurrentWorkflowsUnderStress - many workflows during chaos
func TestConcurrentWorkflowsUnderStress(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping stress test in short mode")
	}

	c, err := client.Dial(client.Options{HostPort: temporalAddress})
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer c.Close()

	w := worker.New(c, taskQueue, worker.Options{
		MaxConcurrentWorkflowTaskPollers: 20,
	})
	w.RegisterWorkflow(LongRunningWorkflow)
	w.RegisterActivity(ChaosActivity)
	if err := w.Start(); err != nil {
		t.Fatalf("Failed to start worker: %v", err)
	}
	defer w.Stop()

	// Start many workflows
	numWorkflows := 50
	var wg sync.WaitGroup
	var successCount, failureCount int64

	for i := 0; i < numWorkflows; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()

			workflowID := fmt.Sprintf("stress-%d-%d", time.Now().UnixNano(), id)
			we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
				ID:        workflowID,
				TaskQueue: taskQueue,
			}, LongRunningWorkflow, 3)

			if err != nil {
				atomic.AddInt64(&failureCount, 1)
				return
			}

			var results []string
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
			defer cancel()

			if err := we.Get(ctx, &results); err != nil {
				atomic.AddInt64(&failureCount, 1)
				return
			}

			atomic.AddInt64(&successCount, 1)
		}(i)
	}

	wg.Wait()

	t.Logf("Stress Test Results:")
	t.Logf("  Total: %d", numWorkflows)
	t.Logf("  Success: %d", successCount)
	t.Logf("  Failures: %d", failureCount)

	if failureCount > 0 {
		t.Errorf("Expected 0 failures, got %d", failureCount)
	}
}

// TestTemporalServerRestart - test workflow recovery after server restart
func TestTemporalServerRestart(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping server restart test in short mode")
	}

	c, err := client.Dial(client.Options{HostPort: temporalAddress})
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer c.Close()

	w := worker.New(c, taskQueue, worker.Options{})
	w.RegisterWorkflow(LongRunningWorkflow)
	w.RegisterActivity(ChaosActivity)
	if err := w.Start(); err != nil {
		t.Fatalf("Failed to start worker: %v", err)
	}
	defer w.Stop()

	// Start a long workflow
	workflowID := fmt.Sprintf("chaos-restart-%d", time.Now().UnixNano())
	we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:        workflowID,
		TaskQueue: taskQueue,
	}, LongRunningWorkflow, 10)
	if err != nil {
		t.Fatalf("Failed to start workflow: %v", err)
	}

	t.Logf("Started workflow: %s", workflowID)

	// Wait for progress
	time.Sleep(3 * time.Second)

	// Restart Temporal server
	t.Log("Restarting Temporal server...")
	exec.Command("docker", "restart", "temporal-server").Run()

	// Wait for server to come back
	time.Sleep(10 * time.Second)

	// Reconnect client
	c2, err := client.Dial(client.Options{HostPort: temporalAddress})
	if err != nil {
		t.Fatalf("Failed to reconnect: %v", err)
	}
	defer c2.Close()

	// Get workflow result
	we2 := c2.GetWorkflow(context.Background(), workflowID, "")
	_ = we // Silence unused variable warning

	var results []string
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()

	err = we2.Get(ctx, &results)
	if err != nil {
		t.Fatalf("Workflow failed after server restart: %v", err)
	}

	t.Logf("✅ Workflow completed after server restart with %d results", len(results))
}
