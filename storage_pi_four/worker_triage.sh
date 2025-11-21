#!/bin/bash
#
# Polar Eyes Worker Triage Script
# - Relies on systemd/fstab to mount the RAID before this runs.
# - Handles: Mission Triage (Mode 2), Shutdown.
#

set -e

SYS_LOG="/var/log/polar_eyes.log"
RAID_MOUNT_POINT="/mnt/raid"
RAID_LOG_FILE="${RAID_MOUNT_POINT}/polar_eyes_persistent.log"
CONFIG_FILE="/opt/polar-eyes/storage_pi_four/polareyes.conf"
RAID_DEVICE="/dev/md0"

log() {
    LOG_MSG="$(date '+%Y-%m-%d %H:%M:%S') - TRIAGE: $1"
    # Always log to the local SD card
    echo "$LOG_MSG" | sudo tee -a "$SYS_LOG"
    # Also log to the RAID if it's mounted
    if mountpoint -q "$RAID_MOUNT_POINT"; then
        echo "$LOG_MSG" | sudo tee -a "$RAID_LOG_FILE"
    fi
}

# --- Root Check ---
if [ "$EUID" -ne 0 ]; then
  echo "::ERROR:: This script must be run as root (use 'sudo'). Aborting."
  exit 1
fi

# ---------------------------------------------------------
# NORMAL BOOT (TRIAGE)
# ---------------------------------------------------------
log "--- System Booted ---"

# 1. Verify RAID Mount
if ! findmnt -q "$RAID_MOUNT_POINT"; then
    log "FATAL: RAID array not mounted! Check fstab/drives."
else
    log "RAID array verified mounted."
fi

# 2. Read Trigger Pin (Python)
log "Reading Mission Trigger Pin..."

if [ ! -f "/usr/local/bin/read_gpio.py" ]; then
    log "FATAL: Python helper script missing."
    exit 1
fi

PIN_VALUE=$(python3 /usr/local/bin/read_gpio.py)
RET_CODE=$?

if [ $RET_CODE -ne 0 ]; then
    log "FATAL: Python script failed to read GPIO. Exit code $RET_CODE."
    exit 1
fi

log "GPIO Read complete. Pin value: $PIN_VALUE"

# 3. Run Mission Sequence
if [ "$PIN_VALUE" -eq 0 ]; then
    # --- TIMELAPSE MISSION ---
    log "Trigger Pin is LOW. Running Timelapse Sequence."
    
    log "Step 1: Taking Photo..."
    /usr/local/bin/take_photo
    
    log "Step 2: Downloading & Deleting..."
    /usr/local/bin/download_all_data
    
    log "Timelapse Sequence completed."

else
    # --- EVENT MISSION ---
    log "Trigger Pin is HIGH. Running Event Sequence."
    
    log "Step 1: Starting Recording..."
    /usr/local/bin/start_video
    
    log "Step 2: Waiting 3 minutes for event capture..."
    # Note: For the 3-minute DEMO, you might want to lower this sleep to 10s
    sleep 10 
    
    log "Step 3: Stopping Recording..."
    /usr/local/bin/stop_video
    
    log "Step 4: Downloading & Deleting..."
    /usr/local/bin/download_all_data
    
    log "Event Sequence completed."
fi

# 4. Shutdown
log "Mission complete. Shutting down system."
sync
# sudo poweroff # not implemented for demo
exit 0