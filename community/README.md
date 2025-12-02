# Community Forum Setup

Self-hosted community options for your Temporal Cloud offering.

## Recommended Options

### 1. Flarum (Recommended for Starting)

- **Pros**: Lightweight, modern UI, easy to set up, low resources
- **Cons**: Fewer features than Discourse
- **Resources**: 512MB RAM, 1 CPU

```bash
cd community
docker-compose up -d
# Access at http://localhost:8088
```

### 2. Discourse (For Larger Communities)

- **Pros**: Full-featured, great moderation, plugins
- **Cons**: Heavy (2GB+ RAM), complex setup
- **Resources**: 2GB RAM, 2 CPU

Uncomment Discourse section in docker-compose.yaml.

### 3. GitHub Discussions (Zero Maintenance)

- **Pros**: Free, no hosting, integrated with code
- **Cons**: Requires GitHub account, less customizable
- **Resources**: None (hosted by GitHub)

Just enable Discussions in your GitHub repo settings.

## Quick Start with Flarum

```bash
# Start the forum
cd community
docker-compose up -d

# Access
# URL: http://localhost:8088
# Admin: admin / changeme123

# Stop
docker-compose down
```

## Production Setup

### 1. Update Environment Variables

```yaml
environment:
  - FLARUM_BASE_URL=https://community.yourdomain.com
  - FLARUM_ADMIN_PASSWORD=<strong-password>
  - DB_PASSWORD=<strong-password>
```

### 2. Add SSL with Traefik/Nginx

```yaml
services:
  flarum:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.flarum.rule=Host(`community.yourdomain.com`)"
      - "traefik.http.routers.flarum.tls.certresolver=letsencrypt"
```

### 3. Recommended Extensions for Flarum

- **flarum/tags** - Organize discussions
- **flarum/mentions** - @mentions
- **flarum/likes** - Like posts
- **flarum/subscriptions** - Follow discussions
- **flarum/markdown** - Markdown support

Install via admin panel or CLI:

```bash
docker exec -it community-forum composer require flarum/tags
```

## Categories to Create

1. **Announcements** - Product updates, releases
2. **Getting Started** - Onboarding help
3. **Workflows** - Workflow design questions
4. **Activities** - Activity implementation
5. **SDKs** - Language-specific help (Go, TypeScript, Python, Java)
6. **Billing** - Billing and subscription questions
7. **Feature Requests** - User suggestions
8. **Bug Reports** - Issue reporting
9. **Show & Tell** - User projects

## Integration with Admin Portal

Add community link to your admin portal navigation:

```tsx
// components/nav.tsx
<a href="https://community.yourdomain.com" target="_blank">
  Community
</a>
```

## Slack Alternative: Mattermost

If you prefer Slack-like chat over forums:

```yaml
services:
  mattermost:
    image: mattermost/mattermost-team-edition:latest
    ports:
      - "8065:8065"
    environment:
      - MM_SQLSETTINGS_DRIVERNAME=postgres
      - MM_SQLSETTINGS_DATASOURCE=postgres://mattermost:secret@mattermost-db:5432/mattermost?sslmode=disable
    volumes:
      - mattermost_data:/mattermost/data
    depends_on:
      - mattermost-db

  mattermost-db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=mattermost
      - POSTGRES_PASSWORD=secret
      - POSTGRES_DB=mattermost
    volumes:
      - mattermost_db:/var/lib/postgresql/data

volumes:
  mattermost_data:
  mattermost_db:
```

## Cost Comparison

| Option             | Hosting Cost  | Maintenance | Features     |
| ------------------ | ------------- | ----------- | ------------ |
| GitHub Discussions | $0            | None        | Basic        |
| Flarum             | $5-10/mo VPS  | Low         | Good         |
| Discourse          | $20-50/mo VPS | Medium      | Excellent    |
| Mattermost         | $10-20/mo VPS | Medium      | Chat-focused |
