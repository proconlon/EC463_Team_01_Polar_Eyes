#!/usr/bin/python3
import RPi.GPIO as GPIO
import sys

PIN = 17 # The BCM pin to read

try:
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    # Set up the pin as an input
    GPIO.setup(PIN, GPIO.IN) 
    
    # Read the value and print it to stdout
    value = GPIO.input(PIN)
    print(value)
    
except Exception as e:
    # If anything fails, print to stderr so the log can see it
    print(f"PYTHON_GPIO_ERROR: {e}", file=sys.stderr)
    sys.exit(1)

finally:
    # Always clean up the GPIO
    GPIO.cleanup()

sys.exit(0)