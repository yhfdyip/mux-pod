#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "=== MuxPod アイコン生成 ==="

# Step 1: SVG → PNG 変換（フォアグラウンド）
echo "[1/3] フォアグラウンドPNG生成..."
rsvg-convert -w 1024 -h 1024 \
  assets/icon/icon-foreground.svg \
  -o assets/icon/icon-foreground.png

# Step 2: フルアイコンPNG生成（背景付き）
echo "[2/3] フルアイコンPNG生成..."
rsvg-convert -w 1024 -h 1024 \
  docs/logo/logo.svg \
  -o assets/icon/icon.png

# Step 3: flutter_launcher_icons 実行
echo "[3/3] flutter_launcher_icons 実行..."
dart run flutter_launcher_icons

echo "=== 完了 ==="
