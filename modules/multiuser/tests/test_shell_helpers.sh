#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
SCRIPT="$ROOT/lun.sh"

eval "$(sed -n '/^multiuser_quota_g(){/,/^}/p' "$SCRIPT")"
for helper in \
  normalize_host \
  valid_port_value \
  valid_ipv4_value \
  valid_cdn_endpoint \
  clean_cdn_endpoint_token \
  normalize_cdn_ip_input \
  lun_version_is_older; do
  eval "$(sed -n "/^${helper}(){/,/^}/p" "$SCRIPT")"
done

[[ $(multiuser_quota_g 6) == 6G ]]
[[ $(multiuser_quota_g 6.5) == 6.5G ]]
[[ $(multiuser_quota_g 500M) == 500M ]]
[[ $(multiuser_quota_g 2T) == 2T ]]
[[ $(multiuser_quota_g 0) == 0 ]]

cdn_sample=$(cat <<'EOF'
**108.162.198.211:2083#JP 电信优选[64ms 160.85Mbps]**
162.159.38.68:443#JP 电信优选[66ms 168.07Mbps]
108.162.198.42:2096#JP 电信优选[67ms 159.52Mbps]
162.159.39.156:2083#JP 电信优选[68ms 163.97Mbps]
162.159.44.228:8443#JP 电信优选[69ms 164.93Mbps]
162.159.39.221:8443#JP 电信优选[69ms 205.15Mbps]
162.159.39.148:2096#JP 电信优选[83ms 153.88Mbps]
108.162.198.61:2083#JP 电信优选[85ms 161.34Mbps]
EOF
)
expected_cdn='108.162.198.211 162.159.38.68 108.162.198.42 162.159.39.156 162.159.44.228 162.159.39.221 162.159.39.148 108.162.198.61'
[[ $(normalize_cdn_ip_input "$cdn_sample") == "$expected_cdn" ]]
[[ $(normalize_cdn_ip_input '1.1.1.1 2.2.2.2') == '1.1.1.1 2.2.2.2' ]]
[[ $(normalize_cdn_ip_input '1.1.1.1:443#A 1.1.1.1:8443#B [2606:4700::1]:443 best.example.com:2053') == '1.1.1.1 2606:4700::1 best.example.com' ]]
[[ -z $(normalize_cdn_ip_input '999.1.1.1 160.85Mbps] JP') ]]
lun_version_is_older V26.7.29.1 V26.7.29.2
! lun_version_is_older V26.7.29.2 V26.7.29.2
! lun_version_is_older V26.7.30.1 V26.7.29.2

grep -q '输入协议代码（输入 0 返回）' "$SCRIPT"
grep -q '设备 ID（输入 0 返回）' "$SCRIPT"
grep -q '输入用户 ID（输入 0 返回）' "$SCRIPT"
grep -q '每月额度（只输入数字按 G 计算' "$SCRIPT"
grep -q '正在检查 Lun 更新，请稍候' "$SCRIPT"
grep -q '当前已是最新版' "$SCRIPT"
! grep -q 'update_lun_script; exit' "$SCRIPT"

echo "multi-user shell helper tests passed"
