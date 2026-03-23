# Deployment Pipeline Setup Guide

This guide walks you through activating the CI/CD deployment pipeline for your app.

## Pipeline Components

### 1. `.github/workflows/deploy.yml`
- **Triggers**: On push to `main` or `develop`, and on pull requests to `main`
- **Build stage**: Installs dependencies, runs linter/tests, builds Docker image
- **Registry**: Pushes to GitHub Container Registry (ghcr.io)
- **Deploy stage**: Automatically deploys to production after successful build (main branch only)

### 2. `docker-compose.prod.yml`
- Production-ready compose configuration
- Includes health checks (curl every 30 seconds)
- Auto-restart policy: `unless-stopped`
- Single service deployment

### 3. `k8s-manifest.yaml`
- Kubernetes Deployment with 2 replicas
- LoadBalancer Service for external access
- Liveness and readiness probes
- Resource limits: 256Mi memory, 500m CPU per pod

---

## Step 1: Create GitHub Secrets

### Prerequisites
- Admin access to your GitHub repository
- SSH key pair for your production server (run `ssh-keygen -t ed25519` if needed)

### Add Secrets to GitHub

1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add these three secrets:

#### Secret 1: `DEPLOY_KEY`
- **Value**: Your SSH private key (the contents of `~/.ssh/id_ed25519` or similar)
- **How to get it**:
  ```bash
  cat ~/.ssh/id_ed25519
  ```
- **Copy the entire output** (including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`)

#### Secret 2: `DEPLOY_HOST`
- **Value**: Your production server's IP address or hostname
- **Example**: `123.45.67.89` or `prod.example.com`

#### Secret 3: `DEPLOY_USER`
- **Value**: SSH username for your production server
- **Example**: `ubuntu` or `deploy` or `root`

---

## Step 2: Configure Production Server

### SSH Key Setup

On your production server, add your public SSH key to `authorized_keys`:

```bash
# On your local machine, print the public key
cat ~/.ssh/id_ed25519.pub

# On the production server, append it to authorized_keys
echo "YOUR_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh
```

### Install Docker & Docker Compose

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
docker-compose --version
```

### Create Application Directory

```bash
# Create app directory
sudo mkdir -p /app
sudo chown $USER:$USER /app

# Copy docker-compose.prod.yml to the server
# (This will be done by the deployment script)
```

---

## Step 3: Update Image References

### Update `k8s-manifest.yaml`

Replace `YOUR_GITHUB_ORG/YOUR_REPO` with your actual GitHub repository path:

```bash
# Find your repository path
# It's in the format: github-username/repository-name

# Example:
# If your repo is at https://github.com/john-doe/rova-nexus
# Then the image reference should be: john-doe/rova-nexus
```

Edit `k8s-manifest.yaml` and replace this line:
```yaml
image: ghcr.io/YOUR_GITHUB_ORG/YOUR_REPO:main
```

With your actual repository:
```yaml
image: ghcr.io/john-doe/rova-nexus:main
```

---

## Step 4: Test the Pipeline

### Push to trigger the workflow

```bash
# Make a small change to your code
echo "# Updated" >> README.md

# Commit and push
git add .
git commit -m "Trigger deployment workflow"
git push origin main
```

### Monitor the workflow

1. Go to your GitHub repository
2. Click **Actions** tab
3. Watch the workflow execute:
   - Build stage: ~5-10 minutes (first time may be longer)
   - Deploy stage: ~2-3 minutes

### Check logs

Click on the workflow run to see detailed logs for each step.

---

## Step 5: Deploy to Kubernetes (Optional)

If you're using Kubernetes instead of a traditional server:

```bash
# Make sure kubectl is configured
kubectl cluster-info

# Deploy the manifest
kubectl apply -f k8s-manifest.yaml

# Check deployment status
kubectl get pods -l app=rova-nexus
kubectl get svc rova-nexus

# Port-forward to access locally
kubectl port-forward svc/rova-nexus 8080:80

# Access at http://localhost:8080
```

### Update Kubernetes deployment with new images

After the GitHub Actions workflow completes, update the deployment to pull the latest image:

```bash
# Trigger a rollout to pull the new image
kubectl rollout restart deployment/rova-nexus

# Watch the rollout
kubectl rollout status deployment/rova-nexus
```

---

## Workflow Execution Flow

```
Push to main branch
    ↓
GitHub Actions triggers
    ↓
Build Stage:
  - Checkout code
  - Install Node.js dependencies
  - Run linter
  - Run tests
  - Build Docker image
  - Push to ghcr.io
    ↓
Deploy Stage (main branch only):
  - SSH into production server
  - Pull latest image from ghcr.io
  - Run docker-compose up -d
  - Application restarts with new image
    ↓
Deployment complete
Access at: http://DEPLOY_HOST
```

---

## Troubleshooting

### SSH Connection Fails
- **Error**: `Connection refused` or `Permission denied`
- **Solution**: 
  - Verify `DEPLOY_HOST` is correct
  - Ensure public SSH key is in `~/.ssh/authorized_keys` on production server
  - Check SSH port (default 22) is open
  - Test manually: `ssh -i ~/.ssh/id_ed25519 DEPLOY_USER@DEPLOY_HOST`

### Docker Pull Fails
- **Error**: `401 Unauthorized` from ghcr.io
- **Solution**:
  - GitHub Actions automatically uses `GITHUB_TOKEN` for authentication
  - Ensure repository is not private, or add a Personal Access Token (PAT) with `read:packages` scope

### Build Fails
- **Error**: `npm install` fails
- **Solution**:
  - Check `package.json` exists in repository root
  - Verify all dependencies are compatible with Node.js 20
  - Check logs in GitHub Actions

### Pods Fail to Start (Kubernetes)
- **Error**: `ImagePullBackOff` or `CrashLoopBackOff`
- **Solution**:
  ```bash
  # Check pod logs
  kubectl logs -f deployment/rova-nexus
  
  # Describe pod for events
  kubectl describe pod <pod-name>
  
  # Update image reference in manifest if needed
  kubectl set image deployment/rova-nexus app=ghcr.io/YOUR_ORG/YOUR_REPO:main
  ```

---

## Next Steps

1. ✅ Add GitHub secrets
2. ✅ Configure production server
3. ✅ Update image references
4. ✅ Push code to main branch
5. ✅ Monitor first deployment
6. 📊 Set up monitoring/logging
7. 🔐 Enable branch protection rules

---

## Advanced Configuration

### Add Staging Environment

Create `.github/workflows/deploy-staging.yml` to deploy to a staging server on `develop` branch.

### Add Slack Notifications

Add step to workflow:
```yaml
- name: Notify Slack
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK }}
```

### Add Automated Testing

Update workflow to run more comprehensive tests:
```yaml
- name: Run integration tests
  run: npm run test:integration
```

### Add Docker Registry Cleanup

Clean up old images to save storage:
```yaml
- name: Delete untagged images
  uses: actions/github-script@v7
  with:
    script: |
      // Script to delete old/untagged images from ghcr.io
```

---

## Support

For issues:
- Check GitHub Actions logs
- Review workflow YAML syntax
- Test SSH connection manually to production server
- Check Docker/Kubernetes logs on target server
