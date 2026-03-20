FROM python:3.14-slim-trixie

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libmediainfo0v5 && \
    rm -rf /var/lib/apt/lists/*

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
ENV UV_SYSTEM_PYTHON=1
ENV UV_NO_BINARY_PACKAGE=pymediainfo

# Create mount points
RUN mkdir -p /mnt/config /mnt/data /mnt/storage

# Copy the wdcli script
COPY scripts/wdcli /usr/local/bin/wdcli
RUN chmod +x /usr/local/bin/wdcli

# Set working directory
WORKDIR /app
