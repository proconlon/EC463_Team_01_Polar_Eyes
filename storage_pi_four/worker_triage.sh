#!/bin/bash
#
# This script is run by the worker-boot.service on each startup.
# it's a triage script since it decides what to do based on a GPIO pin on each boot (passed in from Arduino)
# Note it will power off when done!!!

# It reads the trigger pin, runs the correct mission, and shuts down.
#
# It also has a special setup mode for creation of the RAID (one-time)
# sudo /usr/local/bin/worker_triage.sh --setup-raid
#

set -e # Exit immediately if any command fails

SYS_LOG="/var/log/polar_eyes.log"
RAID_MOUNT_POINT="/mnt/raid"
RAID_LOG_FILE="${RAID_MOUNT_POINT}/polar_eyes_persistent.log"

CONFIG_FILE="/opt/polar-eyes/storage_pi_four/polareyes.conf"
RAID_DEVICE="/dev/md0"
TRIGGER_PIN=17 # GPIO 17

# --- [MODE 1: ONE-TIME RAID SETUP] ---
if [ "$1" == "--setup-raid" ]; then
    echo "--- [RAID SETUP MODE] Starting ---"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "::error:: Hardware config file not found at $CONFIG_FILE"
        exit 1
    fi

    # Read the stable drive IDs from the config file
    DRIVE_1=$(grep 'drive_1' $CONFIG_FILE | cut -d '=' -f 2 | tr -d ' ')
    DRIVE_2=$(grep 'drive_2' $CONFIG_FILE | cut -d '=' -f 2 | tr -d ' ')

    if [ -z "$DRIVE_1" ] || [ -z "$DRIVE_2" ]; then
        echo "::error:: Drive IDs not found in config file."
        exit 1
    fi
    echo "Found drives: $DRIVE_1 and $DRIVE_2"
    echo "Drives will be wiped and a RAID 1 array will be created."
    echo "This assumes you have manually wiped the drives first (see README)."

    echo "Building RAID 1 array..."
    # Create the RAID 1 array (mirroring)
    yes | mdadm --create $RAID_DEVICE --level=1 --raid-devices=2 $DRIVE_1 $DRIVE_2 --run

    echo "Creating filesystem..."
    # Create a filesystem on the new array
    mkfs.xfs $RAID_DEVICE

    # Create a mount point
    mkdir -p $RAID_MOUNT_POINT

    echo "Configuring fstab for auto-mount..."
    # Add to fstab to auto-mount on boot (with "nofail")
    ARRAY_UUID=$(mdadm --detail --scan | grep $RAID_DEVICE | awk '{print $4}' | cut -d '=' -f 2)
    FSTAB_LINE="UUID=$ARRAY_UUID $RAID_MOUNT_POINT xfs defaults,nofail 0 2"

    # Check if the line already exists before adding it
    if ! grep -q "$FSTAB_LINE" /etc/fstab; then
        echo "$FSTAB_LINE" >> /etc/fstab
        echo "Added RAID to /etc/fstab."
    else
        echo "RAID entry already exists in /etc/fstab."
    fi

    echo "--- [RAID SETUP MODE] Complete. Array created and fstab updated."
    echo "You can now reboot."
    exit 0
fi

# --- [MODE 2: NORMAL BOOT] ---
echo "--- [TRIAGE] System Booted ---" | sudo tee -a "$SYS_LOG"

# --- 2. Mount RAID Array ---
# The fstab entry should handle this, but we'll mount it just in case
mount -a

if ! mountpoint -q "$RAID_MOUNT_POINT"; then
    # RAID FAILED: Log all future output to SYS_LOG only
    echo "[TRIAGE] WARNING: RAID array not mounted. Logging to SD card only." | sudo tee -a "$SYS_LOG"
    # This exec redirects all stdout/stderr from this point on
    exec &> >(sudo tee -a "$SYS_LOG")
else
    # RAID SUCCESS: Log all future output to *BOTH* files
    echo "[TRIAGE] RAID array mounted. Logging to system and RAID." | sudo tee -a "$SYS_LOG" | sudo tee -a "$RAID_LOG_FILE"
    # This exec redirects all stdout/stderr to both locations
    exec &> >(sudo tee -a "$SYS_LOG" | sudo tee -a "$RAID_LOG_FILE")
fi

echo "[TRIAGE] Setting up GPIO..."
# 4. Setup GPIO
echo $TRIGGER_PIN > /sys/class/gpio/export || true
sleep 0.1
echo "in" > /sys/class/gpio/gpio${TRIGGER_PIN}/direction

# 5. Read Trigger Pin
PIN_VALUE=$(cat /sys/class/gpio/gpio${TRIGGER_PIN}/value)

if [ "$PIN_VALUE" -eq 0 ]; then
    echo "[TRIAGE] Trigger Pin is LOW. Running Timelapse Mission."
    /usr/local/bin/timelapse_capture
    echo "[TRIAGE] Timelapse script completed."
else
    echo "[TRIAGE] Trigger Pin is HIGH. Running Event Mission."
    /usr/local/bin/event_capture
    echo "[TRIAGE] Event script completed."
fi

# 6. Clean up GPIO
echo $TRIGGER_PIN > /sys/class/gpio/unexport

# 7. Shut Down
echo "[TRIAGE] Mission complete. Shutting down system."
sudo poweroff