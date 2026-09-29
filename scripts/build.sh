#!/bin/bash
# 玩趣 - 命令行构建（不依赖 DevEco Studio GUI）
# 产物: entry/build/default/outputs/default/entry-default-unsigned.hap（未签名）
# 安装到设备前需在 DevEco Studio 中配置签名（File > Project Structure > Signing Configs）
set -e

DEVECO="/Applications/DevEco-Studio.app/Contents"
export PATH="$DEVECO/tools/node/bin:$PATH"
export DEVECO_SDK_HOME="$DEVECO/sdk"
export JAVA_HOME="$DEVECO/jbr/Contents/Home"
export HVIGOR_USER_HOME="$(cd "$(dirname "$0")/.." && pwd)/.hvigor-home"
export npm_config_cache="$HVIGOR_USER_HOME/npm-cache"

cd "$(dirname "$0")/.."
"$DEVECO/tools/hvigor/bin/hvigorw" --mode module -p product=default -p module=entry@default assembleHap --no-daemon "$@"

echo
echo "✔ 构建完成: entry/build/default/outputs/default/entry-default-unsigned.hap"
