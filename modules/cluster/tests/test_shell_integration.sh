#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
SCRIPT="$ROOT/lun.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
contains() { grep -Fq -- "$2" "$1" || fail "missing: $2"; }
section() {
  awk -v name="$2" '$0 == name "(){" { show=1 } show { print } show && $0 == "}" { exit }' "$1"
}

bash -n "$SCRIPT"
contains "$SCRIPT" '当前版本：V26.11.19.2'
contains "$SCRIPT" '自动巡检：每天一次'
contains "$SCRIPT" '"suspect": "疑似离线"'
contains "$SCRIPT" 'cluster_cmd endpoint-reconcile'
contains "$SCRIPT" '分布式服务器集群'
contains "$SCRIPT" 'subscription_agent_enabled(){'
contains "$SCRIPT" 'subscription_only_enabled(){'
contains "$SCRIPT" 'cluster_existing_internal=$(cluster_config_value internal_port'
contains "$SCRIPT" '[ "$cluster_reuse_existing" != yes ]'

(
  for fn in lun_has_systemd cluster_service_is_active cluster_maintenance_repair; do
    eval "$(section "$SCRIPT" "$fn")"
  done
  manager=yes runtime=yes
  command(){
    if [[ "$*" == '-v systemctl' ]]; then [[ "$manager" == yes ]]; else builtin command "$@"; fi
  }
  test(){
    if [[ "$*" == '-d /run/systemd/system' ]]; then [[ "$runtime" == yes ]]; else builtin test "$@"; fi
  }
  systemctl(){ [[ "$*" == 'is-active --quiet lun-agent' ]]; }
  rc-service(){ [[ "$*" == 'lun-agent status' ]]; }
  pidof(){ return 1; } # Missing/false-negative pidof must not hide a real manager.
  lun_has_systemd || fail 'active systemd not detected without pidof'
  cluster_service_is_active lun-agent not-openrc
  runtime=no
  if lun_has_systemd; then fail 'accepted systemctl without a running systemd'; fi
  cluster_service_is_active not-systemd lun-agent
  manager=no runtime=yes
  if lun_has_systemd; then fail 'accepted systemd marker without systemctl'; fi

  healthy=yes action=
  cluster_service_is_active(){ [[ "$healthy" == yes ]]; }
  subscription_agent_ready(){ return 0; }
  cluster_service_start(){ action+=start; }
  restart_subscription_service(){ action+=subscription; }
  apply_lun_firewall_rules(){ action+=firewall; }
  cluster_cmd(){ action+="$1"; }
  cluster_maintenance_repair
  [[ "$action" == endpoint-reconcilefirewallstatus ]] || fail 'healthy services were unnecessarily restarted'
  action= healthy=no
  cluster_maintenance_repair
  [[ "$action" == startsubscriptionendpoint-reconcilefirewallstatus ]] || fail 'stopped service was not repaired'
)

