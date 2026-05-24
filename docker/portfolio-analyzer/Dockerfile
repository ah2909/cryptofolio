# ── Stage 1: Base ─────────────────────────────────────────────────────────────
FROM python:3.12-slim AS base

WORKDIR /usr/src/app

# gcc/g++ needed for pandas and ta C extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

COPY ./src/portfolio-analyzer/requirements.txt .

# ── Stage 2: Development ──────────────────────────────────────────────────────
FROM base AS development

RUN pip install --no-cache-dir -r requirements.txt

COPY ./src/portfolio-analyzer/ .

EXPOSE 7070

# uvicorn --reload provides hot-reload (mirrors nodemon in other services)
CMD ["python", "server.py"]


# ── Stage 3: Production ───────────────────────────────────────────────────────
FROM base AS production

RUN pip install --no-cache-dir -r requirements.txt \
    && pip cache purge

COPY ./src/portfolio-analyzer/ .

RUN find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true

EXPOSE 7070

CMD ["uvicorn", "src.app:app", "--host", "0.0.0.0", "--port", "7070", \
     "--workers", "2", "--log-level", "info"]
