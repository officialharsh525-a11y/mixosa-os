#!/usr/bin/env bash

iso_name="mixosa"
iso_label="MIXOSA"
iso_publisher="Mixosa OS Project"
iso_application="Mixosa OS live environment"
iso_version="2026.08"
install_dir="mixosa"
arch="x86_64"

# UEFI systemd-boot is explicitly selected, and setup.sh creates the required
# efiboot/loader hierarchy before mkarchiso runs. Omitting BIOS here is
# intentional: it prevents mkarchiso from looking for an undeclared syslinux/
# directory and produces a clean UEFI image.
bootmodes=('uefi.systemd-boot')
buildmodes=('iso')

# Keep the live root filesystem compressed and favor a parallel compressor.
airootfs_image_type="squashfs"
airootfs_image_tool_options=(-comp zstd -Xcompression-level 15 -processors 0)

file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
)
