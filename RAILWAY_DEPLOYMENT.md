# Railway Zero-Secrets Deployment Guide

## Overview

This guide implements the "Railway Zero-Secrets Bootstrapper" system for deploying Suna on Railway with built-in cost protection and automatic maintenance mode activation when free tier limits are approached.

## Quick Start

```bash
# 1. Install Railway CLI
npm install -g @railway/cli

# 2. Login to Railway
railway login

# 3. Initialize project
railway init

# 4. Link to this repository
railway link

# 5. Configure secrets (see below)
railway variables set SUPABASE_URL="your-value"

# 6. Deploy
railway up
```

## Prerequisites

- Railway account (free tier available)
- GitHub repository linked to Railway
- All secrets from `.agents` file prepared
- `master.secrets.json` filled out locally (never commit)

## Railway Cost Protection System

### Free Tier Limits (2025)

- **Monthly Credit:** $5
- **Execution Time:** Primary cost factor
- **Memory:** Billed by GB-hour
- **CPU:** Billed by vCPU-hour
- **Network:** Generally free within limits

### Cost Protection Features

This deployment includes automatic guardrails:

1. **Minimal Resource Allocation**
   - CPU: 0.5 vCPU per service (minimum)
   - Memory: 256-512 MB per service
   - No auto-scaling

2. **Usage Monitoring**
   - Automatic cost tracking
   - Free tier ceiling detection
   - Alert thresholds at 80%

3. **Auto-Shutdown**
   - Triggers when free tier at risk
   - Deploys maintenance page
   - Prepares Coolify migration

## Deployment Architecture

```
Railway Project: suna-ai-platform
├── Backend Service (FastAPI)
│   ├── CPU: 0.5 vCPU
│   ├── Memory: 512 MB
│   └── Health: /health
├── Worker Service (Dramatiq)
│   ├── CPU: 0.25 vCPU
│   ├── Memory: 256 MB
│   └── Processes: 2
├── Frontend Service (Next.js)
│   ├── CPU: 0.5 vCPU
│   ├── Memory: 512 MB
│   └── Health: /
└── Redis Plugin
    ├── Memory: 256 MB
    └── Persistence: Enabled
```

## Step-by-Step Deployment

### Step 1: Prepare Secrets

Reference `.agents` file for complete list. Minimum required:

```bash
# Core Database (REQUIRED)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_JWT_SECRET=your-super-secret-jwt-token-with-at-least-32-characters-long

# Security (REQUIRED)
ENCRYPTION_KEY=base64_encoded_32_byte_key
KORTIX_ADMIN_API_KEY=hex_encoded_admin_key

# LLM Provider (at least one REQUIRED)
ANTHROPIC_API_KEY=sk-ant-api03-...
# OR
OPENAI_API_KEY=sk-...

# Search & Scraping (REQUIRED)
TAVILY_API_KEY=tvly-...
FIRECRAWL_API_KEY=fc-...
RAPID_API_KEY=your-rapid-api-key

# Sandbox (REQUIRED)
DAYTONA_API_KEY=your-daytona-key
DAYTONA_SERVER_URL=https://app.daytona.io/api
DAYTONA_TARGET=us
```

### Step 2: Create Railway Project

```bash
# Initialize new Railway project
railway init

# Enter project details:
# Name: suna-ai-platform
# Environment: production
```

### Step 3: Add Redis Plugin

```bash
# Via CLI
railway add redis

# Or via Dashboard:
# 1. Go to Railway dashboard
# 2. Select your project
# 3. Click "New" → "Database" → "Redis"
```

### Step 4: Configure Environment Variables

**Option A: Via CLI (Bulk Import)**

```bash
# Export from master.secrets.json
cat master.secrets.json | jq -r '.projects."suna-kortix".environments.railway | to_entries[] | .value | to_entries[] | select(.value != "") | .key + "=" + .value' > railway-env.txt

# Import to Railway
while IFS='=' read -r key value; do
  railway variables set "$key=$value"
done < railway-env.txt

# Clean up
rm railway-env.txt
```

