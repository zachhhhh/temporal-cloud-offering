package sdk_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.temporal.io/api/enums/v1"
	"go.temporal.io/api/workflowservice/v1"
	"go.temporal.io/sdk/client"
	"go.temporal.io/sdk/temporal"
	"go.temporal.io/sdk/worker"
	"go.temporal.io/sdk/workflow"
)

const (
	temporalAddress = "localhost:7233"
	namespace       = "default"
	taskQueue       = "sdk-test-queue"
)

// ============================================
// Test Workflows & Activities
// ============================================

func GreetingWorkflow(ctx workflow.Context, name string) (string, error) {
	ao := workflow.ActivityOptions{
		StartToCloseTimeout: 10 * time.Second,
	}
	ctx = workflow.WithActivityOptions(ctx, ao)

	var result string
	err := workflow.ExecuteActivity(ctx, GreetingActivity, name).Get(ctx, &result)
	return result, err
}

func GreetingActivity(ctx context.Context, name string) (string, error) {
	return fmt.Sprintf("Hello, %s!", name), nil
}

func LongWorkflow(ctx workflow.Context, seconds int) (string, error) {
	workflow.Sleep(ctx, time.Duration(seconds)*time.Second)
	return fmt.Sprintf("Slept for %d seconds", seconds), nil
}

func SignalableWorkflow(ctx workflow.Context) (string, error) {
	var message string
	signalChan := workflow.GetSignalChannel(ctx, "message")

	selector := workflow.NewSelector(ctx)
	selector.AddReceive(signalChan, func(c workflow.ReceiveChannel, more bool) {
		c.Receive(ctx, &message)
	})
	selector.Select(ctx)

	return message, nil
}

func QueryableWorkflow(ctx workflow.Context) error {
	counter := 0

	err := workflow.SetQueryHandler(ctx, "counter", func() (int, error) {
		return counter, nil
	})
	if err != nil {
		return err
	}

	for i := 0; i < 5; i++ {
		workflow.Sleep(ctx, 500*time.Millisecond)
		counter++
	}

	return nil
}

// ============================================
// SDK Connection Tests
// ============================================

func TestSDKConnection(t *testing.T) {
	c, err := client.Dial(client.Options{
		HostPort:  temporalAddress,
		Namespace: namespace,
	})
	require.NoError(t, err, "Should connect to Temporal")
	defer c.Close()

	t.Log("✅ SDK connected to Temporal server")
}

func TestNamespaceExists(t *testing.T) {
	c, err := client.Dial(client.Options{
		HostPort:  temporalAddress,
		Namespace: namespace,
	})
	require.NoError(t, err)
	defer c.Close()

	// Use the workflow service client to describe namespace
	resp, err := c.WorkflowService().DescribeNamespace(context.Background(), &workflowservice.DescribeNamespaceRequest{
		Namespace: namespace,
	})
	require.NoError(t, err)
	assert.Equal(t, namespace, resp.NamespaceInfo.Name)

	t.Logf("✅ Namespace '%s' exists", namespace)
}

// ============================================
// Workflow Execution Tests
// ============================================

func TestExecuteWorkflow(t *testing.T) {
	c, err := client.Dial(client.Options{
		HostPort:  temporalAddress,
		Namespace: namespace,
	})
	require.NoError(t, err)
	defer c.Close()

	w := worker.New(c, taskQueue, worker.Options{})
	w.RegisterWorkflow(GreetingWorkflow)
	w.RegisterActivity(GreetingActivity)
	require.NoError(t, w.Start())
	defer w.Stop()

	workflowID := fmt.Sprintf("sdk-test-%d", time.Now().UnixNano())
	we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:        workflowID,
		TaskQueue: taskQueue,
	}, GreetingWorkflow, "SDK Test")
	require.NoError(t, err)

	var result string
	err = we.Get(context.Background(), &result)
	require.NoError(t, err)
	assert.Equal(t, "Hello, SDK Test!", result)

	t.Logf("✅ Workflow executed: %s", result)
}

func TestWorkflowWithOptions(t *testing.T) {
	c, err := client.Dial(client.Options{
		HostPort:  temporalAddress,
		Namespace: namespace,
	})
	require.NoError(t, err)
	defer c.Close()

	w := worker.New(c, taskQueue, worker.Options{})
	w.RegisterWorkflow(GreetingWorkflow)
	w.RegisterActivity(GreetingActivity)
	require.NoError(t, w.Start())
	defer w.Stop()

	workflowID := fmt.Sprintf("sdk-options-%d", time.Now().UnixNano())
	we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:                       workflowID,
		TaskQueue:                taskQueue,
		WorkflowExecutionTimeout: 30 * time.Second,
		WorkflowRunTimeout:       30 * time.Second,
		WorkflowTaskTimeout:      10 * time.Second,
		RetryPolicy: &temporal.RetryPolicy{
			MaximumAttempts: 3,
		},
	}, GreetingWorkflow, "Options Test")
	require.NoError(t, err)

	var result string
	err = we.Get(context.Background(), &result)
	require.NoError(t, err)

	t.Logf("✅ Workflow with options executed: %s", result)
}

