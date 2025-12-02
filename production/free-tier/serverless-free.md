# Serverless Free Tier Stack

Combine multiple free tiers for $0/month hosting.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    FREE TIER STACK                       │
├─────────────────────────────────────────────────────────┤
│  Fly.io (Free)         │  Temporal Server (256MB)       │
│                        │  Temporal UI                    │
├─────────────────────────────────────────────────────────┤
│  Railway (Free)        │  Billing Service               │
│  or Render             │  Usage Collector               │
│                        │  Admin Portal                   │
├─────────────────────────────────────────────────────────┤
│  Neon (Free)           │  PostgreSQL (0.5GB storage)    │
├─────────────────────────────────────────────────────────┤
│  Upstash (Free)        │  Redis (10K commands/day)      │
├─────────────────────────────────────────────────────────┤
│  Cloudflare (Free)     │  DNS + CDN + SSL               │
└─────────────────────────────────────────────────────────┘
```

## Free Tier Limits

| Service        | Free Tier                             |
| -------------- | ------------------------------------- |
| **Fly.io**     | 3 shared VMs (256MB), 3GB storage     |
| **Railway**    | $5 credit/month, 500 hours            |
| **Render**     | 750 hours/month static + web services |
| **Neon**       | 0.5GB storage, 1 project              |
| **Upstash**    | 10K commands/day, 256MB               |
| **Cloudflare** | Unlimited DNS, CDN, SSL               |

## Limitations

⚠️ **Not recommended for Temporal** because:

- Temporal needs persistent connections
- 256MB RAM is too small for Temporal server
- Free tiers sleep after inactivity

## Better Alternative

Use **Oracle Cloud Free Tier** instead - it's truly free with enough resources.
