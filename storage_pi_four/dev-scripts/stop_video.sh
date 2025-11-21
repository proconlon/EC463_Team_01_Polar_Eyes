#!/bin/bash
APP_PATH="/opt/polar-eyes/bin/camera_control"
LOG_FILE="/var/log/polar_eyes.log"
DL_TIMEOUT="30s"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - CAM_CTRL: $1" | tee -a "$LOG_FILE"; }
log "Request received: STOP VIDEO"

if [ ! -f "$APP_PATH" ]; then log "WARNING: Binary missing."; exit 0; fi

for i in {1..3}; do
    log "Attempt $i/3..."
    timeout "$DL_TIMEOUT" "$APP_PATH" record-stop /mnt/raid2
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ] || [ $EXIT_CODE -eq 124 ]; then log "Success."; exit 0; fi
    log "Failed. Resetting USB..."
    if [ $i -lt 3 ]; then python3 /usr/local/bin/reset_camera.py; sleep 5; fi
done
exit 1