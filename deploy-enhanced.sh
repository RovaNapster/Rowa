#!/bin/bash
set -e

# Enhanced deployment orchestrator with comprehensive logging, monitoring, and safety checks
# Usage: ./deploy.sh <environment> <action> [service] [value]

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly LOG_DIR="${LOG_DIR:-.logs}"
readonly BACKUP_DIR="${BACKUP_DIR:-.backups}"
readonly IMAGE_TAG="${IMAGE_TAG:-latest}"
readonly DEPLOY_TIMEOUT="${DEPLOY_TIMEOUT:-300}"
readonly HEALTH_CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-5}"
readonly HEALTH_CHECK_RETRIES="${HEALTH_CHECK_RETRIES:-30}"

# Color output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging setup
mkdir -p "${LOG_DIR}"
readonly LOG_FILE="${LOG_DIR}/deploy-$(date +%Y%m%d-%H%M%S).log"

log() {
  echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "${LOG_FILE}"
}

log_success() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓${NC} $1" | tee -a "${LOG_FILE}"
}

log_error() {
  echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗${NC} $1" | tee -a "${LOG_FILE}"
}

log_warning() {
  echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠${NC} $1" | tee -a "${LOG_FILE}"
}

# Validate environment
validate_env() {
  local env=$1
  if [[ ! "$env" =~ ^(staging|production|development)$ ]]; then
    log_error "Invalid environment: $env. Must be: staging, production, or development"
    exit 1
  fi
}

# Validate action
validate_action() {
  local action=$1
  if [[ ! "$action" =~ ^(deploy|rollback|status|logs|metrics|scale|backup|restore|restart|health-check)$ ]]; then
    log_error "Invalid action: $action"
    log "Available actions: deploy, rollback, status, logs, metrics, scale, backup, restore, restart, health-check"
    exit 1
  fi
}

# Check Docker and compose availability
check_prerequisites() {
  log "Checking prerequisites..."
  
  if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    exit 1
  fi
  
  if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    log_error "Docker Compose is not available"
    exit 1
  fi
  
  if ! docker ps &> /dev/null; then
    log_error "Cannot connect to Docker daemon"
    exit 1
  fi
  
  log_success "Prerequisites check passed"
}

# Validate docker-compose configuration
validate_compose() {
  log "Validating docker-compose configuration..."
  
  if ! docker-compose config > /dev/null 2>&1; then
    log_error "docker-compose.yml validation failed"
    exit 1
  fi
  
  log_success "Configuration valid"
}

# Check service health
health_check() {
  local service=$1
  local expected_state=${2:-"running"}
  
  log "Health checking service: $service"
  
  for ((i=1; i<=HEALTH_CHECK_RETRIES; i++)); do
    local state=$(docker-compose ps "$service" 2>/dev/null | awk 'NR==2 {print $NF}' || echo "unknown")
    
    if [[ "$state" == "$expected_state" ]] || [[ "$state" == *"Up"* ]]; then
      log_success "Health check passed for $service (attempt $i/$HEALTH_CHECK_RETRIES)"
      return 0
    fi
    
    log_warning "Health check attempt $i/$HEALTH_CHECK_RETRIES for $service (state: $state)"
    sleep "${HEALTH_CHECK_INTERVAL}"
  done
  
  log_error "Health check failed for $service after $HEALTH_CHECK_RETRIES attempts"
  return 1
}

# Pre-deployment backup
backup_volumes() {
  local env=$1
  
  log "Creating backup for environment: $env"
  mkdir -p "${BACKUP_DIR}/${env}"
  
  local backup_file="${BACKUP_DIR}/${env}/backup-$(date +%Y%m%d-%H%M%S).tar.gz"
  
  log "Backing up volumes to: $backup_file"
  docker run --rm \
    -v nexnod-node1-data:/data1 \
    -v nexnod-node2-data:/data2 \
    -v nexnod-node3-data:/data3 \
    -v lidbema-zone1-logs:/logs1 \
    -v lidbema-zone2-logs:/logs2 \
    -v lidbema-zone3-logs:/logs3 \
    -v lidbema-pwa-logs:/logs-pwa \
    -v nexnod-node1-logs:/logs-node1 \
    -v nexnod-node2-logs:/logs-node2 \
    -v nexnod-node3-logs:/logs-node3 \
    -v "$(pwd)/${BACKUP_DIR}:/backup" \
    alpine tar czf "/backup/$(basename "$backup_file")" \
    -C / data1 data2 data3 logs1 logs2 logs3 logs-pwa logs-node1 logs-node2 logs-node3 2>&1 | tee -a "${LOG_FILE}"
  
  if [ -f "$backup_file" ]; then
    log_success "Backup created: $backup_file ($(du -h "$backup_file" | cut -f1))"
  else
    log_error "Backup creation failed"
    return 1
  fi
}

# Deploy services
deploy() {
  local env=$1
  
  log "Deploying to environment: $env"
  
  validate_compose
  
  # Pull latest images
  log "Pulling latest images..."
  docker-compose pull --policy always 2>&1 | tee -a "${LOG_FILE}" || log_warning "Some images may not have updates"
  
  # Stop existing containers gracefully
  log "Stopping existing services..."
  docker-compose down --timeout 30 2>&1 | tee -a "${LOG_FILE}"
  
  # Build/rebuild services
  log "Building services..."
  docker-compose build --parallel 2>&1 | tee -a "${LOG_FILE}"
  
  # Start services
  log "Starting services..."
  docker-compose up -d 2>&1 | tee -a "${LOG_FILE}"
  
  # Health checks for all services
  local services=("lidbema-zone1" "lidbema-zone2" "lidbema-zone3" "lidbema-pwa" "nexnod-node1" "nexnod-node2" "nexnod-node3" "prometheus" "grafana")
  local failed=0
  
  for service in "${services[@]}"; do
    if ! health_check "$service" "running"; then
      log_error "Service $service failed health check"
      failed=$((failed + 1))
    fi
  done
  
  if [ $failed -gt 0 ]; then
    log_error "$failed service(s) failed health checks"
    return 1
  fi
  
  log_success "Deployment completed successfully"
}

