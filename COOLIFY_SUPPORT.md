# Coolify Deployment Support for Suna

## Overview

This document provides configuration details for deploying Suna on Coolify, an alternative to Railway that supports self-hosted deployments. Coolify is particularly useful when:

- Railway free tier limits are exceeded
- You need more control over hosting costs
- You want to deploy on your own infrastructure
- You're using Hostinger VPN for network access

## Prerequisites

- Coolify instance (v4.0+)
- Hostinger VPN (optional, for private network access)
- Domain name (optional, for custom domains)
- All secrets from `.agents` file

## Coolify vs Railway Comparison

| Feature | Railway | Coolify |
|---------|---------|---------|
| Hosting | Cloud (managed) | Self-hosted |
| Free Tier | $5/month credit | Unlimited (your resources) |
| Setup Complexity | Low | Medium |
| Control | Limited | Full |
| VPN Support | No | Yes (Hostinger compatible) |
| Cost Predictability | Variable | Fixed (hosting cost) |

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Hostinger VPN (Optional)                │
│                    Private Network Layer                    │
└─────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Coolify Instance                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   Frontend   │  │    Backend   │  │    Worker    │    │
│  │   (Next.js)  │  │  (FastAPI)   │  │  (Dramatiq)  │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
│         │                  │                  │            │
│         └──────────────────┴──────────────────┘            │
│                            ▼                                │
│  ┌──────────────┐  ┌──────────────┐                      │
│  │    Redis     │  │   Supabase   │                      │
│  │   (Cache)    │  │  (Database)  │                      │
│  └──────────────┘  └──────────────┘                      │
└─────────────────────────────────────────────────────────────┘
```

## Docker Compose for Coolify

Coolify uses Docker Compose under the hood. Use the existing `docker-compose.yaml` as a base, with these modifications:

### Coolify-Specific docker-compose.yml

```yaml
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    networks:
      - coolify
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3

  backend:
    image: ghcr.io/suna-ai/suna-backend:latest
    platform: linux/amd64
    build:
      context: ./backend
      dockerfile: Dockerfile
    ports:
      - "8000:8000"
    environment:
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - ENV_MODE=production
    env_file:
      - .env
    depends_on:
      redis:
        condition: service_healthy
    networks:
      - coolify
    restart: unless-stopped
    labels:
      - coolify.managed=true

  worker:
    image: ghcr.io/suna-ai/suna-backend:latest
    platform: linux/amd64
    build:
      context: ./backend
      dockerfile: Dockerfile
    command: uv run dramatiq --processes 4 --threads 4 run_agent_background
    environment:
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - ENV_MODE=production
    env_file:
      - .env
    depends_on:
      redis:
        condition: service_healthy
    networks:
      - coolify
    restart: unless-stopped
    labels:
      - coolify.managed=true

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    depends_on:
      - backend
    networks:
      - coolify
    restart: unless-stopped
    labels:
      - coolify.managed=true
      - traefik.enable=true
      - traefik.http.routers.suna-frontend.rule=Host(`your-domain.com`)
      - traefik.http.routers.suna-frontend.entrypoints=websecure
      - traefik.http.routers.suna-frontend.tls.certresolver=letsencrypt

networks:
  coolify:
    external: true

volumes:
  redis_data:
```

## Coolify Configuration

### 1. Create New Project in Coolify

1. Log into your Coolify dashboard
2. Click "New Resource" → "Docker Compose"
3. Name: `suna-ai-platform`
4. Paste the docker-compose.yml above

### 2. Configure Environment Variables

In Coolify UI, add all environment variables from `.agents` file:

**Core Secrets:**
```bash
SUPABASE_URL=your-supabase-url
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
SUPABASE_JWT_SECRET=your-jwt-secret
ENCRYPTION_KEY=your-encryption-key
KORTIX_ADMIN_API_KEY=your-admin-key
```

**Redis:**
```bash
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_SSL=false
```

**LLM Provider (at least one required):**
```bash
ANTHROPIC_API_KEY=your-anthropic-key
# or
OPENAI_API_KEY=your-openai-key
# or other providers from .agents file
```

**Search & Scraping:**
```bash
TAVILY_API_KEY=your-tavily-key
FIRECRAWL_API_KEY=your-firecrawl-key
RAPID_API_KEY=your-rapidapi-key
```

**Sandbox:**
```bash
DAYTONA_API_KEY=your-daytona-key
DAYTONA_SERVER_URL=https://app.daytona.io/api
DAYTONA_TARGET=us
```

Add all other optional secrets as needed from `.agents` file.

### 3. Configure Domain (Optional)

If using a custom domain:

1. In Coolify, go to your project settings
2. Add domain: `your-domain.com`
3. Enable SSL/TLS (Let's Encrypt)
4. Update DNS A record to point to your Coolify server IP
5. Update environment variables:
   ```bash
   NEXT_PUBLIC_URL=https://your-domain.com
   NEXT_PUBLIC_BACKEND_URL=https://your-domain.com/api
   ```

### 4. Deploy

1. Click "Deploy" in Coolify UI
2. Monitor logs for any errors
3. Wait for all services to become healthy
4. Access at your configured domain or server IP

## Hostinger VPN Integration

### Why Hostinger VPN?

- Secure access to Coolify-hosted services
- Private network for database connections
- Protection from unauthorized access
- Cost-effective VPN solution

### Setup Steps

1. **Install Hostinger VPN on Coolify Server:**
   ```bash
   # SSH into your Coolify server
   wget https://hostinger-vpn-client.tar.gz
   tar -xzf hostinger-vpn-client.tar.gz
   sudo ./install.sh
   ```

2. **Configure VPN Connection:**
   ```bash
   # Add VPN configuration
   sudo hostinger-vpn add-connection \
     --name suna-network \
     --server vpn.hostinger.com \
     --username your-vpn-user \
     --password your-vpn-pass
   
   # Start VPN
   sudo hostinger-vpn connect suna-network
   
   # Enable auto-start
   sudo systemctl enable hostinger-vpn
   ```

3. **Update Coolify Network Settings:**
   ```yaml
   # In docker-compose.yml, add VPN network
   networks:
     coolify:
       external: true
     vpn:
       driver: bridge
       ipam:
         config:
           - subnet: 10.8.0.0/24
   ```

4. **Configure Firewall:**
   ```bash
   # Allow VPN traffic
   sudo ufw allow from 10.8.0.0/24
   sudo ufw allow 1194/udp  # VPN port
   ```

### VPN Network Diagram

```
Internet → Hostinger VPN → Coolify Server (10.8.0.1)
                              ├─ Frontend (10.8.0.10)
                              ├─ Backend (10.8.0.11)
                              ├─ Worker (10.8.0.12)
                              └─ Redis (10.8.0.13)
