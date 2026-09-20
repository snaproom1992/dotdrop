#!/bin/bash
# シミュレータでアプリを起動して、画面を撮る。**Mac でしか動かない。**
#
#   ios/tools/shots.sh [出力先]
#
# 日本語と英語の両方を撮る（SHOT_LANGS で変えられる）。言語は起動引数で
# 切り替えるので、シミュレータ自体の設定は触らない。
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

shoot () {   # shoot <言語> <名前> <待つ秒数>
  local lang="$1" name="$2" wait="${3:-2.5}"
  local dir="$OUT/$lang"
  mkdir -p "$dir"
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  # 端末の言語はアプリごとに起動引数で上書きできる（simctl の再起動が要らない）
  xcrun simctl launch "$UDID" "$BUNDLE" \
    -AppleLanguages "($lang)" -AppleLocale "$(locale_of "$lang")" -shot "$name" > /dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot --type=png "$dir/$name.png" > /dev/null
  echo "  ✓ $dir/$name.png"
}

locale_of () { case "$1" in en) echo en_US;; *) echo ja_JP;; esac; }

record () {  # record <言語>
  local lang="$1" dir="$OUT/$lang"
  mkdir -p "$dir"
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE" \
    -AppleLanguages "($lang)" -AppleLocale "$(locale_of "$lang")" -shot demo > /dev/null
  sleep 1.5
  xcrun simctl io "$UDID" recordVideo --codec h264 --force "$dir/demo.mov" &
  local rec=$!
  sleep "${SHOT_VIDEO_SECONDS:-28}"
  kill -INT "$rec" 2>/dev/null || true
  wait "$rec" 2>/dev/null || true
  echo "  ✓ $dir/demo.mov"
}

for LANG_CODE in ${SHOT_LANGS:-ja en}; do
  echo "▶ 撮る（${LANG_CODE}）"
  shoot "$LANG_CODE" title   3.0    # 玉が落ちてくるアニメが終わるのを待つ
  shoot "$LANG_CODE" play    2.0
  shoot "$LANG_CODE" aim     2.0
  shoot "$LANG_CODE" fever   2.0
  shoot "$LANG_CODE" result  3.0    # カウントアップが終わるのを待つ
  shoot "$LANG_CODE" records 3.0    # 板が出てベストスコアが回りきるのを待つ
  shoot "$LANG_CODE" lessons 2.0    # あそびかたの一覧（英語がいちばん伸びる画面）
  echo "▶ 動画（${LANG_CODE}）"
  record "$LANG_CODE"
done

xcrun simctl shutdown "$UDID" 2>/dev/null || true
echo "▶ 完了：$OUT"
find "$OUT" -type f | sort
