#!/bin/zsh
set -euo pipefail

cd "${0:A:h}/.."

flutter pub get
flutter analyze
flutter test
flutter build macos --release

app_path="build/macos/Build/Products/Release/该提肛了.app"
release_dir="releases"
"$PWD/tool/thin_macos_arm64.sh" "$app_path"
mkdir -p "$release_dir"
rm -f "$release_dir/Ass-Timer.dmg"
xattr -cr "$app_path"
hdiutil create \
  -volname "Ass-Timer" \
  -srcfolder "$app_path" \
  -ov \
  -format UDZO \
  "$release_dir/Ass-Timer.dmg"
shasum -a 256 "$release_dir/Ass-Timer.dmg" > "$release_dir/Ass-Timer.dmg.sha256"
