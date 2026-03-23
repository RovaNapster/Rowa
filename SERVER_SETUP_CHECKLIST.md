# Server Setup Checklist

Quick reference for setting up deployment servers. Complete these steps in order.

---

## Pre-Setup (Local Machine)

- [ ] Generate SSH keys
  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/lidbema_deploy -N ""
  ```

- [ ] Save public key for later
  ```bash
  cat ~/.ssh/lidbema_deploy.pub
  ```

---

## Staging Server Setup

### System Preparation
- [ ] Connect to staging server via SSH
- [ ] Update system
  ```bash
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y git curl wget
  ```

- [ ] Install Docker
  ```bash
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  docker --version
  ```

### User & Permissions
- [ ] Create deploy user
  ```bash
  sudo useradd -m -s /bin/bash deploy
  sudo usermod -aG docker deploy
  ```

- [ ] Create deployment directory
  ```bash
  sudo mkdir -p /opt/lidbema
  sudo chown deploy:deploy /opt/lidbema
  ```

- [ ] Add SSH public key
  ```bash
  sudo mkdir -p /home/deploy/.ssh
  sudo chmod 700 /home/deploy/.ssh
  echo "ssh-ed25519 AAAA..." | sudo tee -a /home/deploy/.ssh/authorized_keys
  sudo chmod 600 /home/deploy/.ssh/authorized_keys
  sudo chown deploy:deploy /home/deploy/.ssh -R
  ```

- [ ] Configure sudoers
  ```bash
  echo "deploy ALL=(ALL) NOPASSWD: /usr/bin/docker" | sudo tee -a /etc/sudoers.d/deploy
  sudo chmod 0440 /etc/sudoers.d/deploy
  ```

### Repository Setup
- [ ] Clone repository
  ```bash
  sudo -u deploy git clone https://github.com/YOUR_ORG/lidbema /opt/lidbema
  ```

- [ ] Create .env.staging file
  ```bash
  sudo tee /opt/lidbema/.env.staging > /dev/null << 'EOF'
  ENVIRONMENT=staging
  NODE_ENV=production
  LOG_LEVEL=info
  BACKUP_BASE_DIR=/backups/staging
  GRAFANA_ADMIN_PASSWORD=staging_password
  EOF
  sudo chown deploy:deploy /opt/lidbema/.env.staging
  sudo chmod 600 /opt/lidbema/.env.staging
  ```

### Backup & Logging
- [ ] Create backup directories
  ```bash
  sudo mkdir -p /backups/staging/volumes
  sudo chown deploy:deploy /backups -R
  sudo chmod 755 /backups -R
  ```

- [ ] Set up log rotation
  ```bash
  sudo tee /etc/logrotate.d/lidbema-deploy > /dev/null << 'EOF'
  /var/log/deploy-*.log {
    daily
    missingok
    rotate 30
    compress
  }
  EOF
  ```

### Verification
- [ ] Test Docker access
  ```bash
  sudo -u deploy docker ps
  ```

- [ ] Test Docker Compose
  ```bash
  sudo -u deploy docker compose version
  ```

- [ ] Pull images
  ```bash
  cd /opt/lidbema
  sudo -u deploy docker compose pull
  ```

- [ ] Test deployment script
  ```bash
  sudo -u deploy /opt/lidbema/deploy-enhanced.sh staging status
  ```

- [ ] Test SSH from local machine
  ```bash
  ssh -i ~/.ssh/lidbema_deploy deploy@STAGING_IP "docker ps"
  ```

---

## Production Server Setup

**Repeat all steps from Staging Server Setup section, but:**

- [ ] Use `.env.production` instead of `.env.staging`
  ```bash
  ENVIRONMENT=production
  NODE_ENV=production
  LOG_LEVEL=warn
  BACKUP_BASE_DIR=/backups/production
  GRAFANA_ADMIN_PASSWORD=prod_password
  ```

- [ ] Use `/backups/production` instead of `/backups/staging`

- [ ] Use `./deploy-enhanced.sh production` instead of staging

- [ ] Test SSH to production server
  ```bash
  ssh -i ~/.ssh/lidbema_deploy deploy@PROD_IP "docker ps"
  ```

---

## GitHub Configuration

### Add Repository Secrets

Go to: **Settings → Secrets and variables → Actions**

- [ ] STAGING_DEPLOY_KEY
  - Value: `cat ~/.ssh/lidbema_deploy` (private key content)

- [ ] STAGING_DEPLOY_HOST
  - Value: `staging.example.com` (staging server address)

- [ ] STAGING_DEPLOY_USER
  - Value: `deploy`

- [ ] PROD_DEPLOY_KEY
  - Value: `cat ~/.ssh/lidbema_deploy` (private key content)

- [ ] PROD_DEPLOY_HOST
  - Value: `prod.example.com` (production server address)

- [ ] PROD_DEPLOY_USER
  - Value: `deploy`

- [ ] SLACK_WEBHOOK (Optional)
  - Value: Your Slack webhook URL

### Configure Environments

Go to: **Settings → Environments**

- [ ] Create "staging" environment
  - No additional configuration needed

- [ ] Create "production" environment
  - [ ] Enable "Required reviewers"
  - [ ] Add team members who can approve deployments

---

## Testing & Validation

### Manual Deployment Test
- [ ] SSH into staging server
  ```bash
  ssh deploy@STAGING_IP
  ```

- [ ] Update code
  ```bash
  cd /opt/lidbema
  git pull origin develop
  ```

- [ ] Run deployment
  ```bash
  ./deploy-enhanced.sh staging deploy
  ```

- [ ] Check status
  ```bash
  ./deploy-enhanced.sh staging status
  ```

- [ ] Run smoke tests
  ```bash
  ./smoke-tests.sh staging http://localhost
  ```

### CI/CD Pipeline Test
- [ ] Push to develop branch
  ```bash
  git push origin develop
  ```

- [ ] Monitor GitHub Actions
  - Go to: https://github.com/YOUR_ORG/lidbema/actions
  - Watch "Deploy Pipeline" workflow

- [ ] Verify staging deployment
  - [ ] Build completed
  - [ ] Security scan completed
  - [ ] Tests passed
  - [ ] Deployed to staging
  - [ ] Health checks passed
  - [ ] Smoke tests passed

- [ ] Push to main branch
  ```bash
  git push origin main
  ```

- [ ] Verify production deployment
  - [ ] Awaiting approval notification
  - [ ] Approve deployment in GitHub
  - [ ] Pre-deployment backup created
  - [ ] Deployed to production
  - [ ] Health checks passed
  - [ ] All services healthy

---

## Post-Setup

### First Deployment
- [ ] SSH to staging, manual deploy and verify
- [ ] SSH to production, manual deploy and verify
- [ ] Test backup creation
- [ ] Test restore procedure

### Monitor & Document
- [ ] Note server IPs/hostnames
- [ ] Document admin passwords
- [ ] Store SSH keys securely
- [ ] Share access info with team

### Access Points
- [ ] Staging Grafana: `http://STAGING_IP:3100` (admin/admin)
- [ ] Production Grafana: `http://PROD_IP:3100` (admin/admin)
- [ ] Update Grafana passwords after first login

