#!/usr/bin/env python3
"""
Polar Eyes - Pi Listener Service v4.0
1-Minute Auto-Photos + Pin-Duration Video (No Reboots)
"""

import subprocess
import time
import sys
from datetime import datetime
from pathlib import Path
import os
import sensor_logger

# ==========================================
# CONFIGURATION
# ==========================================

# GPIO Pin Assignments (BCM numbering)f
PHOTO_TRIGGER_PIN = 24  # Physical Pin 18 (Optional Manual Override)
VIDEO_TRIGGER_PIN = 27  # Physical Pin 13 (High = Record, Low = Stop)

# GPIO Reader Script
GPIO_READER_SCRIPT = Path("/home/polareyes/gpio_reader.sh")

# Camera Control Scripts
SCRIPT_DIR = Path("/home/polareyes/insta360_control/helper")
PHOTO_SCRIPT = SCRIPT_DIR / "photo.sh"
RECORD_START_SCRIPT = SCRIPT_DIR / "recordStart.sh"
RECORD_STOP_SCRIPT = SCRIPT_DIR / "recordStop.sh"
SHUTOFF_SCRIPT = SCRIPT_DIR / "shutoff.sh"

# Storage Paths
BASE_STORAGE_DIR = Path("/home/polareyes/insta360_control/storage")
PHOTO_STORAGE_DIR = BASE_STORAGE_DIR / "photos"
VIDEO_STORAGE_DIR = BASE_STORAGE_DIR / "videos"
LOG_FILE = Path("/home/polareyes/polar_listener.log")

# Timing
PHOTO_TIMEOUT = 30
VIDEO_START_TIMEOUT = 10
VIDEO_STOP_TIMEOUT = 10
PHOTO_INTERVAL = 30  # 1 minute in seconds

# ==========================================
# LOGGING SETUP
# ==========================================

def log(message, level="INFO"):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] [{level}] {message}"
    print(log_entry)
    sys.stdout.flush()
    try:
        with open(LOG_FILE, 'a') as f:
            f.write(log_entry + '\n')
    except Exception:
        pass

# ==========================================
# HARDWARE CONTROL & VALIDATION
# ==========================================

def read_gpio_pins():
    try:
        result = subprocess.run(
            [str(GPIO_READER_SCRIPT)],
            capture_output=True, text=True, timeout=0.5, errors='replace'
        )
        if result.returncode == 0:
            states = result.stdout.strip().split()
            if len(states) == 2:
                return int(states[0]), int(states[1])
        return 0, 0
    except Exception:
        return 0, 0

def init_gpio():
    try:
        subprocess.run(["pinctrl", "set", str(VIDEO_TRIGGER_PIN), "ip", "pd"], check=True)
        subprocess.run(["pinctrl", "set", str(PHOTO_TRIGGER_PIN), "ip", "pd"], check=True)
        log("✓ GPIO initialized (Triggers with pull-downs)", "INFO")
        return True
    except Exception as e:
        log(f"✗ GPIO init failed: {e}", "ERROR")
        return False

def validate_scripts():
    scripts = {
        "GPIO Reader": GPIO_READER_SCRIPT,
        "Photo": PHOTO_SCRIPT,
        "Record Start": RECORD_START_SCRIPT,
        "Record Stop": RECORD_STOP_SCRIPT,
        "Shutoff": SHUTOFF_SCRIPT
    }
    missing = [name for name, path in scripts.items() if not path.exists()]
    if missing:
        log(f"Missing script(s): {', '.join(missing)}", "ERROR")
        return False
    return True

# ==========================================
# CAMERA CONTROL FUNCTIONS
# ==========================================

def take_photo(trigger_source="AUTO"):
    log("Executing photo capture...")
    try:
        result = subprocess.run(
            [str(PHOTO_SCRIPT), str(PHOTO_STORAGE_DIR)],
            timeout=PHOTO_TIMEOUT, capture_output=True, text=True, errors='replace'
        )
        if result.returncode == 0:
            log(f"✓ Photo saved to {PHOTO_STORAGE_DIR}", "SUCCESS")
            
            # Log the telemetry with the trigger source!
            try:
                import sensor_logger
                sensor_logger.log_event(trigger_source)
            except Exception as e:
                log(f"Failed to log telemetry: {e}", "WARNING")
                
            return True
        else:
            log(f"✗ Photo capture failed ({result.returncode})", "ERROR")
            if result.stderr:
                log(f"Error: {result.stderr.strip()}", "ERROR")
            return False
    except subprocess.TimeoutExpired:
        log("⚠ Photo capture timeout", "WARNING")
        return True
    except Exception as e:
        log(f"✗ Photo exception: {e}", "ERROR")
        return False

