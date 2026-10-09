#!/bin/sh
# Shared setup: load .env and validate it. Sourced by the other scripts.

PATH=/usr/sbin:/usr/bin:/sbin:/bin:$PATH

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GENERATED_DIR="$PROJECT_DIR/generated"

if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo "missing $PROJECT_DIR/.env (copy .env.example)" >&2
    exit 1
fi
. "$PROJECT_DIR/.env"

: "${LOG_PROJECTS:?Set LOG_PROJECTS in .env}"
: "${LOG_DIR:?Set LOG_DIR in .env}"
: "${LOG_ROTATE_PERIOD:=daily}"
: "${LOG_ROTATE_KEEP:=14}"
: "${SYSLOG_UNIT:=syslog-ng}"

case "$LOG_ROTATE_PERIOD" in
    daily|weekly|monthly|yearly) ;;
    *) echo "LOG_ROTATE_PERIOD must be daily, weekly, monthly or yearly" >&2; exit 1 ;;
esac
