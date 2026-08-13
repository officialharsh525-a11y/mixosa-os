#!/usr/bin/env bash
#
# setup.sh - Master bootstrap script for Mixosa OS.
#
# Creates the live_build/ directory tree (if missing) and writes every file
# mkarchiso needs into its correct relative path. Safe to re-run: existing
# files it manages are overwritten, but it never deletes anything it didn't
# create.
#
# Intended to run INSIDE the mixosa-builder container (see
# Dockerfile.archiso), as root, with no 'sudo' required.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIVE_BUILD_DIR="${REPO_ROOT}/live_build"
RELENG_DIR="/usr/share/archiso/configs/releng"

echo "==> Mixosa OS build environment setup"
echo "==> Repo root:   ${REPO_ROOT}"
echo "==> live_build:  ${LIVE_BUILD_DIR}"

mkdir -p "${LIVE_BUILD_DIR}"

# ---------------------------------------------------------------------------
# 1. Boot-loader templates (syslinux for BIOS, efiboot for UEFI/systemd-boot)
#    mkarchiso needs these directories to exist with valid config files in
#    order to satisfy the bootmodes declared in profiledef.sh. Rather than
#    hand-maintain low-level syslinux/systemd-boot templates, seed them from
#    the archiso package's own reference "releng" profile, which ships
#    inside the archlinux archiso package installed by Dockerfile.archiso.
#    If live_build/syslinux or live_build/efiboot already exist (e.g. you
#    committed customized versions), they are left untouched.
# ---------------------------------------------------------------------------
if [ -d "${RELENG_DIR}" ]; then
    for dir in syslinux efiboot; do
        if [ -d "${RELENG_DIR}/${dir}" ] && [ ! -d "${LIVE_BUILD_DIR}/${dir}" ]; then
            echo "==> Seeding ${dir}/ from archiso releng reference profile"
            cp -r "${RELENG_DIR}/${dir}" "${LIVE_BUILD_DIR}/${dir}"
        fi
    done
else
    echo "WARNING: ${RELENG_DIR} not found." >&2
    echo "         This script expects to run inside the mixosa-builder" >&2
    echo "         image built from Dockerfile.archiso, where the 'archiso'" >&2
    echo "         package (and its releng reference configs) is installed." >&2
    echo "         Without syslinux/ and efiboot/, mkarchiso WILL fail." >&2
fi

# ---------------------------------------------------------------------------
# 2. airootfs overlay - files here get copied verbatim onto the live
#    filesystem. We use it to enable services by symlinking unit files,
#    since archiso no longer runs a chroot customization script by default.
# ---------------------------------------------------------------------------
mkdir -p "${LIVE_BUILD_DIR}/airootfs/etc/systemd/system/multi-user.target.wants"
mkdir -p "${LIVE_BUILD_DIR}/airootfs/etc/skel"
mkdir -p "${LIVE_BUILD_DIR}/airootfs/root"

echo "==> Enabling NetworkManager and sddm in the live image"
ln -sf /usr/lib/systemd/system/NetworkManager.service \
    "${LIVE_BUILD_DIR}/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/sddm.service \
    "${LIVE_BUILD_DIR}/airootfs/etc/systemd/system/display-manager.service"

# ---------------------------------------------------------------------------
# 3. pacman.conf - referenced by profiledef.sh's pacman_conf= setting.
#    Enables [multilib] since 'wine' needs 32-bit libraries.
# ---------------------------------------------------------------------------
cat > "${LIVE_BUILD_DIR}/pacman.conf" <<'PACMAN_CONF_EOF'
[options]
HoldPkg     = pacman glibc
Architecture = auto

CheckSpace
SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist
PACMAN_CONF_EOF

# ---------------------------------------------------------------------------
# 4. profiledef.sh
# ---------------------------------------------------------------------------
cat > "${LIVE_BUILD_DIR}/profiledef.sh" <<'PROFILEDEF_EOF'
#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="mixosa"
iso_label="MIXOSA_$(date +%Y%m)"
iso_publisher="Mixosa OS <https://github.com/your-org/mixosa-os>"
iso_application="Mixosa OS Live/Install Medium"
iso_version="$(date +%Y.%m.%d)"
install_dir="mixosa"
buildmodes=('iso')

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

file_permissions=(
    ["/etc/shadow"]="0:0:0400"
    ["/etc/gshadow"]="0:0:0400"
    ["/root"]="0:0:0750"
    ["/root/.automated_script.sh"]="0:0:0755"
    ["/usr/local/bin/choose-mirror"]="0:0:0755"
    ["/usr/local/bin/livecd-sound"]="0:0:0755"
)
PROFILEDEF_EOF
chmod 755 "${LIVE_BUILD_DIR}/profiledef.sh"

# ---------------------------------------------------------------------------
# 5. packages.x86_64
# ---------------------------------------------------------------------------
cat > "${LIVE_BUILD_DIR}/packages.x86_64" <<'PACKAGES_EOF'
# --- Base system ---
base
linux-zen
linux-zen-headers
linux-firmware
networkmanager

# --- Desktop environment (KDE Plasma) ---
plasma-desktop
sddm
dolphin
konsole

# --- Audio (PipeWire stack) ---
pipewire
pipewire-alsa
pipewire-pulse
wireplumber

# --- Theme & tools ---
whitesur-gtk-theme
wine
bottles
localsend
git
nano
sudo
PACKAGES_EOF

echo "==> live_build/ is ready:"
find "${LIVE_BUILD_DIR}" -maxdepth 1 -print

echo "==> Done. Run: mkarchiso -v -w work -o out live_build"