**Option B: Via Dashboard (Manual)**

1. Go to Railway dashboard
2. Select your project
3. Click "Variables" tab
4. Add each variable from `.agents` file
5. Mark sensitive values as "Secret"

**Option C: Using Script**

```bash
# Use the provided script
./scripts/railway-deploy.sh --set-secrets
```

### Step 5: Configure Services

**Backend Service:**

```bash
# Set build settings
railway service settings backend \
  --build-command "uv sync --frozen" \
  --start-command "uv run api.py" \
  --healthcheck-path "/health" \
  --healthcheck-timeout 100

# Set resource limits (cost protection)
railway service settings backend \
  --cpu 0.5 \
  --memory 512
```

**Worker Service:**

```bash
railway service settings worker \
  --build-command "uv sync --frozen" \
  --start-command "uv run dramatiq --processes 2 --threads 2 run_agent_background" \
  --cpu 0.25 \
  --memory 256
```

**Frontend Service:**

```bash
railway service settings frontend \
  --build-command "npm ci && npm run build" \
  --start-command "npm start" \
  --healthcheck-path "/" \
  --cpu 0.5 \
  --memory 512
```

### Step 6: Deploy

```bash
# Deploy all services
railway up

# Monitor deployment
railway logs -f

# Check status
railway status
```

### Step 7: Verify Deployment

```bash
# Get deployment URL
railway domain

# Test backend health
curl https://your-app.railway.app/health

# Test frontend
curl https://your-frontend.railway.app/

# Check all services
railway ps
```

### Step 8: Configure Custom Domain (Optional)

```bash
# Add custom domain
railway domain add your-domain.com

# Configure DNS:
# Add CNAME record: your-domain.com → your-app.railway.app

# Verify SSL
curl -I https://your-domain.com
```

## Cost Monitoring Setup

### Automated Monitoring Script

Create `scripts/railway-cost-monitor.sh`:

