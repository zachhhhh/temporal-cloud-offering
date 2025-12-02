package temporal_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.temporal.io/sdk/client"
	"go.temporal.io/sdk/temporal"
	"go.temporal.io/sdk/worker"
	"go.temporal.io/sdk/workflow"
)

const (
	temporalAddress = "localhost:7233"
	taskQueue       = "test-task-queue"
)

// ============================================
// Test Workflows
// ============================================

// SimpleWorkflow - basic workflow that returns a greeting
func SimpleWorkflow(ctx workflow.Context, name string) (string, error) {
	return fmt.Sprintf("Hello, %s!", name), nil
}

// ActivityWorkflow - workflow that calls an activity
func ActivityWorkflow(ctx workflow.Context, input string) (string, error) {
	ao := workflow.ActivityOptions{
		StartToCloseTimeout: 10 * time.Second,
		RetryPolicy: &temporal.RetryPolicy{
			MaximumAttempts: 3,
		},
	}
	ctx = workflow.WithActivityOptions(ctx, ao)

	var result string
	err := workflow.ExecuteActivity(ctx, ProcessActivity, input).Get(ctx, &result)
	return result, err
}

// SignalWorkflow - workflow that waits for signals
func SignalWorkflow(ctx workflow.Context) ([]string, error) {
	var signals []string
	signalChan := workflow.GetSignalChannel(ctx, "test-signal")

	// Wait for up to 3 signals or timeout
	for i := 0; i < 3; i++ {
		selector := workflow.NewSelector(ctx)

		selector.AddReceive(signalChan, func(c workflow.ReceiveChannel, more bool) {
			var signal string
			c.Receive(ctx, &signal)
			signals = append(signals, signal)
		})

		timerFuture := workflow.NewTimer(ctx, 5*time.Second)
		selector.AddFuture(timerFuture, func(f workflow.Future) {
			// Timeout - stop waiting
		})

		selector.Select(ctx)

		if len(signals) == 0 && i == 0 {
			// First iteration timeout means no signals coming
			break
		}
	}

	return signals, nil
}

// QueryWorkflow - workflow that supports queries
func QueryWorkflow(ctx workflow.Context) error {
	status := "started"

	// Register query handler
	err := workflow.SetQueryHandler(ctx, "status", func() (string, error) {
		return status, nil
	})
	if err != nil {
		return err
	}

	// Simulate work
	workflow.Sleep(ctx, 2*time.Second)
	status = "processing"

	workflow.Sleep(ctx, 2*time.Second)
	status = "completed"

	return nil
}

// ChildWorkflow - parent workflow that starts child workflows
func ParentWorkflow(ctx workflow.Context, count int) ([]string, error) {
	var results []string

	for i := 0; i < count; i++ {
		cwo := workflow.ChildWorkflowOptions{
			WorkflowID: fmt.Sprintf("child-%d", i),
		}
		ctx := workflow.WithChildOptions(ctx, cwo)

		var result string
		err := workflow.ExecuteChildWorkflow(ctx, ChildWorkflow, i).Get(ctx, &result)
		if err != nil {
			return nil, err
		}
		results = append(results, result)
	}

	return results, nil
}

func ChildWorkflow(ctx workflow.Context, num int) (string, error) {
	return fmt.Sprintf("child-%d-done", num), nil
}

// TimerWorkflow - workflow with timers
func TimerWorkflow(ctx workflow.Context, durations []time.Duration) ([]string, error) {
	var events []string

	for i, d := range durations {
		events = append(events, fmt.Sprintf("timer-%d-started", i))
		workflow.Sleep(ctx, d)
		events = append(events, fmt.Sprintf("timer-%d-fired", i))
	}

	return events, nil
}

// RetryWorkflow - workflow with activity retries
func RetryWorkflow(ctx workflow.Context, failCount int) (string, error) {
	ao := workflow.ActivityOptions{
		StartToCloseTimeout: 10 * time.Second,
		RetryPolicy: &temporal.RetryPolicy{
			InitialInterval:    100 * time.Millisecond,
			BackoffCoefficient: 1.5,
			MaximumAttempts:    5,
		},
	}
	ctx = workflow.WithActivityOptions(ctx, ao)

	var result string
	err := workflow.ExecuteActivity(ctx, FlakeyActivity, failCount).Get(ctx, &result)
	return result, err
}

