#!/bin/bash

# Main build script shared by both GitHub Actions and local builds.
# expects $GITHUB_WORKSPACE and $GITHUB_RUN_NUMBER to be set
# this script should also be run as root

set -e

# --- [START NEW CODE] ---

MOUNT_DIR="/mnt/raspi-root"
LOOP_DEV="" # Will be set later

# Define a cleanup function.
# Robust against transient "target is busy" errors from chroot post-install
# scripts (mdadm, tailscale, update-initramfs, etc.) that leave file
# descriptors briefly open under /sys, /proc, /dev.
cleanup() {
    # Disable -e inside cleanup: a single failed umount must not abort the
    # rest of the teardown, or the loop device leaks and the runner fails
    # with a misleading exit code.
    set +e

    echo "--- [BUILD SCRIPT] Cleaning up ---"

    # Flush pending writes and give chroot-spawned helpers a moment to exit
    sync
    sleep 1

    # Try a clean unmount up to 3 times, then fall back to lazy unmount
    # (safe for the bind-mounted pseudo-filesystems and acceptable for the
    # rootfs/firmware partitions because we already sync'd).
    safe_umount() {
        local target="$1"
        if ! mountpoint -q "$target"; then return 0; fi
        local i
        for i in 1 2 3; do
            if sudo umount "$target" 2>/dev/null; then
                return 0
            fi
            sleep 1
        done
        echo "WARNING: $target still busy; falling back to lazy unmount"
        sudo umount -l "$target" 2>/dev/null || true
    }

    # Tear down inner binds first
    safe_umount "$MOUNT_DIR/sys"
    safe_umount "$MOUNT_DIR/proc"
    safe_umount "$MOUNT_DIR/dev/pts"
    safe_umount "$MOUNT_DIR/dev"

    # Then the real partitions on the loop device
    safe_umount "$MOUNT_DIR/boot/firmware"
    safe_umount "$MOUNT_DIR"

    # Detach loop device only if it was set
    if [ -n "$LOOP_DEV" ] && [ -b "$LOOP_DEV" ]; then
        echo "Detaching $LOOP_DEV..."
        sudo kpartx -dv "$LOOP_DEV" || true
        sudo losetup -d "$LOOP_DEV" || true
    fi
    echo "--- [BUILD SCRIPT] Cleanup complete ---"
    return 0
}

# Set the trap: This tells bash to run cleanup() on ANY exit
# (success, error, or interrupt)
trap cleanup EXIT


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
sudo mkdir -p "$MOUNT_DIR"

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

# also set default static ip (removed, letting dhcp handle it for now)
# sudo sed -i '1 s/$/ ip=192.168.2.100/' $MOUNT_DIR/boot/firmware/cmdline.txt
# ssh dev@192.168.2.100 to access over ethernet

echo "Setting executable permission on setup script..."
SCRIPT_PATH="/opt/polar-eyes/storage_pi_four/build-scripts/setup_worker.sh"
sudo chmod +x $MOUNT_DIR/$SCRIPT_PATH

echo "Running setup script inside chroot..."
sudo chroot $MOUNT_DIR /bin/bash -c "$SCRIPT_PATH"

# echo "Cleaning up..."
# sudo umount $MOUNT_DIR/sys
# sudo umount $MOUNT_DIR/proc
# sudo umount $MOUNT_DIR/dev/pts
# sudo umount $MOUNT_DIR/dev

# sudo umount $MOUNT_DIR/boot/firmware
# sudo umount $MOUNT_DIR

# sudo kpartx -dv $LOOP_DEV
# sudo losetup -d $LOOP_DEV

echo "Finalizing artifact..."
mkdir -p $GITHUB_WORKSPACE/build
mv $IMAGE_FILE $GITHUB_WORKSPACE/build/polar-eyes-worker-v${BUILD_NUMBER}.img

echo "--- [BUILD SCRIPT] Complete ---"
echo "Find your image at: $GITHUB_WORKSPACE/build/polar-eyes-worker-v${BUILD_NUMBER}.img"