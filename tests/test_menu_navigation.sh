#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/lun.sh"
for helper in prompt_port pick_protocols configure_addym_menu lun_menu; do
  [[ $(grep -c "^${helper}(){" "$SCRIPT") == 1 ]]
done
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
  load_function cluster_menu
  cluster_installed() { return 0; }
  cluster_role() { printf 'disabled\n'; }
  cluster_is_federation() { [[ $calls == $'install\n' ]]; }
  cluster_legacy_present() { return 1; }
  cluster_install() { record install; }
  cluster_federation_menu() { record menu; }
  calls=
  output=$(cluster_menu <<< '0')
  [[ $output == *'一键开启本机联邦身份'* ]]
  [[ $output != *'配置无效'* && -z $calls ]]
  cluster_menu <<< '1' >/dev/null
  [[ $calls == $'install\nmenu\n' ]]
)

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
  cluster_service_restart() { record restart; return "$restart_rc"; }
  cluster_write_install_payload() { :; }
  cluster_push_event() { :; }
  mktemp() { command mktemp; }
  cluster_cmd() {
    case "$1" in
      service-current) record "$*"; return "$service_current_rc" ;;
      update-all) record "$*"; return 0 ;;
      *) printf 'unexpected cluster command: %s\n' "$*" >&2; return 1 ;;
    esac
  }
  update_lun_script() { official_calls=$((official_calls + 1)); return 1; }
  official_calls=0
  service_current_rc=0
  restart_rc=0
  calls=
  # 本机来源不依赖 GitHub；当前服务就绪时不得重启。
  cluster_update_all_ui <<< $'\n\n' >/dev/null
  [[ $official_calls -eq 0 && $calls == $'service-current\nupdate-all --script-payload '* ]]

  # 旧监听需先重启，再下发；重启失败不得继续分发。
  service_current_rc=1
  calls=
  cluster_update_all_ui <<< $'\n\n' >/dev/null
  [[ $official_calls -eq 0 && $calls == $'service-current\nrestart\nupdate-all --script-payload '* ]]
  restart_rc=1
  calls=
  if cluster_update_all_ui <<< $'\n\n' >/dev/null; then
    echo 'failed service restart unexpectedly started an update' >&2
    exit 1
  fi
  [[ $calls == $'service-current\nrestart\n' ]]

  # 官方来源更新失败、取消或 EOF 时，不检查服务、不重启、不分发。
  calls=
  if cluster_update_all_ui <<< $'2\n\n' >/dev/null; then
    echo 'official update failure was ignored' >&2
    exit 1
  fi
  [[ $official_calls -eq 1 && -z $calls ]]
  cancel_rc=0
  cluster_update_all_ui <<< '0' >/dev/null || cancel_rc=$?
  [[ $cancel_rc -eq 2 && $official_calls -eq 1 && -z $calls ]]
  eof_rc=0
  cluster_update_all_ui </dev/null >/dev/null || eof_rc=$?
  [[ $eof_rc -eq 2 && $official_calls -eq 1 && -z $calls ]]
)

printf 'ok - menu navigation and local-version distribution\n'
