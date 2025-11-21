#!/bin/bash

# NOTE: This script needs to be run as root with env variables set!
# sudo -E ./local_builder.sh

# This script should match the GitHub Actions in .github/workflows/build-pi4.yml
# This is for running locally but will do the same thing
# Ensure you update both the below IMAGE_URL and ZIP_FILE when updating the base image. 
# Update here and in the GHA file when there is a new release of raspios that you want to use.

set -e

# Set the environment variables the main script needs (using same name as GHA for convenience so we can share the script)
export GITHUB_WORKSPACE=$(readlink -f "$(dirname "$0")/../../")
export GITHUB_RUN_NUMBER="local-$(date +%s)"

# Base image (update as needed)
IMAGE_URL="https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz"
ZIP_FILE="$GITHUB_WORKSPACE/2025-10-01-raspios-trixie-arm64-lite.img.xz"
DECOMPRESSED_NAME="$GITHUB_WORKSPACE/2025-10-01-raspios-trixie-arm64-lite.img"

# do not change below, this is the expected name of the image that the other scripts will use.
# if you update the base image version, ensure you delete the old image named as $IMG_FILE first otherwise it will not re-download
PRISTINE_IMG_FILE="$GITHUB_WORKSPACE/base-raspios-lite-arm64.PRISTINE.img"
IMG_FILE="$GITHUB_WORKSPACE/base-raspios-lite-arm64.img" # working copy


echo "Checking dependencies..."
# some dependencies are in the build-pi-4-image.sh script, so check those here too.
for cmd in wget unxz qemu-arm-static kpartx rsync sudo losetup parted; do
  if ! command -v $cmd &> /dev/null; then
    echo "::error:: Command not found: $cmd"
    echo "Please install it and try again."
    exit 1
  fi
done
echo "Dependencies satisfied."

echo "Checking kernel modules..."
if ! lsmod | grep -q "^loop "; then
  echo "Loop module not loaded. Attempting to load..."
  sudo -E modprobe loop
  if ! lsmod | grep -q "^loop "; then
    echo "::error:: Failed to load 'loop' kernel module. Build cannot continue."
    exit 1
  fi
  echo "Loop module loaded successfully."
else
  echo "Loop module is already loaded."
fi

# Download the base image if not already present
if [ ! -f "$PRISTINE_IMG_FILE" ]; then
  echo "Pristine base image not found. Downloading to $ZIP_FILE..."
  # Use -O to specify the full output path
  wget -q --show-progress -O "$ZIP_FILE" "$IMAGE_URL"
  echo "Decompressing..."
  unxz "$ZIP_FILE"
  # Move the decompressed file to be our new "pristine" copy
  mv "$DECOMPRESSED_NAME" "$PRISTINE_IMG_FILE"
else
  echo "Pristine base image found at $PRISTINE_IMG_FILE. Skipping download."
fi

# Always create a fresh working copy from the pristine image
echo "Creating fresh working copy for the build..."
rm -f "$IMG_FILE"
cp "$PRISTINE_IMG_FILE" "$IMG_FILE"

echo "Expanding image file by 2GB..."
# 1. Append 2GB of zero-filled space to the image file
truncate -s +2G "$IMG_FILE"

# 2. Expand the second partition (rootfs) to fill the new space
# Note: 'parted' is generally safe for scripting partition tables
sudo parted -s "$IMG_FILE" resizepart 2 100%

# 3. Resize the filesystem to match the new partition size
# We must mount it as a loop device briefly to run resize2fs
echo "Resizing filesystem..."
LOOP_DEV=$(sudo losetup -P -f --show "$IMG_FILE")
# Force check is sometimes required before resize
sudo e2fsck -f -p "${LOOP_DEV}p2" || true 
sudo resize2fs "${LOOP_DEV}p2"
sudo losetup -d "$LOOP_DEV"
echo "Image expansion complete."

# run the build script
echo "Starting local build..."
chmod +x $GITHUB_WORKSPACE/storage_pi_four/build-scripts/build-pi4-image.sh
sudo -E $GITHUB_WORKSPACE/storage_pi_four/build-scripts/build-pi4-image.sh

# ensure the build output is owned by local user
echo "Build complete. Fixing file permissions..."
sudo -E chown -R $USER:$USER $GITHUB_WORKSPACE/build/
echo "Local build is in the 'build' folder. Done."