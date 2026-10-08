#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/lun.sh"
LUN_CYAN= LUN_YELLOW= LUN_RESET=
ui_title() { :; }
ui_dash() { :; }
ui_pause() { :; }
yellow_line() { :; }
green_line() { :; }
red_line() { :; }

load_function() {
  eval "$(awk -v target="$1" '
    $0 ~ "^" target "\\(\\)\\{" { capture=1 }
    capture {
      print
      line=$0
      opens=gsub(/\{/, "{", line)
      closes=gsub(/\}/, "}", line)
      depth+=opens-closes
      if (started && depth==0) exit
      started=1
    }
  ' "$SCRIPT")"
}
record() { calls+="$*"$'\n'; }

(
  load_function visit_monitor_ui
  visit_monitor_enabled() { return 1; }
  visit_monitor_activity_ui() { record activity; }
  visit_monitor_statistics_ui() { record statistics; }
  visit_monitor_control_ui() { record control; }
  visit_monitor_settings_ui() { record settings; }
  visit_monitor_maintenance_ui() { record maintenance; }
  calls=
  visit_monitor_ui <<< $'1\n2\n3\n4\n5\n0' >/dev/null
  [[ $calls == $'activity\nstatistics\ncontrol\nsettings\nmaintenance\n' ]]
)
(
  load_function visit_monitor_activity_ui
  multiuser_visit_refresh() { :; }
  multiuser_cmd() { record "$*"; }
  multiuser_visit_filter_ui() { record filter; }
  calls=
  visit_monitor_activity_ui <<< $'1\n2\n3\n0' >/dev/null
  [[ $calls == *'--view smart --noise auto'* ]]
  [[ $calls == *'--view raw --noise show'* ]]
  [[ $calls == *$'filter\n' ]]
)
(
  load_function visit_monitor_statistics_ui
  multiuser_visit_refresh() { :; }
  multiuser_cmd() { record "$*"; }
  calls=
  visit_monitor_statistics_ui <<< $'1\n2\n0' >/dev/null
  [[ $calls == *'--group domain --noise auto'* ]]
  [[ $calls == *'--group user --noise auto'* ]]
)
(
  load_function visit_monitor_control_ui
  visit_monitor_enable() { record enable; }
  visit_monitor_disable() { record disable; }
  calls=
  visit_monitor_control_ui <<< $'1\n2\n0' >/dev/null
  [[ $calls == $'enable\ndisable\n' ]]
)
(
  load_function visit_monitor_settings_ui
  visit_monitor_filter_ui() { record filter; }
  visit_monitor_storage_ui() { record storage; }
  calls=
  visit_monitor_settings_ui <<< $'1\n2\n0' >/dev/null
  [[ $calls == $'filter\nstorage\n' ]]
)
(
  load_function cluster_federation_menu
  load_function cluster_maintenance_ui
  cluster_show_nodes() { :; }
  cluster_enabled() { return 0; }
  cluster_server_management_ui() { record servers; }
  cluster_add_server_ui() { record add; }
  cluster_show_subscription_links() { record subscriptions; }
  cluster_sync_ui() { record sync; }
  cluster_cdn_sync_ui() { record cdn; }
  cluster_settings_ui() { record settings; }
  calls=
  # 集群 5 -> 维护 2 才能进入 CDN 同步；返回后其它入口仍能正常调度。
  cluster_federation_menu <<< $'1\n2\n3\n4\n5\n2\n0\n6\n0' >/dev/null
  [[ $calls == $'servers\nadd\nsubscriptions\nsync\ncdn\nsettings\n' ]]
)
(
  load_function cluster_server_management_ui
  cluster_show_nodes() { :; }
  cluster_node_action_ui() { record single; }
  cluster_batch_action_ui() { record batch; }
  cluster_location_ui() { record region; }
  cluster_remove_member_ui() { record revoke; }
  calls=
  cluster_server_management_ui <<< $'1\n2\n3\n4\n0' >/dev/null
  [[ $calls == $'single\nbatch\nregion\nrevoke\n' ]]
)
(
  load_function cluster_add_server_ui
  cluster_cmd() { record "$*"; }
  cluster_join_ui() { record join; }
  calls=
  cluster_add_server_ui <<< $'1\n2\n0' >/dev/null
  [[ $calls == $'federation-join-code\njoin\n' ]]
)
(
  load_function cluster_update_all_ui
  cluster_show_nodes() { :; }
  cluster_untrusted_member_numbers() { :; }
  lun_update_target() { printf '%s\n' "$SCRIPT"; }
  cluster_module_dir() { printf '%s\n' "$ROOT/modules/cluster"; }
  cluster_install_service() { :; }
  cluster_service_restart() { :; }
  cluster_write_install_payload() { :; }
  cluster_push_event() { :; }
  mktemp() { command mktemp; }
  cluster_cmd() { [[ $1 == update-all ]]; record "$*"; }
  update_lun_script() { official_calls=$((official_calls + 1)); return 1; }
  official_calls=0
  calls=
  # 本机来源即使 GitHub 不可达也继续；官方来源更新失败时不得分发。
  cluster_update_all_ui <<< $'\n\n' >/dev/null
  [[ $official_calls -eq 0 && $calls == 'update-all --script-payload '* ]]
  calls=
  if cluster_update_all_ui <<< $'2\n\n' >/dev/null; then
    echo 'official update failure was ignored' >&2
    exit 1
  fi
  [[ $official_calls -eq 1 && -z $calls ]]
  if cluster_update_all_ui </dev/null >/dev/null; then
    echo 'EOF unexpectedly started an update' >&2
    exit 1
  fi
  [[ -z $calls ]]
)

printf 'ok - menu navigation and local-version distribution\n'
