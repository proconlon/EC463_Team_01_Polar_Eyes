#!/bin/bash
#
# Polar Eyes - Pi 5 Worker Deployment
# ---------------------------------------------------------
# Lays out the worker_pi_five/ files at the absolute paths the
# scripts internally reference, then installs the systemd unit.
#
# Run on the Pi 5 itself, as root:
#     sudo ./worker_pi_five/setup_pi_five.sh
#
# Idempotent: safe to re-run after pulling repo updates.
# ---------------------------------------------------------

set -e

# ---------- Root check ----------
if [ "$EUID" -ne 0 ]; then
    echo "::ERROR:: This script must be run as root (use 'sudo'). Aborting."
    exit 1
fi

# ---------- Path resolution ----------
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SRC_DIR="$SCRIPT_DIR/src"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
SDK_DIR="$SCRIPT_DIR/camera_sdk"
CONFIG_DIR="$SCRIPT_DIR/config"

# Deployment roots on the Pi 5
DEPLOY_USER="polareyes"
DEPLOY_HOME="/home/${DEPLOY_USER}"
INSTA_DIR="${DEPLOY_HOME}/insta360_control"
HELPER_DIR="${INSTA_DIR}/helper"
STORAGE_DIR="${INSTA_DIR}/storage"
SYSTEMD_DIR="/etc/systemd/system"

log() {
    echo "[setup_pi_five] $1"
}

# ---------- 1. Sanity checks on repo contents ----------
log "Verifying repo layout..."
for required in \
    "$SRC_DIR/polar_listener.py" \
    "$SRC_DIR/sensor_logger.py" \
    "$SCRIPTS_DIR/run_listener.sh" \
    "$SCRIPTS_DIR/gpio_reader.sh" \
    "$SCRIPTS_DIR/photo.sh" \
    "$CONFIG_DIR/polar-listener.service"
do
    if [ ! -f "$required" ]; then
        log "FATAL: Missing required file: $required"
        exit 1
    fi
done

# ---------- 2. Create deployment directories ----------
log "Creating deployment directories under ${DEPLOY_HOME}..."
mkdir -p "$INSTA_DIR"
mkdir -p "$HELPER_DIR"
mkdir -p "$STORAGE_DIR/photos"
mkdir -p "$STORAGE_DIR/videos"

# ---------- 3. Install Python listener + telemetry module ----------
log "Installing Python sources to ${DEPLOY_HOME}/..."
install -m 0755 "$SRC_DIR/polar_listener.py"   "${DEPLOY_HOME}/polar_listener.py"
install -m 0644 "$SRC_DIR/sensor_logger.py"    "${DEPLOY_HOME}/sensor_logger.py"
install -m 0755 "$SRC_DIR/simple_timelapse.py" "${DEPLOY_HOME}/simple_timelapse.py"

# timelapse.py expects a sibling helper/ dir, so it lives inside insta360_control/
install -m 0755 "$SRC_DIR/timelapse.py"        "${INSTA_DIR}/timelapse.py"

# ---------- 4. Install root-level bash helpers ----------
log "Installing root-level bash helpers..."
install -m 0755 "$SCRIPTS_DIR/run_listener.sh" "${DEPLOY_HOME}/run_listener.sh"
install -m 0755 "$SCRIPTS_DIR/gpio_reader.sh"  "${DEPLOY_HOME}/gpio_reader.sh"
install -m 0755 "$SCRIPTS_DIR/bash_test.sh"    "${DEPLOY_HOME}/bash_test.sh"
install -m 0755 "$SCRIPTS_DIR/bash2.sh"        "${DEPLOY_HOME}/bash2.sh"

