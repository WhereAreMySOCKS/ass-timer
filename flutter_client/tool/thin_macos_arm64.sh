#!/bin/zsh
set -euo pipefail

app_path="${1:?usage: thin_macos_arm64.sh /path/to/App.app}"

while IFS= read -r candidate; do
  if file "$candidate" | grep -q "universal binary"; then
    temporary="$candidate.arm64-thin"
    lipo "$candidate" -thin arm64 -output "$temporary"
    permissions=$(stat -f '%Lp' "$candidate")
    chmod "$permissions" "$temporary"
    mv "$temporary" "$candidate"
  fi
done < <(find "$app_path" -type f)

codesign --force --deep --sign - "$app_path"
