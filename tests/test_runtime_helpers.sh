#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/lun.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" PYTHONIOENCODING=utf-8
mkdir -p "$HOME/lun"
real_python=$(command -v python3)
for helper in lun_python_healthy lun_python_activate lun_python_select lun_python_asset \
    lun_python_install_portable lun_python_ensure ensure_lun_base_dependencies; do
  eval "$(awk -v target="$helper" '
    $0 ~ "^" target "\\(\\)\\{" {capture=1; print; next}
    capture && /^[A-Za-z_][A-Za-z_0-9]*\(\)\{/ {exit}
    capture {print}
  ' "$SCRIPT")"
done
if [[ ${OSTYPE:-} == msys* ]]; then flock(){ :; }; fi
lun_python_healthy "$real_python" basic
lun_python_healthy "$real_python" modules

(
  # Basic use must not fetch a modern runtime merely because Python is old.
  lun_python_healthy(){ [[ $2 == basic ]]; }
  lun_python_install_portable(){ echo unexpected-download >&2; return 1; }
  lun_install_packages(){ echo unexpected-package-install >&2; return 1; }
  lun_python_ensure basic
  [[ ! -e "$HOME/lun/runtime/bin/python3" ]]
)
echo 'ok - basic mode keeps an adequate legacy interpreter without downloads'

(
  # A stale marker must not suppress checks or record a failed install as ready.
  : > "$HOME/lun/.dependencies_ready"
  lun_base_dependencies_ready(){ [[ -f "$tmp/packages-ready" ]]; }
  lun_install_packages(){ return 1; }
  ! ensure_lun_base_dependencies
  [[ ! -e "$HOME/lun/.dependencies_ready" ]]
  lun_install_packages(){ : > "$tmp/packages-ready"; }
  ensure_lun_base_dependencies
  [[ -f "$HOME/lun/.dependencies_ready" ]]
  lun_install_packages(){ echo unexpected-reinstall >&2; return 1; }
  ensure_lun_base_dependencies
)
echo 'ok - failed package installs cannot create readiness markers'

lun_python_select "$real_python"
lun_python_activate
[[ $(command -v python3) == "$HOME/lun/runtime/bin/python3" ]]
lun_python_healthy "$(command -v python3)" modules
cp "$HOME/lun/runtime/bin/python3" "$tmp/launcher-before"
(
  lun_python_asset(){ echo 'x86_64-unknown-linux-gnu 0000000000000000000000000000000000000000000000000000000000000000'; }
  lun_runtime_fetch(){ printf bad-archive > "$2"; }
  ! lun_python_install_portable
  cmp "$tmp/launcher-before" "$HOME/lun/runtime/bin/python3"
  [[ -z $(find "$HOME/lun/runtime" -maxdepth 1 -name '.install.*' -type d -print) ]]
)
echo 'ok - checksum failure preserves the previous interpreter and cleans staging'

mkdir -p "$tmp/fixture/python/bin"
# Use a verified local interpreter, never a downloaded binary, in offline tests.
printf '#!/bin/sh\nexec "%s" "$@"\n' "$real_python" > "$tmp/fixture/python/bin/python3"
chmod 700 "$tmp/fixture/python/bin/python3"
tar -czf "$tmp/fixture.tar.gz" -C "$tmp/fixture" python
digest=$(sha256sum "$tmp/fixture.tar.gz" | cut -d ' ' -f1)
(
  lun_python_asset(){ printf 'x86_64-unknown-linux-gnu %s\n' "$digest"; }
  lun_runtime_fetch(){ cp "$tmp/fixture.tar.gz" "$2"; }
  lun_python_install_portable
  lun_python_healthy "$HOME/lun/runtime/bin/python3" modules
  lun_runtime_fetch(){ echo unexpected-repeat-download >&2; return 1; }
  lun_python_install_portable
  lun_python_ensure modules
)
echo 'ok - isolated runtime installs atomically and is reused without network'

(
  export HOME="$tmp/unhealthy"
  mkdir -p "$HOME/lun"
  lun_python_asset(){ printf 'x86_64-unknown-linux-gnu %s\n' "$digest"; }
  lun_runtime_fetch(){ cp "$tmp/fixture.tar.gz" "$2"; }
  lun_python_healthy(){ return 1; }
  ! lun_python_install_portable
  [[ ! -e "$HOME/lun/runtime/bin/python3" ]]
)
echo 'ok - incompatible executables are never activated'

(
  export HOME="$tmp/unsafe"
  mkdir -p "$HOME/lun"
  "$real_python" - "$tmp/unsafe.tar.gz" <<'PY'
import tarfile, sys
with tarfile.open(sys.argv[1], 'w:gz') as archive:
    archive.addfile(tarfile.TarInfo('../escape'))
PY
  unsafe_digest=$(sha256sum "$tmp/unsafe.tar.gz" | cut -d ' ' -f1)
  lun_python_asset(){ printf 'x86_64-unknown-linux-gnu %s\n' "$unsafe_digest"; }
  lun_runtime_fetch(){ cp "$tmp/unsafe.tar.gz" "$2"; }
  ! lun_python_install_portable
  [[ ! -e "$HOME/lun/runtime/bin/python3" && ! -e "$HOME/lun/runtime/escape" ]]
)
echo 'ok - unsafe archive paths are rejected before extraction'
