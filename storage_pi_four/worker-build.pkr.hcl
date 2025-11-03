// This file is the "recipe" for Packer to build our bootable SD card image.
// It tells Packer to:
// 1. Start with a specific, "frozen" RPi OS Lite image.
// 2. Copy our entire project repo into the image.
// 3. Run our 'setup_worker.sh' script inside the image to install/compile everything.
// 4. Save the result as a new .img file.

variable "build_version" {
  type    = string
  default = "1"
}

packer {
  required_plugins {
    arm = {
      version = ">= 1.1.0"
      source  = "github.com/mkaczanowski/packer-builder-arm/"
    }
  }
}

source "arm" "raspi-worker" {
  // 1. The base OS (which our GitHub Action must download)
  base_image_file   = "base-raspios-lite-arm64.img"
  image_output_path = "./build/polar-eyes-worker-v${var.build_version}.img"
  qemu_binary       = "/usr/bin/qemu-arm-static"
}

build {
  name    = "polar-eyes-worker"
  sources = ["source.arm.raspi-worker"]

  // 2. Copy our project code into the image
  provisioner "file" {
    source      = "../" // Copy the entire repo (parent dir)
    destination = "/opt/polar-eyes"
  }
  
  // 3. Run our setup script INSIDE the image
  provisioner "shell" {
    script = "/opt/polar-eyes/storage_pi_four/setup_worker.sh"
  }
}