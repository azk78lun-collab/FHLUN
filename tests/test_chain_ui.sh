#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
load(){
  eval "$(awk -v name="$1" '$0 ~ "^" name "\\(\\)\\{" {p=1; print; next} p && /^[A-Za-z_][A-Za-z_0-9]*\(\)\{/ {exit} p {print}' "$ROOT/lun.sh")"
}
ui_title(){ :; }; ui_pause(){ :; }; ui_dash(){ :; }
red_line(){ :; }; yellow_line(){ :; }; green_line(){ :; }
cluster_show_nodes(){ :; }; cluster_enabled(){ return 0; }
LUN_CYAN= LUN_YELLOW= LUN_RESET=
load cluster_federation_menu
load cluster_chain_ui
load chain_runtime_apply
load chain_preserve_existing_core_fields
load validate_rebuild
record(){ calls+="$*"$'\n'; }
(
  calls=
  cluster_chain_ui(){ record chain-ui; }
  cluster_federation_menu <<< $'7\n0' >/dev/null
  [[ $calls == $'chain-ui\n' ]]
)
(
  calls=
  cluster_cmd(){ record "$*"; }
  cluster_refresh_profiles_async(){ record refreshed; }
  cluster_chain_ui <<< $'2\n1\n2\n\n\n0' >/dev/null
  [[ $calls == *'chain-plan --entry 1 --exit 2 --port 0'* ]]
  [[ $calls == *'chain-create --entry 1 --exit 2 --port 0'* ]]
  [[ $calls == *refreshed* ]]
)
(
  calls=
  cluster_cmd(){ record "$*"; [[ $1 != chain-plan ]]; }
  cluster_refresh_profiles_async(){ record refreshed; }
  cluster_chain_ui <<< $'2\n1\n2\n12345\n0' >/dev/null
  [[ $calls != *chain-create* && $calls != *refreshed* ]]
)
(
  calls=
  cluster_cmd(){ record "$*"; }
  cluster_refresh_profiles_async(){ record refreshed; }
  cluster_chain_ui <<< $'3\n1\nabcdef\n4\n2\nabcdef\n\n0' >/dev/null
  [[ $calls == *'chain-repair --node-id 1 --chain-id abcdef'* ]]
  [[ $calls == *'chain-remove --node-id 2 --chain-id abcdef'* ]]
)
(
  calls=
  cluster_cmd(){ record "$*"; }
  multiuser_enabled(){ return 0; }
  multiuser_reconcile_configs(){ record users; }
  validate_core_configs(){ record validate; }
  xrestart(){ record restart; }
  chain_runtime_status(){ record ready; }
  subscription_agent_enabled(){ return 0; }
  multiuser_service_restart(){ record agent; }
  apply_lun_firewall_rules(){ record firewall; }
  refresh_subscription_outputs(){ [[ ${LUN_CHAIN_REBUILD:-no} == yes ]]; record subscriptions; }
  chain_runtime_apply
  [[ $calls == $'chain-inject\nusers\nvalidate\nrestart\nready\nagent\nfirewall\nsubscriptions\n' ]]
  calls=
  validate_core_configs(){ record invalid; return 1; }
  ! chain_runtime_apply
  [[ $calls == $'chain-inject\nusers\ninvalid\n' ]]
  validate_core_configs(){ record validate; }
  refresh_subscription_outputs(){ record subscription-failed; return 1; }
  ! chain_runtime_apply
  [[ $calls == *subscription-failed* ]]
)
grep -q 'chain_inject_core || return 1' "$ROOT/lun.sh"
(
  calls=
  validate_core_configs(){ record validate; }
  xrestart(){ record restart; }
  chain_runtime_status(){ record ready; return "$ready_rc"; }
  sleep(){ :; }
  ready_rc=0
  LUN_CHAIN_PREPARE=no validate_rebuild
  [[ $calls == $'validate\n' ]]
  calls=
  LUN_CHAIN_PREPARE=yes validate_rebuild
  [[ $calls == $'validate\nrestart\nready\n' ]]
  calls= ready_rc=1
  if LUN_CHAIN_PREPARE=yes validate_rebuild; then exit 1; fi
  [[ $calls == $'validate\nrestart\nready\nready\nready\n' ]]
)
grep -q 'for fw_file in "$fw_root"/port_chain_' "$ROOT/lun.sh"
grep -q 'for chain_reserved_file in "$HOME/lun"/port_chain_' "$ROOT/lun.sh"
grep -q 'elif \[ "${LUN_CHAIN_REBUILD:-no}" = yes \]; then' "$ROOT/lun.sh"
(
  temp=$(mktemp -d)
  trap 'rm -rf -- "$temp"' EXIT
  HOME="$temp/home"
  rebuild_snapshot="$temp/snapshot"
  mkdir -p "$HOME/lun" "$rebuild_snapshot/lun"
  python3 - "$HOME/lun" "$rebuild_snapshot/lun" <<'PY'
import json, sys
from pathlib import Path
root, before = map(Path, sys.argv[1:])
old = {"log": {"custom": True}, "inbounds": [{"tag": "xhttp", "port": 12345, "password": "unchanged"}],
       "outbounds": [{"tag": "warp", "settings": {"keep": True}}], "routing": {"custom": [1, 2]}}
(before / "xr.json").write_text(json.dumps(old))
(before / "sb.json").write_text('{"custom-singbox":true}\n')
(root / "sb.json").write_text('{"wrong":true}')
(root / "xr.json").write_text(json.dumps({"inbounds": [{"tag": "reality-vision", "port": 25001}], "routing": {}}))
PY
  LUN_CHAIN_PREPARE=yes chain_preserve_existing_core_fields
  python3 - "$HOME/lun" "$rebuild_snapshot/lun" <<'PY'
import json, sys
from pathlib import Path
root, before = map(Path, sys.argv[1:])
old = json.loads((before / "xr.json").read_text())
new = json.loads((root / "xr.json").read_text())
added = new["inbounds"].pop()
assert added == {"tag": "reality-vision", "port": 25001}
assert new == old, "existing credentials, routing and custom fields must remain exact"
assert (root / "sb.json").read_bytes() == (before / "sb.json").read_bytes()
(before / "xr.json").unlink()
(root / "xr.json").write_text(json.dumps({"inbounds": [added, {"tag": "vmess-was-on-singbox", "port": 12345}]}))
PY
  LUN_CHAIN_PREPARE=yes chain_preserve_existing_core_fields
  python3 - "$HOME/lun" <<'PY'
import json, sys
from pathlib import Path
assert json.loads((Path(sys.argv[1]) / "xr.json").read_text())["inbounds"] == [{"tag": "reality-vision", "port": 25001}]
PY
  rebuild_snapshot="$temp/missing"
  if LUN_CHAIN_PREPARE=yes chain_preserve_existing_core_fields; then exit 1; fi
  LUN_CHAIN_PREPARE=no chain_preserve_existing_core_fields
)
echo 'Chain UI, validation order, firewall and port ownership checks passed'
