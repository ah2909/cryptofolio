# ========================================
# STAGE 1: Base - Common dependencies for both dev and prod 
# ========================================
FROM node:23-alpine3.20 AS base

WORKDIR /usr/src/app
COPY ./src/websocket/package*.json ./

# ========================================
# STAGE 2: Development - With nodemon and dev tools
# ========================================
FROM base AS development

# Install ALL dependencies (including devDependencies)
RUN npm ci

# Copy source code
COPY ./src/websocket/ .
EXPOSE 3003

CMD ["npm", "run", "dev"]

# ========================================
# STAGE 3: Production - Optimized and secure
# ========================================
FROM base AS production

# Install only production dependencies (smaller image)
RUN npm ci --omit=dev && \
    npm cache clean --force

COPY ./src/websocket/ .

EXPOSE 3003

# Use node directly in production (faster startup)
CMD ["npm", "start"]