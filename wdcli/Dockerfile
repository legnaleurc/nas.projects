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

# Create mount points and writable cache for arbitrary runtime UID/GID
RUN mkdir -p /mnt/config /mnt/data /mnt/storage

# Copy scripts
COPY scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/wdcli /usr/local/bin/itsame

# Set working directory
WORKDIR /app
