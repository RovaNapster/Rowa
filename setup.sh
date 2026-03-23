#!/bin/bash
# Environment setup and validation - Fixed for cross-platform support

set -e

# Define colors (skip on Windows cmd)
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

echo -e "${GREEN}=== Lidbema Multi-App Deployment Setup ===${NC}\n"

# ============================================================================
# REQUIREMENTS CHECK
# ============================================================================
echo "Checking requirements..."

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}✗ $1 is not installed${NC}"
        return 1
    fi
    version=$("$1" --version 2>&1 | head -1)
    echo -e "${GREEN}✓ $1 is installed (${version})${NC}"
}

check_command docker
check_command docker-compose
check_command curl

# ============================================================================
# DOCKER SETUP
# ============================================================================
echo -e "\n${GREEN}=== Docker Setup ===${NC}"

if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker daemon is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker daemon is running${NC}"

# Create networks
echo "Creating networks..."
docker network create lidbema-network 2>/dev/null && echo "  ✓ lidbema-network" || echo "  ✓ lidbema-network (already exists)"
docker network create nexnod-network 2>/dev/null && echo "  ✓ nexnod-network" || echo "  ✓ nexnod-network (already exists)"
docker network create monitoring-network 2>/dev/null && echo "  ✓ monitoring-network" || echo "  ✓ monitoring-network (already exists)"

# ============================================================================
# ENVIRONMENT CONFIGURATION
# ============================================================================
echo -e "\n${GREEN}=== Environment Configuration ===${NC}"

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    cat > .env << 'EOF'
# General
ENVIRONMENT=staging
LOG_LEVEL=info
NODE_ENV=production

# Lidbema Configuration
LIDBEMA_REPLICAS=1
LIDBEMA_LOG_LEVEL=info

# NexNod Configuration
NEXNOD_REPLICAS=3
NEXNOD_CLUSTER_SIZE=3

# Monitoring
PROMETHEUS_RETENTION=15d
GRAFANA_ADMIN_PASSWORD=admin
GRAFANA_ADMIN_USER=admin

# Backup
BACKUP_RETENTION_DAYS=30
BACKUP_BASE_DIR=/backups
EOF
    echo -e "${GREEN}✓ Created .env file${NC}"
else
    echo -e "${YELLOW}⚠ .env already exists${NC}"
fi

# ============================================================================
# DOCKERFILE CREATION
# ============================================================================
echo -e "\n${GREEN}=== Creating Dockerfiles ===${NC}"

create_dockerfile_nodejs() {
    local service=$1
    local path=$2

    if [ -f "$path/Dockerfile" ]; then
        echo -e "${YELLOW}⚠ Dockerfile already exists for $service${NC}"
        return
    fi

    mkdir -p "$path"
    cat > "$path/Dockerfile" << 'EOF'
FROM node:18-alpine AS base
WORKDIR /app
ENV NODE_ENV=production

FROM base AS dependencies
COPY package*.json ./
RUN npm ci --only=production 2>/dev/null || npm ci

FROM base AS builder
COPY package*.json ./
RUN npm ci

FROM base
COPY --from=dependencies /app/node_modules ./node_modules
COPY . .

RUN mkdir -p /app/logs

EXPOSE 3000 9001 4000

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD node -e "require('http').get('http://localhost:' + (process.env.PORT || 3000) + '/health', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})" || exit 1

CMD ["node", "app.js"]
EOF
    echo -e "${GREEN}✓ Created Dockerfile for $service${NC}"
}

create_app_js() {
    local service=$1
    local path=$2

    if [ -f "$path/app.js" ]; then
        return
    fi

    mkdir -p "$path"
    cat > "$path/app.js" << 'EOF'
const http = require('http');
const os = require('os');

const PORT = process.env.PORT || 3000;
const SERVICE_ID = process.env.NODE_ID || process.env.ZONE_ID || 'unknown';

const server = http.createServer((req, res) => {
    if (req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            status: 'ok',
            service: SERVICE_ID,
            timestamp: new Date().toISOString(),
            uptime: process.uptime()
        }));
    } else if (req.url === '/') {
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end(`<h1>${SERVICE_ID}</h1><p>Service is running on ${os.hostname()}</p>`);
    } else {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Not found' }));
    }
});

server.listen(PORT, () => {
    console.log(`[${SERVICE_ID}] Server running on port ${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
});

process.on('SIGTERM', () => {
    console.log('[SIGTERM] Gracefully shutting down...');
    server.close(() => {
        console.log('Server closed');
        process.exit(0);
    });
});
EOF
}

create_package_json() {
    local service=$1
    local path=$2

    if [ -f "$path/package.json" ]; then
        return
    fi

    mkdir -p "$path"
    cat > "$path/package.json" << 'EOF'
{
  "name": "lidbema-service",
  "version": "1.0.0",
  "description": "Lidbema multi-zone service",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "dev": "nodemon app.js"
  },
  "keywords": [],
  "author": "",
  "license": "MIT",
  "dependencies": {},
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF
}

for service in LidbemaZon1 LidbemaZon2 LidbemaZon3 NexNod1 NexNod2 NexNod3; do
    create_dockerfile_nodejs "$service" "$service"
    create_app_js "$service" "$service"
    create_package_json "$service" "$service"
done

if [ -d "Lidbema PWa" ]; then
    create_dockerfile_nodejs "Lidbema PWa" "Lidbema PWa"
    create_app_js "Lidbema PWa" "Lidbema PWa"
    create_package_json "Lidbema PWa" "Lidbema PWa"
fi

# ============================================================================
# PERMISSIONS
# ============================================================================
echo -e "\n${GREEN}=== Setting Permissions ===${NC}"

chmod +x deploy.sh setup.sh 2>/dev/null || true
echo -e "${GREEN}✓ Deployment scripts are executable${NC}"

# ============================================================================
# VALIDATION
# ============================================================================
echo -e "\n${GREEN}=== Validation ===${NC}"

if docker compose -f docker-compose.yml config > /dev/null 2>&1; then
    echo -e "${GREEN}✓ docker-compose.yml is valid${NC}"
else
    echo -e "${RED}✗ docker-compose.yml has syntax errors${NC}"
    docker compose -f docker-compose.yml config
    exit 1
fi

# ============================================================================
# SUMMARY
# ============================================================================
echo -e "\n${GREEN}=== Setup Complete ===${NC}\n"

echo "Next steps:"
echo "  1. Review .env file: cat .env"
echo "  2. Verify Dockerfile exists in each service directory"
echo "  3. For GitHub Actions, configure these secrets:"
echo "     - STAGING_DEPLOY_KEY (SSH private key)"
echo "     - STAGING_DEPLOY_HOST (e.g., user@host.com)"
echo "     - PROD_DEPLOY_KEY"
echo "     - PROD_DEPLOY_HOST"
echo ""
echo "To start deployment:"
echo "  ./deploy.sh staging deploy          # Deploy to staging"
echo "  ./deploy.sh production deploy       # Deploy to production"
echo "  ./deploy.sh staging status          # Check status"
echo "  ./deploy.sh staging logs            # View logs"
echo ""
echo "To view monitoring:"
echo "  Grafana:    http://localhost:3100 (admin/admin)"
echo "  Prometheus: http://localhost:9090"
echo ""