// ============================================
// Signal Tests
// ============================================

func TestSignalWorkflow(t *testing.T) {
	c, err := client.Dial(client.Options{
		HostPort:  temporalAddress,
		Namespace: namespace,
	})
	require.NoError(t, err)
	defer c.Close()

	w := worker.New(c, taskQueue, worker.Options{})
	w.RegisterWorkflow(SignalableWorkflow)
	require.NoError(t, w.Start())
	defer w.Stop()

	workflowID := fmt.Sprintf("sdk-signal-%d", time.Now().UnixNano())
	we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:        workflowID,
		TaskQueue: taskQueue,
	}, SignalableWorkflow)
	require.NoError(t, err)

	// Send signal
	time.Sleep(500 * time.Millisecond)
	err = c.SignalWorkflow(context.Background(), workflowID, "", "message", "Signal received!")
	require.NoError(t, err)

	var result string
	err = we.Get(context.Background(), &result)
	require.NoError(t, err)
	assert.Equal(t, "Signal received!", result)

	t.Logf("✅ Signal sent and received: %s", result)
}

func TestSignalWithStart(t *testing.T) {
	c, err := client.Dial(client.Options{
		HostPort:  temporalAddress,
		Namespace: namespace,
	})
	require.NoError(t, err)
	defer c.Close()

	w := worker.New(c, taskQueue, worker.Options{})
	w.RegisterWorkflow(SignalableWorkflow)
	require.NoError(t, w.Start())
	defer w.Stop()

	workflowID := fmt.Sprintf("sdk-signal-start-%d", time.Now().UnixNano())
	we, err := c.SignalWithStartWorkflow(context.Background(), workflowID, "message", "Signal with start!",
		client.StartWorkflowOptions{
			TaskQueue: taskQueue,
		}, SignalableWorkflow)
	require.NoError(t, err)

	var result string
	err = we.Get(context.Background(), &result)
	require.NoError(t, err)
	assert.Equal(t, "Signal with start!", result)

	t.Logf("✅ SignalWithStart executed: %s", result)
}

// ============================================
// Query Tests
// ============================================

func TestQueryWorkflow(t *testing.T) {
	c, err := client.Dial(client.Options{
		HostPort:  temporalAddress,
		Namespace: namespace,
	})
	require.NoError(t, err)
	defer c.Close()

	w := worker.New(c, taskQueue, worker.Options{})
	w.RegisterWorkflow(QueryableWorkflow)
	require.NoError(t, w.Start())
	defer w.Stop()

	workflowID := fmt.Sprintf("sdk-query-%d", time.Now().UnixNano())
	we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:        workflowID,
		TaskQueue: taskQueue,
	}, QueryableWorkflow)
	require.NoError(t, err)

	// Query during execution
	time.Sleep(1 * time.Second)
	resp, err := c.QueryWorkflow(context.Background(), workflowID, "", "counter")
	require.NoError(t, err)

	var counter int
	err = resp.Get(&counter)
	require.NoError(t, err)
	assert.Greater(t, counter, 0)

	t.Logf("✅ Query returned counter: %d", counter)

	// Wait for completion
	err = we.Get(context.Background(), nil)
	require.NoError(t, err)
}

// ============================================
// Workflow Management Tests
// ============================================

func TestCancelWorkflow(t *testing.T) {
	c, err := client.Dial(client.Options{
		HostPort:  temporalAddress,
		Namespace: namespace,
	})
	require.NoError(t, err)
	defer c.Close()

	w := worker.New(c, taskQueue, worker.Options{})
	w.RegisterWorkflow(LongWorkflow)
	require.NoError(t, w.Start())
	defer w.Stop()

	workflowID := fmt.Sprintf("sdk-cancel-%d", time.Now().UnixNano())
	we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:        workflowID,
		TaskQueue: taskQueue,
	}, LongWorkflow, 60) // 60 second workflow
	require.NoError(t, err)

	// Cancel after 1 second
	time.Sleep(1 * time.Second)
	err = c.CancelWorkflow(context.Background(), workflowID, "")
	require.NoError(t, err)

	// Verify cancelled
	var result string
	err = we.Get(context.Background(), &result)
	assert.Error(t, err) // Should error due to cancellation

	t.Log("✅ Workflow cancelled successfully")
}

