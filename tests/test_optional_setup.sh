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

(
  for fn in lun_version_is_older vless_ws_vision_enabled xray_supports_ws_vision \
      prepare_vless_ws_vision prompt_vless_ws_vision installxray; do load_function "$fn"; done
  mkdir -p "$HOME/lun/xrk"
  printf 'test-encryption\n' > "$HOME/lun/xrk/enkey"
  printf 'test-decryption\n' > "$HOME/lun/xrk/dekey"
  cat > "$HOME/lun/xray" <<'EOF'
#!/bin/sh
printf 'Xray %s\n' "$XRAY_FIXTURE_VERSION"
EOF
  chmod +x "$HOME/lun/xray"
  export XRAY_FIXTURE_VERSION=26.3.27
  insuuid(){ uuid=00000000-0000-4000-8000-000000000001; }
  ensure_cdn_origin_cert(){ :; }
  xray_stream_security_block(){ printf '        "security": "none",\n'; }
  xhp= vlp= vxp= xup= xcp= vwp=yes port_vw=8080 cdnym= ym_vl_re=
  (installxray) >/dev/null
  ! grep -Fq 'xtls-rprx-vision' "$HOME/lun/xr.json"
  [[ ! -e "$HOME/lun/vless_ws_vision" ]]
  XRAY_FIXTURE_VERSION=26.3.26
  ! prompt_vless_ws_vision <<< '1' >/dev/null 2>&1
  [[ ! -e "$HOME/lun/vless_ws_vision" ]]
  XRAY_FIXTURE_VERSION=26.3.27
  prompt_vless_ws_vision <<< '1' >/dev/null
  [[ ! -e "$HOME/lun/vless_ws_vision" ]]
  (installxray) >/dev/null
  grep -Fq '"id": "00000000-0000-4000-8000-000000000001", "flow": "xtls-rprx-vision"' "$HOME/lun/xr.json"
  grep -Fq '"decryption": "test-decryption"' "$HOME/lun/xr.json"
  vless_ws_vision_enabled
  prompt_vless_ws_vision <<< '2' >/dev/null
  (installxray) >/dev/null
  ! grep -Fq 'xtls-rprx-vision' "$HOME/lun/xr.json"
)
echo 'ok - WS Vision is opt-in, gated by Xray version, and reversible'

(
  for fn in argo_configured_protocol argo_origin_port load_saved_argo \
      append_argo_xhttp_links prompt_argo_protocol_seed prompt_argo protocol_capability_mark \
      valid_port_value normalize_host host_is_ipv6 uri_host; do load_function "$fn"; done
  is_nat_mode(){ return 0; }
  ensure_port_available(){ [[ $1 == 8080 ]]; }
  inner_port_from_public(){ [[ $1 == 28080 ]] && echo 8080 || true; }
  port_valid(){ valid_port_value "$1"; }
  show_port_mapping_hint(){ :; }
  cdn_origin_tls_for_port(){ [[ ${tls:-no} == yes ]]; }
  valid_addym(){ [[ $1 == tunnel.example.test ]]; }
  sanitize_argo_token(){ printf '%s\n' "$1"; }
  prompt_argo_ip(){ return 0; }
  port_vm_ws= port_vw= port_vx= argo=
  rm -f "$HOME/lun/port_vw"
  prompt_argo <<< $'3\n28080\n\n\n\n' >/dev/null
  [[ $argo == vxpt && $vxpt == 8080 && $vxp == yes && $LUN_ARGO_EDITED == yes ]]

  printf '8080\n' > "$HOME/lun/port_vx"
  printf 'Vlessx\n' > "$HOME/lun/vlvm"
  printf 'tunnel.example.test\n' > "$HOME/lun/sbargoym.log"
  printf 'mock-token\n' > "$HOME/lun/sbargotoken.log"
  load_saved_argo
  [[ $argo == vxpt && $ARGO_DOMAIN == tunnel.example.test && $ARGO_AUTH == mock-token ]]
  [[ $(argo_origin_port "$argo") == 8080 && $(protocol_capability_mark 3 tunnel) == ✓ ]]
  tls=yes
  ! prompt_argo <<< '3' >/dev/null 2>&1
  tls=no
  prompt_argo <<< $'3\ntunnel.example.test\nmock-token\n' >/dev/null
  [[ $argo == vxpt && $ARGO_DOMAIN == tunnel.example.test && $ARGO_AUTH == mock-token ]]
  routed_node_name(){ printf '[测试]%s-01\n' "$1"; }
  uuid=00000000-0000-4000-8000-000000000001 enkey=test-encryption argodomain=$ARGO_DOMAIN
  argo_entries='tunnel.example.test|01 2001:db8::1|02'
  append_argo_xhttp_links > "$tmp/argo-display"
  cmp "$HOME/lun/jhsub.txt" "$tmp/argo-display"
  [[ $(wc -l < "$tmp/argo-display") == 2 ]]
  grep -Fq '@tunnel.example.test:443?encryption=test-encryption&flow=xtls-rprx-vision&type=xhttp' "$tmp/argo-display"
  grep -Fq '@[2001:db8::1]:443?' "$tmp/argo-display"
  grep -Fq "host=$argodomain&path=/$uuid-vx&mode=packet-up&security=tls&sni=$argodomain" "$tmp/argo-display"
  grep -Fq '#[测试]vless-xhttp-argo-tls-443-ar02-01' "$tmp/argo-display"
)
echo 'ok - XHTTP tunnel stays on the internal HTTP port and exports TLS 443 with the right Host, path and flow'