(
  # No system service or internet involved: substitute a local module and verify
  # the old-runtime and startup-failure paths on the actual shell updater.
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  export HOME="$tmp/home"
  LUN_CLUSTER_REQUIRED_VERSION=$(sed -n 's/^LUN_CLUSTER_REQUIRED_VERSION=//p' "$SCRIPT")
  [[ $(sed -n 's/^VERSION = "\([0-9.]*\)"$/\1/p' "$ROOT/modules/cluster/lun_cluster.py") == "$LUN_CLUSTER_REQUIRED_VERSION" ]]
  for fn in cluster_module_dir cluster_agent_version cluster_agent_version_current \
    lun_version_is_older cluster_download_agent cluster_wait_for_running_agent cluster_upgrade_local_agent; do
    eval "$(section "$SCRIPT" "$fn")"
  done
  mkdir -p "$(cluster_module_dir)"
  target="$(cluster_module_dir)/lun_cluster.py"
  LUN_CLUSTER_AGENT_SOURCE="$tmp/candidate.py"
  state="$tmp/restarts"
  enabled=yes running=yes ready=yes
  fixture(){ printf '#!/usr/bin/env python3\nVERSION = "%s"\n' "$2" > "$1"; }
  cluster_enabled(){ [ "$enabled" = yes ]; }
  cluster_is_federation(){ return 0; }
  lun_python_ensure(){ return 0; }
  cluster_runtime_command(){
    if [ "$1" = is-active ]; then [ "$running" = yes ]; else cluster_agent_version "$target" >> "$state"; fi
  }
  cluster_cmd(){ [ "$1" = service-current ] && [ "$ready" = yes ]; }
  sleep(){ :; }
  red_line(){ printf '%s\n' "$*"; }
  yellow_line(){ :; }
  green_line(){ :; }

  fixture "$target" 0.3.5
  fixture "$LUN_CLUSTER_AGENT_SOURCE" 0.3.7
  if cluster_upgrade_local_agent; then fail 'stale download accepted'; fi
  [[ $(cluster_agent_version "$target") == 0.3.5 && ! -e "$state" ]]
  fixture "$LUN_CLUSTER_AGENT_SOURCE" "$LUN_CLUSTER_REQUIRED_VERSION"
  ready=no
  if cluster_upgrade_local_agent; then fail 'reported success without running new build'; fi
  [[ $(cluster_agent_version "$target") == 0.3.5 ]]
  [[ $(cat "$state") == "$LUN_CLUSTER_REQUIRED_VERSION"$'\n0.3.5' ]]
  : > "$state"
  ready=yes
  cluster_upgrade_local_agent
  [[ $(cluster_agent_version "$target") == "$LUN_CLUSTER_REQUIRED_VERSION" ]]
  [[ $(cat "$state") == "$LUN_CLUSTER_REQUIRED_VERSION" ]]
  cluster_upgrade_local_agent
  [[ $(cat "$state") == "$LUN_CLUSTER_REQUIRED_VERSION" ]]

  fixture "$target" 0.3.5
  : > "$state"
  enabled=no
  cluster_upgrade_local_agent
  [[ $(cluster_agent_version "$target") == 0.3.5 && ! -s "$state" ]]
  enabled=yes running=no
  cluster_upgrade_local_agent
  [[ $(cluster_agent_version "$target") == "$LUN_CLUSTER_REQUIRED_VERSION" && ! -s "$state" ]]
  [[ -z $(find "$(cluster_module_dir)" -type d -name '.upgrade.*' -print) ]]
)

MENU=$(section "$SCRIPT" cluster_federation_menu)
printf '%s\n' "$MENU" | grep -Fq '添加服务器' || fail 'federation menu missing add server entry'
printf '%s\n' "$MENU" | grep -Fq '刷新并查看聚合订阅' || fail 'federation menu missing aggregate refresh'
printf '%s\n' "$MENU" | grep -Fq 'cluster_maintenance_ui' || fail 'federation menu missing maintenance entry'
MAINTENANCE=$(section "$SCRIPT" cluster_maintenance_ui)
printf '%s\n' "$MAINTENANCE" | grep -Fq '一键更新所有 VPS 代理脚本' || fail 'update label is unclear'
printf '%s\n' "$MAINTENANCE" | grep -Fq 'cluster_cdn_sync_ui' || fail 'CDN sync is not in maintenance'
ADD_SERVER=$(section "$SCRIPT" cluster_add_server_ui)
printf '%s\n' "$ADD_SERVER" | grep -Fq 'federation-join-code' || fail 'join address creation is inaccessible'
if printf '%s\n' "$MENU" | grep -Eq '角色互换|switch-master'; then
  fail 'federation menu still exposes legacy roles'
fi
if grep -Fq '主 VPS' "$SCRIPT" || grep -Fq '子 VPS' "$SCRIPT" || grep -Fq '服务器联动程序' "$SCRIPT"; then
  fail 'legacy role wording remains user-visible in lun.sh'
fi

TRUST=$(section "$SCRIPT" cluster_node_allowed)
printf '%s\n' "$TRUST" | grep -Fq 'row.get("trusted") is not True' || fail 'target trust is not sourced from backend trusted=true'
if printf '%s\n' "$TRUST" | grep -Eq 'row.get\("role"\)|legacy-unverified'; then
  fail 'target trust still inferred from role/state'
fi
TRUSTED=$(section "$SCRIPT" cluster_trusted_member_ids)
printf '%s\n' "$TRUSTED" | grep -Fq 'row.get("trusted") is not True' || fail 'trusted member list ignores backend trusted flag'
SHOW_NODES=$(section "$SCRIPT" cluster_show_nodes)
printf '%s\n' "$SHOW_NODES" | grep -Fq 'row.get("trusted") is not True' || fail 'display state does not expose untrusted backend records'
printf '%s\n' "$SHOW_NODES" | grep -Fq 'row.get("display_place")' || fail 'menu ignores localized region'
UNTRUSTED=$(section "$SCRIPT" cluster_untrusted_member_numbers)
printf '%s\n' "$UNTRUSTED" | grep -Fq 'row.get("trusted") is not True' || fail 'automatic update exclusion ignores backend trusted flag'

