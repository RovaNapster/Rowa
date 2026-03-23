# Tailscale VPN Setup - Implementation Guide

Complete setup guide for Tailscale VPN integration with your deployment pipeline.

---

## Auth Key Status

✅ **Received:** tskey-client-ktMzc8Yx9411CNTRL-MEaT7AkPMPYCir6QvmzcPYNC4eQxEBQw  
✅ **Type:** Reusable client auth key  
✅ **Format:** Valid Tailscale token  
✅ **Status:** Ready to use  

---

## What You Get with Tailscale

✓ **Secure VPN** - End-to-end encrypted mesh network  
✓ **Zero-config** - Automatic NAT traversal and key exchange  
✓ **Remote SSH** - SSH to servers without exposing SSH ports  
✓ **Service Access** - Access monitoring dashboards securely  
✓ **Team Access** - Add team members to private network  
✓ **Works Anywhere** - Through firewalls, NAT, etc.  

---

## 5-Step Implementation

### Step 1: Add GitHub Secret (2 minutes)

**Go to:** GitHub repository → Settings → Secrets and variables → Actions

**Click:** "New repository secret"

**Add:**
```
Name: TAILSCALE_AUTH_KEY
Value: tskey-client-ktMzc8Yx9411CNTRL-MEaT7AkPMPYCir6QvmzcPYNC4eQxEBQw
```

**Click:** "Add secret"

### Step 2: Update docker-compose.yml (3 minutes)

Add to your `docker-compose.yml` (before `networks:` section):

```yaml
  tailscale:
    image: tailscale/tailscale:latest
    container_name: tailscale-vpn
    cap_add:
      - NET_ADMIN
    volumes:
      - /var/lib/tailscale:/var/lib/tailscale
      - /dev/net/tun:/dev/net/tun
    environment:
      - TS_AUTHKEY=${TAILSCALE_AUTH_KEY}
      - TS_STATE_DIR=/var/lib/tailscale
    networks:
      - monitoring-network
    restart: unless-stopped
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv6.conf.all.forwarding=1
    healthcheck:
      test: ["CMD", "tailscale", "status"]
      interval: 30s
      timeout: 10s
      retries: 3
```

Or copy from: `docker-compose-tailscale-integration.yml`

### Step 3: Add Environment Variable (1 minute)

Add to `.env.staging` and `.env.production`:

```bash
TAILSCALE_AUTH_KEY=tskey-client-ktMzc8Yx9411CNTRL-MEaT7AkPMPYCir6QvmzcPYNC4eQxEBQw
```

### Step 4: Deploy on Staging (5 minutes)

```bash
# SSH to staging server
ssh deploy@staging-server

# Go to repository
cd /opt/lidbema

# Source environment
export $(cat .env.staging | xargs)

# Deploy Tailscale
docker compose up -d tailscale

# Get Tailscale IP (wait 10-15 seconds)
docker exec tailscale tailscale ip -4
# Output: 100.x.y.z

# Verify status
docker exec tailscale tailscale status
```

### Step 5: Connect Locally (2 minutes)

**On your local machine:**

```bash
# Install Tailscale
# macOS: brew install tailscale
# Linux: curl -fsSL https://tailscale.com/install.sh | sh
# Windows: https://tailscale.com/download

# Authenticate
tailscale up

# Verify connection
tailscale status

# SSH to server via VPN
ssh -i ~/.ssh/lidbema_deploy deploy@100.x.y.z

# Access services
http://100.x.y.z:3100  # Grafana
http://100.x.y.z:9090  # Prometheus
http://100.x.y.z:3000  # Lidbema PWA
```

**Total Time: ~15 minutes setup + testing**

---

## Verify Everything Works

### On Staging Server

```bash
# Check Tailscale running
docker ps | grep tailscale

# Get IP
docker exec tailscale tailscale ip -4

# Check status
docker exec tailscale tailscale status
```

### On Your Local Machine

```bash
# Check Tailscale connected
tailscale status

# Ping server
tailscale ping 100.x.y.z

# SSH test
ssh -i ~/.ssh/lidbema_deploy deploy@100.x.y.z "docker ps"

# Web access test
curl http://100.x.y.z:3100
```

### If Tests Fail

```bash
# Check logs
docker logs tailscale

# Restart
docker restart tailscale

# Wait 15 seconds and try again
sleep 15
docker exec tailscale tailscale status
```

---

## Network Topology

```
Your Local Machine
├─ Tailscale IP: 100.x.x.1
├─ Installed: tailscale
└─ Can reach: All servers

Staging Server (VPN)
├─ Tailscale IP: 100.x.x.2
├─ Container: tailscale
├─ Ports: 3001-3003 (zones), 3000 (PWA), 9090 (prometheus), 3100 (grafana)
└─ All services accessible via VPN IP

Production Server (VPN)
├─ Tailscale IP: 100.x.x.3
├─ Container: tailscale
├─ Ports: Same as staging
└─ All services accessible via VPN IP
```

---

## Accessing Services Via Tailscale

### SSH Access (No SSH port exposure!)

```bash
# Before: Needed to expose port 22
# Now: SSH only available through VPN

ssh -i ~/.ssh/lidbema_deploy deploy@100.x.y.z
```

