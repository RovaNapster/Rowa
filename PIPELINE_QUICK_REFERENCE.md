# Deployment Pipeline Quick Reference

## Initial Setup

```bash
# 1. Set up pipeline infrastructure
chmod +x setup-pipeline.sh deploy-enhanced.sh
./setup-pipeline.sh

# 2. Configure GitHub Secrets (in GitHub UI)
# Settings > Secrets and variables > Actions
# Add: STAGING_DEPLOY_KEY, STAGING_DEPLOY_HOST, PROD_DEPLOY_KEY, PROD_DEPLOY_HOST, SLACK_WEBHOOK
```

## Common Commands

### Local Testing
```bash
# Check current deployment status
./deploy-enhanced.sh staging status

# Deploy to staging
./deploy-enhanced.sh staging deploy

# View logs
./deploy-enhanced.sh staging logs

# Run health checks
./deploy-enhanced.sh staging health-check
```

### Monitoring
```bash
# Show resource usage
./deploy-enhanced.sh production metrics

# View specific service logs
./deploy-enhanced.sh production logs lidbema-zone1

# Check deployment status
./deploy-enhanced.sh production status
```

### Management
```bash
# Scale NexNod cluster
./deploy-enhanced.sh production scale nexnod-node1 5

# Restart services
./deploy-enhanced.sh production restart

# Backup volumes
./deploy-enhanced.sh production backup

# Rollback to previous version
./deploy-enhanced.sh production rollback
```

## GitHub Actions Workflows

### Automatic Triggers
- **develop branch** → Staging deployment
- **main branch** → Production deployment (requires approval)
- **Pull request** → CI validation (build, lint, security scan)

### Manual Triggers
- **Actions > Deploy Pipeline > Run workflow** → Manual staging/production deployment
- **Actions > Rollback Verification > Run workflow** → Manual rollback

## Pipeline Stages

### Pull Request
```
Build → Lint → Security Scan → Results in PR
```

### Staging Deployment
```
develop push → Build → Security Scan → Deploy → Health Check → Smoke Tests → Slack
```

### Production Deployment
```
main push → Build → Security Scan → Approve → Backup → Deploy → Health Check → Rollback on Fail → Slack
```

## Services

| Service | Port | Type | Replicas |
|---------|------|------|----------|
| lidbema-zone1 | 3001 | Application | 1 |
| lidbema-zone2 | 3002 | Application | 1 |
| lidbema-zone3 | 3003 | Application | 1 |
| lidbema-pwa | 3000 | Application | 1 |
| nexnod-node1 | 4001 | Cluster | 1 |
| nexnod-node2 | 4002 | Cluster | 1 |
| nexnod-node3 | 4003 | Cluster | 1 |
| prometheus | 9090 | Monitoring | 1 |
| grafana | 3100 | Monitoring | 1 |

## Health Endpoints
- Lidbema zones: `http://localhost:300X/health`
- NexNod nodes: `http://localhost:400X/health`
- Prometheus: `http://localhost:9090/-/healthy`
- Grafana: `http://localhost:3100/api/health`

## Environment Variables

Configure in `.env.pipeline`:
- `LOG_LEVEL` - info/debug (default: info)
- `METRICS_ENABLED` - Enable monitoring (default: true)
- `BACKUP_RETENTION_DAYS` - Backup cleanup (staging: 30, production: 90)
- `HEALTH_CHECK_RETRIES` - Retry attempts (staging: 3, production: 5)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Health check fails | Check logs: `./deploy-enhanced.sh <env> logs <service>` |
| Deployment hangs | Check timeout settings, verify network connectivity |
| Rollback needed | Use `./deploy-enhanced.sh <env> rollback` |
| Services down | Check status: `./deploy-enhanced.sh <env> status` |
| Backup missing | Create new: `./deploy-enhanced.sh <env> backup` |

## Important Files

- `.github/workflows/ci.yml` - Pull request validation
- `.github/workflows/deploy.yml` - Build and deploy pipeline
- `.github/workflows/rollback.yml` - Manual rollback workflow
- `deploy-enhanced.sh` - Local deployment script
- `setup-pipeline.sh` - Infrastructure setup
- `docker-compose.yml` - Service configuration
- `.env.pipeline` - Pipeline environment variables
- `PIPELINE_CONFIG.md` - Detailed documentation

## Backup/Restore

```bash
# Create backup
./deploy-enhanced.sh production backup

# List backups
ls -lh .backups/production/

# Restore specific backup
./deploy-enhanced.sh production restore .backups/production/backup-20240101-120000.tar.gz
```

## Key Features

✓ Automated CI/CD with GitHub Actions
✓ Multi-environment support (staging/production)
✓ Automatic health checks and rollback
✓ Comprehensive logging and monitoring
✓ Backup/restore capabilities
✓ Service scaling
✓ Slack notifications
✓ Security scanning (Trivy)
✓ Build caching for speed
✓ Parallel builds and scanning
