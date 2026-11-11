#!/usr/bin/env bash
# Stable recovery entry point. Keep API 1 and --target/--stage backward compatible.
set -euo pipefail
LUN_UPGRADE_API=1

lun_bridge_fetch(){
  local url=$1 output=$2 accept=${3:-application/vnd.github+json}
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --proto '=https' --proto-redir '=https' -H "Accept: $accept" -H 'Cache-Control: no-cache' \
      --connect-timeout 10 --max-time 60 --retry 2 "$url" -o "$output"
  else
    wget -qO "$output" --header="Accept: $accept" --header='Cache-Control: no-cache' --timeout=30 --tries=2 "$url"
  fi
}

lun_bridge_sha_field(){
  sed -n 's/.*"sha"[[:space:]]*:[[:space:]]*"\([0-9a-f]\{40\}\)".*/\1/p' "$1" | head -n 1
}

lun_bridge_version(){
  grep -Eo 'V[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$1" | head -n 1
}

lun_bridge_older(){
  awk -v a="$1" -v b="$2" 'BEGIN {
    gsub(/^V/,"",a); gsub(/^V/,"",b); na=split(a,x,"."); nb=split(b,y,".");
    for(i=1;i<=na || i<=nb;i++){if(x[i]+0<y[i]+0)exit 0;if(x[i]+0>y[i]+0)exit 1} exit 1
  }'
}

lun_bridge_main(){
(
  local mode=install destination= entry= temporary secondary_tmp= commit blob actual version current before after
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --target|--stage)
        [ "$#" -ge 2 ] || { echo '缺少更新目标路径。' >&2; return 2; }
        [ "$1" != --stage ] || mode=stage
        destination=$2; shift 2 ;;
      *) echo '用法：bash upgrade.sh [--target 实际命令路径 | --stage 暂存文件]' >&2; return 2 ;;
    esac
  done
  if [ -z "$destination" ]; then
    destination=$(type -P lun 2>/dev/null || true)
    if [ -z "$destination" ]; then
      if [ "$(id -u)" = 0 ]; then destination=/usr/bin/lun; else destination="$HOME/bin/lun"; fi
    fi
  fi
  case "$destination" in /*) ;; *) echo '更新目标必须是绝对路径。' >&2; return 2 ;; esac
  [ ! -d "$destination" ] || { echo '更新目标不能是目录。' >&2; return 2; }
  for entry in bash sed grep awk wc tr cat cmp sha1sum sha256sum mv cp chmod mktemp readlink; do
    command -v "$entry" >/dev/null 2>&1 || { echo "缺少恢复组件：$entry；请先补装基础工具。" >&2; return 1; }
  done
  if [ "$mode" = install ] && [ -L "$destination" ]; then
    destination=$(readlink -f "$destination") || return 1
  fi
  mkdir -p "$(dirname "$destination")" || return 1
  [ -w "$(dirname "$destination")" ] || { echo "无权写入 $destination；请使用 root 或指定可写入口。" >&2; return 1; }
  temporary=$(mktemp -d "$(dirname "$destination")/.lun-upgrade.XXXXXX") || return 1
  chmod 700 "$temporary"
  trap 'rm -rf -- "$temporary"; [ -z "$secondary_tmp" ] || rm -f -- "$secondary_tmp"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  echo '正在核对 GitHub main 最新提交……' >&2
  lun_bridge_fetch "https://api.github.com/repos/azk78lun-collab/FHLUN/commits/main?fhlun_nocache=$(date +%s)-$$" "$temporary/head.sha" application/vnd.github.sha || return 1
  commit=$(tr -d '[:space:]' < "$temporary/head.sha")
  [[ $commit =~ ^[0-9a-f]{40}$ ]] || { echo '无法确认 GitHub 最新提交；检查未完成，不能判断为最新版。' >&2; return 1; }
  lun_bridge_fetch "https://api.github.com/repos/azk78lun-collab/FHLUN/contents/lun.sh?ref=$commit&fhlun_nocache=$(date +%s)-$$" "$temporary/file.json" || return 1
  blob=$(lun_bridge_sha_field "$temporary/file.json")
  [[ $blob =~ ^[0-9a-f]{40}$ ]] || { echo '无法取得脚本内容标识，未修改现有入口。' >&2; return 1; }
  if ! lun_bridge_fetch "https://raw.githubusercontent.com/azk78lun-collab/FHLUN/$commit/lun.sh" "$temporary/lun.sh" application/vnd.github.raw+json; then
    lun_bridge_fetch "https://api.github.com/repos/azk78lun-collab/FHLUN/contents/lun.sh?ref=$commit&fhlun_nocache=$(date +%s)-$$" "$temporary/lun.sh" application/vnd.github.raw+json || return 1
  fi
  actual=$({ printf 'blob %s\0' "$(wc -c < "$temporary/lun.sh" | tr -d '[:space:]')"; cat "$temporary/lun.sh"; } | sha1sum | awk '{print $1}')
  [ "$actual" = "$blob" ] || { echo '下载内容与 GitHub 指定提交不一致，已拒绝更新。' >&2; return 1; }
  version=$(lun_bridge_version "$temporary/lun.sh")
  [ -n "$version" ] && grep -q 'Lun 项目地址' "$temporary/lun.sh" && bash -n "$temporary/lun.sh" || { echo '远端脚本格式或语法无效，未修改现有入口。' >&2; return 1; }
  if [ "$mode" = stage ]; then
    cp "$temporary/lun.sh" "$destination" || return 1
    chmod 700 "$destination"
    echo "已核验远端 $version / 提交 ${commit:0:12}。" >&2
    return 0
  fi
  current=$(lun_bridge_version "$destination" 2>/dev/null || true)
  if [ -n "$current" ] && lun_bridge_older "$version" "$current"; then
    echo "远端 $version 低于本机 $current，已拒绝降级。" >&2
    return 1
  fi
  if [ -f "$destination" ] && cmp -s "$temporary/lun.sh" "$destination"; then
    echo "已核验实际入口：$destination；当前已是最新版 $version（提交 ${commit:0:12}）。"
    return 0
  fi
  [ ! -e "$destination" ] || cp -p "$destination" "$destination.update-backup" || return 1
  before=$(sha256sum "$temporary/lun.sh" | awk '{print $1}')
  cp "$temporary/lun.sh" "$temporary/replace" && chmod 755 "$temporary/replace" || return 1
  mv -f "$temporary/replace" "$destination" || return 1
  after=$(sha256sum "$destination" | awk '{print $1}')
  if [ "$before" != "$after" ] || [ "$(lun_bridge_version "$destination")" != "$version" ]; then
    [ ! -f "$destination.update-backup" ] || cp -p "$destination.update-backup" "$destination"
    echo '更新后的入口核验失败，已尝试恢复原脚本。' >&2
    return 1
  fi
  entry="$HOME/bin/lun"
  if [ -f "$entry" ] && [ "$(readlink -f "$entry")" != "$destination" ]; then
    secondary_tmp=$(mktemp "$entry.replace.XXXXXX") || return 1
    cp "$destination" "$secondary_tmp" && chmod 755 "$secondary_tmp" && mv -f "$secondary_tmp" "$entry" || return 1
    secondary_tmp=
  fi
  echo "Lun 更新完成：${current:-未安装} → $version"
  echo "生效入口：$destination；提交：${commit:0:12}；SHA-256：$after"
  echo '代理参数、证书、用户数据库和集群身份未修改；请重新运行 lun。'
)
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  lun_bridge_main "$@"
fi
