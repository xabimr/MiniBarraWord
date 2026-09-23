#!/bin/zsh
# Compila MiniBarra (universal: Apple Silicon + Intel), monta el paquete .app y lo firma (ad hoc).
#   ./build.sh             solo compila en build/MiniBarra.app
#   ./build.sh --install   además la instala en ~/Applications
#   ./build.sh --dmg       además crea build/MiniBarra-<versión>.dmg para distribuirla
set -euo pipefail
cd "$(dirname "$0")"

ARCHS=(--arch arm64 --arch x86_64)
swift build -c release $ARCHS
BIN="$(swift build -c release $ARCHS --show-bin-path)/MiniBarra"

APP="build/MiniBarra.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MiniBarra"
cp Support/Info.plist "$APP/Contents/Info.plist"
[[ -f Support/AppIcon.icns ]] && cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier gal.xabierrolan.MiniBarra "$APP"

case "${1:-}" in
  --install)
    pkill -x MiniBarra 2>/dev/null || true
    mkdir -p ~/Applications
    rm -rf ~/Applications/MiniBarra.app
    cp -R "$APP" ~/Applications/
    echo "Instalada en ~/Applications/MiniBarra.app"
    ;;
  --dmg)
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Support/Info.plist)
    DMG="build/MiniBarra-$VERSION.dmg"
    STAGE=$(mktemp -d)
    cp -R "$APP" "$STAGE/"
    ln -s /Applications "$STAGE/Aplicaciones"
    cp Support/LEEME.txt "$STAGE/LEEME - Primera apertura.txt"
    rm -f "$DMG"
    hdiutil create -volname "MiniBarra" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
    rm -rf "$STAGE"
    echo "DMG creado: $DMG"
    ;;
esac
