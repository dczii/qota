#!/usr/bin/env bash
# Recreate AppIcon.png from the text sidecar when the binary is missing.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PNG="${ROOT}/Qota/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
B64="${ROOT}/Qota/Assets.xcassets/AppIcon.appiconset/AppIcon.png.b64"
if [[ -f "${PNG}" ]]; then
  exit 0
fi
if [[ ! -f "${B64}" ]]; then
  exit 0
fi
if base64 -D -i "${B64}" -o "${PNG}" 2>/dev/null; then
  exit 0
fi
base64 -d "${B64}" > "${PNG}"
