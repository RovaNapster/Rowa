#!/bin/bash
# Multi-app deployment orchestrator
# Handles staging, production, and disaster recovery deployments
# Cross-platform: Linux, macOS, Windows (Git Bash/WSL)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVIRONMENT=${1:-staging}
ACTION=${2:-deploy}

# Color codes (disabled on Windows native cmd)
if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "cygwin" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

health_check() {
    local url=$1
    local max_attempts=30
    local attempt=1

    log_info "Health checking $url..."
    while [ $attempt -le $max_attempts ]; do
        if curl -sf "$url" > /dev/null 2>&1; then
            log_info "✓ Health check passed"
            return 0
        fi
        log_warn "Health check attempt $attempt/$max_attempts..."
        sleep 5
        ((attempt++))
    done

    log_error "Health check failed after $max_attempts attempts"
    return 1
}

# ============================================================================
# ENVIRONMENT CONFIGURATION
# ============================================================================
case $ENVIRONMENT in
    staging)
        DOCKER_HOST=${STAGING_DOCKER_HOST:-unix:///var/run/docker.sock}
        HEALTHCHECK_URL=${STAGING_HEALTHCHECK_URL:-http://localhost:3000/health}
        BACKUP_DIR="${BACKUP_BASE_DIR:-/backups}/staging"
        LOG_PREFIX="staging"
        ;;
    production)
        DOCKER_HOST=${PROD_DOCKER_HOST:-unix:///var/run/docker.sock}
        HEALTHCHECK_URL=${PROD_HEALTHCHECK_URL:-http://localhost:3000/health}
        BACKUP_DIR="${BACKUP_BASE_DIR:-/backups}/production"
        LOG_PREFIX="production"
        ;;
    disaster)
        DOCKER_HOST=${DISASTER_DOCKER_HOST:-unix:///var/run/docker.sock}
        HEALTHCHECK_URL=${DISASTER_HEALTHCHECK_URL:-http://localhost:3000/health}
        BACKUP_DIR="${BACKUP_BASE_DIR:-/backups}/disaster"
        LOG_PREFIX="disaster-recovery"
        ;;
    *)
        log_error "Unknown environment: $ENVIRONMENT. Use: staging, production, or disaster"
        ;;
esac

export DOCKER_HOST

# ============================================================================
# DEPLOYMENT FUNCTIONS
# ============================================================================
deploy() {
    log_info "Starting deployment to $ENVIRONMENT..."

    # Create backup directory
    mkdir -p "$BACKUP_DIR"

    # Create backup of compose config
    log_info "Creating backup of compose config..."
    docker compose -f docker-compose.yml config > "$BACKUP_DIR/compose-$(date +%s).yml" 2>/dev/null || log_warn "Failed to backup compose config"

    # Pull latest images
    log_info "Pulling latest images..."
    docker compose -f docker-compose.yml pull --quiet 2>&1 || log_warn "Image pull completed with warnings"

    # Deploy services
    log_info "Deploying services..."
    docker compose -f docker-compose.yml up -d --remove-orphans 2>&1 || log_error "Deployment failed"

    # Wait for services to stabilize
    log_info "Waiting for services to stabilize (30 seconds)..."
    sleep 30

    # Health check
    health_check "$HEALTHCHECK_URL" || {
        log_warn "Health check failed. Rolling back..."
        rollback
        return 1
    }

    log_info "✓ Deployment completed successfully"
    return 0
}

rollback() {
    log_warn "Rolling back to previous version..."

    # Find most recent backup
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/compose-*.yml 2>/dev/null | head -1)

    if [ -z "$LATEST_BACKUP" ]; then
        log_error "No backup found for rollback"
        return 1
    fi

    log_info "Using backup: $LATEST_BACKUP"
    docker compose -f "$LATEST_BACKUP" up -d --remove-orphans 2>&1 || log_error "Rollback deployment failed"

    sleep 30
    health_check "$HEALTHCHECK_URL" || return 1

    log_info "✓ Rollback completed"
    return 0
}

scale_service() {
    local service=$1
    local replicas=$2

    if [ -z "$service" ] || [ -z "$replicas" ]; then
        log_error "Usage: scale <service> <replicas>"
    fi

    log_info "Scaling $service to $replicas replicas..."
    docker compose up -d --scale "$service=$replicas" || log_error "Scaling failed"
}

logs_view() {
    local service=$1
    if [ -z "$service" ]; then
        docker compose logs -f --tail=100
    else
        docker compose logs -f --tail=100 "$service"
    fi
}

status() {
    log_info "Deployment Status: $ENVIRONMENT"
    echo ""
    docker compose ps || log_warn "Failed to get compose status"
    echo ""
    log_info "Volume Status:"
    docker volume ls --filter label=app=lidbema --filter label=app=nexnod || true
    echo ""
    log_info "Network Status:"
    docker network ls --filter driver=bridge || true
}

metrics() {
    log_info "Service Metrics:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" || log_warn "Failed to get metrics"
}

backup_data() {
    log_info "Backing up data volumes..."
    mkdir -p "$BACKUP_DIR/volumes"

    # Backup Lidbema zone logs
    for zone in 1 2 3; do
        if docker volume inspect "lidbema-zone$zone-logs" > /dev/null 2>&1; then
            docker run --rm \
                -v "lidbema-zone$zone-logs:/data" \
                -v "$BACKUP_DIR/volumes":/backup \
                alpine tar czf "/backup/lidbema-zone$zone-logs-$(date +%s).tar.gz" -C /data . 2>/dev/null || true
        fi
    done

    # Backup PWA logs
    if docker volume inspect lidbema-pwa-logs > /dev/null 2>&1; then
        docker run --rm \
            -v lidbema-pwa-logs:/data \
            -v "$BACKUP_DIR/volumes":/backup \
            alpine tar czf "/backup/lidbema-pwa-logs-$(date +%s).tar.gz" -C /data . 2>/dev/null || true
    fi

    # Backup NexNod data and logs
    for node in 1 2 3; do
        if docker volume inspect "nexnod-node$node-data" > /dev/null 2>&1; then
            docker run --rm \
                -v "nexnod-node$node-data:/data" \
                -v "$BACKUP_DIR/volumes":/backup \
                alpine tar czf "/backup/nexnod-node$node-data-$(date +%s).tar.gz" -C /data . 2>/dev/null || true
        fi

        if docker volume inspect "nexnod-node$node-logs" > /dev/null 2>&1; then
            docker run --rm \
                -v "nexnod-node$node-logs:/data" \
                -v "$BACKUP_DIR/volumes":/backup \
                alpine tar czf "/backup/nexnod-node$node-logs-$(date +%s).tar.gz" -C /data . 2>/dev/null || true
        fi
    done

    log_info "✓ Data backup completed"
}

restore_data() {
    local backup_file=$1

    if [ -z "$backup_file" ]; then
        log_error "Usage: restore <backup-file>"
    fi

    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
    fi

    log_warn "Restoring from $backup_file..."
    log_warn "This will overwrite existing data"
    read -p "Continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cancelled"
        return 0
    fi

    # Extract volume name from filename
    SERVICE_NAME=$(basename "$backup_file" .tar.gz | sed 's/-[0-9]*$//')

    docker run --rm \
        -v "${SERVICE_NAME}:/data" \
        -v "$(dirname "$backup_file")":/backup \
        alpine tar xzf "/backup/$(basename "$backup_file")" -C /data || log_error "Restore failed"

    log_info "✓ Data restore completed"
}

disaster_recovery() {
    log_warn "Initiating disaster recovery sequence..."
    log_warn "This will destroy all containers and volumes"
    read -p "Continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cancelled"
        return 0
    fi

    # Kill all containers
    docker compose down -v 2>/dev/null || true

    # Wait for cleanup
    sleep 5

    # Redeploy from scratch
    deploy || return 1

    # Restore latest backups if available
    LATEST_ZONE_BACKUP=$(ls -t "$BACKUP_DIR/volumes"/lidbema-zone*-logs-* 2>/dev/null | head -1)
    if [ -n "$LATEST_ZONE_BACKUP" ]; then
        log_info "Restoring latest Lidbema backup..."
        restore_data "$LATEST_ZONE_BACKUP" || log_warn "Failed to restore backup"
    fi

    log_info "✓ Disaster recovery completed"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================
case $ACTION in
    deploy)
        deploy
        ;;
    rollback)
        rollback
        ;;
    scale)
        scale_service "$3" "$4"
        ;;
    logs)
        logs_view "$3"
        ;;
    status)
        status
        ;;
    metrics)
        metrics
        ;;
    backup)
        backup_data
        ;;
    restore)
        restore_data "$3"
        ;;
    disaster)
        disaster_recovery
        ;;
    *)
        cat << EOF
Multi-App Deployment Orchestrator

Usage: $0 <environment> <action> [options]

Environments:
  staging          Staging environment
  production       Production environment
  disaster         Disaster recovery (rebuilds from scratch)

Actions:
  deploy           Deploy latest images and start services
  rollback         Rollback to previous version
  scale SVC N      Scale service to N replicas
  logs [SVC]       View service logs (all if SVC not specified)
  status           Show deployment status
  metrics          Show resource metrics
  backup           Backup all data volumes
  restore FILE     Restore from backup file
  disaster         Full disaster recovery (destructive)

Examples:
  $0 production deploy
  $0 staging logs lidbema-zone1
  $0 production scale nexnod-node1 5
  $0 staging backup
  $0 production metrics

EOF
        exit 1
        ;;
esac
