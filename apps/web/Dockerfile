# Multi-stage build for Next.js (apps/web)
FROM node:20-alpine AS base

# Dependencies stage
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Copy only web app package files for better caching
COPY apps/web/package.json apps/web/package-lock.json* ./
RUN npm ci --only=production || npm ci

# Builder stage
FROM base AS builder
WORKDIR /app

# Copy node_modules from deps and the full repo
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build the Next.js application (standalone)
ENV NEXT_TELEMETRY_DISABLED 1
WORKDIR /app/apps/web
RUN npm run build

# Runner stage
FROM base AS runner
WORKDIR /app
ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

# Create non-root user
RUN addgroup -S nodejs -g 1001 \
 && adduser -S nextjs -u 1001 -G nodejs

# Copy public and standalone output
COPY --from=builder /app/apps/web/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/static ./.next/static

USER nextjs
EXPOSE 3000
ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

CMD ["node", "server.js"]
