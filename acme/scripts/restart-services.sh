#!/bin/sh
# Service detection and restart script
# Called by deploy-to-synology.sh after certificate deployment

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/utils.sh"

log "info" "Starting service restart process..."
echo ""

# Dry run mode
DRY_RUN=false
if [ "$1" = "--dry-run" ]; then
    DRY_RUN=true
    log "info" "DRY RUN MODE - No services will be restarted"
    echo ""
fi

# Counter for statistics
total_services=0
restarted_services=0
skipped_services=0
failed_services=0

# Reload nginx by sending SIGHUP to its master process.
# Requires pid:host in compose.yaml so the container can see and signal host processes.
log "info" "Reloading nginx..."
total_services=$((total_services + 1))
if [ "$DRY_RUN" = "true" ]; then
    log "info" "[DRY RUN] Would send SIGHUP to nginx"
    skipped_services=$((skipped_services + 1))
else
    NGINX_PID=$(cat /run/nginx.pid 2>/dev/null || cat /var/run/nginx.pid 2>/dev/null || echo "")
    if [ -n "$NGINX_PID" ]; then
        if kill -HUP "$NGINX_PID" 2>/dev/null; then
            log "info" "  ✓ nginx reloaded (pid $NGINX_PID)"
            restarted_services=$((restarted_services + 1))
        else
            log "error" "  ✗ Failed to send SIGHUP to nginx (pid $NGINX_PID)"
            failed_services=$((failed_services + 1))
        fi
    else
        log "error" "  ✗ nginx PID file not found at /run/nginx.pid or /var/run/nginx.pid"
        log "error" "  Check that pid:host is set in compose.yaml"
        failed_services=$((failed_services + 1))
    fi
fi
echo ""

# Summary
log "info" "========================================="
log "info" "Service Restart Summary"
log "info" "========================================="
log "info" "Total services checked: $total_services"
log "info" "Successfully restarted: $restarted_services"
log "info" "Skipped (not running): $skipped_services"
log "info" "Failed to restart: $failed_services"
echo ""

if [ $failed_services -gt 0 ]; then
    log "warn" "Some services failed to restart"
    log "warn" "Please check logs and restart manually if needed"
    exit 1
fi

if [ $restarted_services -eq 0 ]; then
    log "warn" "No services were restarted"
    log "warn" "This may indicate a configuration issue"
fi

log "info" "Service restart process completed"
exit 0
