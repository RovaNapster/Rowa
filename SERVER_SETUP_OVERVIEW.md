# Server Setup Materials - Overview

Complete documentation for setting up deployment servers.

---

## Available Setup Guides

### 1. **SERVER_SETUP.md** (Quick Reference)
- Concise commands for each setup step
- Best for: Quick copy-paste reference
- Time: 30-45 minutes per server
- Audience: Experienced DevOps engineers

### 2. **SERVER_SETUP_DETAILED.md** (Complete Guide)
- Detailed explanations for each step
- Context for why each step matters
- Troubleshooting solutions included
- Best for: First-time setup, need understanding
- Time: 1-2 hours per server
- Audience: Everyone, especially new to deployment

### 3. **SERVER_SETUP_CHECKLIST.md** (Implementation Checklist)
- Step-by-step checkboxes
- Fill-in template for server info
- Quick troubleshooting table
- Best for: Tracking progress, ensuring nothing missed
- Time: Use alongside detailed guide
- Audience: Project managers, operations teams

---

## Setup Workflow

```
Local Machine
    ↓
Generate SSH Keys
    ↓
┌─ Staging Server ────────────────────────────────────┐
│                                                      │
│ 1. System Setup (Docker, Git)                       │
│ 2. User Setup (deploy user, permissions)            │
│ 3. SSH Key Setup (public key auth)                  │
│ 4. Repository Setup (git clone)                     │
│ 5. Configuration (env files)                        │
│ 6. Backup Setup (directories)                       │
│ 7. Verification (test everything)                   │
│                                                      │
└─ Test: Manual deployment ───────────────────────────┘
         ↓
┌─ Production Server (Same steps as staging) ─────────┐
│                                                      │
│ 1. System Setup (Docker, Git)                       │
│ 2. User Setup (deploy user, permissions)            │
│ 3. SSH Key Setup (public key auth)                  │
│ 4. Repository Setup (git clone)                     │
│ 5. Configuration (env files)                        │
│ 6. Backup Setup (directories)                       │
│ 7. Verification (test everything)                   │
│                                                      │
└─ Test: Manual deployment ───────────────────────────┘
         ↓
GitHub Configuration
    ↓
Add 6+ Secrets (SSH keys, hostnames, usernames)
    ↓
Test CI/CD Pipeline
    ↓
git push origin develop
    ↓
Staging auto-deploys
    ↓
git push origin main (with approval)
    ↓
Production auto-deploys
    ↓
✓ Fully automated pipeline operational
```

---

## What Gets Set Up

### System Components
- ✓ Docker Engine
- ✓ Docker Compose
- ✓ Git
- ✓ curl & wget utilities

### User & Access
- ✓ `deploy` system user
- ✓ SSH key authentication (ED25519)
- ✓ Docker group membership (no sudo needed)
- ✓ Sudo access for Docker commands

### Directories
- ✓ `/opt/lidbema` - Repository location
- ✓ `/backups/staging/volumes` - Staging backups
- ✓ `/backups/production/volumes` - Production backups

### Configuration
- ✓ `.env.staging` - Staging environment vars
- ✓ `.env.production` - Production environment vars
- ✓ Log rotation configuration
- ✓ Docker settings

---

## Time Estimate

| Task | Time |
|------|------|
| Generate SSH keys (local) | 2 minutes |
| Staging server setup | 30-45 minutes |
| Production server setup | 30-45 minutes |
| GitHub configuration | 5 minutes |
| Testing & validation | 10 minutes |
| **TOTAL** | **1.5-2 hours** |

---

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] Two Linux servers (Ubuntu 20.04+ or Debian 11+)
- [ ] Root or sudo access to both servers
- [ ] SSH access to both servers
- [ ] GitHub repository with deployment workflow configured
- [ ] Internet connection on servers (for Docker pulls)
- [ ] Ability to copy/paste between local machine and servers
- [ ] Text editor (nano, vim, or similar)

---

## Key Information to Gather

Before setup, collect this information:

**Staging Server:**
```
Hostname/IP: _________________________
Username: root or ubuntu
SSH Port: _____ (usually 22)
```

**Production Server:**
```
Hostname/IP: _________________________
Username: root or ubuntu
SSH Port: _____ (usually 22)
```

**GitHub:**
```
Organization: _________________________
Repository: _________________________
Repository URL: _________________________
```

---

## Expected Outputs

After successful setup, you should have:

### On Each Server:
```
/opt/lidbema/                    (cloned repository)
/backups/staging/                (backup location)
/home/deploy/.ssh/authorized_keys (SSH key)
~/.env.staging or .env.production (config file)
```

### In GitHub:
```
6 Secrets:
- STAGING_DEPLOY_KEY
- STAGING_DEPLOY_HOST
- STAGING_DEPLOY_USER
- PROD_DEPLOY_KEY
- PROD_DEPLOY_HOST
- PROD_DEPLOY_USER
```

### Operational Capability:
```
✓ Can SSH as deploy user
✓ Can run docker commands without sudo
✓ Can access GitHub repository
✓ Can execute deploy-enhanced.sh
✓ Can create backups
✓ Can view logs
✓ Can run health checks
```

---

## Quick Start (TL;DR)

For experienced DevOps engineers, abbreviated steps:

