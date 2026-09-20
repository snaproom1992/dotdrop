#!/bin/bash
# シミュレータでアプリを起動して、画面を撮る。**Mac でしか動かない。**
#
#   ios/tools/shots.sh [出力先]
#
# 出来上がりは 出力先/<インチ>/<言語>/<画面>.png
#   6.9 … 1320×2868（iPhone 16 Pro Max）。App Store でいま求められるサイズ
#   demo.mov は録画そのまま、preview.mp4 は App Store のプレビュー用（886×1920）
#   6.5 … 1284×2778（iPhone 14 Plus）。古い枠に入れたいとき用
# 動画は 6.9 だけ。プレビューは任意なので、2つ作っても使い道がない。
#
# 言語は起動引数で切り替える（シミュレータ自体の設定は触らない）。
#
# UI テストは使わない。`-shot <名前>` を付けて起動すると、アプリ側
# （ScreenshotMode.swift・DEBUG のみ）がその画面を作って止まるので、
# あとは simctl で撮るだけでよい。指で操作する必要がない。
set -euo pipefail

OUT="${1:-shots}"
BUNDLE="com.snaproom.dotdrop"
PROJ="ios/DotDrop/DotDrop.xcodeproj"
# 「インチ:シミュレータ名」を ; で並べる。先頭のものだけ動画も撮る
DEVICES="${SHOT_DEVICES:-6.9:iPhone 16 Pro Max;6.5:iPhone 14 Plus}"
LANGS="${SHOT_LANGS:-ja en}"
SCREENS="title play aim fever result records lessons split"

mkdir -p "$OUT"
echo "▶ 使えるシミュレータ"
xcrun simctl list devices available | sed -n '/iOS/,$p' | head -30

# 端末が無ければ作る。ランナーに置いてあるのは 16 系と SE だけなので、
# 6.5インチを撮るには自分で作る必要がある
make_device () {  # make_device <シミュレータ名>
  xcrun simctl list -j | python3 -c "
import sys, json
want = sys.argv[1]
d = json.load(sys.stdin)
dt = next((t['identifier'] for t in d['devicetypes'] if t['name'] == want), None)
rts = [r for r in d['runtimes'] if r.get('isAvailable') and 'iOS' in r['name']]
if not dt or not rts:
    sys.stderr.write('※ 「%s」は作れない\\n' % want); raise SystemExit(1)
rts.sort(key=lambda r: [int(x) for x in r['version'].split('.')])
print(dt); print(rts[-1]['identifier'])
" "$1" > /tmp/dt.txt || return 1
  xcrun simctl create "$1" "$(sed -n 1p /tmp/dt.txt)" "$(sed -n 2p /tmp/dt.txt)" > /dev/null
}

udid_of () {  # udid_of <シミュレータ名>
  xcrun simctl list devices available -j | python3 -c "
import sys, json
want = sys.argv[1]
for runtime, items in json.load(sys.stdin)['devices'].items():
    if 'iOS' not in runtime: continue
    for it in items:
        if it['name'] == want: print(it['udid']); raise SystemExit
" "$1"
}

locale_of () { case "$1" in en) echo en_US;; *) echo ja_JP;; esac; }

# ビルドは1回でよい（シミュレータ用の1つのバイナリを、どの端末にも入れられる）
FIRST_ENTRY="${DEVICES%%;*}"
FIRST_NAME="${FIRST_ENTRY#*:}"
FIRST_UDID=$(udid_of "$FIRST_NAME" || true)
[ -n "$FIRST_UDID" ] || { echo "「${FIRST_NAME}」が見つからない"; exit 1; }

echo "▶ ビルド"
DERIVED=$(mktemp -d)
xcodebuild -project "$PROJ" -scheme DotDrop -configuration Debug \
  -destination "id=$FIRST_UDID" -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO build > /tmp/shots-build.log 2>&1 \
  || { tail -40 /tmp/shots-build.log; exit 1; }
APP=$(find "$DERIVED/Build/Products" -name 'DotDrop.app' -maxdepth 3 | head -1)
echo "▶ アプリ $APP"

launch () {  # launch <udid> <言語> <-shot の名前>
  xcrun simctl terminate "$1" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$1" "$BUNDLE" \
    -AppleLanguages "($2)" -AppleLocale "$(locale_of "$2")" -shot "$3" > /dev/null
}

FIRST=1
# シミュレータ名に空白が入るので、区切りは ; にしてある
printf '%s\n' "$DEVICES" | tr ';' '\n' | while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  inch="${entry%%:*}"
  name="${entry#*:}"
  udid=$(udid_of "$name" || true)
  if [ -z "$udid" ]; then
    echo "  「${name}」が無いので作る"
    make_device "$name" || true
    udid=$(udid_of "$name" || true)
  fi
  if [ -z "$udid" ]; then echo "※ 「${name}」を用意できないので飛ばす"; continue; fi

  echo "▶ $inch インチ（${name}）"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b
  # 時刻などを固定して、撮るたびに差分が出ないようにする
  xcrun simctl status_bar "$udid" override --time "9:41" \
    --batteryState charged --batteryLevel 100 2>/dev/null || true
  xcrun simctl install "$udid" "$APP"

  for lang in $LANGS; do
    dir="$OUT/$inch/$lang"
    mkdir -p "$dir"
    for screen in $SCREENS; do
      # タイトルは玉が落ちきるのを、結果ときろくは数字が回りきるのを待つ
      case "$screen" in title|result|records) wait=3.0;; *) wait=2.0;; esac
      launch "$udid" "$lang" "$screen"
      sleep "$wait"
      xcrun simctl io "$udid" screenshot --type=png "$dir/$screen.png" > /dev/null
      echo "  ✓ $dir/$screen.png"
    done

    if [ "$FIRST" = 1 ]; then
      echo "▶ 動画（$inch / ${lang}）"
      launch "$udid" "$lang" demo
      sleep 1.5
      xcrun simctl io "$udid" recordVideo --codec h264 --force "$dir/demo.mov" &
      rec=$!
      sleep "${SHOT_VIDEO_SECONDS:-28}"
      kill -INT "$rec" 2>/dev/null || true
      wait "$rec" 2>/dev/null || true
      echo "  ✓ $dir/demo.mov"
      # App Store のプレビューは 886×1920 しか受け付けない。録画は端末そのままの
      # 大きさなので、ここで直しておく（そのままだと寸法違いで弾かれる）
      swift ios/tools/preview.swift "$dir/demo.mov" "$dir/preview.mp4" 886 1920 \
        || echo "  ※ プレビューへの変換に失敗（録画そのものは残っている）"
    fi
  done

  xcrun simctl shutdown "$udid" 2>/dev/null || true
  FIRST=0
done

echo "▶ 完了：$OUT"
find "$OUT" -type f | sort
