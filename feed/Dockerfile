FROM python:3.12-slim AS builder

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
ENV UV_SYSTEM_PYTHON=1
ENV UV_NO_BINARY_PACKAGE=pymediainfo

RUN apt-get update && apt-get install -y --no-install-recommends \
    libmagic1 \
    libmediainfo0v5 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app
RUN uv sync --no-dev
