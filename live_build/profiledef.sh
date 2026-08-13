#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="mixosa"
iso_label="MIXOSA_$(date +%Y%m)"
iso_publisher="Mixosa OS <https://github.com/your-org/mixosa-os>"
iso_application="Mixosa OS Live/Install Medium"
iso_version="$(date +%Y.%m.%d)"
install_dir="mixosa"
buildmodes=('iso')

# BIOS (syslinux) + UEFI (systemd-boot) boot support for x86_64.
bootmodes=(
    'bios.syslinux.mbr'
    'bios.syslinux.eltorito'
    'uefi-x64.systemd-boot.esp'
    'uefi-x64.systemd-boot.eltorito'
)

arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')

# Explicit ownership/permissions for security-sensitive paths in the
# generated airootfs. Anything not listed here keeps the permissions it
# had on disk when mkarchiso copied it in.
file_permissions=(
    ["/etc/shadow"]="0:0:0400"
    ["/etc/gshadow"]="0:0:0400"
    ["/root"]="0:0:0750"
    ["/root/.automated_script.sh"]="0:0:0755"
    ["/usr/local/bin/choose-mirror"]="0:0:0755"
    ["/usr/local/bin/livecd-sound"]="0:0:0755"
)
