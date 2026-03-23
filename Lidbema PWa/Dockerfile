FROM node:18-alpine AS base
WORKDIR /app
ENV NODE_ENV=production

FROM base AS dependencies
COPY package*.json ./
RUN npm install --omit=dev

FROM base AS builder
COPY package*.json ./
RUN npm install

FROM base
COPY --from=dependencies /app/node_modules ./node_modules
COPY . .

RUN mkdir -p /app/logs /app/data

EXPOSE 3000 4000 9001 9101

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD node -e "require('http').get('http://localhost:' + (process.env.PORT || 3000) + '/health', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})" || exit 1

CMD ["node", "app.js"]
