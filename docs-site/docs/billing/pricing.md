---
sidebar_position: 1
---

# Pricing

Simple, transparent pricing based on your usage.

## Plans

| Feature              | Free      | Essential | Business  | Enterprise |
| -------------------- | --------- | --------- | --------- | ---------- |
| **Monthly Price**    | $0        | $100      | $500      | Custom     |
| **Actions Included** | 100,000   | 1,000,000 | 2,500,000 | Unlimited  |
| **Active Storage**   | 100 MB    | 1 GB      | 10 GB     | Unlimited  |
| **Retained Storage** | 4 GB      | 40 GB     | 100 GB    | Unlimited  |
| **Namespaces**       | 1         | 5         | 20        | Unlimited  |
| **Support**          | Community | Email     | Priority  | Dedicated  |
| **SLA**              | -         | 99.9%     | 99.95%    | 99.99%     |

## Usage-Based Pricing

Beyond your plan's included usage:

| Metric               | Price                |
| -------------------- | -------------------- |
| **Actions**          | $25 per million      |
| **Active Storage**   | $0.042 per GB-hour   |
| **Retained Storage** | $0.00105 per GB-hour |

## What Counts as an Action?

An **action** is any of the following:

- Workflow Task completion
- Activity Task completion
- Signal sent to a workflow
- Query to a workflow
- Timer fired
- Child workflow started

## Storage Explained

### Active Storage

Data for **running** workflows:

- Workflow state
- Pending activities
- Event history (in progress)

### Retained Storage

Data for **completed** workflows:

- Closed workflow history
- Search attributes
- Retained for visibility queries

## Example Costs

### Startup (Light Usage)

- 500,000 actions/month
- 500 MB active storage
- 10 GB retained storage
- **Cost: $0** (Free tier)

### Growing Business

- 5,000,000 actions/month
- 5 GB active storage
- 100 GB retained storage
- **Cost: ~$250/month** (Essential + overage)

### Enterprise Scale

- 50,000,000 actions/month
- 50 GB active storage
- 1 TB retained storage
- **Cost: Contact us** (Enterprise plan)

## FAQ

### When am I billed?

Monthly, on the anniversary of your signup date.

### Can I change plans?

Yes, upgrade or downgrade anytime. Changes take effect immediately.

### Is there a free trial?

The Free tier is always free. No credit card required.

### What happens if I exceed my limits?

You're automatically charged for overage at the rates above.