---

## Troubleshooting Quick Fixes

| Problem | Solution |
|---------|----------|
| Permission denied on /opt/lidbema | `sudo chown deploy:deploy /opt/lidbema -R` |
| Docker command not found | `sudo usermod -aG docker deploy` (requires relogin) |
| SSH key not accepted | Check key permissions: `ls -la /home/deploy/.ssh/` |
| Docker Compose pull fails | `sudo systemctl restart docker` |
| Backups not created | `sudo chown deploy:deploy /backups -R` |
| Logs not rotating | Check: `sudo cat /etc/logrotate.d/lidbema-deploy` |

---

## Server Information Sheet

Fill in this info for future reference:

**Staging Server:**
- Hostname/IP: `_______________`
- SSH Username: `deploy`
- SSH Key: `~/.ssh/lidbema_deploy`
- Repository Path: `/opt/lidbema`
- Backup Path: `/backups/staging`
- Grafana URL: `http://_______________:3100`
- Status Command: `./deploy-enhanced.sh staging status`

**Production Server:**
- Hostname/IP: `_______________`
- SSH Username: `deploy`
- SSH Key: `~/.ssh/lidbema_deploy`
- Repository Path: `/opt/lidbema`
- Backup Path: `/backups/production`
- Grafana URL: `http://_______________:3100`
- Status Command: `./deploy-enhanced.sh production status`

---

## Completion Status

**Staging Server:**
- [ ] System setup complete
- [ ] User & permissions configured
- [ ] Repository cloned
- [ ] Environment files created
- [ ] Backups configured
- [ ] All verification tests passed

**Production Server:**
- [ ] System setup complete
- [ ] User & permissions configured
- [ ] Repository cloned
- [ ] Environment files created
- [ ] Backups configured
- [ ] All verification tests passed

**GitHub Configuration:**
- [ ] All 6+ secrets added
- [ ] Environments configured
- [ ] Required reviewers set up

**Testing:**
- [ ] Manual deployment test passed
- [ ] CI/CD pipeline test passed
- [ ] Smoke tests passed

---

**When complete, you're ready for automated deployments!**

Next: Push to develop branch to test staging pipeline, then to main for production.
