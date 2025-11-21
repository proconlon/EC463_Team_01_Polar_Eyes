#!/usr/bin/env python3
import RPi.GPIO as GPIO
import subprocess
import time
import threading
import logging
import os
import sys

# --- CONFIGURATION ---
SHUTTER_PIN = 23  # Pin 16
MODE_PIN    = 24  # Pin 18
RAID_PATH   = "/mnt/raid2"
KEEPALIVE_FILE = os.path.join(RAID_PATH, ".keepalive")

LOG_FILE = "/var/log/polar_eyes.log"
logging.basicConfig(filename=LOG_FILE, level=logging.INFO, format='%(asctime)s - LISTENER: %(message)s')

def run_command(command):
    try:
        logging.info(f"Executing: {command}")
        subprocess.run(command, shell=True, check=True)
    except subprocess.CalledProcessError as e:
        logging.error(f"Command failed: {command} (Exit Code: {e.returncode})")
    except Exception as e:
        logging.error(f"Execution error: {e}")

def raid_keepalive():
    while True:
        try:
            if os.path.ismount(RAID_PATH):
                with open(KEEPALIVE_FILE, "w") as f: f.write(str(time.time()))
        except IOError: logging.error("RAID I/O Error detected.")
        except Exception: pass
        time.sleep(60)

if __name__ == "__main__":
    try:
        try: GPIO.cleanup()
        except: pass
        
        logging.info("--- SYSTEM STARTUP: Polling Listener ---")
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(SHUTTER_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        GPIO.setup(MODE_PIN,    GPIO.IN, pull_up_down=GPIO.PUD_DOWN)

        t = threading.Thread(target=raid_keepalive); t.daemon = True; t.start()

        logging.info("performing SAFETY BOOT PHOTO...")
        run_command("/usr/local/bin/take_photo")
        logging.info("Service Ready. Entering Polling Loop...")
        
        last_shutter_state = GPIO.HIGH
        
        while True:
            current_shutter_state = GPIO.input(SHUTTER_PIN)
            # Detect FALLING EDGE
            if last_shutter_state == GPIO.HIGH and current_shutter_state == GPIO.LOW:
                logging.info("--- TRIGGER DETECTED ---")
                mode = GPIO.input(MODE_PIN)
                if mode == GPIO.HIGH:
                    logging.info("Mode: VIDEO")
                    run_command("/usr/local/bin/start_video")
                    time.sleep(10) # Blocking duration
                    run_command("/usr/local/bin/stop_video")
                else:
                    logging.info("Mode: PHOTO")
                    run_command("/usr/local/bin/take_photo")
                logging.info("--- Mission Complete ---")
                time.sleep(1) # Debounce

            last_shutter_state = current_shutter_state
            time.sleep(0.05)

    except Exception as e:
        logging.critical(f"Service crashed: {e}"); GPIO.cleanup(); sys.exit(1)