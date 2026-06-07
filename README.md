# Portfolio Backend

Microservices-based cryptocurrency portfolio and trading platform.

## Services

| Service                | Stack                        | Port |
| ---------------------- | ---------------------------- | ---- |
| `backend`              | Laravel 11 / PHP 8.2         | 8000 |
| `auth-service`         | Node.js / Express            | 8086 |
| `websocket`            | Node.js / Socket.IO          | 3003 |
| `portfolio-analyzer`   | Python / FastAPI + LangGraph | 7070 |
| `crypto-alert-service` | Go / Gin                     | 4000 |

**Infrastructure:** MariaDB 11.4 (backend: 3306, auth: 3307), Redis 7 (6379)

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) + Docker Compose v2
- [Git](https://git-scm.com/)

---

## First-time Setup

### 1. Clone the repo with all submodules

```bash
git clone --recurse-submodules <root-repo-url>
cd portfolio_backend
```

If you already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

### 2. Configure root environment (Docker Compose variables)

```bash
cp .env.example .env
```

Edit `.env` and fill in the database credentials:

```env
# Backend DB
BACKEND_DATABASE=db
BACKEND_USERNAME=user
BACKEND_PASSWORD=secret
BACKEND_ROOT_PASSWORD=rootsecret

# Auth DB
AUTH_DATABASE=auth_service
AUTH_PASSWORD=authsecret
```

### 3. Configure each service

Each service has its own `.env`. Copy and fill in the examples:

```bash
cp src/backend/.env.example         src/backend/.env
cp src/auth-service/.env.example    src/auth-service/.env
cp src/portfolio-analyzer/.env.example src/portfolio-analyzer/.env
```

Key variables to fill in per service:

`src/backend/.env`

- `COINGECKO_API_KEY` — get from [coingecko.com](https://www.coingecko.com/en/api)
- `AUTH_SERVICE_URL` — set to `http://auth-service:8086`
- `FRONTEND_URL` — your frontend origin for CORS (e.g. `http://localhost:5173`)

`src/auth-service/.env`

- `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` — from [Google Cloud Console](https://console.cloud.google.com/)
- `FRONTEND_URL` — same as backend

`src/portfolio-analyzer/.env`

- `GEMINI_API_KEY` — from [Google AI Studio](https://aistudio.google.com/)

### 4. Generate RSA key pair for JWT (auth-service)

The auth service uses RS256 JWT tokens. If `id_rsa_priv.pem` and `id_rsa_pub.pem` are not present:

```bash
cd src/auth-service
openssl genrsa -out id_rsa_priv.pem 2048
openssl rsa -in id_rsa_priv.pem -pubout -out id_rsa_pub.pem
cd ../..
```

### 5. Start all services

```bash
docker compose up --build
```

Services are ready when you see each container reporting healthy/listening.

---

## Verify the setup

```bash
# Backend health
curl http://localhost:8000/api

# Auth service JWKS (used by backend for JWT validation)
curl http://localhost:8086/.well-known/jwks.json

# WebSocket service
curl http://localhost:3003

# Portfolio analyzer
curl http://localhost:7070/health
```

---

## Daily development

```bash
# Start all services (no rebuild)
docker compose up

# Start a specific service only
docker compose up backend

# Rebuild after Dockerfile changes
docker compose up --build <service>

# Stop everything
docker compose down
```

### Running tests

```bash
# Laravel (backend)
docker exec backend php artisan test

# Portfolio analyzer (Python)
docker exec portfolio-analyzer pytest -v
```

### Viewing logs

```bash
docker compose logs -f backend
docker compose logs -f auth-service
docker compose logs -f websocket
docker compose logs -f portfolio-analyzer
```

---

## Repository structure

```
portfolio_backend/
├── docker/                  # Dockerfiles per service
│   ├── backend/
│   ├── auth-service/
│   ├── websocket/
│   └── portfolio-analyzer/
├── src/                     # Service source code (git submodules)
│   ├── backend/             # Laravel API
│   ├── auth-service/        # JWT + Google OAuth
│   ├── websocket/           # Binance real-time feed
│   └── portfolio-analyzer/  # AI portfolio analysis
├── data/                    # DB & cache volumes — gitignored, created by Docker
├── docker-compose.yml
├── .env.example             # Root env template (DB credentials for Compose)
└── README.md
```

---

## Updating submodules

When a teammate pushes changes to a service repo:

```bash
git submodule update --remote --merge
```

To update a single service:

```bash
git submodule update --remote --merge src/backend
```
