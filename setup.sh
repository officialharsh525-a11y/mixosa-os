#!/usr/bin/env bash
set -Eeuo pipefail

if (( EUID != 0 )); then
  echo "Run this script with sudo or as root."
  exit 1
fi

log() { printf '[mixosa-setup] %s\n' "$*"; }
warn() { printf '[mixosa-setup] WARNING: %s\n' "$*" >&2; }

# Prefer the invoking desktop user. If the script is run directly as root,
# use the first regular local account when one exists.
TARGET_USER="${SUDO_USER:-}"
if [[ -z "$TARGET_USER" || "$TARGET_USER" == root ]]; then
  TARGET_USER="$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}' /etc/passwd || true)"
fi
TARGET_HOME=""
if [[ -n "$TARGET_USER" ]]; then
  TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
fi

export DEBIAN_FRONTEND=noninteractive
log "Refreshing Arch package databases."
pacman -Syu --noconfirm

log "Installing Mixosa runtime dependencies."
pacman -S --needed --noconfirm \
  base-devel git curl wget unzip flatpak mesa \
  linux-zen linux-zen-headers \
  wine winetricks samba \
  networkmanager kdeconnect

systemctl enable NetworkManager.service 2>/dev/null || true
systemctl enable smb.service 2>/dev/null || true
systemctl enable nmb.service 2>/dev/null || true

if [[ -n "$TARGET_USER" ]]; then
  log "Configuring Flatpak applications for $TARGET_USER."
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || warn "Could not add Flathub."
  runuser -u "$TARGET_USER" -- flatpak install --user --assumeyes flathub \
    com.usebottles.bottles org.localsend.localsend_app \
    || warn "Bottles or LocalSend could not be installed; rerun after networking is available."

  if ! runuser -u "$TARGET_USER" -- bash -lc 'command -v yay >/dev/null 2>&1'; then
    log "Building yay for $TARGET_USER."
    tmpdir="$(mktemp -d)"
    chown "$TARGET_USER":"$TARGET_USER" "$tmpdir"
    runuser -u "$TARGET_USER" -- git clone --depth=1 https://aur.archlinux.org/yay.git "$tmpdir/yay"
    runuser -u "$TARGET_USER" -- bash -lc "cd '$tmpdir/yay' && makepkg -si --noconfirm"
    rm -rf "$tmpdir"
  fi

  theme_dir="$TARGET_HOME/.local/share"
  runuser -u "$TARGET_USER" -- mkdir -p "$theme_dir"
  if [[ ! -d "$theme_dir/WhiteSur-gtk-theme" ]]; then
    runuser -u "$TARGET_USER" -- git clone --depth=1 \
      https://github.com/vinceliuice/WhiteSur-gtk-theme.git "$theme_dir/WhiteSur-gtk-theme"
    runuser -u "$TARGET_USER" -- bash -lc "cd '$theme_dir/WhiteSur-gtk-theme' && ./install.sh -c dark -s 2k" \
      || warn "WhiteSur GTK theme installation failed."
  fi
  if [[ ! -d "$theme_dir/WhiteSur-icon-theme" ]]; then
    runuser -u "$TARGET_USER" -- git clone --depth=1 \
      https://github.com/vinceliuice/WhiteSur-icon-theme.git "$theme_dir/WhiteSur-icon-theme"
    runuser -u "$TARGET_USER" -- bash -lc "cd '$theme_dir/WhiteSur-icon-theme' && ./install.sh" \
      || warn "WhiteSur icon theme installation failed."
  fi
else
  warn "No regular user was found. Skipping per-user yay, Flatpak, and theme setup."
fi

log "Mixosa setup completed. Log out and back in to apply desktop theme changes."
