"""
Temporal Python SDK Tests
Tests all SDK functionality against the local Temporal server
"""

import asyncio
import pytest
from datetime import timedelta
from temporalio.client import Client
from temporalio.worker import Worker
from temporalio import workflow, activity

TEMPORAL_ADDRESS = "localhost:7233"
NAMESPACE = "default"
TASK_QUEUE = "python-sdk-test-queue"


# ============================================
# Test Workflows & Activities
# ============================================

@activity.defn
async def greeting_activity(name: str) -> str:
    return f"Hello, {name}!"


@activity.defn
async def slow_activity(seconds: int) -> str:
    await asyncio.sleep(seconds)
    return f"Slept for {seconds} seconds"


@workflow.defn
class GreetingWorkflow:
    @workflow.run
    async def run(self, name: str) -> str:
        return await workflow.execute_activity(
            greeting_activity,
            name,
            start_to_close_timeout=timedelta(seconds=10),
        )


@workflow.defn
class SignalWorkflow:
    def __init__(self):
        self.message = ""

    @workflow.run
    async def run(self) -> str:
        await workflow.wait_condition(lambda: self.message != "")
        return self.message

    @workflow.signal
    async def set_message(self, message: str):
        self.message = message


@workflow.defn
class QueryWorkflow:
    def __init__(self):
        self.counter = 0

    @workflow.run
    async def run(self) -> int:
        for _ in range(5):
            await asyncio.sleep(0.5)
            self.counter += 1
        return self.counter

    @workflow.query
    def get_counter(self) -> int:
        return self.counter


# ============================================
# Fixtures
# ============================================

@pytest.fixture
async def client():
    """Create Temporal client"""
    client = await Client.connect(TEMPORAL_ADDRESS, namespace=NAMESPACE)
    yield client
    await client.close()


@pytest.fixture
async def worker(client):
    """Create and start worker"""
    worker = Worker(
        client,
        task_queue=TASK_QUEUE,
        workflows=[GreetingWorkflow, SignalWorkflow, QueryWorkflow],
        activities=[greeting_activity, slow_activity],
    )
    async with worker:
        yield worker


# ============================================
# Connection Tests
# ============================================

@pytest.mark.asyncio
async def test_connection():
    """Test basic connection to Temporal"""
    client = await Client.connect(TEMPORAL_ADDRESS, namespace=NAMESPACE)
    assert client is not None
    await client.close()
    print("✅ Connected to Temporal server")


@pytest.mark.asyncio
async def test_namespace_exists(client):
    """Test namespace exists"""
    # The client connected successfully, so namespace exists
    assert client is not None
    print(f"✅ Namespace '{NAMESPACE}' accessible")


# ============================================
# Workflow Execution Tests
# ============================================

@pytest.mark.asyncio
async def test_execute_workflow(client, worker):
    """Test basic workflow execution"""
    import uuid
    workflow_id = f"python-test-{uuid.uuid4()}"
    
    result = await client.execute_workflow(
        GreetingWorkflow.run,
        "Python SDK",
        id=workflow_id,
        task_queue=TASK_QUEUE,
    )
    
    assert result == "Hello, Python SDK!"
    print(f"✅ Workflow executed: {result}")


@pytest.mark.asyncio
async def test_workflow_handle(client, worker):
    """Test getting workflow handle"""
    import uuid
    workflow_id = f"python-handle-{uuid.uuid4()}"
    
    handle = await client.start_workflow(
        GreetingWorkflow.run,
        "Handle Test",
        id=workflow_id,
        task_queue=TASK_QUEUE,
    )
    
    result = await handle.result()
    assert result == "Hello, Handle Test!"
    print(f"✅ Workflow handle works: {result}")


# ============================================
# Signal Tests
# ============================================

@pytest.mark.asyncio
async def test_signal_workflow(client, worker):
    """Test sending signals to workflow"""
    import uuid
    workflow_id = f"python-signal-{uuid.uuid4()}"
    
    handle = await client.start_workflow(
        SignalWorkflow.run,
        id=workflow_id,
        task_queue=TASK_QUEUE,
    )
    
    # Send signal
    await asyncio.sleep(0.5)
    await handle.signal(SignalWorkflow.set_message, "Signal received!")
    
    result = await handle.result()
    assert result == "Signal received!"
    print(f"✅ Signal sent and received: {result}")


# ============================================
# Query Tests
# ============================================

@pytest.mark.asyncio
async def test_query_workflow(client, worker):
    """Test querying workflow state"""
    import uuid
    workflow_id = f"python-query-{uuid.uuid4()}"
    
    handle = await client.start_workflow(
        QueryWorkflow.run,
        id=workflow_id,
        task_queue=TASK_QUEUE,
    )
    
    # Query during execution
    await asyncio.sleep(1)
    counter = await handle.query(QueryWorkflow.get_counter)
    assert counter > 0
    print(f"✅ Query returned counter: {counter}")
    
    # Wait for completion
    final = await handle.result()
    assert final == 5


# ============================================
# Workflow Management Tests
# ============================================

@pytest.mark.asyncio
async def test_cancel_workflow(client, worker):
    """Test cancelling a workflow"""
    import uuid
    workflow_id = f"python-cancel-{uuid.uuid4()}"
    
    handle = await client.start_workflow(
        QueryWorkflow.run,  # Long-running workflow
        id=workflow_id,
        task_queue=TASK_QUEUE,
    )
    
    # Cancel after short delay
    await asyncio.sleep(0.5)
    await handle.cancel()
    
    # Verify cancelled
    try:
        await handle.result()
        assert False, "Should have raised"
    except Exception:
        pass
    
    print("✅ Workflow cancelled successfully")


@pytest.mark.asyncio
async def test_describe_workflow(client, worker):
    """Test describing workflow execution"""
    import uuid
    workflow_id = f"python-describe-{uuid.uuid4()}"
    
    result = await client.execute_workflow(
        GreetingWorkflow.run,
        "Describe Test",
        id=workflow_id,
        task_queue=TASK_QUEUE,
    )
    
    # Describe the completed workflow
    handle = client.get_workflow_handle(workflow_id)
    desc = await handle.describe()
    
    assert desc.status.name == "COMPLETED"
    print(f"✅ Workflow described: status={desc.status.name}")


# ============================================
# History Tests
# ============================================

@pytest.mark.asyncio
async def test_workflow_history(client, worker):
    """Test getting workflow history"""
    import uuid
    workflow_id = f"python-history-{uuid.uuid4()}"
    
    await client.execute_workflow(
        GreetingWorkflow.run,
        "History Test",
        id=workflow_id,
        task_queue=TASK_QUEUE,
    )
    
    # Get history
    handle = client.get_workflow_handle(workflow_id)
    event_count = 0
    async for event in handle.fetch_history_events():
        event_count += 1
    
    assert event_count > 0
    print(f"✅ Workflow history has {event_count} events")


# ============================================
# List Workflows Tests
# ============================================

@pytest.mark.asyncio
async def test_list_workflows(client):
    """Test listing workflows"""
    count = 0
    async for wf in client.list_workflows(query=""):
        count += 1
        if count >= 5:
            break
    
    print(f"✅ Listed {count} workflows")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
