# Lidbema Multi-App Deployment Pipeline

Comprehensive deployment pipeline covering all services: Lidbema Zones (1-3), PWA, and NexNod cluster.

## Components

### Core Files
- **docker-compose.yml** - Full service orchestration with health checks, logging, and networking
- **deploy.sh** - Deployment orchestrator with rollback, scaling, and disaster recovery
- **.github/workflows/deploy.yml** - CI/CD pipeline for automated builds, scanning, and deployment
- **prometheus.yml** - Monitoring configuration
- **prometheus-rules.yml** - Alert rules for all services
- **setup.sh** - Initial environment setup

## Quick Start

```bash
# 1. Initial setup
chmod +x setup.sh
./setup.sh

# 2. Deploy to staging
./deploy.sh staging deploy

# 3. Check status
./deploy.sh staging status

# 4. View logs
./deploy.sh staging logs
```

## Deployment Environments

### Staging
- Branch: `develop`
- Triggers on: push to develop
- URL: https://staging.lidbema.local
- Deploys: All images from develop branch

### Production
- Branch: `main`
- Triggers on: push to main
- URL: https://lidbema.local
- Deploys: All images from main branch after security scanning
- Protection: Environment approval required

### Disaster Recovery
- Manual trigger only
- Full recovery from backups
- Zero-downtime restoration

## CI/CD Pipeline Flow

1. **Build** - Parallel builds for all services with cache optimization
2. **Test** - Build verification for each service
3. **Security Scan** - Trivy vulnerability scanning of entire codebase
4. **Publish** - Push images to registry (main branch only)
5. **Deploy** - Deploy to appropriate environment
6. **Health Check** - Verify all services are healthy

## Services

### Lidbema Zones
- **lidbema-zone1** (port 3001)
- **lidbema-zone2** (port 3002)
- **lidbema-zone3** (port 3003)
- **lidbema-pwa** (port 3000) - Aggregates zones

### NexNod Cluster
- **nexnod-node1** (port 4001)
- **nexnod-node2** (port 4002)
- **nexnod-node3** (port 4003)
- Cluster peer discovery on port 9001

### Monitoring
- **Prometheus** (port 9090) - Metrics collection
- **Grafana** (port 3100) - Visualization

## Deployment Commands

```bash
# Deploy actions
./deploy.sh <env> deploy           # Deploy latest images
./deploy.sh <env> rollback         # Rollback to previous version
./deploy.sh <env> disaster         # Full disaster recovery

# Management
./deploy.sh <env> status           # Show deployment status
./deploy.sh <env> logs [service]   # View service logs
./deploy.sh <env> metrics          # Show resource metrics
./deploy.sh <env> scale service N  # Scale service to N replicas

# Backup/Restore
./deploy.sh <env> backup           # Backup data volumes
./deploy.sh <env> restore file     # Restore from backup

# Examples
./deploy.sh production deploy
./deploy.sh staging logs lidbema-zone1
./deploy.sh production scale nexnod-node1 5
```

## GitHub Actions Setup

### Required Secrets
```
STAGING_DEPLOY_KEY      # SSH private key for staging
STAGING_DEPLOY_HOST     # Deploy host for staging
PROD_DEPLOY_KEY         # SSH private key for production
PROD_DEPLOY_HOST        # Deploy host for production
SLACK_WEBHOOK           # Slack notification webhook
```

### Workflow Triggers
- Automated on push to `main` (production) and `develop` (staging)
- Manual run available via GitHub Actions UI
- Pull requests trigger build/test/scan without deployment

## Monitoring & Alerts

### Key Metrics
- Service availability (up/down)
- Error rates (5xx responses)
- Latency (P95, P99)
- Resource usage (CPU, memory)
- Cluster health (NexNod node count)

### Alert Severity Levels
- **Critical** - Service down, cluster degraded
- **Warning** - High latency, high resource usage, error rate spikes

## Rollback Strategy

Automatic rollback triggered if:
- Health check fails after deployment
- Critical alert fires
- Manual rollback command

Rollback restores:
- Previous docker-compose configuration
- Service images from backup
- Health verification before completion

## Data Backup

### Backup Locations
- Staging: `/backups/staging/volumes/`
- Production: `/backups/production/volumes/`
- Disaster: `/backups/disaster/volumes/`

### Backup Contents
- Lidbema zone logs
- NexNod node data and logs
- Timestamped compression for point-in-time recovery

### Retention Policy
- 30-day retention (configurable via `.env`)
- Automated cleanup of old backups

## Networking

### Networks
- **lidbema-network** - Zone services and PWA
- **nexnod-network** - NexNod cluster peer communication
- **monitoring-network** - Prometheus and Grafana

### Service Discovery
- Internal DNS via Docker network
- Zone services: `lidbema-zone<N>:3000`
- NexNod nodes: `nexnod-node<N>:4000`
- Cluster discovery: automatic via peer list

## Logging

### Log Destinations
- Container logs: `docker compose logs <service>`
- Deployment logs: `/var/log/deploy-<env>.log`
- Volume logs: Persisted in named volumes

### Log Levels
- ERROR
- WARNING
- INFO (default)
- DEBUG (configurable)

## Scaling

### Horizontal Scaling
```bash
# Scale NexNod node to 5 replicas
./deploy.sh production scale nexnod-node1 5

# Scale Lidbema zone to 3 replicas
./deploy.sh staging scale lidbema-zone1 3
```

### Resource Limits
- CPU: Configurable per service
- Memory: Configurable per service
- Automatic restart on failure

## Health Checks

All services include health check endpoints:
- **Lidbema zones**: `/health`
- **PWA**: `/health`
- **NexNod nodes**: `/health`

Health check configuration:
- Interval: 30 seconds
- Timeout: 10 seconds
- Retries: 3
- Start period: 40 seconds

## Security Considerations

- Vulnerability scanning on every build
- Private registry credentials via GitHub Secrets
- SSH key authentication for remote deployment
- Health checks prevent bad deployments
- Automatic rollback on failure
