#!/bin/bash
APP_PATH="/opt/polar-eyes/bin/camera_control"
LOG_FILE="/var/log/polar_eyes.log"
DL_TIMEOUT="30s"
RAID_PATH="/mnt/raid2"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - CAM_CTRL: $1" | tee -a "$LOG_FILE"; }
log "Request received: TAKE PHOTO"

if [ ! -f "$APP_PATH" ]; then log "WARNING: Binary missing."; exit 0; fi

for i in {1..3}; do
    log "Attempt $i/3..."
    timeout "$DL_TIMEOUT" "$APP_PATH" photo "$RAID_PATH"
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ] || [ $EXIT_CODE -eq 124 ]; then
        log "Success (or Timeout treated as Success)."
        exit 0
    else
        FOUND_FILE=$(find "$RAID_PATH" -maxdepth 1 -name "*.insp" -mmin -1 2>/dev/null | head -n 1)
        if [ -n "$FOUND_FILE" ]; then log "File found despite error. Success."; exit 0; fi
        
        log "Attempt $i failed. Resetting USB..."
        if [ $i -lt 3 ]; then python3 /usr/local/bin/reset_camera.py; sleep 5; fi
    fi
done
log "CRITICAL: Failed after 3 attempts."; exit 1