package load_test

import (
	"context"
	"fmt"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"go.temporal.io/sdk/client"
	"go.temporal.io/sdk/worker"
	"go.temporal.io/sdk/workflow"
)

const (
	temporalAddress = "localhost:7233"
	taskQueue       = "load-test-queue"
)

// LoadTestWorkflow - simple workflow for load testing
func LoadTestWorkflow(ctx workflow.Context, id int) (string, error) {
	// Simulate some work
	workflow.Sleep(ctx, 100*time.Millisecond)
	return fmt.Sprintf("completed-%d", id), nil
}

// LoadTestResult holds load test metrics
type LoadTestResult struct {
	TotalWorkflows   int64
	SuccessCount     int64
	FailureCount     int64
	Duration         time.Duration
	WorkflowsPerSec  float64
	AvgLatencyMs     float64
	P99LatencyMs     float64
	MaxConcurrent    int64
}

func TestLoadBasic(t *testing.T) {
	c, err := client.Dial(client.Options{HostPort: temporalAddress})
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer c.Close()

	w := worker.New(c, taskQueue, worker.Options{
		MaxConcurrentWorkflowTaskPollers: 10,
	})
	w.RegisterWorkflow(LoadTestWorkflow)
	if err := w.Start(); err != nil {
		t.Fatalf("Failed to start worker: %v", err)
	}
	defer w.Stop()

	// Run load test
	result := runLoadTest(t, c, 100, 10) // 100 workflows, 10 concurrent

	t.Logf("Load Test Results:")
	t.Logf("  Total Workflows: %d", result.TotalWorkflows)
	t.Logf("  Success: %d, Failures: %d", result.SuccessCount, result.FailureCount)
	t.Logf("  Duration: %v", result.Duration)
	t.Logf("  Throughput: %.2f workflows/sec", result.WorkflowsPerSec)
	t.Logf("  Avg Latency: %.2f ms", result.AvgLatencyMs)

	// Assertions
	if result.FailureCount > 0 {
		t.Errorf("Expected 0 failures, got %d", result.FailureCount)
	}
	if result.WorkflowsPerSec < 5 {
		t.Errorf("Throughput too low: %.2f workflows/sec", result.WorkflowsPerSec)
	}
}

func TestLoadHigh(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping high load test in short mode")
	}

	c, err := client.Dial(client.Options{HostPort: temporalAddress})
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer c.Close()

	w := worker.New(c, taskQueue, worker.Options{
		MaxConcurrentWorkflowTaskPollers: 20,
	})
	w.RegisterWorkflow(LoadTestWorkflow)
	if err := w.Start(); err != nil {
		t.Fatalf("Failed to start worker: %v", err)
	}
	defer w.Stop()

	// High load test
	result := runLoadTest(t, c, 1000, 50) // 1000 workflows, 50 concurrent

	t.Logf("High Load Test Results:")
	t.Logf("  Total Workflows: %d", result.TotalWorkflows)
	t.Logf("  Success: %d, Failures: %d", result.SuccessCount, result.FailureCount)
	t.Logf("  Duration: %v", result.Duration)
	t.Logf("  Throughput: %.2f workflows/sec", result.WorkflowsPerSec)

	if float64(result.FailureCount)/float64(result.TotalWorkflows) > 0.01 {
		t.Errorf("Failure rate too high: %.2f%%", float64(result.FailureCount)/float64(result.TotalWorkflows)*100)
	}
}

func TestLoadSustained(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping sustained load test in short mode")
	}

	c, err := client.Dial(client.Options{HostPort: temporalAddress})
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer c.Close()

	w := worker.New(c, taskQueue, worker.Options{
		MaxConcurrentWorkflowTaskPollers: 10,
	})
	w.RegisterWorkflow(LoadTestWorkflow)
	if err := w.Start(); err != nil {
		t.Fatalf("Failed to start worker: %v", err)
	}
	defer w.Stop()

	// Sustained load for 1 minute
	duration := 1 * time.Minute
	rate := 10 // workflows per second

	result := runSustainedLoad(t, c, duration, rate)

	t.Logf("Sustained Load Test Results:")
	t.Logf("  Duration: %v", result.Duration)
	t.Logf("  Total Workflows: %d", result.TotalWorkflows)
	t.Logf("  Success: %d, Failures: %d", result.SuccessCount, result.FailureCount)
	t.Logf("  Actual Rate: %.2f workflows/sec", result.WorkflowsPerSec)
}

func runLoadTest(t *testing.T, c client.Client, total, concurrent int) LoadTestResult {
	var (
		successCount int64
		failureCount int64
		totalLatency int64
		wg           sync.WaitGroup
		sem          = make(chan struct{}, concurrent)
	)

	start := time.Now()

	for i := 0; i < total; i++ {
		wg.Add(1)
		sem <- struct{}{}

		go func(id int) {
			defer wg.Done()
			defer func() { <-sem }()

			workflowStart := time.Now()
			workflowID := fmt.Sprintf("load-test-%d-%d", start.UnixNano(), id)

			we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
				ID:        workflowID,
				TaskQueue: taskQueue,
			}, LoadTestWorkflow, id)

			if err != nil {
				atomic.AddInt64(&failureCount, 1)
				return
			}

			var result string
			if err := we.Get(context.Background(), &result); err != nil {
				atomic.AddInt64(&failureCount, 1)
				return
			}

			latency := time.Since(workflowStart).Milliseconds()
			atomic.AddInt64(&totalLatency, latency)
			atomic.AddInt64(&successCount, 1)
		}(i)
	}

	wg.Wait()
	duration := time.Since(start)

	return LoadTestResult{
		TotalWorkflows:  int64(total),
		SuccessCount:    successCount,
		FailureCount:    failureCount,
		Duration:        duration,
		WorkflowsPerSec: float64(total) / duration.Seconds(),
		AvgLatencyMs:    float64(totalLatency) / float64(successCount),
	}
}

func runSustainedLoad(t *testing.T, c client.Client, duration time.Duration, rate int) LoadTestResult {
	var (
		successCount int64
		failureCount int64
		wg           sync.WaitGroup
	)

	start := time.Now()
	ticker := time.NewTicker(time.Second / time.Duration(rate))
	defer ticker.Stop()

	timeout := time.After(duration)
	id := 0

loop:
	for {
		select {
		case <-timeout:
			break loop
		case <-ticker.C:
			wg.Add(1)
			go func(workflowID int) {
				defer wg.Done()

				we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
					ID:        fmt.Sprintf("sustained-%d-%d", start.UnixNano(), workflowID),
					TaskQueue: taskQueue,
				}, LoadTestWorkflow, workflowID)

				if err != nil {
					atomic.AddInt64(&failureCount, 1)
					return
				}

				var result string
				if err := we.Get(context.Background(), &result); err != nil {
					atomic.AddInt64(&failureCount, 1)
					return
				}

				atomic.AddInt64(&successCount, 1)
			}(id)
			id++
		}
	}

	wg.Wait()
	elapsed := time.Since(start)

	return LoadTestResult{
		TotalWorkflows:  int64(id),
		SuccessCount:    successCount,
		FailureCount:    failureCount,
		Duration:        elapsed,
		WorkflowsPerSec: float64(id) / elapsed.Seconds(),
	}
}
