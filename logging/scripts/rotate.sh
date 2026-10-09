#!/bin/sh
# Rotate the log files. Run daily from DSM Task Scheduler; pass -d for a dry run.

set -eu

. "$(cd "$(dirname "$0")" && pwd)/env.sh"

if [ ! -f "$GENERATED_DIR/logrotate.conf" ]; then
    echo "missing $GENERATED_DIR/logrotate.conf (run scripts/install.sh first)" >&2
    exit 1
fi

exec logrotate "$@" -s "$GENERATED_DIR/logrotate.status" "$GENERATED_DIR/logrotate.conf"
