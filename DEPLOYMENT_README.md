# Suna Railway Zero-Secrets Deployment System

## Overview

This repository implements the **Railway Zero-Secrets Bootstrapper** system, enabling:

- ✅ **Zero-secrets repository**: All secrets managed externally
- ✅ **Automated Railway deployment**: One-command deployment with cost guardrails
- ✅ **Free-tier protection**: Automatic monitoring and shutdown before cost overruns
- ✅ **Maintenance mode**: Graceful degradation when limits reached
- ✅ **Migration support**: Seamless transition to Coolify when needed
- ✅ **Multi-host compatibility**: Railway, Coolify, and Hostinger VPN support

## Quick Start

### 1. Prepare Secrets

```bash
# Copy template to working file
cp master.secrets.json.template master.secrets.json

# Edit and fill in your secrets
nano master.secrets.json

# NEVER commit this file - it's in .gitignore
```

### 2. Deploy to Railway

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Deploy with automated script
./scripts/railway-deploy.sh
```

### 3. Monitor Costs

```bash
# Check current usage
railway usage

# Set up automated monitoring
export RAILWAY_TOKEN="your-token"
export RAILWAY_PROJECT_ID="your-project-id"

# Add to crontab (check hourly)
crontab -e
# Add: 0 * * * * /path/to/suna/scripts/railway-cost-monitor.sh
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Repository (GitHub)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   .agents    │  │ railway.toml │  │ maintenance  │    │
│  │  (secrets    │  │   (deploy    │  │    .html     │    │
│  │  manifest)   │  │    config)   │  │  (fallback)  │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                             │
│  NO SECRETS COMMITTED TO REPOSITORY                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Local Secret Management                        │
│  ┌──────────────────────────────────────────────────┐      │
│  │  master.secrets.json (LOCAL ONLY - .gitignore)   │      │
│  │  - Development secrets                            │      │
│  │  - Production secrets                             │      │
│  │  - Railway secrets                                │      │
│  │  - Coolify secrets                                │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┴───────────────────┐
        ▼                                       ▼
┌──────────────────┐                  ┌──────────────────┐
│   Railway        │                  │   Coolify        │
│   (Cloud PaaS)   │                  │   (Self-Hosted)  │
│   ┌──────────┐   │                  │   ┌──────────┐   │
│   │ Backend  │   │                  │   │ Backend  │   │
│   ├──────────┤   │                  │   ├──────────┤   │
│   │ Worker   │   │                  │   │ Worker   │   │
│   ├──────────┤   │                  │   ├──────────┤   │
│   │ Frontend │   │                  │   │ Frontend │   │
│   ├──────────┤   │                  │   ├──────────┤   │
│   │ Redis    │   │                  │   │ Redis    │   │
│   └──────────┘   │                  │   └──────────┘   │
│                  │                  │                  │
│ Cost Monitor ──► │                  │ ◄── Hostinger   │
│ (auto-shutdown)  │                  │     VPN         │
└──────────────────┘                  └──────────────────┘
        │                                       │
        └──── Maintenance Mode ────────────────┘
              (when limits reached)
```

## File Structure

```
suna/
├── .agents                          # Secrets specification (manifest)
│   └── JSON schema of all required secrets
├── master.secrets.json.template     # Template for local secrets
├── master.secrets.json              # YOUR LOCAL SECRETS (never commit)
├── railway.toml                     # Railway deployment config
├── maintenance.html                 # Maintenance mode page
├── RAILWAY_DEPLOYMENT.md           # Railway deployment guide
├── COOLIFY_SUPPORT.md              # Coolify deployment guide
├── COOLIFY_MIGRATION.md            # Migration from Railway to Coolify
├── DEPLOYMENT_README.md            # This file
├── scripts/
│   ├── railway-deploy.sh           # Automated Railway deployment
│   ├── railway-cost-monitor.sh     # Cost monitoring & auto-shutdown
│   └── maintenance-mode.sh         # Maintenance mode control
└── [application code...]
```

## Key Files Explained

### `.agents` - Secrets Specification

Machine-readable manifest of all secrets required by the application. Contains:

- Secret names and descriptions
- Format specifications
- Required vs optional flags
- Placeholder values
- Categorization (database, llm, search, etc.)
- Provider signup URLs

**Purpose:** Enable automated secret provisioning without storing actual values.

### `master.secrets.json` - Local Secret Store

Local file (NOT committed) containing actual secret values for all environments:

- Development
- Production  
- Railway
- Coolify

**Security:**
- ✅ Listed in `.gitignore`
- ✅ Never committed to repository
- ✅ Only exists on developer/admin machines
- ✅ Encrypted backup recommended

### `railway.toml` - Deployment Configuration

Railway deployment configuration with:

- Service definitions (backend, worker, frontend)
- Resource limits (CPU, memory) for cost protection
- Health check configurations
- Environment variable placeholders
- Build and start commands
- Cost guardrails enforced

### `maintenance.html` - Fallback Page

Static HTML page served when:

- Free tier limit reached (auto-triggered)
- Manual maintenance mode enabled
- Migration to Coolify in progress

Features:
- Auto-refresh every 5 minutes
- Service status information
- Migration status
- Contact information
- Professional branding

## Deployment Workflows

### Railway Deployment (Free Tier)

```bash
# 1. Initial setup
railway login
railway init

