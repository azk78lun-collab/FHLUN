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
  cloudflare_manual_rule_file \
  cloudflare_manual_rule_matches \
  cdn_first_endpoint \
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

test_home=$(mktemp -d)
original_home=$HOME
HOME=$test_home
mkdir -p "$HOME/lun"
cdnym=proxy.example.com
printf '%s\n' 'proxy.example.com|3|8080|56567|test-uuid-vx' > "$HOME/lun/cdn_cloudflare_manual"
cloudflare_manual_rule_matches 3 8080 56567 test-uuid-vx
! cloudflare_manual_rule_matches 3 443 56567 test-uuid-vx
[[ $(cdn_first_endpoint '-1 108.162.198.211 162.159.38.68') == 108.162.198.211 ]]
HOME=$original_home
rm -rf "$test_home"

grep -q '输入协议代码（输入 0 返回）' "$SCRIPT"
grep -q '设备 ID（输入 0 返回）' "$SCRIPT"
grep -q '输入用户 ID（输入 0 返回）' "$SCRIPT"
grep -q '每月额度（只输入数字按 G 计算' "$SCRIPT"
grep -q '正在检查 Lun 更新，请稍候' "$SCRIPT"
grep -q '当前已是最新版' "$SCRIPT"
! grep -q 'update_lun_script; exit' "$SCRIPT"
grep -q '已自动使用 HTTP 继续安装' "$SCRIPT"
grep -q 'mu_ss_port=$(random_nat_port' "$SCRIPT"
! grep -q '输入 HTTP 才继续' "$SCRIPT"
grep -q '手动登记已设置的规则（无需 API' "$SCRIPT"
grep -q '粘贴 Token（输入会显示，0 返回）' "$SCRIPT"
grep -q '区域 → Origin Rules → 编辑' "$SCRIPT"
! grep -q '粘贴 Token（输入隐藏' "$SCRIPT"
grep -q '当前版本：V26.8.2.1' "$SCRIPT"
grep -q 'apk add --no-cache bash busybox-extras curl gcompat' "$SCRIPT"
grep -q 'apt install -y busybox coreutils curl util-linux' "$SCRIPT"
grep -q '7. %s网站访问监控%s' "$SCRIPT"
grep -q '8. %s使用说明 / 协议特点%s' "$SCRIPT"
grep -q '一键开启 / 修复监控' "$SCRIPT"
grep -q 'ExecStart=.* visit-serve' "$SCRIPT"
grep -q 'set-subscription-port --port' "$SCRIPT"
grep -q 'sync-subscription-state' "$SCRIPT"
grep -q 'show-local-subscription' "$SCRIPT"
grep -q 'token：按设备独立管理' "$SCRIPT"
grep -q 'multiuser_clear_legacy_subscription_autostart' "$SCRIPT"
! grep -q 'ps -ef 2>/dev/null | grep "$showsubport"' "$SCRIPT"
! grep -q '输入 ENABLE 确认启用' "$SCRIPT"
! grep -q '启用 / 修改保留时间' "$SCRIPT"
grep -q '今日智能活动（过滤并合并）' "$SCRIPT"
grep -q '今日原始连接明细' "$SCRIPT"
grep -q '这里记录的是代理连接，不是浏览器点击历史' "$SCRIPT"
grep -q 'visit-recent --days 1 --limit 100 --view smart --noise auto' "$SCRIPT"
grep -q 'visit-filter --mode standard' "$SCRIPT"
! grep -q '今日最近访问' "$SCRIPT"

extract_shell_function() {
  awk -v target="$1" '
    $0 ~ "^" target "\\(\\)\\{" { capture=1 }
    capture {
      print
      line=$0
      opens=gsub(/\{/, "{", line)
      closes=gsub(/\}/, "}", line)
      depth+=opens-closes
      if (started && depth==0) exit
      started=1
    }
  ' "$SCRIPT"
}

eval "$(extract_shell_function multiuser_prepare_service_port)"
multiuser_enabled() { return 0; }
multiuser_clear_legacy_subscription_autostart() { :; }
multiuser_config_value() { printf '443\n'; }
valid_port_value() { return 0; }
sleep() { :; }
yellow_line() { :; }
green_line() { :; }
red_line() { :; }
apply_lun_firewall_rules() { :; }

owned_busybox_stopped=no
stop_subscription_service() { owned_busybox_stopped=yes; }
port_in_use() { [[ $owned_busybox_stopped != yes ]]; }
multiuser_prepare_service_port

stop_subscription_service() { :; }
port_in_use() { return 0; }
select_subscription_port() { printf '12344\n'; }
client_port() { printf '51286\n'; }
is_nat_mode() { return 0; }
captured_port_update=
multiuser_cmd() { captured_port_update="$*"; }
multiuser_prepare_service_port
[[ $captured_port_update == "set-subscription-port --port 12344 --public-port 51286" ]]

select_subscription_port() { return 1; }
! multiuser_prepare_service_port

echo "multi-user shell helper tests passed"