(
  eval "$(section "$SCRIPT" cluster_sync_ui)"
  cluster_trusted_member_ids() { printf '%s\n' 03 10; }
  cluster_node_allowed() { [[ $1 == 10 ]]; }
  cluster_refresh_profiles_async() { printf '%s\n' 'refresh'; }
  yellow_line() { printf '%s\n' "$*"; }
  red_line() { printf '%s\n' "$*"; }
  cluster_cmd() { printf 'CMD %s\n' "$*"; [[ $1 != "${FAIL_COMMAND:-}" ]]; }
  all=$(cluster_sync_ui <<< "")
  [[ $all == "$(cluster_sync_ui <<< all)" ]] || fail 'Enter does not match all'
  [[ $all == *'CMD sync --node-id 03'* && $all == *'CMD sync --node-id 10'* ]] || fail 'Enter did not sync all peers'
  selected=$(cluster_sync_ui <<< 10)
  [[ $selected == *'CMD sync-users --node-id 10'* && $selected != *'--node-id 03'* ]] || fail 'single node sync changed'
  cancelled=$(cluster_sync_ui <<< 0)
  [[ $cancelled != *'CMD '* ]] || fail 'cancel still performs sync'
  if partial=$(FAIL_COMMAND=sync-users cluster_sync_ui <<< ""); then fail 'user sync failure reported as success'; fi
  [[ $partial == *'CMD sync --node-id 10'* && $partial == *'用户配置同步未完成'* ]] || fail 'partial sync wrongly stops snapshots or hides user failure'
)

PUSH=$(section "$SCRIPT" cluster_push_event)
printf '%s\n' "$PUSH" | grep -Fq 'cluster_cmd push' || fail 'rebuild publication missing push'
printf '%s\n' "$PUSH" | grep -Fq ') >/dev/null 2>&1 &' || fail 'snapshot publication blocks caller'
contains "$SCRIPT" 'cluster_push_event'
REFRESH_OUTPUTS=$(section "$SCRIPT" refresh_subscription_outputs)
printf '%s\n' "$REFRESH_OUTPUTS" | grep -Fq 'cip || return 1' || fail 'subscription refresh does not rebuild local outputs first'
printf '%s\n' "$REFRESH_OUTPUTS" | grep -Fq 'cluster_push_event' || fail 'subscription refresh does not publish the rebuilt snapshot'

JOIN=$(section "$SCRIPT" cluster_join_ui)
printf '%s\n' "$JOIN" | grep -Fq 'cluster_cmd --json add-peer' || fail 'one-paste join does not capture the new member identity'
printf '%s\n' "$JOIN" | grep -Fq 'finalize-peer --node-id' || fail 'one-paste join does not finalize federation propagation'
printf '%s\n' "$JOIN" | grep -Fq '无需其它操作' || fail 'one-paste join completion is unclear'

CDN=$(section "$SCRIPT" cluster_cdn_payload)
printf '%s\n' "$CDN" | grep -Fq '"mode"' || fail 'CDN payload missing mode'
printf '%s\n' "$CDN" | grep -Fq '"cfip"' || fail 'CDN payload missing cfip'
if printf '%s\n' "$CDN" | grep -Eiq '"(cdnym|cert|token|origin|tunnel|port)"'; then
  fail 'CDN payload includes forbidden configuration'
fi
CDN_UI=$(section "$SCRIPT" cluster_cdn_sync_ui)
printf '%s\n' "$CDN_UI" | grep -Fq 'cdn-pool-preview' || fail 'CDN preview contract missing'
printf '%s\n' "$CDN_UI" | grep -Fq 'cdn-pool-sync' || fail 'CDN sync contract missing'
printf '%s\n' "$CDN_UI" | grep -Fq 'for cluster_id in' || fail 'CDN targets are not processed individually'
printf '%s\n' "$CDN_UI" | grep -Fq '回车确认同步此成员' || fail 'CDN target confirmation is not per-member'
if printf '%s\n' "$CDN_UI" | grep -Fq '尚未提供'; then
  fail 'CDN UI still has a temporary unsupported branch'
fi

