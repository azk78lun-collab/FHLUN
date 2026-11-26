#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
load_function(){
  eval "$(awk -v fn="$1" '
    $0 ~ "^" fn "\\(\\)\\{" {on=1; print; next}
    on && /^[A-Za-z_][A-Za-z_0-9]*\(\)\{/ {exit}
    on {print}
  ' "$ROOT/lun.sh")"
}
load_function valid_port_value
load_function snell_write_config
if [[ ${1:-} == --fixture ]]; then
  snell_write_config "$2" 127.0.0.1 "$(printf 'a%.0s' {1..64})"
  exit
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp"
mkdir -p "$HOME/lun/snell"
for fn in protocol_label protocol_var protocol_capability_mark protocol_current_port \
  legacy_protocol_pick_state install_protocol_menu \
  snell_public_port snell_service snell_apply_only firewall_append_port firewall_append_file \
  collect_lun_firewall_ports snell_show_sharing_status; do
  load_function "$fn"
done
red_line(){ :; }
green_line(){ :; }
is_nat_mode(){ [[ $nat_mode == yes ]]; }
pool_public_for_inner(){ return 1; }
nat_mode=no
[[ $(protocol_label 15) == 'Snell v6' && $(protocol_var 15) == snpt ]]
[[ $(protocol_capability_mark 15 direct) == ✓ ]]
for flag in cdn origin tunnel; do [[ $(protocol_capability_mark 15 "$flag") == — ]]; done
[[ $(snell_public_port 25443) == 25443 ]]
nat_mode=yes ptmap='55000-25443'
[[ $(snell_public_port 25443) == 55000 ]]
! snell_public_port 25444

# If OpenRC cannot stop our still-running service, do not report success.
lun_has_systemd(){ return 1; }
rc-service(){ [[ $2 == status && $simulated_running == yes ]]; }
rc-update(){ :; }
simulated_running=yes
! snell_service disable
simulated_running=no
snell_service disable

snell_preflight(){ :; }
snell_service(){ printf '%s\n' "$1" >> "$tmp/service-actions"; }
apply_lun_firewall_rules(){ [[ ${firewall_ok:-yes} == yes ]]; }
snell_install(){
  snell_write_config "$port_snell" :: "$(printf 'a%.0s' {1..64})" > "$HOME/lun/snell/config.json" &&
  printf '%s\n' "$port_snell" > "$HOME/lun/port_snell"
}
snp=yes port_snell=25443
snell_apply_only
[[ $(cat "$HOME/lun/port_snell") == 25443 ]]
cp "$HOME/lun/snell/config.json" "$tmp/old.json"
port_snell=25444 firewall_ok=no
! snell_apply_only
cmp "$tmp/old.json" "$HOME/lun/snell/config.json"
[[ $(cat "$HOME/lun/port_snell") == 25443 ]]
grep -qx install "$tmp/service-actions"

# Opting into Snell on an existing VPS must not take the generic rebuild path.
ui_title(){ :; }
LUN_GREEN= LUN_RESET=
load_installed_protocol_flags(){ vlpt=14443; snpt=25443; }
pick_protocols(){ snpt=25444; }
install_protocol_menu <<< 2 >/dev/null
[[ $LUN_MENU_ACTION == snell-apply ]]
pick_protocols(){ vlpt=14444; snpt=25444; }
install_protocol_menu <<< 2 >/dev/null
[[ $LUN_MENU_ACTION == rep ]]

collect_lun_firewall_ports "$HOME/lun" "$tmp/firewall"
[[ $(cat "$tmp/firewall") == 'tcp:25443' ]]
: > "$HOME/lun/jhsub.txt"
: > "$HOME/lun/clmi.yaml"
: > "$HOME/lun/sbox.json"
snell_show_sharing_status > "$tmp/status"
! grep -Fq "$(printf 'a%.0s' {1..64})" "$tmp/status"
[[ ! -e "$HOME/lun/jhsub.txt" && ! -e "$HOME/lun/clmi.yaml" && ! -e "$HOME/lun/sbox.json" ]]
firewall_ok=yes snp=
snell_apply_only
[[ ! -e "$HOME/lun/snell/config.json" && ! -e "$HOME/lun/port_snell" ]]
echo 'ok - Snell number, NAT mapping, TCP-only firewall, private output, and rollback'
