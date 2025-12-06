# Coolify Migration Guide

## Migration from Railway to Coolify

This guide provides step-by-step instructions for migrating your Suna deployment from Railway to Coolify when free tier limits are reached or cost optimization is needed.

## When to Migrate

Consider migration when:

- ✅ Railway free tier ($5/month) consistently exceeded
- ✅ Need predictable, fixed hosting costs
- ✅ Want more control over infrastructure
- ✅ Require VPN access (Hostinger integration)
- ✅ Maintenance mode activated due to cost limits

## Pre-Migration Checklist

- [ ] Coolify instance ready (v4.0+)
- [ ] Domain name configured (optional)
- [ ] All secrets documented in `master.secrets.json`
- [ ] Recent backup of Railway data
- [ ] SSH access to Coolify server
- [ ] Hostinger VPN configured (if using)
- [ ] DNS records ready to update
- [ ] Team notified of maintenance window

## Migration Timeline

**Estimated Duration:** 2-4 hours

1. **Preparation:** 30 minutes
2. **Data Backup:** 15 minutes
3. **Coolify Setup:** 45 minutes
4. **Service Deployment:** 30 minutes
5. **Testing & Validation:** 30 minutes
6. **DNS Cutover:** 15 minutes
7. **Monitoring:** 30 minutes

## Step-by-Step Migration Process

### Phase 1: Pre-Migration Preparation

#### 1.1 Backup Railway Data

```bash
# Export Railway environment variables
railway variables > railway-env-backup.txt

# Export database dump (if using Railway Postgres)
railway run pg_dump > railway-db-backup.sql

# Backup Redis data (if needed)
railway run redis-cli --rdb dump.rdb

# Save logs for reference
railway logs --service=backend > backend-logs.txt
railway logs --service=worker > worker-logs.txt
railway logs --service=frontend > frontend-logs.txt
```

#### 1.2 Document Current Configuration

```bash
# Create migration documentation
cat > migration-notes.md << EOF
# Migration Notes - $(date)

## Railway Configuration
- Backend URL: $(railway variables | grep NEXT_PUBLIC_BACKEND_URL)
- Frontend URL: $(railway variables | grep NEXT_PUBLIC_URL)
- Database: Supabase (cloud)
- Redis: Railway Redis Plugin

## Services Running
- Backend: ✓
- Worker: ✓
- Frontend: ✓
- Redis: ✓

## Resource Usage (Last 30 days)
- CPU: [Check Railway dashboard]
- Memory: [Check Railway dashboard]
- Estimated cost: [Check Railway dashboard]

## Notes
- [Add any custom configurations]
- [Document any issues or gotchas]
EOF
```

#### 1.3 Notify Users

```bash
# Deploy maintenance page to Railway
railway service maintenance --enable

# Or manually update to serve maintenance.html
railway run --service=frontend cp maintenance.html public/index.html
railway redeploy --service=frontend
```

### Phase 2: Coolify Setup

#### 2.1 Access Coolify Instance

```bash
# SSH into Coolify server
ssh root@your-coolify-server.com

# Verify Coolify is running
docker ps | grep coolify
```

#### 2.2 Create New Project

1. Open Coolify Dashboard: `https://your-coolify-server.com:3000`
2. Login with admin credentials
3. Click "New Resource" → "Docker Compose"
4. Name: `suna-ai-platform`
5. Paste contents from COOLIFY_SUPPORT.md docker-compose.yml

#### 2.3 Configure Environment Variables

Transfer all secrets from Railway to Coolify:

```bash
# In Coolify UI, add environment variables from Railway backup
# Reference: .agents file for complete list

# Core secrets
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
SUPABASE_JWT_SECRET=
ENCRYPTION_KEY=
KORTIX_ADMIN_API_KEY=

# Infrastructure
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_SSL=false

# LLM (at least one)
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
# ... etc from .agents file

# Update URLs for new environment
NEXT_PUBLIC_URL=https://your-new-domain.com
NEXT_PUBLIC_BACKEND_URL=https://your-new-domain.com/api
WEBHOOK_BASE_URL=https://your-new-domain.com
```

