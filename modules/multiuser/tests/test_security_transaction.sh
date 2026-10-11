#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
for helper in multiuser_apply_changes multiuser_security_transaction; do
  eval "$(sed -n "/^${helper}(){/,/^}/p" "$ROOT/lun.sh")"
done
events=()
green_line(){ events+=(green); }
red_line(){ events+=(red); }
yellow_line(){ events+=(yellow); }
cluster_enabled(){ return 0; }
cluster_is_federation(){ return 0; }
cluster_cmd(){ events+=(broadcast); }
visit_monitor_enabled(){ return 0; }
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
printf 'Security transaction service/commit order tests passed\n'