```bash
# 1. Generate key locally
ssh-keygen -t ed25519 -f ~/.ssh/lidbema_deploy -N ""

# 2. On each server, run:
sudo apt update && sudo apt upgrade -y && \
curl -fsSL https://get.docker.com | sh && \
sudo useradd -m -s /bin/bash deploy && \
sudo usermod -aG docker deploy && \
sudo mkdir -p /opt/lidbema && \
sudo chown deploy:deploy /opt/lidbema && \
sudo mkdir -p /backups/staging /backups/production && \
sudo chown deploy:deploy /backups -R

# 3. Add SSH key
sudo mkdir -p /home/deploy/.ssh && \
sudo chmod 700 /home/deploy/.ssh && \
echo "ssh-ed25519 AAAA..." | sudo tee -a /home/deploy/.ssh/authorized_keys && \
sudo chmod 600 /home/deploy/.ssh/authorized_keys && \
sudo chown deploy:deploy /home/deploy/.ssh -R

# 4. Clone repo
sudo -u deploy git clone https://github.com/ORG/lidbema /opt/lidbema

# 5. Create env files (.env.staging and .env.production)

# 6. Configure sudo
echo "deploy ALL=(ALL) NOPASSWD: /usr/bin/docker" | sudo tee -a /etc/sudoers.d/deploy

# 7. Verify
sudo -u deploy docker ps
cd /opt/lidbema && sudo -u deploy ./deploy-enhanced.sh staging status

# 8. Add GitHub secrets (6 total)

# 9. Test
git push origin develop
```

---

## Navigation Guide

**If you're new to this:**
1. Start with `SERVER_SETUP_DETAILED.md`
2. Use `SERVER_SETUP_CHECKLIST.md` to track progress
3. Refer to `SERVER_SETUP.md` for quick command lookup

**If you're experienced:**
1. Use `SERVER_SETUP.md` directly
2. Cross-reference `SERVER_SETUP_DETAILED.md` if stuck
3. Use checklist for final verification

**If you're managing others:**
1. Share `SERVER_SETUP_DETAILED.md` with your team
2. Use `SERVER_SETUP_CHECKLIST.md` to verify completion
3. Keep `SERVER_SETUP.md` as reference

---

## Common Mistakes to Avoid

❌ **Don't:**
- Forget to generate SSH keys first
- Skip the `chmod` commands (permission errors!)
- Use RSA keys instead of ED25519
- Set passwords for deploy user (SSH keys only)
- Run all commands as root (use `sudo -u deploy`)
- Commit private keys to git
- Forget to restart Docker after install
- Store secrets in config files (use GitHub Secrets)
- Skip verification steps
- Use different keys for staging and production

✓ **Do:**
- Generate ED25519 keys
- Set correct permissions (700 for dirs, 600 for files)
- Use sudo for system commands
- Use `sudo -u deploy` for deploy user commands
- Test SSH access before configuring GitHub
- Verify all steps complete successfully
- Document server info for future reference
- Use GitHub Secrets for sensitive data
- Test manual deployment before CI/CD
- Use identical setup for both servers

---

## Support & Troubleshooting

**Most Common Issues:**

1. **Permission Denied**
   - Solution: Review ownership and permissions
   - Check: `ls -la /opt/lidbema` `ls -la /home/deploy/.ssh`

2. **Docker Command Not Found**
   - Solution: User needs to log out and back in
   - Or: `sudo usermod -aG docker deploy`

3. **SSH Key Not Working**
   - Solution: Verify key permissions are 600
   - Check: `cat /home/deploy/.ssh/authorized_keys`

4. **Git Clone Fails**
   - Solution: Ensure URL is correct
   - Or: Use HTTPS instead of SSH: `git clone https://github.com/ORG/repo.git`

5. **Backup Directory Errors**
   - Solution: Fix ownership: `sudo chown deploy:deploy /backups -R`

**For detailed help:**
- See "Common Issues & Solutions" in SERVER_SETUP_DETAILED.md
- Run diagnostics: `./deploy-enhanced.sh staging status`
- Check logs: `docker compose logs`

---

## Success Criteria

You've successfully set up servers when:

- [x] SSH access works: `ssh -i ~/.ssh/lidbema_deploy deploy@SERVER_IP`
- [x] Docker works: `docker ps` (no errors)
- [x] Repository cloned: `/opt/lidbema` exists and contains files
- [x] Backup dirs exist: `/backups/staging` and `/backups/production`
- [x] Deploy script runs: `./deploy-enhanced.sh staging status` (no errors)
- [x] Manual deployment succeeds
- [x] GitHub secrets added and CI/CD pipeline runs
- [x] Automated deployment to staging works

---

## Next Steps After Setup

Once servers are configured:

1. **Test Staging Deployment**
   - `git push origin develop`
   - Monitor GitHub Actions
   - Verify staging deployment completes

2. **Test Production Deployment**
   - `git push origin main`
   - Approve in GitHub
   - Verify production deployment completes

3. **Configure Monitoring**
   - Access Grafana: `http://SERVER_IP:3100`
   - Set up alert notifications
   - Import or create dashboards

4. **Operational Readiness**
   - Train team on deployment procedures
   - Document runbooks
   - Set up on-call rotation

---

## Documentation Files

| File | Purpose | Read Time |
|------|---------|-----------|
| SERVER_SETUP.md | Quick reference | 5 min |
| SERVER_SETUP_DETAILED.md | Complete guide | 20 min |
| SERVER_SETUP_CHECKLIST.md | Implementation tracking | 10 min |
| This file | Overview & navigation | 5 min |

---

**Ready to set up servers?**

Choose your guide:
- **New to deployment?** → Start with `SERVER_SETUP_DETAILED.md`
- **Experienced engineer?** → Use `SERVER_SETUP.md`
- **Need to track progress?** → Use `SERVER_SETUP_CHECKLIST.md`

All guides are complete and self-contained. Pick one and follow it through to the end.
