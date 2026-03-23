#!/bin/bash
# Quick deployment commands reference
# Common operations for managing the pipeline

# ============================================================================
# DEPLOYMENT OPERATIONS
# ============================================================================

# Deploy to staging
./deploy-enhanced.sh staging deploy

# Deploy to production (requires GitHub approval)
./deploy-enhanced.sh production deploy

# Rollback to previous version
./deploy-enhanced.sh production rollback

# Full disaster recovery (destructive)
./deploy-enhanced.sh production disaster

# ============================================================================
# STATUS & MONITORING
# ============================================================================

# Check deployment status
./deploy-enhanced.sh staging status

# View resource metrics (CPU, memory, network)
./deploy-enhanced.sh staging metrics

# View all service logs
./deploy-enhanced.sh staging logs

# View specific service logs
./deploy-enhanced.sh staging logs lidbema-pwa
./deploy-enhanced.sh staging logs prometheus

# Follow logs in real-time
docker compose logs -f

# ============================================================================
# BACKUP & RESTORE
# ============================================================================

# Create backup of all volumes
./deploy-enhanced.sh staging backup

# Restore from backup file
./deploy-enhanced.sh production restore /backups/production/volumes/lidbema-zone1-logs-TIMESTAMP.tar.gz

# List available backups
ls -lh /backups/staging/volumes/

# ============================================================================
# SERVICE MANAGEMENT
# ============================================================================

# Scale service to N replicas
./deploy-enhanced.sh production scale nexnod-node1 5
./deploy-enhanced.sh staging scale lidbema-zone1 3

# Restart all services
docker compose restart

# Restart specific service
docker compose restart lidbema-pwa

# Stop all services
docker compose down

# Stop with volume cleanup (WARNING: destructive)
docker compose down -v

# Start services
docker compose up -d

# ============================================================================
# HEALTH CHECKS
# ============================================================================

# Run smoke tests
./smoke-tests.sh staging http://localhost

# Test specific endpoint
curl http://localhost:3000/health
curl http://localhost:9090/-/healthy
curl http://localhost:3100/api/health

# Check container health status
docker compose ps

# View health check history
docker inspect lidbema-pwa | grep -A 20 "Health"

# ============================================================================
# MONITORING ACCESS
# ============================================================================

# Prometheus - Metrics & Alerting
# URL: http://localhost:9090
# Query: {job=~"lidbema|nexnod"}

# Grafana - Dashboards & Visualization
# URL: http://localhost:3100
# Default creds: admin/admin

# Service Metrics Endpoints
# Zone 1: http://localhost:9001/metrics
# Zone 2: http://localhost:9002/metrics
# Zone 3: http://localhost:9003/metrics
# PWA: http://localhost:9000/metrics
# NexNod 1: http://localhost:9101/metrics
# NexNod 2: http://localhost:9102/metrics
# NexNod 3: http://localhost:9103/metrics

# ============================================================================
# TROUBLESHOOTING
# ============================================================================

# Check Docker daemon status
docker info

# Verify docker-compose syntax
docker compose config

# View container details
docker inspect <container-name>

# Check network connectivity
docker network inspect lidbema-network

# Check disk space
docker system df

# Clean up unused resources
docker system prune -a

# View build cache
docker buildx du

# ============================================================================
# CI/CD PIPELINE
# ============================================================================

# Create release tag (triggers production deployment)
git tag -a v1.0.0 -m "Production Release v1.0.0"
git push origin v1.0.0

# View GitHub Actions workflow
# https://github.com/YOUR_ORG/lidbema/actions

# Manual workflow trigger
# GitHub UI: Actions → Deploy Pipeline → Run workflow

# ============================================================================
# DEBUGGING
# ============================================================================

# Enable debug mode in deploy script
set -x
./deploy-enhanced.sh staging deploy
set +x

# Collect diagnostic information
docker compose ps -a > diagnostics.txt
docker compose logs --tail=100 >> diagnostics.txt
docker system df >> diagnostics.txt
docker stats --no-stream >> diagnostics.txt

# View Docker daemon logs (platform-specific)
# macOS: ~/Library/Containers/com.docker.docker/Data/log/vm/dockerd.log
# Linux: journalctl -xu docker.service
# Windows: %LOCALAPPDATA%\Docker\log\vm\dockerd.log

# ============================================================================
# SECURITY
# ============================================================================

# Scan images for vulnerabilities
trivy image ghcr.io/your-org/lidbema-pwa:latest

# View image layers
docker history <image-name>

# Check container resource limits
docker inspect --format='{{json .HostConfig}}' <container-name> | jq '.Memory'

# Rotate secrets (manual)
# 1. Update GitHub secrets
# 2. Trigger new deployment: git push origin main

# ============================================================================
# PERFORMANCE TUNING
# ============================================================================

# View resource allocation
docker stats --no-stream

# Adjust resource limits (in docker-compose.yml)
# deploy:
#   resources:
#     limits:
#       cpus: '0.5'
#       memory: 512M

# View CPU/Memory trends
docker stats --no-stream | sort -k 4 -hr

# ============================================================================
# ADVANCED OPERATIONS
# ============================================================================

# Pull latest images without deploying
docker compose pull

# Build images locally
docker compose build --no-cache

# Connect to running container
docker compose exec lidbema-pwa sh

# Copy files to/from container
docker compose cp lidbema-pwa:/app/logs/. ./local-logs

# Execute command in container
docker compose exec prometheus promtool query instant 'up'

# View container environment variables
docker inspect <container-name> | grep -A 10 "Env"

# ============================================================================
# CLEANUP
# ============================================================================

# Remove stopped containers
docker container prune -f

# Remove unused volumes
docker volume prune -f

# Remove unused networks
docker network prune -f

# Remove unused images
docker image prune -af

# Full cleanup (WARNING: removes all Docker data)
docker system prune -af --volumes

# ============================================================================
# USEFUL SCRIPTS
# ============================================================================

# Deploy, backup, and validate
deploy_safe() {
    ./deploy-enhanced.sh staging backup
    ./deploy-enhanced.sh staging deploy
    ./smoke-tests.sh staging http://localhost
}

# Rotate through services and check logs
check_all_logs() {
    for service in lidbema-zone1 lidbema-zone2 lidbema-zone3 lidbema-pwa nexnod-node1 nexnod-node2 nexnod-node3; do
        echo "=== $service ==="
        docker compose logs --tail=5 $service
    done
}

# Monitor in real-time
monitor() {
    watch -n 2 'docker compose ps && echo "---" && docker stats --no-stream'
}

# ============================================================================
# DOCUMENTATION
# ============================================================================

# Full pipeline guide
cat PIPELINE_GUIDE.md

# Deployment strategies
cat DEPLOYMENT.md

# Server setup instructions
cat SERVER_SETUP.md

# Deployment status
cat DEPLOYMENT_STATUS.md

# Health check configuration
cat health-checks.yml