```bash
#!/bin/bash
# Railway Cost Monitoring and Auto-Shutdown Script

set -euo pipefail

# Configuration
RAILWAY_TOKEN="${RAILWAY_TOKEN:-}"
PROJECT_ID="${RAILWAY_PROJECT_ID:-}"
FREE_TIER_LIMIT=5.00  # $5 USD
WARNING_THRESHOLD=0.80  # 80% of limit
SHUTDOWN_THRESHOLD=0.95  # 95% of limit

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check required variables
if [ -z "$RAILWAY_TOKEN" ] || [ -z "$PROJECT_ID" ]; then
  echo -e "${RED}ERROR: RAILWAY_TOKEN and RAILWAY_PROJECT_ID must be set${NC}"
  exit 1
fi

# Fetch current usage from Railway API
get_usage() {
  curl -s -X POST https://backboard.railway.app/graphql/v2 \
    -H "Authorization: Bearer $RAILWAY_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"query\":\"query { project(id: \\\"$PROJECT_ID\\\") { usage { current } } }\"}" \
    | jq -r '.data.project.usage.current'
}

# Calculate percentage
calculate_percentage() {
  local usage=$1
  echo "scale=2; ($usage / $FREE_TIER_LIMIT) * 100" | bc
}

# Send alert
send_alert() {
  local level=$1
  local message=$2
  
  echo -e "${YELLOW}[ALERT-$level] $message${NC}"
  
  # Send to configured alert channels
  # Example: Email, Slack, Discord, etc.
  # This is a placeholder - implement your notification system
  
  # Example: Send email (requires mailutils)
  # echo "$message" | mail -s "Suna Railway Alert - $level" admin@your-domain.com
  
  # Example: Slack webhook
  # curl -X POST "$SLACK_WEBHOOK_URL" -H 'Content-Type: application/json' \
  #   -d "{\"text\":\"$message\"}"
}

# Enable maintenance mode
enable_maintenance_mode() {
  echo -e "${RED}Enabling maintenance mode...${NC}"
  
  # Deploy maintenance page
  railway service deploy maintenance --detach
  
  # Pause main services
  railway service pause backend
  railway service pause worker
  railway service pause frontend
  
  echo -e "${GREEN}Maintenance mode activated${NC}"
  
  # Send alert
  send_alert "CRITICAL" "Free tier limit reached. Maintenance mode activated. Please migrate to Coolify."
}

# Main monitoring logic
main() {
  echo "=== Railway Cost Monitor ==="
  echo "Checking usage for project: $PROJECT_ID"
  
  # Get current usage
  CURRENT_USAGE=$(get_usage)
  
  if [ -z "$CURRENT_USAGE" ] || [ "$CURRENT_USAGE" == "null" ]; then
    echo -e "${RED}ERROR: Could not fetch usage data${NC}"
    exit 1
  fi
  
  # Calculate percentage
  PERCENTAGE=$(calculate_percentage "$CURRENT_USAGE")
  
  echo "Current usage: \$$CURRENT_USAGE / \$$FREE_TIER_LIMIT ($PERCENTAGE%)"
  
  # Check thresholds
  if (( $(echo "$PERCENTAGE >= 95" | bc -l) )); then
    echo -e "${RED}CRITICAL: Usage at $PERCENTAGE%${NC}"
    enable_maintenance_mode
    exit 2
    
  elif (( $(echo "$PERCENTAGE >= 80" | bc -l) )); then
    echo -e "${YELLOW}WARNING: Usage at $PERCENTAGE%${NC}"
    send_alert "WARNING" "Railway usage at $PERCENTAGE%. Consider migration to Coolify soon."
    
  elif (( $(echo "$PERCENTAGE >= 50" | bc -l) )); then
    echo -e "${YELLOW}INFO: Usage at $PERCENTAGE%${NC}"
    
  else
    echo -e "${GREEN}OK: Usage at $PERCENTAGE%${NC}"
  fi
  
  # Log usage
  echo "$(date -Iseconds),$CURRENT_USAGE,$PERCENTAGE" >> railway-usage.log
}

# Run main function
main "$@"
```

### Set Up Monitoring Cron Job

```bash
# Make script executable
chmod +x scripts/railway-cost-monitor.sh

# Add to crontab (check every hour)
crontab -e

# Add this line:
0 * * * * cd /path/to/suna && ./scripts/railway-cost-monitor.sh >> /var/log/railway-monitor.log 2>&1
```

### Manual Monitoring

```bash
# Check current usage
railway usage

# View detailed breakdown
railway usage --service=backend
railway usage --service=worker
railway usage --service=frontend
```

## Maintenance Mode

### Manual Activation

```bash
# Enable maintenance mode
./scripts/maintenance-mode.sh enable

# Check status
railway ps

# Disable maintenance mode
./scripts/maintenance-mode.sh disable
```

### What Happens in Maintenance Mode

1. **Main services paused** (backend, worker, frontend)
2. **Maintenance page deployed** (static HTML)
3. **Cost accumulation stops**
4. **Users see maintenance message**
5. **Admin receives alert**
6. **Migration checklist prepared** (COOLIFY_MIGRATION.md)

### Maintenance Page Customization

Edit `maintenance.html` to customize:

- Branding
- Message
- Contact information
- ETA for return
- Migration status

## Troubleshooting

### Deployment Fails

```bash
# Check build logs
railway logs --service=backend --build

# Check runtime logs
railway logs --service=backend --tail

# Verify environment variables
railway variables

# Restart service
railway service restart backend
```

### Out of Memory Errors

```bash
# Check memory usage
railway logs --service=backend | grep "OOM"

# Increase memory limit (careful with costs)
railway service settings backend --memory 1024

# Or optimize application
```

### Database Connection Issues

```bash
# Verify Supabase URL
railway variables get SUPABASE_URL

# Test connection
railway run curl -I $SUPABASE_URL

# Check firewall rules (Railway generally allows all outbound)
```

### Redis Connection Failed

