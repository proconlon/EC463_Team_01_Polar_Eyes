#!/bin/bash
# Fast GPIO pin reader for Pi 5
# Returns: "PHOTO_STATE VIDEO_STATE" (e.g., "0 1" means photo=LOW, video=HIGH)

# Read both pins in one shot
PHOTO_RAW=$(pinctrl get 24)
VIDEO_RAW=$(pinctrl get 27)

# Extract hi/lo and convert to 1/0
if echo "$PHOTO_RAW" | grep -q "hi"; then
    PHOTO=1
else
    PHOTO=0
fi

if echo "$VIDEO_RAW" | grep -q "hi"; then
    VIDEO=1
else
    VIDEO=0
fi

# Output as space-separated values (easy to parse)
echo "$PHOTO $VIDEO"
