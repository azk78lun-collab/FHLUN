#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
mkdir -p "$HOME/bin" "$TMP/empty" "$TMP/system"
load(){
  eval "$(awk -v name="$1" '$0 ~ "^" name "\\(\\)\\{" {p=1; print; next} p && /^[A-Za-z_][A-Za-z_0-9]*\(\)\{/ {exit} p {print}' "$ROOT/lun.sh")"
}
for name in download_lun_script lun_script_version lun_version_is_older lun_install_update_stage \
    lun_sync_secondary_entry update_lun_script lun_reopen_updated_menu lun_init_colors service_update_menu; do load "$name"; done
yellow_line(){ :; }; green_line(){ :; }; red_line(){ :; }; ui_title(){ :; }; ui_pause(){ :; }
ENTRY="$TMP/system/lun"
REMOTE="$TMP/remote"
lun_update_target(){ printf '%s\n' "$ENTRY"; }
fixture(){ printf '#!/usr/bin/env bash\n# V%s\n# Lun 项目地址\nprintf "%%s\\n" "%s"\n' "$2" "$3" > "$1"; }
curl(){
  local output= previous= argument
  [[ ${download_ok:-yes} == yes ]] || return 1
  for argument; do
    [[ $previous != -o ]] || output=$argument
    previous=$argument
  done
  [[ -n $output ]] || return 1
  cp "$REMOTE" "$output"
}
wget(){ return 1; }

fixture "$ENTRY" 26.10.20.3 old
fixture "$HOME/bin/lun" 26.10.20.3 secondary-old
fixture "$REMOTE" 26.10.24.1 new
target=outer-target tmp=outer-temp expected_hash=outer-hash
update_lun_script
cmp "$ENTRY" "$REMOTE"
cmp "$HOME/bin/lun" "$REMOTE"
[[ $(lun_script_version "$ENTRY.update-backup") == V26.10.20.3 ]]
[[ $LUN_UPDATED_ENTRY == "$ENTRY" ]]
[[ $target == outer-target && $tmp == outer-temp && $expected_hash == outer-hash ]]
[[ -z $(find "$TMP" -name '*.tmp.*' -o -name '*.update.*') ]]
echo 'ok - real downloader/install chain replaces the command, not the temporary file'

# Same version, changed content is still an update; identical content is a verified no-op.
fixture "$REMOTE" 26.10.24.1 new-content
update_lun_script
cmp "$ENTRY" "$REMOTE"
update_lun_script
[[ $LUN_UPDATED_ENTRY == "$ENTRY" ]]
cp "$ENTRY" "$TMP/expected"
fixture "$REMOTE" 26.10.20.3 older
update_lun_script
cmp "$ENTRY" "$TMP/expected"
[[ -z $LUN_UPDATED_ENTRY ]]
printf 'not a shell script\n' > "$REMOTE"
! update_lun_script
cmp "$ENTRY" "$TMP/expected"
[[ -z $LUN_UPDATED_ENTRY ]]
fixture "$REMOTE" 26.10.24.2 syntax-check
printf 'if broken\n' >> "$REMOTE"
! update_lun_script
cmp "$ENTRY" "$TMP/expected"
download_ok=no
! update_lun_script
cmp "$ENTRY" "$TMP/expected"
[[ -z $LUN_UPDATED_ENTRY ]]
echo 'ok - same-version changes, verified no-op, downgrade and corrupt/download failures'

(
  update_local_lun_bundle(){ LUN_UPDATED_ENTRY=$ENTRY; return 1; } # Core failure must not strand a successfully updated menu.
  lun_reopen_updated_menu(){ printf 'reopened\n' > "$TMP/reopened"; }
  service_update_menu <<< $'4\n' >/dev/null
  [[ $(cat "$TMP/reopened") == reopened ]]
)
(
  export vlpt=12345 xcpt=23456 vwp=yes domain=old.example.com certmode=dns ONECLICK_FORCE_CERT=yes
  printf '#!/usr/bin/env bash\n[[ -z ${vlpt+x} && -z ${xcpt+x} && -z ${vwp+x} && -z ${domain+x} && -z ${certmode+x} && -z ${ONECLICK_FORCE_CERT+x} ]] || exit 9\nprintf "new-menu-loaded\\n"\n' > "$ENTRY"
  LUN_UPDATED_ENTRY=$ENTRY
  lun_reopen_updated_menu
) > "$TMP/reloaded"
[[ $(cat "$TMP/reloaded") == new-menu-loaded ]]
echo 'ok - return from update loads the installed menu without inherited install arguments'

(
  # Simulate an interactive terminal without requiring PTYs on Windows.
  tty_available=yes
  [(){ if [[ $# == 3 && $1 == -t && $2 == 1 ]]; then [[ $tty_available == yes ]]; else builtin [ "$@"; fi; }
  PATH="$TMP/empty" TERM=xterm
  unset NO_COLOR COLORTERM
  lun_init_colors
  [[ $LUN_CYAN == $'\033[36m' && $LUN_RESET == $'\033[0m' && $LUN_COLOR_COUNT == 8 ]]
  TERM=xterm-256color
  lun_init_colors
  [[ $LUN_ORANGE == $'\033[38;5;208m' && $LUN_COLOR_COUNT == 256 ]]
  tput(){ return 1; } # Missing terminfo behaves like missing tput.
  TERM=xterm
  lun_init_colors
  [[ $LUN_CYAN == $'\033[36m' ]]
  tty_available=no
  lun_init_colors
  [[ -z $LUN_CYAN && $LUN_COLOR_COUNT == 0 ]]
  tty_available=yes TERM=dumb
  lun_init_colors
  [[ -z $LUN_CYAN ]]
  TERM=xterm NO_COLOR=1
  lun_init_colors
  [[ -z $LUN_CYAN ]]
)
echo 'ok - ANSI fallback without tput/terminfo; redirected and explicitly disabled color stays plain'
