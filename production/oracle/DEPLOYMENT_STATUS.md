# Oracle Cloud Deployment Status

**Last Updated:** 2025-12-02

## Current Infrastructure

### VM 1: temporal-cloud (Primary)

- **IP:** 161.118.255.113
- **Shape:** VM.Standard.E2.1.Micro (1 OCPU, 1GB RAM)
- **Status:** Running
- **Services:**
  - Temporal Server (port 7233)
  - Temporal UI (via Caddy on port 80)
  - PostgreSQL (internal)
  - Billing API (via Caddy /api/\*)
  - Caddy reverse proxy (port 80)

### VM 2: temporal-cloud-2 (Available)

- **IP:** 161.118.214.222
- **Shape:** VM.Standard.E2.1.Micro (1 OCPU, 1GB RAM)
- **Status:** Running (idle, can be used for workers)

## Access URLs

| Service       | URL                           |
| ------------- | ----------------------------- |
| Temporal UI   | http://161.118.255.113/       |
| Temporal gRPC | 161.118.255.113:7233          |
| Health Check  | http://161.118.255.113/health |
| Billing API   | http://161.118.255.113/api/*  |

## SSH Access

```bash
# Primary VM
ssh -i ~/.ssh/oracle_temporal ubuntu@161.118.255.113

# Secondary VM
ssh -i ~/.ssh/oracle_temporal ubuntu@161.118.214.222
```

## ARM Instance (Pending)

Oracle ARM A1 instances (4 OCPU, 24GB RAM) are currently out of capacity in Singapore region.

### Retry Script

Run the retry script to automatically create an ARM instance when capacity becomes available:

```bash
# Run continuously (retries every 5 minutes for 24 hours)
./retry-arm-instance.sh

# Run once (for cron jobs)
./retry-arm-instance.sh --once

# Set up as cron job (every 5 minutes)
crontab -e
# Add: */5 * * * * /path/to/retry-arm-instance.sh --once >> /tmp/arm-retry.log 2>&1
```

## Resource Usage

Current memory usage on primary VM:

- Total: 956MB
- Used: ~550MB
- Available: ~400MB
- Swap: 4GB (using ~130MB)

Docker container limits:

- PostgreSQL: 256MB
- Temporal: 512MB
- Temporal UI: 128MB
- Billing API: 64MB

## Upgrade Path

When ARM capacity becomes available:

1. Run `./retry-arm-instance.sh` to create ARM instance
2. Install K3s on ARM instance
3. Deploy full Temporal stack with Elasticsearch
4. Migrate data from current PostgreSQL
5. Update DNS/load balancer
6. Terminate AMD Micro VMs (optional, keep for workers)

## Free Tier Limits

| Resource      | Limit      | Current Usage |
| ------------- | ---------- | ------------- |
| AMD Micro VMs | 2          | 2             |
| ARM A1 OCPUs  | 4          | 0 (pending)   |
| ARM A1 Memory | 24GB       | 0 (pending)   |
| Block Storage | 200GB      | ~100GB        |
| Bandwidth     | 10TB/month | Minimal       |

## Known Limitations

1. **Low Memory:** 1GB RAM per VM limits scalability
2. **No HA:** Single-node deployment, no redundancy
3. **No SSL:** Currently HTTP only (add domain + Caddy HTTPS for production)
4. **ARM Pending:** K3s deployment waiting for ARM capacity
