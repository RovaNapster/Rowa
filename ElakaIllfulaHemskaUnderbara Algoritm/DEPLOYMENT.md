# Rova Nexus Deployment Pipeline

## Pipeline Overview

This deployment pipeline includes:
- **CI/CD via GitHub Actions**: Automated builds, tests, and pushes to container registry
- **Docker multi-stage builds**: Optimized production images
- **Health checks**: Built-in container health monitoring
- **Production compose file**: Ready-to-deploy stack

## Setup Instructions

### 1. GitHub Actions Setup
The workflow (`.github/workflows/deploy.yml`) automatically:
- Builds on push to `main` or `develop`
- Pushes to GitHub Container Registry (GHCR)
- Deploys to production on `main` branch push

No additional setup needed—GitHub Actions is enabled by default.

### 2. Configure Secrets (Optional)
If deploying to external servers, add these secrets to your GitHub repo:
- `SSH_HOST`: Production server address
- `SSH_USER`: SSH username
- `SSH_KEY`: SSH private key
- `REGISTRY_TOKEN`: Token for private registries

### 3. Environment Variables
Create `.env` file for local development:
```
NODE_ENV=development
```

### 4. Build Locally
```bash
# Development
docker compose up

# Production build
docker build -t rova-nexus:latest .
```

### 5. Deploy to Production

**Option A: Docker Compose (single server)**
```bash
docker compose -f docker-compose.prod.yml up -d
```

**Option B: Kubernetes (multi-node)**
Apply the manifest:
```bash
kubectl apply -f k8s-manifest.yml
```

**Option C: Update via GitHub Actions**
Push to `main` branch—pipeline auto-deploys.

## Image Tagging Strategy

Images are tagged as:
- `latest` (default branch)
- `main-<sha>` (commit SHA)
- `develop-<sha>` (develop branch)
- `v1.0.0` (semantic versions)

## Monitoring

Check container health:
```bash
docker ps  # View status
docker logs rova-nexus-prod  # View logs
docker inspect rova-nexus-prod  # Health status
```

## Next Steps

1. **Add deployment endpoint**: Update `.github/workflows/deploy.yml` `Deploy to production` step with your server details
2. **Enable branch protection**: Require PR reviews before merging to `main`
3. **Set up monitoring**: Add Prometheus/DataDog for metrics
4. **Configure secrets**: Add SSH or deployment keys if needed
