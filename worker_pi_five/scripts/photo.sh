#!/bin/bash
# Helper script to take a photo with camera_control 
# Includes 3x Retry and Software USB Reset

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
SDK_DIR="$ROOT_DIR/CameraSDK-20250418_161512-2.0.2-gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu"
LIB_DIR="$SDK_DIR/lib"
APP="$ROOT_DIR/camera_control"

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

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$LIB_DIR

MAX_RETRIES=3
ATTEMPT=1
SUCCESS=0

while [ $ATTEMPT -le $MAX_RETRIES ]; do
    echo "Attempt $ATTEMPT of $MAX_RETRIES: Running camera_control photo..."
    
    # Run the app normally (no 'exec') so we can catch the exit code
    "$APP" photo "$@"
    
    # Check if the command succeeded
    if [ $? -eq 0 ]; then
        echo "✓ Photo captured successfully."
        SUCCESS=1
        break
    else
        echo "✗ Photo capture failed (Attempt $ATTEMPT/$MAX_RETRIES)."
        
        # If we have retries left, reset the USB stack
        if [ $ATTEMPT -lt $MAX_RETRIES ]; then
            echo "Initiating software USB reset to clear ghost connections..."
            
            for dev in /sys/bus/usb/devices/*; do
                if [ -f "$dev/authorized" ]; then
                    basename=$(basename "$dev")
                    
                    # Skip root hubs (usb1, usb2, etc.) to avoid crashing the Pi's main controller
                    if [[ "$basename" != usb* ]]; then
                        echo 0 > "$dev/authorized"
                        sleep 0.5
                        echo 1 > "$dev/authorized"
                    fi
                fi
            done
            
            echo "Waiting 4 seconds for camera to reboot and establish USB handshake..."
            sleep 4
        fi
    fi
    
    ATTEMPT=$((ATTEMPT + 1))
done

# If all retries failed, exit with an error code so the Python script knows
if [ $SUCCESS -eq 0 ]; then
    echo "FATAL: Failed to capture photo after $MAX_RETRIES attempts."
    exit 1
fi

exit 0