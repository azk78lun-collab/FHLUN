#!/usr/bin/env bash
set -euo pipefail

ROOT=${LUN_ROOT:-/root/lun}
AGENT="$ROOT/modules/multiuser/lun-agent"
DB="$ROOT/modules/multiuser/data/lun.db"
NAME=${LUN_TEST_USER:-codex-smoke-20260722}
TMP=$(mktemp -d /tmp/fhlun-mu-smoke.XXXXXX)
CLIENT_PID=
CREATED=no
USER_ID=
DID=

agent() {
  "$AGENT" --root "$ROOT" "$@"
}

cleanup() {
  if [[ -n "$CLIENT_PID" ]]; then
    kill "$CLIENT_PID" 2>/dev/null || true
  fi
  if [[ "$CREATED" == yes ]]; then
    agent update-device --device-id "$DID" --enable >/dev/null 2>&1 || true
    agent set-protocol --user-id "$USER_ID" --protocol so --enabled yes >/dev/null 2>&1 || true
    agent update-user --user-id "$USER_ID" --lifetime-quota 100M --monthly-quota 50M >/dev/null 2>&1 || true
    agent apply >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

[[ $(id -u) -eq 0 ]] || { echo "remote_smoke.sh must run as root" >&2; exit 1; }
[[ -x "$AGENT" ]] || { echo "multi-user agent is not installed" >&2; exit 1; }

if python3 - "$DB" "$NAME" <<'PY'
import sqlite3, sys
db = sqlite3.connect(sys.argv[1])
raise SystemExit(0 if db.execute("SELECT 1 FROM users WHERE name=?", (sys.argv[2],)).fetchone() else 1)
PY
then
  echo "test user already exists: $NAME" >&2
  exit 1
fi

agent add-user --name "$NAME" --lifetime-quota 100M --monthly-quota 50M \
  --reset-day 22 --expires never --max-devices 2 --device-name phone-smoke >"$TMP/add-user.out"
CREATED=yes
read -r USER_ID DID UUID PASSWORD TOKEN < <(python3 - "$DB" "$NAME" <<'PY'
import sqlite3, sys
db = sqlite3.connect(sys.argv[1])
db.row_factory = sqlite3.Row
row = db.execute("SELECT u.id uid,d.id did,d.uuid,d.password,d.token FROM users u JOIN devices d ON d.user_id=u.id WHERE u.name=? ORDER BY d.id LIMIT 1", (sys.argv[2],)).fetchone()
print(row["uid"], row["did"], row["uuid"], row["password"], row["token"])
PY
)
agent apply >"$TMP/apply.out"

read -r SCHEME HOST PORT LEGACY_PORT SS_PORT SS_SERVER_KEY SS_METHOD < <(python3 - "$ROOT" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
config = json.loads((root / "modules/multiuser/config.json").read_text())
sb = json.loads((root / "sb.json").read_text())
ss = next(item for item in sb["inbounds"] if item.get("tag") == "ss-2022-mu")
print(config["scheme"], config["public_host"], config["port"], config.get("legacy_http_port", 0),
      ss["listen_port"], ss["password"], ss["method"])
PY
)
SOCKS_PORT=$(python3 - "$ROOT/xr.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
print(next(item["port"] for item in data["inbounds"] if item.get("tag") == "socks5-xr"))
PY
)
SS_USER_KEY=$(python3 - "$DB" "$DID" <<'PY'
import sqlite3, sys
print(sqlite3.connect(sys.argv[1]).execute("SELECT ss_password FROM devices WHERE id=?", (sys.argv[2],)).fetchone()[0])
PY
)

if [[ "$SCHEME" == https ]]; then
  SUB_STATUS=$(curl -kfsS --resolve "$HOST:$PORT:127.0.0.1" -o "$TMP/sub.txt" -w '%{http_code}' \
    "https://$HOST:$PORT/$TOKEN/jhsub.txt")
else
  SUB_STATUS=$(curl -fsS -o "$TMP/sub.txt" -w '%{http_code}' "http://127.0.0.1:$PORT/$TOKEN/jhsub.txt")
fi
[[ "$SUB_STATUS" == 200 ]] || { echo "new subscription failed: $SUB_STATUS" >&2; exit 1; }
grep -q "$UUID" "$TMP/sub.txt"
if [[ "$LEGACY_PORT" -gt 0 ]]; then
  [[ $(curl -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1:$LEGACY_PORT/$TOKEN/jhsub.txt") == 404 ]]
fi

curl --max-time 20 --proxy-user "$UUID:$PASSWORD" --socks5-hostname "127.0.0.1:$SOCKS_PORT" \
  -fsS https://cp.cloudflare.com/generate_204 -o /dev/null
agent maintenance >/dev/null
XRAY_BYTES=$(python3 - "$DB" "$DID" <<'PY'
import sqlite3, sys
row = sqlite3.connect(sys.argv[1]).execute(
    "SELECT COALESCE(SUM(uplink+downlink),0) FROM usage_totals WHERE device_id=? AND core='xray'",
    (sys.argv[2],),
).fetchone()
print(row[0])
PY
)
[[ "$XRAY_BYTES" -gt 0 ]] || { echo "xray per-user traffic was not collected" >&2; exit 1; }
if curl --max-time 5 --proxy-user "$UUID:$PASSWORD" --socks5-hostname "127.0.0.1:$SOCKS_PORT" \
  -fsS "http://127.0.0.1:$LEGACY_PORT/" -o /dev/null; then
  echo "private destination guard did not reject loopback" >&2
  exit 1
fi

agent set-protocol --user-id "$USER_ID" --protocol so --enabled no >/dev/null
agent apply >/dev/null
if curl --max-time 5 --proxy-user "$UUID:$PASSWORD" --socks5-hostname "127.0.0.1:$SOCKS_PORT" \
  -fsS https://cp.cloudflare.com/generate_204 -o /dev/null; then
  echo "disabled SOCKS permission still authenticates" >&2
  exit 1
fi
agent set-protocol --user-id "$USER_ID" --protocol so --enabled yes >/dev/null
agent apply >/dev/null

agent add-device --user-id "$USER_ID" --name laptop-smoke >"$TMP/add-device.out"
if agent add-device --user-id "$USER_ID" --name overflow-smoke >"$TMP/overflow.out" 2>&1; then
  echo "max_devices was not enforced" >&2
  exit 1
fi
read -r SECOND_ID SECOND_TOKEN < <(python3 - "$DB" "$USER_ID" <<'PY'
import sqlite3, sys
row = sqlite3.connect(sys.argv[1]).execute("SELECT id,token FROM devices WHERE user_id=? AND name='laptop-smoke'", (sys.argv[2],)).fetchone()
print(*row)
PY
)
agent rotate-device --device-id "$SECOND_ID" --confirm laptop-smoke >"$TMP/rotate.out"
agent apply >/dev/null
if [[ "$SCHEME" == https ]]; then
  [[ $(curl -ksS --resolve "$HOST:$PORT:127.0.0.1" -o /dev/null -w '%{http_code}' \
    "https://$HOST:$PORT/$SECOND_TOKEN/jhsub.txt") == 404 ]]
fi

agent update-device --device-id "$DID" --disable >/dev/null
agent apply >/dev/null
if [[ "$SCHEME" == https ]]; then
  [[ $(curl -ksS --resolve "$HOST:$PORT:127.0.0.1" -o /dev/null -w '%{http_code}' \
    "https://$HOST:$PORT/$TOKEN/jhsub.txt") == 403 ]]
fi
agent update-device --device-id "$DID" --enable >/dev/null
agent apply >/dev/null

python3 - "$TMP/ss-client.json" "$SS_PORT" "$SS_METHOD" "$SS_SERVER_KEY:$SS_USER_KEY" <<'PY'
import json, sys
path, port, method, password = sys.argv[1:]
data = {
  "inbounds": [{"type": "socks", "tag": "smoke-in", "listen": "127.0.0.1", "listen_port": 39012}],
  "outbounds": [{"type": "shadowsocks", "tag": "smoke-out", "server": "127.0.0.1",
                 "server_port": int(port), "method": method, "password": password}],
  "route": {"final": "smoke-out"}
}
open(path, "w").write(json.dumps(data))
PY
"$ROOT/sing-box" check -c "$TMP/ss-client.json"
"$ROOT/sing-box" run -c "$TMP/ss-client.json" >"$TMP/ss-client.log" 2>&1 &
CLIENT_PID=$!
for _ in {1..30}; do
  ss -lnt | grep -q ':39012 ' && break
  sleep 0.2
done
curl --max-time 20 --socks5-hostname 127.0.0.1:39012 -fsS https://cp.cloudflare.com/generate_204 -o /dev/null
kill "$CLIENT_PID" 2>/dev/null || true
wait "$CLIENT_PID" 2>/dev/null || true
CLIENT_PID=
agent maintenance >/dev/null

read -r XRAY_BYTES SINGBOX_BYTES < <(python3 - "$DB" "$DID" <<'PY'
import sqlite3, sys
db = sqlite3.connect(sys.argv[1])
def total(core):
    row = db.execute("SELECT COALESCE(SUM(uplink+downlink),0) FROM usage_totals WHERE device_id=? AND core=?", (sys.argv[2], core)).fetchone()
    return row[0]
print(total("xray"), total("singbox"))
PY
)
[[ "$SINGBOX_BYTES" -gt 0 ]] || { echo "sing-box per-user traffic was not collected" >&2; exit 1; }

agent update-user --user-id "$USER_ID" --lifetime-quota 1 >/dev/null
agent maintenance >/dev/null
if [[ "$SCHEME" == https ]]; then
  [[ $(curl -ksS --resolve "$HOST:$PORT:127.0.0.1" -o /dev/null -w '%{http_code}' \
    "https://$HOST:$PORT/$TOKEN/jhsub.txt") == 403 ]]
fi
agent update-user --user-id "$USER_ID" --lifetime-quota 100M >/dev/null
agent apply >/dev/null

echo "remote multi-user smoke test passed"
echo "user=$NAME id=$USER_ID devices=2 xray_bytes=$XRAY_BYTES singbox_bytes=$SINGBOX_BYTES"
