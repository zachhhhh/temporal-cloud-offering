---
slug: /
sidebar_position: 1
---

# Welcome to Your Temporal Cloud

Build reliable, scalable applications with durable workflow execution.

## What is Temporal?

Temporal is a **durable execution platform** that makes it easy to build reliable applications. Your code runs exactly once, survives failures, and scales automatically.

## Quick Start

### 1. Create an Account

Sign up at [admin.yourdomain.com](https://admin.yourdomain.com) to get started.

### 2. Create a Namespace

```bash
# Via Admin Portal or API
curl -X POST https://api.yourdomain.com/api/v1/organizations/{org_id}/namespaces \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{"name": "my-namespace", "region": "us-east-1"}'
```

### 3. Connect Your Application

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

<Tabs>
<TabItem value="go" label="Go">

```go
import "go.temporal.io/sdk/client"

c, err := client.Dial(client.Options{
    HostPort:  "temporal.yourdomain.com:7233",
    Namespace: "my-namespace",
})
```

</TabItem>
<TabItem value="typescript" label="TypeScript">

```typescript
import { Connection, Client } from "@temporalio/client";

const connection = await Connection.connect({
  address: "temporal.yourdomain.com:7233",
});

const client = new Client({
  connection,
  namespace: "my-namespace",
});
```

</TabItem>
<TabItem value="python" label="Python">

```python
from temporalio.client import Client

client = await Client.connect(
    "temporal.yourdomain.com:7233",
    namespace="my-namespace",
)
```

</TabItem>
</Tabs>

### 4. Run Your First Workflow

```go
we, err := c.ExecuteWorkflow(ctx, client.StartWorkflowOptions{
    ID:        "my-workflow-id",
    TaskQueue: "my-task-queue",
}, MyWorkflow, input)
```

## Key Features

- **Durable Execution** - Workflows survive process crashes and restarts
- **Automatic Retries** - Failed activities retry automatically
- **Visibility** - Full observability into workflow state
- **Scalability** - Handle millions of concurrent workflows

## Pricing

| Plan       | Actions/Month | Price      |
| ---------- | ------------- | ---------- |
| Free       | 100,000       | $0         |
| Essential  | 1,000,000     | $100/mo    |
| Business   | 2,500,000     | $500/mo    |
| Enterprise | Unlimited     | Contact us |

See [Pricing](/billing/pricing) for details.

## Support

- **Documentation**: You're here!
- **Email**: support@yourdomain.com
- **Community**: [community.yourdomain.com](https://community.yourdomain.com)
