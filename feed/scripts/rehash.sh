#!/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec uv run "$SCRIPT_DIR/rehash.py" \
  --feed-config=/mnt/feed.yaml \
  --synology-config=/mnt/synology.yaml \
  "$@"
