import csv
import os
import time
from datetime import datetime
import random

# File path for the telemetry log
LOG_FILE = "/home/polareyes/insta360_control/storage/telemetry.csv"

def get_sensor_data():
    """
    STUB FUNCTION: Replace these random ranges with actual 
    I2C/UART library calls when the hardware is connected.
    """
    return {
        "gps_lat": round(random.uniform(42.3000, 42.4000), 6), # Boston area
        "gps_lon": round(random.uniform(-71.1000, -71.0000), 6),
        "gps_alt_m": round(random.uniform(2.0, 5.0), 1),
        "baro_hpa": round(random.uniform(1010.0, 1015.0), 2),
        "temp_c": round(random.uniform(-5.0, 0.0), 1),
        "batt_v": round(random.uniform(12.1, 12.6), 2),
        "batt_ma": round(random.uniform(800, 1200), 0)
    }

def log_event(trigger_type="AUTO"):
    """
    Writes a single line of telemetry to the CSV file.
    Call this immediately after a photo is taken.
    """
    file_exists = os.path.isfile(LOG_FILE)
    
    # Use UTC for standard scientific logging, or local time if preferred
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # Read the hardware
    data = get_sensor_data()
    
    row = [
        timestamp,
        trigger_type,
        data["gps_lat"],
        data["gps_lon"],
        data["gps_alt_m"],
        data["baro_hpa"],
        data["temp_c"],
        data["batt_v"],
        data["batt_ma"]
    ]
    
    try:
        with open(LOG_FILE, mode='a', newline='') as file:
            writer = csv.writer(file)
            # Write header if file is brand new
            if not file_exists:
                writer.writerow([
                    "Timestamp", "Trigger", "Latitude", "Longitude", 
                    "Altitude(m)", "Pressure(hPa)", "Temp(C)", "Battery(V)", "Current(mA)"
                ])
            writer.writerow(row)
        print(f"[TELEMETRY] Logged {trigger_type} event data.")
    except Exception as e:
        print(f"[TELEMETRY] Error writing to log: {e}")

# Quick test if run manually
if __name__ == "__main__":
    print("Testing Sensor Logger...")
    log_event("TEST_BOOT")
