# Complete Self-Hosting Guide

This document explains how to run a fully self-hosted Temporal Cloud offering with NO external dependencies.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        YOUR TEMPORAL CLOUD                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                   │
│  │ Admin Portal │  │ Temporal UI  │  │   Docs Site  │  ← Customer-facing│
│  │  (React/Next)│  │ (Self-hosted)│  │  (Docusaurus)│                   │
│  └──────┬───────┘  └──────┬───────┘  └──────────────┘                   │
│         │                 │                                              │
│  ┌──────┴───────┐  ┌──────┴───────┐                                     │
│  │Billing API   │  │Temporal Server│  ← Core Services                   │
│  │  (Go/Stripe) │  │  (Go/gRPC)   │                                     │
│  └──────┬───────┘  └──────┬───────┘                                     │
│         │                 │                                              │
│  ┌──────┴─────────────────┴───────┐                                     │
│  │         PostgreSQL              │  ← Data Layer                      │
│  │   (Temporal + Billing DBs)      │                                     │
│  └─────────────────────────────────┘                                     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## What is Temporal Server?

**Temporal Server** is the core workflow orchestration engine. It:

1. **Stores Workflow State** - Every step of customer workflows persists in PostgreSQL
2. **Manages Task Queues** - Routes tasks to customer workers
3. **Handles Retries** - Automatically retries failed activities
4. **Provides Durability** - Workflows survive crashes and restarts

### How Customers Use It

```go
// Customer's code connects to YOUR Temporal Server
client, _ := client.Dial(client.Options{
    HostPort: "temporal.yourdomain.com:7233",
})

// Start a workflow
we, _ := client.ExecuteWorkflow(ctx, options, MyWorkflow, input)
```

### What Gets Billed

| Metric               | Description                                      | Price            |
| -------------------- | ------------------------------------------------ | ---------------- |
| **Actions**          | Workflow tasks, activity tasks, signals, queries | $25/million      |
| **Active Storage**   | Running workflow data                            | $0.042/GB-hour   |
| **Retained Storage** | Completed workflow history                       | $0.00105/GB-hour |

## What is the Billing API?

Your custom **Billing Service** handles:

1. **Usage Collection** - Prometheus scrapes Temporal metrics
2. **Aggregation** - Hourly rollups per organization
3. **Pricing Calculation** - Apply your pricing model
4. **Stripe Integration** - Automatic invoicing and payment

### Billing Flow

```
Temporal Server → Prometheus → Usage Collector → PostgreSQL → Billing API → Stripe
       ↓                                              ↓
   /metrics                                    Monthly Invoice
```

## Components to Self-Host

### 1. Temporal Server ✅

- **Source**: https://github.com/temporalio/temporal (Apache 2.0)
- **Image**: `temporalio/auto-setup:latest`
- **Status**: Fully open source, self-hostable

### 2. Temporal UI ⚠️ (Needs Configuration)

- **Source**: https://github.com/temporalio/ui (MIT License)
- **Image**: `temporalio/ui:latest`
- **Issue**: Contains links to temporal.io docs, Slack, changelog
- **Solution**: Configure environment variables (see below)

### 3. Admin Portal ✅

- **Source**: This repo (`admin-portal/`)
- **Status**: Fully custom, self-hosted

### 4. Billing Service ✅

- **Source**: This repo (`billing-service/`)
- **Status**: Fully custom, self-hosted

### 5. Documentation Site ❌ (Need to Create)

- **Solution**: Deploy your own docs with Docusaurus/GitBook

### 6. Community/Support ❌ (Need to Create)

- **Solution**: Self-hosted forum (Discourse) or support system

## Configuring Temporal UI for Self-Hosting

### Environment Variables

```yaml
# docker-compose.yaml
temporal-ui:
  image: temporalio/ui:latest
  environment:
    - TEMPORAL_ADDRESS=temporal:7233
    - TEMPORAL_NOTIFY_ON_NEW_VERSION=false # Disable update notifications
    - TEMPORAL_FEEDBACK_URL=mailto:support@yourdomain.com # Your support
    - TEMPORAL_UI_PUBLIC_PATH= # Your base path
```

### Full Configuration File

Create `temporal-ui-config.yaml`:

```yaml
notifyOnNewVersion: false
feedbackUrl: "https://support.yourdomain.com"
defaultNamespace: default
enableUi: true
cloudUi: false
```

