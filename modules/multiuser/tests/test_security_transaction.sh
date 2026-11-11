#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
for helper in multiuser_apply_changes multiuser_security_transaction; do
  eval "$(sed -n "/^${helper}(){/,/^}/p" "$ROOT/lun.sh")"
done
events=()
multiuser_module_dir(){ printf '%s\n' "$ROOT/modules/multiuser"; }
green_line(){ events+=(green); }
red_line(){ events+=(red); }
yellow_line(){ events+=(yellow); }
cluster_enabled(){ return 0; }
cluster_is_federation(){ return 0; }
cluster_cmd(){ events+=(broadcast); }
visit_monitor_enabled(){ return 0; }
lun_service_running(){ return 0; }
lun_service_enabled(){ return 0; }
lun_service_disable_autostart(){ events+=(disable-autostart); }
visit_monitor_service_stop(){ events+=(visit-stop); }
visit_monitor_service_start(){ events+=(visit-start); }
multiuser_service_stop(){ events+=(stop); }
fail_start=no
multiuser_service_start(){
  events+=(start)
  if [[ $fail_start == yes ]]; then fail_start=no; return 1; fi
}
multiuser_cmd(){ events+=("$*"); }

multiuser_security_transaction rotate-device --device-id 1 --confirm phone
[[ " ${events[*]} " == *'--defer-security-commit rotate-device'* ]]
[[ " ${events[*]} " == *'start security-commit visit-start green broadcast'* ]]
events=(); fail_start=yes
if multiuser_security_transaction delete-user --user-id 2 --confirm alice; then exit 1; fi
[[ " ${events[*]} " == *'security-rollback start green visit-start'* ]]
[[ " ${events[*]} " != *' security-commit '* && " ${events[*]} " != *' broadcast '* ]]
events=(); fail_start=yes
if multiuser_apply_changes; then exit 1; fi
[[ " ${events[*]} " != *'green'* && " ${events[*]} " != *'broadcast'* ]]

# An originally stopped/disabled service remains stopped after a rollback.
lun_service_running(){ return 1; }
lun_service_enabled(){ return 1; }
events=(); fail_start=yes
if multiuser_security_transaction delete-user --user-id 2 --confirm alice; then exit 1; fi
[[ " ${events[*]} " == *'security-rollback disable-autostart green'* ]]
[[ " ${events[*]} " != *'visit-start'* ]]

# A one-shot local identity change must not activate subscription delivery.
subscription_agent_enabled(){ return 1; }
events=()
multiuser_security_transaction set-local-identity --uuid example
[[ " ${events[*]} " == *'set-local-identity --uuid example security-commit'* ]]
[[ " ${events[*]} " != *' start '* ]]

(
for helper in local_identity_apply prompt_local_identity; do
  eval "$(sed -n "/^${helper}(){/,/^}/p" "$ROOT/lun.sh")"
done
events=()
cluster_push_event(){ events+=(snapshot); }
multiuser_security_transaction(){ events+=(transaction); return 1; }
if local_identity_apply example; then exit 1; fi
[[ " ${events[*]} " == ' transaction ' ]]
# Neither menu is allowed to write the UUID file before its transaction.
! grep -q 'echo "UUID 已更新：' "$ROOT/lun.sh"
[[ $(grep -c 'prompt_local_identity; ui_pause' "$ROOT/lun.sh") == 2 ]]
)

# Reject an outdated agent before stopping services or mutating credentials.
old=$(mktemp -d)
trap 'rm -rf "$old"' EXIT
printf '# old module\n' > "$old/lun_agent.py"
multiuser_module_dir(){ printf '%s\n' "$old"; }
multiuser_download_agent(){ events+=(download); }
events=()
if multiuser_security_transaction rotate-device --device-id 1; then exit 1; fi
[[ " ${events[*]} " == *'download red'* ]]
[[ " ${events[*]} " != *'stop'* && " ${events[*]} " != *'rotate-device'* ]]
printf 'Security transaction service/commit order tests passed\n'
