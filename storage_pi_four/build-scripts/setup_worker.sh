# #!/bin/bash

# This script is run during image build process for dependencies and some file setup.
# Note it is run within the chroot of the image being built.

set -e

# make the chroot env happy
export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8

echo "--- [WORKER PI SETUP] Starting ---"

echo "Installing dependencies..."
apt-get update
apt-get install -y curl mdadm xfsprogs gdisk logrotate g++ make python3-rpi.gpio

# install tailscale for access
# will remove for prod, just for dev
curl -fsSL https://tailscale.com/install.sh | sh

echo "ARM environment check:"
uname -m

# Configure Log Rotation
echo "Setting up logrotate for /var/log/polar_eyes.log..."
cat << 'EOF' > /etc/logrotate.d/polar-eyes
# --- SD Card Log (Small, protect the card) ---
/var/log/polar_eyes.log {
    weekly
    size 10M
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    create 666 root root
}

# --- RAID Log (Persistent, can be larger) ---
/mnt/raid/polar_eyes_persistent.log {
    monthly
    size 100M
    rotate 10
    compress
    delaycompress
    missingok
    notifempty
    create 666 root root
}
EOF

# polar eyes application code
echo "Installing Triage Script and Boot Service..."

# Copy the Triage Script (the "brains")
cp /opt/polar-eyes/storage_pi_four/worker_triage.sh /usr/local/bin/worker_triage.sh
chmod +x /usr/local/bin/worker_triage.sh

# Copy the Service File (the "trigger")
cp /opt/polar-eyes/storage_pi_four/worker-boot.service /etc/systemd/system/worker-boot.service
systemctl enable worker-boot.service

echo "Setting up Insta360 SDK..."

# 1. Create a clean home for the app and sdk
mkdir -p /opt/polar-eyes/bin
mkdir -p /opt/polar-eyes/sdk

# 2. Safer Search: Find the file first, THEN process it
echo "Looking for libCameraSDK.so..."
SDK_FILE=$(find /opt/polar-eyes -type f -name "libCameraSDK.so" | head -n 1)

if [ -n "$SDK_FILE" ]; then
    # File found! Determine the directory.
    # We use dirname twice to go from /lib/libCameraSDK.so -> /lib -> /SDK_ROOT
    RAW_SDK_DIR=$(dirname "$(dirname "$SDK_FILE")")
    
    echo "Found SDK at: $RAW_SDK_DIR"
    cp -r "$RAW_SDK_DIR"/* /opt/polar-eyes/sdk/
    echo "SDK installed successfully."
else
    # File not found - Skip gracefully
    echo "WARNING: libCameraSDK.so not found in build context."
    echo "Skipping SDK installation. You must manually copy the SDK to /opt/polar-eyes/sdk/ on the device later."
fi

# 3. Install the C++ Binary
# Assuming your compiled binary is named 'camera_control'
# If you have 4 separate binaries, copy them all here.
if [ -f "/opt/polar-eyes/storage_pi_four/camera_control" ]; then
    cp /opt/polar-eyes/storage_pi_four/camera_control /opt/polar-eyes/bin/
    chmod +x /opt/polar-eyes/bin/camera_control
    echo "Binary installed to /opt/polar-eyes/bin/camera_control"
fi

cp /opt/polar-eyes/storage_pi_four/dev-scripts/take_photo.sh /usr/local/bin/take_photo
cp /opt/polar-eyes/storage_pi_four/dev-scripts/start_video.sh /usr/local/bin/start_video
cp /opt/polar-eyes/storage_pi_four/dev-scripts/stop_video.sh /usr/local/bin/stop_video
cp /opt/polar-eyes/storage_pi_four/dev-scripts/download_all_data.sh /usr/local/bin/download_all_data

cp /opt/polar-eyes/storage_pi_four/read_gpio.py /usr/local/bin/read_gpio.py
chmod +x /usr/local/bin/take_photo
chmod +x /usr/local/bin/start_video
chmod +x /usr/local/bin/stop_video
chmod +x /usr/local/bin/download_all_data
chmod +x /usr/local/bin/read_gpio.py

touch /var/log/polar_eyes.log
chmod 666 /var/log/polar_eyes.log
systemctl enable ssh

echo "--- [WORKER PI SETUP] Complete ---"