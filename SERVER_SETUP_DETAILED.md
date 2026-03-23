# Deployment Server Setup - Detailed Guide

Complete setup instructions for staging and production deployment servers.

---

## Prerequisites - What You Need

Before starting, ensure you have:

1. **Two Linux Servers** (Ubuntu 20.04+ or Debian 11+)
   - One for staging environment
   - One for production environment
   - Both with internet access for Docker pulls

2. **SSH Access**
   - Can SSH into both servers as root or with sudo
   - Can create files and users

3. **GitHub Repository**
   - Your Lidbema repository URL
   - SSH key for git authentication (optional, can use HTTPS)

4. **Deployment SSH Keys**
   - Generate ED25519 keys for deployment authentication
   - Will be added to GitHub as secrets

---

## Step 1: Generate SSH Keys (Run on Your Local Machine)

Generate the SSH key pair that will be used for automated deployments:

```bash
# Generate ED25519 key (more secure than RSA)
ssh-keygen -t ed25519 -f ~/.ssh/lidbema_deploy -N ""

# View the private key (will add to GitHub secret STAGING_DEPLOY_KEY)
cat ~/.ssh/lidbema_deploy

# View the public key (will add to deployment servers)
cat ~/.ssh/lidbema_deploy.pub
```

**Output:**
```
Your identification has been saved in ~/.ssh/lidbema_deploy
Your public key has been saved in ~/.ssh/lidbema_deploy.pub
```

Keep these files safe. You'll use them in the next steps.

---

## Step 2: System Setup (Run on Each Server)

Connect to your staging/production server and run these commands:

### 2a. Update System

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y git curl wget
```

### 2b. Install Docker

```bash
# Download Docker install script
curl -fsSL https://get.docker.com -o get-docker.sh

# Install Docker
sudo sh get-docker.sh

# Verify installation
docker --version
docker compose version

# Cleanup
rm get-docker.sh
```

### 2c. Create Deploy User

```bash
# Create deploy user (non-interactive, no password login)
sudo useradd -m -s /bin/bash deploy

# Add deploy user to docker group (allows docker commands without sudo)
sudo usermod -aG docker deploy

# Verify user created
id deploy
```

### 2d. Create Deployment Directory

```bash
# Create directory for Lidbema repository
sudo mkdir -p /opt/lidbema

# Set ownership to deploy user
sudo chown deploy:deploy /opt/lidbema

# Set permissions
sudo chmod 755 /opt/lidbema

# Verify
ls -ld /opt/lidbema
```

---

## Step 3: SSH Key Setup (Run on Each Server)

Add your public key so GitHub Actions can SSH into the server:

```bash
# Create .ssh directory for deploy user
sudo mkdir -p /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh

# Copy your public key (replace with actual key from Step 1)
echo "ssh-ed25519 AAAA..." | sudo tee -a /home/deploy/.ssh/authorized_keys

# Set proper permissions
sudo chmod 600 /home/deploy/.ssh/authorized_keys
sudo chown deploy:deploy /home/deploy/.ssh -R

# Verify (you should see your key)
sudo cat /home/deploy/.ssh/authorized_keys
```

**Replace "AAAA..." with your actual public key from `cat ~/.ssh/lidbema_deploy.pub`**

---

## Step 4: Docker Permissions (Run on Each Server)

Allow deploy user to run Docker without entering password:

```bash
# Create sudoers file for deploy user
echo "deploy ALL=(ALL) NOPASSWD: /usr/bin/docker" | sudo tee -a /etc/sudoers.d/deploy

# Set proper permissions
sudo chmod 0440 /etc/sudoers.d/deploy

# Verify
sudo -u deploy docker ps
```

**Expected Output:** Should return empty container list (no error)

---

## Step 5: Git Configuration (Run on Each Server)

Clone the Lidbema repository:

```bash
# Switch to deploy user
sudo su - deploy

# Clone the repository (using HTTPS is simplest for initial setup)
git clone https://github.com/YOUR_ORG/lidbema.git /opt/lidbema

# Change to repository directory
cd /opt/lidbema

# Verify files exist
ls -la

# Exit deploy user shell
exit
```

**Replace `YOUR_ORG` with your actual GitHub organization name**

---

## Step 6: Environment Files (Run on Each Server)

Create environment configuration files:

### For Staging Server Only:

```bash
sudo tee /opt/lidbema/.env.staging > /dev/null << 'EOF'
# Staging Environment Configuration
ENVIRONMENT=staging
NODE_ENV=production
LOG_LEVEL=info

# Lidbema Configuration
LIDBEMA_REPLICAS=1
LIDBEMA_LOG_LEVEL=info

# NexNod Configuration
NEXNOD_REPLICAS=3
NEXNOD_CLUSTER_SIZE=3

# Monitoring
PROMETHEUS_RETENTION=15d
GRAFANA_ADMIN_PASSWORD=staging_admin_password_change_me

