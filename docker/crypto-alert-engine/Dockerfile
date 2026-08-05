# --- Stage 1: Base image for dependencies ---
FROM golang:1.27rc2-alpine3.24 AS base

WORKDIR /app

# Install git (often needed for go mod download)
RUN apk add --no-cache git

COPY /src/crypto-alert-engine/go.mod /src/crypto-alert-engine/go.sum ./
RUN go mod download


# --- Stage 2: Development (Hot Reloading) ---
FROM base AS development

# Install Air for hot reloading (latest official repository: air-verse/air)
RUN go install github.com/air-verse/air@v1.67.4

COPY . .

EXPOSE 4000

# Start Air live-reloading tool
CMD ["air"]


# --- Stage 3: Build static Go binary ---
FROM base AS builder

COPY . .

# Build statically linked binary optimized for production
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o crypto-alert-engine .


# --- Stage 4: Production image ---
FROM alpine:3.24 AS production

WORKDIR /app

COPY --from=builder /app/crypto-alert-engine .

RUN adduser -D -u 10001 appuser
USER appuser

EXPOSE 4000

ENTRYPOINT ["./crypto-alert-engine"]
