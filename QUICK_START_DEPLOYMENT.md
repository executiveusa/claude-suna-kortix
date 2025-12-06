# Quick Start: Railway Zero-Secrets Deployment

## 5-Minute Railway Deployment

### Prerequisites
- GitHub account
- Railway account (free tier)
- All secrets ready

### Step 1: Prepare Secrets (2 minutes)
```bash
# Copy template
cp master.secrets.json.template master.secrets.json

# Edit with your secrets
nano master.secrets.json

# Fill in required fields:
# - SUPABASE_URL
# - SUPABASE_ANON_KEY
# - SUPABASE_SERVICE_ROLE_KEY
# - At least one LLM API key
# - TAVILY_API_KEY
# - FIRECRAWL_API_KEY
# - DAYTONA_API_KEY
```

### Step 2: Deploy (3 minutes)
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Deploy
./scripts/railway-deploy.sh
```

That's it! Your Suna instance will be live at the Railway URL.

## What You Get

✅ **Full Suna Platform**
- Backend API (FastAPI)
- Worker (Dramatiq)
- Frontend (Next.js)
- Redis (Cache)

✅ **Cost Protection**
- Automatic monitoring
- Free tier guardrails
- Auto-shutdown at 95%

✅ **Maintenance Mode**
- Graceful degradation
- Static fallback page
- Cost savings

## Next Steps

### Monitor Your Deployment
```bash
# Check status
railway status

# View logs
railway logs -f

# Check usage
railway usage
```

### Set Up Monitoring (5 minutes)
```bash
# Get your tokens
export RAILWAY_TOKEN="$(railway whoami --token)"
export RAILWAY_PROJECT_ID="$(railway status --json | jq -r .projectId)"

# Set up cron (check every hour)
crontab -e
# Add: 0 * * * * cd /path/to/suna && ./scripts/railway-cost-monitor.sh
```

### Custom Domain (Optional)
```bash
# Add domain
railway domain add your-domain.com

# Update DNS
# Add CNAME: your-domain.com → your-app.railway.app

# Update env vars
railway variables set NEXT_PUBLIC_URL="https://your-domain.com"
railway variables set NEXT_PUBLIC_BACKEND_URL="https://your-domain.com/api"
```

## Troubleshooting

### Deployment Failed?
```bash
# Check logs
railway logs --service=backend --build

# Verify secrets
railway variables | grep SUPABASE_URL
```

### Services Not Starting?
```bash
# Check health
railway logs --service=backend | grep health

# Restart
railway service restart backend
```

### Cost Too High?
```bash
# Enable maintenance mode
./scripts/maintenance-mode.sh enable

# Migrate to Coolify
# See COOLIFY_MIGRATION.md
```

## File Reference

- **`.agents`** - Complete secrets list
- **`master.secrets.json`** - Your local secrets (NOT committed)
- **`railway.toml`** - Deployment config
- **`RAILWAY_DEPLOYMENT.md`** - Full deployment guide
- **`COOLIFY_MIGRATION.md`** - Migration guide
- **`DEPLOYMENT_README.md`** - System overview

## Cost Estimates

### Railway Free Tier
- **Monthly Credit:** $5
- **Typical Usage:** 60-80% of free tier
- **Cost:** $0/month
- **When to Migrate:** >80% usage for 3+ days

### After Free Tier
- **Railway Pro:** $20-50/month (variable)
- **Coolify + VPS:** $30-40/month (fixed)

## Support

- **Railway Issues:** [Railway Discord](https://discord.gg/railway)
- **Suna Issues:** [GitHub Issues](https://github.com/kortix-ai/suna/issues)
- **Full Docs:** See `DEPLOYMENT_README.md`

## Security Reminders

❌ **NEVER commit `master.secrets.json`**
❌ **NEVER push secrets to GitHub**
✅ **Use Railway's encrypted variables**
✅ **Rotate secrets quarterly**
✅ **Different secrets per environment**

---

**Need Help?** See full documentation in `RAILWAY_DEPLOYMENT.md`
