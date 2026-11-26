#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
SCRIPT="$ROOT/lun.sh"

bash -n "$SCRIPT"
required=$(sed -n 's/^LUN_CDNOPT_REQUIRED_VERSION=//p' "$SCRIPT")
[[ -n "$required" && $(python3 -B "$ROOT/modules/cdnopt/lun_cdn_optimizer.py" --version) == "$required" ]]
grep -q '3. 一键优选 CDN 节点（按需下载，浏览器实测）' "$SCRIPT"
grep -q 'cdnopt_download_agent ||' "$SCRIPT"
grep -q 'firewall_append_file tcp "$fw_root/cdnopt_port"' "$SCRIPT"
grep -q '^prompt_cdn_ips(){' "$SCRIPT"
grep -q 'save_cdn_ip_list "$addresses"' "$SCRIPT"
grep -q -- '--status-file "$status"' "$SCRIPT"
grep -q -- '--current-file "$HOME/lun/cdnip"' "$SCRIPT"
grep -q -- '--test-port "${cdnpt:-443}"' "$SCRIPT"
grep -q -- '--server-place "$(cat "$HOME/lun/server_place" 2>/dev/null)"' "$SCRIPT"
grep -q '客户端线路与本机 VPS 分别测试、分别排行' "$SCRIPT"
grep -q '^cdnopt_reconcile_cluster_async$' "$SCRIPT"

eval "$(sed -n '/^cdnopt_public_host(){/,/^}/p' "$SCRIPT")"
yellow_line(){ printf '%s\n' "$*"; }
curl(){
  case "${*: -1}" in
    https://ipv4.icanhazip.com) printf '%s' "${ip4a:-}" ;;
    https://api.ipify.org) printf '%s' "${ip4b:-}" ;;
    https://ipv6.icanhazip.com) printf '%s' "${ip6a:-}" ;;
    https://api6.ipify.org) printf '%s' "${ip6b:-}" ;;
  esac
}
ip4a=8.8.8.8 ip4b=8.8.8.8
[[ $(cdnopt_public_host) == 8.8.8.8 ]]
ip4b=
[[ $(cdnopt_public_host 2>/dev/null) == 8.8.8.8 ]]
ip4b=1.1.1.1
! cdnopt_public_host >/dev/null 2>&1
ip4a=10.0.0.1 ip4b= ip6a=2606:4700:4700::1111 ip6b=2606:4700:4700::1111
[[ $(cdnopt_public_host) == 2606:4700:4700::1111 ]]
ip4a= ip4b= ip6a= ip6b=
! cdnopt_public_host >/dev/null 2>&1
unset -f curl yellow_line

eval "$(sed -n '/^cdnopt_preferred_host(){/,/^}/p' "$SCRIPT")"
saved_home=$HOME
tmp_home=$(mktemp -d)
HOME=$tmp_home
mkdir -p "$HOME/lun"
subscription_agent_enabled(){ return 0; }
multiuser_config_value(){ printf '%s\n' "${test_configured_host:-}"; }
is_ip_literal(){ [[ $1 == 8.8.8.8 ]]; }
valid_domain(){ [[ $1 == *.* ]]; }
cdnopt_domain_matches_ip(){ [[ $1 == "${matching_host:-}" && $2 == 8.8.8.8 ]]; }
test_configured_host=ddns.example.com matching_host=ddns.example.com
[[ $(cdnopt_preferred_host 8.8.8.8) == ddns.example.com ]]
printf '%s\n' service.example.com > "$HOME/lun/domain"
matching_host=service.example.com
[[ $(cdnopt_preferred_host 8.8.8.8) == service.example.com ]]
matching_host=wrong.example.com
[[ $(cdnopt_preferred_host 8.8.8.8) == 8.8.8.8 ]]
unset -f subscription_agent_enabled multiuser_config_value is_ip_literal valid_domain cdnopt_domain_matches_ip
HOME=$saved_home
rm -rf "$tmp_home"

eval "$(sed -n '/^cdnopt_reconcile_cluster_async(){/,/^}/p' "$SCRIPT")"
saved_home=$HOME
tmp_home=$(mktemp -d)
HOME=$tmp_home
mkdir -p "$HOME/lun"
cluster_enabled(){ return 0; }
cluster_cmd(){ printf '%s\n' "$*"; }
cdnopt_reconcile_cluster_async
wait "$!"
grep -qx 'endpoint-reconcile' "$HOME/lun/cdnopt-endpoint-sync.log"
rm -f "$HOME/lun/cdnopt-endpoint-sync.log"
cluster_enabled(){ return 1; }
cdnopt_reconcile_cluster_async
[[ ! -e $HOME/lun/cdnopt-endpoint-sync.log ]]
unset -f cluster_cmd cluster_enabled
HOME=$saved_home
rm -rf "$tmp_home"

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

(
  for fn in cdnopt_feedback_session cdnopt_apply_selection cdnopt_cleanup_session; do
    eval "$(sed -n "/^$fn(){/,/^}/p" "$SCRIPT")"
  done
  HOME=$(mktemp -d)
  trap 'rm -rf -- "$HOME"' EXIT
  mkdir -p "$HOME/lun/test-cdnopt"
  cdnopt_module_dir(){ printf '%s\n' "$HOME/lun/test-cdnopt"; }
  cdnopt_agent(){ printf '%s\n' fixture; }
  clear_cdn_ip_list(){ rm -f "$HOME/lun/cdnip" "$HOME/lun"/cdnip[0-9]*; }
  save_cdn_ip_list(){ printf '%s\n' "$1" > "$HOME/lun/cdnip"; [[ "$fixture_result" == success ]]; }
  apply_lun_firewall_rules(){ :; }
  green_line(){ :; }; red_line(){ :; }; yellow_line(){ :; }
  if [[ ${OSTYPE:-} == msys* ]]; then flock(){ :; }; fi
  cdnopt_internal=1234 cdnopt_public=1234 cdnopt_ip=8.8.8.8 cdnopt_host=8.8.8.8 cdnopt_top=1
  python3(){
    local selection receipt tries
    if [[ "$2" == extract ]]; then
      [[ "${*: -1}" != ips ]] || printf '8.8.8.8\n'
      return 0
    fi
    while (( $# > 1 )); do
      case "$1" in --result-file) selection=$2 ;; --status-file) receipt=$2 ;; esac
      shift
    done
    [[ "$fixture_result" != cancelled ]] || return 2
    printf '{}\n' > "$selection"
    for tries in {1..40}; do
      if [[ -s "$receipt" ]]; then cat "$receipt" > "$HOME/feedback.json"; return 0; fi
      sleep .1
    done
    return 1
  }
  printf '1.1.1.1\n' > "$HOME/lun/cdnip"
  fixture_result=failure
  if cdnopt_feedback_session; then exit 1; fi
  grep -Fq '"state":"failure"' "$HOME/feedback.json"
  [[ $(cat "$HOME/lun/cdnip") == 1.1.1.1 ]]
  fixture_result=success
  cdnopt_feedback_session
  grep -Fq '"state":"success"' "$HOME/feedback.json"
  [[ $(cat "$HOME/lun/cdnip") == 8.8.8.8 ]]
  fixture_result=cancelled
  rc=0; cdnopt_feedback_session || rc=$?
  [[ $rc == 2 && ! -e "$HOME/lun/cdnopt_port" ]]
  [[ -z $(find "$(cdnopt_module_dir)" -name 'session.*' -print) ]]
)

echo "cdn optimizer shell integration tests passed"