# 2. Configure secrets from master.secrets.json
./scripts/railway-deploy.sh --set-secrets

# 3. Deploy application
./scripts/railway-deploy.sh

# 4. Monitor costs
railway usage

# 5. Set up automated monitoring
# See RAILWAY_DEPLOYMENT.md for cron setup
```

**Cost Protection Active:**
- ✅ Minimal resources allocated
- ✅ Hourly usage checks
- ✅ Auto-shutdown at 95% free tier
- ✅ Maintenance page auto-deployed

### Coolify Migration (When Needed)

```bash
# 1. Trigger conditions
# - Free tier exceeded
# - Need predictable costs
# - Want more control

# 2. Follow migration guide
cat COOLIFY_MIGRATION.md

# 3. Key steps
# - Prepare Coolify instance
# - Configure environment variables
# - Deploy services
# - Test thoroughly
# - Switch DNS
# - Decommission Railway

# 4. Migration time: 2-4 hours
```

**When to Migrate:**
- Railway usage consistently >80% of free tier
- Need for VPN access (Hostinger)
- Require custom infrastructure
- Want fixed monthly costs

## Secret Management Workflow

### For Developers

```bash
# 1. Clone repository
git clone https://github.com/kortix-ai/suna.git
cd suna

# 2. Create local secrets file
cp master.secrets.json.template master.secrets.json

# 3. Fill in your development secrets
nano master.secrets.json

# 4. Verify file is ignored
git status  # Should not show master.secrets.json

# 5. Run local setup
python setup.py
```

### For Deployment

```bash
# Railway
./scripts/railway-deploy.sh --set-secrets

# Coolify
# Via Coolify UI: Settings > Environment Variables
# Paste from master.secrets.json

# Manual
railway variables set SUPABASE_URL="..."
# Repeat for all secrets from .agents file
```

### Secret Rotation

```bash
# 1. Update secrets in providers (Supabase, Anthropic, etc.)

# 2. Update master.secrets.json

# 3. Update deployment
# Railway:
railway variables set API_KEY="new-value"
railway service restart backend

# Coolify:
# Update via UI, then restart services
```

**Rotation Schedule:**
- Quarterly: All API keys
- Immediately: After team member leaves
- Immediately: After suspected compromise

## Cost Management

### Railway Free Tier Strategy

**Limits:**
- $5/month credit
- ~500 hours of 0.5 vCPU
- ~1000 hours of 256MB memory

**Optimization:**
1. **Minimal Resources**
   - Backend: 0.5 vCPU, 512MB
   - Worker: 0.25 vCPU, 256MB
   - Frontend: 0.5 vCPU, 512MB
   - Redis: Railway plugin (included)

2. **Monitoring**
   - Check usage daily
   - Alert at 80% threshold
   - Auto-shutdown at 95%

3. **Usage Reduction**
   - Reduce worker processes
   - Enable aggressive caching
   - Optimize database queries
   - Reduce log verbosity

### Cost Comparison

| Hosting | Monthly Cost | Pros | Cons |
|---------|-------------|------|------|
| Railway Free | $0 ($5 credit) | Easy setup, managed | Limited resources |
| Railway Pro | $20-50 | More resources | Variable costs |
| Coolify + VPS | $30-40 | Predictable, control | More setup, maintenance |
| Coolify + VPN | $40-50 | Private network | Highest cost |

**Recommendation:**
- **Start:** Railway free tier
- **Grow:** Railway Pro or Coolify
- **Scale:** Coolify with dedicated VPS

## Maintenance Mode

### Automatic Activation

Triggered when:
- Cost usage ≥95% of free tier
- Manual trigger by admin
- Migration preparation

**Actions:**
1. Main services paused
2. Maintenance page deployed
3. Admin notified
4. Migration checklist prepared

### Manual Control

```bash
# Enable
./scripts/maintenance-mode.sh enable

# Check status
./scripts/maintenance-mode.sh status

