#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
for helper in multiuser_bandwidth_runner multiuser_bandwidth_config multiuser_bandwidth_write_runner; do
  eval "$(sed -n "/^${helper}(){/,/^}/p" "$ROOT/lun.sh")"
done
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp" MOCK_TC="$tmp/tc-state"
mkdir -p "$tmp/bin" "$MOCK_TC" "$HOME/lun/modules/multiuser"
export PATH="$tmp/bin:$PATH"
multiuser_module_dir(){ printf '%s\n' "$HOME/lun/modules/multiuser"; }
cat > "$tmp/bin/tc" <<'EOF'
#!/bin/sh
echo "$*" >> "$MOCK_TC/calls"
iface=$4
case "$1 $2" in
'qdisc show')
  if [ -r "$MOCK_TC/$iface" ]; then read kind handle rate < "$MOCK_TC/$iface"; else kind=fq_codel handle=0: rate=0; fi
  echo "qdisc $kind $handle root rate $rate"
  ;;
'qdisc replace')
  [ "$5" = root ] || exit 0
  kind=$8; rate=0
  if [ "$kind" = cake ]; then rate=${10}; [ "$rate" != 999mbit ] || exit 1; fi
  echo "$kind $7 $rate" > "$MOCK_TC/$iface"
  ;;
'class replace')
  case "$*" in *'rate 999mbit'*) exit 1 ;; esac
  ;;
'qdisc del') rm -f "$MOCK_TC/$iface" ;;
*) exit 1 ;;
esac
EOF
cat > "$tmp/bin/ip" <<'EOF'
#!/bin/sh
case "$*" in *'route show default'*) echo 'default via 1.2.3.4 dev eth0' ;; esac
exit 0
EOF
cat > "$tmp/bin/modprobe" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$tmp/bin/"*
multiuser_bandwidth_write_runner
runner=$(multiuser_bandwidth_runner)
config=$(multiuser_bandwidth_config)
printf 'RATE_MBIT=80\nINTERFACE=eth0\n' > "$config"
echo 'tbf 1: 20mbit' > "$MOCK_TC/eth0"
if sh "$runner" apply; then exit 1; fi
[[ $(cat "$MOCK_TC/eth0") == 'tbf 1: 20mbit' ]]
[[ ! -f "$config.owned" ]]
sh "$runner" clear
[[ $(cat "$MOCK_TC/eth0") == 'tbf 1: 20mbit' ]]
rm "$MOCK_TC/eth0"
sh "$runner" apply
[[ $(cat "$MOCK_TC/eth0") == 'cake f1a0: 80mbit' ]]
before=$(cat "$config.owned")
printf 'RATE_MBIT=999\nINTERFACE=eth0\n' > "$tmp/failed.conf"
if sh "$runner" apply "$tmp/failed.conf"; then exit 1; fi
[[ $(cat "$MOCK_TC/eth0") == 'cake f1a0: 80mbit' ]]
[[ $(cat "$config.owned") == "$before" ]]
[[ $(sed -n 's/^RATE_MBIT=//p' "$config") == 80 ]]
printf 'RATE_MBIT=60\nINTERFACE=eth1\n' > "$tmp/new.conf"
sh "$runner" apply "$tmp/new.conf"
[[ ! -f "$MOCK_TC/eth0" && $(cat "$MOCK_TC/eth1") == 'cake f1a0: 60mbit' ]]
sh "$runner" clear
sh "$runner" clear
[[ ! -f "$MOCK_TC/eth1" && ! -f "$config.owned" ]]
sh "$runner" apply
echo 'tbf 2: 10mbit' > "$MOCK_TC/eth0"
sh "$runner" clear
[[ $(cat "$MOCK_TC/eth0") == 'tbf 2: 10mbit' ]]
# The menu must not commit a candidate configuration when service startup fails.
eval "$(sed -n '/^multiuser_bandwidth_enable(){/,/^}/p' "$ROOT/lun.sh")"
multiuser_install_tc(){ :; }
multiuser_bandwidth_install_service(){ :; }
pidof(){ return 1; }
rc-update(){ :; }
rc-service(){ return 1; }
red_line(){ :; }
yellow_line(){ :; }
green_line(){ :; }
rm -f "$MOCK_TC/eth0"
sh "$runner" apply
before=$(cat "$config.owned")
if multiuser_bandwidth_enable <<< $'60\neth1'; then exit 1; fi
[[ $(cat "$MOCK_TC/eth0") == 'cake f1a0: 80mbit' ]]
[[ ! -f "$MOCK_TC/eth1" && $(cat "$config.owned") == "$before" ]]
[[ $(sed -n 's/^RATE_MBIT=//p' "$config") == 80 ]]
[[ -z $(find "$(dirname "$config")" -name '*.candidate.*' -o -name '*.previous.*') ]]
rc-service(){ :; }
multiuser_bandwidth_enable <<< $'60\neth1'
[[ ! -f "$MOCK_TC/eth0" && $(cat "$MOCK_TC/eth1") == 'cake f1a0: 60mbit' ]]
[[ $(sed -n 's/^RATE_MBIT=//p' "$config") == 60 ]]
printf 'Bandwidth ownership / rollback / interface tests passed\n'
