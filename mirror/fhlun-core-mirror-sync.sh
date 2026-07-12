#!/bin/sh
set -eu

mirror_dir=/var/lib/fhlun-core
mkdir -p "$mirror_dir"
tmp_dir=$(mktemp -d "${mirror_dir}/.sync.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT INT TERM

sync_asset(){
  name=$1
  url=$2
  target="$tmp_dir/$name"

  curl -4 -fL --connect-timeout 10 --max-time 600 --retry 2 -o "$target" "$url"
  [ -s "$target" ] || return 1
  chmod 0644 "$target"
  mv -f "$target" "$mirror_dir/$name"
}

sync_asset xray-amd64 https://github.com/azk78lun-collab/FHLUN/releases/download/lun/xray-amd64
sync_asset xray-arm64 https://github.com/azk78lun-collab/FHLUN/releases/download/lun/xray-arm64
sync_asset sing-box-amd64 https://github.com/azk78lun-collab/FHLUN/releases/download/lun/sing-box-amd64
sync_asset sing-box-arm64 https://github.com/azk78lun-collab/FHLUN/releases/download/lun/sing-box-arm64
sync_asset cloudflared-linux-amd64 https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
sync_asset cloudflared-linux-arm64 https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