```

## Resource Requirements

### Minimum Server Specs

- **CPU:** 2 cores
- **RAM:** 4GB
- **Storage:** 20GB SSD
- **Network:** 100Mbps

### Recommended Server Specs

- **CPU:** 4 cores
- **RAM:** 8GB
- **Storage:** 50GB SSD
- **Network:** 1Gbps

## Cost Estimates

### Self-Hosted on VPS

| Provider | Specs | Monthly Cost |
|----------|-------|--------------|
| DigitalOcean | 4 vCPU, 8GB RAM | $48 |
| Hetzner | 4 vCPU, 8GB RAM | €20 (~$22) |
| Linode | 4 vCPU, 8GB RAM | $36 |
| Hostinger VPS | 4 vCPU, 8GB RAM | $29.99 |

**Plus:**
- Coolify: Free (self-hosted)
- Hostinger VPN: ~$9.99/month
- Domain: ~$12/year
- **Total Monthly:** ~$35-60 (fixed, predictable)

### Cost Comparison with Railway

- **Railway Free Tier:** $0 (limited to $5 credit)
- **Railway Pro:** ~$20-50/month (variable based on usage)
- **Coolify + VPS:** ~$35-60/month (fixed)

**Coolify becomes cost-effective when:**
- Consistent high usage on Railway
- Need for predictable costs
- Require more control over infrastructure
- Want to avoid vendor lock-in

## Monitoring and Maintenance

### Health Checks

Coolify automatically monitors:
- Service uptime
- Resource usage (CPU, RAM, Disk)
- Container health status
- Network connectivity

### Backup Strategy

```bash
# Automated backup script
#!/bin/bash
# Save as /root/backup-suna.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/suna"

# Backup Redis data
docker exec suna-redis redis-cli SAVE
docker cp suna-redis:/data/dump.rdb $BACKUP_DIR/redis_$DATE.rdb

# Backup environment variables
docker exec suna-backend env > $BACKUP_DIR/env_$DATE.txt

# Backup to remote storage (optional)
# rclone copy $BACKUP_DIR remote:suna-backups/

# Keep only last 7 days
find $BACKUP_DIR -mtime +7 -delete

echo "Backup completed: $DATE"
```

Add to crontab:
```bash
0 2 * * * /root/backup-suna.sh >> /var/log/suna-backup.log 2>&1
```

## Troubleshooting

### Service Won't Start

```bash
# Check logs
docker-compose logs -f backend

# Verify environment variables
docker-compose config

# Restart services
docker-compose restart
```

### Database Connection Issues

```bash
# Test Supabase connectivity
curl -I $SUPABASE_URL

# Check Redis
docker exec suna-redis redis-cli ping
```

### VPN Connection Problems

```bash
# Check VPN status
sudo hostinger-vpn status

# Reconnect VPN
sudo hostinger-vpn reconnect suna-network

# View VPN logs
sudo journalctl -u hostinger-vpn
```

## Migration from Railway

See [COOLIFY_MIGRATION.md](./COOLIFY_MIGRATION.md) for detailed migration steps.

## Security Considerations

1. **Firewall Configuration:**
   ```bash
   # Allow only necessary ports
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw allow 22/tcp      # SSH
   sudo ufw allow 80/tcp      # HTTP
   sudo ufw allow 443/tcp     # HTTPS
   sudo ufw allow 1194/udp    # VPN
   sudo ufw enable
   ```

2. **SSL/TLS Certificates:**
   - Coolify auto-manages Let's Encrypt certificates
   - Certificates auto-renew every 90 days
   - Monitor expiration in Coolify dashboard

3. **Secret Management:**
   - Store secrets in Coolify's encrypted environment variable system
   - Never commit secrets to version control
   - Rotate secrets regularly (quarterly recommended)
   - Use different secrets for staging/production

4. **Access Control:**
   - Enable Coolify's built-in authentication
   - Use strong passwords (20+ characters)
   - Enable 2FA if available
   - Restrict SSH access to known IPs
   - Use SSH keys instead of passwords

## Support and Resources

- **Coolify Documentation:** https://coolify.io/docs
- **Coolify Discord:** https://discord.gg/coolify
- **Hostinger VPN Support:** https://hostinger.com/vpn
- **Suna GitHub:** https://github.com/kortix-ai/suna

## Next Steps

1. Review [COOLIFY_MIGRATION.md](./COOLIFY_MIGRATION.md) for migration process
2. Set up monitoring and alerts
3. Configure automated backups
4. Test disaster recovery procedures
5. Document your specific configuration

---

**Last Updated:** December 2024  
**Compatibility:** Coolify v4.0+, Suna v0.1.3+
