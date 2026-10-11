#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
export PYTHONDONTWRITEBYTECODE=1
export PYTHONPATH="$ROOT/tests/offline${PYTHONPATH:+:$PYTHONPATH}"
unset LUN_TEST_SKIP_SYMLINK

for file in lun.sh sap.sh saph.sh sapsbx.sh sapsbxh.sh container/nodejs/start.sh \
    mirror/fhlun-core-mirror-sync.sh modules/multiuser/build-singbox-enhanced.sh; do
  bash -n "$file"
done
for suite in modules/multiuser/tests modules/cluster/tests modules/cdnopt/tests tests; do
  python3 -B -m unittest discover -s "$suite" -p 'test_*.py' -v
done
for test in tests/test_menu_navigation.sh tests/test_banner.sh \
    modules/cluster/tests/test_shell_integration.sh modules/cdnopt/tests/test_shell_integration.sh \
    modules/multiuser/tests/test_firewall_helpers.sh modules/multiuser/tests/test_nat_hopping.sh \
    modules/multiuser/tests/test_security_transaction.sh modules/multiuser/tests/test_bandwidth_ownership.sh \
    modules/multiuser/tests/test_shell_helpers.sh; do
  bash -n "$test"
  bash "$test"
done
printf 'All offline checks passed\n'
