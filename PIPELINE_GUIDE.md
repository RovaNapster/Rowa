# Lidbema Deployment Pipeline - Quick Reference

## Overview

This deployment pipeline provides automated CI/CD for 7 containerized services across staging and production environments with health checks, security scanning, automatic rollback, and disaster recovery.

## Quick Start

```bash
# 1. Initialize the pipeline
chmod +x setup-pipeline.sh
./setup-pipeline.sh

# 2. Deploy to staging
chmod +x deploy-enhanced.sh
./deploy-enhanced.sh staging deploy

# 3. Run smoke tests
chmod +x smoke-tests.sh
./smoke-tests.sh staging

# 4. Check status
./deploy-enhanced.sh staging status
```

## Architecture

### Services (7 total)
- **Lidbema Zones** (3 instances): Zone-based services on ports 3001-3003
- **Lidbema PWA**: Frontend aggregator on port 3000
- **NexNod Cluster** (3 nodes): Distributed cluster on ports 4001-4003
- **Prometheus**: Metrics collection on port 9090
- **Grafana**: Visualization on port 3100

### Networks
- `lidbema-network`: Zone services + PWA
- `nexnod-network`: NexNod cluster peer communication
- `monitoring-network`: Prometheus + Grafana

## Deployment Pipeline Flow

```
git push → GitHub Actions
    ├─ Build (7 services in parallel)
    ├─ Test (build verification)
    ├─ Security Scan (Trivy vulnerability scan)
    ├─ Deploy Staging (auto on develop branch)
    │   └─ Health checks
    │   └─ Smoke tests
    └─ Deploy Production (manual approval on main branch)
        ├─ Pre-deployment backup
        ├─ Health checks
        └─ Auto-rollback on failure
```

## Commands Reference

### Deployment

```bash
# Deploy to environment
./deploy-enhanced.sh staging deploy
./deploy-enhanced.sh production deploy

# Rollback to previous version
./deploy-enhanced.sh production rollback

# View deployment status
./deploy-enhanced.sh staging status

# View real-time metrics
./deploy-enhanced.sh staging metrics

# View service logs
./deploy-enhanced.sh staging logs
./deploy-enhanced.sh staging logs lidbema-zone1
```

### Data Management

```bash
# Backup all volumes
./deploy-enhanced.sh staging backup

# Restore from backup
./deploy-enhanced.sh production restore /backups/production/volumes/lidbema-zone1-logs-TIMESTAMP.tar.gz

# Full disaster recovery (destructive)
./deploy-enhanced.sh production disaster
```

### Scaling

```bash
# Scale service to N replicas
./deploy-enhanced.sh production scale nexnod-node1 5
./deploy-enhanced.sh staging scale lidbema-zone1 3
```

### Testing

```bash
# Run comprehensive smoke tests
./smoke-tests.sh staging http://localhost
./smoke-tests.sh production https://lidbema.local
```

## GitHub Actions Setup

### 1. Add Secrets to GitHub

Settings → Secrets and variables → Actions

```
STAGING_DEPLOY_KEY      SSH private key for staging
STAGING_DEPLOY_HOST     staging.example.com
STAGING_DEPLOY_USER     deploy

PROD_DEPLOY_KEY         SSH private key for production
PROD_DEPLOY_HOST        prod.example.com
PROD_DEPLOY_USER        deploy

SLACK_WEBHOOK           (optional) For notifications
```

### 2. Configure Environment Protection

Settings → Environments → production
- Enable "Required reviewers"
- Add team members for approval

### 3. Create SSH Keys

```bash
ssh-keygen -t ed25519 -f ~/.ssh/lidbema_deploy -N ""
cat ~/.ssh/lidbema_deploy       # → STAGING_DEPLOY_KEY
cat ~/.ssh/lidbema_deploy.pub   # → authorized_keys on server
```

## Deployment Servers Setup

Run on each deployment server (staging & production):

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add deploy user
sudo useradd -m -s /bin/bash deploy
sudo usermod -aG docker deploy

# Clone repository
sudo -u deploy git clone https://github.com/ORG/lidbema /opt/lidbema

# Create directories
sudo mkdir -p /backups/{staging,production}
sudo chown deploy:deploy /backups -R
```

## Monitoring & Alerts

### Access Points

- **Prometheus**: http://localhost:9090
  - Query builder for metrics
  - Alert rules status
  
- **Grafana**: http://localhost:3100
  - Default creds: admin/admin
  - Pre-configured dashboards (after setup)

### Key Metrics

```promql
# Service availability
up{job=~"lidbema|nexnod"}

# Error rate (5xx responses)
rate(http_requests_total{status=~"5.."}[5m])

# Latency percentiles
histogram_quantile(0.95, http_request_duration_seconds_bucket)

# Resource usage
container_memory_usage_bytes
container_cpu_usage_seconds_total
```

### Alert Rules

See `prometheus-rules.yml` for configured alerts:
- Service down (Critical)
- High error rate (Warning)
- High latency (Warning)
- Disk space low (Warning)
- Cluster degraded (Critical)

## Health Checks

All services include HTTP health endpoints:

```
GET /health → Returns 200 OK when healthy
GET /health → Returns 503 when unhealthy
```

### Health Check Configuration

- **Interval**: 30 seconds
- **Timeout**: 10 seconds
- **Retries**: 3 consecutive failures triggers restart
- **Start Period**: 40 seconds (grace period)

Deployment waits up to 30 attempts (5 minutes) for all health checks to pass.

## Backup & Recovery

### Automatic Backups

- Staging: Pre-deployment
- Production: Pre-deployment
- Retention: 30 days (configurable)

### Manual Backup

```bash
./deploy-enhanced.sh production backup
ls -lh /backups/production/volumes/
```

### Restore from Backup

```bash
# List available backups
ls /backups/production/volumes/

