import subprocess
import time
from datetime import datetime

# CONFIGURATION
INTERVAL_SECONDS = 300  # 5 Minutes
RETRY_ATTEMPTS = 3      # Number of times to try if it fails
RETRY_DELAY = 5         # Seconds to wait between retries
PHOTO_SCRIPT = "/home/polareyes/insta360_control/helper/photo.sh"

def log(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}")

log("Starting Robust Timelapse (5-minute intervals)...")

try:
    while True:
        success = False
        
        for attempt in range(1, RETRY_ATTEMPTS + 1):
            log(f"Triggering camera (Attempt {attempt}/{RETRY_ATTEMPTS})...")
            
            result = subprocess.run(
                [PHOTO_SCRIPT], 
                capture_output=True, 
                text=True, 
                errors='replace'
            )
            
            if result.returncode == 0:
                log("✓ Photo captured successfully.")
                success = True
                break  # Exit the retry loop
            else:
                log(f"⚠ Attempt {attempt} failed (Exit code: {result.returncode})")
                if attempt < RETRY_ATTEMPTS:
                    log(f"Retrying in {RETRY_DELAY}s...")
                    time.sleep(RETRY_DELAY)
                else:
                    log("✗ All retry attempts failed for this interval.", "ERROR")

        log(f"Waiting {INTERVAL_SECONDS}s until next interval.")
        time.sleep(INTERVAL_SECONDS)

except KeyboardInterrupt:
    log("Timelapse stopped by user.")
