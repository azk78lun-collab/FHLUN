#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
load(){
  eval "$(awk -v name="$1" '$0 ~ "^" name "\\(\\)\\{" {p=1; print; next} p && /^[A-Za-z_][A-Za-z_0-9]*\(\)\{/ {exit} p {print}' "$ROOT/lun.sh")"
}
for name in lun_version_is_older core_update_running core_update_restart update_installed_core update_local_lun_bundle service_update_menu; do load "$name"; done
TEMP=$(mktemp -d)
trap 'rm -rf -- "$TEMP"' EXIT
export HOME="$TEMP/home"
mkdir -p "$HOME/lun"
cpu=amd64
yellow_line(){ :; }; green_line(){ :; }; red_line(){ :; }; ui_title(){ :; }; ui_pause(){ :; }
LOG="$TEMP/actions"
touch "$LOG"
core_update_digest(){ printf '%s' "${digest_value:-}"; }
core_update_running(){ [[ $active == yes ]]; }
core_update_restart(){ printf 'restart %s\n' "$1" >> "$LOG"; [[ $restart_ok == yes ]]; }
xrestart(){ printf 'restore xray\n' >> "$LOG"; }
sbrestart(){ printf 'restore sing-box\n' >> "$LOG"; }
multiuser_enabled(){ [[ $multiuser == yes ]]; }
download_core_asset(){ printf 'download %s\n' "$1" >> "$LOG"; cp "$TEMP/candidate" "$2"; }
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

reset_case
multiuser=yes active=yes
binary "$HOME/lun/sing-box" 'sing-box version 1.0.0'
binary "$TEMP/candidate" 'sing-box version 1.1.0'
printf '{}\n' > "$HOME/lun/sb.json"
update_installed_core sing-box
[[ $(cat "$LOG") == $'download sing-box-multiuser-amd64\nrestart sing-box' ]]
rm "$HOME/lun/sing-box"
: > "$LOG"
update_installed_core sing-box
[[ ! -s $LOG ]] # never install an unused core

update_lun_script(){ printf 'script\n' >> "$LOG"; return "$script_rc"; }
update_installed_core(){ printf '%s\n' "$1" >> "$LOG"; [[ $1 != "$fail_engine" ]]; }
script_rc=0 fail_engine=none
: > "$LOG"
update_local_lun_bundle
[[ $(cat "$LOG") == $'script\nxray\nsing-box' ]]
script_rc=1
: > "$LOG"
if update_local_lun_bundle; then exit 1; fi
[[ $(cat "$LOG") == script ]]
script_rc=0 fail_engine=xray
: > "$LOG"
if update_local_lun_bundle; then exit 1; fi
[[ $(cat "$LOG") == $'script\nxray\nsing-box' ]]
fail_engine=none
output=$(service_update_menu <<< $'4\n0')
[[ $output == *'同时检查 Xray / Sing-box'* ]]
[[ $output != *'5. 更新 Xray'* && $output != *'6. 更新 Sing-box'* ]]
printf 'Unified updates: digest, compatibility, rollback, state and menu tests passed\n'
