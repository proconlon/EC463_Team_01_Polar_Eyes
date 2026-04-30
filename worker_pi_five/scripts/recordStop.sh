#!/bin/bash
# Helper script to stop video recording with camera_control

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
SDK_DIR="$ROOT_DIR/CameraSDK-20250418_161512-2.0.2-gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu"
LIB_DIR="$SDK_DIR/lib"
APP="$ROOT_DIR/camera_control"

# Set how long to wait before giving up (15 seconds is usually safe)
TIMEOUT_SECS=60

# check if application exists
if [ ! -f "$APP" ]; then
    echo "Error: camera_control not found."
    exit 1
fi

# check if library directory exists
if [ ! -d "$LIB_DIR" ]; then
    echo "Error: SDK library directory not found: $LIB_DIR"
    exit 1
fi

# export library path
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$LIB_DIR

echo "Sending stop command (Timeout: ${TIMEOUT_SECS}s)..."

# Run the app wrapped in the timeout command (notice no 'exec')
timeout $TIMEOUT_SECS "$APP" record-stop "$@"
EXIT_CODE=$?

# Analyze the result
if [ $EXIT_CODE -eq 124 ]; then
    # Exit code 124 specifically means the timeout command triggered
    echo "Warning: SDK hung at 99%. Timed out after ${TIMEOUT_SECS}s."
    echo "Assuming completion."
    exit 0
elif [ $EXIT_CODE -eq 0 ]; then
    echo "Stop command completed normally."
    exit 0
else
    echo "SDK crashed or failed (Exit code: $EXIT_CODE). Forcing success to release lock."
    # We exit 0 anyway so the Python script doesn't get jammed up
    exit 0
fi
