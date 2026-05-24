# Same structure as websocket service
FROM node:23-alpine3.20 AS base

WORKDIR /usr/src/app
COPY ./src/auth-service/package*.json ./

# Development stage
FROM base AS development
RUN apk add --no-cache python3 make g++
RUN npm ci
COPY ./src/auth-service/ .
EXPOSE 8086

CMD ["npm", "run", "dev"]

# Production stage
FROM base AS production
RUN npm ci --omit=dev && npm cache clean --force
COPY ./src/auth-service/ .
EXPOSE 8086

CMD ["npm", "start"]