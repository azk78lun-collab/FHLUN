#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
for helper in acme_stage_dir acme_http_pre acme_http_post acme_http_method \
    ensure_lun_acme_cron acme_renew_cron acme_preserve_nginx_target \
    acme_cert_transaction deploy_acme_cert reload_runtime_after_cert \
    cert_key_matches cert_hash_update issue_acme_cert; do
  eval "$(awk -v target="$helper" '
    $0 ~ "^" target "\\(\\)\\{" {capture=1; print; next}
    capture && /^[A-Za-z_][A-Za-z_0-9]*\(\)\{/ {exit}
    capture {print}
  ' "$ROOT/lun.sh")"
done
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp" PYTHONIOENCODING=utf-8
# MSYS cannot apply mkdir's POSIX mode at creation; Linux still tests it natively.
if [[ ${OSTYPE:-} == msys* ]]; then
  mkdir(){ if [[ ${1:-} == -m ]]; then shift 2; fi; command mkdir "$@"; }
  flock(){ :; } # Windows smoke check; Linux exercises the real file locks.
fi
mkdir -p "$HOME/lun/modules/multiuser" "$HOME/.acme.sh"
calls="$tmp/calls"; : > "$calls"
red_line(){ printf '%s\n' "$*" >&2; }
green_line(){ :; }
yellow_line(){ :; }
pidof(){ [[ $1 == systemd ]]; }
nginx(){
  [[ ! -f "$tmp/nginx-invalid" ]] || return 1
  if [[ $1 == -T ]]; then
    echo 'server_name example.test;'
    [[ ! -f "$tmp/nginx-challenge" ]] || echo 'location ^~ /.well-known/acme-challenge/ { alias /var/lib/acme-challenge/; }'
  fi
  return 0
}
systemctl(){
  printf '%s\n' "$*" >> "$calls"
  case "$1" in
    is-active) [[ -f "$tmp/active-${*: -1}" ]] ;;
    stop) rm -f "$tmp/active-$2" ;;
    start) [[ ! -f "$tmp/start-fails" ]] || return 1; : > "$tmp/active-$2" ;;
    restart|reload-or-restart)
      if [[ -f "$tmp/reload-fails" ]]; then rm -f "$tmp/reload-fails"; return 1; fi
      : > "$tmp/active-$2" ;;
    *) return 1 ;;
  esac
}
ss(){
  echo 'State Recv-Q Send-Q Local Address:Port Peer Address:Port Process'
  if [[ -f "$tmp/unknown" ]]; then echo 'LISTEN 0 10 0.0.0.0:80 0.0.0.0:* users:(("other",pid=999,fd=1))'
  elif [[ -f "$tmp/active-nginx" ]]; then echo 'LISTEN 0 10 0.0.0.0:80 0.0.0.0:* users:(("nginx",pid=1,fd=1))'; fi
}
acme_http_owner_service(){ [[ $1 == 1 ]] && echo 'systemd|nginx'; }
acme_challenge_firewall_open(){ : > "$tmp/firewall-open"; }
acme_challenge_firewall_close(){ rm -f "$tmp/firewall-open"; }
: > "$tmp/active-nginx"
acme_http_pre standalone
[[ ! -f "$tmp/active-nginx" && -f "$tmp/firewall-open" ]]
acme_http_post
[[ -f "$tmp/active-nginx" && ! -d "$HOME/lun/.acme-http80" && ! -f "$tmp/firewall-open" ]]
acme_http_post
[[ -f "$tmp/active-nginx" ]]
echo 'ok - borrowed port 80 restored; cleanup idempotent'
acme_http_pre standalone
: > "$tmp/start-fails"
! acme_http_post
[[ -f "$HOME/lun/.acme-http80/services" && ! -f "$tmp/active-nginx" ]]
rm "$tmp/start-fails"
acme_http_post
[[ -f "$tmp/active-nginx" && ! -d "$HOME/lun/.acme-http80" ]]
echo 'ok - failed service restoration retains a retryable lease'
: > "$tmp/unknown"
! acme_http_pre standalone
[[ -f "$tmp/active-nginx" && ! -d "$HOME/lun/.acme-http80" ]]
rm "$tmp/unknown"
: > "$tmp/nginx-invalid"
! acme_http_pre standalone
[[ -f "$tmp/active-nginx" ]]
rm "$tmp/nginx-invalid"
[[ $(acme_http_method example.test) == nginx ]]
: > "$tmp/nginx-challenge"
[[ $(acme_http_method example.test) == standalone ]]
rm "$tmp/nginx-challenge"
acme_http_pre nginx
[[ -f "$tmp/active-nginx" ]]
acme_http_post
echo 'ok - unknown owner rejected; Nginx mode does not stop service'

cronfile="$tmp/crontab"
printf '%s\n' '0 0 * * * bash ~/.acme.sh/acme.sh --cron >/dev/null 2>&1' '5 3 * * * unrelated-job' > "$cronfile"
crontab(){ if [[ $1 == -l ]]; then cat "$cronfile"; else cp "$1" "$cronfile"; fi; }
ensure_lun_acme_cron
ensure_lun_acme_cron
[[ $(grep -c 'cert-renew-cron' "$cronfile") == 1 ]]
grep -q 'unrelated-job' "$cronfile"
! grep -q -- 'acme.sh --cron' "$cronfile"
echo 'ok - daily renewal cron idempotent; unrelated tasks preserved'