# Disable
./scripts/maintenance-mode.sh disable
```

## Monitoring & Alerts

### Cost Monitoring

```bash
# Manual check
railway usage

# Automated monitoring (cron)
0 * * * * /path/to/scripts/railway-cost-monitor.sh

# Email alerts (configure in script)
# - 80% warning
# - 95% critical
# - Auto-shutdown notification
```

### Health Monitoring

```bash
# Service health
railway logs --service=backend | grep health

# Resource usage
railway logs --service=backend | grep -i memory

# Error tracking
railway logs --service=backend | grep ERROR
```

### Coolify Monitoring

```bash
# Via Coolify dashboard
# - CPU/Memory graphs
# - Health status
# - Logs viewer
# - Resource alerts
```

## Troubleshooting

### Deployment Fails

```bash
# Check Railway status
railway status

# View build logs
railway logs --service=backend --build

# Check environment variables
railway variables

# Verify secrets are set
railway variables | grep SUPABASE_URL
```

### Cost Unexpectedly High

```bash
# Check usage breakdown
railway usage --service=backend
railway usage --service=worker
railway usage --service=frontend

# Reduce resources
railway service settings backend --cpu 0.25 --memory 256

# Enable maintenance mode
./scripts/maintenance-mode.sh enable
```

### Migration Issues

See detailed troubleshooting in:
- `RAILWAY_DEPLOYMENT.md` - Railway-specific
- `COOLIFY_MIGRATION.md` - Migration-specific
- `COOLIFY_SUPPORT.md` - Coolify-specific

## Security Best Practices

### Secret Management

- ✅ Never commit secrets to repository
- ✅ Use `.gitignore` for `master.secrets.json`
- ✅ Different secrets per environment
- ✅ Rotate secrets quarterly
- ✅ Encrypted backups of master.secrets.json
- ✅ Audit secret access regularly

### Deployment Security

- ✅ Use Railway's encrypted variables
- ✅ Enable 2FA on Railway/Coolify accounts
- ✅ Limit team access (principle of least privilege)
- ✅ Use HTTPS only (automatic on Railway/Coolify)
- ✅ Regular security audits
- ✅ Keep dependencies updated

### Network Security

- ✅ Configure CORS properly
- ✅ Rate limit API endpoints
- ✅ Use Hostinger VPN for private access (Coolify)
- ✅ Firewall rules on VPS (Coolify)
- ✅ SSL/TLS certificates (automatic)

## Development vs Production

### Development (Local)

```bash
# Use local secrets
cp backend/.env.example backend/.env
nano backend/.env  # Fill from master.secrets.json

# Run setup wizard
python setup.py

# Start services
python start.py
```

### Production (Railway)

```bash
# Use Railway environment
./scripts/railway-deploy.sh

# Secrets managed in Railway dashboard
# No .env files needed in production
```

### Production (Coolify)

```bash
# Use Coolify environment
# Configure via Coolify UI

# Secrets in Coolify's encrypted storage
# Deploy via docker-compose
```

## Documentation Index

- **[RAILWAY_DEPLOYMENT.md](./RAILWAY_DEPLOYMENT.md)** - Complete Railway guide
- **[COOLIFY_SUPPORT.md](./COOLIFY_SUPPORT.md)** - Coolify deployment guide
- **[COOLIFY_MIGRATION.md](./COOLIFY_MIGRATION.md)** - Railway to Coolify migration
- **[.agents](./.agents)** - Secrets specification manifest
- **[maintenance.html](./maintenance.html)** - Maintenance mode page

## Support & Resources

### Official Documentation
- **Railway:** https://docs.railway.app/
- **Coolify:** https://coolify.io/docs
- **Suna:** https://github.com/kortix-ai/suna

### Community
- **Railway Discord:** https://discord.gg/railway
- **Coolify Discord:** https://discord.gg/coolify
- **Suna GitHub Issues:** https://github.com/kortix-ai/suna/issues

### Getting Help

1. Check documentation above
2. Search GitHub issues
3. Ask in Discord communities
4. Create GitHub issue with `[DEPLOYMENT]` tag

## Contributing

Improvements to this deployment system:

1. Fork repository
2. Create feature branch
3. Test deployment changes
4. Submit pull request
5. Update documentation

**Areas for contribution:**
- Additional hosting platform support
- Improved cost monitoring
- Better secret management tools
- Enhanced maintenance mode
- Migration automation

## License

Apache License 2.0 - See [LICENSE](./LICENSE)

---

**System Version:** 1.0.0  
**Last Updated:** December 2024  
**Compatibility:** Railway (2024), Coolify v4.0+, Suna v0.1.3+
