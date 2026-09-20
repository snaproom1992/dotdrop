#!/bin/bash
# シミュレータでアプリを起動して、画面を撮る。**Mac でしか動かない。**
#
#   ios/tools/shots.sh [出力先]
#
# UI テストは使わない。`-shot <名前>` を付けて起動すると、アプリ側
# （ScreenshotMode.swift・DEBUG のみ）がその画面を作って止まるので、
# あとは simctl で撮るだけでよい。指で操作する必要がない。
set -euo pipefail

OUT="${1:-shots}"
DEVICE="${SHOT_DEVICE:-iPhone 16 Pro Max}"   # 6.9インチ＝App Store で必須のサイズ
BUNDLE="com.snaproom.dotdrop"
PROJ="ios/DotDrop/DotDrop.xcodeproj"

mkdir -p "$OUT"
echo "▶ 使えるシミュレータ"
xcrun simctl list devices available | sed -n '/iOS/,$p' | head -20

UDID=$(xcrun simctl list devices available -j \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)['devices']
want = '''$DEVICE'''
for runtime, items in d.items():
    if 'iOS' not in runtime: continue
    for it in items:
        if it['name'] == want: print(it['udid']); raise SystemExit
# 見つからなければ、いちばん大きそうな iPhone で代用する
best = None
for runtime, items in d.items():
    if 'iOS' not in runtime: continue
    for it in items:
        if it['name'].startswith('iPhone'):
            if best is None or ('Max' in it['name'] and 'Max' not in best[0]):
                best = (it['name'], it['udid'])
if best: sys.stderr.write('※ %s が無いので %s で撮る\n' % (want, best[0])); print(best[1])
")
[ -n "$UDID" ] || { echo "シミュレータが見つからない"; exit 1; }
echo "▶ 端末 $UDID"

echo "▶ ビルド"
DERIVED=$(mktemp -d)
xcodebuild -project "$PROJ" -scheme DotDrop -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO build > /tmp/shots-build.log 2>&1 \
  || { tail -40 /tmp/shots-build.log; exit 1; }
APP=$(find "$DERIVED/Build/Products" -name 'DotDrop.app' -maxdepth 3 | head -1)
echo "▶ アプリ $APP"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
# 時刻表示などを固定して、撮るたびに差分が出ないようにする
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"

shoot () {   # shoot <名前> <待つ秒数>
  local name="$1" wait="${2:-2.5}"
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE" -shot "$name" > /dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$name.png" > /dev/null
  echo "  ✓ $OUT/$name.png"
}

echo "▶ 撮る"
shoot title  3.0    # 玉が落ちてくるアニメが終わるのを待つ
shoot play   2.0
shoot aim    2.0
shoot fever  2.0
shoot result 3.0    # カウントアップが終わるのを待つ
shoot records 3.0   # 板が出てベストスコアが回りきるのを待つ

echo "▶ 動画（自分で打ち続けるデモを録る）"
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE" -shot demo > /dev/null
sleep 1.5
xcrun simctl io "$UDID" recordVideo --codec h264 --force "$OUT/demo.mov" &
REC=$!
sleep "${SHOT_VIDEO_SECONDS:-28}"
kill -INT "$REC" 2>/dev/null || true
wait "$REC" 2>/dev/null || true
echo "  ✓ $OUT/demo.mov"

xcrun simctl shutdown "$UDID" 2>/dev/null || true
echo "▶ 完了：$OUT"
ls -la "$OUT"
