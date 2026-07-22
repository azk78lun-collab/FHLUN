#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
SCRIPT="$ROOT/lun.sh"

eval "$(sed -n '/^multiuser_quota_g(){/,/^}/p' "$SCRIPT")"

[[ $(multiuser_quota_g 6) == 6G ]]
[[ $(multiuser_quota_g 6.5) == 6.5G ]]
[[ $(multiuser_quota_g 500M) == 500M ]]
[[ $(multiuser_quota_g 2T) == 2T ]]
[[ $(multiuser_quota_g 0) == 0 ]]

grep -q '输入协议代码（输入 0 返回）' "$SCRIPT"
grep -q '设备 ID（输入 0 返回）' "$SCRIPT"
grep -q '输入用户 ID（输入 0 返回）' "$SCRIPT"
grep -q '每月额度（只输入数字按 G 计算' "$SCRIPT"

echo "multi-user shell helper tests passed"
