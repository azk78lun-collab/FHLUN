#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
SCRIPT="$ROOT/lun.sh"

for helper in \
  valid_port_value \
  firewall_append_port \
  firewall_append_file \
  collect_lun_firewall_ports \
  firewall_iptables_global_restrictive \
  firewall_iptables_port_restricted \
  firewall_apply_ufw \
  firewall_apply_iptables_family; do
  eval "$(sed -n "/^${helper}(){/,/^}/p" "$SCRIPT")"
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/lun/modules/multiuser"

printf '20001\n' > "$tmp/lun/port_vl_re"
printf '20002\n' > "$tmp/lun/port_ss"
printf '20003\n' > "$tmp/lun/port_hy2"
printf '20004\n' > "$tmp/lun/port_xc"
printf '20005\n' > "$tmp/lun/port_nv"
printf '21000\n' > "$tmp/lun/subport.log"
printf 'invalid\n' > "$tmp/lun/port_tu"
cat > "$tmp/lun/modules/multiuser/config.json" <<'JSON'
{
  "port": 22000,
  "legacy_http_port": 22001,
  "ss_port": 22002
}
JSON

collect_lun_firewall_ports "$tmp/lun" "$tmp/actual"
cat > "$tmp/expected" <<'EOF'
tcp:20001
tcp:20002
tcp:20004
tcp:20005
tcp:21000
tcp:22000
tcp:22001
tcp:22002
udp:20002
udp:20003
udp:20004
udp:20005
udp:22002
EOF

diff -u "$tmp/expected" "$tmp/actual"

printf 'tcp:23000\nudp:23001\n' > "$tmp/desired"
: > "$tmp/owned"
: > "$tmp/ufw-calls"
ufw() {
  printf '%s\n' "$*" >> "$tmp/ufw-calls"
  if [[ $1 == status ]]; then
    printf 'Status: active\n'
  fi
  return 0
}
firewall_record_owned() {
  printf '%s\n' "$*" >> "$tmp/owned"
}
firewall_apply_ufw "$tmp/desired"
grep -qxF 'ufw any tcp 23000' "$tmp/owned"
grep -qxF 'ufw any udp 23001' "$tmp/owned"
grep -q '^allow 23000/tcp comment FHLUN$' "$tmp/ufw-calls"

: > "$tmp/owned"
: > "$tmp/iptables-calls"
iptables() {
  case "$1" in
    -S) printf '%s\n' '-P INPUT DROP' ;;
    -C) return 1 ;;
    -I) printf '%s\n' "$*" >> "$tmp/iptables-calls" ;;
  esac
}
firewall_apply_iptables_family iptables "$tmp/desired"
grep -qxF 'iptables ipv4 tcp 23000' "$tmp/owned"
grep -qxF 'iptables ipv4 udp 23001' "$tmp/owned"
grep -q -- '--comment FHLUN -j ACCEPT' "$tmp/iptables-calls"

: > "$tmp/owned"
: > "$tmp/iptables-calls"
iptables() {
  case "$1" in
    -S)
      printf '%s\n' \
        '-P INPUT ACCEPT' \
        '-A INPUT -p tcp -m tcp --dport 22 -j DROP'
      ;;
    -C) return 1 ;;
    -I) printf '%s\n' "$*" >> "$tmp/iptables-calls" ;;
  esac
}
if firewall_apply_iptables_family iptables "$tmp/desired"; then
  echo "unrelated DROP rule must not trigger port opening" >&2
  exit 1
else
  [[ $? == 2 ]]
fi
[[ ! -s "$tmp/owned" ]]
[[ ! -s "$tmp/iptables-calls" ]]

: > "$tmp/owned"
: > "$tmp/iptables-calls"
iptables() {
  case "$1" in
    -S)
      printf '%s\n' \
        '-P INPUT ACCEPT' \
        '-A INPUT -p tcp -m tcp --dport 23000 -j DROP'
      ;;
    -C) return 1 ;;
    -I) printf '%s\n' "$*" >> "$tmp/iptables-calls" ;;
  esac
}
firewall_apply_iptables_family iptables "$tmp/desired"
grep -qxF 'iptables ipv4 tcp 23000' "$tmp/owned"
! grep -q -- '--dport 23001' "$tmp/iptables-calls"

grep -q 'apply_lun_firewall_rules quiet' "$SCRIPT"
grep -q '^apply_lun_firewall_rules || true$' "$SCRIPT"
grep -q 'remove_lun_firewall_rules' "$SCRIPT"
! grep -q 'iptables -P INPUT ACCEPT' "$SCRIPT"

echo "firewall helper tests passed"