### Grafana Dashboard

```bash
# URL: http://TAILSCALE_IP:3100
# Example: http://100.x.y.z:3100
# Credentials: admin/admin
```

### Prometheus Metrics

```bash
# URL: http://TAILSCALE_IP:9090
# Example: http://100.x.y.z:9090
```

### All Services

```bash
# Any service is accessible via Tailscale IP + port
http://100.x.y.z:3001  # Lidbema Zone 1
http://100.x.y.z:3002  # Lidbema Zone 2
http://100.x.y.z:3003  # Lidbema Zone 3
http://100.x.y.z:4001  # NexNod Node 1
# ... and so on
```

---

## GitHub Actions Integration (Optional)

Update `.github/workflows/deploy.yml`:

```yaml
  deploy-production:
    runs-on: ubuntu-latest
    needs: [test, security-scan]
    environment: production
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Connect Tailscale
        uses: tailscale/github-action@v2
        with:
          authkey: ${{ secrets.TAILSCALE_AUTH_KEY }}

      - name: Deploy via VPN
        run: |
          ssh -i ~/.ssh/lidbema_deploy \
              deploy@${{ secrets.PROD_DEPLOY_HOST }} \
              'cd /opt/lidbema && ./deploy-enhanced.sh production deploy'
```

---

## Security Features

✓ **Encryption** - End-to-end encrypted all traffic  
✓ **No Ports** - SSH and services don't need public ports  
✓ **Access Control** - Tailscale ACLs for fine-grained control  
✓ **Key-based Auth** - No passwords, only SSH keys  
✓ **Audit Trail** - All connections logged  
✓ **Revocable** - Can immediately revoke access  

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Container won't start | Check logs: `docker logs tailscale` |
| No Tailscale IP | Wait 15 seconds, retry: `docker exec tailscale tailscale ip -4` |
| Can't SSH | Verify local Tailscale: `tailscale status` |
| Slow connection | Check routes: `docker exec tailscale tailscale routes` |
| Services not accessible | Verify Tailscale IP: `docker exec tailscale tailscale ip -4` |

---

## Monitoring

```bash
# Check status
docker exec tailscale tailscale status

# View logs
docker logs -f tailscale

# Monitor resources
docker stats tailscale

# Test connectivity
docker exec tailscale tailscale ping 100.x.x.2
```

---

## Files Provided

1. **TAILSCALE_GUIDE.md** (10.5 KB)
   - Complete integration guide
   - Use cases and setup steps

2. **TAILSCALE_DEPLOYMENT.md** (7.6 KB)
   - Deployment configuration
   - Quick commands and troubleshooting

3. **docker-compose-tailscale-integration.yml** (7.5 KB)
   - Ready-to-use Docker Compose service
   - Just copy-paste to your docker-compose.yml

---

## Implementation Timeline

**Day 1:**
- [ ] Add GitHub Secret (2 min)
- [ ] Update docker-compose.yml (3 min)
- [ ] Add env variables (1 min)
- [ ] Deploy on staging (5 min)
- [ ] Test locally (5 min)
- **Total: 16 minutes**

**Day 2:**
- [ ] Deploy on production (5 min)
- [ ] Test end-to-end (10 min)
- [ ] Update GitHub Actions (5 min)
- [ ] Final verification (5 min)
- **Total: 25 minutes**

**When ready for production:**
- [ ] All testing complete
- [ ] Documentation updated
- [ ] Team trained on VPN access
- [ ] Ready for deployment

---

## Success Criteria

You've successfully set up Tailscale when:

- ✓ Auth key added to GitHub Secrets
- ✓ Tailscale service in docker-compose.yml
- ✓ Container running: `docker ps | grep tailscale`
- ✓ Tailscale IP obtained: `docker exec tailscale tailscale ip -4`
- ✓ Local Tailscale connected: `tailscale status`
- ✓ Can SSH to server: `ssh deploy@100.x.y.z`
- ✓ Can access services: `http://100.x.y.z:3100`

---

## Next Actions

**Immediate (Now):**
1. Review this guide
2. Review TAILSCALE_GUIDE.md
3. Review docker-compose-tailscale-integration.yml

**This Week:**
1. Add GitHub Secret
2. Update docker-compose.yml
3. Deploy on staging
4. Test connectivity

**Next Week:**
1. Deploy on production
2. Update GitHub Actions
3. Final verification
4. Team documentation

---

## Support Resources

- **Tailscale Docs:** https://tailscale.com/kb/
- **Docker Hub:** https://hub.docker.com/r/tailscale/tailscale
- **Admin Panel:** https://login.tailscale.com
- **GitHub Action:** https://github.com/tailscale/github-action

---

## Summary

✅ Auth key received and documented  
✅ Tailscale image pulled (165MB)  
✅ Configuration files created  
✅ Integration guide complete  
✅ Troubleshooting documented  

**Status: Ready for immediate deployment**

---

**Auth Key:** tskey-client-ktMzc8Yx9411CNTRL-MEaT7AkPMPYCir6QvmzcPYNC4eQxEBQw  
**Setup Time:** 15-30 minutes  
**Benefit:** Secure VPN access to all infrastructure  
**Next Action:** Add to GitHub Secrets, then deploy!