# Backup Settings
BACKUP_RETENTION_DAYS=30
BACKUP_BASE_DIR=/backups/staging

# Deployment Settings
DEPLOYMENT_TIMEOUT=600
ROLLBACK_ON_HEALTH_CHECK_FAILURE=true
EOF

# Set permissions
sudo chown deploy:deploy /opt/lidbema/.env.staging
sudo chmod 600 /opt/lidbema/.env.staging
```

### For Production Server Only:

```bash
sudo tee /opt/lidbema/.env.production > /dev/null << 'EOF'
# Production Environment Configuration
ENVIRONMENT=production
NODE_ENV=production
LOG_LEVEL=warn

# Lidbema Configuration
LIDBEMA_REPLICAS=1
LIDBEMA_LOG_LEVEL=warn

# NexNod Configuration
NEXNOD_REPLICAS=3
NEXNOD_CLUSTER_SIZE=3

# Monitoring
PROMETHEUS_RETENTION=30d
GRAFANA_ADMIN_PASSWORD=production_secure_password_change_me

# Backup Settings
BACKUP_RETENTION_DAYS=90
BACKUP_BASE_DIR=/backups/production

# Deployment Settings
DEPLOYMENT_TIMEOUT=600
ROLLBACK_ON_HEALTH_CHECK_FAILURE=true
EOF

# Set permissions
sudo chown deploy:deploy /opt/lidbema/.env.production
sudo chmod 600 /opt/lidbema/.env.production
```

---

## Step 7: Backup Directory Setup (Run on Each Server)

Create directories for automated backups:

```bash
# Create backup directories
sudo mkdir -p /backups/staging/volumes
sudo mkdir -p /backups/production/volumes

# Set ownership to deploy user
sudo chown deploy:deploy /backups -R

# Set permissions
sudo chmod 755 /backups
sudo chmod 755 /backups/staging
sudo chmod 755 /backups/staging/volumes
sudo chmod 755 /backups/production
sudo chmod 755 /backups/production/volumes

# Verify
ls -ld /backups/staging /backups/production
```

---

## Step 8: Log Rotation Setup (Run on Each Server)

Set up log rotation for deployment logs:

```bash
sudo tee /etc/logrotate.d/lidbema-deploy > /dev/null << 'EOF'
/var/log/deploy-*.log {
  daily
  missingok
  rotate 30
  compress
  delaycompress
  notifempty
  create 0640 deploy deploy
  sharedscripts
  postrotate
    systemctl reload rsyslog > /dev/null 2>&1 || true
  endscript
}
EOF

# Verify
sudo cat /etc/logrotate.d/lidbema-deploy
```

---

## Step 9: Verification (Run on Each Server)

Test that everything is configured correctly:

### 9a. Test Docker

```bash
# Switch to deploy user
sudo su - deploy

# Test Docker access
docker ps

# Test Docker Compose
cd /opt/lidbema
docker compose version

# Test pulling images
docker compose pull

# Exit
exit
```

**Expected Output:** Should show no errors, list containers if any exist

### 9b. Test Deployment Script

```bash
sudo su - deploy
cd /opt/lidbema

# Check status (should show healthy services if already deployed)
./deploy-enhanced.sh staging status

# Or for production
./deploy-enhanced.sh production status

exit
```

### 9c. Test SSH Access

From your local machine, verify SSH access works:

```bash
# Test SSH to staging server
ssh -i ~/.ssh/lidbema_deploy deploy@staging.example.com "docker ps"

# Test SSH to production server
ssh -i ~/.ssh/lidbema_deploy deploy@prod.example.com "docker ps"
```

**Expected Output:** Should return Docker containers or empty list

---

## Step 10: GitHub Secrets Configuration

Add these secrets to your GitHub repository so CI/CD can deploy:

### On GitHub:
1. Go to: **Settings → Secrets and variables → Actions**
2. Click **New repository secret**

### Add These 6 Secrets:

**STAGING_DEPLOY_KEY**
- Value: Contents of `~/.ssh/lidbema_deploy` (private key)
- Description: SSH private key for staging deployment

**STAGING_DEPLOY_HOST**
- Value: `staging.example.com` (your actual staging server hostname/IP)
- Description: Hostname or IP of staging server

**STAGING_DEPLOY_USER**
- Value: `deploy`
- Description: SSH username for staging deployments

**PROD_DEPLOY_KEY**
- Value: Contents of `~/.ssh/lidbema_deploy` (same private key)
- Description: SSH private key for production deployment

**PROD_DEPLOY_HOST**
- Value: `prod.example.com` (your actual production server hostname/IP)
- Description: Hostname or IP of production server

**PROD_DEPLOY_USER**
- Value: `deploy`
- Description: SSH username for production deployments

**SLACK_WEBHOOK** (Optional)
- Value: Your Slack webhook URL
- Description: For deployment notifications

---

## Step 11: Pre-Deployment Testing

Test the complete deployment workflow:

### 11a. Manual Test on Staging

```bash
# SSH into staging server as deploy user
ssh deploy@staging.example.com