### Phase 3: Service Deployment

#### 3.1 Deploy Backend Service

```bash
# In Coolify, deploy backend first
# Click "Deploy" on backend service
# Monitor logs for any errors
```

Expected output:
```
✓ Pulling image
✓ Starting container
✓ Running health check
✓ Service healthy at http://backend:8000/health
```

#### 3.2 Deploy Worker Service

```bash
# Deploy worker after backend is healthy
# Worker depends on backend and Redis
```

Expected output:
```
✓ Worker started
✓ Connected to Redis
✓ Dramatiq actors registered
✓ Ready to process tasks
```

#### 3.3 Deploy Frontend Service

```bash
# Deploy frontend last
# Depends on backend API
```

Expected output:
```
✓ Next.js app built successfully
✓ Server running on port 3000
✓ Healthcheck passing
```

#### 3.4 Verify All Services

```bash
# Check all services are running
docker-compose ps

# Expected output:
# NAME              STATUS    PORTS
# suna-backend      Up        0.0.0.0:8000->8000/tcp
# suna-worker       Up        
# suna-frontend     Up        0.0.0.0:3000->3000/tcp
# suna-redis        Up        6379/tcp

# Test health endpoints
curl http://localhost:8000/health
# Expected: {"status": "healthy"}

curl http://localhost:3000
# Expected: HTML content
```

### Phase 4: Testing & Validation

#### 4.1 Test Core Functionality

```bash
# Test backend API
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test"}'

# Test frontend
curl http://localhost:3000 | grep "Suna"

# Test worker (check logs)
docker-compose logs -f worker | grep "Actor registered"
```

#### 4.2 Test Database Connection

```bash
# Verify Supabase connectivity
docker-compose exec backend python -c "
from core.database import get_supabase_client
client = get_supabase_client()
print('Supabase connected:', client.table('users').select('id').limit(1).execute())
"
```

#### 4.3 Test Redis Cache

```bash
# Verify Redis
docker-compose exec redis redis-cli ping
# Expected: PONG

docker-compose exec backend python -c "
import redis
r = redis.Redis(host='redis', port=6379)
r.set('test', 'success')
print('Redis test:', r.get('test'))
"
# Expected: b'success'
```

#### 4.4 Test LLM Integration

```bash
# Test LLM API (example with Anthropic)
docker-compose exec backend python -c "
import anthropic
client = anthropic.Anthropic()
message = client.messages.create(
    model='claude-3-sonnet-20240229',
    max_tokens=100,
    messages=[{'role': 'user', 'content': 'Hello'}]
)
print('LLM connected:', message.content[0].text[:50])
"
```

### Phase 5: DNS Cutover

#### 5.1 Prepare DNS Changes

```bash
# Document current DNS records
dig your-domain.com A
dig api.your-domain.com A

# Prepare new DNS records
# A Record: your-domain.com → Coolify Server IP
# CNAME: api.your-domain.com → your-domain.com
```

#### 5.2 Lower TTL (24 hours before cutover)

```bash
# In your DNS provider:
# 1. Lower TTL to 300 seconds (5 minutes)
# 2. Wait 24 hours for propagation
```

#### 5.3 Update DNS Records

```bash
# In your DNS provider dashboard:
# 1. Update A record to point to Coolify server IP
# 2. Update any CNAMEs for subdomains
# 3. Verify changes with:

dig your-domain.com A
# Should show new Coolify IP after propagation
```

#### 5.4 Monitor DNS Propagation

```bash
# Check DNS propagation globally
# Use: https://www.whatsmydns.net/

# Or via CLI:
for ns in 8.8.8.8 1.1.1.1 208.67.222.222; do
  echo "Checking $ns:"
  dig @$ns your-domain.com A +short
done
```

#### 5.5 Update Environment Variables

```bash
# In Coolify, update URLs to use new domain
NEXT_PUBLIC_URL=https://your-domain.com
NEXT_PUBLIC_BACKEND_URL=https://your-domain.com/api
WEBHOOK_BASE_URL=https://your-domain.com

# Redeploy services to pick up new env vars
docker-compose up -d --force-recreate
```

