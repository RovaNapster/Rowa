#!/bin/bash

# Pipeline setup script - Initialize deployment infrastructure
# This script prepares the deployment environment with necessary directories, configurations, and permissions

set -e

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BLUE='\033[0;34m'
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

echo -e "${BLUE}Setting up deployment pipeline infrastructure...${NC}"

# Create required directories
echo "Creating directories..."
mkdir -p .logs .backups .cache .artifacts
chmod 755 deploy-enhanced.sh setup-pipeline.sh

echo -e "${GREEN}✓${NC} Created deployment directories"

# Validate GitHub Actions configuration
echo "Validating GitHub Actions configuration..."
if [ -d ".github/workflows" ]; then
  echo -e "${GREEN}✓${NC} Found .github/workflows directory"
  ls -la .github/workflows/
else
  echo -e "${RED}✗${NC} .github/workflows directory not found"
  exit 1
fi

# Check Docker installation
echo "Checking Docker installation..."
if command -v docker &> /dev/null; then
  DOCKER_VERSION=$(docker --version)
  echo -e "${GREEN}✓${NC} $DOCKER_VERSION"
else
  echo -e "${RED}✗${NC} Docker not installed"
  exit 1
fi

# Check Docker Compose
echo "Checking Docker Compose..."
if docker-compose --version &> /dev/null; then
  COMPOSE_VERSION=$(docker-compose --version)
  echo -e "${GREEN}✓${NC} $COMPOSE_VERSION"
elif docker compose version &> /dev/null; then
  COMPOSE_VERSION=$(docker compose version)
  echo -e "${GREEN}✓${NC} Docker Compose: $COMPOSE_VERSION"
else
  echo -e "${RED}✗${NC} Docker Compose not found"
  exit 1
fi

# Validate docker-compose.yml
echo "Validating docker-compose.yml..."
if docker-compose config > /dev/null 2>&1; then
  echo -e "${GREEN}✓${NC} docker-compose.yml is valid"
else
  echo -e "${RED}✗${NC} docker-compose.yml validation failed"
  exit 1
fi

# Set up environment file
echo "Setting up environment files..."
if [ ! -f .env.pipeline ]; then
  echo -e "${RED}✗${NC} .env.pipeline not found"
else
  echo -e "${GREEN}✓${NC} .env.pipeline configured"
fi

# Output setup summary
echo -e "\n${BLUE}Pipeline Setup Summary:${NC}"
echo "  ✓ Directories created: .logs, .backups, .cache, .artifacts"
echo "  ✓ Deployment scripts: deploy-enhanced.sh"
echo "  ✓ CI/CD workflows: .github/workflows/"
echo "  ✓ Docker Compose validated"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Configure GitHub Secrets:"
echo "     - STAGING_DEPLOY_KEY"
echo "     - STAGING_DEPLOY_HOST"
echo "     - STAGING_DEPLOY_USER"
echo "     - PROD_DEPLOY_KEY"
echo "     - PROD_DEPLOY_HOST"
echo "     - PROD_DEPLOY_USER"
echo "     - SLACK_WEBHOOK"
echo ""
echo "  2. Set up branch protection rules on main and develop"
echo ""
echo "  3. Deploy locally to test:"
echo "     ./deploy-enhanced.sh staging status"
echo "     ./deploy-enhanced.sh staging deploy"
echo ""
echo "  4. Push to GitHub to trigger CI/CD pipeline"
echo ""
echo -e "${GREEN}Pipeline setup complete!${NC}"
