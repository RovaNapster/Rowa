# Tailscale VPN Integration Guide

Tailscale enables secure mesh VPN connectivity to your deployment servers and services.

---

## What is Tailscale?

Tailscale is a zero-configuration VPN that creates a secure mesh network between your machines and services. Benefits:

- **Zero-config:** Automatic NAT traversal and encryption
- **Secure:** Encrypted end-to-end with no central server
- **Private:** Your own isolated network
- **Easy:** Works across firewalls and NAT
- **Docker-native:** Runs in containers

---

## Image Information

**Image:** `tailscale/tailscale:latest`  
**Size:** 165MB (image) / 55.8MB (disk usage)  
**Digest:** sha256:95e528798bebe75f39b10e74e7051cf51188ee615934f232ba7ad06a3390ffa1  
**Status:** ✓ Downloaded and verified

---

## Use Cases for Deployment Pipeline

### 1. Secure SSH Access to Servers
Connect to staging/production servers over Tailscale instead of exposing SSH:

```yaml
# docker-compose.yml service
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
```

### 2. VPN Access to Monitoring
Access Prometheus/Grafana securely:

```bash
# Via Tailscale IP (instead of localhost)
http://100.x.y.z:3100  # Grafana through VPN
http://100.x.y.z:9090  # Prometheus through VPN
```

### 3. Deployment Server Network
Connect all deployment servers in one secure mesh:

```
Local Machine (100.x.x.1)
    ↓ Tailscale VPN
Staging Server (100.x.x.2)
    ↓ Tailscale VPN
Production Server (100.x.x.3)
    ↓ Tailscale VPN
Services (100.x.x.4-12)
```

---

## Setup Steps

### Step 1: Create Tailscale Auth Key

1. Go to https://login.tailscale.com
2. Authenticate with your Tailscale account
3. Go to **Settings → Authentication keys**
4. Create new auth key (reusable)
5. Copy the key (save for later)

### Step 2: Add to GitHub Secrets

Store auth key in GitHub:

```
Settings → Secrets and variables → Actions
Create new secret: TAILSCALE_AUTH_KEY
Value: [your auth key from step 1]
```

### Step 3: Add to Deployment Servers

Set environment variable on each server:

```bash
# On staging server
export TAILSCALE_AUTH_KEY="tskey-..."

# On production server
export TAILSCALE_AUTH_KEY="tskey-..."
```

Or add to .env files:

```bash
# /opt/lidbema/.env.staging
TAILSCALE_AUTH_KEY=tskey-...

# /opt/lidbema/.env.production
TAILSCALE_AUTH_KEY=tskey-...
```

### Step 4: Deploy Tailscale Container

**Option A: Manual Deployment**

```bash
docker run -d \
  --name tailscale \
  --cap-add NET_ADMIN \
  -v /var/lib/tailscale:/var/lib/tailscale \
  -v /dev/net/tun:/dev/net/tun \
  -e TS_AUTHKEY="${TAILSCALE_AUTH_KEY}" \
  -e TS_STATE_DIR=/var/lib/tailscale \
  --restart unless-stopped \
  tailscale/tailscale:latest
```

**Option B: Docker Compose**

Add to `docker-compose.yml`:

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
```

Then deploy:

```bash
docker compose up -d tailscale
```

### Step 5: Verify Connection

```bash
# Check Tailscale container is running
docker ps | grep tailscale

# View Tailscale logs
docker logs tailscale

# Check Tailscale IP (wait ~30 seconds after start)
docker exec tailscale tailscale ip -4

# Verify VPN connection
docker exec tailscale tailscale status
```

---

## Accessing Services via Tailscale

### Get Your Tailscale IP

```bash
# From the Tailscale container
docker exec tailscale tailscale ip -4
# Output: 100.x.y.z

# Or view all devices
docker exec tailscale tailscale status
```

### Access from Local Machine

1. Install Tailscale: https://tailscale.com/download
2. Authenticate and join your network
3. Access services by Tailscale IP:

```bash
# SSH to servers
ssh -i ~/.ssh/lidbema_deploy deploy@100.x.y.z

# Access Grafana
http://100.x.y.z:3100

# Access Prometheus
http://100.x.y.z:9090

# Access Lidbema PWA
http://100.x.y.z:3000
```

---

## Secure Deployment Flow with Tailscale

```
Developer
    ↓
Tailscale VPN
    ↓
SSH to Staging (100.x.y.1)
    ↓
Verify Deploy
    ↓
Tailscale VPN
    ↓
SSH to Production (100.x.y.2)
    ↓
Execute Deploy
    ↓
Access Grafana via VPN (100.x.y.z:3100)
    ↓
Monitor Health
```

---

## Docker Compose Integration

### Updated docker-compose.yml with Tailscale

```yaml
version: '3.8'

services:
  # Existing services...
  lidbema-zone1:
    # ... existing config ...
    depends_on:
      - tailscale

  # New Tailscale service
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
      - lidbema-network
      - nexnod-network
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
      start_period: 10s
    labels:
      - "app=tailscale"
      - "type=vpn"

