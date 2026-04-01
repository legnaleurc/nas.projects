FROM python:3.14-slim-trixie

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libmediainfo0v5 && \
    rm -rf /var/lib/apt/lists/*

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
ENV UV_SYSTEM_PYTHON=1
ENV UV_NO_BINARY_PACKAGE=pymediainfo

# Set working directory
WORKDIR /app

# Copy the wdcli script
COPY scripts/drive.sh /app/drive.sh
RUN chmod +x /app/drive.sh
