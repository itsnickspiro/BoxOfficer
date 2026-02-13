# BoxOfficer Backend — Multi-stage Docker build
# Stage 1: Firebase Functions (API proxy)
# Stage 2: Next.js Web Dashboard

# =============================================================================
# Stage 1: Build the Next.js Web Dashboard
# =============================================================================
FROM node:20-alpine AS web-builder

WORKDIR /app/web-dashboard
COPY web-dashboard/package.json web-dashboard/package-lock.json* ./
RUN npm ci --prefer-offline 2>/dev/null || npm install
COPY web-dashboard/ .
RUN npm run build

# =============================================================================
# Stage 2: Production image
# =============================================================================
FROM node:20-alpine AS production

WORKDIR /app

# Install Cloud Functions dependencies
COPY functions/package.json functions/package-lock.json* ./functions/
RUN cd functions && (npm ci --prefer-offline 2>/dev/null || npm install)
COPY functions/ ./functions/

# Copy built Next.js app
COPY --from=web-builder /app/web-dashboard/.next ./web-dashboard/.next
COPY --from=web-builder /app/web-dashboard/public ./web-dashboard/public
COPY --from=web-builder /app/web-dashboard/package.json ./web-dashboard/
COPY --from=web-builder /app/web-dashboard/node_modules ./web-dashboard/node_modules

# Copy Firebase config
COPY firebase.json .firebaserc firestore.rules firestore.indexes.json ./

# Environment variables (override at runtime)
ENV PORT=3000
ENV NODE_ENV=production

EXPOSE 3000

# Start the Next.js dashboard (Cloud Functions deploy separately via Firebase CLI)
WORKDIR /app/web-dashboard
CMD ["npx", "next", "start", "-p", "3000"]
