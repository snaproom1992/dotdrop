#!/usr/bin/env bash
# リポジトリ直下のゲーム本体を、アプリ同梱の www/ にコピーする。
# index.html を直したら、この脚本を走らせてから Xcode でビルドすること。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEST="$ROOT/ios/DotDrop/Resources/www"
mkdir -p "$DEST"
cp "$ROOT/index.html" "$ROOT/manifest.json" \
  "$ROOT/icon-180.png" "$ROOT/icon-192.png" "$ROOT/icon-512.png" "$ROOT/icon-1024.png" \
  "$ROOT/ogp.png" \
  "$DEST/"
echo "synced -> $DEST"
ls -la "$DEST"
