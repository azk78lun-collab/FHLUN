#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
SCRIPT="$ROOT/lun.sh"

bash -n "$SCRIPT"
[[ $(python3 -B "$ROOT/modules/cdnopt/lun_cdn_optimizer.py" --version) == 1.1.0 ]]
grep -q '3. 一键优选 CDN 节点（按需下载，浏览器实测）' "$SCRIPT"
grep -q 'cdnopt_download_agent ||' "$SCRIPT"
grep -q 'firewall_append_file tcp "$fw_root/cdnopt_port"' "$SCRIPT"
grep -q '^prompt_cdn_ips(){' "$SCRIPT"
grep -q 'save_cdn_ip_list "$cdnopt_ips"' "$SCRIPT"
grep -q '网页默认剔除延迟 >150 ms 或带宽 <80 Mbps' "$SCRIPT"

eval "$(sed -n '/^cdnopt_prompt_count(){/,/^}/p' "$SCRIPT")"
CDNOPT_TOP_COUNT=
cdnopt_prompt_count <<< "" >/dev/null
[[ $CDNOPT_TOP_COUNT == 5 ]]
CDNOPT_TOP_COUNT=
cdnopt_prompt_count <<< "12" >/dev/null
[[ $CDNOPT_TOP_COUNT == 12 ]]
set +e
cdnopt_prompt_count <<< "0" >/dev/null
rc=$?
set -e
[[ $rc == 2 ]]

echo "cdn optimizer shell integration tests passed"
