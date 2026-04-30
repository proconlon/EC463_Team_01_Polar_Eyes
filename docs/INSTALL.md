# Polar Eyes — Installation Guide

End-to-end install for a freshly imaged Raspberry Pi 5 worker node. After this, `polar-listener.service` will boot the system and start capturing on every sentry trigger or timelapse interval.

---

## 0. Prerequisites

### Hardware

- **Raspberry Pi 5** (4 GB or 8 GB), 32 GB+ SD card, Pi OS Lite (64-bit, Trixie or newer)
- **Insta360 X5** (or compatible) camera, USB-C cable
- **Sentry Node** (Adafruit ItsyBitsy with sentry firmware flashed) wired to Pi 5 GPIO:
  - BCM 24 (Pin 18) → photo trigger (active high)
  - BCM 27 (Pin 13) → video trigger (high = record, low = stop)

### Pi-side accounts and OS state

The deployment script assumes a `polareyes` user already exists on the Pi:

```bash
sudo useradd -m -s /bin/bash polareyes
sudo usermod -aG video,gpio,plugdev,dialout polareyes
```

Required packages (Pi OS Lite is missing some of these by default):

```bash
sudo apt-get update
sudo apt-get install -y \
    python3 python3-pip \
    build-essential g++ make \
    pinctrl \
    rsync git
```

> **Note:** `pinctrl` ships with current Raspberry Pi OS; if `pinctrl` is missing, install `raspi-utils` or update the OS image.

---

## 1. Clone the repository

Clone into the `polareyes` user's home so the deployment paths line up cleanly:

```bash
sudo -u polareyes -i
cd ~
git clone https://github.com/BU-EC463/EC463_Team_01_Polar_Eyes.git
cd EC463_Team_01_Polar_Eyes
exit   # back to your normal user (e.g. dev / pi)
```

---

## 2. Build the C++ camera control binary

