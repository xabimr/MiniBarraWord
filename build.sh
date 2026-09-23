#!/bin/zsh
# Compila MiniBarra, monta el paquete .app, lo firma (ad hoc) y lo instala en ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP="build/MiniBarra.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MiniBarra "$APP/Contents/MacOS/MiniBarra"
cp Support/Info.plist "$APP/Contents/Info.plist"
[[ -f Support/AppIcon.icns ]] && cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier gal.xabierrolan.MiniBarra "$APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x MiniBarra 2>/dev/null || true
  mkdir -p ~/Applications
  rm -rf ~/Applications/MiniBarra.app
  cp -R "$APP" ~/Applications/
  echo "Instalada en ~/Applications/MiniBarra.app"
fi
