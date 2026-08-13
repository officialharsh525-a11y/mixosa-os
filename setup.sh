#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="${SCRIPT_DIR}/live_build"
OUTPUT_DIR="${SCRIPT_DIR}/out"
WORK_DIR="${SCRIPT_DIR}/work"
IMAGE_NAME="${MIXOSA_BUILDER_IMAGE:-mixosa-os-builder:latest}"

if [[ ! -f "${SCRIPT_DIR}/Dockerfile.archiso" ]]; then
  printf 'error: Dockerfile.archiso was not found in %s\n' "${SCRIPT_DIR}" >&2
  exit 1
fi

if [[ ! -f "${PROFILE_DIR}/profiledef.sh" || ! -f "${PROFILE_DIR}/packages.x86_64" ]]; then
  printf 'error: live_build is missing profiledef.sh or packages.x86_64\n' >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}" "${WORK_DIR}"

# The systemd-boot profile requires these files. Generate them idempotently so
# a clean checkout contains only the five requested source files.
mkdir -p "${PROFILE_DIR}/efiboot/loader/entries"
cat > "${PROFILE_DIR}/efiboot/loader/loader.conf" <<'EOF'
timeout 5
default mixosa-x86_64.conf
console-mode max
editor no
EOF

cat > "${PROFILE_DIR}/efiboot/loader/entries/mixosa-x86_64.conf" <<'EOF'
title   Mixosa OS (x86_64)
linux   /%INSTALL_DIR%/boot/x86_64/vmlinuz-linux
initrd  /%INSTALL_DIR%/boot/x86_64/amd_ucode.img
initrd  /%INSTALL_DIR%/boot/x86_64/intel_ucode.img
initrd  /%INSTALL_DIR%/boot/x86_64/archiso.img
options archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% copytoram=y
EOF

# Use a single absolute mount for the repository and explicit subdirectory
# mounts. This avoids duplicate or relative host paths in Docker.
docker run --rm --privileged \
  --volume "${SCRIPT_DIR}:/src:ro" \
  --volume "${OUTPUT_DIR}:/src/out" \
  --volume "${WORK_DIR}:/src/work" \
  --workdir /src \
  "${IMAGE_NAME}" \
  bash -Eeuo pipefail -c '
    rm -rf /src/work/*
    mkdir -p /src/out
    mkarchiso -v -w /src/work -o /src/out /src/live_build
  '

printf 'Mixosa OS ISO artifacts are available in %s\n' "${OUTPUT_DIR}"