### Forking Temporal UI (For Full Control)

If you need to remove ALL external references:

```bash
# Fork the repo
git clone https://github.com/temporalio/ui.git temporal-ui-custom

# Search for external links
grep -r "temporal.io" src/
grep -r "slack" src/
grep -r "community" src/

# Replace with your URLs
# Build custom image
docker build -t your-registry/temporal-ui:custom .
```

## Setting Up Your Documentation Site

### Option 1: Docusaurus (Recommended)

```bash
npx create-docusaurus@latest docs classic

# Structure
docs/
├── docs/
│   ├── getting-started.md
│   ├── workflows/
│   ├── activities/
│   ├── billing/
│   └── api-reference/
├── blog/
└── docusaurus.config.js
```

### Option 2: GitBook

Self-hosted GitBook or use their service with custom domain.

### Option 3: MkDocs

```bash
pip install mkdocs-material
mkdocs new docs
```

## Setting Up Community/Support

### Option 1: Discourse (Self-Hosted Forum)

```yaml
# docker-compose.yaml
discourse:
  image: discourse/discourse
  environment:
    - DISCOURSE_HOSTNAME=community.yourdomain.com
```

### Option 2: GitHub Discussions

Use your GitHub repo's Discussions feature.

### Option 3: Zendesk/Intercom

Commercial support system with your branding.

## Complete Self-Hosted Stack

```yaml
# Full docker-compose.yaml for self-hosted stack
version: "3.8"

services:
  # Database
  postgresql:
    image: postgres:15-alpine

  # Core Temporal
  temporal:
    image: temporalio/auto-setup:latest

  # Temporal UI (configured)
  temporal-ui:
    image: temporalio/ui:latest
    environment:
      - TEMPORAL_NOTIFY_ON_NEW_VERSION=false
      - TEMPORAL_FEEDBACK_URL=https://support.yourdomain.com

  # Your Custom Services
  billing-service:
    build: ./billing-service

  admin-portal:
    build: ./admin-portal

  usage-collector:
    build: ./usage-collector

  # Documentation (Docusaurus)
  docs:
    build: ./docs
    ports:
      - "3001:80"

  # Community Forum (Discourse)
  # discourse:
  #   image: discourse/discourse
```

## External Dependencies Audit

| Component       | External Dependency       | Self-Host Solution              |
| --------------- | ------------------------- | ------------------------------- |
| Temporal Server | None                      | ✅ Already self-hosted          |
| Temporal UI     | Links to docs.temporal.io | Configure feedbackUrl           |
| Temporal UI     | Slack community link      | Remove or replace               |
| Temporal UI     | Version check             | Set NOTIFY_ON_NEW_VERSION=false |
| Billing         | Stripe API                | Required (or use Lago)          |
| Admin Portal    | None                      | ✅ Already self-hosted          |
| Docs            | None                      | Need to create                  |
| Community       | None                      | Need to create                  |

## Open Source Repositories

All Temporal components are open source:

| Repository      | License    | URL                                          |
| --------------- | ---------- | -------------------------------------------- |
| Temporal Server | Apache 2.0 | https://github.com/temporalio/temporal       |
| Temporal UI     | MIT        | https://github.com/temporalio/ui             |
| Go SDK          | MIT        | https://github.com/temporalio/sdk-go         |
| TypeScript SDK  | MIT        | https://github.com/temporalio/sdk-typescript |
| Python SDK      | MIT        | https://github.com/temporalio/sdk-python     |
| Java SDK        | Apache 2.0 | https://github.com/temporalio/sdk-java       |

## Billing Alternatives to Stripe

If you want to avoid Stripe:

### Lago (Open Source)

- Self-hosted billing platform
- https://github.com/getlago/lago
- Usage-based billing built-in

### Kill Bill

- Open source billing
- https://github.com/killbill/killbill

### Custom Implementation

- Direct bank integration
- Cryptocurrency payments

## Checklist for Full Self-Hosting

- [x] Temporal Server (self-hosted)
- [x] PostgreSQL (self-hosted)
- [x] Billing Service (custom)
- [x] Admin Portal (custom)
- [x] Usage Collector (custom)
- [ ] Temporal UI (configure to remove external links)
- [ ] Documentation Site (create with Docusaurus)
- [ ] Community Forum (Discourse or similar)
- [ ] Support System (email/ticketing)
- [ ] Custom Domain & SSL
- [ ] Email Service (for notifications)