# Restore specific volume
./deploy-enhanced.sh production restore \
  /backups/production/volumes/lidbema-zone1-logs-TIMESTAMP.tar.gz
```

### Point-in-Time Recovery

Backups are timestamped with Unix timestamps for easy point-in-time recovery:

```bash
# Find backups from specific date
ls -lh /backups/production/volumes/ | grep "2024-01"

# Calculate Unix timestamp for specific time
date -d "2024-01-15 10:00:00" +%s  # 1705318800
```

## Rollback Strategy

### Automatic Rollback (Triggered When)

1. Health checks fail post-deployment
2. Critical alerts fire
3. Manual rollback command

### Manual Rollback

```bash
./deploy-enhanced.sh production rollback
```

Rollback automatically:
- Restores previous docker-compose config
- Re-deploys previous service images
- Verifies health checks before completion

### Rollback Verification

```bash
# Check if rollback succeeded
./deploy-enhanced.sh production status

# View rollback logs
./deploy-enhanced.sh production logs
```

## Disaster Recovery

### When to Use

- Complete service failure
- Corrupted database/volumes
- Full environment rebuilding needed

### Recovery Procedure

```bash
# Initiate disaster recovery (destructive)
./deploy-enhanced.sh production disaster

# Answer 'yes' to confirm
# System will:
# 1. Stop all containers
# 2. Remove all volumes (warning!)
# 3. Redeploy fresh
# 4. Restore latest backups
```

## Scaling Services

### Horizontal Scaling

```bash
# Scale NexNod node to 5 replicas
./deploy-enhanced.sh production scale nexnod-node1 5

# Scale Lidbema zone to 3 replicas
./deploy-enhanced.sh staging scale lidbema-zone1 3
```

### Resource Limits

Add to docker-compose.yml service definition:

```yaml
services:
  service-name:
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
```

## Troubleshooting

### Deployment Fails

```bash
# Check deployment logs
./deploy-enhanced.sh staging logs

# Check specific service
./deploy-enhanced.sh staging logs lidbema-zone1

# Run preflight checks
./deploy-enhanced.sh staging status

# Verify docker-compose syntax
docker compose -f docker-compose.yml config
```

### Health Checks Failing

```bash
# Test health endpoint manually
curl -v http://localhost:3000/health

# Check container logs
docker compose logs lidbema-pwa

# Increase health check timeout in docker-compose.yml
```

### Out of Disk Space

```bash
# Check disk usage
df -h
docker system df

# Clean up unused images/volumes
docker system prune -a --volumes
```

### Network Issues

```bash
# Verify networks exist
docker network ls

# Check network connectivity
docker network inspect lidbema-network

# Restart network (in docker-compose.yml)
docker compose up -d --force-recreate
```

## Best Practices

1. **Always backup before production deploy**
   ```bash
   ./deploy-enhanced.sh production backup
   ```

2. **Test in staging first**
   ```bash
   git push origin develop  # Auto-deploys to staging
   # Wait for tests
   git push origin main     # Deploy to production
   ```

3. **Tag production releases**
   ```bash
   git tag -a v1.0.0 -m "Production release"
   git push origin v1.0.0
   ```

4. **Monitor after deployment**
   - Check Grafana dashboards
   - Monitor error rates
   - Watch resource usage

5. **Keep backups off-site**
   ```bash
   # Sync to cloud storage periodically
   aws s3 sync /backups s3://backup-bucket/lidbema/
   ```

## Environment Variables

### Deployment Variables

```bash
ENVIRONMENT              staging|production|disaster
LOG_LEVEL                debug|info|warn|error
NODE_ENV                 production
BACKUP_RETENTION_DAYS    30
DEPLOYMENT_TIMEOUT       600
```

### Service Variables

```bash
LIDBEMA_LOG_LEVEL        Service log level
NEXNOD_CLUSTER_SIZE      Number of cluster nodes
PROMETHEUS_RETENTION     Metrics retention (15d)
GRAFANA_ADMIN_PASSWORD   Grafana password
```

## Support & Debugging

### Enable Debug Mode

```bash
# Show all commands being executed
set -x
./deploy-enhanced.sh staging deploy
set +x
```

### Check Docker Logs

```bash
# View daemon logs
# macOS: ~/Library/Containers/com.docker.docker/Data/log/vm/dockerd.log
# Linux: journalctl -xu docker.service
# Windows: %LOCALAPPDATA%\Docker\log\vm\dockerd.log
```

### Collect Diagnostic Information

```bash
# Create diagnostic bundle
docker compose ps -a
docker compose logs --tail=100 > logs.txt
docker system df > disk.txt
docker stats --no-stream > metrics.txt
```

## Related Documentation

- `DEPLOYMENT.md` - Deployment concepts and strategies
- `SERVER_SETUP.md` - Deployment server configuration
- `docker-compose.yml` - Service definitions
- `prometheus.yml` - Metrics configuration
- `prometheus-rules.yml` - Alert rules
- `.github/workflows/deploy.yml` - CI/CD workflow
