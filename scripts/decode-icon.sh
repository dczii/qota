#!/usr/bin/env bash
# Recreate AppIcon.png from the text sidecar when the binary is missing.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="${ROOT}/Qota/Assets.xcassets/AppIcon.appiconset"
PNG="${DIR}/AppIcon.png"
if [[ -f "${PNG}" ]]; then
  exit 0
fi

decode() {
  if base64 -D -o "${PNG}" 2>/dev/null; then
    return 0
  fi
  base64 -d > "${PNG}"
}

shopt -s nullglob
parts=( "${DIR}"/AppIcon.png.b64.[a-z][a-z] )
if [[ ${#parts[@]} -gt 0 ]]; then
  cat "${parts[@]}" | decode
  exit 0
fi
if [[ -f "${DIR}/AppIcon.png.b64" ]]; then
  decode < "${DIR}/AppIcon.png.b64"
fi
