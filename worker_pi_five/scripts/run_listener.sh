#!/bin/bash
# Polar Eyes Hardware Guard Wrapper

echo "[*] Initializing Pi 5 Hardware Pins..."

# 1. Force the RP1 chip to engage pull-down resistors
/usr/bin/pinctrl set 27 ip pd
/usr/bin/pinctrl set 24 ip pd

echo "[*] Pins 27 & 24 locked LOW. Launching Python Listener..."

# 2. Launch the Python script
# We use 'exec' so that the Python process replaces the shell process
sudo /usr/bin/python3 /home/polareyes/polar_listener.py
