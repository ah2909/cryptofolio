# ── Stage 1: Base ─────────────────────────────────────────────────────────────
FROM python:3.12-slim AS base

WORKDIR /usr/src/app

# all deps ship manylinux wheels and ta is pure-python — no compilers needed
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

COPY ./src/portfolio-analyzer/requirements.txt .

# ── Stage 2: Development ──────────────────────────────────────────────────────
FROM base AS development

RUN pip install -r requirements.txt

COPY ./src/portfolio-analyzer/ .

EXPOSE 7070

# uvicorn --reload provides hot-reload (mirrors nodemon in other services)
CMD ["python", "server.py"]


# ── Stage 3: Production ───────────────────────────────────────────────────────
FROM base AS production

RUN pip install -r requirements.txt

COPY ./src/portfolio-analyzer/ .

EXPOSE 7070

CMD ["uvicorn src.app:app --host 0.0.0.0 --port 7070 --workers ${WORKERS:-1} --log-level info"]