### Phase 6: Post-Migration

#### 6.1 Monitor Application Health

```bash
# Monitor logs in real-time
docker-compose logs -f

# Check error rates
docker-compose logs backend | grep ERROR | wc -l

# Monitor resource usage
docker stats

# Expected healthy state:
# - CPU: < 50%
# - Memory: < 80%
# - No critical errors in logs
```

#### 6.2 Verify User Experience

**Manual Testing Checklist:**

- [ ] Homepage loads correctly
- [ ] User can sign in
- [ ] User can create new agent
- [ ] Agent can process requests
- [ ] Chat interface works
- [ ] File uploads work
- [ ] Background tasks execute
- [ ] Email notifications sent (if configured)

#### 6.3 Performance Testing

```bash
# Basic load test (requires 'ab' tool)
ab -n 1000 -c 10 https://your-domain.com/

# Expected results:
# - Requests per second: > 50
# - Failed requests: 0
# - Time per request: < 200ms
```

#### 6.4 Configure Monitoring

```bash
# Set up Coolify monitoring
# In Coolify dashboard:
# 1. Enable health checks for all services
# 2. Set up email alerts for failures
# 3. Configure resource usage alerts

# Create monitoring script
cat > /root/monitor-suna.sh << 'EOF'
#!/bin/bash

# Check service health
BACKEND_HEALTH=$(curl -s http://localhost:8000/health | jq -r '.status')
if [ "$BACKEND_HEALTH" != "healthy" ]; then
  echo "ALERT: Backend unhealthy" | mail -s "Suna Alert" admin@your-domain.com
fi

# Check resource usage
CPU_USAGE=$(docker stats --no-stream --format "{{.CPUPerc}}" suna-backend | tr -d '%')
if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
  echo "ALERT: High CPU usage: $CPU_USAGE%" | mail -s "Suna Alert" admin@your-domain.com
fi

# Check disk space
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
if [ $DISK_USAGE -gt 85 ]; then
  echo "ALERT: Low disk space: $DISK_USAGE% used" | mail -s "Suna Alert" admin@your-domain.com
fi

EOF

chmod +x /root/monitor-suna.sh

# Add to crontab (run every 5 minutes)
echo "*/5 * * * * /root/monitor-suna.sh" | crontab -
```

### Phase 7: Decommission Railway

#### 7.1 Wait Period (Recommended: 48 hours)

```bash
# Keep Railway running for 48 hours as backup
# Monitor Coolify for any issues during this period
# Be ready to rollback if needed
```

#### 7.2 Final Verification

```bash
# Verify all functionality on Coolify
# Compare metrics with Railway baseline
# Ensure no data loss or functionality regression
```

#### 7.3 Stop Railway Services

```bash
# After successful 48-hour run on Coolify:

# Pause Railway services (keeps data, stops billing)
railway service pause --all

# Or fully delete if confident
# railway down

# Export final backup before deletion
railway variables > railway-final-backup.txt
railway logs --service=backend > railway-final-logs.txt
```

#### 7.4 Update Documentation

```bash
# Update your internal documentation
# - New deployment URLs
# - New monitoring dashboards
# - Updated runbooks
# - Emergency procedures for Coolify

# Update README.md if needed
# - Remove Railway-specific instructions
# - Add Coolify deployment notes
```

## Rollback Procedure

If issues occur during migration:

### Quick Rollback to Railway

```bash
# 1. Keep Railway services running (don't delete)
# 2. If issues on Coolify, revert DNS:
#    - Point DNS back to Railway
#    - Wait for propagation (5-30 minutes)

# 3. Verify Railway is still working:
railway status
railway logs --service=backend

# 4. Investigate Coolify issues:
docker-compose logs

# 5. Fix issues and try migration again
```

### Rollback Checklist

- [ ] DNS reverted to Railway
- [ ] Railway services verified working
- [ ] Users notified of temporary issue
- [ ] Migration issues documented
- [ ] Plan created for retry