// ============================================
// Test Activities
// ============================================

func ProcessActivity(ctx context.Context, input string) (string, error) {
	return fmt.Sprintf("processed: %s", input), nil
}

var activityAttempts = make(map[string]int)

func FlakeyActivity(ctx context.Context, failCount int) (string, error) {
	key := fmt.Sprintf("flakey-%d", failCount)
	activityAttempts[key]++

	if activityAttempts[key] <= failCount {
		return "", fmt.Errorf("intentional failure %d/%d", activityAttempts[key], failCount)
	}

	return fmt.Sprintf("succeeded after %d attempts", activityAttempts[key]), nil
}

// ============================================
// Tests
// ============================================

func getClient(t *testing.T) client.Client {
	c, err := client.Dial(client.Options{
		HostPort: temporalAddress,
	})
	require.NoError(t, err, "Failed to connect to Temporal")
	return c
}

func startWorker(t *testing.T, c client.Client) worker.Worker {
	w := worker.New(c, taskQueue, worker.Options{})

	// Register workflows
	w.RegisterWorkflow(SimpleWorkflow)
	w.RegisterWorkflow(ActivityWorkflow)
	w.RegisterWorkflow(SignalWorkflow)
	w.RegisterWorkflow(QueryWorkflow)
	w.RegisterWorkflow(ParentWorkflow)
	w.RegisterWorkflow(ChildWorkflow)
	w.RegisterWorkflow(TimerWorkflow)
	w.RegisterWorkflow(RetryWorkflow)

	// Register activities
	w.RegisterActivity(ProcessActivity)
	w.RegisterActivity(FlakeyActivity)

	err := w.Start()
	require.NoError(t, err, "Failed to start worker")

	return w
}

func TestSimpleWorkflow(t *testing.T) {
	c := getClient(t)
	defer c.Close()

	w := startWorker(t, c)
	defer w.Stop()

	workflowID := fmt.Sprintf("test-simple-%d", time.Now().UnixNano())
	we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:        workflowID,
		TaskQueue: taskQueue,
	}, SimpleWorkflow, "World")
	require.NoError(t, err)

	var result string
	err = we.Get(context.Background(), &result)
	require.NoError(t, err)
	assert.Equal(t, "Hello, World!", result)

	t.Logf("✅ Simple workflow completed: %s", result)
}

func TestActivityWorkflow(t *testing.T) {
	c := getClient(t)
	defer c.Close()

	w := startWorker(t, c)
	defer w.Stop()

	workflowID := fmt.Sprintf("test-activity-%d", time.Now().UnixNano())
	we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:        workflowID,
		TaskQueue: taskQueue,
	}, ActivityWorkflow, "test-input")
	require.NoError(t, err)

	var result string
	err = we.Get(context.Background(), &result)
	require.NoError(t, err)
	assert.Equal(t, "processed: test-input", result)

	t.Logf("✅ Activity workflow completed: %s", result)
}

func TestSignalWorkflow(t *testing.T) {
	c := getClient(t)
	defer c.Close()

	w := startWorker(t, c)
	defer w.Stop()

	workflowID := fmt.Sprintf("test-signal-%d", time.Now().UnixNano())
	we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:        workflowID,
		TaskQueue: taskQueue,
	}, SignalWorkflow)
	require.NoError(t, err)

	// Send signals
	time.Sleep(500 * time.Millisecond)
	err = c.SignalWorkflow(context.Background(), workflowID, "", "test-signal", "signal-1")
	require.NoError(t, err)

	err = c.SignalWorkflow(context.Background(), workflowID, "", "test-signal", "signal-2")
	require.NoError(t, err)

	err = c.SignalWorkflow(context.Background(), workflowID, "", "test-signal", "signal-3")
	require.NoError(t, err)

	var result []string
	err = we.Get(context.Background(), &result)
	require.NoError(t, err)
	assert.Len(t, result, 3)
	assert.Contains(t, result, "signal-1")
	assert.Contains(t, result, "signal-2")
	assert.Contains(t, result, "signal-3")

	t.Logf("✅ Signal workflow received %d signals: %v", len(result), result)
}

