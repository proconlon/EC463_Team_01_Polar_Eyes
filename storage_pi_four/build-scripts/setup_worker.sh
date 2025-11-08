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
apt-get install -y curl mdadm xfsprogs gdisk logrotate g++ make

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


# Demo scripts for 11/11 Demo day
cp /opt/polar-eyes/storage_pi_four/dev-scripts/mock_timelapse.sh /usr/local/bin/timelapse_capture
cp /opt/polar-eyes/storage_pi_four/dev-scripts/mock_event.sh /usr/local/bin/event_capture
chmod +x /usr/local/bin/timelapse_capture
chmod +x /usr/local/bin/event_capture


touch /var/log/polar_eyes.log
chmod 666 /var/log/polar_eyes.log
systemctl enable ssh

echo "--- [WORKER PI SETUP] Complete ---"