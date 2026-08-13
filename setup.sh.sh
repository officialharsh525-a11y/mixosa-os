#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="${IMAGE_NAME:-mixosa-archiso}"
OUTPUT_DIR="${PROJECT_DIR}/output"
WORK_DIR="${PROJECT_DIR}/.archiso-work"

mkdir -p "${OUTPUT_DIR}" "${WORK_DIR}"

printf '%s\n' '==> Building the Archiso Docker image'
docker build \
  --file "${PROJECT_DIR}/Dockerfile.archiso" \
  --tag "${IMAGE_NAME}" \
  "${PROJECT_DIR}"

printf '%s\n' '==> Building the Mixosa OS ISO'
docker run --rm \
  --privileged \
  --volume "${PROJECT_DIR}/live_build:/profile:ro" \
  --volume "${OUTPUT_DIR}:/output" \
  --volume "${WORK_DIR}:/work" \
  "${IMAGE_NAME}" \
  -v \
  -w /work \
  -o /output \
  /profile

printf '%s\n' '==> ISO build completed:'
find "${OUTPUT_DIR}" -maxdepth 1 -type f -name '*.iso' -print
