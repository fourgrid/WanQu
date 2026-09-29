#!/bin/bash
# 玩趣 - 签名打包并安装到已连接的手机（USB 调试需已开启并授权）
# 前提：已在 DevEco Studio 中为本工程生成过自动签名（build-profile.json5 有 signingConfigs）
set -e

DEVECO="/Applications/DevEco-Studio.app/Contents"
HDC="$DEVECO/sdk/default/openharmony/toolchains/hdc"

"$HDC" kill >/dev/null 2>&1 || true
TARGETS=$("$HDC" list targets | grep -v "^\[Empty\]" | grep -v "^$" || true)
if [ -z "$TARGETS" ]; then
  echo "✗ 未检测到设备：请用 USB 连接手机并允许调试"
  exit 1
fi
echo "设备: $TARGETS"

bash "$(dirname "$0")/build.sh" "$@"

HAP="$(cd "$(dirname "$0")/.." && pwd)/entry/build/default/outputs/default"
SIGNED=$(ls "$HAP"/entry-default-signed.hap 2>/dev/null || true)
if [ -z "$SIGNED" ]; then
  echo "✗ 没有签名产物（entry-default-signed.hap）。请先在 DevEco 中完成自动签名。"
  exit 1
fi

echo "安装 $SIGNED ..."
"$HDC" install -r "$SIGNED"
echo "✔ 安装完成，桌面图标：玩趣"