BACKUP=$(section "$SCRIPT" cluster_backup_ui)
printf '%s\n' "$BACKUP" | grep -Fq 'federation-backup' || fail 'federation backup command missing'
printf '%s\n' "$BACKUP" | grep -Fq 'federation-restore' || fail 'federation restore command missing'
printf '%s\n' "$BACKUP" | grep -Fq 'identity-backup' || fail 'identity backup command missing'
printf '%s\n' "$BACKUP" | grep -Fq 'identity-restore' || fail 'identity restore command missing'
if printf '%s\n' "$BACKUP" | grep -Fq '尚未提供 identity-restore'; then
  fail 'identity restore still has a temporary unsupported branch'
fi

contains "$SCRIPT" 'cluster_refresh_profiles_async'
SUBSCRIPTION=$(section "$SCRIPT" cluster_show_subscription_links)
printf '%s\n' "$SUBSCRIPTION" | grep -Fq 'cluster_refresh_profiles_async' || fail 'aggregate view does not refresh asynchronously'
if printf '%s\n' "$SUBSCRIPTION" | grep -Fq 'cluster_refresh_profiles >/dev/null'; then
  fail 'aggregate view waits for synchronous refresh'
fi
contains "$SCRIPT" 'data.get("internal_port")'
contains "$SCRIPT" '待重新配对/未信任'

TAKEOVER=$(section "$SCRIPT" cluster_subscription_takeover_start)
printf '%s\n' "$TAKEOVER" | grep -Fq 'subscription_agent_init_single_user' || fail 'cluster install does not initialize subscription-only agent'
printf '%s\n' "$TAKEOVER" | grep -Fq 'multiuser_clear_legacy_subscription_autostart' || fail 'BusyBox autostart is not cleared during takeover'
printf '%s\n' "$TAKEOVER" | grep -Fq 'subscription_agent_ready' || fail 'subscription-only listener is not verified'
contains "$SCRIPT" 'set -- init-subscription-only --legacy-uuid "$sa_uuid" --legacy-token "$sa_token"'
contains "$SCRIPT" '--port "$sa_port" --public-port "$sa_public_port"'

RESTART=$(section "$SCRIPT" restart_subscription_service)
printf '%s\n' "$RESTART" | grep -Fq 'if multiuser_enabled' || fail 'real multiuser reconcile path missing'
printf '%s\n' "$RESTART" | grep -Fq 'if cluster_enabled' || fail 'cluster subscription-only path missing'
contains "$SCRIPT" 'cluster_subscription_agent_ensure || {'
contains "$SCRIPT" 'restart_subscription_busybox'

contains "$SCRIPT" 'cluster_subscription_state_snapshot(){'
contains "$SCRIPT" 'cluster_subscription_state_restore(){'
contains "$SCRIPT" 'cluster_install_rollback(){'
contains "$SCRIPT" 'lun-agent 未能接管单用户订阅，联邦不会以半启用状态保留。'
RELEASE=$(section "$SCRIPT" cluster_subscription_takeover_release)
printf '%s\n' "$RELEASE" | grep -Fq 'multiuser_enabled && return 0' || fail 'cluster disable would disturb real multiuser'
printf '%s\n' "$RELEASE" | grep -Fq 'restart_subscription_busybox' || fail 'cluster disable does not restore single-user BusyBox'

SYNC_STATE=$(section "$SCRIPT" multiuser_sync_subscription_state)
printf '%s\n' "$SYNC_STATE" | grep -Fq 'subscription_agent_enabled' || fail 'subscription-only state cannot sync'
RECONCILE=$(section "$SCRIPT" multiuser_reconcile_configs)
printf '%s\n' "$RECONCILE" | grep -Fq 'multiuser_enabled' || fail 'proxy/user reconcile was widened to subscription-only'

contains "$ROOT/modules/multiuser/lun_agent.py" '"subscription-access"'
contains "$ROOT/modules/multiuser/lun_agent.py" 'now - previous < 30'
CLUSTER_SERVICE=$(section "$SCRIPT" cluster_install_service)
if printf '%s\n' "$CLUSTER_SERVICE" | grep -Eiq 'heartbeat|timer|cron|while.*sync'; then
  fail 'cluster service adds a fixed heartbeat/sync timer'
fi
printf '%s\n' "$CLUSTER_SERVICE" | grep -Fq 'Restart=always' || fail 'cluster service does not survive an in-process update restart'

printf 'ok - Lun federation Shell integration\n'
