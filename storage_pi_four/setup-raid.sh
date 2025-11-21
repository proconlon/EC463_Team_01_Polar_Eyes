#!/bin/bash
# SAFE RAID PROVISIONING SCRIPT (FIXED)
# Usage: 
#   sudo ./setup-raid.sh          (Safe: Adopts existing RAID)
#   sudo ./setup-raid.sh --wipe   (Destructive: Creates new RAID)

set -e
if [ "$EUID" -ne 0 ]; then echo "Run as root."; exit 1; fi

CONFIG_FILE="/boot/firmware/polareyes.conf"
RAID_DEVICE="/dev/md0"
RAID_MOUNT_POINT="/mnt/raid"
FSTAB_FILE="/etc/fstab"
LOG_FILE="/var/log/raid_setup.log"

# --- Logging Helper ---
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SETUP: $1" | tee -a "$LOG_FILE"
}

log "--- [RAID SETUP MODE] Starting ---"

# --- 1. Find Drives ---
log "Scanning for USB drives..."
# Find drives (sdX) associated with USB, ignoring partitions
DRIVES=($(ls /dev/disk/by-id/usb* | grep -v 'part[0-9]$' || true))

if [ ${#DRIVES[@]} -lt 2 ]; then
    log "FATAL: Less than 2 USB drives found."
    exit 1
fi
DRIVE_1=${DRIVES[0]}
DRIVE_2=${DRIVES[1]}
log "Target Drives: $DRIVE_1, $DRIVE_2"

# --- 2. Check for Existing RAID ---
IS_RAID=0
# We check both drives. If either has a superblock, we assume RAID.
if mdadm --examine $DRIVE_1 2>/dev/null | grep -q "Magic : a92b4efc" || \
   mdadm --examine $DRIVE_2 2>/dev/null | grep -q "Magic : a92b4efc"; then
    log "Existing RAID superblock detected."
    IS_RAID=1
fi

# --- 3. Logic Branch ---
if [ "$1" == "--wipe" ]; then
    log "--- WIPE MODE DETECTED ---"
    echo "WARNING: ALL DATA WILL BE DESTROYED."
    read -p "Type 'YES' to confirm wipe and re-format: " CONFIRM
    if [ "$CONFIRM" != "YES" ]; then exit 1; fi
    
    # [FIX 1] Unmount FIRST, then Stop
    log "Unmounting filesystem..."
    umount $RAID_MOUNT_POINT 2>/dev/null || true
    
    log "Stopping old arrays..."
    mdadm --stop $RAID_DEVICE 2>/dev/null || true
    
    log "Unmounting individual drives..."
    umount ${DRIVE_1}* 2>/dev/null || true
    umount ${DRIVE_2}* 2>/dev/null || true
    
    log "Wiping metadata..."
    mdadm --zero-superblock $DRIVE_1 2>/dev/null || true
    mdadm --zero-superblock $DRIVE_2 2>/dev/null || true
    
    log "Creating new RAID 1 array..."
    yes | mdadm --create $RAID_DEVICE --level=1 --raid-devices=2 $DRIVE_1 $DRIVE_2 --run
    
    log "Formatting XFS..."
    mkfs.xfs -f $RAID_DEVICE

elif [ "$IS_RAID" -eq 1 ]; then
    log "--- EXISTING RAID DETECTED ---"
    log "Attempting to assemble and adopt..."
    
    # Ensure it's not already running to avoid 'busy' errors
    mdadm --stop $RAID_DEVICE 2>/dev/null || true
    
    # Assemble
    if mdadm --assemble $RAID_DEVICE $DRIVE_1 $DRIVE_2 --run; then
        log "Array assembled successfully."
    else
        # [FIX 3] Fail fast if assembly fails
        log "FATAL: Failed to assemble existing RAID."
        exit 1
    fi
    
else
    log "--- NO RAID DETECTED ---"
    log "Drives appear blank, but --wipe was not passed."
    log "Run 'sudo ./setup-raid.sh --wipe' to initialize new drives."
    exit 1
fi

# --- 4. Configuration ---
log "Configuring Mount Point..."
mkdir -p $RAID_MOUNT_POINT

log "Updating fstab..."
# [FIX 2] Use blkid for reliable UUID extraction
ARRAY_UUID=$(blkid -s UUID -o value $RAID_DEVICE)

if [ -z "$ARRAY_UUID" ]; then
    log "FATAL: Could not determine UUID. Array might not be active."
    exit 1
fi

# Note: 'nofail' is critical for headless systems
FSTAB_LINE="UUID=$ARRAY_UUID $RAID_MOUNT_POINT xfs defaults,nofail,noatime 0 2"

if ! grep -q "$ARRAY_UUID" $FSTAB_FILE; then
    echo "$FSTAB_LINE" >> $FSTAB_FILE
    log "fstab updated."
else
    log "fstab already up to date."
fi

log "Generating Config File..."
echo "# Auto-generated config" > $CONFIG_FILE
echo "raid_uuid=$ARRAY_UUID" >> $CONFIG_FILE
echo "raid_mount_point=$RAID_MOUNT_POINT" >> $CONFIG_FILE
echo "drive_1=$DRIVE_1" >> $CONFIG_FILE
echo "drive_2=$DRIVE_2" >> $CONFIG_FILE

log "--- SETUP COMPLETE ---"
log "You can now reboot."