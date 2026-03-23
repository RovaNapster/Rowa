# Deployment Server Setup

Run this on your staging and production servers to prepare for automated deployments.

## Prerequisites

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker (Ubuntu/Debian)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add deploy user
sudo useradd -m -s /bin/bash deploy
sudo usermod -aG docker deploy

# Create deployment directory
sudo mkdir -p /opt/lidbema
sudo chown deploy:deploy /opt/lidbema
```

## SSH Setup

```bash
# As root or with sudo:
mkdir -p /home/deploy/.ssh
chmod 700 /home/deploy/.ssh

# Add your public key:
echo "ssh-ed25519 AAAA..." >> /home/deploy/.ssh/authorized_keys
chmod 600 /home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy/.ssh -R
```

## Sudoers Configuration

Allow deploy user to run docker commands without password:

```bash
echo "deploy ALL=(ALL) NOPASSWD: /usr/bin/docker" | sudo tee -a /etc/sudoers.d/deploy
sudo chmod 0440 /etc/sudoers.d/deploy
```

## Repository Setup

```bash
sudo -u deploy git clone https://github.com/YOUR_ORG/lidbema /opt/lidbema
cd /opt/lidbema
sudo -u deploy git remote set-url origin git@github.com:YOUR_ORG/lidbema.git
```

## Environment Files

Create these files on the deployment server:

### /opt/lidbema/.env.staging
```bash
ENVIRONMENT=staging
NODE_ENV=production
LOG_LEVEL=info
BACKUP_BASE_DIR=/backups/staging
GRAFANA_ADMIN_PASSWORD=YOUR_SECURE_PASSWORD
```

### /opt/lidbema/.env.production
```bash
ENVIRONMENT=production
NODE_ENV=production
LOG_LEVEL=warn
BACKUP_BASE_DIR=/backups/production
GRAFANA_ADMIN_PASSWORD=YOUR_SECURE_PASSWORD
```

## Backup Directory Setup

```bash
sudo mkdir -p /backups/staging /backups/production
sudo chown deploy:deploy /backups -R
sudo chmod 755 /backups -R
```

## Verification

```bash
# Test deployment script
cd /opt/lidbema
./deploy-enhanced.sh staging status

# Test image pull
docker compose pull

# Run preflight check
./deploy-enhanced.sh staging deploy --dry-run
```

## Monitoring

Set up log rotation for deployment logs:

```bash
sudo tee /etc/logrotate.d/lidbema-deploy << 'LOGROTATE'
/var/log/deploy-*.log {
  daily
  missingok
  rotate 30
  compress
  delaycompress
  notifempty
  create 0640 deploy deploy
  sharedscripts
}
LOGROTATE
```