def start_video():
    log("Starting video recording...")
    try:
        result = subprocess.run(
            [str(RECORD_START_SCRIPT)],
            timeout=VIDEO_START_TIMEOUT, capture_output=True, text=True, errors='replace'
        )
        if result.returncode == 0:
            log("✓ Video recording started", "SUCCESS")
            return True
        else:
            log(f"✗ Video start failed ({result.returncode})", "ERROR")
            if result.stderr:
                log(f"Error: {result.stderr.strip()}", "ERROR")
            return False
    except subprocess.TimeoutExpired:
        log("⚠ Video start timeout", "WARNING")
        return False
    except Exception as e:
        log(f"✗ Video exception: {e}", "ERROR")
        return False

def stop_video():
    log("Stopping video recording...")
    try:
        result = subprocess.run(
            [str(RECORD_STOP_SCRIPT), str(VIDEO_STORAGE_DIR)],
            timeout=VIDEO_STOP_TIMEOUT, capture_output=True, text=True, errors='replace'
        )
        if result.returncode == 0:
            log(f"✓ Video stopped/saved to {VIDEO_STORAGE_DIR}", "SUCCESS")
            return True
        else:
            log(f"✗ Video stop failed ({result.returncode})", "ERROR")
            if result.stderr:
                log(f"Error: {result.stderr.strip()}", "ERROR")
            return False
    except Exception as e:
        log(f"✗ Video stop exception: {e}", "ERROR")
        return False

# ==========================================
# GPIO MONITORING & INTERVAL CYCLE
# ==========================================

class TriggerMonitor:
    def __init__(self):
        self.photo_triggered = False
        self.video_triggered = False
        self.video_recording = False
        self.last_photo_state = 0
        self.last_video_state = 0
        self.last_interval_time = time.time()
        
    def poll(self):
        current_time = time.time()
        
        # --- 1-MINUTE INTERVAL TIMER ---
        if current_time - self.last_interval_time >= PHOTO_INTERVAL:
            if self.video_recording:
                log("⚠ 1-minute interval reached, but skipped because video is recording.", "WARNING")
            else:
                log("=" * 50)
                log("1-MINUTE INTERVAL REACHED. TAKING AUTO-PHOTO.")
                log("=" * 50)
                take_photo()
            
            # Reset the clock whether we took a photo or skipped it
            self.last_interval_time = current_time

        # Read GPIO Pins
        photo_pin, video_pin = read_gpio_pins()
        
        if photo_pin != self.last_photo_state:
            self.last_photo_state = photo_pin
            
        if video_pin != self.last_video_state:
            self.last_video_state = video_pin
        
        # --- PHOTO TRIGGER (Hardware Override) ---
        if photo_pin == 1 and not self.photo_triggered:
            self.photo_triggered = True
            if not self.video_recording:
                log("=" * 50)
                log("PHOTO TRIGGER DETECTED (EXTERNAL PIN)")
                log("=" * 50)
                take_photo("MANUAL_PIN")
                # Reset interval clock so we don't immediately double-shoot
                self.last_interval_time = time.time() 
            time.sleep(1) # Small cooldown
            
        elif photo_pin == 0:
            self.photo_triggered = False
        
        # --- VIDEO TRIGGER (Pin Duration Logic) ---
        if video_pin == 1 and not self.video_triggered:
            self.video_triggered = True
            log("=" * 50)
            log("VIDEO START TRIGGER DETECTED (PIN HIGH)")
            log("=" * 50)
            
            if start_video():
                self.video_recording = True
                
        elif video_pin == 0 and self.video_triggered:
            self.video_triggered = False
            
            if self.video_recording:
                log("=" * 50)
                log("VIDEO STOP TRIGGER DETECTED (PIN LOW)")
                log("=" * 50)
                stop_video()
                self.video_recording = False
                
                # Reset interval clock after a video finishes
                self.last_interval_time = time.time()

# ==========================================
# MAIN LOOP
# ==========================================

def main():
    log("=" * 60)
    log("POLAR EYES - Pi Listener Service v4.0")
    log("1-Minute Auto-Photos + Pin-Duration Video")
    log("=" * 60)
    
    if os.geteuid() != 0:
        log("ERROR: This script must be run as sudo/root", "ERROR")
        sys.exit(1)
    
    if not validate_scripts():
        sys.exit(1)
    
    PHOTO_STORAGE_DIR.mkdir(parents=True, exist_ok=True)
    VIDEO_STORAGE_DIR.mkdir(parents=True, exist_ok=True)
    
    if not init_gpio():
        sys.exit(1)
    
    # --- STARTUP SEQUENCE ---
    log("System initialized. Taking initial boot photo...")
    take_photo()
    
    # Initialize monitor AFTER the initial photo so the 1-minute timer starts now
    monitor = TriggerMonitor()
    
    log(f"System ready. Listening for triggers. Next auto-photo in {PHOTO_INTERVAL} seconds...")
    
    try:
        while True:
            monitor.poll()
            time.sleep(0.05)
    except KeyboardInterrupt:
        log("\nShutdown signal received")
    finally:
        log("Service stopped")

if __name__ == "__main__":
    main()