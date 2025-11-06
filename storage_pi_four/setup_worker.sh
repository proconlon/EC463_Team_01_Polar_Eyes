# #!/bin/bash
# # This script is run by Packer to build the OS image.
# echo "--- [WORKER PI SETUP] Starting ---"

# # 1. Install Dependencies
# apt-get update
# apt-get install -y git g++ make mdadm rpi.gpio-common

# # 2. Get the Code
# # (Packer copies this to /opt/polar-eyes)
# CODE_DIR="/opt/polar-eyes"

# # 3. Build C++ Code
# echo "Building C++ capture tools..."
# make -C $CODE_DIR/storage_pi_four/
# mv $CODE_DIR/storage_pi_four/timelapse_capture /usr/local/bin/
# mv $CODE_DIR/storage_pi_four/event_capture /usr/local/bin/

# # 4. Install the Triage Script
# echo "Installing Triage Script..."
# mv $CODE_DIR/storage_pi_four/worker_triage.sh /usr/local/bin/
# chmod +x /usr/local/bin/worker_triage.sh

# # 5. Install and Enable the Boot Service
# echo "Enabling Boot Service..."
# cp $CODE_DIR/config_scripts/worker-boot.service /etc/systemd/system/
# systemctl enable worker-boot.service

# # 6. Create Log File
# touch /var/log/polar_eyes.log
# chmod 666 /var/log/polar_eyes.log

# #!/bin/bash
# echo "--- [WORKER PI SETUP] Reading Config ---"

# # Load the config file
# CONFIG_FILE="/boot/firmware/polareyes.conf"

# # Use 'grep' and 'awk' to parse the INI file
# RAID_DEVICES=$(grep -E "^raid_devices" $CONFIG_FILE | awk -F' = ' '{print $2}')
# RAID_LEVEL=$(grep -E "^raid_level" $CONFIG_FILE | awk -F' = ' '{print $2}')
# RAID_MOUNT=$(grep -E "^raid_mount_point" $CONFIG_FILE | awk -F' = ' '{print $2}')

# # Now, use these variables to build the RAID
# echo "Building RAID Level $RAID_LEVEL with devices: $RAID_DEVICES"
# # sudo mdadm --create /dev/md0 --level=$RAID_LEVEL --raid-devices=3 $RAID_DEVICES
# # ... (rest of your mdadm setup)

# echo "--- [WORKER PI SETUP] Complete ---"

#!/bin/bash
set -e # Exit immediately if any command fails

echo "--- [MINIMAL TEST SCRIPT] Starting ---"

echo "Running apt-get update..."
apt-get update

echo "Installing a small package (curl)..."
apt-get install -y curl

echo "Proving we are in an ARM environment:"
uname -m

echo "Creating a test file..."
touch /I_WAS_HERE.txt

echo "--- [MINIMAL TEST SCRIPT] Complete ---"