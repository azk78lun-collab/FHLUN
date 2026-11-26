#!/bin/sh
set -eu

VERSION=${SING_BOX_VERSION:-1.14.4}
OUTPUT=${1:-"$(pwd)/sing-box-multiuser-$(uname -m)"}
HELPER_OUTPUT=${2:-}
SOURCE_DIR=${SING_BOX_SOURCE_DIR:-}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
HELPER_SOURCE=${LUN_SB_STATS_SOURCE:-"$SCRIPT_DIR/sb_stats_helper.go"}

command -v go >/dev/null 2>&1 || {
echo "Go 1.25.5 或更高版本未安装。" >&2
exit 1
}

cleanup=
helper_dir=
trap '[ -z "$helper_dir" ] || rm -rf "$helper_dir"; [ -z "$cleanup" ] || rm -rf "$cleanup"' EXIT
trap 'exit 130' HUP INT TERM
if [ -z "$SOURCE_DIR" ]; then
command -v git >/dev/null 2>&1 || { echo "缺少 git。" >&2; exit 1; }
SOURCE_DIR=$(mktemp -d)
cleanup=$SOURCE_DIR
git clone --depth 1 --branch "v$VERSION" https://github.com/SagerNet/sing-box.git "$SOURCE_DIR"
fi

mkdir -p "$(dirname "$OUTPUT")"
cd "$SOURCE_DIR"
case "${GOOS:-$(go env GOOS)}" in
windows) default_tags=release/DEFAULT_BUILD_TAGS_WINDOWS ;;
*) default_tags=release/DEFAULT_BUILD_TAGS ;;
esac
TAGS=${SING_BOX_TAGS:-$(cat "$default_tags")}
case ",$TAGS," in *,with_v2ray_api,*) ;; *) TAGS="$TAGS,with_v2ray_api" ;; esac
case ",$TAGS," in *,with_purego,*) ;; *) TAGS="$TAGS,with_purego" ;; esac
LDFLAGS=$(cat release/LDFLAGS)
CGO_ENABLED=0 go build -trimpath -tags "$TAGS" \
  -ldflags "$LDFLAGS -X github.com/sagernet/sing-box/constant.Version=$VERSION -s -w -buildid=" \
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
CGO_ENABLED=0 go build -trimpath -ldflags "-s -w -buildid=" -o "$HELPER_OUTPUT" "./${helper_dir##*/}"
rm -rf "$helper_dir"
chmod +x "$HELPER_OUTPUT"
go version -m "$HELPER_OUTPUT" | grep -q 'github.com/sagernet/sing-box' || {
echo "统计辅助程序构建校验失败。" >&2
exit 1
}
echo "已生成：$HELPER_OUTPUT"
fi
