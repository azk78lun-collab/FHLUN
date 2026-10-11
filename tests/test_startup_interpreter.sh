#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/lun.sh"
[[ $(head -n 1 "$SCRIPT") == '#!/usr/bin/env bash' ]]
bash -n "$SCRIPT"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
# Execute through the kernel-selected interpreter, not an explicit Bash call.
head -n 1 "$SCRIPT" > "$TMP/lun"
printf '%s\n' \
  'test -n "${BASH_VERSION:-}" || exit 1' \
  'read -r -a rule <<< "one two"' \
  '[[ ${rule[1]} == two ]]' \
  'printf "Bash entrypoint OK\n"' >> "$TMP/lun"
chmod 700 "$TMP/lun"
[[ $("$TMP/lun") == 'Bash entrypoint OK' ]]
printf 'Direct executable interpreter regression passed\n'
