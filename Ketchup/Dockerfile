FROM node:18-alpine AS builder
WORKDIR /app
RUN npm init -y && npm install http-server

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/node_modules /app/node_modules
COPY Index.html manifest.json sw.js /app/

EXPOSE 3050

HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=10s \
  CMD wget --quiet --tries=1 --spider http://localhost:3050/Index.html || exit 1

CMD ["npx", "http-server", "-p", "3050", "-c-1", "--cors"]
