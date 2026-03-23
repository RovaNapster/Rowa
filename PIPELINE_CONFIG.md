# Docker Deployment Pipeline Configuration

This document outlines the complete deployment pipeline for Lidbema and NexNod services.

## Pipeline Architecture

### CI/CD Workflows

#### 1. `ci.yml` - Pull Request Validation
- **Trigger**: Pull requests to main/develop
- **Steps**:
  - Build all service images
  - Lint Dockerfiles with Hadolint
  - Validate docker-compose.yml
  - Security scanning with Trivy

#### 2. `deploy.yml` - Build and Deploy
- **Trigger**: Push to main/develop or manual dispatch
- **Steps**:
  1. **Validate** - Configuration and secrets check
  2. **Build** - Parallel build of 7 services with layer caching
  3. **Security Scan** - Trivy vulnerability scanning (can be skipped with approval)
  4. **Deploy Staging** - Deploy to staging on develop push
     - Pre-deployment checks
     - Service deployment
     - Health verification (30 attempts, 5s interval)
     - Smoke tests
     - Slack notification
  5. **Deploy Production** - Deploy to production on main push (requires approval)
     - Pre-deployment checks
     - Volume backup (automatic)
     - Service deployment
     - Health verification with automatic rollback on failure
     - Cluster stability checks
     - Slack notification

#### 3. `rollback.yml` - Manual Rollback
- **Trigger**: Manual dispatch from Actions UI
- **Steps**:
  - Backup verification
  - Execute rollback on target environment
  - Service verification
  - Completion notification

### Deployment Script: `deploy-enhanced.sh`

Enhanced deployment orchestrator with comprehensive features:

**Usage:**
```bash
./deploy-enhanced.sh <environment> <action> [service] [value]
```

**Environments:** staging, production, development

**Actions:**
- `deploy` - Deploy/update all services
- `rollback` - Rollback to previous version
- `status` - Show deployment status and resource usage
- `logs [service]` - View service logs (all if service not specified)
- `metrics` - Display resource utilization metrics
- `scale <service> <replicas>` - Scale service to N replicas
- `backup` - Create backup of volumes
- `restore <file>` - Restore from backup
- `restart [service]` - Restart services
- `health-check` - Run full health check on all services

**Examples:**
```bash
# Check deployment status
./deploy-enhanced.sh staging status

# Deploy to staging
./deploy-enhanced.sh staging deploy

# View logs for a specific service
./deploy-enhanced.sh production logs lidbema-zone1

# Scale NexNod node to 5 replicas
./deploy-enhanced.sh staging scale nexnod-node1 5

# Run health checks
./deploy-enhanced.sh production health-check

# Create backup
./deploy-enhanced.sh production backup
```

## Required GitHub Secrets

Configure these secrets in your GitHub repository Settings > Secrets and variables > Actions:

**Staging Secrets:**
- `STAGING_DEPLOY_KEY` - SSH private key for staging server
- `STAGING_DEPLOY_HOST` - Staging server hostname/IP
- `STAGING_DEPLOY_USER` - SSH user for staging (optional, defaults to deploy)

**Production Secrets:**
- `PROD_DEPLOY_KEY` - SSH private key for production server
- `PROD_DEPLOY_HOST` - Production server hostname/IP
- `PROD_DEPLOY_USER` - SSH user for production (optional, defaults to deploy)

**Notifications:**
- `SLACK_WEBHOOK` - Slack webhook URL for deployment notifications

## Branch Strategy

### Main Branch (`main`)
- Production deployments
- Requires pull request review
- Triggers security scanning + deployment with approval
- Automatic rollback if health checks fail

### Develop Branch (`develop`)
- Staging deployments
- Automated deployment after branch protection checks
- Security scanning enabled
- Smoke tests verify functionality

### Feature Branches
- CI validation only (no deployment)
- Build, lint, and security scanning
- Results visible in PR checks

## Deployment Flow

### Staging Deployment
```
develop push → CI validation → Build → Security Scan → Deploy to Staging → Health Check → Smoke Tests → Slack Notify
```

### Production Deployment
```
main push → CI validation → Build → Security Scan → Awaiting Approval → Pre-Deployment Backup → Deploy → Health Check → Rollback on Failure → Slack Notify
```

## Health Checks

All services include automated health verification:

**Configuration:**
- Interval: 30 seconds
- Timeout: 10 seconds
- Retries: 3 (staging) / 5 (production)
- Start period: 40 seconds

**Health Endpoints:**
- Lidbema zones (1-3): `/health`
- PWA: `/health`
- NexNod nodes: `/health`
- Prometheus: `/-/healthy`
- Grafana: `/api/health`

**Post-Deployment Checks:**
- All services responding
- Metrics collection working
- Cluster peer communication established
- Previous deployment still accessible for rollback

## Backup Strategy

### Automatic Backups
- Created before each production deployment
- Compressed with gzip
- Stored in `.backups/production/` directory
- Timestamped for easy identification

### Backup Contents
- NexNod cluster data (nodes 1-3)
- Service logs (all services)
- Application logs (Lidbema zones, PWA, NexNod nodes)