## Common Migration Issues

### Issue 1: Environment Variables Missing

**Symptom:** Services crash on startup
**Solution:**
```bash
# Verify all env vars are set
docker-compose config

# Compare with .agents file
# Add missing variables in Coolify UI
```

### Issue 2: Database Connection Failed

**Symptom:** "Could not connect to Supabase"
**Solution:**
```bash
# Check Supabase URL is correct
echo $SUPABASE_URL

# Test connectivity
curl -I $SUPABASE_URL

# Verify firewall allows outbound HTTPS
sudo ufw status
```

### Issue 3: Redis Connection Issues

**Symptom:** "Redis connection refused"
**Solution:**
```bash
# Check Redis is running
docker-compose ps redis

# Test Redis connection
docker-compose exec redis redis-cli ping

# Verify REDIS_HOST is correct (should be "redis")
docker-compose exec backend env | grep REDIS_HOST
```

### Issue 4: SSL Certificate Not Working

**Symptom:** HTTPS not working, browser security warning
**Solution:**
```bash
# In Coolify dashboard:
# 1. Go to Domain settings
# 2. Click "Generate SSL Certificate"
# 3. Wait for Let's Encrypt issuance
# 4. Verify certificate:

curl -I https://your-domain.com
```

### Issue 5: High Memory Usage

**Symptom:** Services OOM killed, frequent restarts
**Solution:**
```bash
# Increase memory limits in docker-compose.yml
services:
  backend:
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G

# Restart services
docker-compose up -d
```

## Cost Comparison After Migration

### Before (Railway - Exceeded Free Tier)

```
Railway Pro Plan: $20-50/month (variable)
- Backend: ~$15-25
- Worker: ~$10-15
- Frontend: ~$10-15
- Redis Plugin: ~$5
- Bandwidth: Variable
Total: $20-50/month (unpredictable)
```

### After (Coolify Self-Hosted)

```
VPS (Hetzner): €20/month ($22)
- 4 vCPU, 8GB RAM, 160GB SSD
- All services included
- Unlimited bandwidth (20TB)
Coolify: Free (self-hosted)
Hostinger VPN: $9.99/month (optional)
Domain: $1/month (annual)
Total: ~$33/month (predictable)
```

**Savings:** $17-27/month or 34-54% cost reduction

## Success Criteria

Migration is successful when:

- ✅ All services running on Coolify
- ✅ DNS fully propagated to new server
- ✅ All functionality verified working
- ✅ No increase in error rates
- ✅ Response times similar or better
- ✅ 48+ hours of stable operation
- ✅ Railway services decommissioned
- ✅ Team trained on Coolify operations
- ✅ Monitoring and alerts configured
- ✅ Backup procedures tested

## Post-Migration Optimization

### Week 1: Monitoring & Tuning

- Monitor resource usage patterns
- Adjust memory/CPU limits if needed
- Optimize Docker image sizes
- Fine-tune worker concurrency

### Week 2-4: Performance Optimization

- Enable Redis persistence
- Configure CDN for static assets (if needed)
- Optimize database queries
- Implement caching strategies

### Month 2+: Cost & Stability

- Review actual hosting costs
- Evaluate resource allocation
- Plan capacity upgrades if needed
- Document lessons learned

## Support Resources

- **Coolify Documentation:** https://coolify.io/docs
- **Coolify Discord:** https://discord.gg/coolify
- **Suna GitHub Issues:** https://github.com/kortix-ai/suna/issues
- **Migration Support:** Create issue with [MIGRATION] tag

## Conclusion

This migration typically takes 2-4 hours and results in:

- ✅ Predictable, lower costs
- ✅ More control over infrastructure
- ✅ No vendor lock-in
- ✅ Better resource utilization
- ✅ VPN integration capability

**Remember:** Keep Railway running for 48 hours as a safety net before full decommissioning.

---

**Document Version:** 1.0.0  
**Last Updated:** December 2024  
**Tested With:** Railway → Coolify v4.0, Suna v0.1.3
