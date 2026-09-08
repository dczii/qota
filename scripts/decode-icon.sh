#!/usr/bin/env bash
# Recreate AppIcon.png when the binary is missing (GitHub clones).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="${ROOT}/Qota/Assets.xcassets/AppIcon.appiconset"
PNG="${DIR}/AppIcon.png"
if [[ -f "${PNG}" ]]; then
  exit 0
fi

if command -v python3 >/dev/null 2>&1 && [[ -f "${ROOT}/scripts/generate_icon.py" ]]; then
  if python3 "${ROOT}/scripts/generate_icon.py" && [[ -f "${PNG}" ]]; then
    exit 0
  fi
fi

if command -v xcrun >/dev/null 2>&1 && [[ -f "${ROOT}/scripts/generate-icon.swift" ]]; then
  if xcrun swift "${ROOT}/scripts/generate-icon.swift" "${PNG}" && [[ -f "${PNG}" ]]; then
    exit 0
  fi
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
  exit 0
fi

echo "Could not create ${PNG}. Need python3 + Pillow, or Xcode (swift)." >&2
exit 1