# Go to repository
cd /opt/lidbema

# Pull latest code
git pull origin develop

# Run manual deployment
./deploy-enhanced.sh staging deploy

# Check status
./deploy-enhanced.sh staging status

# Run smoke tests
./smoke-tests.sh staging http://localhost
```

### 11b. Test GitHub Actions Integration

```bash
# From your local machine, push to develop branch
git push origin develop

# Watch GitHub Actions:
# Go to https://github.com/YOUR_ORG/lidbema/actions
# Should see "Deploy Pipeline" workflow running
# Monitor until completion
```

---

## Common Issues & Solutions

### Issue: Docker command not found
**Solution:** 
```bash
# Ensure deploy user is in docker group
sudo usermod -aG docker deploy

# User needs to log out and back in for group changes to take effect
```

### Issue: Permission denied on /opt/lidbema
**Solution:**
```bash
# Fix permissions
sudo chown deploy:deploy /opt/lidbema -R
sudo chmod 755 /opt/lidbema
```

### Issue: SSH key authentication fails
**Solution:**
```bash
# Verify key permissions
sudo -u deploy cat /home/deploy/.ssh/authorized_keys

# Fix permissions if needed
sudo chmod 600 /home/deploy/.ssh/authorized_keys
sudo chmod 700 /home/deploy/.ssh
```

### Issue: Docker Compose fails
**Solution:**
```bash
# Ensure Docker daemon is running
sudo systemctl status docker
sudo systemctl start docker

# Test compose
docker compose version
```

### Issue: Git clone fails
**Solution:**
```bash
# If using SSH, ensure you have SSH key set up for git
# Or use HTTPS with personal access token:
git clone https://USERNAME:TOKEN@github.com/YOUR_ORG/lidbema.git
```

---

## Monitoring Server Health

### Check Docker status

```bash
# Is Docker running?
sudo systemctl status docker

# Docker disk usage
docker system df

# Running containers
docker ps

# View logs
docker compose logs --tail=50
```

### Check deployment user

```bash
# Is deploy user configured?
id deploy

# Can deploy user run docker?
sudo -u deploy docker ps
```

### Check backup storage

```bash
# Is backup directory present?
ls -ld /backups/staging /backups/production

# Backup storage usage
du -sh /backups/*

# Recent backups
ls -lh /backups/staging/volumes/ | head -10
```

---

## Maintenance

### Regular Tasks

**Weekly:**
- Check Docker disk usage: `docker system df`
- Verify deployments succeed
- Monitor backup completion

**Monthly:**
- Review Docker logs
- Clean up old images: `docker image prune -a`
- Verify disaster recovery procedures

**Quarterly:**
- Test full backup/restore cycle
- Review and update security settings
- Update Docker and system packages

### Updating Docker

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Verify Docker still works
docker ps
docker compose version
```

---

## Security Best Practices

1. **SSH Keys**
   - Use ED25519 keys (not RSA)
   - Rotate keys annually
   - Never commit private keys to git

2. **Passwords**
   - Use strong passwords for Grafana/database
   - Store in GitHub secrets, not in config files
   - Rotate monthly

3. **Firewall**
   - Restrict SSH to known IPs
   - Only expose necessary ports (80, 443)
   - Use VPN for admin access

4. **Monitoring**
   - Monitor failed deployment attempts
   - Alert on disk space issues
   - Track service health

5. **Backups**
   - Test restore procedures monthly
   - Store backups off-site (S3, etc.)
   - Verify backup integrity

---

## Next Steps

1. ✓ Run all setup steps on staging server first
2. ✓ Test manual deployments
3. ✓ Verify GitHub Actions integration
4. ✓ Run same setup on production server
5. ✓ Add GitHub secrets
6. ✓ Test CI/CD pipeline with develop branch
7. ✓ Test production deployment with approval

---

## Summary

**You have successfully:**
- ✓ Set up Docker on deployment servers
- ✓ Created deploy user with proper permissions
- ✓ Configured SSH key authentication
- ✓ Set up backup directories
- ✓ Configured environment files
- ✓ Prepared for automated deployments

**Pipeline is now ready for:**
- Automated staging deployments from `develop` branch
- Automated production deployments (with approval) from `main` branch
- Zero-downtime deployments with automatic rollback
- Comprehensive monitoring and alerting

---

## Support

For issues or questions:
1. Check the "Common Issues & Solutions" section above
2. Review logs: `./deploy-enhanced.sh staging logs`
3. Run diagnostics: `./deploy-enhanced.sh staging status`
4. Check GitHub Actions output for detailed error messages

**Last Updated:** 2026-03-16  
**Status:** Ready for Production Deployment
