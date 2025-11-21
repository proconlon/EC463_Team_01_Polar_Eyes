This is the folder for the Arduino nano which will be always on device.

This device will:

* Always remain powered on
* Power on the pi Zero via relay every 3 minutes to capture a picture
* Power on the Raspberry Pi 4 via GPIO every 30 minutes to transfer images over ethernet
* Monitor the 6 PIR and 2 mmWave radar sensors to detect motion events. When a motion event is detected, the GPIO headers will send a special signal to the Pi zero to start recording a video instead of the normal image.