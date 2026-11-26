#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
load(){
  eval "$(awk -v name="$1" '$0 ~ "^" name "\\(\\)\\{" {p=1; print; next} p && /^[A-Za-z_][A-Za-z_0-9]*\(\)\{/ {exit} p {print}' "$ROOT/lun.sh")"
}
for name in lun_version_is_older core_update_running core_update_restart update_lun_singbox update_installed_core update_local_lun_bundle sync_lun_runtime service_update_menu; do load "$name"; done
TEMP=$(mktemp -d)
trap 'rm -rf -- "$TEMP"' EXIT
export HOME="$TEMP/home"
mkdir -p "$HOME/lun"
cpu=amd64
LUN_SINGBOX_VERSION=$(sed -n 's/^LUN_SINGBOX_VERSION=//p' "$ROOT/lun.sh")
LUN_MULTIUSER_GENERATION="singbox-$LUN_SINGBOX_VERSION"
yellow_line(){ :; }; green_line(){ :; }; red_line(){ :; }; ui_title(){ :; }; ui_pause(){ :; }
LOG="$TEMP/actions"
touch "$LOG"
core_update_digest(){ printf '%s' "${digest_value:-}"; }
core_update_running(){ [[ $active == yes ]]; }
core_update_restart(){ printf 'restart %s\n' "$1" >> "$LOG"; [[ $restart_ok == yes ]]; }
xrestart(){ printf 'restore xray\n' >> "$LOG"; }
sbrestart(){ printf 'restore sing-box\n' >> "$LOG"; }
multiuser_enabled(){ [[ $multiuser == yes ]]; }
download_core_asset(){
  printf 'download %s\n' "$1" >> "$LOG"
  if [[ $1 == *.tar.gz ]]; then cp "$TEMP/bundle" "$2"; else cp "$TEMP/candidate" "$2"; fi
}
binary(){
  printf '#!/usr/bin/env bash\nif [ "$1" = version ]; then echo "%s"; else exit "${invalid:-0}"; fi\n' "$2" > "$1"
  chmod 755 "$1"
}
reset_case(){
  : > "$LOG"
  active=no restart_ok=yes multiuser=no digest_value=
  export invalid=0
  binary "$HOME/lun/xray" 'Xray 1.0.0'
  binary "$TEMP/candidate" 'Xray 1.1.0'
  printf '{}\n' > "$HOME/lun/xr.json"
}

reset_case
digest_value="sha256:$(sha256sum "$HOME/lun/xray" | awk '{print $1}')"
update_installed_core xray
[[ ! -s $LOG ]]

reset_case
cp "$HOME/lun/xray" "$TEMP/candidate"
active=yes
update_installed_core xray
[[ $(cat "$LOG") == 'download xray-amd64' ]]

reset_case
before=$(sha256sum "$HOME/lun/xray")
export invalid=1
if update_installed_core xray; then echo 'invalid core accepted' >&2; exit 1; fi
[[ $(sha256sum "$HOME/lun/xray") == "$before" ]]
[[ $(cat "$LOG") == 'download xray-amd64' ]]

reset_case
update_installed_core xray
cmp -s "$HOME/lun/xray" "$TEMP/candidate"
[[ $(cat "$LOG") == 'download xray-amd64' ]] # stopped service stays stopped

reset_case
active=yes
update_installed_core xray
[[ $(cat "$LOG") == $'download xray-amd64\nrestart xray' ]]

reset_case
active=yes restart_ok=no
before=$(sha256sum "$HOME/lun/xray")
if update_installed_core xray; then echo 'restart failure ignored' >&2; exit 1; fi
[[ $(sha256sum "$HOME/lun/xray") == "$before" ]]
[[ $(cat "$LOG") == $'download xray-amd64\nrestart xray\nrestore xray' ]]

reset_case
binary "$HOME/lun/xray" 'Xray 2.0.0'
before=$(sha256sum "$HOME/lun/xray")
update_installed_core xray
[[ $(sha256sum "$HOME/lun/xray") == "$before" ]]

reset_case
digest_value="sha256:$(printf wrong | sha256sum | awk '{print $1}')"
before=$(sha256sum "$HOME/lun/xray")
if update_installed_core xray; then echo 'digest mismatch ignored' >&2; exit 1; fi
[[ $(sha256sum "$HOME/lun/xray") == "$before" ]]

reset_case
binary "$HOME/lun/xray" 'Xray 2.0.0-alpha.2'
binary "$TEMP/candidate" 'Xray 2.0.0-alpha.1'
before=$(sha256sum "$HOME/lun/xray")
update_installed_core xray
[[ $(sha256sum "$HOME/lun/xray") == "$before" ]]

multiuser_module_dir(){ printf '%s\n' "$HOME/lun/modules/multiuser"; }
lun_python_ensure(){ :; }
flock(){ :; }
snell_service(){ if [[ $1 == status ]]; then [[ $active == yes ]]; else printf 'snell %s\n' "$1" >> "$LOG"; fi; }
sleep(){ :; }
reset_case
: > "$LOG"
update_installed_core sing-box
[[ ! -s $LOG ]] # never install an unused core

mkdir -p "$TEMP/payload" "$HOME/lun/snell" "$(multiuser_module_dir)"
# The fixture prints real version and build-tag lines, just like the actual core.
printf '#!/usr/bin/env bash\ncase "$1" in version) printf "sing-box version %s\\nTags: with_v2ray_api\\n";; check) exit 0;; esac\n' \
  "$LUN_SINGBOX_VERSION" > "$TEMP/payload/sing-box"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TEMP/payload/lun-sb-stats"
tar -czf "$TEMP/bundle" -C "$TEMP/payload" sing-box lun-sb-stats
bundle_digest="sha256:$(sha256sum "$TEMP/bundle" | awk '{print $1}')"
binary "$HOME/lun/sing-box" 'sing-box version 1.13.14'
binary "$HOME/lun/snell/sing-box" 'sing-box version 1.14.4'
printf '{}\n' > "$HOME/lun/sb.json"
printf '{}\n' > "$HOME/lun/snell/config.json"
before=$(sha256sum "$HOME/lun/sing-box")
digest_value="sha256:$(printf wrong | sha256sum | awk '{print $1}')"
! update_installed_core sing-box
[[ $(sha256sum "$HOME/lun/sing-box") == "$before" ]]
digest_value=$bundle_digest active=yes restart_ok=no
! update_installed_core sing-box
[[ $(sha256sum "$HOME/lun/sing-box") == "$before" ]]
[[ ! -e "$(multiuser_module_dir)/lun-sb-stats" && ! -e "$HOME/lun/.lun-singbox-version" ]]
restart_ok=yes
update_installed_core sing-box
[[ "$HOME/lun/sing-box" -ef "$HOME/lun/snell/sing-box" ]]
[[ -x "$(multiuser_module_dir)/lun-sb-stats" && $(cat "$HOME/lun/.lun-singbox-version") == "$LUN_SINGBOX_VERSION" ]]
: > "$LOG"
update_installed_core sing-box
[[ ! -s $LOG ]] # already synchronized; never restart

rm -f "$HOME/lun/sing-box" "$HOME/lun/snell/sing-box"
active=no
update_installed_core sing-box
[[ "$HOME/lun/sing-box" -ef "$HOME/lun/snell/sing-box" ]]
[[ $(cat "$LOG") == "download sing-box-lun-$cpu.tar.gz" ]] # recover missing binaries without starting stopped services

(
  # A retry may recover only its own interrupted migration, never another security operation.
  mu=$(multiuser_module_dir)
  pending_dir="$mu/.security-transaction"
  mkdir -p "$mu/data" "$pending_dir"
  printf 'fixture\n' > "$mu/config.json"
  printf 'fixture\n' > "$mu/data/lun.db"
  printf '%s\n' '--staged-core-upgrade' > "$mu/lun_agent.py"
  update_installed_core(){ :; }
  # BusyBox flock accepts nonblocking FD locks, not util-linux's -w.
  flock(){ [[ "$*" == '-n 7' ]]; }
  cluster_enabled(){ return 1; }
  visit_monitor_enabled(){ return 1; }
  multiuser_config_value(){ printf 'old\n'; }
  multiuser_service_stop(){ printf 'stop\n' >> "$LOG"; }
  multiuser_service_start(){ printf 'start\n' >> "$LOG"; }
  multiuser_cmd(){
    [[ $1 == security-rollback ]]
    printf 'rollback\n' >> "$LOG"
    rm -f "$pending_dir/state.json"
    rmdir "$pending_dir"
  }
  multiuser_security_transaction(){ printf 'new migration\n' >> "$LOG"; }
  : > "$LOG"
  printf '{}\n' > "$pending_dir/state.json"
  ! sync_lun_runtime
  [[ -f $pending_dir/state.json && ! -s $LOG ]]
  printf '{"core_upgrade_reset":true}\n' > "$pending_dir/state.json"
  sync_lun_runtime
  [[ $(cat "$LOG") == $'stop\nrollback\nstart\nnew migration' ]]
)

update_lun_script(){ printf 'script\n' >> "$LOG"; return "$script_rc"; }
cluster_update_from_installed_script(){ printf 'federation\n' >> "$LOG"; return "$cluster_rc"; }
update_installed_core(){ printf '%s\n' "$1" >> "$LOG"; [[ $1 != "$fail_engine" ]]; }
sync_lun_runtime(){ update_installed_core sing-box; }
script_rc=0 cluster_rc=0 fail_engine=none
: > "$LOG"
update_local_lun_bundle
[[ $(cat "$LOG") == $'script\nfederation\nxray\nsing-box' ]]
script_rc=1
: > "$LOG"
if update_local_lun_bundle; then exit 1; fi
[[ $(cat "$LOG") == script ]]
script_rc=0 fail_engine=xray
: > "$LOG"
if update_local_lun_bundle; then exit 1; fi
[[ $(cat "$LOG") == $'script\nfederation\nxray' ]]
fail_engine=none cluster_rc=1
: > "$LOG"
if update_local_lun_bundle; then exit 1; fi
[[ $(cat "$LOG") == $'script\nfederation\nxray' ]]
cluster_rc=0
output=$(service_update_menu <<< $'4\n0')
[[ $output == *'同时检查 Xray / Sing-box'* ]]
[[ $output != *'5. 更新 Xray'* && $output != *'6. 更新 Sing-box'* ]]
printf 'Unified updates: digest, compatibility, rollback, state and menu tests passed\n'
