# Deployment Pipeline Setup

This project includes a complete CI/CD deployment pipeline.

## GitHub Actions Workflow

**File**: `.github/workflows/deploy.yml`

### Pipeline Stages:

1. **Build**
   - Checks out code
   - Installs dependencies
   - Runs linter and tests
   - Builds Docker image with multi-stage caching
   - Pushes to GitHub Container Registry (ghcr.io)

2. **Deploy** (triggered on main branch push)
   - Pulls latest image from registry
   - Connects via SSH to production server
   - Runs docker-compose up

### Required GitHub Secrets:

- `DEPLOY_KEY`: SSH private key for deployment server
- `DEPLOY_HOST`: Production server hostname/IP
- `DEPLOY_USER`: SSH username for deployment server

### Setup Instructions:

1. Add secrets in GitHub repo settings → Secrets and variables → Actions
2. Update image references in production compose file
3. Ensure deployment server has Docker and docker-compose installed
4. Set up SSH key-based authentication on deployment server

## Production Docker Compose

**File**: `docker-compose.prod.yml`

- Runs the pre-built image from the registry
- Maps port 80 for HTTP
- Includes health checks
- Sets restart policy to `unless-stopped`

## Kubernetes Deployment

**File**: `k8s-manifest.yaml`

For Kubernetes environments:
- 2 replicas for high availability
- Resource limits and requests
- Liveness and readiness probes
- LoadBalancer service for external access

Deploy with:
```bash
kubectl apply -f k8s-manifest.yaml
```

Update the image reference in the manifest with your actual registry path.

## Quick Start

1. Push to main branch → GitHub Actions runs workflow
2. View builds at: `https://github.com/YOUR_ORG/YOUR_REPO/actions`
3. Access deployed app at: `http://YOUR_DEPLOY_HOST`

## Local Testing

Test the production image locally:
```bash
docker build -t myapp:test .
docker-compose -f docker-compose.prod.yml up
```