func TestTerminateWorkflow(t *testing.T) {
	c, err := client.Dial(client.Options{
		HostPort:  temporalAddress,
		Namespace: namespace,
	})
	require.NoError(t, err)
	defer c.Close()

	w := worker.New(c, taskQueue, worker.Options{})
	w.RegisterWorkflow(LongWorkflow)
	require.NoError(t, w.Start())
	defer w.Stop()

	workflowID := fmt.Sprintf("sdk-terminate-%d", time.Now().UnixNano())
	we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:        workflowID,
		TaskQueue: taskQueue,
	}, LongWorkflow, 60)
	require.NoError(t, err)

	// Terminate after 1 second
	time.Sleep(1 * time.Second)
	err = c.TerminateWorkflow(context.Background(), workflowID, "", "Test termination")
	require.NoError(t, err)

	// Verify terminated
	var result string
	err = we.Get(context.Background(), &result)
	assert.Error(t, err)

	t.Log("✅ Workflow terminated successfully")
}

func TestDescribeWorkflow(t *testing.T) {
	c, err := client.Dial(client.Options{
		HostPort:  temporalAddress,
		Namespace: namespace,
	})
	require.NoError(t, err)
	defer c.Close()

	w := worker.New(c, taskQueue, worker.Options{})
	w.RegisterWorkflow(GreetingWorkflow)
	w.RegisterActivity(GreetingActivity)
	require.NoError(t, w.Start())
	defer w.Stop()

	workflowID := fmt.Sprintf("sdk-describe-%d", time.Now().UnixNano())
	we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:        workflowID,
		TaskQueue: taskQueue,
	}, GreetingWorkflow, "Describe Test")
	require.NoError(t, err)

	// Wait for completion
	var result string
	err = we.Get(context.Background(), &result)
	require.NoError(t, err)

	// Describe workflow
	desc, err := c.DescribeWorkflowExecution(context.Background(), workflowID, "")
	require.NoError(t, err)
	assert.Equal(t, enums.WORKFLOW_EXECUTION_STATUS_COMPLETED, desc.WorkflowExecutionInfo.Status)

	t.Logf("✅ Workflow described: status=%s", desc.WorkflowExecutionInfo.Status.String())
}

// ============================================
// History Tests
// ============================================

func TestGetWorkflowHistory(t *testing.T) {
	c, err := client.Dial(client.Options{
		HostPort:  temporalAddress,
		Namespace: namespace,
	})
	require.NoError(t, err)
	defer c.Close()

	w := worker.New(c, taskQueue, worker.Options{})
	w.RegisterWorkflow(GreetingWorkflow)
	w.RegisterActivity(GreetingActivity)
	require.NoError(t, w.Start())
	defer w.Stop()

	workflowID := fmt.Sprintf("sdk-history-%d", time.Now().UnixNano())
	we, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:        workflowID,
		TaskQueue: taskQueue,
	}, GreetingWorkflow, "History Test")
	require.NoError(t, err)

	var result string
	err = we.Get(context.Background(), &result)
	require.NoError(t, err)

	// Get history
	iter := c.GetWorkflowHistory(context.Background(), workflowID, "", false, enums.HISTORY_EVENT_FILTER_TYPE_ALL_EVENT)
	eventCount := 0
	for iter.HasNext() {
		_, err := iter.Next()
		require.NoError(t, err)
		eventCount++
	}

	assert.Greater(t, eventCount, 0)
	t.Logf("✅ Workflow history has %d events", eventCount)
}

// ============================================
// List Workflows Tests
// ============================================

func TestListWorkflows(t *testing.T) {
	c, err := client.Dial(client.Options{
		HostPort:  temporalAddress,
		Namespace: namespace,
	})
	require.NoError(t, err)
	defer c.Close()

	// List open workflows
	resp, err := c.ListOpenWorkflow(context.Background(), &workflowservice.ListOpenWorkflowExecutionsRequest{
		Namespace:       namespace,
		MaximumPageSize: 10,
	})
	require.NoError(t, err)
	t.Logf("✅ Listed %d open workflows", len(resp.Executions))

	// List closed workflows
	closedResp, err := c.ListClosedWorkflow(context.Background(), &workflowservice.ListClosedWorkflowExecutionsRequest{
		Namespace:       namespace,
		MaximumPageSize: 10,
	})
	require.NoError(t, err)
	t.Logf("✅ Listed %d closed workflows", len(closedResp.Executions))
}
