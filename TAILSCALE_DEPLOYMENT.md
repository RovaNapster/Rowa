# Tailscale Deployment Configuration

Tailscale auth key has been provided and is ready for GitHub Actions integration.

---

## Auth Key Information

**Status:** ✓ Received  
**Type:** Reusable client auth key  
**Format:** tskey-client-*  
**Use:** GitHub Actions CI/CD pipeline  

---

## GitHub Secrets Setup

### Required Secret

Add this to your GitHub repository:

**Settings → Secrets and variables → Actions**

Create new secret:
```
Name: TAILSCALE_AUTH_KEY
Value: tskey-client-ktMzc8Yx9411CNTRL-MEaT7AkPMPYCir6QvmzcPYNC4eQxEBQw
```

---

## Docker Compose Integration

Add Tailscale to your docker-compose.yml:

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

---

## Deployment Steps

### Step 1: Add to GitHub Secrets

Go to your GitHub repository:
1. Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `TAILSCALE_AUTH_KEY`
4. Value: The key provided above
5. Click "Add secret"

### Step 2: Add Environment Variable to Servers

**On Staging Server:**
```bash
# Add to /opt/lidbema/.env.staging
echo 'TAILSCALE_AUTH_KEY=tskey-client-ktMzc8Yx9411CNTRL-MEaT7AkPMPYCir6QvmzcPYNC4eQxEBQw' >> /opt/lidbema/.env.staging
```

**On Production Server:**
```bash
# Add to /opt/lidbema/.env.production
echo 'TAILSCALE_AUTH_KEY=tskey-client-ktMzc8Yx9411CNTRL-MEaT7AkPMPYCir6QvmzcPYNC4eQxEBQw' >> /opt/lidbema/.env.production
```

### Step 3: Deploy Tailscale Container

**Option A: Manual Deployment**
```bash
docker run -d \
  --name tailscale \
  --cap-add NET_ADMIN \
  -v /var/lib/tailscale:/var/lib/tailscale \
  -v /dev/net/tun:/dev/net/tun \
  -e TS_AUTHKEY='tskey-client-ktMzc8Yx9411CNTRL-MEaT7AkPMPYCir6QvmzcPYNC4eQxEBQw' \
  -e TS_STATE_DIR=/var/lib/tailscale \
  --restart unless-stopped \
  tailscale/tailscale:latest
```

**Option B: Docker Compose**
```bash
# Update docker-compose.yml with tailscale service (see above)
docker compose up -d tailscale
```

### Step 4: Verify Connection

```bash
# Check if running
docker ps | grep tailscale

# Get Tailscale IP
docker exec tailscale tailscale ip -4

# Check status
docker exec tailscale tailscale status

# View logs
docker logs tailscale
```

---

## Expected Output

After successful deployment:

```bash
$ docker exec tailscale tailscale status
100.x.y.z          lidbema-prod             linux   -
100.x.y.a          your-local-machine       darwin  -
100.x.y.b          staging-server           linux   -
```

---

## GitHub Actions Integration

Update `.github/workflows/deploy.yml` to use Tailscale:

```yaml
  deploy-production:
    runs-on: ubuntu-latest
    needs: [test, security-scan]
    if: github.ref == 'refs/heads/main'
    environment:
      name: production
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

## Accessing Services via Tailscale

### From Your Local Machine

1. **Install Tailscale locally:**
   ```bash
   # macOS
   brew install tailscale
   
   # Linux
   curl -fsSL https://tailscale.com/install.sh | sh
   
   # Windows
   Download from https://tailscale.com/download
   ```

2. **Authenticate:**
   ```bash
   tailscale up
   # Opens browser to authenticate
   ```

3. **Get your Tailscale IP:**
   ```bash
   tailscale ip -4
   ```

4. **Access services:**
   ```bash
   # SSH to servers via VPN
   ssh -i ~/.ssh/lidbema_deploy deploy@100.x.y.z
   
   # Access Grafana
   http://100.x.y.z:3100
   
   # Access Prometheus
   http://100.x.y.z:9090
   
   # Access Lidbema PWA
   http://100.x.y.z:3000
   ```

---

## Tailscale Network Topology

Your mesh network will look like:

```
Your Local Machine (100.x.x.1)
├─ Tailscale Client
├─ Can SSH to servers
└─ Can access all services

