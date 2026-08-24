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
contains "$SCRIPT" '当前版本：V26.8.10.4'
contains "$SCRIPT" 'cluster_cmd endpoint-reconcile'
contains "$SCRIPT" '分布式服务器集群'
contains "$SCRIPT" 'subscription_agent_enabled(){'
contains "$SCRIPT" 'subscription_only_enabled(){'
contains "$SCRIPT" 'cluster_existing_internal=$(cluster_config_value internal_port'
contains "$SCRIPT" '[ "$cluster_reuse_existing" != yes ]'

MENU=$(section "$SCRIPT" cluster_federation_menu)
printf '%s\n' "$MENU" | grep -Fq '生成加入地址' || fail 'federation menu missing join address'
printf '%s\n' "$MENU" | grep -Fq '刷新并查看聚合订阅' || fail 'federation menu missing aggregate refresh'
printf '%s\n' "$MENU" | grep -Fq '一键更新所有 VPS 代理脚本' || fail 'federation menu update label is unclear'
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
UNTRUSTED=$(section "$SCRIPT" cluster_untrusted_member_numbers)
printf '%s\n' "$UNTRUSTED" | grep -Fq 'row.get("trusted") is not True' || fail 'automatic update exclusion ignores backend trusted flag'

PUSH=$(section "$SCRIPT" cluster_push_event)
printf '%s\n' "$PUSH" | grep -Fq 'cluster_cmd push' || fail 'rebuild publication missing push'
printf '%s\n' "$PUSH" | grep -Fq ') >/dev/null 2>&1 &' || fail 'snapshot publication blocks caller'
contains "$SCRIPT" 'cluster_push_event'

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
