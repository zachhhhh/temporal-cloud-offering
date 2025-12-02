# OAuth/SSO Setup for Temporal Cloud Offering

This guide covers setting up OAuth/SSO authentication for your Temporal Cloud deployment.

## Overview

We support multiple OAuth providers:

- **Google OAuth** (Recommended for quick setup)
- **Auth0** (Recommended for enterprise)
- **GitHub OAuth**
- **Cloudflare Access** (Zero Trust)

---

## Option 1: Google OAuth (Simplest)

### Step 1: Create Google OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Navigate to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth 2.0 Client IDs**
5. Configure consent screen if prompted
6. Application type: **Web application**
7. Add authorized redirect URIs:
   ```
   https://temporal.YOUR_DOMAIN/sso/callback
   https://app.YOUR_DOMAIN/api/auth/callback/google
   ```
8. Copy **Client ID** and **Client Secret**

### Step 2: Update Environment

```bash
# In production/cloudflare-tunnel/.env
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
```

### Step 3: Update Temporal UI Config

```yaml
# deploy/temporal-ui-config-oidc.yaml
auth:
  enabled: true
  providers:
    - label: "Sign in with Google"
      type: oidc
      providerUrl: "https://accounts.google.com"
      clientId: "${GOOGLE_CLIENT_ID}"
      clientSecret: "${GOOGLE_CLIENT_SECRET}"
      scopes:
        - openid
        - profile
        - email
      callbackUrl: "https://temporal.YOUR_DOMAIN/sso/callback"
```

---

## Option 2: Cloudflare Access (Zero Trust - Recommended for Production)

Cloudflare Access provides enterprise-grade authentication without modifying your application.

### Step 1: Enable Cloudflare Access

1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Navigate to **Access** → **Applications**
3. Click **Add an application** → **Self-hosted**

### Step 2: Configure Application

For each service, create an Access application:

**Temporal UI:**

- Application name: `Temporal UI`
- Session Duration: `24h`
- Application domain: `temporal.YOUR_DOMAIN`
- Path: Leave empty (protects entire subdomain)

**Admin Portal:**

- Application name: `Admin Portal`
- Session Duration: `24h`
- Application domain: `app.YOUR_DOMAIN`

**Grafana:**

- Application name: `Grafana Metrics`
- Session Duration: `24h`
- Application domain: `grafana.YOUR_DOMAIN`

### Step 3: Configure Identity Providers

1. Go to **Settings** → **Authentication**
2. Add identity providers:
   - **Google** (one-click setup)
   - **GitHub**
   - **One-time PIN** (email-based)
   - **SAML** (for enterprise SSO)

### Step 4: Create Access Policies

Create policies to control who can access:

```
Policy Name: Allow Team Members
Action: Allow
Include:
  - Emails ending in: @yourcompany.com
  - Specific emails: user1@gmail.com, user2@gmail.com
```

### Step 5: Update Tunnel Config

Cloudflare Access works automatically with tunnels. No additional config needed!

---

## Option 3: Auth0 (Enterprise Features)

### Step 1: Create Auth0 Application

1. Go to [Auth0 Dashboard](https://manage.auth0.com/)
2. Create a new **Regular Web Application**
3. Configure:
   - Allowed Callback URLs:
     ```
     https://temporal.YOUR_DOMAIN/sso/callback
     https://app.YOUR_DOMAIN/api/auth/callback/auth0
     ```
   - Allowed Logout URLs:
     ```
     https://temporal.YOUR_DOMAIN
     https://app.YOUR_DOMAIN
     ```

### Step 2: Get Credentials

From your Auth0 application settings:

- Domain: `YOUR_TENANT.auth0.com`
- Client ID: `xxxxx`
- Client Secret: `xxxxx`

### Step 3: Update Configuration

```yaml
# deploy/temporal-ui-config-oidc.yaml
auth:
  enabled: true
  providers:
    - label: "Sign in"
      type: oidc
      providerUrl: "https://YOUR_TENANT.auth0.com/"
      clientId: "${AUTH0_CLIENT_ID}"
      clientSecret: "${AUTH0_CLIENT_SECRET}"
      scopes:
        - openid
        - profile
        - email
      callbackUrl: "https://temporal.YOUR_DOMAIN/sso/callback"
```

---

## Option 4: GitHub OAuth

### Step 1: Create GitHub OAuth App

1. Go to GitHub → Settings → Developer settings → OAuth Apps
2. Click **New OAuth App**
3. Configure:
   - Homepage URL: `https://app.YOUR_DOMAIN`
   - Authorization callback URL: `https://app.YOUR_DOMAIN/api/auth/callback/github`

### Step 2: Update Admin Portal

The admin portal uses NextAuth.js. Update `admin-portal/.env`:

```bash
GITHUB_CLIENT_ID=your-client-id
GITHUB_CLIENT_SECRET=your-client-secret
NEXTAUTH_URL=https://app.YOUR_DOMAIN
NEXTAUTH_SECRET=generate-a-random-secret
```

---

## Applying OAuth to Temporal UI

### Method 1: Environment Variables

```bash
# In docker-compose or deployment
TEMPORAL_AUTH_ENABLED=true
TEMPORAL_AUTH_PROVIDER_URL=https://accounts.google.com
TEMPORAL_AUTH_CLIENT_ID=your-client-id
TEMPORAL_AUTH_CLIENT_SECRET=your-client-secret
TEMPORAL_AUTH_CALLBACK_URL=https://temporal.YOUR_DOMAIN/sso/callback
```

### Method 2: Config File

Mount the OIDC config file:

```yaml
# docker-compose.yaml
temporal-ui:
  image: temporalio/ui:latest
  volumes:
    - ./temporal-ui-config-oidc.yaml:/etc/temporal/config/ui.yaml
  environment:
    - GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}
    - GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET}
```

---

## Testing OAuth

1. Start your services:

   ```bash
   cd deploy && docker-compose up -d
   ```

2. Start the tunnel:

   ```bash
   ./production/cloudflare-tunnel/run-tunnel.sh
   ```

3. Visit `https://temporal.YOUR_DOMAIN`
   - You should see a "Sign in" button
   - Click to authenticate via your provider

---

## Troubleshooting

### "Redirect URI mismatch"

- Ensure callback URLs exactly match what's configured in your OAuth provider
- Check for trailing slashes

### "Invalid client_id"

- Verify environment variables are loaded
- Check for typos in client ID

### "Access denied"

- Check Cloudflare Access policies
- Verify user email is in allowed list

### Tunnel not connecting

```bash
# Check tunnel status
cloudflared tunnel info temporal-cloud

# View logs
tail -f /tmp/cloudflared-temporal.log
```

---

## Security Best Practices

1. **Use Cloudflare Access** for production - adds WAF, DDoS protection
2. **Rotate secrets** regularly
3. **Limit OAuth scopes** to minimum required
4. **Enable MFA** on your OAuth provider
5. **Monitor access logs** in Cloudflare dashboard