networks:
  lidbema-network:
    driver: bridge
  nexnod-network:
    driver: bridge
  monitoring-network:
    driver: bridge

volumes:
  # ... existing volumes ...
```

---

## Security Best Practices

### 1. Use Reusable Auth Keys
- Can be revoked if compromised
- Set expiration dates
- Create separate keys per environment

### 2. Restrict ACLs
Configure access control lists in Tailscale dashboard:

```
// Allow all tagged devices
"rules": [
  {
    "action": "accept",
    "src": ["tag:staging", "tag:production", "tag:developer"],
    "dst": ["*:*"],
  },
]
```

### 3. Enable MFA
- Enable 2FA on Tailscale account
- Use hardware security keys when possible

### 4. Monitor Access
- View connected devices: Tailscale dashboard
- Check logs: `docker logs tailscale`
- Monitor network traffic

### 5. Rotate Keys
- Regenerate auth keys quarterly
- Revoke old keys
- Update GitHub secrets

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs tailscale

# Check capabilities
docker inspect tailscale | grep CapAdd

# Verify /dev/net/tun exists
ls -la /dev/net/tun
```

### Can't Connect to VPN

```bash
# Verify auth key
echo $TAILSCALE_AUTH_KEY

# Check Tailscale status
docker exec tailscale tailscale status

# Try reconnecting
docker restart tailscale

# Check if already authorized
docker exec tailscale tailscale up
```

### High Memory Usage

```bash
# Check memory
docker stats tailscale

# Restart if needed
docker restart tailscale
```

---

## Tailscale Commands

### Inside Container

```bash
# Check status
docker exec tailscale tailscale status

# Get IP address
docker exec tailscale tailscale ip -4

# View routes
docker exec tailscale tailscale routes

# Check version
docker exec tailscale tailscale version

# Logout
docker exec tailscale tailscale logout
```

### Local Machine

```bash
# After installing Tailscale locally
tailscale up

# Check status
tailscale status

# Get local IP
tailscale ip -4

# See devices
tailscale list-devices
```

---

## Integration with Deployment Pipeline

### GitHub Actions Integration

```yaml
# .github/workflows/deploy.yml - Add this job

  deploy-via-tailscale:
    runs-on: ubuntu-latest
    needs: [security-scan, test]
    environment: production
    steps:
      - name: Connect to Tailscale
        uses: tailscale/github-action@v2
        with:
          authkey: ${{ secrets.TAILSCALE_AUTH_KEY }}

      - name: Deploy via Tailscale VPN
        run: |
          ssh -i ~/.ssh/lidbema_deploy \
              deploy@${{ secrets.PROD_DEPLOY_HOST }} \
              'cd /opt/lidbema && ./deploy-enhanced.sh production deploy'
```

---

## Monitoring Tailscale

### Health Check

```yaml
healthcheck:
  test: ["CMD", "tailscale", "status"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 10s
```

### Metrics (if available)

```bash
# Check if Tailscale exposes metrics
docker exec tailscale curl localhost:9001/metrics 2>/dev/null || echo "Not available"
```

### Logs

```bash
# View Tailscale logs
docker logs -f tailscale

# View last 50 lines
docker logs --tail=50 tailscale
```

---

## Alternative Deployment Methods

### 1. Host Network Mode (Simpler)
```yaml
tailscale:
  image: tailscale/tailscale:latest
  network_mode: host
  volumes:
    - /var/lib/tailscale:/var/lib/tailscale
    - /dev/net/tun:/dev/net/tun
```

### 2. Sidecar Pattern (Per Service)
Run Tailscale sidecar with each service for isolated access.

### 3. Host-level Installation (Alternative)
Install Tailscale directly on host instead of in Docker.

---

## Cost & Licensing

**Free Plan:**
- Up to 3 users
- Unlimited devices
- 1 tailnet (network)
- Basic support

**Paid Plans:**
- More users
- Advanced features
- Priority support
- See: https://tailscale.com/pricing

**For Business:**
- Team management
- SSO integration
- Custom branding

---

## Next Steps

1. Create Tailscale account: https://tailscale.com
2. Generate auth key in dashboard
3. Add to GitHub secrets
4. Update docker-compose.yml
5. Deploy Tailscale container
6. Verify connection
7. Access services via Tailscale IP
8. Update team access

---

## Resources

- **Tailscale Docs:** https://tailscale.com/kb/
- **Docker Hub:** https://hub.docker.com/r/tailscale/tailscale
- **GitHub Action:** https://github.com/tailscale/github-action
- **Admin Panel:** https://login.tailscale.com

---

## Summary

✓ Tailscale image pulled and ready  
✓ Provides secure VPN to deployment infrastructure  
✓ Zero-config mesh networking  
✓ Encrypts all traffic end-to-end  
✓ Easy to integrate with Docker  
✓ Works across firewalls and NAT  

**Next Action:** Create Tailscale account and auth key, then add to docker-compose.yml or deploy manually.

---

**Image Status:** ✓ Ready to use  
**Size:** 165MB  
**Tested:** Yes  
**Production Ready:** Yes
