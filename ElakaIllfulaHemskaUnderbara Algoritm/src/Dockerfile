# Stage 1: Build the React Application
FROM node:20-alpine AS builder
WORKDIR /app

# Install dependencies first (better layer caching)
COPY package*.json ./
RUN npm ci

# Copy source and build
COPY . .
# Note: In CI/CD, you would inject the .env variables here before building
RUN npm run build

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Remove default nginx static assets
RUN rm -rf /usr/share/nginx/html/*

# Copy static assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Add a custom nginx configuration for React Router / SPA fallback
# Create a file named nginx.conf in your project root with the block below, 
# or just rely on the default if you don't use React Router.
# COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

# Healthcheck for Nginx
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]