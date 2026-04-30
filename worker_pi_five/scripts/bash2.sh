#!/bin/bash

echo "=================================================="
echo " POLAR EYES: DEMO DAY GPIO TESTER (v3.2)"
echo " Pins: PHOTO=27 (Pin 13), VIDEO=24 (Pin 18)"
echo "=================================================="

# 1. Hardware Force-Lock
# We do this every time the script runs to ensure resistors are ON
pinctrl set 27 ip pd
pinctrl set 24 ip pd

echo "[*] Hardware Pull-Downs: ACTIVE"
echo "[*] System: READY. Waiting for Arduino signals..."
echo "--------------------------------------------------"

# State Tracking
LAST_PHOTO="lo"
LAST_VIDEO="lo"

while true; do
    # Capture current states
    PHOTO_STATE=$(pinctrl get 27 | grep -o 'hi\|lo')
    VIDEO_STATE=$(pinctrl get 24 | grep -o 'hi\|lo')

    # --- PHOTO LOGIC (BCM 27) ---
    if [ "$PHOTO_STATE" == "hi" ] && [ "$LAST_PHOTO" == "lo" ]; then
        echo "[$(date +'%H:%M:%S')] >>> PHOTO TRIGGER START (BCM 27)"
    elif [ "$PHOTO_STATE" == "lo" ] && [ "$LAST_PHOTO" == "hi" ]; then
        echo "[$(date +'%H:%M:%S')] <<< PHOTO TRIGGER END"
    fi
    LAST_PHOTO=$PHOTO_STATE

    # --- VIDEO LOGIC (BCM 24) ---
    if [ "$VIDEO_STATE" == "hi" ] && [ "$LAST_VIDEO" == "lo" ]; then
        echo "[$(date +'%H:%M:%S')] >>> VIDEO RECORD START (BCM 24)"
    elif [ "$VIDEO_STATE" == "lo" ] && [ "$LAST_VIDEO" == "hi" ]; then
        echo "[$(date +'%H:%M:%S')] <<< VIDEO RECORD END"
    fi
    LAST_VIDEO=$VIDEO_STATE

    sleep 0.05 # Fast polling (20Hz) for responsive testing
done
