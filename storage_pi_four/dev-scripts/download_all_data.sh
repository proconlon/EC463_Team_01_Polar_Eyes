#!/bin/bash
# Wrapper for C++ Camera Control - Download Data
# NOT FULLY TESTED AND NOT USED FOR MVP

APP_PATH="/opt/polar-eyes/bin/camera_control"
LIB_PATH="/opt/polar-eyes/sdk/lib"
LOG_FILE="/var/log/polar_eyes.log"
RAID_PATH="/mnt/raid"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - CAM_CTRL: $1" | tee -a "$LOG_FILE"
}

export LD_LIBRARY_PATH=$LIB_PATH:$LD_LIBRARY_PATH

log "Request received: DOWNLOAD DATA"

# Verify RAID is actually there before telling C++ to write to it
if [ ! -d "$RAID_PATH" ]; then
    log "CRITICAL ERROR: RAID path $RAID_PATH does not exist or is not mounted!"
    exit 1
fi

if [ -f "$APP_PATH" ]; then
    log "Binary found. Executing download to $RAID_PATH..."
    "$APP_PATH" download_all "$RAID_PATH"
    
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        log "Success: Data downloaded."
    else
        log "ERROR: Binary returned exit code $EXIT_CODE"
        exit $EXIT_CODE
    fi
else
    log "WARNING: Binary not found at $APP_PATH. Simulating success for testing."
    log "Simulating file transfer to $RAID_PATH..."
    sleep 2
    exit 0
fi