The Insta360 SDK is **not** committed to git (it's vendor-licensed). Download `CameraSDK-…-aarch64-none-linux-gnu.tar.gz` from your team Drive and extract it into `worker_pi_five/camera_sdk/`:

```bash
cd /home/polareyes/EC463_Team_01_Polar_Eyes/worker_pi_five/camera_sdk
tar -xzf /path/to/CameraSDK-*-aarch64-none-linux-gnu.tar.gz
ls   # should show: camera_control.cpp Makefile CameraSDK-…/ archive/
```

Build:

```bash
make
# produces: ./camera_control
```

Smoke-test (camera must be powered on and connected via USB):

```bash
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$(pwd)/CameraSDK-*/lib
./camera_control battery
```

---

## 3. Run the deployment script

`setup_pi_five.sh` lays the worker files out at the absolute deployment paths the scripts internally reference (e.g. `/home/polareyes/insta360_control/helper/photo.sh`), installs the systemd unit, and reloads systemd.

```bash
cd /home/polareyes/EC463_Team_01_Polar_Eyes
sudo ./worker_pi_five/setup_pi_five.sh
```

Expected output ends with:

```
[setup_pi_five] --- DEPLOYMENT COMPLETE ---
[setup_pi_five] Next steps:
[setup_pi_five]   1. Verify camera_control was built ...
[setup_pi_five]   2. Start the listener ...
[setup_pi_five]   3. Tail the logs ...
```

The script is **idempotent** — re-run it after every `git pull` to redeploy the latest code.

### What gets deployed where

| Source in repo                                 | Deployed path on Pi 5                              |
|------------------------------------------------|----------------------------------------------------|
| `worker_pi_five/src/polar_listener.py`         | `/home/polareyes/polar_listener.py`                |
| `worker_pi_five/src/sensor_logger.py`          | `/home/polareyes/sensor_logger.py`                 |
| `worker_pi_five/src/simple_timelapse.py`       | `/home/polareyes/simple_timelapse.py`              |
| `worker_pi_five/src/timelapse.py`              | `/home/polareyes/insta360_control/timelapse.py`    |
| `worker_pi_five/scripts/run_listener.sh`       | `/home/polareyes/run_listener.sh`                  |
| `worker_pi_five/scripts/gpio_reader.sh`        | `/home/polareyes/gpio_reader.sh`                   |
| `worker_pi_five/scripts/{photo,recordStart,recordStop,shutoff,copyStorage,run,usb_reset}.sh` | `/home/polareyes/insta360_control/helper/`         |
| `worker_pi_five/scripts/setup_camera_sdk.sh`   | `/home/polareyes/insta360_control/helper/setup.sh` |
| `worker_pi_five/camera_sdk/camera_control`     | `/home/polareyes/insta360_control/camera_control`  |
| `worker_pi_five/camera_sdk/CameraSDK-…/`       | `/home/polareyes/insta360_control/CameraSDK-…/`    |
| `worker_pi_five/config/polar-listener.service` | `/etc/systemd/system/polar-listener.service`       |

Runtime data (created on first run):

```text
/home/polareyes/insta360_control/storage/
├── photos/
├── videos/
└── telemetry.csv
/home/polareyes/polar_listener.log
```

---

## 4. Start the listener service

```bash
sudo systemctl start polar-listener.service
sudo systemctl status polar-listener.service
```

Tail the journal in real time:

```bash
journalctl -u polar-listener.service -f
```

You should see boot output like:

```
POLAR EYES - Pi Listener Service v4.0
✓ GPIO initialized (Triggers with pull-downs)
System initialized. Taking initial boot photo...
✓ Photo saved to /home/polareyes/insta360_control/storage/photos
System ready. Listening for triggers. Next auto-photo in 30 seconds...
```

The service is `Restart=always`, so it will auto-recover from a crash and re-launch at every boot (`systemctl enable` was already run by the setup script).

---

## 5. Verify

| Check | Command |
|---|---|
| Listener is running | `systemctl is-active polar-listener.service` |
| Photos are landing | `ls -lt /home/polareyes/insta360_control/storage/photos \| head` |
| Telemetry is logging | `tail /home/polareyes/insta360_control/storage/telemetry.csv` |
| Camera USB is healthy | `lsusb \| grep -i insta360` |
| GPIO pins responsive | `pinctrl get 24 27` |

Trigger a manual photo by pulling BCM 24 high (3.3 V) for ~100 ms. Trigger a video by holding BCM 27 high; release to stop.

---

## 6. Updating

After pulling new code:

```bash
cd /home/polareyes/EC463_Team_01_Polar_Eyes
git pull
# rebuild only if camera_control.cpp changed:
( cd worker_pi_five/camera_sdk && make )
sudo ./worker_pi_five/setup_pi_five.sh
sudo systemctl restart polar-listener.service
```

---

## Troubleshooting

### `polar-listener.service` keeps restarting
Tail the journal: `journalctl -u polar-listener.service -n 100 --no-pager`. Most common causes:
- `camera_control` not built or SDK missing → see step 2.
- USB camera not enumerated → `dmesg | tail` and check the cable / power.
- `pinctrl` not installed → `sudo apt-get install pinctrl`.

### Photos succeed but no telemetry CSV
Confirm `sensor_logger.py` was deployed alongside `polar_listener.py`:
```bash
ls /home/polareyes/sensor_logger.py /home/polareyes/polar_listener.py
```
Both must be in the same directory for `import sensor_logger` to resolve.

### "Failed to capture photo after 3 attempts"
The C++ wrapper retries 3× and then resets the USB stack. If still failing, manually power-cycle the camera and re-run the listener.

### Listener can't find scripts
Re-run the setup script — the absolute deployment paths inside `polar_listener.py` (e.g. `/home/polareyes/insta360_control/helper/photo.sh`) must match what the deployment installer placed on disk.

---

## Uninstall

```bash
sudo systemctl stop polar-listener.service
sudo systemctl disable polar-listener.service
sudo rm /etc/systemd/system/polar-listener.service
sudo systemctl daemon-reload
sudo rm -rf /home/polareyes/insta360_control
sudo rm /home/polareyes/{polar_listener.py,sensor_logger.py,simple_timelapse.py,run_listener.sh,gpio_reader.sh,bash_test.sh,bash2.sh}
```
