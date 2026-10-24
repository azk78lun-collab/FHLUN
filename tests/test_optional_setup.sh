#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/lun.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp" PYTHONIOENCODING=utf-8
mkdir -p "$HOME/lun"
LUN_GREEN= LUN_YELLOW= LUN_RESET=
load_function() {
  eval "$(awk -v target="$1" '
    $0 ~ "^" target "\\(\\)\\{" {capture=1; print; next}
    capture && /^[A-Za-z_][A-Za-z_0-9]*\(\)\{/ {exit}
    capture {print}
  ' "$SCRIPT")"
}
record(){ printf '%s\n' "$*" >> "$tmp/calls"; }
red_line(){ printf '%s\n' "$*" >&2; }
green_line(){ :; }
yellow_line(){ :; }
ui_title(){ :; }
ui_pause(){ :; }
for fn in valid_domain is_ip_literal public_cert_subject prepare_runtime_cert \
    cert_reusable_for_request configure_public_domain_certificate oneclick_setup_menu \
    install_protocol_menu; do load_function "$fn"; done

# The self-signed fallback must never become a public-certificate request.
(
  load_domain_cert_config(){ :; }
  issue_public_domain_cert(){ record "http $*"; }
  issue_acme_cert(){ record "acme $*"; }
  cert_reusable_for_request(){ return 1; }
  sync_cert_metadata(){ :; }
  domain= ONECLICK_FORCE_CERT=no
  printf 'www.bing.com\n' > "$HOME/lun/cert_subject"
  for certmode in domain dns; do
    ! prepare_runtime_cert
    [[ ! -f "$tmp/calls" ]]
  done
  for domain in none del 192.0.2.1 https://proxy.example.com; do
    ! public_cert_subject >/dev/null
  done
  domain=proxy.example.com
  certmode=domain
  prepare_runtime_cert
  [[ $(cat "$tmp/calls") == 'http proxy.example.com' ]]
  rm "$tmp/calls"
  certmode=dns
  prepare_runtime_cert
  [[ $(cat "$tmp/calls") == 'acme dns proxy.example.com' ]]
  rm "$tmp/calls"
  domain=
  printf 'saved.example.com\n' > "$HOME/lun/domain"
  prepare_runtime_cert
  [[ $(cat "$tmp/calls") == 'acme dns saved.example.com' ]]
  rm "$tmp/calls" "$HOME/lun/domain"

  # Valid matching certificates are reused in a non-TTY rebuild, not reissued.
  cert_reusable_for_request(){ [[ $2 == proxy.example.com ]]; }
  cert_hash_update(){ record hash; }
  domain=proxy.example.com
  prepare_runtime_cert
  [[ $(cat "$tmp/calls") == hash ]]
  rm "$tmp/calls"
)
echo 'ok - public issuance never falls back to a self-signed or Reality name'

(
  load_function issue_public_domain_cert
  domain=
  saved_dns_acme_available(){ return "$dns_rc"; }
  issue_acme_cert(){ record "$*"; }
  dns_rc=0
  ! issue_public_domain_cert ''
  [[ ! -f "$tmp/calls" ]]
  issue_public_domain_cert proxy.example.com
  [[ $(cat "$tmp/calls") == 'dns proxy.example.com' ]]
  rm "$tmp/calls"
  dns_rc=1
  issue_public_domain_cert proxy.example.com
  [[ $(cat "$tmp/calls") == 'domain proxy.example.com' ]]
  rm "$tmp/calls"
)
echo 'ok - automatic domain certificate uses saved DNS credentials or HTTP-01 only'

(
  cert_key_matches(){ return 0; }
  openssl(){ return 0; }
  cert_publicly_trusted_for_domain(){ [[ $2 == proxy.example.com ]]; }
  cert_reusable_for_request dns proxy.example.com
  ! cert_reusable_for_request domain other.example.com
  ! cert_reusable_for_request ip 192.0.2.1
  cert_publicly_trusted_for_domain(){ return 1; }
  ! cert_reusable_for_request domain proxy.example.com
  openssl(){ return 1; }
  ! cert_reusable_for_request any ''
)
echo 'ok - expired, mismatched and self-signed certificates cannot satisfy public requests'

(
  domain=old.example.com
  printf '%s\n' "$domain" > "$HOME/lun/domain"
  printf 'old certificate\n' > "$HOME/lun/cert.crt"
  printf 'unchanged\n' > "$HOME/lun/cdnym"
  printf 'unchanged\n' > "$HOME/lun/sbargotoken.log"
  printf '20000\n' > "$HOME/lun/port_xc"
  prompt_service_domain(){ domain=new.example.com; printf '%s\n' "$domain" > "$HOME/lun/domain"; }
  prompt_acme_email(){ return 0; }
  cert_reusable_for_request(){ return 1; }
  issue_public_domain_cert(){ record "issue $*"; return "$issue_rc"; }
  issue_rc=1
  ! configure_public_domain_certificate
  [[ $domain == old.example.com && $(cat "$HOME/lun/domain") == old.example.com ]]
  [[ $(cat "$HOME/lun/cert.crt") == 'old certificate' ]]
  [[ $(cat "$tmp/calls") == 'issue new.example.com' ]]
  rm "$tmp/calls"
  issue_rc=0
  configure_public_domain_certificate
  [[ $domain == new.example.com && $(cat "$HOME/lun/domain") == new.example.com ]]
  [[ $(cat "$HOME/lun/cdnym") == unchanged && $(cat "$HOME/lun/sbargotoken.log") == unchanged ]]
  [[ $(cat "$HOME/lun/port_xc") == 20000 ]]
  rm "$tmp/calls"
  prompt_service_domain(){ domain=; rm "$HOME/lun/domain"; return 2; }
  rc=0
  configure_public_domain_certificate || rc=$?
  [[ $rc == 2 && $domain == new.example.com && $(cat "$HOME/lun/domain") == new.example.com ]]
  [[ ! -f "$tmp/calls" ]]
  # Missing previous domain is also restored on failure.
  domain=; rm "$HOME/lun/domain"
  prompt_service_domain(){ domain=new.example.com; printf '%s\n' "$domain" > "$HOME/lun/domain"; }
  issue_rc=1
  ! configure_public_domain_certificate
  [[ -z $domain && ! -f "$HOME/lun/domain" ]]
  rm "$tmp/calls"
)
echo 'ok - domain-only failure/cancellation restores the domain; unrelated settings remain intact'

(
  configure_public_domain_certificate(){ record certificate; }
  prompt_cdn(){ record cdn; CDN_REBUILD_REQUIRED=$rebuild; }
  argo_network_menu(){ record tunnel; LUN_MENU_ACTION=rep; }
  prompt_origin_rules(){ record origin; CDN_REBUILD_REQUIRED=$rebuild; }
  oneclick_full_setup(){ record full; }
  load_installed_protocol_flags(){ record protocols; }
  for choice in 1 2 3 4 5; do
    rebuild=no CLOUDFLARE_PROTOCOL_PORT_CHANGED=no
    LUN_MENU_ACTION=menu
    oneclick_setup_menu <<< "$choice" >/dev/null
    expected=
    case $choice in
      1) expected=certificate; [[ $LUN_MENU_ACTION == list ]] ;;
      2) expected=cdn; [[ $LUN_MENU_ACTION == list ]] ;;
      3) expected=tunnel; [[ $LUN_MENU_ACTION == rep ]] ;;
      4) expected=origin; [[ $LUN_MENU_ACTION == list ]] ;;
      5) expected=full; [[ $LUN_MENU_ACTION == rep ]] ;;
    esac
    [[ $(cat "$tmp/calls") == "$expected" ]]
    rm "$tmp/calls"
  done
  for choice in 2 4; do
    rebuild=yes
    oneclick_setup_menu <<< "$choice" >/dev/null
    [[ $LUN_MENU_ACTION == rep && $(tail -n1 "$tmp/calls") == protocols ]]
    rm "$tmp/calls"
  done
  rc=0; oneclick_setup_menu </dev/null >/dev/null || rc=$?
  [[ $rc == 2 && ! -f "$tmp/calls" ]]
  rc=0; oneclick_setup_menu <<< 0 >/dev/null || rc=$?
  [[ $rc == 2 && ! -f "$tmp/calls" ]]
  oneclick_setup_menu(){ record optional; LUN_MENU_ACTION=list; }
  install_protocol_menu <<< 3 >/dev/null
  [[ $(cat "$tmp/calls") == optional && $LUN_MENU_ACTION == list ]]
  rm "$tmp/calls"
)
echo 'ok - optional setup dispatch is isolated and preserves each requested action'

# Both cores must propagate certificate preparation failures, not continue with old files.
grep -Fq 'prepare_runtime_cert || { echo "XHTTP TLS 证书准备失败。"; return 1; }' "$SCRIPT"
grep -Fq 'prepare_runtime_cert || { echo "Sing-box 证书准备失败。"; return 1; }' "$SCRIPT"
echo 'ok - core installers stop on certificate preparation failure'
