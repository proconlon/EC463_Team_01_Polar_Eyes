James

The raspberry pi 4 is tentatively going to be for RAID only. The images will be passed here via ethernet from the Pi zero 2W.

The pi 4 will be on intermittently only (currently estimaging every 30min) until all images have been transferred and then shutdown clean.

Thus the build for the OS must be fast booting and shutdown as soon as possible.


# Building the Image


When run with Act locally, the built file is located at 

```sh
./build/polar-eyes-worker-v...img
```

Better way to build is using the local_builder.sh script

**Must specify -E to preserve env variables**

```sh
sudo -E storage_pi_four/build-scripts/local_builder.sh
```

# one time setup

* Commands for one time setup of the pi 4 after first boot
* Cover tailscale setup and RAID setup

```sh
sudo tailscale up
sudo /usr/local/bin/worker_triage.sh --setup-raid # ensure the polareyes.conf has the proper uuids for the drives
# when you first start the raid, you need to sync
# can watch status with
watch cat /proc/mdstat # this will take a very long time!!

sudo reboot
```

# Development Workflow

Don't rebuild the entire image for every code change. Currently, the build process just copies the entire repo into the image (fine for now).

Use the rsync command in storage_pi_four/build-scripts/build-pi4-image.sh to clone your changes over to the running Pi over ssh. (some big files are manually excluded)

```sh
sudo rsync -av --exclude='base-raspios-lite-arm64.img' --exclude='base-raspios-lite-arm64.PRISTINE.img' --exclude='build/' --exclude='actions-runner/' --exclude='.git/' $GITHUB_WORKSPACE/ $MOUNT_DIR/opt/polar-eyes/
```

*Eventually would like to change this to a git clone/pull and probably set a better rootfs structure to make it more obvious what files are copied into the image.*


# Format disks for RAID

### Step 1: Identify the Drives

1.  SSH into Pi
2.  Plug in *only* the drives you want to use for the RAID array.
3.  Run `lsblk` to list all block devices. Identify your two USB drives.

    ```bash
    dev@raspberrypi:~$ lsblk
    NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
    sda           8:0    0 119.2G  0 disk 
    └─sda1        8:1    0 119.2G  0 part 
    sdb           8:16   0 115.3G  0 disk 
    ├─sdb1        8:17   0   256M  0 part 
    ├─sdb2        8:18   0     1G  0 part 
    └─sdb3        8:19   0 114.1G  0 part 
    mmcblk0     179:0    0 119.1G  0 disk 
    ├─mmcblk0p1 179:1    0   256M  0 part /boot/firmware
    └─mmcblk0p2 179:2    0 118.8G  0 part /
    ```
    * In this example, our drives are clearly `/dev/sda` and `/dev/sdb`.
    * **Do not** select `/dev/mmcblk0`, which is your SD card (OS).

### Step 2: Wipe the Drives

Run the following commands one by one. This process is destructive and irreversible.

```bash
# Set a variable for the first drive to wipe
# !! TRIPLE-CHECK THIS NAME !!
DRIVE_TO_WIPE=/dev/sda

# --- Wipe First Drive ---
echo "Wiping $DRIVE_TO_WIPE..."
sudo umount ${DRIVE_TO_WIPE}* || true
sudo sgdisk --zap-all $DRIVE_TO_WIPE
sudo wipefs -a $DRIVE_TO_WIPE
sudo mdadm --zero-superblock $DRIVE_TO_WIPE
echo "--- $DRIVE_TO_WIPE wipe complete ---"


# Set a variable for the second drive to wipe
# !! TRIPLE-CHECK THIS NAME !!
DRIVE_TO_WIPE=/dev/sdb

# --- Wipe Second Drive ---
echo "Wiping $DRIVE_TO_WIPE..."
sudo umount ${DRIVE_TO_WIPE}* || true
sudo sgdisk --zap-all $DRIVE_TO_WIPE
sudo wipefs -a $DRIVE_TO_WIPE
sudo mdadm --zero-superblock $DRIVE_TO_WIPE
echo "--- $DRIVE_TO_WIPE wipe complete ---"
```

### Step 3: Verify

Run `lsblk` again. Your drives should now be "clean" and show no partitions:

```bash
dev@raspberrypi:~$ lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sda           8:0    0 119.2G  0 disk 
sdb           8:16   0 115.3G  0 disk 
mmcblk0     179:0    0 119.1G  0 disk 
├─mmcblk0p1 179:1    0   256M  0 part /boot/firmware
└─mmcblk0p2 179:2    0 118.8G  0 part /
```