stage=$(acme_stage_dir example.test)
mkdir -p "$stage"
for kind in old new; do
  (cd "$tmp" && MSYS_NO_PATHCONV=1 openssl req -x509 -newkey rsa:2048 -nodes -days 2 \
    -subj '/CN=example.test' -addext 'subjectAltName=DNS:example.test' \
    -keyout "$kind.key" -out "$kind.crt" >/dev/null 2>&1)
done
cp "$tmp/old.key" "$HOME/lun/private.key"; cp "$tmp/old.crt" "$HOME/lun/cert.crt"
cp "$tmp/new.key" "$stage/private.key"; cp "$tmp/new.crt" "$stage/cert.crt"
printf '{"scheme":"http","public_host":"example.test","port":27260,"legacy_token":"unchanged"}\n' > "$HOME/lun/modules/multiuser/config.json"
cp "$HOME/lun/modules/multiuser/config.json" "$tmp/config-before"
config_metadata=$(stat -c '%a:%u:%g' "$HOME/lun/modules/multiuser/config.json")
cert_covers_domain(){ openssl x509 -in "$1" -noout -checkhost "$2" >/dev/null 2>&1; }
cert_publicly_trusted_for_domain(){ return 0; } # Test fixtures are self-signed; production verifier is unchanged.
multiuser_config_value(){ python3 - "$HOME/lun/modules/multiuser/config.json" "$1" <<'PY'
import json,sys
print(json.load(open(sys.argv[1])).get(sys.argv[2],''))
PY
}
acme_subscription_ready(){ [[ ! -f "$tmp/probe-fails" ]]; }
: > "$tmp/active-lun-agent"
cp "$tmp/old.key" "$stage/private.key"
! deploy_acme_cert example.test domain
cmp "$HOME/lun/cert.crt" "$tmp/old.crt"
cmp "$HOME/lun/modules/multiuser/config.json" "$tmp/config-before"
[[ $(stat -c '%a:%u:%g' "$HOME/lun/modules/multiuser/config.json") == "$config_metadata" ]]
cp "$tmp/new.key" "$stage/private.key"
: > "$tmp/reload-fails"
! deploy_acme_cert example.test domain
cmp "$HOME/lun/cert.crt" "$tmp/old.crt"
cmp "$HOME/lun/private.key" "$tmp/old.key"
cmp "$HOME/lun/modules/multiuser/config.json" "$tmp/config-before"
[[ -f "$tmp/active-nginx" && -f "$tmp/active-lun-agent" ]]
: > "$tmp/probe-fails"
! deploy_acme_cert example.test domain
cmp "$HOME/lun/cert.crt" "$tmp/old.crt"
cmp "$HOME/lun/modules/multiuser/config.json" "$tmp/config-before"
rm "$tmp/probe-fails"
deploy_acme_cert example.test domain
cmp "$HOME/lun/cert.crt" "$tmp/new.crt"
[[ $(multiuser_config_value scheme) == https ]]
[[ $(multiuser_config_value port) == 27260 && $(multiuser_config_value legacy_token) == unchanged ]]
! grep -q 'restart sb' "$calls"
[[ -z $(find "$HOME/lun" -maxdepth 1 -type d -name '.cert-deploy.*' -print) ]]
echo 'ok - certificate/subscription rollback and HTTPS recovery; inactive cores unchanged'

# An issuance failure must still restore a temporarily stopped service.
ensure_acme_sh(){ :; }
domain_matches_local_ip(){ :; }
resolve_domain_ipv4(){ echo 1.2.3.4; }
resolve_domain_ipv6(){ :; }
show_domain_acme_diagnostics(){ :; }
is_nat_mode(){ return 1; }
acme_http_method(){ echo standalone; }
acme_issued_artifacts_valid(){ return 1; }
timeout(){ shift; return 1; }
! issue_acme_cert domain example.test
[[ -f "$tmp/active-nginx" && ! -d "$HOME/lun/.acme-http80" && ! -f "$tmp/firewall-open" ]]
echo 'ok - issuance failure returns port 80'
acme_http_pre standalone
acme_renew_cron && { echo 'Expected failed renewal status' >&2; exit 1; }
[[ -f "$tmp/active-nginx" && ! -d "$HOME/lun/.acme-http80" ]]
grep -q 'status=1' "$HOME/lun/acme_renew.status"
[[ -f "$HOME/lun/acme_renew.log" ]]
echo 'ok - failed daily renewal restores service and records status'
printf 'self\n' > "$HOME/lun/cert_mode"
cp "$tmp/old.crt" "$stage/cert.crt"; cp "$tmp/old.key" "$stage/private.key"
! acme_renew_cron
cmp "$HOME/lun/cert.crt" "$tmp/new.crt"
echo 'ok - daily deployment does not overwrite a manually replaced certificate'
