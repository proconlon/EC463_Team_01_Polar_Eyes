#!/bin/bash
# This script is run by Packer inside the image
echo "--- [WORKER PI SETUP] Starting ---"

# 1. Install Dependencies
apt-get update
apt-get install -y git g++ make mdadm

# 2. Get the Code
# (Packer can also be set to clone this, but this is simple)
mkdir /opt/polar-eyes
# (Packer will copy your repo files here)

# 3. Build C++ Code
echo "Building C++ capture tools..."
cd /opt/polar-eyes/worker_node_pi_four/
make all
mv timelapse_capture /usr/local/bin/

# 4. Set up Boot Service
echo "Setting up boot script..."
# (This service will run your C++ code ONCE on boot, then shut down)
cp /opt/polar-eyes/config_scripts/worker-boot.service /etc/systemd/system/
systemctl enable worker-boot.service

echo "--- [WORKER PI SETUP] Complete ---"