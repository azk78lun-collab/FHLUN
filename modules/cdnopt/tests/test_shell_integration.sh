#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
SCRIPT="$ROOT/lun.sh"

bash -n "$SCRIPT"
[[ $(python3 -B "$ROOT/modules/cdnopt/lun_cdn_optimizer.py" --version) == 2.0.0 ]]
grep -q '3. 一键优选 CDN 节点（按需下载，浏览器实测）' "$SCRIPT"
grep -q 'cdnopt_download_agent ||' "$SCRIPT"
grep -q 'firewall_append_file tcp "$fw_root/cdnopt_port"' "$SCRIPT"
grep -q '^prompt_cdn_ips(){' "$SCRIPT"
grep -q 'save_cdn_ip_list "$cdnopt_ips"' "$SCRIPT"
grep -q -- '--current-file "$HOME/lun/cdnip"' "$SCRIPT"
grep -q -- '--test-port "${cdnpt:-443}"' "$SCRIPT"
grep -q -- '--server-place "$(cat "$HOME/lun/server_place" 2>/dev/null)"' "$SCRIPT"
grep -q '客户端线路与本机 VPS 分别测试、分别排行' "$SCRIPT"

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