func TestQueryWorkflow(t *testing.T) {
	c := getClient(t)
	defer c.Close()

	w := startWorker(t, c)
	defer w.Stop()

	workflowID := fmt.Sprintf("test-query-%d", time.Now().UnixNano())
	we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:        workflowID,
		TaskQueue: taskQueue,
	}, QueryWorkflow)
	require.NoError(t, err)

	// Query status during execution
	time.Sleep(1 * time.Second)
	resp, err := c.QueryWorkflow(context.Background(), workflowID, "", "status")
	require.NoError(t, err)

	var status string
	err = resp.Get(&status)
	require.NoError(t, err)
	t.Logf("Query result (early): %s", status)

	// Wait for completion
	err = we.Get(context.Background(), nil)
	require.NoError(t, err)

	// Query after completion
	resp, err = c.QueryWorkflow(context.Background(), workflowID, "", "status")
	require.NoError(t, err)
	err = resp.Get(&status)
	require.NoError(t, err)
	assert.Equal(t, "completed", status)

	t.Logf("✅ Query workflow final status: %s", status)
}

func TestChildWorkflows(t *testing.T) {
	c := getClient(t)
	defer c.Close()

	w := startWorker(t, c)
	defer w.Stop()

	workflowID := fmt.Sprintf("test-parent-%d", time.Now().UnixNano())
	we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:        workflowID,
		TaskQueue: taskQueue,
	}, ParentWorkflow, 3)
	require.NoError(t, err)

	var results []string
	err = we.Get(context.Background(), &results)
	require.NoError(t, err)
	assert.Len(t, results, 3)

	t.Logf("✅ Parent workflow completed with %d child results: %v", len(results), results)
}

func TestTimerWorkflow(t *testing.T) {
	c := getClient(t)
	defer c.Close()

	w := startWorker(t, c)
	defer w.Stop()

	workflowID := fmt.Sprintf("test-timer-%d", time.Now().UnixNano())
	durations := []time.Duration{100 * time.Millisecond, 200 * time.Millisecond}

	we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:        workflowID,
		TaskQueue: taskQueue,
	}, TimerWorkflow, durations)
	require.NoError(t, err)

	var events []string
	err = we.Get(context.Background(), &events)
	require.NoError(t, err)
	assert.Len(t, events, 4) // 2 timers x 2 events each

	t.Logf("✅ Timer workflow events: %v", events)
}

func TestRetryWorkflow(t *testing.T) {
	c := getClient(t)
	defer c.Close()

	w := startWorker(t, c)
	defer w.Stop()

	// Reset attempts counter
	activityAttempts = make(map[string]int)

	workflowID := fmt.Sprintf("test-retry-%d", time.Now().UnixNano())
	we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:        workflowID,
		TaskQueue: taskQueue,
	}, RetryWorkflow, 2) // Fail 2 times, succeed on 3rd
	require.NoError(t, err)

	var result string
	err = we.Get(context.Background(), &result)
	require.NoError(t, err)
	assert.Contains(t, result, "succeeded after 3 attempts")

	t.Logf("✅ Retry workflow completed: %s", result)
}

func TestWorkflowHistory(t *testing.T) {
	c := getClient(t)
	defer c.Close()

	w := startWorker(t, c)
	defer w.Stop()

	workflowID := fmt.Sprintf("test-history-%d", time.Now().UnixNano())
	we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:        workflowID,
		TaskQueue: taskQueue,
	}, ActivityWorkflow, "history-test")
	require.NoError(t, err)

	var result string
	err = we.Get(context.Background(), &result)
	require.NoError(t, err)

	// Get workflow history
	iter := c.GetWorkflowHistory(context.Background(), workflowID, "", false, 0)
	eventCount := 0
	for iter.HasNext() {
		event, err := iter.Next()
		require.NoError(t, err)
		eventCount++
		t.Logf("  Event %d: %s", event.EventId, event.EventType.String())
	}

	assert.Greater(t, eventCount, 0)
	t.Logf("✅ Workflow history has %d events (retained storage)", eventCount)
}
