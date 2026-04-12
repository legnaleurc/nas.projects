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

# Function: syno_restart_service()
# Restarts a Synology service using synosystemctl (available on the NAS host).
syno_restart_service() {
    service=$1

    if [ "$DRY_RUN" = "true" ]; then
        log "info" "[DRY RUN] Would restart: $service"
        return 0
    fi

    log "info" "Attempting to restart: $service"
    if synosystemctl restart "$service" 2>/dev/null; then
        log "info" "  ✓ Restarted successfully"
        return 0
    else
        log "error" "  ✗ Restart failed"
        return 1
    fi
}

# Counter for statistics
total_services=0
restarted_services=0
skipped_services=0
failed_services=0

# Reload DSM nginx using synosystemctl
log "info" "Reloading nginx..."
total_services=$((total_services + 1))
if [ "$DRY_RUN" = "true" ]; then
    log "info" "[DRY RUN] Would reload: nginx"
    skipped_services=$((skipped_services + 1))
elif synosystemctl reload nginx 2>/dev/null; then
    log "info" "  ✓ nginx reloaded"
    restarted_services=$((restarted_services + 1))
else
    log "warn" "  ✗ nginx reload failed, trying restart..."
    if syno_restart_service nginx; then
        restarted_services=$((restarted_services + 1))
    else
        failed_services=$((failed_services + 1))
    fi
fi
echo ""

# Optional services that may use the certificate
OPTIONAL_SERVICES="smbdav ftpd sshd avahi-daemon"

log "info" "Checking optional services..."
for service in $OPTIONAL_SERVICES; do
    total_services=$((total_services + 1))
    if synosystemctl get-active-status "$service" 2>/dev/null | grep -q "active"; then
        if syno_restart_service "$service"; then
            restarted_services=$((restarted_services + 1))
        else
            failed_services=$((failed_services + 1))
        fi
    else
        log "debug" "Service not running or not installed: $service (skipping)"
        skipped_services=$((skipped_services + 1))
    fi
done
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
