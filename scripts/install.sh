#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${HOME}/Applications"
DERIVED="${ROOT}/.build/DerivedData"
APP="${DERIVED}/Build/Products/Release/Qota.app"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Install Xcode from the Mac App Store, then run:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

mkdir -p "${DEST}" "${DERIVED}"
bash "${ROOT}/scripts/decode-icon.sh"
echo "Building Qota (Release)…"
xcodebuild \
  -project "${ROOT}/Qota.xcodeproj" \
  -scheme Qota \
  -configuration Release \
  -derivedDataPath "${DERIVED}" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=NO

if [[ ! -d "${APP}" ]]; then
  echo "Build succeeded but Qota.app was not at:"
  echo "  ${APP}"
  exit 1
fi

rm -rf "${DEST}/Qota.app"
cp -R "${APP}" "${DEST}/Qota.app"
echo "Installed ${DEST}/Qota.app"
open "${DEST}/Qota.app"
