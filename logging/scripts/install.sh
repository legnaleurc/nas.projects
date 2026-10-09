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
    # syslog-ng drops privileges to $SYSLOG_USER, so it must own the folder it writes to.
    # The setgid bit makes new files inherit $LOG_GROUP, which the rule makes group read-write.
    chown "$SYSLOG_USER:$LOG_GROUP" "$LOG_DIR"
    chmod 2770 "$LOG_DIR"
    # Bring files created before LOG_GROUP was set (or changed) in line.
    find "$LOG_DIR" -maxdepth 1 -type f -exec chgrp "$LOG_GROUP" {} + -exec chmod 0660 {} +
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

# syslog-ng runs unprivileged and silently skips include files it cannot read,
# so the rule must be world-readable. cp would inherit the source folder's mode.
install_rule() {
    rm -f "$SYSLOG_DST"
    cp "$1" "$SYSLOG_DST"
    chown root:root "$SYSLOG_DST"
    chmod 0644 "$SYSLOG_DST"
}

if cmp -s "$GENERATED_DIR/docker-logs.conf" "$SYSLOG_DST" \
    && [ "$(stat -c %a "$SYSLOG_DST")" = 644 ]; then
    echo "syslog-ng rule unchanged"
    exit 0
fi

# Swap in the new rule, and roll back if the full config no longer parses.
if [ -f "$SYSLOG_DST" ]; then
    rm -f "$GENERATED_DIR/docker-logs.conf.previous"
    cp "$SYSLOG_DST" "$GENERATED_DIR/docker-logs.conf.previous"
fi
install_rule "$GENERATED_DIR/docker-logs.conf"

if ! syslog-ng --syntax-only; then
    if [ -f "$GENERATED_DIR/docker-logs.conf.previous" ]; then
        install_rule "$GENERATED_DIR/docker-logs.conf.previous"
    else
        rm -f "$SYSLOG_DST"
    fi
    echo "syslog-ng syntax check failed; previous rule restored" >&2
    exit 1
fi

systemctl reload "$SYSLOG_UNIT"

# The reload is asynchronous and reports success even when an include is skipped,
# so confirm the running config actually contains the rule.
for _ in 1 2 3 4 5 6 7 8 9 10; do
    if syslog-ng-ctl config --preprocessed | grep -q d_docker_logs; then
        echo "syslog-ng rule installed and $SYSLOG_UNIT reloaded"
        exit 0
    fi
    sleep 1
done
echo "syslog-ng reloaded but the rule is not active; check /var/log/syslog.log" >&2
exit 1
