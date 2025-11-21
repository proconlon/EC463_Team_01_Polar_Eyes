#!/usr/bin/env python3
import os, sys, fcntl, subprocess, re
USBDEVFS_RESET = 21780

def reset_device():
    try:
        result = subprocess.check_output(['lsusb'], text=True)
        for line in result.split('\n'):
            if "Insta360" in line:
                match = re.search(r'Bus (\d+) Device (\d+)', line)
                if match:
                    path = f"/dev/bus/usb/{match.group(1)}/{match.group(2)}"
                    print(f"Resetting {path}...")
                    with open(path, 'w', os.O_WRONLY) as f:
                        fcntl.ioctl(f, USBDEVFS_RESET, 0)
                    return
    except Exception as e: print(f"Error: {e}")

if __name__ == "__main__": reset_device()