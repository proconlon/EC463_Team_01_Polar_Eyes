#!/bin/bash
# Helper script to software reset all connected USB devices
# This simulates physically unplugging and replugging the USB cables.

echo "Initiating software USB reset..."

# Find all USB devices, but ignore the root hubs (usb1, usb2, etc.)
# Root hubs control the actual host controller; disabling them can freeze the system.
for dev in /sys/bus/usb/devices/*; do
    if [ -f "$dev/authorized" ]; then
        basename=$(basename "$dev")
        
        # Skip root hubs (they don't have hyphens in their names)
        if [[ "$basename" == usb* ]]; then
            continue
        fi

        echo "Simulating unplug for USB device: $basename"
        echo 0 > "$dev/authorized"
        
        sleep 0.5
        
        echo "Simulating replug for USB device: $basename"
        echo 1 > "$dev/authorized"
    fi
done

echo "Software USB reset complete."