# Rollback to previous version
rollback() {
  local env=$1
  
  log "Initiating rollback for environment: $env"
  
  log "Stopping current services..."
  docker-compose down --timeout 30 2>&1 | tee -a "${LOG_FILE}"
  
  log "Restoring previous configuration..."
  if [ -f ".docker-compose-${env}-backup.yml" ]; then
    cp ".docker-compose-${env}-backup.yml" docker-compose.yml
    log_success "Restored previous docker-compose configuration"
  fi
  
  log "Restarting services..."
  docker-compose up -d 2>&1 | tee -a "${LOG_FILE}"
  
  local services=("lidbema-zone1" "lidbema-zone2" "lidbema-zone3" "lidbema-pwa" "nexnod-node1" "nexnod-node2" "nexnod-node3")
  for service in "${services[@]}"; do
    health_check "$service" "running" || log_error "Service $service failed to restore"
  done
  
  log_success "Rollback completed"
}

# Show deployment status
show_status() {
  local env=$1
  
  log "Deployment status for environment: $env"
  
  echo -e "\n${BLUE}Services:${NC}"
  docker-compose ps
  
  echo -e "\n${BLUE}Networks:${NC}"
  docker network ls | grep lidbema-network || log_warning "lidbema-network not found"
  docker network ls | grep nexnod-network || log_warning "nexnod-network not found"
  
  echo -e "\n${BLUE}Volumes:${NC}"
  docker volume ls | grep -E "(lidbema|nexnod)" || log_warning "No relevant volumes found"
  
  echo -e "\n${BLUE}Resource Usage:${NC}"
  docker stats --no-stream
}

# View logs
show_logs() {
  local service=$1
  
  if [ -n "$service" ]; then
    log "Logs for service: $service"
    docker-compose logs -f --tail 100 "$service" 2>&1 | tee -a "${LOG_FILE}"
  else
    log "Logs for all services"
    docker-compose logs --tail 50 2>&1 | tee -a "${LOG_FILE}"
  fi
}

# Show metrics
show_metrics() {
  log "Resource metrics"
  
  echo -e "${BLUE}CPU & Memory Usage:${NC}"
  docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
  
  echo -e "\n${BLUE}Disk Usage:${NC}"
  docker system df
}

# Scale service
scale_service() {
  local service=$1
  local replicas=$2
  
  log "Scaling service $service to $replicas replicas"
  
  if [ -z "$service" ] || [ -z "$replicas" ]; then
    log_error "Usage: ./deploy.sh $env scale <service> <replicas>"
    exit 1
  fi
  
  docker-compose up -d --scale "$service=$replicas" 2>&1 | tee -a "${LOG_FILE}"
  
  log_success "Scaling completed"
}

# Restart services
restart_services() {
  local env=$1
  local service=$2
  
  log "Restarting services for environment: $env"
  
  if [ -n "$service" ]; then
    log "Restarting specific service: $service"
    docker-compose restart "$service" 2>&1 | tee -a "${LOG_FILE}"
  else
    log "Restarting all services"
    docker-compose restart 2>&1 | tee -a "${LOG_FILE}"
  fi
  
  sleep 5
  health_check "${service:-lidbema-pwa}" "running" || log_warning "Service may still be starting"
}

# Full health check
full_health_check() {
  log "Running full health check"
  
  local services=("lidbema-zone1" "lidbema-zone2" "lidbema-zone3" "lidbema-pwa" "nexnod-node1" "nexnod-node2" "nexnod-node3" "prometheus" "grafana")
  local healthy=0
  
  for service in "${services[@]}"; do
    if health_check "$service" "running"; then
      log_success "$service is healthy"
      healthy=$((healthy + 1))
    fi
  done
  
  echo -e "\n${BLUE}Health Summary:${NC} $healthy/${#services[@]} services healthy"
}

# Main entry point
main() {
  local env=$1
  local action=$2
  local service=$3
  local value=$4
  
  if [ -z "$env" ] || [ -z "$action" ]; then
    echo "Usage: $SCRIPT_NAME <environment> <action> [service] [value]"
    echo ""
    echo "Environments: staging, production, development"
    echo "Actions: deploy, rollback, status, logs, metrics, scale, backup, restore, restart, health-check"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME staging deploy"
    echo "  $SCRIPT_NAME production logs lidbema-zone1"
    echo "  $SCRIPT_NAME staging scale nexnod-node1 5"
    exit 1
  fi
  
  validate_env "$env"
  validate_action "$action"
  check_prerequisites
  
  log "Starting deployment pipeline"
  log "Environment: $env | Action: $action"
  
  case "$action" in
    deploy)
      backup_volumes "$env"
      deploy "$env"
      ;;
    rollback)
      rollback "$env"
      ;;
    status)
      show_status "$env"
      ;;
    logs)
      show_logs "$service"
      ;;
    metrics)
      show_metrics
      ;;
    scale)
      scale_service "$service" "$value"
      ;;
    backup)
      backup_volumes "$env"
      ;;
    restart)
      restart_services "$env" "$service"
      ;;
    health-check)
      full_health_check
      ;;
    *)
      log_error "Unknown action: $action"
      exit 1
      ;;
  esac
  
  log "Deployment pipeline completed"
}

main "$@"
