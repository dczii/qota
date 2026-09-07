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

if [[ -f "${DIR}/AppIcon.png.b64.aa" ]]; then
  cat "${DIR}/AppIcon.png.b64.aa" "${DIR}/AppIcon.png.b64.ab" "${DIR}/AppIcon.png.b64.ac" "${DIR}/AppIcon.png.b64.ad" | decode
  exit 0
fi
if [[ -f "${DIR}/AppIcon.png.b64" ]]; then
  decode < "${DIR}/AppIcon.png.b64"
fi
