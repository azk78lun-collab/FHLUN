#!/bin/sh
set -eu

VERSION=${SING_BOX_VERSION:-1.13.14}
OUTPUT=${1:-"$(pwd)/sing-box-multiuser-$(uname -m)"}
HELPER_OUTPUT=${2:-}
SOURCE_DIR=${SING_BOX_SOURCE_DIR:-}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
HELPER_SOURCE=${LUN_SB_STATS_SOURCE:-"$SCRIPT_DIR/sb_stats_helper.go"}
TAGS=${SING_BOX_TAGS:-with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_acme,with_clash_api,with_tailscale,with_ccm,with_ocm,with_naive_outbound,with_v2ray_api,badlinkname,tfogo_checklinkname0,with_purego}

command -v go >/dev/null 2>&1 || {
echo "Go 1.24.7 或更高版本未安装。" >&2
exit 1
}

cleanup=
if [ -z "$SOURCE_DIR" ]; then
command -v git >/dev/null 2>&1 || { echo "缺少 git。" >&2; exit 1; }
SOURCE_DIR=$(mktemp -d)
cleanup=$SOURCE_DIR
git clone --depth 1 --branch "v$VERSION" https://github.com/SagerNet/sing-box.git "$SOURCE_DIR"
fi

trap '[ -n "$cleanup" ] && rm -rf "$cleanup"' EXIT HUP INT TERM
mkdir -p "$(dirname "$OUTPUT")"
cd "$SOURCE_DIR"
CGO_ENABLED=0 go build -trimpath -tags "$TAGS" \
  -ldflags "-X github.com/sagernet/sing-box/constant.Version=$VERSION -s -w -buildid=" \
  -o "$OUTPUT" ./cmd/sing-box
chmod +x "$OUTPUT"
go version -m "$OUTPUT" | grep -q with_v2ray_api || {
echo "构建结果缺少 with_v2ray_api。" >&2
exit 1
}
echo "已生成：$OUTPUT"

if [ -n "$HELPER_OUTPUT" ]; then
[ -s "$HELPER_SOURCE" ] || { echo "缺少统计辅助程序源码：$HELPER_SOURCE" >&2; exit 1; }
helper_dir=$(mktemp -d "$SOURCE_DIR/.lun-sb-stats.XXXXXX")
cp "$HELPER_SOURCE" "$helper_dir/main.go"
CGO_ENABLED=0 go build -trimpath -ldflags "-s -w -buildid=" -o "$HELPER_OUTPUT" "$helper_dir"
rm -rf "$helper_dir"
chmod +x "$HELPER_OUTPUT"
go version -m "$HELPER_OUTPUT" | grep -q 'github.com/sagernet/sing-box' || {
echo "统计辅助程序构建校验失败。" >&2
exit 1
}
echo "已生成：$HELPER_OUTPUT"
fi
