#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

awk '/# BEGIN Lun banner UI/{copy=1} copy{print} /# END Lun banner UI/{exit}' \
  "$repo/lun.sh" > "$tmp/banner-functions.sh"

export HOME="$tmp/home"
mkdir -p "$HOME/lun"
LUN_BOLD=$'\033[1m'
LUN_BANNER_CYAN=$'\033[36m'
LUN_BANNER_WHITE=$'\033[37m'
LUN_ORANGE=$'\033[33m'
LUN_RESET=$'\033[0m'
source "$tmp/banner-functions.sh"

fail(){ printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_eq(){ [[ "$1" == "$2" ]] || fail "expected [$2], got [$1]"; }

assert_eq "$(LUN_BANNER_TEST_COLS=71 LUN_BANNER_TEST_LINES=50 lun_banner_ascii_size)" compact
assert_eq "$(LUN_BANNER_TEST_COLS=72 LUN_BANNER_TEST_LINES=25 lun_banner_ascii_size)" small
assert_eq "$(LUN_BANNER_TEST_COLS=96 LUN_BANNER_TEST_LINES=31 lun_banner_ascii_size)" medium
assert_eq "$(LUN_BANNER_TEST_COLS=120 LUN_BANNER_TEST_LINES=37 lun_banner_ascii_size)" large

for spec in small:12:72 medium:18:96 large:24:120; do
  IFS=: read -r size expected_lines expected_width <<< "$spec"
  lun_banner_ascii_data "$size" > "$tmp/$size.marked"
  sed 's/@[CWO]@//g' "$tmp/$size.marked" > "$tmp/$size.txt"
  [[ $(wc -l < "$tmp/$size.txt") -eq $expected_lines ]] || fail "$size line count"
  awk -v max="$expected_width" 'length($0)>max{exit 1}' "$tmp/$size.txt" || fail "$size exceeds width"
  LC_ALL=C grep -q '[^ -~]' "$tmp/$size.txt" && fail "$size contains non-ASCII art"
  grep -q '[^ .+*#@-]' "$tmp/$size.txt" && fail "$size contains an unexpected glyph"
done

lun_banner_render_ascii medium > "$tmp/rendered.txt"
grep -q '@[CWO]@' "$tmp/rendered.txt" && fail "color marker leaked"
[[ $(wc -l < "$tmp/rendered.txt") -eq 18 ]] || fail "rendered medium line count"

clear(){ :; }
LUN_BANNER_ALLOW_NONTTY=1
LUN_BANNER_TEST_COLS=96
LUN_BANNER_TEST_LINES=31
TERM=xterm
export LUN_BANNER_ALLOW_NONTTY LUN_BANNER_TEST_COLS LUN_BANNER_TEST_LINES TERM
lun_splash > "$tmp/splash.txt"
[[ $(wc -l < "$tmp/splash.txt") -eq 21 ]] || fail "splash should contain medium art, title, intro and prompt"
grep -q '正在准备主面板，完成后自动进入' "$tmp/splash.txt" || fail "automatic dashboard preparation prompt missing"
! grep -q '秒后自动继续' "$tmp/splash.txt" || fail "automatic splash timeout remains"
! grep -q '按任意键' "$tmp/splash.txt" || fail "any-key trigger remains"
! grep -q '按 Enter' "$tmp/splash.txt" || fail "confirmation prompt remains"

lun_panel_header > "$tmp/header.txt"
[[ $(wc -l < "$tmp/header.txt") -eq 2 ]] || fail "panel header should use two compact lines"
grep -q 'Lun' "$tmp/header.txt" || fail "panel title missing"
grep -q '多协议统一接入 · 多 VPS 集群联动 · 多用户精细管理' "$tmp/header.txt" || fail "panel introduction missing"

unset LUN_BANNER_ALLOW_NONTTY
[[ -z "$(lun_splash)" ]] || fail "non-TTY splash emitted output"
LUN_BANNER_ALLOW_NONTTY=1 TERM=dumb lun_splash > "$tmp/dumb.txt"
[[ ! -s "$tmp/dumb.txt" ]] || fail "TERM=dumb should skip splash"
LUN_BANNER_ALLOW_NONTTY=1 TERM=xterm LUN_BANNER_TEST_COLS=71 LUN_BANNER_TEST_LINES=50 lun_splash > "$tmp/narrow.txt"
[[ ! -s "$tmp/narrow.txt" ]] || fail "narrow terminal should skip splash"

dashboard=$(sed -n '/^lun_dashboard_render(){/,/^}/p' "$repo/lun.sh")
[[ $dashboard != *'lun_splash'* && $dashboard != *'lun_banner'* ]] || fail "dashboard still contains the splash"
[[ $dashboard == *'lun_panel_header'* ]] || fail "dashboard header is not persistent"
[[ $(grep -c '^lun_splash$' "$repo/lun.sh") -eq 1 ]] || fail "splash must be called exactly once"
[[ $(grep -c '^lun_menu_prepare$' "$repo/lun.sh") -eq 1 ]] || fail "main menu must be prepared exactly once"
grep -q '^lun_menu_prepare(){' "$repo/lun.sh" || fail "menu preparation function missing"
grep -q '^lun_menu_screen(){' "$repo/lun.sh" || fail "prepared menu display function missing"
! grep -q '欢迎界面模式' "$repo/lun.sh" || fail "welcome mode menu remains"
! grep -q 'banner_mode' "$repo/lun.sh" || fail "legacy banner setting remains"

for removed in lun_banner_send_kitty lun_banner_send_wezterm download_lun_banner_asset lun-wheel.png '1337;File'; do
  ! grep -q "$removed" "$repo/lun.sh" || fail "removed image feature remains: $removed"
done

printf 'startup splash tests: PASS\n'