```bash
# Verify Redis plugin is added
railway plugins

# Check Redis connection string
railway variables get REDIS_URL

# Test Redis
railway run redis-cli ping
```

### Cost Unexpectedly High

```bash
# Review usage by service
railway usage --service=backend
railway usage --service=worker
railway usage --service=frontend

# Check for runaway processes
railway logs --service=worker | grep "error"

# Reduce resources
railway service settings backend --cpu 0.25 --memory 256
```

## Optimization Tips

### Reduce Costs

1. **Minimize Worker Processes**
   ```bash
   # Reduce from 4 to 2 processes
   START_COMMAND="uv run dramatiq --processes 2 --threads 2 run_agent_background"
   ```

2. **Enable Aggressive Caching**
   ```bash
   # In backend/.env
   REDIS_CACHE_TTL=3600  # 1 hour
   ```

3. **Optimize Database Queries**
   - Use connection pooling
   - Minimize round trips
   - Add indexes

4. **Reduce Logging**
   ```bash
   # Set log level to WARNING
   LOG_LEVEL=WARNING
   ```

### Monitor Efficiently

```bash
# Check usage daily
railway usage

# Set up alerts in Railway dashboard
# Settings → Usage → Alerts → Set threshold at 80%

# Review cost reports weekly
# Dashboard → Billing → Usage History
```

## Migration Trigger Conditions

Migrate to Coolify when:

1. **Cost threshold exceeded** (>95% of free tier)
2. **Consistent high usage** (>80% for 3+ days)
3. **Need for more control** (custom configs, VPN access)
4. **Predictable workload** (fixed hosting cost makes sense)

When triggered, follow: [COOLIFY_MIGRATION.md](./COOLIFY_MIGRATION.md)

## Security Best Practices

1. **Secret Management**
   - Never commit secrets to repo
   - Use Railway's built-in secrets
   - Rotate regularly (quarterly)
   - Use different secrets per environment

2. **Access Control**
   - Limit Railway project access
   - Use teams for collaboration
   - Enable 2FA on Railway account
   - Review audit logs regularly

3. **Network Security**
   - Use HTTPS only (Railway provides automatically)
   - Configure CORS properly
   - Rate limit API endpoints
   - Monitor for suspicious activity

4. **Dependency Security**
   - Keep dependencies updated
   - Run security audits: `npm audit`, `pip audit`
   - Monitor for CVEs
   - Use Dependabot

## Support & Resources

- **Railway Documentation:** https://docs.railway.app/
- **Railway Discord:** https://discord.gg/railway
- **Railway Status:** https://status.railway.app/
- **Suna GitHub:** https://github.com/kortix-ai/suna
- **Cost Calculator:** https://railway.app/pricing

## Deployment Checklist

### Pre-Deployment

- [ ] All secrets prepared in `master.secrets.json`
- [ ] Railway CLI installed and authenticated
- [ ] `.agents` file reviewed
- [ ] Cost monitoring script configured
- [ ] Maintenance page customized
- [ ] Team notified of deployment

### During Deployment

- [ ] Railway project created
- [ ] Redis plugin added
- [ ] Environment variables set
- [ ] Services configured with resource limits
- [ ] All services deployed successfully
- [ ] Health checks passing
- [ ] Domain configured (if applicable)
- [ ] SSL certificate issued

### Post-Deployment

- [ ] All functionality tested
- [ ] Cost monitoring active
- [ ] Alerts configured
- [ ] Documentation updated
- [ ] Team trained on Railway operations
- [ ] Backup procedures documented
- [ ] Migration plan prepared (COOLIFY_MIGRATION.md)

## Next Steps

1. **Monitor costs daily** for first week
2. **Adjust resource limits** based on actual usage
3. **Set up monitoring alerts** at 80% threshold
4. **Prepare migration plan** to Coolify when needed
5. **Document any custom configurations**
6. **Review security settings** weekly

---

**Document Version:** 1.0.0  
**Last Updated:** December 2024  
**Tested With:** Railway (2024), Suna v0.1.3+