# ---------- 5. Install camera helper bash wrappers ----------
log "Installing camera helper scripts to ${HELPER_DIR}..."
install -m 0755 "$SCRIPTS_DIR/photo.sh"         "${HELPER_DIR}/photo.sh"
install -m 0755 "$SCRIPTS_DIR/recordStart.sh"   "${HELPER_DIR}/recordStart.sh"
install -m 0755 "$SCRIPTS_DIR/recordStop.sh"    "${HELPER_DIR}/recordStop.sh"
install -m 0755 "$SCRIPTS_DIR/shutoff.sh"       "${HELPER_DIR}/shutoff.sh"
install -m 0755 "$SCRIPTS_DIR/copyStorage.sh"   "${HELPER_DIR}/copyStorage.sh"
install -m 0755 "$SCRIPTS_DIR/run.sh"           "${HELPER_DIR}/run.sh"
install -m 0755 "$SCRIPTS_DIR/usb_reset.sh"     "${HELPER_DIR}/usb_reset.sh"

# Original name for the SDK build script was setup.sh; preserve it on the Pi
install -m 0755 "$SCRIPTS_DIR/setup_camera_sdk.sh" "${HELPER_DIR}/setup.sh"

# ---------- 6. Install C++ camera control binary + SDK ----------
log "Installing camera_control binary + Insta360 SDK..."
if [ -f "$SDK_DIR/camera_control" ]; then
    install -m 0755 "$SDK_DIR/camera_control" "${INSTA_DIR}/camera_control"
else
    log "WARNING: $SDK_DIR/camera_control not found; build it first via 'make' in worker_pi_five/camera_sdk/."
fi

# Copy the entire SDK directory (libCameraSDK.so + headers) so the bash
# wrappers' LD_LIBRARY_PATH discovery resolves at runtime.
SDK_SUBDIR=$(find "$SDK_DIR" -maxdepth 1 -type d -name "CameraSDK-*" | head -n 1)
if [ -n "$SDK_SUBDIR" ]; then
    SDK_BASENAME=$(basename "$SDK_SUBDIR")
    log "Syncing SDK directory: $SDK_BASENAME"
    rsync -a --delete "$SDK_SUBDIR/" "${INSTA_DIR}/${SDK_BASENAME}/"
else
    log "WARNING: No CameraSDK-* directory found under $SDK_DIR. Camera scripts will fail until SDK is present."
fi

# ---------- 7. Storage permissions ----------
log "Setting ownership on ${INSTA_DIR} and ${DEPLOY_HOME} runtime files..."
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "$INSTA_DIR" || true
chown "${DEPLOY_USER}:${DEPLOY_USER}" \
    "${DEPLOY_HOME}/polar_listener.py" \
    "${DEPLOY_HOME}/sensor_logger.py" \
    "${DEPLOY_HOME}/simple_timelapse.py" \
    "${DEPLOY_HOME}/run_listener.sh" \
    "${DEPLOY_HOME}/gpio_reader.sh" \
    "${DEPLOY_HOME}/bash_test.sh" \
    "${DEPLOY_HOME}/bash2.sh" || true

# Ensure every deployed *.sh is executable (belt-and-suspenders alongside install -m 0755)
log "Ensuring all deployed shell scripts are executable..."
chmod +x \
    "${DEPLOY_HOME}/run_listener.sh" \
    "${DEPLOY_HOME}/gpio_reader.sh" \
    "${DEPLOY_HOME}/bash_test.sh" \
    "${DEPLOY_HOME}/bash2.sh" \
    "${HELPER_DIR}"/*.sh

# ---------- 8. Install systemd unit ----------
log "Installing systemd unit polar-listener.service..."
install -m 0644 "$CONFIG_DIR/polar-listener.service" "${SYSTEMD_DIR}/polar-listener.service"

systemctl daemon-reload
systemctl enable polar-listener.service

log "--- DEPLOYMENT COMPLETE ---"
log ""
log "Next steps:"
log "  1. Verify camera_control was built: ls -l ${INSTA_DIR}/camera_control"
log "     (build it via: cd worker_pi_five/camera_sdk && make)"
log "  2. Start the listener:    sudo systemctl start polar-listener.service"
log "  3. Tail the logs:         journalctl -u polar-listener.service -f"
log "  4. Telemetry CSV will be written to: ${STORAGE_DIR}/telemetry.csv"
