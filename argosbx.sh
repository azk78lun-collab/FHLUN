#!/bin/sh
set -eu

LUN_SCRIPT_URL="https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh"

echo "提示：argosbx.sh 已更名为 lun.sh，正在转到 Lun 主脚本..."

if command -v curl >/dev/null 2>&1; then
  exec sh -c "curl -Ls '$LUN_SCRIPT_URL' | sh -s -- \"\$@\"" sh "$@"
elif command -v wget >/dev/null 2>&1; then
  exec sh -c "wget -qO- '$LUN_SCRIPT_URL' | sh -s -- \"\$@\"" sh "$@"
else
  echo "未找到 curl 或 wget，无法下载 Lun 主脚本。"
  exit 1
fi
