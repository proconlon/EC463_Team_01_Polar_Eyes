#!/bin/bash

echo "==========================================="
echo " POLAR EYES: NATIVE BASH GPIO TEST"
echo "==========================================="

# 1. Force the hardware pull-down resistors ON
echo "[*] Forcing internal pull-down resistors (pd)..."
pinctrl set 17 ip pd
pinctrl set 24 ip pd

echo "[*] Hardware locked. Pins should now rest at 'lo'."
echo "[*] Waiting for 3.3V trigger... (Press Ctrl+C to exit)"
echo "-------------------------------------------"

# Track the last known state so we only print when it changes
LAST_PHOTO="lo"
LAST_VIDEO="lo"

# 2. Infinite loop to read the pins
while true; do
    # pinctrl get outputs a string like: "23: ip    pd | lo // GPIO23 = input"
    # We use grep to extract just the 'hi' or 'lo' part
    PHOTO_STATE=$(pinctrl get 17 | grep -o 'hi\|lo')
    VIDEO_STATE=$(pinctrl get 24 | grep -o 'hi\|lo')

    # Check for Photo Trigger (BCM 23)
    if [ "$PHOTO_STATE" == "hi" ] && [ "$LAST_PHOTO" == "lo" ]; then
        echo ">>> [$(date +'%H:%M:%S')] PHOTO TRIGGER DETECTED (BCM 23) <<<"
    fi
    LAST_PHOTO=$PHOTO_STATE

    # Check for Video Trigger (BCM 24)
    if [ "$VIDEO_STATE" == "hi" ] && [ "$LAST_VIDEO" == "lo" ]; then
        echo ">>> [$(date +'%H:%M:%S')] VIDEO TRIGGER DETECTED (BCM 24) <<<"
    fi
    LAST_VIDEO=$VIDEO_STATE

    # Sleep for 100ms to prevent maxing out the CPU
    sleep 0.1
done

