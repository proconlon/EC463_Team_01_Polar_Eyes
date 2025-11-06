#!/bin/bash

# Main build script shared by both GitHub Actions and local builds.
# expects $GITHUB_WORKSPACE and $GITHUB_RUN_NUMBER to be set
# this script should also be run as root

set -e

IMAGE_FILE="$GITHUB_WORKSPACE/base-raspios-lite-arm64.img"
BUILD_NUMBER="${GITHUB_RUN_NUMBER:-local}" # Use "local" if no run number

echo "--- [BUILD SCRIPT] Starting ---"
echo "Workspace: $GITHUB_WORKSPACE"
echo "Build: $BUILD_NUMBER"
echo "Image File: $IMAGE_FILE"

if [ ! -f "$IMAGE_FILE" ]; then
  echo "::error::Image file does not exist at $IMAGE_FILE"
  exit 1
fi

echo "Setting up loop device..."
LOOP_DEV=$(sudo losetup -f --show $IMAGE_FILE)
echo "Image attached to $LOOP_DEV"
sudo kpartx -av $LOOP_DEV

echo "Mounting filesystems..."
MOUNT_DIR="/mnt/raspi-root"
sudo mkdir -p $MOUNT_DIR

sleep 2
LOOP_NAME=$(basename $LOOP_DEV)
sudo mount /dev/mapper/${LOOP_NAME}p2 $MOUNT_DIR
sudo mkdir -p $MOUNT_DIR/boot/firmware
sudo mount /dev/mapper/${LOOP_NAME}p1 $MOUNT_DIR/boot/firmware

echo "Setting up chroot environment..."
sudo mount --bind /dev $MOUNT_DIR/dev
sudo mount --bind /dev/pts $MOUNT_DIR/dev/pts
sudo mount --bind /proc $MOUNT_DIR/proc
sudo mount --bind /sys $MOUNT_DIR/sys

echo "Copying project files..."
sudo cp /usr/bin/qemu-arm-static $MOUNT_DIR/usr/bin/
sudo rsync -av --exclude='base-raspios-lite-arm64.img' --exclude='base-raspios-lite-arm64.PRISTINE.img' --exclude='build/' --exclude='actions-runner/' --exclude='.git/' $GITHUB_WORKSPACE/ $MOUNT_DIR/opt/polar-eyes/

# Enable ssh. Username dev, ask James for login password
echo "Creating 'dev' user and enabling SSH..."
echo 'dev:$6$8QX8/V.NUD5DCbRS$pvJkm1aIFeOvbh4.7dB2wxxg08dQTBFm6KHJvdBTfZCS3P0i8K8jBfzNdDCjjvDLoFwRwoRwewGULYu469RbA1' | sudo tee $MOUNT_DIR/boot/firmware/userconf.txt > /dev/null
# set SSH enable file
sudo touch $MOUNT_DIR/boot/firmware/ssh
# also set default static ip
sudo sed -i '1 s/$/ ip=192.168.2.100/' $MOUNT_DIR/boot/firmware/cmdline.txt
# ssh dev@192.168.2.100 to access over ethernet

echo "Setting executable permission on setup script..."
SCRIPT_PATH="/opt/polar-eyes/storage_pi_four/setup_worker.sh"
sudo chmod +x $MOUNT_DIR/$SCRIPT_PATH

echo "Running setup script inside chroot..."
sudo chroot $MOUNT_DIR /bin/bash -c "$SCRIPT_PATH"

echo "Cleaning up..."
sudo umount $MOUNT_DIR/sys
sudo umount $MOUNT_DIR/proc
sudo umount $MOUNT_DIR/dev/pts
sudo umount $MOUNT_DIR/dev

sudo umount $MOUNT_DIR/boot/firmware
sudo umount $MOUNT_DIR

sudo kpartx -dv $LOOP_DEV
sudo losetup -d $LOOP_DEV

echo "Finalizing artifact..."
mkdir -p $GITHUB_WORKSPACE/build
mv $IMAGE_FILE $GITHUB_WORKSPACE/build/polar-eyes-worker-v${BUILD_NUMBER}.img

echo "--- [BUILD SCRIPT] Complete ---"
echo "Find your image at: $GITHUB_WORKSPACE/build/polar-eyes-worker-v${BUILD_NUMBER}.img"