#!/usr/bin/env bash

iso_name="mixosa"
iso_label="MIXOSA_$(date +%Y%m)"
iso_publisher="Mixosa OS"
iso_application="Mixosa OS Live/Install Media"
iso_version="$(date +%Y.%m.%d)"
install_dir="/arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-x64.systemd-boot.esp' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
workdir="work"
outdir="out"

# Keep the image reproducible and avoid embedding the Git checkout metadata.
file_permissions=(
  ["/root/mixosa-setup.sh"]="0:0:755"
)
