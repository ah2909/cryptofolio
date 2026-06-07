# Architecture

Microservices-based cryptocurrency portfolio, analytics, and alerting platform.

## Services

| Service | Stack | Port | Responsibility |
| --- | --- | --- | --- |
| **backend** | Laravel 11 (PHP 8.2) | 8000 | Main REST API: portfolios, assets, exchanges, transactions. Proxies AI analysis. |
| **auth-service** | Node / Express | 8086 | RS256 JWT issuance, JWKS endpoint, Google OAuth. |
| **websocket** | Node / Socket.IO | 3003 | Binance WS → live price streaming to FE; app-event relay; CEX REST proxy (ccxt). |
| **portfolio-analyzer** | Python / FastAPI + LangGraph | 7070 | AI portfolio analysis (risk, alerts, insights via Gemini). |
| **crypto-alert-service** | Go | 4000 | Own Binance WS feed to evaluate price alerts → Telegram; publishes client events to Redis. |

Infrastructure: MariaDB (backend `:3306`, auth `:3307`), Redis `:6379`(cache + Pub/Sub).

## System diagram

```mermaid
graph TB
    subgraph Client
        FE["Frontend<br/>(NextJS)"]
    end

    subgraph Application Services
        BE["backend<br/>Laravel 11 · :8000<br/>REST API"]
        AUTH["auth-service<br/>Node/Express · :8086<br/>JWT + Google OAuth"]
        WS["websocket<br/>Node/Socket.IO · :3003<br/>Price streaming + app events + CEX REST"]
        PA["portfolio-analyzer<br/>Python/FastAPI · :7070<br/>LangGraph AI analysis"]
        ALERT["crypto-alert-service<br/>Go · :4000<br/>Price alerts"]
    end

    subgraph Data Stores
        MDB[("MariaDB<br/>backend · :3306")]
        ADB[("MariaDB<br/>auth · :3307")]
        REDIS[("Redis · :6379<br/>cache + Pub/Sub")]
    end

    subgraph External
        BINANCE(["Binance WS"])
        CEX(["Binance / OKX / Bybit REST"])
        CG(["CoinGecko"])
        GOOG(["Google OAuth"])
        GEM(["Gemini"])
        TG(["Telegram"])
    end

    %% Frontend connections
    FE -->|"REST /api (JWT)"| BE
    FE -->|"login / OAuth"| AUTH
    FE -->|"Socket.IO (prices + app events)"| WS
    FE -->|"REST: manage alerts (JWT)"| ALERT

    %% Backend
    BE -->|"JWKS validate"| AUTH
    BE -->|"proxy /analyze"| PA
    BE -->|"asset prices"| CG
    BE --> MDB
    BE -->|"PUBLISH ws:events"| REDIS

    %% Auth
    AUTH --> ADB
    AUTH --> GOOG

    %% Analyzer
    PA --> CG
    PA --> GEM

    %% Websocket
    WS -->|"price stream"| BINANCE
    WS -->|"CEX REST (ccxt)"| CEX
    REDIS -->|"SUBSCRIBE ws:events"| WS

    %% Alert service
    ALERT -->|"price stream (alert eval)"| BINANCE
    ALERT --> MDB
    ALERT -->|"PUBLISH ws:events · alert dedup"| REDIS
    ALERT -->|"alert notify"| TG
```

## Realtime flow 1 — live price streaming

The `websocket` service owns the FE price feed. It opens one shared Binance connection and fans ticks out to subscribed clients per-user, throttled.

```mermaid
sequenceDiagram
    participant FE as Frontend
    participant WS as websocket
    participant BN as Binance WS

    FE->>WS: connect (JWT) + subscribe [btcusdt@ticker, ...]
    WS->>BN: SUBSCRIBE btcusdt@ticker (ref-counted)
    BN-->>WS: ticker tick (~1/s)
    WS-->>FE: ticker event (throttled, per-user room)
    FE->>WS: unsubscribe / disconnect
    WS->>BN: UNSUBSCRIBE (when ref count hits 0)
```

## Realtime flow 2 — alert fired (Redis Pub/Sub)

The alert-service evaluates alerts against its own Binance feed. When one fires it delivers to Telegram **and** publishes a `ws:events` message; the `websocket` service (the sole subscriber) emits it to the owning user's Socket.IO room. The backend uses the same channel for its own business events.

```mermaid
sequenceDiagram
    participant BN as Binance WS
    participant AL as crypto-alert-service
    participant TG as Telegram
    participant R as Redis
    participant WS as websocket
    participant FE as Frontend

    BN-->>AL: price tick (BTCUSDT)
    Note over AL: Evaluate(alert, price) == true
    AL->>TG: SendAlert (Telegram)
    AL->>R: PUBLISH ws:events {event, userId, data}
    R-->>WS: message on ws:events
    WS-->>FE: io.to(userId).emit(event, data)
```