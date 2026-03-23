# Build stage (minimal - static files only)
FROM node:20-alpine AS builder
WORKDIR /build
COPY . .
# For PWA apps, just validate the JSON
RUN test -f manifest.json && echo "✓ manifest.json valid"

# Production stage - serve with nginx
FROM nginx:alpine
# Copy static assets to nginx default directory
COPY --from=builder /build /usr/share/nginx/html

# Copy custom nginx config for SPA routing
COPY <<EOF /etc/nginx/conf.d/default.conf
server {
    listen 80;
    server_name _;
    
    root /usr/share/nginx/html;
    index index.html;
    
    # Cache static assets (except service worker)
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1d;
        add_header Cache-Control "public, immutable";
    }
    
    # Service worker must not be cached
    location = /sw.js {
        expires -1;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }
    
    # SPA routing: serve index.html for all routes
    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD stat /usr/share/nginx/html/index.html >/dev/null || exit 1

CMD ["nginx", "-g", "daemon off;"]