### Retention Policy
- Staging: 30 days
- Production: 90 days
- Manual backups: indefinite

### Restore Process
```bash
./deploy-enhanced.sh production restore <backup-file>
```

## Rollback Procedure

### Automatic Rollback
- Triggered if production health checks fail
- Restores previous docker-compose configuration
- Restores services from previous image tags
- Verifies health before completion

### Manual Rollback
Via GitHub Actions UI:
1. Go to Actions > Rollback Verification
2. Click "Run workflow"
3. Select environment (staging/production)
4. Optionally specify backup file
5. Confirm and execute

Via CLI:
```bash
./deploy-enhanced.sh production rollback
```

## Monitoring & Logging

### Deployment Logs
- Location: `.logs/deploy-YYYYMMDD-HHMMSS.log`
- Contains: All deployment actions, errors, and results
- Retention: Indefinite (manual cleanup)

### Service Logs
- View all: `./deploy-enhanced.sh <env> logs`
- View specific: `./deploy-enhanced.sh <env> logs <service>`
- Stored in Docker volumes for persistence

### Metrics
```bash
./deploy-enhanced.sh <env> metrics
```
Shows:
- CPU and memory usage per container
- Disk usage by volumes and images
- Network usage statistics

## Notifications

### Slack Integration
Deployments trigger notifications to configured Slack webhook:

**Message Content:**
- Deployment status (Success/Failed)
- Environment (Staging/Production)
- Commit SHA
- Branch name
- Rollback status (if applicable)

## Environment Configuration

Edit `.env.pipeline` to customize:

```bash
# Log levels
STAGING_LOG_LEVEL=info
PRODUCTION_LOG_LEVEL=info

# Health check tuning
PRODUCTION_HEALTH_CHECK_RETRIES=5
STAGING_HEALTH_CHECK_RETRIES=3

# Backup retention
STAGING_BACKUP_RETENTION_DAYS=30
PRODUCTION_BACKUP_RETENTION_DAYS=90

# Registry configuration
REGISTRY=ghcr.io
REGISTRY_PULL_POLICY=always
```

## Troubleshooting

### Deployment Failures

**Health check fails:**
1. Check service logs: `./deploy-enhanced.sh <env> logs <service>`
2. Verify endpoints are responding: Check application health endpoints
3. Check resource availability: `./deploy-enhanced.sh <env> metrics`
4. Automatic rollback should restore previous version

**Build failures:**
1. Check Dockerfile syntax in PR
2. Verify all COPY paths exist
3. Check Docker daemon connectivity
4. Review Hadolint warnings in CI logs

**Network issues:**
1. Verify service names in environment variables
2. Check docker networks: `docker network ls`
3. Inspect network: `docker network inspect <network-name>`

### Rollback Issues

**Backup not found:**
1. Create manual backup: `./deploy-enhanced.sh production backup`
2. Verify backup directory: `.backups/production/`
3. Check backup file permissions

**Services won't restart:**
1. Check resource availability
2. Verify Docker daemon status
3. Check service dependencies
4. Review logs for error details

## Best Practices

1. **Branch Protection**: Require PR review before merging to main
2. **Testing**: Run full test suite before merging
3. **Staging First**: Always deploy to staging before production
4. **Monitoring**: Keep Grafana and Prometheus healthy
5. **Backups**: Verify backup integrity regularly
6. **Secrets**: Rotate SSH keys periodically
7. **Notifications**: Monitor Slack for deployment alerts
8. **Logging**: Archive deployment logs regularly

## Security Considerations

- SSH keys stored as GitHub Secrets (never in code)
- Trivy scanning on every image build
- Health checks prevent bad deployments
- Automatic rollback on failure
- Slack notifications for audit trail
- Environment isolation (staging vs production)
- Private registry credentials via GitHub Secrets

## Advanced Operations

### Scaling Services
```bash
# Scale NexNod cluster to 5 nodes
./deploy-enhanced.sh production scale nexnod-node1 5

# Scale Lidbema zone to 3 replicas
./deploy-enhanced.sh staging scale lidbema-zone1 3
```

### Disaster Recovery
```bash
# Full backup
./deploy-enhanced.sh production backup

# View backups
ls .backups/production/

# Restore specific backup
./deploy-enhanced.sh production restore .backups/production/backup-20240101-120000.tar.gz
```

### Debugging
```bash
# Check status
./deploy-enhanced.sh production status

# View all logs
./deploy-enhanced.sh production logs

# View specific service logs
./deploy-enhanced.sh production logs lidbema-zone1 | tail -100

# Health check
./deploy-enhanced.sh production health-check
```

## Performance Tuning

### Build Optimization
- Parallel builds (max-parallel: 4) reduce build time
- GitHub Actions cache enabled for layers
- Image scanning runs in parallel (max-parallel: 3)

### Deployment Speed
- Pre-deployment validation: ~30 seconds
- Service startup: ~40 seconds
- Health checks: ~150 seconds (30 attempts × 5 second interval)
- Total deployment: ~3-5 minutes

### Resource Efficiency
- Multi-stage Dockerfiles recommended
- Proper layer caching improves rebuild speed
- Volume backups use compression (gzip)
- Automatic cleanup of old images recommended