Staging Server (100.x.x.2)
├─ Tailscale Container
├─ All services on local network
└─ Accessible via VPN

Production Server (100.x.x.3)
├─ Tailscale Container
├─ All services on local network
└─ Accessible via VPN

Monitoring (100.x.x.4-12)
├─ Prometheus (port 9090)
├─ Grafana (port 3100)
└─ All services via VPN IPs
```

---

## Security Features

✓ **End-to-End Encryption:** All traffic encrypted  
✓ **No Central Server:** Direct peer-to-peer connections  
✓ **Automatic NAT Traversal:** Works through firewalls  
✓ **Access Control:** Tailscale ACL rules  
✓ **Key Rotation:** Auth keys can be revoked  
✓ **Audit Logs:** Track all connections  

---

## Monitoring Tailscale

### Check Container Status
```bash
docker ps | grep tailscale
docker logs tailscale
docker stats tailscale
```

### Verify Network
```bash
docker exec tailscale tailscale status
docker exec tailscale tailscale routes
docker exec tailscale tailscale ping 100.x.x.2
```

### Health Check
```bash
docker exec tailscale tailscale status | grep "Health"
```

---

## Troubleshooting

### Container Won't Start
```bash
# Check capabilities
docker inspect tailscale | grep CapAdd

# Check /dev/net/tun
ls -la /dev/net/tun

# View logs
docker logs tailscale
```

### Can't Connect
```bash
# Verify auth key
echo $TAILSCALE_AUTH_KEY

# Check if already authorized
docker exec tailscale tailscale status

# Force reconnect
docker restart tailscale
```

### Slow Connection
```bash
# Check routes
docker exec tailscale tailscale routes

# Check ping
docker exec tailscale tailscale ping 100.x.x.2
```

---

## Next Steps

1. ✅ Auth key received
2. ⏭️ Add `TAILSCALE_AUTH_KEY` to GitHub Secrets
3. ⏭️ Update docker-compose.yml with tailscale service
4. ⏭️ Deploy on staging: `docker compose up -d tailscale`
5. ⏭️ Get Tailscale IP: `docker exec tailscale tailscale ip -4`
6. ⏭️ Verify connection from local machine
7. ⏭️ Update GitHub Actions workflow
8. ⏭️ Deploy on production

---

## Quick Commands

```bash
# Deploy Tailscale (once auth key is in .env)
docker compose up -d tailscale

# Get Tailscale IP
docker exec tailscale tailscale ip -4

# Check status
docker exec tailscale tailscale status

# SSH to server via VPN
ssh -i ~/.ssh/lidbema_deploy deploy@100.x.y.z

# Access Grafana via VPN
http://100.x.y.z:3100
```

---

## Files to Update

1. **docker-compose.yml** - Add tailscale service
2. **.env.staging** - Add TAILSCALE_AUTH_KEY
3. **.env.production** - Add TAILSCALE_AUTH_KEY
4. **.github/workflows/deploy.yml** - Add Tailscale integration
5. **GitHub Secrets** - Add TAILSCALE_AUTH_KEY

---

## Status

✓ Auth key provided  
✓ Tailscale image pulled (165MB)  
✓ Configuration documented  
✓ Deployment guide created  
✓ Ready to deploy  

**Next Action:** Add secret to GitHub, then deploy Tailscale container on staging/production servers.

---

**Document:** TAILSCALE_DEPLOYMENT.md  
**Created:** 2026-03-16  
**Status:** Ready for implementation
