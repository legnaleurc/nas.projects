#!/bin/sh
# Generate syslog-ng and logrotate config from .env and install the syslog-ng rule.
# Safe to run by hand or as a DSM boot-up task; does nothing if the result is unchanged.
# Pass -n or --dry-run to only show what would change.

set -eu

DRY_RUN=0
case "${1:-}" in
    -n|--dry-run) DRY_RUN=1 ;;
    "") ;;
    *) echo "usage: $0 [-n|--dry-run]" >&2; exit 2 ;;
esac

. "$(cd "$(dirname "$0")" && pwd)/env.sh"

SYSLOG_DST=/usr/local/etc/syslog-ng/patterndb.d/docker-logs.conf

# "acme dfd dns" -> "acme|dfd|dns"
LOG_PROJECTS_REGEX="$(echo $LOG_PROJECTS | tr ' ' '|')"

OUT_DIR="$GENERATED_DIR"
if [ "$DRY_RUN" = 1 ]; then
    OUT_DIR="$(mktemp -d)"
    trap 'rm -rf "$OUT_DIR"' EXIT
else
    mkdir -p "$GENERATED_DIR" "$LOG_DIR"
fi

render() {
    sed -e "s#@LOG_DIR@#$LOG_DIR#g" \
        -e "s#@LOG_PROJECTS_REGEX@#$LOG_PROJECTS_REGEX#g" \
        -e "s#@LOG_ROTATE_PERIOD@#$LOG_ROTATE_PERIOD#g" \
        -e "s#@LOG_ROTATE_KEEP@#$LOG_ROTATE_KEEP#g" \
        "$PROJECT_DIR/templates/$1.in" > "$OUT_DIR/$1"
}

render docker-logs.conf
render logrotate.conf

if [ "$DRY_RUN" = 1 ]; then
    show_diff() {
        echo "== $2"
        if [ -f "$2" ]; then
            diff -u "$2" "$1" && echo "(unchanged)" || true
        else
            echo "(would be created)"
            cat "$1"
        fi
    }
    show_diff "$OUT_DIR/docker-logs.conf" "$SYSLOG_DST"
    show_diff "$OUT_DIR/logrotate.conf" "$GENERATED_DIR/logrotate.conf"
    echo "dry run: nothing installed; the syslog-ng syntax check only runs on a real install"
    exit 0
fi

if cmp -s "$GENERATED_DIR/docker-logs.conf" "$SYSLOG_DST"; then
    echo "syslog-ng rule unchanged"
    exit 0
fi

# Swap in the new rule, and roll back if the full config no longer parses.
if [ -f "$SYSLOG_DST" ]; then
    cp "$SYSLOG_DST" "$GENERATED_DIR/docker-logs.conf.previous"
fi
cp "$GENERATED_DIR/docker-logs.conf" "$SYSLOG_DST"

if ! syslog-ng --syntax-only; then
    if [ -f "$GENERATED_DIR/docker-logs.conf.previous" ]; then
        cp "$GENERATED_DIR/docker-logs.conf.previous" "$SYSLOG_DST"
    else
        rm -f "$SYSLOG_DST"
    fi
    echo "syslog-ng syntax check failed; previous rule restored" >&2
    exit 1
fi

systemctl reload "$SYSLOG_UNIT"
echo "syslog-ng rule installed and $SYSLOG_UNIT reloaded"
