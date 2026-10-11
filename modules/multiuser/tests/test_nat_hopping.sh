#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
for helper in valid_port_value hy2_hop_restore_family hy2_hop_apply; do
  eval "$(sed -n "/^${helper}(){/,/^}/p" "$ROOT/lun.sh")"
done
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp"
mkdir -p "$HOME/lun"
red_line(){ printf '%s\n' "$*" >&2; }
yellow_line(){ printf '%s\n' "$*" >&2; }
firewall_save_iptables(){ :; }
declare -A rules exists jumps
rules[iptables]=; rules[ip6tables]=
exists[iptables]=no; exists[ip6tables]=no
jumps[iptables]=no; jumps[ip6tables]=no
foreign='-A PREROUTING -p tcp --dport 8000 -j DNAT --to-destination 10.0.0.2:80'
calls=0
fail_family=none
ipt(){
  local family=$1 action chain
  shift
  [[ $1 == -t && $2 == nat ]]
  shift 2
  action=$1; chain=${2:-}
  calls=$((calls + 1))
  case "$action" in
    -S)
      if [[ $chain == PREROUTING ]]; then printf '%s\n' "$foreign"; return; fi
      [[ ${exists[$family]} == yes ]] || return 1
      printf '%s\n' '-N LUN_HY2_HOP'
      [[ -z ${rules[$family]} ]] || printf '%s\n' "${rules[$family]}"
      ;;
    -N) [[ ${exists[$family]} == no ]] || return 1; exists[$family]=yes ;;
    -F) [[ $chain == LUN_HY2_HOP ]]; [[ ${exists[$family]} == yes ]] || return 1; rules[$family]= ;;
    -X) [[ ${exists[$family]} == yes && -z ${rules[$family]} && ${jumps[$family]} == no ]] || return 1; exists[$family]=no ;;
    -C) [[ ${jumps[$family]} == yes ]] ;;
    -I) [[ $chain == PREROUTING ]]; jumps[$family]=yes ;;
    -D) [[ $chain == PREROUTING ]]; jumps[$family]=no ;;
    -A)
      [[ $chain == LUN_HY2_HOP ]]
      [[ $family != "$fail_family" || "$*" != *'--dport 23334'* ]] || return 1
      rules[$family]+="${rules[$family]:+$'\n'}$*"
      ;;
    *) return 1 ;;
  esac
}
iptables(){ ipt iptables "$@"; }
ip6tables(){ ipt ip6tables "$@"; }

hy2_hop_apply '20000 20001-20003' 1234
[[ ${rules[iptables]} == *'--dport 20001:20003'* && ${jumps[iptables]} == yes ]]
[[ $(cat "$HOME/lun/hy2_hop_target") == 1234 ]]
original_v4=${rules[iptables]}; original_v6=${rules[ip6tables]}
fail_family=ip6tables
if hy2_hop_apply '23334' 4321; then echo 'failure injection was ignored' >&2; exit 1; fi
[[ ${rules[iptables]} == "$original_v4" && ${rules[ip6tables]} == "$original_v6" ]]
[[ $(cat "$HOME/lun/hy2_hop_target") == 1234 ]]
fail_family=none
hy2_hop_apply 20004 4321
[[ ${rules[iptables]} == *':4321'* && ${rules[iptables]} != *':1234'* ]]
before=$calls
if hy2_hop_apply '1234;evil' 4321; then exit 1; fi
[[ $calls == "$before" ]]
hy2_hop_apply '' ''
hy2_hop_apply '' ''
[[ ${exists[iptables]} == no && ${exists[ip6tables]} == no ]]
[[ ! -f "$HOME/lun/hy2_hop_ports" ]]

exists[iptables]=yes
rules[iptables]='-A LUN_HY2_HOP -p tcp --dport 9000 -j ACCEPT'
if hy2_hop_apply 20000 1234; then exit 1; fi
[[ ${rules[iptables]} == '-A LUN_HY2_HOP -p tcp --dport 9000 -j ACCEPT' ]]
[[ $foreign == '-A PREROUTING -p tcp --dport 8000 -j DNAT --to-destination 10.0.0.2:80' ]]
if grep -Eq '^-?(ip6tables|iptables).* -F PREROUTING' "$ROOT/lun.sh"; then exit 1; fi
printf 'NAT hopping ownership and rollback tests passed\n'
