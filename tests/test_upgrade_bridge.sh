#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$ROOT/upgrade.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
mkdir -p "$HOME/bin" "$tmp/system"
ENTRY="$tmp/system/lun"
REMOTE="$tmp/remote"
fixture(){ printf '#!/usr/bin/env bash\n# Lun 项目地址\n# V%s\nprintf "%%s\\n" "%s"\n' "$2" "$3" > "$1"; }
fixture "$ENTRY" 26.10.20.3 old
fixture "$HOME/bin/lun" 26.10.20.3 old-secondary
fixture "$REMOTE" 26.11.11.4 current
lun_bridge_fetch(){
  [[ ${network_ok:-yes} == yes ]] || return 1
  case "$1" in
    */commits/main*) printf '%040d\n' 1 > "$2" ;;
    */contents/lun.sh*)
      hash=$({ printf 'blob %s\0' "$(wc -c < "$REMOTE" | tr -d '[:space:]')"; cat "$REMOTE"; } | sha1sum | awk '{print $1}')
      [[ ${wrong_blob:-no} != yes ]] || hash=ffffffffffffffffffffffffffffffffffffffff
      printf '{\n  "sha": "%s"\n}\n' "$hash" > "$2" ;;
    *) cp "$REMOTE" "$2" ;;
  esac
}

(
  # Minimal reproduction of the installed V26.10.20.3 updater's dynamic-scope
  # bug (91b9fbc): download_lun_script overwrote the caller's target variable.
  download_lun_script(){ target=$1; cp "$REMOTE" "$target"; }
  old_update(){
    target=$ENTRY
    update_stage="$target.update"
    download_lun_script "$update_stage"
    [[ $target == "$update_stage" && "$target" -ef "$update_stage" ]]
    cmp -s "$target" "$update_stage" # falsely reports "latest"
    rm "$update_stage"
  }
  old_update
  grep -q 'V26.10.20.3' "$ENTRY"
)
lun_bridge_main --target "$ENTRY"
cmp "$ENTRY" "$REMOTE"
cmp "$HOME/bin/lun" "$REMOTE"
grep -q 'V26.10.20.3' "$ENTRY.update-backup"
lun_bridge_main --target "$ENTRY"
echo 'ok - stable bridge upgrades a stranded legacy entry and verifies no-op'

cp "$ENTRY" "$tmp/expected"
wrong_blob=yes
! lun_bridge_main --target "$ENTRY"
cmp "$ENTRY" "$tmp/expected"
wrong_blob=no network_ok=no
! lun_bridge_main --target "$ENTRY"
cmp "$ENTRY" "$tmp/expected"
network_ok=yes
fixture "$REMOTE" 26.10.20.3 downgrade
! lun_bridge_main --target "$ENTRY"
cmp "$ENTRY" "$tmp/expected"
echo 'ok - mismatched content, failed metadata and downgrades preserve old entry'

fixture "$REMOTE" 26.11.11.5 next-release
lun_bridge_main --stage "$tmp/stage"
cmp "$tmp/stage" "$REMOTE"
cmp "$ENTRY" "$tmp/expected"
[[ -z $(find "$tmp" -type d -name '.lun-upgrade.*' -print) ]]
echo 'ok - stage API is non-mutating and removes temporary files'
