#!/bin/sh
# Start containers that Docker tried to start at boot but failed to.
# Run as a DSM boot-up task. Pass -n or --dry-run to only list them.
#
# Docker restarts "always" / "unless-stopped" containers when the daemon starts, but if
# that start itself fails (a host IP not assigned yet, a network_mode: service:x
# container whose peer is not running yet, ...) it gives up for good. Such containers
# keep the error in State.Error; a successful start clears it, so containers stopped
# by hand are left alone.

set -eu

PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH

DRY_RUN=0
case "${1:-}" in
    -n|--dry-run) DRY_RUN=1 ;;
    "") ;;
    *) echo "usage: $0 [-n|--dry-run]" >&2; exit 2 ;;
esac

# Seconds to wait for the Docker daemon, then rounds of retries and the pause between them.
: "${DOCKER_WAIT:=600}"
: "${RETRY_ROUNDS:=10}"
: "${RETRY_INTERVAL:=30}"

# Print "<id> <name>" for each stopped auto-restart container whose last start failed.
failed_containers() {
    ids="$(docker ps -aq --filter status=exited --filter status=created)"
    [ -n "$ids" ] || return 0
    # State.Error goes last since it is free text.
    docker inspect -f '{{.Id}}|{{.Name}}|{{.HostConfig.RestartPolicy.Name}}|{{.State.Error}}' $ids |
        while IFS='|' read -r id name policy error; do
            case "$policy" in
                always|unless-stopped) ;;
                *) continue ;;
            esac
            [ -n "$error" ] || continue
            echo "$id ${name#/}"
            echo "${name#/}: $error" >&2
        done
}

waited=0
until docker info >/dev/null 2>&1; do
    if [ "$waited" -ge "$DOCKER_WAIT" ]; then
        echo "docker daemon not up after ${DOCKER_WAIT}s" >&2
        exit 1
    fi
    sleep 5
    waited=$((waited + 5))
done

round=1
while :; do
    failed="$(failed_containers)"
    if [ -z "$failed" ]; then
        echo "no containers left to start"
        exit 0
    fi
    if [ "$DRY_RUN" = 1 ]; then
        echo "dry run: would start:"
        echo "$failed" | cut -d' ' -f2
        exit 0
    fi
    if [ "$round" -gt "$RETRY_ROUNDS" ]; then
        echo "gave up after $RETRY_ROUNDS rounds:" >&2
        echo "$failed" | cut -d' ' -f2 >&2
        exit 1
    fi
    # Pause first so containers Docker is still bringing up get a chance on their own.
    sleep "$RETRY_INTERVAL"
    echo "round $round/$RETRY_ROUNDS"
    echo "$failed" | while read -r id name; do
        if docker start "$id" >/dev/null; then
            echo "started $name"
        else
            echo "failed to start $name" >&2
        fi
    done
    round=$((round + 1))
done
