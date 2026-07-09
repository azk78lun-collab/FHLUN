#!/bin/sh
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export LANGUAGE=C.UTF-8
[ -z "${vlpt+x}" ] || vlp=yes
[ -z "${vmpt+x}" ] || { vmp=yes; vmag=yes; }
[ -z "${vwpt+x}" ] || { vwp=yes; vmag=yes; }
[ -z "${hypt+x}" ] || hyp=yes
[ -z "${tupt+x}" ] || tup=yes
[ -z "${xhpt+x}" ] || xhp=yes
[ -z "${vxpt+x}" ] || vxp=yes
[ -z "${anpt+x}" ] || anp=yes
[ -z "${sspt+x}" ] || ssp=yes
[ -z "${arpt+x}" ] || arp=yes
[ -z "${sopt+x}" ] || sop=yes
[ -n "${warp:-}" ] && wap=yes
LUN_MENU_REQUEST=
[ -z "$1" ] && [ "$vwp" != yes ] && [ "$sop" != yes ] && [ "$vxp" != yes ] && [ "$ssp" != yes ] && [ "$vlp" != yes ] && [ "$vmp" != yes ] && [ "$hyp" != yes ] && [ "$tup" != yes ] && [ "$xhp" != yes ] && [ "$anp" != yes ] && [ "$arp" != yes ] && LUN_MENU_REQUEST=yes
if find /proc/*/exe -type l 2>/dev/null | grep -E '/proc/[0-9]+/exe' | xargs -r readlink 2>/dev/null | grep -Eq 'lun/(s|x)'; then
if [ "$1" = "rep" ]; then
[ "$vwp" = yes ] || [ "$sop" = yes ] || [ "$vxp" = yes ] || [ "$ssp" = yes ] || [ "$vlp" = yes ] || [ "$vmp" = yes ] || [ "$hyp" = yes ] || [ "$tup" = yes ] || [ "$xhp" = yes ] || [ "$anp" = yes ] || [ "$arp" = yes ] || { echo "提示：rep重置协议时，请在脚本前至少设置一个协议变量哦，再见！💣"; exit; }
fi
else
[ "$LUN_MENU_REQUEST" = yes ] || [ "$1" = "del" ] || [ "$vwp" = yes ] || [ "$sop" = yes ] || [ "$vxp" = yes ] || [ "$ssp" = yes ] || [ "$vlp" = yes ] || [ "$vmp" = yes ] || [ "$hyp" = yes ] || [ "$tup" = yes ] || [ "$xhp" = yes ] || [ "$anp" = yes ] || [ "$arp" = yes ] || { echo "提示：未安装 Lun，请先运行 lun 菜单安装，或在脚本前至少设置一个协议变量。"; exit; }
fi
export uuid=${uuid:-''}
export port_vl_re=${vlpt:-''}
export port_vm_ws=${vmpt:-''}
export port_vw=${vwpt:-''}
export port_hy2=${hypt:-''}
export port_tu=${tupt:-''}
export port_xh=${xhpt:-''}
export port_vx=${vxpt:-''}
export port_an=${anpt:-''}
export port_ar=${arpt:-''}
export port_ss=${sspt:-''}
export port_so=${sopt:-''}
export ym_vl_re=${reym:-''}
export cdnym=${cdnym:-''}
export argo=${argo:-''}
export ARGO_DOMAIN=${agn:-''}
export ARGO_AUTH=${agk:-''}
export ippz=${ippz:-''}
export warp=${warp:-''}
export name=${name:-''}
export oap=${oap:-''}
export addym=${addym:-''}
export addout=${addout:-''}
export ptmap=${ptmap:-''}
export portpool=${portpool:-''}
export inpool=${inpool:-''}
export outpool=${outpool:-''}
export vpsmode=${vpsmode:-''}
export argoip=${argoip:-''}
export subipmode=${subipmode:-''}
export domain=${domain:-''}
export certmode=${certmode:-''}
export acme_email=${acme_email:-''}
export acme_dns=${acme_dns:-''}
v46url="https://icanhazip.com"
lunurl=${lunurl:-"https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh"}
showmode(){
echo "主脚本：bash <(curl -Ls https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh) 或 bash <(wget -qO- https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)"
echo "风火轮多协议交互面板命令：lun"
echo "显示节点信息命令：lun list 【或者】 主脚本 list"
echo "重置变量组命令：自定义各种协议变量组 lun rep 【或者】 自定义各种协议变量组 主脚本 rep"
echo "更新脚本命令：lun 菜单 → 服务与更新"
echo "更新Xray或Singbox内核命令：lun upx或ups 【或者】 主脚本 upx或ups"
echo "重启脚本命令：lun res 【或者】 主脚本 res"
echo "卸载脚本命令：lun del 【或者】 主脚本 del"
echo "双栈VPS显示IPv4/IPv6节点配置命令：ippz=4或6 lun list 【或者】 ippz=4或6 主脚本 list"
echo "---------------------------------------------------------"
echo
}
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Lun 项目地址：https://github.com/azk78lun-collab/FHLUN"
echo ""
echo ""
echo "Lun一键无交互小钢炮脚本💣"
echo "当前版本：V26.5.10"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
hostname=$(uname -a | awk '{print $2}')
op=$(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release 2>/dev/null | grep -i pretty_name | cut -d \" -f2)
[ -z "$(systemd-detect-virt 2>/dev/null)" ] && vi=$(virt-what 2>/dev/null) || vi=$(systemd-detect-virt 2>/dev/null)
case $(uname -m) in
arm64|aarch64) cpu=arm64;;
amd64|x86_64) cpu=amd64;;
*) echo "目前脚本不支持$(uname -m)架构" && exit
esac

migrate_lun_state(){
if [ ! -d "$HOME/lun" ] && [ -d "$HOME/agsbx" ]; then
mv "$HOME/agsbx" "$HOME/lun"
fi
if [ ! -d "$HOME/weblun" ] && [ -d "$HOME/websbx" ]; then
mv "$HOME/websbx" "$HOME/weblun"
fi
rm -f "$HOME/bin/agsbx" /usr/bin/agsbx 2>/dev/null
}

valid_addym(){
addr=$1
case "$addr" in
""|del|none) return 0 ;;
*"://"*|*/*|*\?*|*#*|*" "*|*"	"*) return 1 ;;
\[*\]) return 0 ;;
*:*) return 1 ;;
*) return 0 ;;
esac
}

valid_domain(){
host=$1
case "$host" in
""|del|none) return 0 ;;
*"://"*|*/*|*\?*|*#*|*" "*|*"	"*|*:*) return 1 ;;
*.*) return 0 ;;
*) return 1 ;;
esac
}

sanitize_argo_token(){
raw=$1
token=
for word in $raw; do
case "$word" in
ey*) token=$word ;;
esac
done
[ -z "$token" ] && token="$raw"
token=$(printf '%s' "$token" | tr -d '"' | tr -d "'" | sed 's/[[:space:]].*$//')
printf '%s\n' "$token"
}

valid_port_value(){
p=$1
case "$p" in
""|*[!0-9]*) return 1 ;;
esac
[ "$p" -ge 1 ] 2>/dev/null && [ "$p" -le 65535 ] 2>/dev/null
}

valid_ptmap_pair(){
pair=$1
case "$pair" in
*-*)
ext=${pair%%-*}
inner=${pair#*-}
[ "$ext" != "$pair" ] && valid_port_value "$ext" && valid_port_value "$inner"
;;
*) return 1 ;;
esac
}

normalize_ptmap(){
out=
for pair in $1; do
valid_ptmap_pair "$pair" || return 1
out="$out $pair"
done
printf '%s\n' "${out# }"
}

load_port_map_config(){
if [ -n "$ptmap" ]; then
case "$ptmap" in
del|none|off)
rm -f "$HOME/lun/port_map"
ptmap=
;;
*)
normalized=$(normalize_ptmap "$ptmap") || { echo "ptmap 格式错误，请使用 外网端口-内网端口，例如：54834-2096 54835-8443"; exit 1; }
ptmap="$normalized"
printf "%s\n" "$ptmap" > "$HOME/lun/port_map"
;;
esac
elif [ -s "$HOME/lun/port_map" ]; then
ptmap=$(cat "$HOME/lun/port_map" 2>/dev/null)
fi
}

load_vps_mode_config(){
if [ -n "$vpsmode" ]; then
case "$vpsmode" in
normal|nat)
printf "%s\n" "$vpsmode" > "$HOME/lun/vps_mode"
;;
del|none|off)
rm -f "$HOME/lun/vps_mode"
vpsmode=normal
;;
*)
echo "vpsmode 只支持 normal 或 nat"
exit 1
;;
esac
elif [ -s "$HOME/lun/vps_mode" ]; then
vpsmode=$(cat "$HOME/lun/vps_mode" 2>/dev/null)
else
if [ -n "$ptmap" ] || { [ -n "$inpool" ] && [ -n "$outpool" ]; }; then
vpsmode=nat
else
vpsmode=normal
fi
fi
case "$vpsmode" in normal|nat) ;; *) vpsmode=normal ;; esac
}

load_argoip_config(){
if [ -n "$argoip" ]; then
case "$argoip" in
del|none|off)
rm -f "$HOME/lun/argoip"
argoip=
;;
*)
bad=
for one in $argoip; do
case "$one" in -1) bad=yes ;; *) valid_addym "$one" || bad=yes ;; esac
done
[ -z "$bad" ] || { echo "argoip 只接受 IP 或域名，多个值用空格分隔"; exit 1; }
printf "%s\n" "$argoip" > "$HOME/lun/argoip"
;;
esac
elif [ -s "$HOME/lun/argoip" ]; then
argoip=$(cat "$HOME/lun/argoip" 2>/dev/null)
fi
}

is_nat_mode(){
case "${vpsmode:-}" in
nat) return 0 ;;
normal) return 1 ;;
esac
[ -n "$ptmap" ] && return 0
[ -n "$inpool" ] && [ -n "$outpool" ] && return 0
return 1
}

client_port(){
inner=$1
if is_nat_mode; then
for pair in $ptmap; do
ext=${pair%%-*}
mapped_inner=${pair#*-}
[ "$mapped_inner" = "$inner" ] && { printf '%s\n' "$ext"; return; }
done
pool_public_for_inner "$inner" && return
fi
printf '%s\n' "$inner"
}

inner_port_from_public(){
public=$1
is_nat_mode || return 1
for pair in $ptmap; do
ext=${pair%%-*}
mapped_inner=${pair#*-}
[ "$ext" = "$public" ] && { printf '%s\n' "$mapped_inner"; return; }
done
pool_inner_for_public "$public" && return
}

show_port_mapping_hint(){
inner=$1
is_nat_mode || return 0
public=$(client_port "$inner")
[ "$public" != "$inner" ] && echo "NAT映射：公网端口 $public -> 内网端口 $inner"
}

valid_port_range(){
range=$1
case "$range" in
*+*)
start=${range%%+*}
end=${range#*+}
;;
*..*)
start=${range%%..*}
end=${range#*..}
;;
*-*)
start=${range%%-*}
end=${range#*-}
;;
*) return 1 ;;
esac
valid_port_value "$start" && valid_port_value "$end" && [ "$start" -le "$end" ] 2>/dev/null
}

normalize_portpool(){
out=
for item in $1; do
case "$item" in
*+*)
valid_port_range "$item" || return 1
;;
*..*)
valid_port_range "$item" || return 1
;;
*-*)
left=${item%%-*}
right=${item#*-}
valid_port_value "$left" && valid_port_value "$right" || return 1
;;
*)
valid_port_value "$item" || return 1
;;
esac
out="$out $item"
done
printf '%s\n' "${out# }"
}

normalize_plain_portpool(){
out=
for item in $1; do
case "$item" in
*+*|*..*)
valid_port_range "$item" || return 1
;;
*-*)
return 1
;;
*)
valid_port_value "$item" || return 1
;;
esac
out="$out $item"
done
printf '%s\n' "${out# }"
}

append_ptmap_pair(){
pair=$1
valid_ptmap_pair "$pair" || return 1
for exist in $ptmap; do
[ "$exist" = "$pair" ] && return 0
done
ptmap="${ptmap:+$ptmap }$pair"
printf "%s\n" "$ptmap" > "$HOME/lun/port_map"
}

load_port_pool_config(){
if [ -n "$inpool" ]; then
case "$inpool" in
del|none|off)
rm -f "$HOME/lun/inner_port_pool"
inpool=
;;
*)
normalized=$(normalize_plain_portpool "$inpool") || { echo "inpool 格式错误，支持端口、范围 1000+2000 或 1000..2000"; exit 1; }
inpool="$normalized"
printf "%s\n" "$inpool" > "$HOME/lun/inner_port_pool"
;;
esac
elif [ -s "$HOME/lun/inner_port_pool" ]; then
inpool=$(cat "$HOME/lun/inner_port_pool" 2>/dev/null)
fi
if [ -n "$outpool" ]; then
case "$outpool" in
del|none|off)
rm -f "$HOME/lun/outer_port_pool"
outpool=
;;
*)
normalized=$(normalize_plain_portpool "$outpool") || { echo "outpool 格式错误，支持端口、范围 1000+2000 或 1000..2000"; exit 1; }
outpool="$normalized"
printf "%s\n" "$outpool" > "$HOME/lun/outer_port_pool"
;;
esac
elif [ -s "$HOME/lun/outer_port_pool" ]; then
outpool=$(cat "$HOME/lun/outer_port_pool" 2>/dev/null)
fi
if [ -n "$portpool" ]; then
case "$portpool" in
del|none|off)
rm -f "$HOME/lun/port_pool"
portpool=
;;
*)
normalized=$(normalize_portpool "$portpool") || { echo "portpool 格式错误，支持端口、范围 1000..1010、非 NAT 范围 1000-1010、NAT 映射 54834-2096"; exit 1; }
portpool="$normalized"
printf "%s\n" "$portpool" > "$HOME/lun/port_pool"
;;
esac
elif [ -s "$HOME/lun/port_pool" ]; then
portpool=$(cat "$HOME/lun/port_pool" 2>/dev/null)
fi
if [ -z "$inpool" ] && [ -n "$portpool" ]; then
inpool="$portpool"
fi
for item in $portpool; do
case "$item" in
*-*)
left=${item%%-*}
right=${item#*-}
if valid_port_value "$left" && valid_port_value "$right" && [ "$left" -gt "$right" ] 2>/dev/null; then
[ "$vpsmode" = "normal" ] || append_ptmap_pair "$item" || true
fi
;;
esac
done
}

plain_port_pool_candidates(){
for item in $1; do
case "$item" in
*+*)
start=${item%%+*}
end=${item#*+}
seq "$start" "$end" 2>/dev/null
;;
*..*)
start=${item%%..*}
end=${item#*..}
seq "$start" "$end" 2>/dev/null
;;
*-*)
left=${item%%-*}
right=${item#*-}
if [ "$left" -gt "$right" ] 2>/dev/null; then
printf '%s\n' "$right"
else
seq "$left" "$right" 2>/dev/null
fi
;;
*)
printf '%s\n' "$item"
;;
esac
done
}

port_pool_inner_candidates(){
if [ -n "$inpool" ]; then
plain_port_pool_candidates "$inpool"
else
plain_port_pool_candidates "$portpool"
fi
}

port_pool_outer_candidates(){
plain_port_pool_candidates "$outpool"
}

pool_public_for_inner(){
inner=$1
[ -n "$inpool" ] && [ -n "$outpool" ] || return 1
idx=0
inner_idx=
for p in $(port_pool_inner_candidates); do
idx=$((idx + 1))
[ "$p" = "$inner" ] && { inner_idx=$idx; break; }
done
[ -n "$inner_idx" ] || return 1
idx=0
for p in $(port_pool_outer_candidates); do
idx=$((idx + 1))
[ "$idx" = "$inner_idx" ] && { printf '%s\n' "$p"; return 0; }
done
return 1
}

pool_inner_for_public(){
public=$1
[ -n "$inpool" ] && [ -n "$outpool" ] || return 1
idx=0
public_idx=
for p in $(port_pool_outer_candidates); do
idx=$((idx + 1))
[ "$p" = "$public" ] && { public_idx=$idx; break; }
done
[ -n "$public_idx" ] || return 1
idx=0
for p in $(port_pool_inner_candidates); do
idx=$((idx + 1))
[ "$idx" = "$public_idx" ] && { printf '%s\n' "$p"; return 0; }
done
return 1
}

load_subip_mode_config(){
if [ -n "$subipmode" ]; then
case "$subipmode" in
ipv4|ipv6|both)
printf "%s\n" "$subipmode" > "$HOME/lun/subip_mode"
;;
del|none|off)
rm -f "$HOME/lun/subip_mode"
subipmode=ipv4
;;
*)
echo "subipmode 只支持 ipv4、ipv6、both。"
exit 1
;;
esac
elif [ -s "$HOME/lun/subip_mode" ]; then
subipmode=$(cat "$HOME/lun/subip_mode" 2>/dev/null)
else
subipmode=ipv4
fi
case "$subipmode" in ipv4|ipv6|both) ;; *) subipmode=ipv4 ;; esac
}

is_ip_literal(){
host=$1
case "$host" in
\[*\]) return 0 ;;
*.*)
printf '%s' "$host" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'
return $?
;;
*:*) return 0 ;;
*) return 1 ;;
esac
}

load_domain_cert_config(){
if [ -n "$domain" ]; then
case "$domain" in
del|none)
rm -f "$HOME/lun/domain"
domain=
;;
*)
if ! valid_domain "$domain"; then
echo "domain 只支持已解析的纯域名，例如 proxy.example.com，不要带 http://、端口或路径。"
exit 1
fi
printf "%s\n" "$domain" > "$HOME/lun/domain"
;;
esac
elif [ -s "$HOME/lun/domain" ]; then
domain=$(cat "$HOME/lun/domain" 2>/dev/null)
fi

if [ -n "$certmode" ]; then
case "$certmode" in
self|domain|dns|ip)
printf "%s\n" "$certmode" > "$HOME/lun/cert_mode"
;;
del|none)
rm -f "$HOME/lun/cert_mode" "$HOME/lun/cert_subject" "$HOME/lun/acme_dns"
certmode=self
;;
*)
echo "certmode 只支持 self、domain、dns、ip。"
exit 1
;;
esac
elif [ -s "$HOME/lun/cert_mode" ]; then
certmode=$(cat "$HOME/lun/cert_mode" 2>/dev/null)
else
certmode=self
fi

[ -n "$acme_email" ] && printf "%s\n" "$acme_email" > "$HOME/lun/acme_email"
[ -n "$acme_dns" ] && { printf "%s\n" "$acme_dns" > "$HOME/lun/acme_dns"; chmod 600 "$HOME/lun/acme_dns" 2>/dev/null; }

if [ -n "$domain" ] && [ -z "$addym" ] && [ -z "$addout" ]; then
addym="$domain"
addout=replace
fi
}

load_addym_config(){
if [ -n "$addym" ]; then
case "$addym" in
del|none)
rm -f "$HOME/lun/addym" "$HOME/lun/addout"
addym=
addout=off
;;
*)
if ! valid_addym "$addym"; then
echo "addym 只需要填写域名或 IP，例如 proxy.example.com，不要带 http://、https://、端口或路径。"
exit 1
fi
printf "%s\n" "$addym" > "$HOME/lun/addym"
;;
esac
elif [ -s "$HOME/lun/addym" ]; then
addym=$(cat "$HOME/lun/addym" 2>/dev/null)
fi

if [ -n "$addout" ]; then
case "$addout" in
off)
rm -f "$HOME/lun/addym" "$HOME/lun/addout"
addym=
addout=off
;;
replace|both)
printf "%s\n" "$addout" > "$HOME/lun/addout"
;;
*)
echo "addout 只支持 off、replace、both。"
exit 1
;;
esac
elif [ -s "$HOME/lun/addout" ]; then
addout=$(cat "$HOME/lun/addout" 2>/dev/null)
else
[ -n "$addym" ] && addout=replace || addout=off
fi
}

download_lun_script(){
target=$1
tmp="${target}.tmp.$$"
rm -f "$tmp"
if command -v curl >/dev/null 2>&1 && curl -fsSL --connect-timeout 10 --max-time 30 --retry 2 "$lunurl" -o "$tmp"; then
:
elif command -v wget >/dev/null 2>&1 && wget -qO "$tmp" --timeout=30 --tries=2 "$lunurl"; then
:
else
rm -f "$tmp"
return 1
fi
mv "$tmp" "$target"
chmod +x "$target"
}

install_lun_entry(){
target=$1
tmp="${target}.tmp.$$"
current_script=$0
current_base=$(basename "$current_script" 2>/dev/null)
rm -f "$tmp"
case "$current_base" in
bash|sh|dash|ash|'')
current_script=
;;
esac
case "$current_script" in
/dev/fd/*|/proc/*/fd/*|/proc/self/fd/*)
current_script=
;;
esac
if [ -n "$current_script" ] && [ -r "$current_script" ] && cp "$current_script" "$tmp" 2>/dev/null; then
mv "$tmp" "$target"
chmod +x "$target"
return 0
fi
rm -f "$tmp"
download_lun_script "$target"
}

ensure_lun_command(){
if [ "$(id -u 2>/dev/null)" = "0" ]; then
target="/usr/bin/lun"
else
target="$HOME/bin/lun"
mkdir -p "$HOME/bin"
fi
if [ ! -s "$target" ] || [ "$LUN_MENU_REQUEST" = yes ]; then
install_lun_entry "$target" >/dev/null 2>&1 || return 1
fi
if [ "$target" = "$HOME/bin/lun" ]; then
grep -qxF 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null || echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
fi
}

if [ "$1" != "del" ]; then
migrate_lun_state
mkdir -p "$HOME/lun"
[ -n "$ARGO_AUTH" ] && ARGO_AUTH=$(sanitize_argo_token "$ARGO_AUTH")
load_domain_cert_config
load_addym_config
load_port_map_config
load_port_pool_config
load_vps_mode_config
load_argoip_config
load_subip_mode_config
ensure_lun_command || true
if [ ! -f sbx_update ]; then
echo "执行必要的脚本依赖中，请稍等10秒……"
if command -v apk >/dev/null 2>&1; then
apk update >/dev/null 2>&1 && apk add --no-cache bash busybox-extras gcompat libc6-compat iptables openssl >/dev/null 2>&1
elif command -v apt >/dev/null 2>&1; then
export DEBIAN_FRONTEND=noninteractive
printf 'iptables-persistent iptables-persistent/autosave_v4 boolean true\niptables-persistent iptables-persistent/autosave_v6 boolean true\n' | debconf-set-selections
apt update >/dev/null 2>&1 && apt install -y busybox coreutils util-linux iptables iptables-persistent cron openssl >/dev/null 2>&1
fi
touch sbx_update
fi
fi
v4v6(){
v4=$( (command -v curl >/dev/null 2>&1 && curl -s4m5 -k "$v46url" 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget -4 --tries=2 -qO- "$v46url" 2>/dev/null) )
v6=$( (command -v curl >/dev/null 2>&1 && curl -s6m5 -k "$v46url" 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget -6 --tries=2 -qO- "$v46url" 2>/dev/null) )
v4dq=$( (command -v curl >/dev/null 2>&1 && curl -s4m5 -k https://myip.ipip.net/ | awk -F'来自于：' '{print $2}' 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget -4 --tries=2 -qO- https://myip.ipip.net/ | awk -F'来自于：' '{print $2}' 2>/dev/null) )
v6dq=$( (command -v curl >/dev/null 2>&1 && curl -s6m5 -k https://ip.fm | sed -n 's/.*Location: //p' 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget -6 --tries=2 -qO- https://ip.fm | grep '<span class="has-text-grey-light">Location:' | tail -n1 | sed -E 's/.*>Location: <\/span>([^<]+)<.*/\1/' 2>/dev/null) )
}
warpsx(){
warpurl=$( (command -v curl >/dev/null 2>&1 && curl -sm5 -k https://warp.xijp.eu.org 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget --tries=2 -qO- https://warp.xijp.eu.org 2>/dev/null) )
if [ -z "$warpurl" ] || printf '%s' "$warpurl" | grep -q html; then
wpv6='2606:4700:110:8d8d:1845:c39f:2dd5:a03a'
pvk='52cuYFgCJXp0LAq7+nWJIbCXXgU9eGggOc+Hlfz5u6A='
res='[215, 69, 233]'
else
pvk=$(echo "$warpurl" | awk -F'：' '/Private_key/{print $2}' | xargs)
wpv6=$(echo "$warpurl" | awk -F'：' '/IPV6/{print $2}' | xargs)
res=$(echo "$warpurl" | awk -F'：' '/reserved/{print $2}' | xargs)
fi
if [ -n "$name" ]; then
sxname=$name-
echo "$sxname" > "$HOME/lun/name"
echo
echo "所有节点名称前缀：$name"
fi
v4v6
if echo "$v6" | grep -q '^2a09' || echo "$v4" | grep -q '^104.28'; then
s1outtag=direct; s2outtag=direct; x1outtag=direct; x2outtag=direct; xip='"::/0", "0.0.0.0/0"'; sip='"::/0", "0.0.0.0/0"'; wap=warpargo
echo; echo "请注意：你已安装了warp"
else
if [ "$wap" != yes ]; then
s1outtag=direct; s2outtag=direct; x1outtag=direct; x2outtag=direct; xip='"::/0", "0.0.0.0/0"'; sip='"::/0", "0.0.0.0/0"'; wap=warpargo
else
case "$warp" in
""|sx|xs) s1outtag=warp-out; s2outtag=warp-out; x1outtag=warp-out; x2outtag=warp-out; xip='"::/0", "0.0.0.0/0"'; sip='"::/0", "0.0.0.0/0"'; wap=warp ;;
s ) s1outtag=warp-out; s2outtag=warp-out; x1outtag=direct; x2outtag=direct; xip='"::/0", "0.0.0.0/0"'; sip='"::/0", "0.0.0.0/0"'; wap=warp ;;
s4) s1outtag=warp-out; s2outtag=direct; x1outtag=direct; x2outtag=direct; xip='"::/0", "0.0.0.0/0"'; sip='"0.0.0.0/0"'; wap=warp ;;
s6) s1outtag=warp-out; s2outtag=direct; x1outtag=direct; x2outtag=direct; xip='"::/0", "0.0.0.0/0"'; sip='"::/0"'; wap=warp ;;
x ) s1outtag=direct; s2outtag=direct; x1outtag=warp-out; x2outtag=warp-out; xip='"::/0", "0.0.0.0/0"'; sip='"::/0", "0.0.0.0/0"'; wap=warp ;;
x4) s1outtag=direct; s2outtag=direct; x1outtag=warp-out; x2outtag=direct; xip='"0.0.0.0/0"'; sip='"::/0", "0.0.0.0/0"'; wap=warp ;;
x6) s1outtag=direct; s2outtag=direct; x1outtag=warp-out; x2outtag=direct; xip='"::/0"'; sip='"::/0", "0.0.0.0/0"'; wap=warp ;;
s4x4|x4s4) s1outtag=warp-out; s2outtag=direct; x1outtag=warp-out; x2outtag=direct; xip='"0.0.0.0/0"'; sip='"0.0.0.0/0"'; wap=warp ;;
s4x6|x6s4) s1outtag=warp-out; s2outtag=direct; x1outtag=warp-out; x2outtag=direct; xip='"::/0"'; sip='"0.0.0.0/0"'; wap=warp ;;
s6x4|x4s6) s1outtag=warp-out; s2outtag=direct; x1outtag=warp-out; x2outtag=direct; xip='"0.0.0.0/0"'; sip='"::/0"'; wap=warp ;;
s6x6|x6s6) s1outtag=warp-out; s2outtag=direct; x1outtag=warp-out; x2outtag=direct; xip='"::/0"'; sip='"::/0"'; wap=warp ;;
sx4|x4s) s1outtag=warp-out; s2outtag=warp-out; x1outtag=warp-out; x2outtag=direct; xip='"0.0.0.0/0"'; sip='"::/0", "0.0.0.0/0"'; wap=warp ;;
sx6|x6s) s1outtag=warp-out; s2outtag=warp-out; x1outtag=warp-out; x2outtag=direct; xip='"::/0"'; sip='"::/0", "0.0.0.0/0"'; wap=warp ;;
xs4|s4x) s1outtag=warp-out; s2outtag=direct; x1outtag=warp-out; x2outtag=warp-out; xip='"::/0", "0.0.0.0/0"'; sip='"0.0.0.0/0"'; wap=warp ;;
xs6|s6x) s1outtag=warp-out; s2outtag=direct; x1outtag=warp-out; x2outtag=warp-out; xip='"::/0", "0.0.0.0/0"'; sip='"::/0"'; wap=warp ;;
* ) s1outtag=direct; s2outtag=direct; x1outtag=direct; x2outtag=direct; xip='"::/0", "0.0.0.0/0"'; sip='"::/0", "0.0.0.0/0"'; wap=warpargo ;;
esac
fi
fi
case "$warp" in *x4*) wxryx='ForceIPv4' ;; *x6*) wxryx='ForceIPv6' ;; *) wxryx='ForceIPv6v4' ;; esac
if command -v curl >/dev/null 2>&1; then
curl -s4m5 -k "$v46url" >/dev/null 2>&1 && v4_ok=true
elif command -v wget >/dev/null 2>&1; then
timeout 3 wget -4 --tries=2 -qO- "$v46url" >/dev/null 2>&1 && v4_ok=true
fi
if command -v curl >/dev/null 2>&1; then
curl -s6m5 -k "$v46url" >/dev/null 2>&1 && v6_ok=true
elif command -v wget >/dev/null 2>&1; then
timeout 3 wget -6 --tries=2 -qO- "$v46url" >/dev/null 2>&1 && v6_ok=true
fi
if [ "$v4_ok" = true ] && [ "$v6_ok" = true ]; then
case "$warp" in *s4*) sbyx='prefer_ipv4' ;; *) sbyx='prefer_ipv6' ;; esac
case "$warp" in *x4*) xryx='ForceIPv4v6' ;; *x*) xryx='ForceIPv6v4' ;; *) xryx='ForceIPv4v6' ;; esac
elif [ "$v4_ok" = true ] && [ "$v6_ok" != true ]; then
case "$warp" in *s4*|x) sbyx='ipv4_only' ;; *) sbyx='prefer_ipv6' ;; esac
case "$warp" in *x4*) xryx='ForceIPv4' ;; *x*) xryx='ForceIPv6v4' ;; *) xryx='ForceIPv4v6' ;; esac
elif [ "$v4_ok" != true ] && [ "$v6_ok" = true ]; then
case "$warp" in *s6*|x) sbyx='ipv6_only' ;; *) sbyx='prefer_ipv4' ;; esac
case "$warp" in *x6*) xryx='ForceIPv6' ;; *x*) xryx='ForceIPv4v6' ;; *) xryx='ForceIPv6v4' ;; esac
fi
}
upxray(){
url="https://github.com/azk78lun-collab/FHLUN/releases/download/lun/xray-$cpu"; out="$HOME/lun/xray"; (command -v curl >/dev/null 2>&1 && curl -Lo "$out" -# --retry 2 "$url") || (command -v wget>/dev/null 2>&1 && timeout 3 wget -O "$out" --tries=2 "$url")
chmod +x "$HOME/lun/xray"
sbcore=$("$HOME/lun/xray" version 2>/dev/null | awk '/^Xray/{print $2}')
echo "已安装Xray正式版内核：$sbcore"
}
upsingbox(){
url="https://github.com/azk78lun-collab/FHLUN/releases/download/lun/sing-box-$cpu"; out="$HOME/lun/sing-box"; (command -v curl>/dev/null 2>&1 && curl -Lo "$out" -# --retry 2 "$url") || (command -v wget>/dev/null 2>&1 && timeout 3 wget -O "$out" --tries=2 "$url")
chmod +x "$HOME/lun/sing-box"
sbcore=$("$HOME/lun/sing-box" version 2>/dev/null | awk '/version/{print $NF}')
echo "已安装Sing-box正式版内核：$sbcore"
}

cert_hash_update(){
if [ -f "$HOME/lun/cert.crt" ]; then
SHA256=$(openssl x509 -in "$HOME/lun/cert.crt" -outform DER 2>/dev/null | sha256sum | awk '{print $1}')
[ -n "$SHA256" ] && echo "$SHA256" > "$HOME/lun/SHA256.txt"
fi
}

gen_random_gmail(){
local prefix
prefix=$(tr -dc 'a-z0-9' </dev/urandom 2>/dev/null | head -c 10)
[ -z "$prefix" ] && prefix="lun$(date +%s 2>/dev/null | tail -c 6)"
[ -z "$prefix" ] && prefix="lun$(od -An -N4 -tu4 </dev/urandom 2>/dev/null | tr -d ' ')"
printf '%s@gmail.com\n' "$prefix"
}

reuse_local_cert_interactive(){
[ -f "$HOME/lun/cert.crt" ] && [ -f "$HOME/lun/private.key" ] || return 1
[ -t 0 ] || return 1
local subj
subj=$(cat "$HOME/lun/cert_subject" 2>/dev/null)
[ -z "$subj" ] && subj=$(openssl x509 -in "$HOME/lun/cert.crt" -noout -subject 2>/dev/null | sed 's/subject=[ ]*//;s/[\/]CN=//;s/,.*//')
[ -z "$subj" ] && subj="已存在"
printf "检测到本机已有证书（主体：%s），是否复用已有证书，跳过重新生成？[Y/n]：" "$subj"
IFS= read -r ans
case "$ans" in
n|N) return 1 ;;
*) echo "已复用本机已有证书，跳过证书生成。"; return 0 ;;
esac
}

cert_subject_default(){
if [ -n "$domain" ]; then
printf '%s\n' "$domain"
elif [ -s "$HOME/lun/cert_subject" ]; then
cat "$HOME/lun/cert_subject" 2>/dev/null
else
printf '%s\n' "www.bing.com"
fi
}

self_signed_cert(){
subject=$(cert_subject_default)
[ -z "$subject" ] && subject=www.bing.com
rm -f "$HOME/lun/private.key" "$HOME/lun/cert.crt" "$HOME/lun/SHA256.txt"
openssl ecparam -genkey -name prime256v1 -out "$HOME/lun/private.key" >/dev/null 2>&1 || return 1
openssl req -new -x509 -days 36500 -key "$HOME/lun/private.key" -out "$HOME/lun/cert.crt" -subj "/CN=$subject" >/dev/null 2>&1 || return 1
echo "self" > "$HOME/lun/cert_mode"
echo "$subject" > "$HOME/lun/cert_subject"
cert_hash_update
}

local_public_ips(){
{
(command -v curl >/dev/null 2>&1 && { curl -s4m5 -k "$v46url" 2>/dev/null; curl -s6m5 -k "$v46url" 2>/dev/null; }) || \
(command -v wget >/dev/null 2>&1 && { timeout 3 wget -4 --tries=2 -qO- "$v46url" 2>/dev/null; echo; timeout 3 wget -6 --tries=2 -qO- "$v46url" 2>/dev/null; })
} | sed '/^$/d'
}

resolve_domain_ips(){
host=$1
{ getent ahosts "$host" 2>/dev/null | awk '{print $1}'; nslookup "$host" 2>/dev/null | awk '/^Address: /{print $2}'; } | sed 's/^\[//; s/\]$//' | sort -u
}

domain_matches_local_ip(){
host=$1
resolved=$(resolve_domain_ips "$host")
[ -n "$resolved" ] || return 1
local_ips=$(local_public_ips)
for rip in $resolved; do
for lip in $local_ips; do
[ "$rip" = "$lip" ] && return 0
done
done
return 1
}

ensure_acme_sh(){
if [ -x "$HOME/.acme.sh/acme.sh" ]; then
return 0
fi
email=$acme_email
[ -z "$email" ] && [ -s "$HOME/lun/acme_email" ] && email=$(cat "$HOME/lun/acme_email" 2>/dev/null)
if [ -z "$email" ]; then
email=$(gen_random_gmail)
printf '%s\n' "$email" > "$HOME/lun/acme_email"
echo "未设置 ACME 邮箱，已随机生成谷歌邮箱：$email"
fi
if command -v curl >/dev/null 2>&1; then
if [ -n "$email" ]; then
curl -fsSL https://get.acme.sh | sh -s email="$email" >/dev/null 2>&1 || return 1
else
curl -fsSL https://get.acme.sh | sh >/dev/null 2>&1 || return 1
fi
elif command -v wget >/dev/null 2>&1; then
if [ -n "$email" ]; then
wget -qO- https://get.acme.sh | sh -s email="$email" >/dev/null 2>&1 || return 1
else
wget -qO- https://get.acme.sh | sh >/dev/null 2>&1 || return 1
fi
else
return 1
fi
"$HOME/.acme.sh/acme.sh" --set-default-ca --server letsencrypt >/dev/null 2>&1 || true
}

install_acme_cert(){
subject=$1
mode=$2
acme="$HOME/.acme.sh/acme.sh"
"$acme" --install-cert -d "$subject" --ecc \
--key-file "$HOME/lun/private.key" \
--fullchain-file "$HOME/lun/cert.crt" \
--reloadcmd "lun res >/dev/null 2>&1 || true" >/dev/null 2>&1 || return 1
echo "$mode" > "$HOME/lun/cert_mode"
echo "$subject" > "$HOME/lun/cert_subject"
cert_hash_update
}

issue_acme_cert(){
mode=$1
subject=$2
[ -z "$subject" ] && return 1
ensure_acme_sh || return 1
acme="$HOME/.acme.sh/acme.sh"
case "$mode" in
domain)
domain_matches_local_ip "$subject" || { echo "域名 $subject 未解析到本机公网 IP，已跳过 ACME 域名证书申请。"; return 1; }
"$acme" --issue --server letsencrypt --keylength ec-256 -d "$subject" --standalone >/dev/null 2>&1 || return 1
;;
dns)
[ -s "$HOME/lun/cert.env" ] && . "$HOME/lun/cert.env"
[ -z "$acme_dns" ] && [ -s "$HOME/lun/acme_dns" ] && acme_dns=$(cat "$HOME/lun/acme_dns" 2>/dev/null)
[ -n "$acme_dns" ] || return 1
"$acme" --issue --server letsencrypt --keylength ec-256 -d "$subject" --dns "$acme_dns" >/dev/null 2>&1 || return 1
;;
ip)
ip_subject=$subject
ip_subject=$(printf '%s' "$ip_subject" | sed 's/^\[//; s/\]$//')
is_ip_literal "$ip_subject" || return 1
"$acme" --issue --server letsencrypt --keylength ec-256 --cert-profile shortlived --days 3 -d "$ip_subject" --standalone >/dev/null 2>&1 || return 1
subject="$ip_subject"
;;
*) return 1 ;;
esac
install_acme_cert "$subject" "$mode"
}

prepare_runtime_cert(){
load_domain_cert_config
if reuse_local_cert_interactive; then return 0; fi
subject=$(cert_subject_default)
case "$certmode" in
domain|dns)
[ -n "$domain" ] && subject="$domain"
echo "证书模式：ACME $certmode，证书主体：$subject"
issue_acme_cert "$certmode" "$subject" && return 0
echo "ACME 证书申请失败或条件不满足，自动恢复自签证书。"
self_signed_cert
;;
ip)
subject=$(cat "$HOME/lun/server_ip.log" 2>/dev/null)
[ -z "$subject" ] && subject=$(local_public_ips | sed -n 1p)
echo "证书模式：ACME IP short-lived，证书主体：$subject"
issue_acme_cert ip "$subject" && return 0
echo "ACME IP 证书申请失败，自动恢复自签证书。"
self_signed_cert
;;
self|*)
if [ ! -f "$HOME/lun/private.key" ] || [ ! -f "$HOME/lun/cert.crt" ] || [ ! -f "$HOME/lun/SHA256.txt" ]; then
self_signed_cert
else
cert_hash_update
fi
;;
esac
}

cert_client_vars(){
cert_mode_current=$(cat "$HOME/lun/cert_mode" 2>/dev/null)
[ -z "$cert_mode_current" ] && cert_mode_current=self
cert_sni=$(cat "$HOME/lun/cert_subject" 2>/dev/null)
[ -z "$cert_sni" ] && cert_sni=www.bing.com
SHA256=$(cat "$HOME/lun/SHA256.txt" 2>/dev/null)
if [ "$cert_mode_current" = "self" ]; then
hy2_pin_arg="&pinSHA256=$SHA256"
hy2_link_insecure=0
generic_link_insecure=1
sbox_tls_insecure=true
clash_skip_verify=true
clash_disable_sni=true
else
hy2_pin_arg=
hy2_link_insecure=0
generic_link_insecure=0
sbox_tls_insecure=false
clash_skip_verify=false
clash_disable_sni=false
fi
}

insuuid(){
if [ -z "$uuid" ] && [ ! -e "$HOME/lun/uuid" ]; then
if [ -e "$HOME/lun/sing-box" ]; then
uuid=$("$HOME/lun/sing-box" generate uuid)
else
uuid=$("$HOME/lun/xray" uuid)
fi
echo "$uuid" > "$HOME/lun/uuid"
elif [ -n "$uuid" ]; then
echo "$uuid" > "$HOME/lun/uuid"
fi
uuid=$(cat "$HOME/lun/uuid")
echo "UUID密码：$uuid"
}
installxray(){
echo
echo "=========启用xray内核========="
mkdir -p "$HOME/lun/xrk"
if [ ! -e "$HOME/lun/xray" ]; then
upxray
fi
cat > "$HOME/lun/xr.json" <<EOF
{
  "log": {
  "loglevel": "none"
  },
  "inbounds": [
EOF
insuuid
if [ -n "$xhp" ] || [ -n "$vlp" ]; then
if [ -z "$ym_vl_re" ]; then
ym_vl_re=apple.com
fi
echo "$ym_vl_re" > "$HOME/lun/ym_vl_re"
echo "Reality域名：$ym_vl_re"
if [ ! -e "$HOME/lun/xrk/private_key" ]; then
key_pair=$("$HOME/lun/xray" x25519)
private_key=$(echo "$key_pair" | awk -F':' '/PrivateKey/ {print $2}' | xargs)
public_key=$(echo "$key_pair" | awk -F':' '/Password/ {print $2}' | xargs)
short_id=$(date +%s%N | sha256sum | cut -c 1-8)
echo "$private_key" > "$HOME/lun/xrk/private_key"
echo "$public_key" > "$HOME/lun/xrk/public_key"
echo "$short_id" > "$HOME/lun/xrk/short_id"
fi
private_key_x=$(cat "$HOME/lun/xrk/private_key")
public_key_x=$(cat "$HOME/lun/xrk/public_key")
short_id_x=$(cat "$HOME/lun/xrk/short_id")
fi
if [ -n "$xhp" ] || [ -n "$vxp" ] || [ -n "$vwp" ]; then
if [ ! -e "$HOME/lun/xrk/dekey" ]; then
vlkey=$("$HOME/lun/xray" vlessenc)
dekey=$(echo "$vlkey" | grep '"decryption":' | sed -n '2p' | cut -d' ' -f2- | tr -d '"')
enkey=$(echo "$vlkey" | grep '"encryption":' | sed -n '2p' | cut -d' ' -f2- | tr -d '"')
echo "$dekey" > "$HOME/lun/xrk/dekey"
echo "$enkey" > "$HOME/lun/xrk/enkey"
fi
dekey=$(cat "$HOME/lun/xrk/dekey")
enkey=$(cat "$HOME/lun/xrk/enkey")
fi

if [ -n "$xhp" ]; then
xhp=xhpt
if [ -z "$port_xh" ] && [ ! -e "$HOME/lun/port_xh" ]; then
port_xh=$(random_port 2>/dev/null || shuf -i 10000-65535 -n 1)
echo "$port_xh" > "$HOME/lun/port_xh"
elif [ -n "$port_xh" ]; then
echo "$port_xh" > "$HOME/lun/port_xh"
fi
port_xh=$(cat "$HOME/lun/port_xh")
echo "Vless-xhttp-reality-enc端口：$port_xh"
cat >> "$HOME/lun/xr.json" <<EOF
    {
      "tag":"xhttp-reality",
      "listen": "::",
      "port": ${port_xh},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "${dekey}"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "reality",
        "realitySettings": {
          "fingerprint": "chrome",
          "target": "${ym_vl_re}:443",
          "serverNames": [
            "${ym_vl_re}"
          ],
          "privateKey": "$private_key_x",
          "shortIds": ["$short_id_x"]
        },
        "xhttpSettings": {
          "host": "",
          "path": "${uuid}-xh",
          "mode": "auto"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "metadataOnly": false
      }
    },
EOF
else
xhp=xhptargo
fi
if [ -n "$vxp" ]; then
vxp=vxpt
if [ -z "$port_vx" ] && [ ! -e "$HOME/lun/port_vx" ]; then
port_vx=$(random_port 2>/dev/null || shuf -i 10000-65535 -n 1)
echo "$port_vx" > "$HOME/lun/port_vx"
elif [ -n "$port_vx" ]; then
echo "$port_vx" > "$HOME/lun/port_vx"
fi
port_vx=$(cat "$HOME/lun/port_vx")
echo "Vless-xhttp-enc端口：$port_vx"
if [ -n "$cdnym" ]; then
echo "$cdnym" > "$HOME/lun/cdnym"
echo "80系CDN或者回源CDN的host域名 (确保IP已解析在CF域名)：$cdnym"
fi
cat >> "$HOME/lun/xr.json" <<EOF
    {
      "tag":"vless-xhttp",
      "listen": "::",
      "port": ${port_vx},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "${dekey}"
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "host": "",
          "path": "${uuid}-vx",
          "mode": "auto"
        }
      },
        "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "metadataOnly": false
      }
    },
EOF
else
vxp=vxptargo
fi
if [ -n "$vwp" ]; then
vwp=vwpt
if [ -z "$port_vw" ] && [ ! -e "$HOME/lun/port_vw" ]; then
port_vw=$(random_port 2>/dev/null || shuf -i 10000-65535 -n 1)
echo "$port_vw" > "$HOME/lun/port_vw"
elif [ -n "$port_vw" ]; then
echo "$port_vw" > "$HOME/lun/port_vw"
fi
port_vw=$(cat "$HOME/lun/port_vw")
echo "Vless-ws-enc端口：$port_vw"
if [ -n "$cdnym" ]; then
echo "$cdnym" > "$HOME/lun/cdnym"
echo "80系CDN或者回源CDN的host域名 (确保IP已解析在CF域名)：$cdnym"
fi
cat >> "$HOME/lun/xr.json" <<EOF
    {
      "tag":"vless-ws",
      "listen": "::",
      "port": ${port_vw},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "${dekey}"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "${uuid}-vw"
        }
      },
        "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "metadataOnly": false
      }
    },
EOF
else
vwp=vwptargo
fi
if [ -n "$vlp" ]; then
vlp=vlpt
if [ -z "$port_vl_re" ] && [ ! -e "$HOME/lun/port_vl_re" ]; then
port_vl_re=$(random_port 2>/dev/null || shuf -i 10000-65535 -n 1)
echo "$port_vl_re" > "$HOME/lun/port_vl_re"
elif [ -n "$port_vl_re" ]; then
echo "$port_vl_re" > "$HOME/lun/port_vl_re"
fi
port_vl_re=$(cat "$HOME/lun/port_vl_re")
echo "Vless-tcp-reality-v端口：$port_vl_re"
cat >> "$HOME/lun/xr.json" <<EOF
        {
            "tag":"reality-vision",
            "listen": "::",
            "port": $port_vl_re,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${uuid}",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "fingerprint": "chrome",
                    "dest": "${ym_vl_re}:443",
                    "serverNames": [
                      "${ym_vl_re}"
                    ],
                    "privateKey": "$private_key_x",
                    "shortIds": ["$short_id_x"]
                }
            },
          "sniffing": {
          "enabled": true,
          "destOverride": ["http", "tls", "quic"],
          "metadataOnly": false
      }
    },
EOF
else
vlp=vlptargo
fi
}

installsb(){
echo
echo "=========启用Sing-box内核========="
if [ ! -e "$HOME/lun/sing-box" ]; then
upsingbox
fi
cat > "$HOME/lun/sb.json" <<EOF
{
"log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
EOF
insuuid
prepare_runtime_cert
if [ -n "$hyp" ]; then
hyp=hypt
if [ -z "$port_hy2" ] && [ ! -e "$HOME/lun/port_hy2" ]; then
port_hy2=$(random_port 2>/dev/null || shuf -i 10000-65535 -n 1)
echo "$port_hy2" > "$HOME/lun/port_hy2"
elif [ -n "$port_hy2" ]; then
echo "$port_hy2" > "$HOME/lun/port_hy2"
fi
port_hy2=$(cat "$HOME/lun/port_hy2")
echo "Hysteria2端口：$port_hy2"
cat >> "$HOME/lun/sb.json" <<EOF
    {
        "type": "hysteria2",
        "tag": "hy2-sb",
        "listen": "::",
        "listen_port": ${port_hy2},
        "users": [
            {
                "password": "${uuid}"
            }
        ],
        "ignore_client_bandwidth":false,
        "tls": {
            "enabled": true,
            "alpn": [
                "h3"
            ],
            "certificate_path": "$HOME/lun/cert.crt",
            "key_path": "$HOME/lun/private.key"
        }
    },
EOF
else
hyp=hyptargo
fi
if [ -n "$tup" ]; then
tup=tupt
if [ -z "$port_tu" ] && [ ! -e "$HOME/lun/port_tu" ]; then
port_tu=$(random_port 2>/dev/null || shuf -i 10000-65535 -n 1)
echo "$port_tu" > "$HOME/lun/port_tu"
elif [ -n "$port_tu" ]; then
echo "$port_tu" > "$HOME/lun/port_tu"
fi
port_tu=$(cat "$HOME/lun/port_tu")
echo "Tuic端口：$port_tu"
cat >> "$HOME/lun/sb.json" <<EOF
        {
            "type":"tuic",
            "tag": "tuic5-sb",
            "listen": "::",
            "listen_port": ${port_tu},
            "users": [
                {
                    "uuid": "${uuid}",
                    "password": "${uuid}"
                }
            ],
            "congestion_control": "bbr",
            "tls":{
                "enabled": true,
                "alpn": [
                    "h3"
                ],
                "certificate_path": "$HOME/lun/cert.crt",
                "key_path": "$HOME/lun/private.key"
            }
        },
EOF
else
tup=tuptargo
fi
if [ -n "$anp" ]; then
anp=anpt
if [ -z "$port_an" ] && [ ! -e "$HOME/lun/port_an" ]; then
port_an=$(random_port 2>/dev/null || shuf -i 10000-65535 -n 1)
echo "$port_an" > "$HOME/lun/port_an"
elif [ -n "$port_an" ]; then
echo "$port_an" > "$HOME/lun/port_an"
fi
port_an=$(cat "$HOME/lun/port_an")
echo "Anytls端口：$port_an"
cat >> "$HOME/lun/sb.json" <<EOF
        {
            "type":"anytls",
            "tag":"anytls-sb",
            "listen":"::",
            "listen_port":${port_an},
            "users":[
                {
                  "password":"${uuid}"
                }
            ],
            "padding_scheme":[],
            "tls":{
                "enabled": true,
                "certificate_path": "$HOME/lun/cert.crt",
                "key_path": "$HOME/lun/private.key"
            }
        },
EOF
else
anp=anptargo
fi
if [ -n "$arp" ]; then
arp=arpt
if [ -z "$ym_vl_re" ]; then
ym_vl_re=apple.com
fi
echo "$ym_vl_re" > "$HOME/lun/ym_vl_re"
echo "Reality域名：$ym_vl_re"
mkdir -p "$HOME/lun/sbk"
if [ ! -e "$HOME/lun/sbk/private_key" ]; then
key_pair=$("$HOME/lun/sing-box" generate reality-keypair)
private_key=$(echo "$key_pair" | awk '/PrivateKey/ {print $2}' | tr -d '"')
public_key=$(echo "$key_pair" | awk '/PublicKey/ {print $2}' | tr -d '"')
short_id=$("$HOME/lun/sing-box" generate rand --hex 4)
echo "$private_key" > "$HOME/lun/sbk/private_key"
echo "$public_key" > "$HOME/lun/sbk/public_key"
echo "$short_id" > "$HOME/lun/sbk/short_id"
fi
private_key_s=$(cat "$HOME/lun/sbk/private_key")
public_key_s=$(cat "$HOME/lun/sbk/public_key")
short_id_s=$(cat "$HOME/lun/sbk/short_id")
if [ -z "$port_ar" ] && [ ! -e "$HOME/lun/port_ar" ]; then
port_ar=$(random_port 2>/dev/null || shuf -i 10000-65535 -n 1)
echo "$port_ar" > "$HOME/lun/port_ar"
elif [ -n "$port_ar" ]; then
echo "$port_ar" > "$HOME/lun/port_ar"
fi
port_ar=$(cat "$HOME/lun/port_ar")
echo "Any-Reality端口：$port_ar"
cat >> "$HOME/lun/sb.json" <<EOF
        {
            "type":"anytls",
            "tag":"anyreality-sb",
            "listen":"::",
            "listen_port":${port_ar},
            "users":[
                {
                  "password":"${uuid}"
                }
            ],
            "padding_scheme":[],
            "tls": {
            "enabled": true,
            "server_name": "${ym_vl_re}",
             "reality": {
              "enabled": true,
              "handshake": {
              "server": "${ym_vl_re}",
              "server_port": 443
             },
             "private_key": "$private_key_s",
             "short_id": ["$short_id_s"]
            }
          }
        },
EOF
else
arp=arptargo
fi
if [ -n "$ssp" ]; then
ssp=sspt
if [ ! -e "$HOME/lun/sskey" ]; then
sskey=$("$HOME/lun/sing-box" generate rand 16 --base64)
echo "$sskey" > "$HOME/lun/sskey"
fi
if [ -z "$port_ss" ] && [ ! -e "$HOME/lun/port_ss" ]; then
port_ss=$(random_port 2>/dev/null || shuf -i 10000-65535 -n 1)
echo "$port_ss" > "$HOME/lun/port_ss"
elif [ -n "$port_ss" ]; then
echo "$port_ss" > "$HOME/lun/port_ss"
fi
sskey=$(cat "$HOME/lun/sskey")
port_ss=$(cat "$HOME/lun/port_ss")
echo "Shadowsocks-2022端口：$port_ss"
cat >> "$HOME/lun/sb.json" <<EOF
        {
            "type": "shadowsocks",
            "tag":"ss-2022",
            "listen": "::",
            "listen_port": $port_ss,
            "method": "2022-blake3-aes-128-gcm",
            "password": "$sskey"
    },
EOF
else
ssp=ssptargo
fi
}

xrsbvm(){
if [ -n "$vmp" ]; then
vmp=vmpt
if [ -z "$port_vm_ws" ] && [ ! -e "$HOME/lun/port_vm_ws" ]; then
port_vm_ws=$(random_port 2>/dev/null || shuf -i 10000-65535 -n 1)
echo "$port_vm_ws" > "$HOME/lun/port_vm_ws"
elif [ -n "$port_vm_ws" ]; then
echo "$port_vm_ws" > "$HOME/lun/port_vm_ws"
fi
port_vm_ws=$(cat "$HOME/lun/port_vm_ws")
echo "Vmess-ws端口：$port_vm_ws"
if [ -n "$cdnym" ]; then
echo "$cdnym" > "$HOME/lun/cdnym"
echo "80系CDN或者回源CDN的host域名 (确保IP已解析在CF域名)：$cdnym"
fi
if [ -e "$HOME/lun/xr.json" ]; then
cat >> "$HOME/lun/xr.json" <<EOF
        {
            "tag": "vmess-xr",
            "listen": "::",
            "port": ${port_vm_ws},
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "${uuid}"
                    }
                ]
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                  "path": "${uuid}-vm"
            }
        },
            "sniffing": {
            "enabled": true,
            "destOverride": ["http", "tls", "quic"],
            "metadataOnly": false
            }
         },
EOF
else
cat >> "$HOME/lun/sb.json" <<EOF
{
        "type": "vmess",
        "tag": "vmess-sb",
        "listen": "::",
        "listen_port": ${port_vm_ws},
        "users": [
            {
                "uuid": "${uuid}",
                "alterId": 0
            }
        ],
        "transport": {
            "type": "ws",
            "path": "${uuid}-vm",
            "max_early_data":2048,
            "early_data_header_name": "Sec-WebSocket-Protocol"
        }
    },
EOF
fi
else
vmp=vmptargo
fi
}

xrsbso(){
if [ -n "$sop" ]; then
sop=sopt
if [ -z "$port_so" ] && [ ! -e "$HOME/lun/port_so" ]; then
port_so=$(random_port 2>/dev/null || shuf -i 10000-65535 -n 1)
echo "$port_so" > "$HOME/lun/port_so"
elif [ -n "$port_so" ]; then
echo "$port_so" > "$HOME/lun/port_so"
fi
port_so=$(cat "$HOME/lun/port_so")
echo "Socks5端口：$port_so"
if [ -e "$HOME/lun/xr.json" ]; then
cat >> "$HOME/lun/xr.json" <<EOF
        {
         "tag": "socks5-xr",
         "port": ${port_so},
         "listen": "::",
         "protocol": "socks",
         "settings": {
            "auth": "password",
             "accounts": [
               {
               "user": "${uuid}",
               "pass": "${uuid}"
               }
            ],
            "udp": true
          },
            "sniffing": {
            "enabled": true,
            "destOverride": ["http", "tls", "quic"],
            "metadataOnly": false
            }
         },
EOF
else
cat >> "$HOME/lun/sb.json" <<EOF
    {
      "tag": "socks5-sb",
      "type": "socks",
      "listen": "::",
      "listen_port": ${port_so},
      "users": [
      {
      "username": "${uuid}",
      "password": "${uuid}"
      }
     ]
    },
EOF
fi
else
sop=soptargo
fi
}

xrsbout(){
if [ -e "$HOME/lun/xr.json" ]; then
sed -i '${s/,\s*$//}' "$HOME/lun/xr.json"
cat >> "$HOME/lun/xr.json" <<EOF
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct",
      "settings": {
      "domainStrategy":"${xryx}"
     }
    },
    {
      "tag": "x-warp-out",
      "protocol": "wireguard",
      "settings": {
        "secretKey": "${pvk}",
        "address": [
          "172.16.0.2/32",
          "${wpv6}/128"
        ],
        "peers": [
          {
            "publicKey": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
            "allowedIPs": [
              "0.0.0.0/0",
              "::/0"
            ],
            "endpoint": "${xendip}:2408"
          }
        ],
        "reserved": ${res}
        }
    },
    {
      "tag":"warp-out",
      "protocol":"freedom",
        "settings":{
        "domainStrategy":"${wxryx}"
       },
       "proxySettings":{
       "tag":"x-warp-out"
     }
}
  ],
  "routing": {
    "domainStrategy": "IPOnDemand",
    "rules": [
      {
        "type": "field",
        "ip": [ ${xip} ],
        "network": "tcp,udp",
        "outboundTag": "${x1outtag}"
      },
      {
        "type": "field",
        "network": "tcp,udp",
        "outboundTag": "${x2outtag}"
      }
    ]
  }
}
EOF
if pidof systemd >/dev/null 2>&1 && [ "$(id -u 2>/dev/null)" = "0" ]; then
cat > /etc/systemd/system/xr.service <<EOF
[Unit]
Description=xr service
After=network.target
[Service]
Type=simple
NoNewPrivileges=yes
TimeoutStartSec=0
ExecStart=/root/lun/xray run -c /root/lun/xr.json
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >/dev/null 2>&1
systemctl enable xr >/dev/null 2>&1
systemctl start xr >/dev/null 2>&1
elif command -v rc-service >/dev/null 2>&1 && [ "$(id -u 2>/dev/null)" = "0" ]; then
cat > /etc/init.d/xray <<EOF
#!/sbin/openrc-run
description="xr service"
command="/root/lun/xray"
command_args="run -c /root/lun/xr.json"
command_background=yes
pidfile="/run/xray.pid"
command_background="yes"
depend() {
need net
}
EOF
chmod +x /etc/init.d/xray >/dev/null 2>&1
rc-update add xray default >/dev/null 2>&1
rc-service xray start >/dev/null 2>&1
else
nohup "$HOME/lun/xray" run -c "$HOME/lun/xr.json" >/dev/null 2>&1 &
fi
fi
if [ -e "$HOME/lun/sb.json" ]; then
sed -i '${s/,\s*$//}' "$HOME/lun/sb.json"
cat >> "$HOME/lun/sb.json" <<EOF
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "endpoints": [
    {
      "type": "wireguard",
      "tag": "warp-out",
      "address": [
        "172.16.0.2/32",
        "${wpv6}/128"
      ],
      "private_key": "${pvk}",
      "peers": [
        {
          "address": "${sendip}",
          "port": 2408,
          "public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
          "allowed_ips": [
            "0.0.0.0/0",
            "::/0"
          ],
          "reserved": $res
        }
      ]
    }
  ],
  "route": {
    "rules": [
       {
          "action": "sniff"
        },
       {
        "action": "resolve",
         "strategy": "${sbyx}"
       },
      {
        "ip_cidr": [ ${sip} ],
        "outbound": "${s1outtag}"
      }
    ],
    "final": "${s2outtag}"
  }
}
EOF
if pidof systemd >/dev/null 2>&1 && [ "$(id -u 2>/dev/null)" = "0" ]; then
cat > /etc/systemd/system/sb.service <<EOF
[Unit]
Description=sb service
After=network.target
[Service]
Type=simple
NoNewPrivileges=yes
TimeoutStartSec=0
ExecStart=/root/lun/sing-box run -c /root/lun/sb.json
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >/dev/null 2>&1
systemctl enable sb >/dev/null 2>&1
systemctl start sb >/dev/null 2>&1
elif command -v rc-service >/dev/null 2>&1 && [ "$(id -u 2>/dev/null)" = "0" ]; then
cat > /etc/init.d/sing-box <<EOF
#!/sbin/openrc-run
description="sb service"
command="/root/lun/sing-box"
command_args="run -c /root/lun/sb.json"
command_background=yes
pidfile="/run/sing-box.pid"
command_background="yes"
depend() {
need net
}
EOF
chmod +x /etc/init.d/sing-box >/dev/null 2>&1
rc-update add sing-box default >/dev/null 2>&1
rc-service sing-box start >/dev/null 2>&1
else
nohup "$HOME/lun/sing-box" run -c "$HOME/lun/sb.json" >/dev/null 2>&1 &
fi
fi
}
ins(){
if [ "$hyp" != yes ] && [ "$tup" != yes ] && [ "$anp" != yes ] && [ "$arp" != yes ] && [ "$ssp" != yes ]; then
installxray
xrsbvm
xrsbso
warpsx
xrsbout
hyp="hyptargo"; tup="tuptargo"; anp="anptargo"; arp="arptargo"; ssp="ssptargo"
elif [ "$xhp" != yes ] && [ "$vlp" != yes ] && [ "$vxp" != yes ] && [ "$vwp" != yes ]; then
installsb
xrsbvm
xrsbso
warpsx
xrsbout
xhp="xhptargo"; vlp="vlptargo"; vxp="vxptargo"; vwp="vwptargo"
else
installsb
installxray
xrsbvm
xrsbso
warpsx
xrsbout
fi
if [ -n "$argo" ] && [ -n "$vmag" ]; then
echo
echo "=========启用Cloudflared-argo内核========="
if [ ! -e "$HOME/lun/cloudflared" ]; then
argocore=$({ command -v curl >/dev/null 2>&1 && curl -Ls https://data.jsdelivr.com/v1/package/gh/cloudflare/cloudflared || wget -qO- https://data.jsdelivr.com/v1/package/gh/cloudflare/cloudflared; } | grep -Eo '"[0-9.]+"' | sed -n 1p | tr -d '",')
echo "下载Cloudflared-argo最新正式版内核：$argocore"
url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$cpu"; out="$HOME/lun/cloudflared"; (command -v curl>/dev/null 2>&1 && curl -Lo "$out" -# --retry 2 "$url") || (command -v wget>/dev/null 2>&1 && timeout 3 wget -O "$out" --tries=2 "$url")
chmod +x "$HOME/lun/cloudflared"
fi
if [ "$argo" = "vmpt" ]; then argoport=$(cat "$HOME/lun/port_vm_ws" 2>/dev/null); echo "Vmess" > "$HOME/lun/vlvm"; elif [ "$argo" = "vwpt" ]; then argoport=$(cat "$HOME/lun/port_vw" 2>/dev/null); echo "Vless" > "$HOME/lun/vlvm"; fi; echo "$argoport" > "$HOME/lun/argoport.log"
if [ -n "${ARGO_DOMAIN}" ] && [ -n "${ARGO_AUTH}" ]; then
argoname='固定'
if pidof systemd >/dev/null 2>&1 && [ "$(id -u 2>/dev/null)" = "0" ]; then
cat > /etc/systemd/system/argo.service <<EOF
[Unit]
Description=argo service
After=network.target
[Service]
Type=simple
NoNewPrivileges=yes
TimeoutStartSec=0
ExecStart=/root/lun/cloudflared tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token "${ARGO_AUTH}"
Restart=on-failure
RestartSec=5s
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >/dev/null 2>&1
systemctl enable argo >/dev/null 2>&1
systemctl start argo >/dev/null 2>&1
elif command -v rc-service >/dev/null 2>&1 && [ "$(id -u 2>/dev/null)" = "0" ]; then
cat > /etc/init.d/argo <<EOF
#!/sbin/openrc-run
description="argo service"
command="/root/lun/cloudflared tunnel"
command_args="--no-autoupdate --edge-ip-version auto --protocol http2 run --token ${ARGO_AUTH}"
pidfile="/run/argo.pid"
command_background="yes"
depend() {
need net
}
EOF
chmod +x /etc/init.d/argo >/dev/null 2>&1
rc-update add argo default >/dev/null 2>&1
rc-service argo start >/dev/null 2>&1
else
nohup "$HOME/lun/cloudflared" tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token "${ARGO_AUTH}" >/dev/null 2>&1 &
fi
echo "${ARGO_DOMAIN}" > "$HOME/lun/sbargoym.log"
echo "${ARGO_AUTH}" > "$HOME/lun/sbargotoken.log"
else
argoname='临时'
nohup "$HOME/lun/cloudflared" tunnel --url http://localhost:$(cat $HOME/lun/argoport.log) --edge-ip-version auto --no-autoupdate --protocol http2 > $HOME/lun/argo.log 2>&1 &
fi
echo "申请Argo$argoname隧道中……请稍等"
sleep 15
if [ -n "${ARGO_DOMAIN}" ] && [ -n "${ARGO_AUTH}" ]; then
argodomain=$(cat "$HOME/lun/sbargoym.log" 2>/dev/null)
else
argodomain=$(grep -a trycloudflare.com "$HOME/lun/argo.log" 2>/dev/null | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
fi
if [ -n "${argodomain}" ]; then
echo "Argo$argoname隧道申请成功"
else
echo "Argo$argoname隧道申请失败，请稍后再试"
fi
fi
sleep 5
echo
if find /proc/*/exe -type l 2>/dev/null | grep -E '/proc/[0-9]+/exe' | xargs -r readlink 2>/dev/null | grep -Eq 'lun/(s|x)' ; then
[ -f ~/.bashrc ] || touch ~/.bashrc
sed -i '/lun/d' ~/.bashrc
if [ "$(id -u 2>/dev/null)" = "0" ]; then
SCRIPT_PATH="/usr/bin/lun"
else
SCRIPT_PATH="$HOME/bin/lun"
mkdir -p "$HOME/bin"
fi
install_lun_entry "$SCRIPT_PATH" || { echo "Lun脚本安装失败，请检查网络后重试。"; exit 1; }
if ! pidof systemd >/dev/null 2>&1 && ! command -v rc-service >/dev/null 2>&1; then
echo "if ! find /proc/*/exe -type l 2>/dev/null | grep -E '/proc/[0-9]+/exe' | xargs -r readlink 2>/dev/null | grep -Eq 'lun/(s|x)' && ! pgrep -f 'lun/(s|x)' >/dev/null 2>&1; then echo '检测到系统可能中断过，或者变量格式错误？建议在SSH对话框输入 reboot 重启下服务器。现在自动执行Lun脚本的节点恢复操作，请稍等……'; sleep 6; export cfip=\"${cfip}\" hyjpt=\"${hyjpt}\" cdnym=\"${cdnym}\" addym=\"${addym}\" addout=\"${addout}\" ptmap=\"${ptmap}\" portpool=\"${portpool}\" inpool=\"${inpool}\" outpool=\"${outpool}\" vpsmode=\"${vpsmode}\" argoip=\"${argoip}\" subipmode=\"${subipmode}\" domain=\"${domain}\" certmode=\"${certmode}\" acme_email=\"${acme_email}\" acme_dns=\"${acme_dns}\" name=\"${name}\" ippz=\"${ippz}\" argo=\"${argo}\" uuid=\"${uuid}\" $wap=\"${warp}\" $xhp=\"${port_xh}\" $vxp=\"${port_vx}\" $ssp=\"${port_ss}\" $sop=\"${port_so}\" $anp=\"${port_an}\" $arp=\"${port_ar}\" $vlp=\"${port_vl_re}\" $vwp=\"${port_vw}\" $vmp=\"${port_vm_ws}\" $hyp=\"${port_hy2}\" $tup=\"${port_tu}\" reym=\"${ym_vl_re}\" agn=\"${ARGO_DOMAIN}\" agk=\"${ARGO_AUTH}\"; bash \"${SCRIPT_PATH}\"; fi" >> ~/.bashrc
fi
sed -i '/export PATH="\$HOME\/bin:\$PATH"/d' ~/.bashrc
if [ "$SCRIPT_PATH" = "$HOME/bin/lun" ]; then
echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
fi
grep -qxF 'source ~/.bashrc' ~/.bash_profile 2>/dev/null || echo 'source ~/.bashrc' >> ~/.bash_profile
. ~/.bashrc 2>/dev/null
crontab -l > /tmp/crontab.tmp 2>/dev/null
if ! pidof systemd >/dev/null 2>&1 && ! command -v rc-service >/dev/null 2>&1; then
sed -i '/lun\/sing-box/d' /tmp/crontab.tmp
sed -i '/lun\/xray/d' /tmp/crontab.tmp
if find /proc/*/exe -type l 2>/dev/null | grep -E '/proc/[0-9]+/exe' | xargs -r readlink 2>/dev/null | grep -q 'lun/s' ; then
echo '@reboot sleep 10 && /bin/sh -c "nohup $HOME/lun/sing-box run -c $HOME/lun/sb.json >/dev/null 2>&1 &"' >> /tmp/crontab.tmp
fi
if find /proc/*/exe -type l 2>/dev/null | grep -E '/proc/[0-9]+/exe' | xargs -r readlink 2>/dev/null | grep -q 'lun/x' ; then
echo '@reboot sleep 10 && /bin/sh -c "nohup $HOME/lun/xray run -c $HOME/lun/xr.json >/dev/null 2>&1 &"' >> /tmp/crontab.tmp
fi
fi
sed -i '/lun\/cloudflared/d' /tmp/crontab.tmp
if [ -n "$argo" ] && [ -n "$vmag" ]; then
if [ -n "${ARGO_DOMAIN}" ] && [ -n "${ARGO_AUTH}" ]; then
if ! pidof systemd >/dev/null 2>&1 && ! command -v rc-service >/dev/null 2>&1; then
echo '@reboot sleep 10 && /bin/sh -c "nohup $HOME/lun/cloudflared tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token $(cat $HOME/lun/sbargotoken.log 2>/dev/null) >/dev/null 2>&1 &"' >> /tmp/crontab.tmp
fi
else
if command -v apk >/dev/null 2>&1; then
cat > /etc/local.d/alpinelun.start <<EOF
#!/bin/bash
sleep 10
nohup $HOME/lun/cloudflared tunnel --url http://localhost:\$(cat $HOME/lun/argoport.log) --edge-ip-version auto --no-autoupdate --protocol http2 > $HOME/lun/argo.log 2>&1 &
sleep 10
HOME="$HOME" $HOME/bin/lun list >/dev/null 2>&1
EOF
chmod +x /etc/local.d/alpinelun.start
rc-update add local default >/dev/null 2>&1
else
echo '@reboot sleep 10 && /bin/bash -c "nohup $HOME/lun/cloudflared tunnel --url http://localhost:$(cat $HOME/lun/argoport.log) --edge-ip-version auto --no-autoupdate --protocol http2 > $HOME/lun/argo.log 2>&1 & sleep 10 && bash $HOME/bin/lun list >/dev/null 2>&1"' >> /tmp/crontab.tmp
fi
fi
fi
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
echo "Lun脚本进程启动成功，安装完毕" && sleep 2
else
echo "Lun脚本进程未启动，安装失败" && exit
fi
# ============ CDN 优选 IP/域名写入 ============
# cfip 变量：用户传入的 CDN 优选地址（1-2个，空格分隔）
# 如果用户传了 cfip，拆分为 cdnip1/cdnip2 写入配置文件
# 如果没传，检查已有配置；都没有则使用默认优选域名
# 注意：默认用域名而非纯IP，稳定性和兼容性更好（参考 sing-box-yg）
if [ -n "$cfip" ]; then
set -- $cfip
cdnip1="$1"
cdnip2="$2"
[ -n "$cdnip1" ] && echo "$cdnip1" > "$HOME/lun/cdnip1" || rm -f "$HOME/lun/cdnip1"
[ -n "$cdnip2" ] && echo "$cdnip2" > "$HOME/lun/cdnip2" || rm -f "$HOME/lun/cdnip2"
else
if [ -s "$HOME/lun/cdnip1" ]; then
cdnip1=$(cat "$HOME/lun/cdnip1")
cdnip2=$(cat "$HOME/lun/cdnip2" 2>/dev/null)
else
# 默认 CDN 优选域名：cloudflare-ech.com 是 Cloudflare 官方 CDN 域名，稳定可靠
# 备选：www.visa.com.sg、www.wto.org、www.web.com 等大厂域名
cdnip1="cloudflare-ech.com"
cdnip2="www.visa.com.sg"
echo "$cdnip1" > "$HOME/lun/cdnip1"
echo "$cdnip2" > "$HOME/lun/cdnip2"
fi
fi
}
lunstatus(){
echo "=========当前内核运行状态========="
procs=$(find /proc/*/exe -type l 2>/dev/null | grep -E '/proc/[0-9]+/exe' | xargs -r readlink 2>/dev/null)
if echo "$procs" | grep -Eq 'lun/s'; then
echo "Sing-box (版本V$("$HOME/lun/sing-box" version 2>/dev/null | awk '/version/{print $NF}'))：运行中"
else
echo "Sing-box：未启用"
fi
if echo "$procs" | grep -Eq 'lun/x'; then
echo "Xray (版本V$("$HOME/lun/xray" version 2>/dev/null | awk '/^Xray/{print $2}'))：运行中"
else
echo "Xray：未启用"
fi
}

argo_status_line(){
procs=$(find /proc/*/exe -type l 2>/dev/null | grep -E '/proc/[0-9]+/exe' | xargs -r readlink 2>/dev/null)
if echo "$procs" | grep -Eq 'lun/c'; then
echo "Argo (版本V$("$HOME/lun/cloudflared" version 2>/dev/null | awk '{print $3}'))：运行中"
else
echo "Argo：未启用"
fi
}

stop_subscription_service(){
for P in /proc/[0-9]*; do
[ -r "$P/cmdline" ] || continue
PID=$(basename "$P")
CMD=$(tr '\0' ' ' < "$P/cmdline" 2>/dev/null)
case "$CMD" in
*httpd*"-h $HOME/weblun"*|*httpd*"-h $HOME/websbx"*)
kill "$PID" 2>/dev/null
;;
esac
done
}

restart_subscription_service(){
[ -s "$HOME/lun/subport.log" ] || [ -n "$sub" ] || return 0
if [ -n "$subid" ]; then
subtoken="$subid"
elif [ -s "$HOME/lun/subtoken.log" ]; then
subtoken=$(cat "$HOME/lun/subtoken.log" 2>/dev/null)
elif [ -s "$HOME/lun/uuid" ]; then
subtoken=$(cat "$HOME/lun/uuid" 2>/dev/null)
else
echo "订阅服务缺少 token/UUID，已跳过。"
return 1
fi
if [ -n "$subpt" ]; then
subport="$subpt"
elif [ -s "$HOME/lun/subport.log" ]; then
subport=$(cat "$HOME/lun/subport.log" 2>/dev/null)
else
subport=$(random_port) || { echo "订阅服务无法取得可用端口，已跳过。"; return 1; }
fi
mapped_inner=$(inner_port_from_public "$subport")
[ -n "$mapped_inner" ] && subport="$mapped_inner"
port_valid "$subport" || { echo "订阅端口 $subport 无效，已跳过。"; return 1; }
stop_subscription_service
sleep 1
if port_in_use "$subport"; then
echo "订阅端口 $subport 仍被占用，订阅服务未启动："
port_owner_lines "$subport" | sed 's/^/  /'
return 1
fi
rm -rf "$HOME/weblun/$subtoken"
mkdir -p "$HOME/weblun/$subtoken"
printf "%s\n" "$subtoken" > "$HOME/lun/subtoken.log"
printf "%s\n" "$subport" > "$HOME/lun/subport.log"
ln -sf "$HOME/lun/clmi.yaml" "$HOME/weblun/$subtoken/clmi.yaml"
ln -sf "$HOME/lun/sbox.json" "$HOME/weblun/$subtoken/sbox.json"
ln -sf "$HOME/lun/jhsub.txt" "$HOME/weblun/$subtoken/jhsub.txt"
if command -v apk >/dev/null 2>&1; then
busybox-extras httpd -f -p "$subport" -h "$HOME/weblun" > /dev/null 2>&1 &
else
busybox httpd -f -p "$subport" -h "$HOME/weblun" > /dev/null 2>&1 &
fi
if command -v apk >/dev/null 2>&1; then
cat > /etc/local.d/alpinesublun.start <<EOF
#!/bin/bash
sleep 10
busybox-extras httpd -f -p \$(cat $HOME/lun/subport.log 2>/dev/null) -h $HOME/weblun > /dev/null 2>&1 &
EOF
chmod +x /etc/local.d/alpinesublun.start
rc-update add local default >/dev/null 2>&1
else
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/weblun/d' /tmp/crontab.tmp
echo '@reboot sleep 10 && /bin/bash -c "busybox httpd -f -p $(cat $HOME/lun/subport.log 2>/dev/null) -h $HOME/weblun > /dev/null 2>&1 &"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
fi
echo "本地订阅服务已刷新。"
show_port_mapping_hint "$subport"
}

cip(){
ipbest(){
serip=$( (command -v curl >/dev/null 2>&1 && (curl -s4m5 -k "$v46url" 2>/dev/null || curl -s6m5 -k "$v46url" 2>/dev/null) ) || (command -v wget >/dev/null 2>&1 && (timeout 3 wget -4 -qO- --tries=2 "$v46url" 2>/dev/null || timeout 3 wget -6 -qO- --tries=2 "$v46url" 2>/dev/null) ) )
if echo "$serip" | grep -q ':'; then
server_ip="[$serip]"
echo "$server_ip" > "$HOME/lun/server_ip.log"
else
server_ip="$serip"
echo "$server_ip" > "$HOME/lun/server_ip.log"
fi
}
ipchange(){
v4v6
if [ -z "$v4" ]; then
vps_ipv4='无IPV4'
vps_ipv6="$v6"
location="$v6dq"
elif [ -n "$v4" ] && [ -n "$v6" ]; then
vps_ipv4="$v4"
vps_ipv6="$v6"
location="$v4dq"
else
vps_ipv4="$v4"
vps_ipv6='无IPV6'
location="$v4dq"
fi
if echo "$v6" | grep -q '^2a09'; then
w6="【WARP】"
fi
if echo "$v4" | grep -q '^104.28'; then
w4="【WARP】"
fi
echo
lunstatus
echo
echo "=========当前服务器本地IP情况========="
echo "本地IPV4地址：$vps_ipv4 $w4"
echo "本地IPV6地址：$vps_ipv6 $w6"
echo "服务器地区：$location"
echo
sleep 2
if [ "$ippz" = "4" ]; then
if [ -z "$v4" ]; then
ipbest
else
server_ip="$v4"
echo "$server_ip" > "$HOME/lun/server_ip.log"
fi
elif [ "$ippz" = "6" ]; then
if [ -z "$v6" ]; then
ipbest
else
server_ip="[$v6]"
echo "$server_ip" > "$HOME/lun/server_ip.log"
fi
else
ipbest
fi
}
ipchange
rm -rf "$HOME/lun/jhsub.txt"
uuid=$(cat "$HOME/lun/uuid")
server_ip=$(cat "$HOME/lun/server_ip.log")
sxname=$(cat "$HOME/lun/name" 2>/dev/null)
xvvmcdnym=$(cat "$HOME/lun/cdnym" 2>/dev/null)
cdnip1=$(cat "$HOME/lun/cdnip1" 2>/dev/null)
cdnip2=$(cat "$HOME/lun/cdnip2" 2>/dev/null)
# 如果 cdnip1/cdnip2 都为空，使用默认 CDN 优选域名（非纯IP，更稳定）
if [ -z "$cdnip1" ] && [ -z "$cdnip2" ]; then
cdnip1="cloudflare-ech.com"
cdnip2="www.visa.com.sg"
fi
argoip_cfg=$(cat "$HOME/lun/argoip" 2>/dev/null)
[ -z "$argoip_cfg" ] && argoip_cfg="162.159.192.1 162.159.192.2"
set -- $argoip_cfg
argoip1=${1:-162.159.192.1}
argoip2=${2:-$argoip1}
client_addr="$server_ip"
node_name_suffix=
if [ -n "$addym" ] && [ "$addout" = "replace" ]; then
client_addr="$addym"
elif [ -n "$addym" ] && [ "$addout" = "both" ]; then
node_name_suffix="-IP"
fi
if [ -s "$HOME/lun/cdnym" ]; then
client_addr="$server_ip"
node_name_suffix="-SERVERIP"
addout=off
fi
cert_client_vars

sed_escape(){
printf '%s' "$1" | sed 's/[.[\*^$()+?{}|\\]/\\&/g; s#/#\\/#g'
}

sed_replacement_escape(){
printf '%s' "$1" | sed 's/[&\\]/\\&/g'
}

replace_link_addr(){
link=$1
new_addr=$2
old_esc=$(sed_escape "$server_ip")
new_esc=$(sed_replacement_escape "$new_addr")
case "$link" in
vmess://*)
payload=${link#vmess://}
json=$(printf '%s' "$payload" | base64 -d 2>/dev/null)
[ -z "$json" ] && printf '%s\n' "$link" && return
json=$(printf '%s' "$json" | sed "s/\"add\": \"$old_esc\"/\"add\": \"$new_esc\"/g; s/-IP\"/-DOMAIN\"/g")
printf 'vmess://%s\n' "$(printf '%s' "$json" | base64 -w0)"
;;
ss://*)
body=${link#ss://}
encoded=${body%%#*}
label=${body#*#}
raw=$(printf '%s' "$encoded" | base64 -d 2>/dev/null)
[ -z "$raw" ] && printf '%s\n' "$link" && return
raw=$(printf '%s' "$raw" | sed "s/@$old_esc:/@$new_esc:/g")
label=$(printf '%s' "$label" | sed 's/-IP$/-DOMAIN/')
printf 'ss://%s#%s\n' "$(printf '%s' "$raw" | base64 -w0)" "$label"
;;
*)
printf '%s\n' "$link" | sed "s/@$old_esc:/@$new_esc:/g; s/-IP$/-DOMAIN/"
;;
esac
}

append_share_link(){
link=$1
printf '%s\n' "$link" >> "$HOME/lun/jhsub.txt"
printf '%s\n' "$link"
if [ -n "$addym" ] && [ "$addout" = "both" ]; then
domain_link=$(replace_link_addr "$link" "$addym")
printf '%s\n' "$domain_link" >> "$HOME/lun/jhsub.txt"
printf '%s\n' "$domain_link"
fi
}

echo "*********************************************************"
echo "*********************************************************"
echo "Lun脚本输出节点配置如下："
echo
case "$server_ip" in
104.28*|\[2a09*) echo "检测到有WARP的IP作为客户端地址 (104.28或者2a09开头的IP)，请把客户端地址上的WARP的IP手动更换为VPS本地IPV4或者IPV6地址" && sleep 3 ;;
esac
echo
ym_vl_re=$(cat "$HOME/lun/ym_vl_re" 2>/dev/null)
cfipsj() { echo $((RANDOM % 13 + 1)); }
if [ -e "$HOME/lun/xray" ]; then
private_key_x=$(cat "$HOME/lun/xrk/private_key" 2>/dev/null)
public_key_x=$(cat "$HOME/lun/xrk/public_key" 2>/dev/null)
short_id_x=$(cat "$HOME/lun/xrk/short_id" 2>/dev/null)
enkey=$(cat "$HOME/lun/xrk/enkey" 2>/dev/null)
fi
if [ -e "$HOME/lun/sing-box" ]; then
private_key_s=$(cat "$HOME/lun/sbk/private_key" 2>/dev/null)
public_key_s=$(cat "$HOME/lun/sbk/public_key" 2>/dev/null)
short_id_s=$(cat "$HOME/lun/sbk/short_id" 2>/dev/null)
sskey=$(cat "$HOME/lun/sskey" 2>/dev/null)
fi
if grep xhttp-reality "$HOME/lun/xr.json" >/dev/null 2>&1; then
echo "💣【 Vless-xhttp-reality-enc 】支持ENC加密，节点信息如下："
port_xh=$(cat "$HOME/lun/port_xh")
client_port_xh=$(client_port "$port_xh")
vl_xh_link="vless://$uuid@$client_addr:$client_port_xh?encryption=$enkey&flow=xtls-rprx-vision&security=reality&sni=$ym_vl_re&fp=chrome&pbk=$public_key_x&sid=$short_id_x&type=xhttp&path=$uuid-xh&mode=auto#${sxname}vl-xhttp-reality-enc-$hostname$node_name_suffix"
append_share_link "$vl_xh_link"
[ -f "$HOME/lun/cdnym" ] && cdn_skip "VLESS XHTTP Reality 不套用普通橙云 CDN，Reality SNI/回源逻辑保持独立，已保留直连节点。"
echo
fi
if grep vless-xhttp "$HOME/lun/xr.json" >/dev/null 2>&1; then
echo "💣【 Vless-xhttp-enc 】支持ENC加密，节点信息如下："
port_vx=$(cat "$HOME/lun/port_vx")
client_port_vx=$(client_port "$port_vx")
vl_vx_link="vless://$uuid@$client_addr:$client_port_vx?encryption=$enkey&flow=xtls-rprx-vision&type=xhttp&path=$uuid-vx&mode=auto#${sxname}vl-xhttp-enc-$hostname$node_name_suffix"
append_share_link "$vl_vx_link"
echo
if [ -f "$HOME/lun/cdnym" ]; then
append_vless_cdn_links "Vless-xhttp-enc-cdn" "vl-xhttp-enc" "$port_vx" "encryption=$enkey&flow=xtls-rprx-vision&type=xhttp&path=$uuid-vx&mode=auto"
fi
fi
if grep vless-ws "$HOME/lun/xr.json" >/dev/null 2>&1; then
echo "💣【 Vless-ws-enc 】支持ENC加密，节点信息如下："
port_vw=$(cat "$HOME/lun/port_vw")
client_port_vw=$(client_port "$port_vw")
vl_vw_link="vless://$uuid@$client_addr:$client_port_vw?encryption=$enkey&flow=xtls-rprx-vision&type=ws&path=$uuid-vw#${sxname}vl-ws-enc-$hostname$node_name_suffix"
append_share_link "$vl_vw_link"
echo
if [ -f "$HOME/lun/cdnym" ]; then
append_vless_cdn_links "Vless-ws-enc-cdn" "vl-ws-enc" "$port_vw" "encryption=$enkey&flow=xtls-rprx-vision&type=ws&path=$uuid-vw"
fi
fi
if grep reality-vision "$HOME/lun/xr.json" >/dev/null 2>&1; then
echo "💣【 Vless-tcp-reality-vision 】节点信息如下："
port_vl_re=$(cat "$HOME/lun/port_vl_re")
client_port_vl_re=$(client_port "$port_vl_re")
vl_link="vless://$uuid@$client_addr:$client_port_vl_re?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$ym_vl_re&fp=chrome&pbk=$public_key_x&sid=$short_id_x&type=tcp&headerType=none#${sxname}vl-reality-vision-$hostname$node_name_suffix"
append_share_link "$vl_link"
[ -f "$HOME/lun/cdnym" ] && cdn_skip "VLESS TCP Reality 不是 HTTP/WS 回源协议，不生成普通橙云 CDN 变体。"
echo
sbvlpt(){
cat <<EOF
    {
      "type": "vless",
      "tag": "${sxname}vless-$hostname$node_name_suffix",
      "server": "$client_addr",
      "server_port": $client_port_vl_re,
      "uuid": "$uuid",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "$ym_vl_re",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
      "reality": {
          "enabled": true,
          "public_key": "$public_key_x",
          "short_id": "$short_id_x"
        }
      }
    },
EOF
}
sbvlpt1(){
echo "\"${sxname}vless-$hostname$node_name_suffix\","
}
clvlpt(){
cat <<EOF
- name: ${sxname}vless-reality-vision-$hostname$node_name_suffix
  type: vless
  server: $client_addr
  port: $client_port_vl_re
  uuid: $uuid
  network: tcp
  udp: true
  tls: true
  flow: xtls-rprx-vision
  servername: $ym_vl_re
  reality-opts:
    public-key: $public_key_x
    short-id: $short_id_x
  client-fingerprint: chrome
EOF
}
clvlpt1(){
echo "- ${sxname}vless-reality-vision-$hostname$node_name_suffix"
}
fi
if grep ss-2022 "$HOME/lun/sb.json" >/dev/null 2>&1; then
echo "💣【 Shadowsocks-2022 】节点信息如下："
port_ss=$(cat "$HOME/lun/port_ss")
client_port_ss=$(client_port "$port_ss")
ss_link="ss://$(echo -n "2022-blake3-aes-128-gcm:$sskey@$client_addr:$client_port_ss" | base64 -w0)#${sxname}Shadowsocks-2022-$hostname$node_name_suffix"
append_share_link "$ss_link"
[ -f "$HOME/lun/cdnym" ] && cdn_skip "Shadowsocks-2022 不是 HTTP/WS 回源协议，不生成普通橙云 CDN 变体。"
echo
sbsspt(){
cat <<EOF
{
       "type": "shadowsocks",
       "tag": "${sxname}Shadowsocks-2022-$hostname$node_name_suffix",
       "server": "$client_addr",
       "server_port": $client_port_ss,
       "method": "2022-blake3-aes-128-gcm",
       "password": "$sskey",
       "udp_over_tcp": {
        "enabled": true,
        "version": 2
      }
     },
EOF
}
sbsspt1(){
echo "\"${sxname}Shadowsocks-2022-$hostname$node_name_suffix\","
}
clsspt(){
cat <<EOF
- name: "${sxname}Shadowsocks-2022-$hostname$node_name_suffix"
  type: ss
  server: $client_addr
  port: $client_port_ss
  cipher: 2022-blake3-aes-128-gcm
  password: "$sskey"
  udp: true
  udp-over-tcp: true
  udp-over-tcp-version: 2
EOF
}
clsspt1(){
echo "- ${sxname}Shadowsocks-2022-$hostname$node_name_suffix"
}
fi
if grep vmess-xr "$HOME/lun/xr.json" >/dev/null 2>&1 || grep vmess-sb "$HOME/lun/sb.json" >/dev/null 2>&1; then
echo "💣【 Vmess-ws 】节点信息如下："
port_vm_ws=$(cat "$HOME/lun/port_vm_ws")
client_port_vm_ws=$(client_port "$port_vm_ws")
vm_link="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"${sxname}vm-ws-$hostname$node_name_suffix\", \"add\": \"$client_addr\", \"port\": \"$client_port_vm_ws\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"www.bing.com\", \"path\": \"/$uuid-vm\", \"tls\": \"\"}" | base64 -w0)"
append_share_link "$vm_link"
echo
sbvmpt(){
cat <<EOF
{
            "server": "$client_addr",
            "server_port": $client_port_vm_ws,
            "tag": "${sxname}vmess-$hostname$node_name_suffix",
            "tls": {
                "enabled": false,
                "server_name": "www.bing.com",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "www.bing.com"
                    ]
                },
                "path": "$uuid-vm",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
EOF
}
sbvmpt1(){
echo "\"${sxname}vmess-$hostname$node_name_suffix\","
}
clvmpt(){
cat <<EOF
- name: ${sxname}vmess-ws-$hostname$node_name_suffix
  type: vmess
  server: $client_addr
  port: $client_port_vm_ws
  uuid: $uuid
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: www.bing.com
  ws-opts:
    path: "$uuid-vm"
    headers:
      Host: www.bing.com
EOF
}
clvmpt1(){
echo "- ${sxname}vmess-ws-$hostname$node_name_suffix"
}
if [ -f "$HOME/lun/cdnym" ]; then
append_vmess_cdn_links "$port_vm_ws"
fi
fi
if grep anytls-sb "$HOME/lun/sb.json" >/dev/null 2>&1; then
echo "💣【 AnyTLS 】节点信息如下："
port_an=$(cat "$HOME/lun/port_an")
client_port_an=$(client_port "$port_an")
an_link="anytls://$uuid@$client_addr:$client_port_an?sni=$cert_sni&insecure=$generic_link_insecure&allowInsecure=$generic_link_insecure#${sxname}anytls-$hostname$node_name_suffix"
append_share_link "$an_link"
[ -f "$HOME/lun/cdnym" ] && cdn_skip "AnyTLS 不是普通 HTTP/WS 回源协议，不生成普通橙云 CDN 变体。"
echo
sbanpt(){
cat <<EOF
         {
            "type": "anytls",
            "tag": "${sxname}anytls-$hostname$node_name_suffix",
            "server": "$client_addr",
            "server_port": $client_port_an,
            "password": "$uuid",
            "idle_session_check_interval": "30s",
            "idle_session_timeout": "30s",
            "min_idle_session": 5,
            "tls": {
                "enabled": true,
                "insecure": $sbox_tls_insecure,
                "server_name": "$cert_sni"
            }
         },
EOF
}
sbanpt1(){
echo "\"${sxname}anytls-$hostname$node_name_suffix\","
}
clanpt(){
cat <<EOF
- name: ${sxname}anytls-$hostname$node_name_suffix
  type: anytls
  server: $client_addr
  port: $client_port_an
  password: $uuid
  client-fingerprint: chrome
  udp: true
  idle-session-check-interval: 30
  idle-session-timeout: 30
  sni: $cert_sni
  skip-cert-verify: $clash_skip_verify
EOF
}
clanpt1(){
echo "- ${sxname}anytls-$hostname$node_name_suffix"
}
fi
if grep anyreality-sb "$HOME/lun/sb.json" >/dev/null 2>&1; then
echo "💣【 Any-Reality 】节点信息如下："
port_ar=$(cat "$HOME/lun/port_ar")
client_port_ar=$(client_port "$port_ar")
ar_link="anytls://$uuid@$client_addr:$client_port_ar?security=reality&sni=$ym_vl_re&fp=chrome&pbk=$public_key_s&sid=$short_id_s&type=tcp&headerType=none#${sxname}any-reality-$hostname$node_name_suffix"
append_share_link "$ar_link"
[ -f "$HOME/lun/cdnym" ] && cdn_skip "Any-Reality 不套用普通橙云 CDN，Reality SNI/回源逻辑保持独立。"
echo
sbarpt(){
cat <<EOF
    {
        "type": "anytls",
        "tag": "${sxname}any-reality-$hostname$node_name_suffix",
        "server": "$client_addr",
        "server_port": $client_port_ar,
        "password": "$uuid",
        "idle_session_check_interval": "30s",
        "idle_session_timeout": "30s",
        "min_idle_session": 5,
        "tls": {
        "enabled": true,
        "server_name": "$ym_vl_re",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
      "reality": {
          "enabled": true,
          "public_key": "$public_key_s",
          "short_id": "$short_id_s"
        }
      }
         },
EOF
}
sbarpt1(){
echo "\"${sxname}any-reality-$hostname$node_name_suffix\","
}
fi
if grep hy2-sb "$HOME/lun/sb.json" >/dev/null 2>&1; then
echo "💣【 Hysteria2 】节点信息如下："
SHA256=$(cat "$HOME/lun/SHA256.txt" 2>/dev/null)
port_hy2=$(cat "$HOME/lun/port_hy2")
client_port_hy2=$(client_port "$port_hy2")
hy2_ports=$(iptables -t nat -nL --line 2>/dev/null | grep -w "$port_hy2" | awk '{print $8}' | sed 's/dpts://; s/dpt://' | tr '\n' ',' | sed 's/,$//')
if [ -n "$hy2_ports" ] || [ -n "$hyjpt" ]; then
echo "Hysteria2跳跃端口已开启：$hy2_ports"
cmhy2pt=$(echo $hy2_ports | tr ':' '-')
hyps="&mport=$cmhy2pt"
sbhy2pt=$(echo "$hy2_ports" | grep -o '[0-9]\+:[0-9]\+' | sed 's/.*/"&"/' | paste -sd,)
sbhy2ports(){
    cat <<EOF
  "server_ports": [ $sbhy2pt ],
EOF
}
else
hyps=
fi
hy2_link="hysteria2://$uuid@$client_addr:$client_port_hy2?security=tls&alpn=h3&insecure=$hy2_link_insecure&allowInsecure=$hy2_link_insecure$hyps&sni=$cert_sni$hy2_pin_arg#${sxname}hy2-$hostname$node_name_suffix"
append_share_link "$hy2_link"
[ -f "$HOME/lun/cdnym" ] && cdn_skip "Hysteria2 使用 UDP/QUIC 语义，不走 Cloudflare 普通橙云 CDN。"
echo
sbhypt(){
cat <<EOF
    {
        "type": "hysteria2",
        "tag": "${sxname}hy2-$hostname$node_name_suffix",
        "server": "$client_addr",
        "server_port": $client_port_hy2,
$(sbhy2ports 2>/dev/null)
        "password": "$uuid",
        "tls": {
            "enabled": true,
            "server_name": "$cert_sni",
            "insecure": $sbox_tls_insecure,
            "alpn": [
                "h3"
            ]
        }
    },
EOF
}
sbhypt1(){
echo "\"${sxname}hy2-$hostname$node_name_suffix\","
}
clhypt(){
cat <<EOF
- name: ${sxname}hysteria2-$hostname$node_name_suffix
  type: hysteria2
  server: $client_addr
  port: $client_port_hy2
  ports: $cmhy2pt
  password: $uuid
  alpn:
    - h3
  sni: $cert_sni
  skip-cert-verify: $clash_skip_verify
  fast-open: true
EOF
}
clhypt1(){
echo "- ${sxname}hysteria2-$hostname$node_name_suffix"
}
fi
if grep tuic5-sb "$HOME/lun/sb.json" >/dev/null 2>&1; then
echo "💣【 Tuic 】节点信息如下："
port_tu=$(cat "$HOME/lun/port_tu")
client_port_tu=$(client_port "$port_tu")
tuic5_link="tuic://$uuid:$uuid@$client_addr:$client_port_tu?congestion_control=bbr&udp_relay_mode=native&alpn=h3&sni=$cert_sni&insecure=$generic_link_insecure&allowInsecure=$generic_link_insecure&allow_insecure=$generic_link_insecure#${sxname}tuic-$hostname$node_name_suffix"
append_share_link "$tuic5_link"
[ -f "$HOME/lun/cdnym" ] && cdn_skip "TUIC 使用 UDP/QUIC 语义，不走 Cloudflare 普通橙云 CDN。"
echo
sbtupt(){
cat <<EOF
        {
            "type":"tuic",
            "tag": "${sxname}tuic5-$hostname$node_name_suffix",
            "server": "$client_addr",
            "server_port": $client_port_tu,
            "uuid": "$uuid",
            "password": "$uuid",
            "congestion_control": "bbr",
            "udp_relay_mode": "native",
            "udp_over_stream": false,
            "zero_rtt_handshake": false,
            "heartbeat": "10s",
            "tls":{
                "enabled": true,
                "server_name": "$cert_sni",
                "insecure": $sbox_tls_insecure,
                "alpn": [
                    "h3"
                ]
            }
        },
EOF
}
sbtupt1(){
echo "\"${sxname}tuic5-$hostname$node_name_suffix\","
}
cltupt(){
cat <<EOF
- name: ${sxname}tuic5-$hostname$node_name_suffix
  server: $client_addr
  port: $client_port_tu
  type: tuic
  uuid: $uuid
  password: $uuid
  alpn: [h3]
  disable-sni: $clash_disable_sni
  reduce-rtt: true
  udp-relay-mode: native
  congestion-controller: bbr
  sni: $cert_sni
  skip-cert-verify: $clash_skip_verify
EOF
}
cltupt1(){
echo "- ${sxname}tuic5-$hostname$node_name_suffix"
}
fi
if grep socks5-xr "$HOME/lun/xr.json" >/dev/null 2>&1 || grep socks5-sb "$HOME/lun/sb.json" >/dev/null 2>&1; then
echo "💣【 Socks5 】客户端信息如下："
port_so=$(cat "$HOME/lun/port_so")
client_port_so=$(client_port "$port_so")
echo "请配合其他应用内置代理使用，勿做节点直接使用"
echo "客户端地址：$client_addr"
[ -n "$addym" ] && [ "$addout" = "both" ] && echo "客户端地址-DOMAIN：$addym"
echo "客户端端口：$client_port_so"
echo "客户端用户名：$uuid"
echo "客户端密码：$uuid"
[ -f "$HOME/lun/cdnym" ] && cdn_skip "Socks5 不是 HTTP/WS 回源协议，不生成普通橙云 CDN 变体。"
echo
fi
argodomain=$(cat "$HOME/lun/sbargoym.log" 2>/dev/null)
[ -z "$argodomain" ] && argodomain=$(grep -a trycloudflare.com "$HOME/lun/argo.log" 2>/dev/null | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
if [ -n "$argodomain" ]; then
vlvm=$(cat $HOME/lun/vlvm 2>/dev/null)
if [ "$vlvm" = "Vmess" ]; then
vmatls_link1="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"${sxname}vmess-ws-tls-argo-$hostname-443\", \"add\": \"$argoip1\", \"port\": \"443\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$uuid-vm\", \"tls\": \"tls\", \"sni\": \"$argodomain\", \"alpn\": \"\", \"fp\": \"chrome\"}" | base64 -w0)"
echo "$vmatls_link1" >> "$HOME/lun/jhsub.txt"
vmatls_link2="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"${sxname}vmess-ws-tls-argo-$hostname-8443\", \"add\": \"162.159.192.1\", \"port\": \"8443\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$uuid-vm\", \"tls\": \"tls\", \"sni\": \"$argodomain\", \"alpn\": \"\", \"fp\": \"chrome\"}" | base64 -w0)"
echo "$vmatls_link2" >> "$HOME/lun/jhsub.txt"
vmatls_link3="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"${sxname}vmess-ws-tls-argo-$hostname-2053\", \"add\": \"162.159.192.1\", \"port\": \"2053\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$uuid-vm\", \"tls\": \"tls\", \"sni\": \"$argodomain\", \"alpn\": \"\", \"fp\": \"chrome\"}" | base64 -w0)"
echo "$vmatls_link3" >> "$HOME/lun/jhsub.txt"
vmatls_link4="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"${sxname}vmess-ws-tls-argo-$hostname-2083\", \"add\": \"162.159.192.1\", \"port\": \"2083\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$uuid-vm\", \"tls\": \"tls\", \"sni\": \"$argodomain\", \"alpn\": \"\", \"fp\": \"chrome\"}" | base64 -w0)"
echo "$vmatls_link4" >> "$HOME/lun/jhsub.txt"
vmatls_link5="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"${sxname}vmess-ws-tls-argo-$hostname-2087\", \"add\": \"162.159.192.1\", \"port\": \"2087\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$uuid-vm\", \"tls\": \"tls\", \"sni\": \"$argodomain\", \"alpn\": \"\", \"fp\": \"chrome\"}" | base64 -w0)"
echo "$vmatls_link5" >> "$HOME/lun/jhsub.txt"
vmatls_link6="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"${sxname}vmess-ws-tls-argo-$hostname-2096\", \"add\": \"[2606:4700::0]\", \"port\": \"2096\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$uuid-vm\", \"tls\": \"tls\", \"sni\": \"$argodomain\", \"alpn\": \"\", \"fp\": \"chrome\"}" | base64 -w0)"
echo "$vmatls_link6" >> "$HOME/lun/jhsub.txt"
vma_link7="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"${sxname}vmess-ws-argo-$hostname-80\", \"add\": \"$argoip2\", \"port\": \"80\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$uuid-vm\", \"tls\": \"\"}" | base64 -w0)"
echo "$vma_link7" >> "$HOME/lun/jhsub.txt"
vma_link8="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"${sxname}vmess-ws-argo-$hostname-8080\", \"add\": \"162.159.192.2\", \"port\": \"8080\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$uuid-vm\", \"tls\": \"\"}" | base64 -w0)"
echo "$vma_link8" >> "$HOME/lun/jhsub.txt"
vma_link9="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"${sxname}vmess-ws-argo-$hostname-8880\", \"add\": \"162.159.192.2\", \"port\": \"8880\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$uuid-vm\", \"tls\": \"\"}" | base64 -w0)"
echo "$vma_link9" >> "$HOME/lun/jhsub.txt"
vma_link10="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"${sxname}vmess-ws-argo-$hostname-2052\", \"add\": \"162.159.192.2\", \"port\": \"2052\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$uuid-vm\", \"tls\": \"\"}" | base64 -w0)"
echo "$vma_link10" >> "$HOME/lun/jhsub.txt"
vma_link11="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"${sxname}vmess-ws-argo-$hostname-2082\", \"add\": \"162.159.192.2\", \"port\": \"2082\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$uuid-vm\", \"tls\": \"\"}" | base64 -w0)"
echo "$vma_link11" >> "$HOME/lun/jhsub.txt"
vma_link12="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"${sxname}vmess-ws-argo-$hostname-2086\", \"add\": \"162.159.192.2\", \"port\": \"2086\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$uuid-vm\", \"tls\": \"\"}" | base64 -w0)"
echo "$vma_link12" >> "$HOME/lun/jhsub.txt"
vma_link13="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"${sxname}vmess-ws-argo-$hostname-2095\", \"add\": \"[2400:cb00:2049::0]\", \"port\": \"2095\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$uuid-vm\", \"tls\": \"\"}" | base64 -w0)"
echo "$vma_link13" >> "$HOME/lun/jhsub.txt"
sbvmargopt(){
cat <<EOF
{
            "server": "$argoip1",
            "server_port": 443,
            "tag": "${sxname}vmess-ws-tls-argo-$hostname-443",
            "tls": {
                "enabled": true,
                "server_name": "$argodomain",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argodomain"
                    ]
                },
                "path": "$uuid-vm",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$argoip2",
            "server_port": 80,
            "tag": "${sxname}vmess-ws-argo-$hostname-80",
            "tls": {
                "enabled": false,
                "server_name": "$argodomain",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argodomain"
                    ]
                },
                "path": "$uuid-vm",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
EOF
}
sbvmargopt1(){
echo "\"${sxname}vmess-ws-tls-argo-$hostname-443\","
echo "\"${sxname}vmess-ws-argo-$hostname-80\","
}
clvmargopt(){
cat <<EOF
- name: ${sxname}vmess-ws-tls-argo-$hostname-443
  type: vmess
  server: "$argoip1"
  port: 443
  uuid: $uuid
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  network: ws
  servername: $argodomain
  ws-opts:
    path: "$uuid-vm"
    headers:
      Host: $argodomain
- name: ${sxname}vmess-ws-argo-$hostname-80
  type: vmess
  server: "$argoip2"
  port: 80
  uuid: $uuid
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: $argodomain
  ws-opts:
    path: "$uuid-vm"
    headers:
      Host: $argodomain
EOF
}
clvmargopt1(){
echo "- ${sxname}vmess-ws-tls-argo-$hostname-443"
echo "- ${sxname}vmess-ws-argo-$hostname-80"
}
elif [ "$vlvm" = "Vless" ]; then
vwatls_link1="vless://$uuid@$argoip1:443?encryption=$enkey&flow=xtls-rprx-vision&type=ws&host=$argodomain&path=$uuid-vw&security=tls&sni=$argodomain&fp=chrome&insecure=0&allowInsecure=0#${sxname}vless-ws-tls-argo-enc-vision-$hostname"
echo "$vwatls_link1" >> "$HOME/lun/jhsub.txt"
vwa_link2="vless://$uuid@$argoip2:80?encryption=$enkey&flow=xtls-rprx-vision&type=ws&host=$argodomain&path=$uuid-vw&security=none#${sxname}vless-ws-argo-enc-vision-$hostname"
echo "$vwa_link2" >> "$HOME/lun/jhsub.txt"
sbvmargopt(){
cat <<EOF
{
            "server": "$argoip1",
            "server_port": 443,
            "tag": "${sxname}vless-ws-tls-argo-$hostname-443",
            "type": "vless",
            "uuid": "$uuid",
            "flow": "xtls-rprx-vision",
            "tls": {
                "enabled": true,
                "server_name": "$argodomain",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "transport": {
                "headers": {
                    "Host": [
                        "$argodomain"
                    ]
                },
                "path": "$uuid-vw",
                "type": "ws"
            }
        },
{
            "server": "$argoip2",
            "server_port": 80,
            "tag": "${sxname}vless-ws-argo-$hostname-80",
            "type": "vless",
            "uuid": "$uuid",
            "flow": "xtls-rprx-vision",
            "tls": {
                "enabled": false,
                "server_name": "$argodomain",
                "insecure": false
            },
            "transport": {
                "headers": {
                    "Host": [
                        "$argodomain"
                    ]
                },
                "path": "$uuid-vw",
                "type": "ws"
            }
        },
EOF
}
sbvmargopt1(){
echo "\"${sxname}vless-ws-tls-argo-$hostname-443\","
echo "\"${sxname}vless-ws-argo-$hostname-80\","
}
clvmargopt(){
cat <<EOF
- name: ${sxname}vless-ws-tls-argo-$hostname-443
  type: vless
  server: "$argoip1"
  port: 443
  uuid: $uuid
  network: ws
  udp: true
  tls: true
  flow: xtls-rprx-vision
  servername: $argodomain
  client-fingerprint: chrome
  ws-opts:
    path: "$uuid-vw"
    headers:
      Host: $argodomain
- name: ${sxname}vless-ws-argo-$hostname-80
  type: vless
  server: "$argoip2"
  port: 80
  uuid: $uuid
  network: ws
  udp: true
  tls: false
  flow: xtls-rprx-vision
  servername: $argodomain
  ws-opts:
    path: "$uuid-vw"
    headers:
      Host: $argodomain
EOF
}
clvmargopt1(){
echo "- ${sxname}vless-ws-tls-argo-$hostname-443"
echo "- ${sxname}vless-ws-argo-$hostname-80"
}
fi
sbtk=$(cat "$HOME/lun/sbargotoken.log" 2>/dev/null)
if [ -n "$sbtk" ]; then
nametn="Argo固定隧道token：$sbtk"
fi
argoshow=$(
echo "Argo隧道端口正在使用$vlvm-ws主协议端口：$(cat $HOME/lun/argoport.log 2>/dev/null)
Argo域名：$argodomain
$nametn

1、💣443端口的$vlvm-ws-tls-argo节点(优选IP与443系端口随便换)
${vmatls_link1}${vwatls_link1}

2、💣80端口的$vlvm-ws-argo节点(优选IP与80系端口随便换)
${vma_link7}${vwa_link2}
"
)
fi

get_func() {
f=$1
if type "$f" >/dev/null 2>&1; then
out=
case "$f" in
*argopt*) out=$($f); [ -n "$out" ] && printf "%s\n" "$out"; return ;;
esac
if [ -n "$addym" ] && [ "$addout" = "both" ]; then
client_addr="$server_ip"
node_name_suffix="-IP"
out=$($f)
[ -n "$out" ] && printf "%s\n" "$out"
client_addr="$addym"
node_name_suffix="-DOMAIN"
out=$($f)
[ -n "$out" ] && printf "%s\n" "$out"
client_addr="$server_ip"
node_name_suffix="-IP"
else
out=$($f)
[ -n "$out" ] && printf "%s\n" "$out"
fi
fi
}
sbxy="$(get_func sbvlpt; get_func sbsspt; get_func sbanpt; get_func sbarpt; get_func sbvmpt; get_func sbhypt; get_func sbtupt; get_func sbvmargopt)"
clxy="$(get_func clvlpt; get_func clsspt; get_func clanpt; get_func clvmpt; get_func clhypt; get_func cltupt; get_func clvmargopt)"
sbgz="$(get_func sbvlpt1; get_func sbsspt1; get_func sbanpt1; get_func sbarpt1; get_func sbvmpt1; get_func sbhypt1; get_func sbtupt1; get_func sbvmargopt1)"
clgz="$({ get_func clvlpt1; get_func clsspt1; get_func clanpt1; get_func clvmpt1; get_func clhypt1; get_func cltupt1; get_func clvmargopt1; } | sed '2,$s/^/    /')"
sbgz=$(printf "%s\n" "$sbgz" | sed '$ s/,$//')
cat > $HOME/lun/sbox.json <<EOF
{
    "log": {
        "disabled": false,
        "level": "info",
        "timestamp": true
    },
    "experimental": {
        "cache_file": {
            "enabled": true,
            "path": "./cache.db",
            "store_fakeip": true
        },
        "clash_api": {
            "external_controller": "127.0.0.1:9090",
            "external_ui": "ui",
            "default_mode": "Rule"
        }
    },
    "dns": {
        "servers": [
            {
                "tag": "aliDns",
                "type": "https",
                "server": "dns.alidns.com",
                "path": "/dns-query",
                "domain_resolver": "local"
            },
            {
                "tag": "local",
                "type": "udp",
                "server": "223.5.5.5"
            },
            {
                "tag": "proxyDns",
                "type": "https",
                "server": "dns.google",
                "path": "/dns-query",
	              "domain_resolver": "aliDns",
                "detour": "proxy"
            },
           {
        "type": "fakeip",
        "tag": "fakeip",
        "inet4_range": "198.18.0.0/15",
        "inet6_range": "fc00::/18"
      }
        ],
        "rules": [
            {
                "rule_set": "geosite-cn",
                "clash_mode": "Rule",
                "server": "aliDns"
            },
            {
                "clash_mode": "Direct",
                "server": "local"
            },
            {
                "clash_mode": "Global",
                "server": "proxyDns"
            },
            {
        "query_type": [
          "A",
          "AAAA"
        ],
        "server": "fakeip"
      }
        ],
        "final": "proxyDns",
        "strategy": "prefer_ipv4"
    },
    "inbounds": [
        {
            "type": "tun",
            "tag": "tun-in",
            "address": [
                "172.19.0.1/30",
                "fd00::1/126"
            ],
            "auto_route": true,
            "strict_route": true
        }
    ],
    "route": {
        "rules": [
            {
	 "inbound": "tun-in",
                "action": "sniff"
            },
            {
                "type": "logical",
                "mode": "or",
                "rules": [
                    {
                        "port": 53
                    },
                    {
                        "protocol": "dns"
                    }
                ],
                "action": "hijack-dns"
            },
         {
          "clash_mode": "Global",
          "outbound": "proxy"
         },
        {
        "rule_set": "geosite-cn",
        "clash_mode": "Rule",
        "outbound": "direct"
       },
     {
    "rule_set": "geoip-cn",
    "clash_mode": "Rule",
    "outbound": "direct"
      },
     {
    "ip_is_private": true,
    "clash_mode": "Rule",
    "outbound": "direct"
    },
     {
      "clash_mode": "Direct",
      "outbound": "direct"
     }
        ],
        "rule_set": [
            {
                "tag": "geosite-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-cn.srs",
                "download_detour": "direct"
            },
            {
                "tag": "geoip-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/cn.srs",
                "download_detour": "direct"
            }
        ],
        "final": "proxy",
        "auto_detect_interface": true,
        "default_domain_resolver": {
        "server": "aliDns"
        }
    },
  "outbounds": [
   $sbxy
        {
            "tag": "proxy",
            "type": "selector",
            "default": "auto",
            "outbounds": [
        "auto",
        $sbgz
            ]
        },
        {
            "tag": "auto",
            "type": "urltest",
            "outbounds": [
            $sbgz
            ],
            "url": "http://www.gstatic.com/generate_204",
            "interval": "10m",
            "tolerance": 50
        },
        {
            "type": "direct",
            "tag": "direct"
        }
    ]
}
EOF

cat > $HOME/lun/clmi.yaml <<EOF
port: 7890
allow-lan: true
mode: rule
log-level: info
unified-delay: true
dns:
  enable: true
  listen: "0.0.0.0:1053"
  ipv6: true
  prefer-h3: false
  respect-rules: true
  use-system-hosts: false
  cache-algorithm: "arc"
  enhanced-mode: "fake-ip"
  fake-ip-range: "198.18.0.1/16"
  fake-ip-filter:
    - "+.lan"
    - "+.local"
    - "+.msftconnecttest.com"
    - "+.msftncsi.com"
    - "localhost.ptlogin2.qq.com"
    - "localhost.sec.qq.com"
    - "+.in-addr.arpa"
    - "+.ip6.arpa"
    - "time.*.com"
    - "time.*.gov"
    - "pool.ntp.org"
    - "localhost.work.weixin.qq.com"
  default-nameserver: ["223.5.5.5", "119.29.29.29"]
  nameserver:
    - "https://1.1.1.1/dns-query"
    - "https://8.8.8.8/dns-query"
  proxy-server-nameserver:
    - "https://223.5.5.5/dns-query"
    - "https://doh.pub/dns-query"

proxies:
$clxy

proxy-groups:
- name: 负载均衡
  type: load-balance
  url: https://www.gstatic.com/generate_204
  interval: 300
  strategy: round-robin
  proxies:
    $clgz
- name: 自动选择
  type: url-test
  url: https://www.gstatic.com/generate_204
  interval: 300
  tolerance: 50
  proxies:
    $clgz
- name: 🌍选择代理节点
  type: select
  proxies:
    - 负载均衡
    - 自动选择
    - DIRECT
    $clgz
rules:
  - GEOIP,LAN,DIRECT
  - GEOSITE,CN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,🌍选择代理节点
EOF
restart_subscription_service
echo "---------------------------------------------------------"
echo "$argoshow"
echo
if [ -s $HOME/lun/subport.log ]; then
showsubport=$(cat $HOME/lun/subport.log)
if ps -ef 2>/dev/null | grep "$showsubport" | grep -v grep >/dev/null; then
show_subscription_links
fi
fi
echo
echo "---------------------------------------------------------"
echo "聚合节点信息，请进入 $HOME/lun/jhsub.txt 文件目录查看或者运行 cat $HOME/lun/jhsub.txt 查看"
echo "========================================================="
echo "相关快捷方式如下：(首次安装成功后需重连SSH，lun快捷方式才可生效；如未生效，请使用主脚本)"
showmode
}
cleandel(){
keep_entry=$1
stop_lun_owned_processes
sed -i '/lun/d' ~/.bashrc
sed -i '/export PATH="\$HOME\/bin:\$PATH"/d' ~/.bashrc
. ~/.bashrc 2>/dev/null
crontab -l > /tmp/crontab.tmp 2>/dev/null
sed -i '/lun\/sing-box/d' /tmp/crontab.tmp
sed -i '/lun\/xray/d' /tmp/crontab.tmp
sed -i '/lun\/cloudflared/d' /tmp/crontab.tmp
sed -i '/weblun/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
[ "$keep_entry" = "keep-entry" ] || \
rm -rf "$HOME/bin/lun" /usr/bin/lun 2>/dev/null
if pidof systemd >/dev/null 2>&1; then
for svc in xr sb argo; do
systemctl stop "$svc" >/dev/null 2>&1
systemctl disable "$svc" >/dev/null 2>&1
done
rm -rf /etc/systemd/system/{xr.service,sb.service,argo.service}
elif command -v rc-service >/dev/null 2>&1; then
for svc in sing-box xray argo; do
rc-service "$svc" stop >/dev/null 2>&1
rc-update del "$svc" default >/dev/null 2>&1
done
rm -rf /etc/init.d/{sing-box,xray,argo} /etc/local.d/alpinelun.start /etc/local.d/alpinesublun.start
iptables -t nat -F PREROUTING >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
rc-service iptables save >/dev/null 2>&1
rc-service ip6tables save >/dev/null 2>&1
fi
}
xrestart(){
for P in /proc/[0-9]*; do [ -L "$P/exe" ] || continue; TARGET=$(readlink -f "$P/exe" 2>/dev/null) || continue; case "$TARGET" in *"/lun/xray"|*"/lun/x") kill "$(basename "$P")" 2>/dev/null ;; esac; done
if pidof systemd >/dev/null 2>&1; then
systemctl restart xr >/dev/null 2>&1
elif command -v rc-service >/dev/null 2>&1; then
rc-service xray restart >/dev/null 2>&1
else
nohup $HOME/lun/xray run -c $HOME/lun/xr.json >/dev/null 2>&1 &
fi
}
sbrestart(){
for P in /proc/[0-9]*; do [ -L "$P/exe" ] || continue; TARGET=$(readlink -f "$P/exe" 2>/dev/null) || continue; case "$TARGET" in *"/lun/sing-box"|*"/lun/s") kill "$(basename "$P")" 2>/dev/null ;; esac; done
if pidof systemd >/dev/null 2>&1; then
systemctl restart sb >/dev/null 2>&1
elif command -v rc-service >/dev/null 2>&1; then
rc-service sing-box restart >/dev/null 2>&1
else
nohup $HOME/lun/sing-box run -c $HOME/lun/sb.json >/dev/null 2>&1 &
fi
}

refresh_protocol_flags(){
unset vlp vmp vwp hyp tup xhp vxp anp ssp arp sop vmag
unset port_vl_re port_vm_ws port_vw port_hy2 port_tu port_xh port_vx port_an port_ar port_ss port_so
[ -z "${vlpt+x}" ] || { vlp=yes; port_vl_re=$vlpt; }
[ -z "${vmpt+x}" ] || { vmp=yes; vmag=yes; port_vm_ws=$vmpt; }
[ -z "${vwpt+x}" ] || { vwp=yes; vmag=yes; port_vw=$vwpt; }
[ -z "${hypt+x}" ] || { hyp=yes; port_hy2=$hypt; }
[ -z "${tupt+x}" ] || { tup=yes; port_tu=$tupt; }
[ -z "${xhpt+x}" ] || { xhp=yes; port_xh=$xhpt; }
[ -z "${vxpt+x}" ] || { vxp=yes; port_vx=$vxpt; }
[ -z "${anpt+x}" ] || { anp=yes; port_an=$anpt; }
[ -z "${sspt+x}" ] || { ssp=yes; port_ss=$sspt; }
[ -z "${arpt+x}" ] || { arp=yes; port_ar=$arpt; }
[ -z "${sopt+x}" ] || { sop=yes; port_so=$sopt; }
[ -n "${warp:-}" ] && wap=yes || wap=
}

prompt_port(){
label=$1
var=$2
printf "请输入 %s 端口，回车随机：" "$label"
IFS= read -r val
eval "export $var=\"\$val\""
}

pick_protocols(){
echo "选择要启用的协议，可输入多个编号，例如：1 4 8"
echo " 1. VLESS TCP Reality Vision"
echo " 2. VLESS XHTTP Reality ENC"
echo " 3. VLESS XHTTP ENC"
echo " 4. VLESS WS ENC"
echo " 5. Shadowsocks-2022"
echo " 6. AnyTLS"
echo " 7. Any-Reality"
echo " 8. VMess WS"
echo " 9. Socks5"
echo "10. Hysteria2"
echo "11. TUIC"
printf "协议编号："
IFS= read -r picks
[ -z "$picks" ] && picks=1
for pick in $picks; do
case "$pick" in
1) prompt_port "VLESS TCP Reality" vlpt ;;
2) prompt_port "VLESS XHTTP Reality" xhpt ;;
3) prompt_port "VLESS XHTTP" vxpt ;;
4) prompt_port "VLESS WS" vwpt ;;
5) prompt_port "Shadowsocks-2022" sspt ;;
6) prompt_port "AnyTLS" anpt ;;
7) prompt_port "Any-Reality" arpt ;;
8) prompt_port "VMess WS" vmpt ;;
9) prompt_port "Socks5" sopt ;;
10) prompt_port "Hysteria2" hypt ;;
11) prompt_port "TUIC" tupt ;;
*) echo "忽略未知协议编号：$pick" ;;
esac
done
printf "是否启用 Argo 隧道？输入 vmpt/vwpt，回车不启用："
IFS= read -r menu_argo
case "$menu_argo" in vmpt|vwpt) export argo="$menu_argo" ;; esac
printf "节点名称前缀，回车不设置："
IFS= read -r menu_name
[ -n "$menu_name" ] && export name="$menu_name"
refresh_protocol_flags
}

configure_addym_menu(){
while :; do
echo "自定义普通节点客户端地址 addym"
echo "说明：只改普通节点 address/server/add，不改 Reality SNI、WS/XHTTP Host、Argo 地址。"
printf "请输入域名或 IP；输入 del 清除；回车保留当前值；0 返回："
IFS= read -r menu_addym
[ "$menu_addym" = "0" ] && return 2
[ "$menu_addym" = "del" ] || [ "$menu_addym" = "none" ] && { addym=del; addout=off; load_addym_config; echo "addym 已清除。"; continue; }
if [ -n "$menu_addym" ] && ! valid_addym "$menu_addym"; then
echo "addym 格式不正确，不要带协议、端口或路径。"
continue
fi
[ -n "$menu_addym" ] && addym="$menu_addym"
echo "输出模式：1. off  2. replace  3. both"
printf "请选择，回车默认 replace，0 返回："
IFS= read -r menu_addout
[ "$menu_addout" = "0" ] && return 2
case "$menu_addout" in
1) addout=off ;;
2) [ -n "$addym" ] && addout=replace ;;
3) addout=both ;;
*) [ -n "$addym" ] && addout=replace ;;
esac
load_addym_config
echo "addym/addout 设置已保存。"
return 0
done
}

update_lun_script(){
if [ "$(id -u 2>/dev/null)" = "0" ]; then
target="/usr/bin/lun"
else
target="$HOME/bin/lun"
mkdir -p "$HOME/bin"
fi
download_lun_script "$target" || { echo "Lun 脚本更新失败，请检查网络后重试。"; return 1; }
echo "Lun 脚本更新完成：$target"
}

lun_menu(){
while :; do
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Lun 风火轮多协议交互面板"
echo " 1. 安装 Lun / 新建协议"
echo " 2. 增删改协议变量组 (rep)"
echo " 3. 查看节点与订阅 (list)"
echo " 4. 设置自定义节点地址 addym/addout"
echo " 5. 重启 Lun 进程"
echo " 6. 更新 Xray 内核"
echo " 7. 更新 Sing-box 内核"
echo " 8. 更新 Lun 脚本"
echo " 9. 卸载 Lun"
echo " 0. 退出"
printf "请输入数字【0-9】："
IFS= read -r menu_choice
case "$menu_choice" in
1) pick_protocols; LUN_MENU_ACTION=install; break ;;
2) pick_protocols; LUN_MENU_ACTION=rep; break ;;
3) LUN_MENU_ACTION=list; break ;;
4) configure_addym_menu; [ -f "$HOME/lun/uuid" ] && LUN_MENU_ACTION=list || LUN_MENU_ACTION=exit; break ;;
5) LUN_MENU_ACTION=res; break ;;
6) LUN_MENU_ACTION=upx; break ;;
7) LUN_MENU_ACTION=ups; break ;;
8) update_lun_script; exit ;;
9) LUN_MENU_ACTION=del; break ;;
0|"") exit ;;
*) echo "输入错误，请重新选择。" ;;
esac
done
}

ui_line(){ printf '%s\n' "================================================================================"; }
ui_dash(){ printf '%s\n' "--------------------------------------------------------------------------------"; }
ui_title(){ ui_line; printf '%s\n' "$1"; ui_line; }
ui_pause(){ printf "按回车返回菜单："; IFS= read -r _pause; }
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
LUN_GREEN=$(tput setaf 2 2>/dev/null)
LUN_YELLOW=$(tput setaf 3 2>/dev/null)
LUN_RESET=$(tput sgr0 2>/dev/null)
else
LUN_GREEN=
LUN_YELLOW=
LUN_RESET=
fi
green_line(){ printf '%s%s%s\n' "$LUN_GREEN" "$1" "$LUN_RESET"; }
yellow_line(){ printf '%s%s%s\n' "$LUN_YELLOW" "$1" "$LUN_RESET"; }

port_valid(){
printf '%s' "$1" | grep -Eq '^[0-9]+$' || return 1
[ "$1" -ge 1 ] 2>/dev/null && [ "$1" -le 65535 ] 2>/dev/null
}

port_in_use(){
p=$1
if command -v ss >/dev/null 2>&1; then
ss -lntu 2>/dev/null | awk '{print $5}' | grep -Eq "[:.]$p$"
elif command -v netstat >/dev/null 2>&1; then
netstat -lntu 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]$p$"
else
return 1
fi
}

port_owner_lines(){
p=$1
if command -v ss >/dev/null 2>&1; then
ss -lntup 2>/dev/null | awk -v p="$p" '$5 ~ "[:.]" p "$" {print}'
elif command -v netstat >/dev/null 2>&1; then
netstat -lntup 2>/dev/null | awk -v p="$p" '$4 ~ "[:.]" p "$" {print}'
fi
}

port_owner_pids(){
port_owner_lines "$1" | sed -n 's/.*pid=\([0-9][0-9]*\).*/\1/p; s/.* \([0-9][0-9]*\)\/[^ ]*.*/\1/p' | sort -u
}

pid_is_lun_owned(){
pid=$1
exe=$(readlink -f "/proc/$pid/exe" 2>/dev/null)
cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
case "$exe" in
*/lun/*|*/agsbx/*) return 0 ;;
esac
case "$cmd" in
*httpd*"-h $HOME/weblun"*|*httpd*"-h $HOME/websbx"*) return 0 ;;
*) return 1 ;;
esac
}

stop_lun_owned_processes(){
for P in /proc/[0-9]*; do
[ -L "$P/exe" ] || continue
pid=$(basename "$P")
if pid_is_lun_owned "$pid"; then
kill "$pid" 2>/dev/null || true
fi
done
stop_subscription_service
if pidof systemd >/dev/null 2>&1; then
systemctl stop xr sb argo >/dev/null 2>&1 || true
elif command -v rc-service >/dev/null 2>&1; then
rc-service xray stop >/dev/null 2>&1 || true
rc-service sing-box stop >/dev/null 2>&1 || true
rc-service argo stop >/dev/null 2>&1 || true
fi
}

release_lun_port_if_owned(){
p=$1
owned=
pids=$(port_owner_pids "$p")
for pid in $pids; do
if pid_is_lun_owned "$pid"; then
owned=yes
break
fi
done
[ -n "$owned" ] || return 1
echo "端口 $p 被旧 Lun 进程占用，正在释放 Lun 相关进程……"
stop_lun_owned_processes
sleep 2
return 0
}

ensure_port_available(){
p=$1
if ! port_in_use "$p"; then
return 0
fi
if release_lun_port_if_owned "$p"; then
if ! port_in_use "$p"; then
echo "端口 $p 已释放。"
return 0
fi
echo "已停止 Lun 进程，但端口 $p 仍被占用。"
fi
echo "端口 $p 被非 Lun 进程占用，请换一个端口。"
port_owner_lines "$p" | sed 's/^/  /'
return 1
}

port_reserved(){
p=$1
for used in "$port_xh" "$port_vx" "$port_vw" "$port_vl_re" "$port_ss" "$port_an" "$port_ar" "$port_vm_ws" "$port_so" "$port_hy2" "$port_tu" "$subpt"; do
[ "$used" = "$p" ] && return 0
done
for file in "$HOME/lun/port_xh" "$HOME/lun/port_vx" "$HOME/lun/port_vw" "$HOME/lun/port_vl_re" "$HOME/lun/port_ss" "$HOME/lun/port_an" "$HOME/lun/port_ar" "$HOME/lun/port_vm_ws" "$HOME/lun/port_so" "$HOME/lun/port_hy2" "$HOME/lun/port_tu" "$HOME/lun/subport.log"; do
[ -s "$file" ] && [ "$(cat "$file" 2>/dev/null)" = "$p" ] && return 0
done
return 1
}

random_port(){
if [ -n "$inpool" ] || [ -n "$portpool" ]; then
candidates=$(port_pool_inner_candidates | shuf 2>/dev/null)
for p in $candidates; do
port_valid "$p" || continue
port_reserved "$p" && continue
port_in_use "$p" || { printf '%s\n' "$p"; return 0; }
done
echo "端口池内没有可用端口，请扩容端口池或手动输入端口。" >&2
return 1
fi
for _try in 1 2 3 4 5 6 7 8 9 10; do
p=$(shuf -i 10000-65535 -n 1)
port_reserved "$p" && continue
port_in_use "$p" || { printf '%s\n' "$p"; return; }
done
shuf -i 10000-65535 -n 1
}

prompt_port(){
label=$1
var=$2
while :; do
if is_nat_mode; then
[ -n "$ptmap" ] && echo "当前手动 NAT 映射：$ptmap；这里请填写内网监听端口或对应公网端口。"
[ -n "$inpool" ] && echo "当前内网端口池：$inpool"
[ -n "$outpool" ] && echo "当前外网端口池：$outpool（按位置映射内网池）"
printf "请输入 %s 内网端口，回车随机，0 返回：" "$label"
else
[ -n "$inpool" ] && echo "当前端口池：$inpool"
printf "请输入 %s 端口，回车随机，0 返回：" "$label"
fi
IFS= read -r val
[ "$val" = "0" ] && return 2
if [ -z "$val" ]; then
val=$(random_port) || { echo "无法从端口池取得可用端口。"; continue; }
echo "随机端口：$val"
fi
mapped_inner=$(inner_port_from_public "$val")
if [ -n "$mapped_inner" ]; then
echo "检测到你输入的是公网端口 $val，已转换为内网监听端口 $mapped_inner。"
val="$mapped_inner"
fi
if ! port_valid "$val"; then
echo "端口必须是 1-65535 的数字。"
continue
fi
ensure_port_available "$val" || continue
eval "export $var=\"\$val\""
if is_nat_mode; then
echo "$label 内网端口：$val"
else
echo "$label 端口：$val"
fi
show_port_mapping_hint "$val"
return 0
done
}

load_installed_protocol_flags(){
[ -s "$HOME/lun/port_vl_re" ] && { vlpt=$(cat "$HOME/lun/port_vl_re"); vlp=yes; port_vl_re=$vlpt; }
[ -s "$HOME/lun/port_xh" ] && { xhpt=$(cat "$HOME/lun/port_xh"); xhp=yes; port_xh=$xhpt; }
[ -s "$HOME/lun/port_vx" ] && { vxpt=$(cat "$HOME/lun/port_vx"); vxp=yes; port_vx=$vxpt; }
[ -s "$HOME/lun/port_vw" ] && { vwpt=$(cat "$HOME/lun/port_vw"); vwp=yes; vmag=yes; port_vw=$vwpt; }
[ -s "$HOME/lun/port_ss" ] && { sspt=$(cat "$HOME/lun/port_ss"); ssp=yes; port_ss=$sspt; }
[ -s "$HOME/lun/port_an" ] && { anpt=$(cat "$HOME/lun/port_an"); anp=yes; port_an=$anpt; }
[ -s "$HOME/lun/port_ar" ] && { arpt=$(cat "$HOME/lun/port_ar"); arp=yes; port_ar=$arpt; }
[ -s "$HOME/lun/port_vm_ws" ] && { vmpt=$(cat "$HOME/lun/port_vm_ws"); vmp=yes; vmag=yes; port_vm_ws=$vmpt; }
[ -s "$HOME/lun/port_so" ] && { sopt=$(cat "$HOME/lun/port_so"); sop=yes; port_so=$sopt; }
[ -s "$HOME/lun/port_hy2" ] && { hypt=$(cat "$HOME/lun/port_hy2"); hyp=yes; port_hy2=$hypt; }
[ -s "$HOME/lun/port_tu" ] && { tupt=$(cat "$HOME/lun/port_tu"); tup=yes; port_tu=$tupt; }
}

show_protocol_summary(){
found=
for item in \
"VLESS Reality:$HOME/lun/port_vl_re" \
"VLESS XHTTP Reality:$HOME/lun/port_xh" \
"VLESS XHTTP:$HOME/lun/port_vx" \
"VLESS WS:$HOME/lun/port_vw" \
"Shadowsocks:$HOME/lun/port_ss" \
"AnyTLS:$HOME/lun/port_an" \
"Any-Reality:$HOME/lun/port_ar" \
"VMess WS:$HOME/lun/port_vm_ws" \
"Socks5:$HOME/lun/port_so" \
"Hysteria2:$HOME/lun/port_hy2" \
"TUIC:$HOME/lun/port_tu"; do
label=${item%%:*}
file=${item#*:}
if [ -s "$file" ]; then
port=$(cat "$file" 2>/dev/null)
if is_nat_mode; then
public=$(client_port "$port")
if [ "$public" != "$port" ]; then
printf "  %-22s 内网端口：%s  公网端口：%s\n" "$label" "$port" "$public"
else
printf "  %-22s 内网端口：%s\n" "$label" "$port"
fi
else
printf "  %-22s 端口：%s\n" "$label" "$port"
fi
found=yes
fi
done
[ -n "$found" ] || echo "  未安装协议"
}

show_cert_summary(){
mode=$(cat "$HOME/lun/cert_mode" 2>/dev/null)
subject=$(cat "$HOME/lun/cert_subject" 2>/dev/null)
[ -z "$mode" ] && mode=self
[ -z "$subject" ] && subject=www.bing.com
if [ -f "$HOME/lun/cert.crt" ]; then
end=$(openssl x509 -in "$HOME/lun/cert.crt" -noout -enddate 2>/dev/null | cut -d= -f2-)
printf "证书模式：%s  主体：%s  到期：%s\n" "$mode" "$subject" "${end:-未知}"
else
printf "证书模式：%s  主体：%s  状态：未生成\n" "$mode" "$subject"
fi
}

show_subscription_summary(){
if [ -s "$HOME/lun/subport.log" ] && [ -s "$HOME/lun/subtoken.log" ]; then
subport=$(cat "$HOME/lun/subport.log")
sub_public_port=$(client_port "$subport")
if is_nat_mode && [ "$sub_public_port" != "$subport" ]; then
green_line "节点订阅分享：$subipmode  内网端口：$subport  公网端口：$sub_public_port  token：$(cat "$HOME/lun/subtoken.log")"
else
green_line "节点订阅分享：$subipmode  端口：$subport  token：$(cat "$HOME/lun/subtoken.log")"
fi
else
echo "节点订阅分享：未启用"
fi
}

subscription_addresses(){
mode=${subipmode:-ipv4}
[ -z "${v4+x}" ] && v4v6
case "$mode" in
ipv6)
[ -n "$v6" ] && printf '[%s]\n' "$v6"
;;
both)
[ -n "$v4" ] && printf '%s\n' "$v4"
[ -n "$v6" ] && printf '[%s]\n' "$v6"
;;
*)
if [ -n "$v4" ]; then
printf '%s\n' "$v4"
else
server_logged=$(cat "$HOME/lun/server_ip.log" 2>/dev/null)
case "$server_logged" in *:*) ;; *) [ -n "$server_logged" ] && printf '%s\n' "$server_logged" ;; esac
fi
;;
esac
}

show_subscription_links(){
[ -s "$HOME/lun/subport.log" ] && [ -s "$HOME/lun/subtoken.log" ] || return
showsubport=$(cat "$HOME/lun/subport.log")
showsubtoken=$(cat "$HOME/lun/subtoken.log" 2>/dev/null)
showpublicport=$(client_port "$showsubport")
addresses=$(subscription_addresses)
[ -n "$addresses" ] || { echo "节点订阅分享地址：当前模式 $subipmode 没有可用 IP，已跳过。"; return; }
echo "**********************************************************"
for subip in $addresses; do
suburl="$subip:$showpublicport/$showsubtoken"
green_line "Clash/Mihomo订阅地址：http://$suburl/clmi.yaml"
green_line "Sing-box订阅地址：http://$suburl/sbox.json"
green_line "聚合协议订阅地址：http://$suburl/jhsub.txt"
done
echo "**********************************************************"
}

# ============ Cloudflare 橙云端口模式判断 ============
# CF 橙云只支持特定端口回源：
#   HTTP 系（明文）：80、8080、8880、2052、2082、2086、2095
#   HTTPS 系（加密）：443、8443、2053、2083、2087、2096
# 返回 http 或 https，端口不在列表内则返回失败（return 1）
cf_port_mode(){
case "$1" in
80|8080|8880|2052|2082|2086|2095) printf 'http\n' ;;
443|8443|2053|2083|2087|2096) printf 'https\n' ;;
*) return 1 ;;
esac
}

# ============ 读取 CDN 优选 IP/域名列表 ============
# 从 cdnip1、cdnip2 两个文件读取用户配置的 CDN 优选地址
# 跳过空值和 "-1"（兼容旧版残留），并用 valid_addym 校验格式
# 返回值：逐行输出有效的优选地址
cdn_ip_list(){
for f in "$HOME/lun/cdnip1" "$HOME/lun/cdnip2"; do
[ -s "$f" ] || continue
while IFS= read -r one; do
case "$one" in ""|-1) continue ;; esac
valid_addym "$one" || continue
printf '%s\n' "$one"
done < "$f"
done
}

# ============ 写入默认 CDN 优选地址 ============
# 当 cdnip1/cdnip2 文件不存在或为空时，写入默认优选域名
# 使用域名而非纯IP：纯 Cloudflare IP 可能被识别为直连，域名走 CDN 代理更稳定
cdn_default_ips(){
[ -s "$HOME/lun/cdnip1" ] || printf "%s\n" "cloudflare-ech.com" > "$HOME/lun/cdnip1"
[ -s "$HOME/lun/cdnip2" ] || printf "%s\n" "www.visa.com.sg" > "$HOME/lun/cdnip2"
}

# ============ CDN 跳过提示 ============
# 当协议不支持 CDN 或缺少必要配置时，输出黄色提示信息
cdn_skip(){
yellow_line "CDN提示：$1"
}

# ============ 显示 CDN 端口建议 ============
# 遍历所有支持 CDN 的协议（VLESS XHTTP、VLESS WS、VMess WS）
# 检查它们的公网端口是否在 Cloudflare 橙云支持端口列表内
# 如果端口匹配，显示可生成 CDN 变体；否则提示需要更换端口
show_cdn_port_advice(){
echo "Cloudflare 橙云普通代理端口：80/8080/8880/2052/2082/2086/2095 或 443/8443/2053/2083/2087/2096。"
echo "NAT VPS 请确保公网端口在上述列表内；只有内网端口匹配不算。"
found=
for item in \
"VLESS XHTTP:$HOME/lun/port_vx" \
"VLESS WS:$HOME/lun/port_vw" \
"VMess WS:$HOME/lun/port_vm_ws"; do
label=${item%%:*}
file=${item#*:}
[ -s "$file" ] || continue
found=yes
inner=$(cat "$file" 2>/dev/null)
public=$(client_port "$inner")
mode=$(cf_port_mode "$public" 2>/dev/null || true)
if [ -n "$mode" ]; then
green_line "$label 可生成 CDN 变体：内网端口 $inner，公网端口 $public，CF 模式 $mode。"
else
yellow_line "$label 当前公网端口 $public 不在 CF 支持端口内，将只保留直连节点。"
yellow_line "  提示：可通过 lun 菜单 → 安装/协议管理 修改端口为 CF 支持端口，以启用 CDN 加速。"
fi
done
[ -n "$found" ] || yellow_line "当前没有 VMess WS / VLESS WS / VLESS XHTTP 非 Reality，普通橙云 CDN 不会生成节点；可使用 CF 隧道/Argo。"
}

# ============ 生成 VLESS CDN 优选节点链接 ============
# 参数：$1=节点标签  $2=基础名称  $3=协议端口  $4=URL查询参数
# 流程：
#   1. 检查 cdnym（回源Host域名）是否存在，没有则跳过
#   2. 获取公网端口并判断 CF 端口模式（http/https）
#   3. 读取 CDN 优选地址列表（cdnip1/cdnip2）
#   4. 为每个优选地址生成一条 CDN 节点链接
# CDN 节点原理：add=优选地址（客户端连CF入口），host=回源域名（CF回源到VPS）
append_vless_cdn_links(){
label=$1
base_name=$2
port=$3
query=$4
# 检查回源 Host 域名：CDN 需要一个解析到 VPS 的域名作为回源地址
[ -n "$xvvmcdnym" ] || { cdn_skip "$label 缺少 CDN 回源 Host，已跳过 CDN 变体。请在 lun → 入口网络管理 → CDN 中设置回源 Host 域名。"; return 0; }
# 获取公网端口（NAT 模式下可能不同于内网端口）
public_port=$(client_port "$port")
# 判断端口是否在 CF 橙云支持列表内
mode=$(cf_port_mode "$public_port" 2>/dev/null) || {
cdn_skip "$label 的公网端口 $public_port 不在 Cloudflare 橙云支持端口内，已跳过 CDN 变体。"
cdn_skip "支持端口：80/8080/8880/2052/2082/2086/2095（HTTP）或 443/8443/2053/2083/2087/2096（HTTPS）。"
cdn_skip "请通过 lun → 安装/协议管理 修改该协议端口。"
return 0
}
# 读取 CDN 优选地址，为空则写入默认值
ips=$(cdn_ip_list)
[ -n "$ips" ] || { cdn_default_ips; ips=$(cdn_ip_list); }
echo "💣【 $label 】CDN 优选节点信息如下："
echo "注：add=CF优选地址（客户端入口），host=回源域名（CF回源到VPS），服务器出站仍直连 VPS。"
for cdn_ip in $ips; do
case "$cdn_ip" in ""|-1) continue ;; esac
if [ "$mode" = "https" ]; then
# HTTPS 模式：启用 TLS，sni=回源域名
cdn_link="vless://$uuid@$cdn_ip:$public_port?${query}&host=$xvvmcdnym&security=tls&sni=$xvvmcdnym&fp=chrome#${sxname}${base_name}-cdn-$hostname-$public_port"
else
# HTTP 模式：不启用 TLS
cdn_link="vless://$uuid@$cdn_ip:$public_port?${query}&host=$xvvmcdnym#${sxname}${base_name}-cdn-$hostname-$public_port"
fi
echo "$cdn_link" >> "$HOME/lun/jhsub.txt"
echo "$cdn_link"
done
echo
}

# ============ 生成 VMess WS CDN 优选节点链接 ============
# 参数：$1=协议端口
# 原理同 append_vless_cdn_links，针对 VMess WS 协议生成 base64 编码的 vmess:// 链接
append_vmess_cdn_links(){
port=$1
[ -n "$xvvmcdnym" ] || { cdn_skip "VMess WS 缺少 CDN 回源 Host，已跳过 CDN 变体。请在 lun → 入口网络管理 → CDN 中设置回源 Host 域名。"; return 0; }
public_port=$(client_port "$port")
mode=$(cf_port_mode "$public_port" 2>/dev/null) || {
cdn_skip "VMess WS 的公网端口 $public_port 不在 Cloudflare 橙云支持端口内，已跳过 CDN 变体。"
cdn_skip "支持端口：80/8080/8880/2052/2082/2086/2095（HTTP）或 443/8443/2053/2083/2087/2096（HTTPS）。"
cdn_skip "请通过 lun → 安装/协议管理 修改该协议端口。"
return 0
}
ips=$(cdn_ip_list)
[ -n "$ips" ] || { cdn_default_ips; ips=$(cdn_ip_list); }
echo "💣【 Vmess-ws-cdn 】CDN 优选节点信息如下："
echo "注：add=CF优选地址（客户端入口），host=回源域名（CF回源到VPS），服务器出站仍直连 VPS。"
for cdn_ip in $ips; do
case "$cdn_ip" in ""|-1) continue ;; esac
if [ "$mode" = "https" ]; then
# HTTPS 模式：启用 TLS，sni=回源域名
vm_cdn_json="{ \"v\": \"2\", \"ps\": \"${sxname}vm-ws-cdn-$hostname-$public_port\", \"add\": \"$cdn_ip\", \"port\": \"$public_port\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$xvvmcdnym\", \"path\": \"/$uuid-vm\", \"tls\": \"tls\", \"sni\": \"$xvvmcdnym\", \"fp\": \"chrome\"}"
else
# HTTP 模式：不启用 TLS
vm_cdn_json="{ \"v\": \"2\", \"ps\": \"${sxname}vm-ws-cdn-$hostname-$public_port\", \"add\": \"$cdn_ip\", \"port\": \"$public_port\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$xvvmcdnym\", \"path\": \"/$uuid-vm\", \"tls\": \"\"}"
fi
vm_cdn_link="vmess://$(printf '%s' "$vm_cdn_json" | base64 -w0)"
echo "$vm_cdn_link" >> "$HOME/lun/jhsub.txt"
echo "$vm_cdn_link"
done
echo
}

# ============ 显示 CDN 配置摘要 ============
# 在仪表板上显示当前 CDN 状态：是否启用、回源 Host、优选地址
show_cdn_summary(){
cdn_host=$(cat "$HOME/lun/cdnym" 2>/dev/null)
if [ -n "$cdn_host" ]; then
cdn_ips=$(cdn_ip_list | tr '\n' ' ' | sed 's/[[:space:]]*$//')
echo "CDN：已启用  Host=$cdn_host  优选=${cdn_ips:-默认域名}"
else
echo "CDN：未启用"
fi
}

lun_dashboard(){
clear 2>/dev/null || true
ui_line
printf " _      _   _ _   _\n"
printf "| |    | | | | \\ | |\n"
printf "| |    | | | |  \\| |\n"
printf "| |___ | |_| | |\\  |\n"
printf "|_____| \\___/|_| \\_|\n"
printf "     (O)===(O)   (O)===(O)   (O)===(O)\n"
ui_line
echo "Lun 风火轮多协议交互面板"
ui_dash
printf "系统：%s  内核：%s  架构：%s  虚拟化：%s\n" "$op" "$(uname -r)" "$cpu" "${vi:-unknown}"
printf "BBR算法：%s\n" "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
v4v6
printf "本地IPv4：%s  本地IPv6：%s\n" "${v4:-无IPV4}" "${v6:-无IPV6}"
ui_dash
lunstatus
ui_dash
show_cert_summary
[ -s "$HOME/lun/domain" ] && printf "服务域名：%s\n" "$(cat "$HOME/lun/domain")" || echo "服务域名：未设置"
[ -s "$HOME/lun/addym" ] && printf "普通节点地址：%s  输出：%s\n" "$(cat "$HOME/lun/addym")" "$(cat "$HOME/lun/addout" 2>/dev/null)" || echo "普通节点地址：使用服务器 IP"
if is_nat_mode; then
echo "VPS类型：NAT VPS"
[ -s "$HOME/lun/port_map" ] && printf "NAT端口映射：%s\n" "$(cat "$HOME/lun/port_map")" || echo "NAT端口映射：无"
[ -s "$HOME/lun/inner_port_pool" ] && printf "内网端口池：%s\n" "$(cat "$HOME/lun/inner_port_pool")" || { [ -s "$HOME/lun/port_pool" ] && printf "内网端口池：%s\n" "$(cat "$HOME/lun/port_pool")" || echo "内网端口池：未设置"; }
[ -s "$HOME/lun/outer_port_pool" ] && printf "外网端口池：%s\n" "$(cat "$HOME/lun/outer_port_pool")" || echo "外网端口池：未设置"
[ -s "$HOME/lun/inner_port_pool" ] && [ -s "$HOME/lun/outer_port_pool" ] && echo "NAT自动映射：外网端口池按顺序对应内网端口池"
else
echo "VPS类型：普通 VPS"
[ -s "$HOME/lun/inner_port_pool" ] && printf "端口池：%s\n" "$(cat "$HOME/lun/inner_port_pool")" || { [ -s "$HOME/lun/port_pool" ] && printf "端口池：%s\n" "$(cat "$HOME/lun/port_pool")" || echo "端口池：未设置"; }
fi
show_cdn_summary
if [ "$wap" = yes ] && [ -n "$warp" ]; then
echo "出站：WARP($warp)，目标网站可能显示 WARP/Cloudflare IP"
else
echo "出站：直连 VPS"
fi
argo_status_line
argodomain=$(cat "$HOME/lun/sbargoym.log" 2>/dev/null)
[ -z "$argodomain" ] && argodomain=$(grep -a trycloudflare.com "$HOME/lun/argo.log" 2>/dev/null | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
[ -n "$argodomain" ] && echo "Argo域名：$argodomain" || echo "Argo域名：未启用"
[ -s "$HOME/lun/argoip" ] && printf "Argo优选：%s\n" "$(cat "$HOME/lun/argoip")" || echo "Argo优选：中性默认"
show_subscription_summary
ui_dash
echo "协议概览："
show_protocol_summary
ui_dash
}

prompt_service_domain(){
while :; do
cur=$(cat "$HOME/lun/domain" 2>/dev/null)
printf "请输入已解析服务域名，回车跳过/保留当前值%s，del 清除，0 返回：" "${cur:+[$cur]}"
IFS= read -r val
[ "$val" = "0" ] && return 2
[ -z "$val" ] && return 0
case "$val" in
del|none)
rm -f "$HOME/lun/domain"
domain=
echo "服务域名已清除。"
continue
;;
esac
if valid_domain "$val"; then
domain="$val"
printf "%s\n" "$domain" > "$HOME/lun/domain"
echo "服务域名已保存：$domain"
resolved=$(resolve_domain_ips "$domain")
if [ -n "$resolved" ]; then
echo "当前解析结果：$resolved"
else
echo "提示：暂未解析到 A/AAAA 记录；普通节点仍可保存，ACME 域名证书会要求解析到本机。"
fi
return 0
fi
echo "域名格式不正确，请只填写 example.com，不要带协议、端口或路径。"
done
}

save_dns_env_interactive(){
printf "请输入 acme.sh DNS provider，例如 dns_cf、dns_ali，回车保留当前值，0 返回："
IFS= read -r val
[ "$val" = "0" ] && return 2
[ -n "$val" ] && { acme_dns="$val"; printf "%s\n" "$acme_dns" > "$HOME/lun/acme_dns"; }
if [ -z "$acme_dns" ] && [ -s "$HOME/lun/acme_dns" ]; then
acme_dns=$(cat "$HOME/lun/acme_dns" 2>/dev/null)
fi
[ -n "$acme_dns" ] || { echo "未设置 DNS provider。"; return 1; }
echo "请输入 DNS API 环境变量，格式 KEY=VALUE；空行结束。"
: > "$HOME/lun/cert.env"
while :; do
printf "> "
IFS= read -r line
[ "$line" = "0" ] && return 2
[ -z "$line" ] && break
case "$line" in
*=*) printf "export %s\n" "$line" >> "$HOME/lun/cert.env" ;;
*) echo "格式错误，示例：CF_Token=xxxx" ;;
esac
done
chmod 600 "$HOME/lun/cert.env" "$HOME/lun/acme_dns" 2>/dev/null
}

prompt_acme_email(){
cur=$(cat "$HOME/lun/acme_email" 2>/dev/null)
printf "Let’s Encrypt 账户邮箱，回车随机生成谷歌邮箱%s，0 返回：" "${cur:+[当前:$cur]}"
IFS= read -r val
[ "$val" = "0" ] && return 2
if [ -n "$val" ]; then
acme_email="$val"
else
acme_email=$(gen_random_gmail)
echo "已随机生成谷歌邮箱：$acme_email"
fi
printf "%s\n" "$acme_email" > "$HOME/lun/acme_email"
}

prompt_cert_mode(){
while :; do
echo "证书模式："
echo " 1. 自签证书（默认，立即可用）"
echo " 2. Let’s Encrypt 域名证书（HTTP-01，要求域名解析到本机且 80 可访问）"
echo " 3. Let’s Encrypt DNS API 证书（acme.sh 原生 DNS provider）"
echo " 4. Let’s Encrypt IP 证书（short-lived，HTTP-01）"
echo " 0. 返回上一步"
printf "请选择 [0-4]，回车默认 1："
IFS= read -r c
case "$c" in
0) return 2 ;;
2)
if [ -z "$domain" ]; then
echo "域名证书需要服务域名。请按 0 返回上一步设置域名，或选择 1 使用自签证书。"
continue
fi
prompt_acme_email
rc=$?
[ "$rc" = 2 ] && return 2
certmode=domain
;;
3)
if [ -z "$domain" ]; then
echo "DNS API 证书需要服务域名。请按 0 返回上一步设置域名，或选择 1 使用自签证书。"
continue
fi
prompt_acme_email
rc=$?
[ "$rc" = 2 ] && return 2
save_dns_env_interactive
rc=$?
[ "$rc" = 2 ] && return 2
[ "$rc" = 0 ] && certmode=dns || continue
;;
4)
prompt_acme_email
rc=$?
[ "$rc" = 2 ] && return 2
certmode=ip
;;
""|1) certmode=self ;;
*) echo "输入错误，请重新选择。"; continue ;;
esac
printf "%s\n" "$certmode" > "$HOME/lun/cert_mode"
return 0
done
}

prompt_argo_protocol_seed(){
while :; do
echo "Argo/CF 隧道需要先有 VMess WS 或 VLESS WS。"
if is_nat_mode; then
echo " 1. 添加 VLESS WS（支持后续 Argo 隧道/CF优选CDN，默认内网端口 8080）"
echo " 2. 添加 VMess WS（支持后续 Argo 隧道/CF优选CDN，默认内网端口 8080）"
else
echo " 1. 添加 VLESS WS（支持后续 Argo 隧道/CF优选CDN，默认端口 8080）"
echo " 2. 添加 VMess WS（支持后续 Argo 隧道/CF优选CDN，默认端口 8080）"
fi
echo " 0. 返回"
printf "请选择 [0-2]，回车默认 1："
IFS= read -r val
case "$val" in
0) return 2 ;;
""|1) target_var=vwpt; target_label="VLESS WS"; argo=vwpt ;;
2) target_var=vmpt; target_label="VMess WS"; argo=vmpt ;;
*) echo "输入错误。"; continue ;;
esac
while :; do
if is_nat_mode; then
printf "%s 内网端口，回车默认 8080，0 返回：" "$target_label"
else
printf "%s 端口，回车默认 8080，0 返回：" "$target_label"
fi
IFS= read -r port
[ "$port" = "0" ] && return 2
[ -z "$port" ] && port=8080
mapped_inner=$(inner_port_from_public "$port")
[ -n "$mapped_inner" ] && port="$mapped_inner"
if port_valid "$port" && ensure_port_available "$port"; then
eval "export $target_var=\"\$port\""
case "$target_var" in
vwpt) vwp=yes; vmag=yes; port_vw=$port ;;
vmpt) vmp=yes; vmag=yes; port_vm_ws=$port ;;
esac
show_port_mapping_hint "$port"
if is_nat_mode; then
echo "已添加 $target_label，内网端口：$port"
else
echo "已添加 $target_label，端口：$port"
fi
return 0
fi
echo "端口不可用，请重新输入。"
done
done
}

prompt_argo_ip(){
while :; do
cur=$(cat "$HOME/lun/argoip" 2>/dev/null)
printf "Argo 优选 IP / 入口地址，可填一到两个 IP/域名；回车保留/使用中性默认；del 清除；0 返回%s：" "${cur:+，当前 $cur}"
IFS= read -r val
[ "$val" = "0" ] && return 2
case "$val" in
"") return 0 ;;
del|none|off)
rm -f "$HOME/lun/argoip"
argoip=
echo "Argo 优选 IP 已清除，将使用中性默认入口。"
return 0
;;
esac
bad=
for one in $val; do
case "$one" in -1) bad=yes ;; *) valid_addym "$one" || bad=yes ;; esac
done
if [ -n "$bad" ]; then
echo "Argo 优选 IP 只接受 IP 或域名，多个值用空格分隔，不要带协议、端口或路径。"
continue
fi
argoip="$val"
printf "%s\n" "$argoip" > "$HOME/lun/argoip"
echo "Argo 优选 IP 已保存：$argoip"
return 0
done
}

prompt_argo(){
vm_ws_port="${port_vm_ws:-$(cat "$HOME/lun/port_vm_ws" 2>/dev/null)}"
vless_ws_port="${port_vw:-$(cat "$HOME/lun/port_vw" 2>/dev/null)}"
if [ -z "$vm_ws_port" ] && [ -z "$vless_ws_port" ]; then
prompt_argo_protocol_seed
rc=$?
[ "$rc" = 2 ] && return 2
[ "$rc" = 0 ] || return 1
seeded_argo="$argo"
vm_ws_port="${port_vm_ws:-$(cat "$HOME/lun/port_vm_ws" 2>/dev/null)}"
vless_ws_port="${port_vw:-$(cat "$HOME/lun/port_vw" 2>/dev/null)}"
fi
echo "Argo 隧道："
[ -n "$vm_ws_port" ] && echo " 1. 使用 VMess WS 端口：$vm_ws_port" || echo " 1. VMess WS 未安装"
[ -n "$vless_ws_port" ] && echo " 2. 使用 VLESS WS 端口：$vless_ws_port" || echo " 2. VLESS WS 未安装"
echo " 0. 返回上一步"
if [ -n "$seeded_argo" ]; then
printf "请选择 [0-2]，回车绑定刚添加的协议："
else
printf "请选择 [0-2]，回车不启用："
fi
IFS= read -r val
case "$val" in
0) return 2 ;;
"") [ -n "$seeded_argo" ] && argo="$seeded_argo" || argo= ;;
1) [ -n "$vm_ws_port" ] && argo=vmpt || { echo "VMess WS 未安装，不能绑定 Argo。"; return 1; } ;;
2) [ -n "$vless_ws_port" ] && argo=vwpt || { echo "VLESS WS 未安装，不能绑定 Argo。"; return 1; } ;;
*) argo= ;;
esac
if [ -n "$argo" ]; then
while :; do
printf "固定隧道域名 agn，回车使用临时隧道，0 返回："
IFS= read -r agn
[ "$agn" = "0" ] && return 2
[ -z "$agn" ] && break
if valid_addym "$agn"; then
break
fi
echo "隧道域名格式不正确，不要带 http://、端口或路径。"
done
printf "固定隧道 token agk，回车使用临时隧道，0 返回："
IFS= read -r agk
[ "$agk" = "0" ] && return 2
[ -n "$agk" ] && agk=$(sanitize_argo_token "$agk")
ARGO_DOMAIN="$agn"
ARGO_AUTH="$agk"
prompt_argo_ip
rc=$?
[ "$rc" = 2 ] && return 2
export argo agn agk ARGO_DOMAIN ARGO_AUTH argoip
fi
}

prompt_subscription(){
printf "是否启用节点订阅分享？[y/N]，0 返回："
IFS= read -r val
case "$val" in
0) return 2 ;;
y|Y)
sub=y
printf "订阅 token，回车使用 UUID，0 返回："
IFS= read -r subid
[ "$subid" = "0" ] && return 2
while :; do
if is_nat_mode; then
printf "节点订阅分享内网监听端口，回车从内网端口池/随机取，0 返回："
else
printf "节点订阅分享端口，回车从端口池/随机取，0 返回："
fi
IFS= read -r subpt
[ "$subpt" = "0" ] && return 2
if [ -z "$subpt" ]; then
subpt=$(random_port) || { echo "无法从端口池取得可用订阅端口。"; continue; }
if is_nat_mode; then
echo "节点订阅分享随机内网端口：$subpt"
else
echo "节点订阅分享随机端口：$subpt"
fi
fi
mapped_inner=$(inner_port_from_public "$subpt")
if [ -n "$mapped_inner" ]; then
echo "检测到你输入的是公网端口 $subpt，已转换为订阅内网端口 $mapped_inner。"
subpt="$mapped_inner"
fi
if port_valid "$subpt" && ensure_port_available "$subpt"; then
show_port_mapping_hint "$subpt"
break
fi
echo "端口格式错误或仍被占用。"
done
export sub subid subpt
;;
*) sub= ;;
esac
}

prompt_subscription_ip_mode(){
while :; do
echo "订阅地址 IP 输出模式："
echo " 1. IPv4 only（默认）"
echo " 2. IPv6 only"
echo " 3. IPv4 + IPv6 auto"
echo " 0. 返回"
printf "请选择 [0-3]，当前 ${subipmode:-ipv4}："
IFS= read -r val
case "$val" in
0) return 2 ;;
""|1) subipmode=ipv4 ;;
2) subipmode=ipv6 ;;
3) subipmode=both ;;
*) echo "输入错误。"; continue ;;
esac
printf "%s\n" "$subipmode" > "$HOME/lun/subip_mode"
echo "订阅 IP 输出模式已设置为：$subipmode"
return 0
done
}

refresh_subscription_share(){
if [ ! -s "$HOME/lun/jhsub.txt" ] || [ ! -s "$HOME/lun/sbox.json" ] || [ ! -s "$HOME/lun/clmi.yaml" ]; then
cip
else
restart_subscription_service
show_subscription_links
fi
}

subscription_menu(){
while :; do
ui_title "Lun 节点订阅分享"
show_subscription_summary
echo " 1. 设置订阅 token / 端口"
echo " 2. 设置订阅 IPv4/IPv6 输出"
echo " 3. 刷新节点分享（不重装内核）"
echo " 0. 返回"
printf "请选择 [0-3]："
IFS= read -r c
case "$c" in
1) prompt_subscription; rc=$?; [ "$rc" = 2 ] && continue; refresh_subscription_share; LUN_MENU_ACTION=menu; ui_pause; continue ;;
2) prompt_subscription_ip_mode; rc=$?; [ "$rc" = 2 ] && continue; refresh_subscription_share; LUN_MENU_ACTION=menu; ui_pause; continue ;;
3) refresh_subscription_share; LUN_MENU_ACTION=menu; ui_pause; continue ;;
0|"") LUN_MENU_ACTION=menu; return ;;
*) echo "输入错误。" ;;
esac
done
}

prompt_warp(){
echo "WARP 出站："
echo " 1. 关闭 WARP，服务器出站直连 VPS（默认）"
echo " 2. 全部代理出站走 WARP"
echo " 3. Sing-box 节点走 WARP，Xray 直连"
echo " 4. Xray 节点走 WARP，Sing-box 直连"
echo " 5. 手动输入高级 warp 值（sx/xs/s/x/s4/s6/x4/x6 等）"
echo " 0. 返回上一步"
printf "请选择 [0-5]，回车默认 1："
IFS= read -r val
[ "$val" = "0" ] && return 2
case "$val" in
""|1)
warp=
wap=
export warp
echo "出站已设置为直连 VPS。"
;;
2) warp=sx; wap=yes; export warp ;;
3) warp=s; wap=yes; export warp ;;
4) warp=x; wap=yes; export warp ;;
5)
printf "请输入高级 warp 值，0 返回："
IFS= read -r val
[ "$val" = "0" ] && return 2
case "$val" in
sx|xs|s|x|s4|s6|x4|x6|s4x4|x4s4|s4x6|x6s4|s6x4|x4s6|s6x6|x6s6|sx4|x4s|sx6|x6s|xs4|s4x|xs6|s6x)
warp="$val"; wap=yes; export warp
;;
*) echo "warp 参数不支持，请重新输入。"; prompt_warp; return $? ;;
esac
;;
*) echo "warp 参数不支持，请重新输入。"; prompt_warp; return $? ;;
esac
}

# ============ CDN 优选 IP 交互配置 ============
# 这是 lun 菜单 "入口网络管理 → CDN" 的交互入口
#
# 两个核心变量通俗解释：
#   cdnym（回源域名）：你自己的域名，必须已解析到 VPS IP。
#     作用：Cloudflare 拿到客户端请求后，通过这个域名找到你的服务器并回源。
#     举例：proxy.example.com 的 A 记录指向你的 VPS IP
#
#   cfip（优选地址）：客户端实际连接的 Cloudflare 入口地址，填 IP 或域名。
#     作用：客户端不直连 VPS，而是先连到 Cloudflare 的这个入口，再由 CF 中转。
#     举例：cloudflare-ech.com、www.visa.com.sg、162.159.192.1
#
# 数据流向：客户端 → cfip（CF入口）→ cdnym（你的域名）→ VPS服务
# 效果：隐藏 VPS 真实 IP，通过 CDN 中转提升连接稳定性和速度
# 限制：只有 VMess WS、VLESS WS、VLESS XHTTP（非Reality）支持，端口须在 CF 橙云端口列表内
prompt_cdn(){
echo "========== CDN 优选 IP 加速配置 =========="
echo "cdnym（回源域名）：你自己的域名，须已解析到 VPS IP，CF 通过它找到你的服务器"
echo "cfip（优选地址）：客户端实际连接的 CF 入口，填 IP 或域名，如 cloudflare-ech.com"
echo "数据流向：客户端 → cfip(CF入口) → cdnym(你的域名) → VPS服务"
echo "效果：隐藏 VPS 真实 IP，通过 Cloudflare CDN 中转，提升连接稳定性"
echo "要求：协议端口必须在 CF 橙云支持端口列表内（见下方提示）"
echo "=========================================="
show_cdn_port_advice
cur_host=$(cat "$HOME/lun/cdnym" 2>/dev/null)
printf "是否生成/保留 CDN 节点？[y/N]，del 清除，0 返回%s：" "${cur_host:+，当前 Host=$cur_host}"
IFS= read -r enable_cdn
case "$enable_cdn" in
0) return 2 ;;
del|none|n|N)
rm -f "$HOME/lun/cdnym" "$HOME/lun/cdnip1" "$HOME/lun/cdnip2"
cdnym=
cfip=
echo "CDN 节点配置已清除。"
return 0
;;
"" )
[ -n "$cur_host" ] || return 0
cdnym="$cur_host"
;;
y|Y) ;;
*) echo "输入错误，请输入 y、n、del 或 0。"; prompt_cdn; return $? ;;
esac
# ---- 第一步：设置回源 Host 域名 ----
# 这个域名必须已解析到 VPS IP，Cloudflare 通过它回源到你的服务器
while :; do
default_host="${cdnym:-${domain:-$cur_host}}"
printf "请输入 CDN 回源 Host 域名%s，0 返回：" "${default_host:+，回车使用 $default_host}"
IFS= read -r val
[ "$val" = "0" ] && return 2
[ -z "$val" ] && val="$default_host"
[ -z "$val" ] && { echo "启用 CDN 需要一个回源 Host 域名（已解析到 VPS 的域名）。"; continue; }
if valid_domain "$val"; then
cdnym="$val"
printf "%s\n" "$cdnym" > "$HOME/lun/cdnym"
break
fi
echo "Host 域名格式不正确，请填写 example.com，不要带协议、端口或路径。"
done
# ---- 第二步：设置 CDN 优选地址 ----
# 优选地址是客户端实际连接的 Cloudflare 入口
# 推荐使用稳定域名：cloudflare-ech.com、www.visa.com.sg、www.wto.org
# 也可填 CF 优选 IP，如 162.159.192.1
while :; do
printf "Cloudflare 优选 cfip，可填一到两个 IP/域名（空格分隔）\n"
printf "推荐：cloudflare-ech.com www.visa.com.sg\n"
printf "回车使用默认优选域名，del 清除，0 返回："
IFS= read -r val
[ "$val" = "0" ] && return 2
if [ "$val" = "del" ] || [ "$val" = "none" ]; then
cfip=
rm -f "$HOME/lun/cdnip1" "$HOME/lun/cdnip2"
break
fi
[ -z "$val" ] && break
bad=
for one in $val; do
case "$one" in -1) bad=yes ;; *) valid_addym "$one" || bad=yes ;; esac
done
[ -z "$bad" ] && break
echo "cfip 只接受 IP 或域名，多个值用空格分隔。"
done
# ---- 第三步：写入优选地址到配置文件 ----
[ -n "$val" ] && cfip="$val"
if [ -n "$cfip" ]; then
set -- $cfip
cdnip1="$1"
cdnip2="$2"
[ -n "$cdnip1" ] && printf "%s\n" "$cdnip1" > "$HOME/lun/cdnip1" || rm -f "$HOME/lun/cdnip1"
[ -n "$cdnip2" ] && printf "%s\n" "$cdnip2" > "$HOME/lun/cdnip2" || rm -f "$HOME/lun/cdnip2"
elif [ -n "$cdnym" ] && [ ! -s "$HOME/lun/cdnip1" ]; then
# 未设置优选地址但有回源 Host：写入默认优选域名
printf "%s\n" "cloudflare-ech.com" > "$HOME/lun/cdnip1"
printf "%s\n" "www.visa.com.sg" > "$HOME/lun/cdnip2"
fi
export cdnym cfip
}

configure_addym_menu(){
while :; do
echo "自定义普通节点客户端地址 addym"
echo "说明：只改普通节点 address/server/add，不改 Reality SNI、WS/XHTTP Host、Argo 地址。"
printf "请输入域名或 IP；输入 del 清除；回车保留当前值；0 返回："
IFS= read -r menu_addym
[ "$menu_addym" = "0" ] && return 2
if [ "$menu_addym" = "del" ] || [ "$menu_addym" = "none" ]; then
addym=del
addout=off
load_addym_config
echo "addym 已清除。"
continue
fi
if [ -n "$menu_addym" ] && ! valid_addym "$menu_addym"; then
echo "addym 格式不正确，不要带协议、端口或路径。"
continue
fi
[ -n "$menu_addym" ] && addym="$menu_addym"
echo "输出模式：1. off  2. replace  3. both"
printf "请选择，回车默认 replace，0 返回："
IFS= read -r menu_addout
[ "$menu_addout" = "0" ] && return 2
case "$menu_addout" in
1) addout=off ;;
2) [ -n "$addym" ] && addout=replace ;;
3) addout=both ;;
*) [ -n "$addym" ] && addout=replace ;;
esac
load_addym_config
echo "addym/addout 设置已保存。"
return 0
done
}

protocol_label(){
case "$1" in
1) echo "VLESS TCP Reality" ;;
2) echo "VLESS XHTTP Reality" ;;
3) echo "VLESS XHTTP" ;;
4) echo "VLESS WS" ;;
5) echo "Shadowsocks-2022" ;;
6) echo "AnyTLS" ;;
7) echo "Any-Reality" ;;
8) echo "VMess WS" ;;
9) echo "Socks5" ;;
10) echo "Hysteria2" ;;
11) echo "TUIC" ;;
esac
}

protocol_note(){
case "$1" in
3) echo "（支持后续CF优选CDN）" ;;
4) echo "（支持后续Argo隧道/CF优选CDN）" ;;
8) echo "（支持后续Argo隧道/CF优选CDN）" ;;
*) echo "" ;;
esac
}

protocol_var(){
case "$1" in
1) echo vlpt ;;
2) echo xhpt ;;
3) echo vxpt ;;
4) echo vwpt ;;
5) echo sspt ;;
6) echo anpt ;;
7) echo arpt ;;
8) echo vmpt ;;
9) echo sopt ;;
10) echo hypt ;;
11) echo tupt ;;
esac
}

protocol_current_port(){
var=$(protocol_var "$1")
[ -n "$var" ] || return
eval "printf '%s\n' \"\${$var-}\""
}

clear_protocol_pick(){
case "$1" in
1) unset vlpt vlp port_vl_re ;;
2) unset xhpt xhp port_xh ;;
3) unset vxpt vxp port_vx ;;
4) unset vwpt vwp port_vw vmag ;;
5) unset sspt ssp port_ss ;;
6) unset anpt anp port_an ;;
7) unset arpt arp port_ar ;;
8) unset vmpt vmp port_vm_ws vmag ;;
9) unset sopt sop port_so ;;
10) unset hypt hyp port_hy2 ;;
11) unset tupt tup port_tu ;;
esac
}

clear_all_protocol_picks(){
for id in 1 2 3 4 5 6 7 8 9 10 11; do
clear_protocol_pick "$id"
done
}

protocol_count(){
count=0
for id in 1 2 3 4 5 6 7 8 9 10 11; do
[ -n "$(protocol_current_port "$id")" ] && count=$((count + 1))
done
printf '%s\n' "$count"
}

show_protocol_picker(){
echo "当前协议选择："
for id in 1 2 3 4 5 6 7 8 9 10 11; do
label=$(protocol_label "$id")
note=$(protocol_note "$id")
port=$(protocol_current_port "$id")
if [ -n "$port" ]; then
if is_nat_mode; then
printf "%2s. %-38s 已选，内网端口：%s" "$id" "$label$note" "$port"
public=$(client_port "$port")
[ "$public" != "$port" ] && printf "，公网端口：%s" "$public"
else
printf "%2s. %-38s 已选，端口：%s" "$id" "$label$note" "$port"
fi
printf "\n"
else
printf "%2s. %-38s 未选择\n" "$id" "$label$note"
fi
done
}

prompt_protocol_by_id(){
id=$1
label=$(protocol_label "$id")
var=$(protocol_var "$id")
[ -n "$label" ] && [ -n "$var" ] || { echo "忽略未知协议编号：$id"; return 0; }
prompt_port "$label" "$var"
}

pick_protocols(){
load_installed_protocol_flags
while :; do
refresh_protocol_flags
show_protocol_picker
echo "操作：输入编号新增/修改端口，例如 1 4 8；输入 d 删除协议；输入 c 清空重选；回车保留当前并继续；0 返回"
printf "请选择："
IFS= read -r picks
case "$picks" in
0) return 2 ;;
""|k|K)
[ "$(protocol_count)" -gt 0 ] && { refresh_protocol_flags; return 0; }
echo "请至少选择一个协议。"
continue
;;
d|D)
printf "请输入要删除的协议编号，多个用空格分隔，0 返回："
IFS= read -r dels
[ "$dels" = "0" ] && continue
for id in $dels; do
clear_protocol_pick "$id"
done
refresh_protocol_flags
continue
;;
c|C)
clear_all_protocol_picks
refresh_protocol_flags
echo "已清空协议选择，请重新新增。"
continue
;;
esac
for id in $picks; do
prompt_protocol_by_id "$id"
rc=$?
[ "$rc" = 2 ] && break
[ "$rc" = 0 ] || return 1
done
refresh_protocol_flags
done
}

guided_protocol_summary(){
shown=
for item in \
"VLESS TCP Reality:$port_vl_re" \
"VLESS XHTTP Reality:$port_xh" \
"VLESS XHTTP:$port_vx" \
"VLESS WS:$port_vw" \
"Shadowsocks-2022:$port_ss" \
"AnyTLS:$port_an" \
"Any-Reality:$port_ar" \
"VMess WS:$port_vm_ws" \
"Socks5:$port_so" \
"Hysteria2:$port_hy2" \
"TUIC:$port_tu"; do
label=${item%%:*}
port=${item#*:}
[ -n "$port" ] || continue
shown=yes
if is_nat_mode; then
public=$(client_port "$port")
[ "$public" != "$port" ] && echo "  $label：内网 $port / 公网 $public" || echo "  $label：内网 $port"
else
echo "  $label：$port"
fi
done
[ -n "$shown" ] || echo "  未选择"
}

guided_summary(){
ui_dash
echo "当前引导配置："
if is_nat_mode; then
echo "VPS类型：NAT VPS"
else
echo "VPS类型：普通 VPS"
fi
echo "协议端口："
guided_protocol_summary
echo "服务域名：${domain:-未设置}"
echo "证书模式：${certmode:-self}"
if [ -n "$sub" ]; then
if is_nat_mode; then
echo "节点订阅分享：启用  token=${subid:-UUID}  内网端口=${subpt:-随机}  IP模式=${subipmode:-ipv4}"
else
echo "节点订阅分享：启用  token=${subid:-UUID}  端口=${subpt:-随机}  IP模式=${subipmode:-ipv4}"
fi
else
echo "节点订阅分享：未启用"
fi
if is_nat_mode; then
[ -n "$ptmap" ] && echo "NAT端口映射：$ptmap" || echo "NAT端口映射：无"
[ -n "$inpool" ] && echo "内网端口池：$inpool" || { [ -n "$portpool" ] && echo "内网端口池：$portpool" || echo "内网端口池：未设置"; }
[ -n "$outpool" ] && echo "外网端口池：$outpool" || echo "外网端口池：未设置"
[ -n "$inpool" ] && [ -n "$outpool" ] && echo "NAT自动映射：外网端口池按顺序对应内网端口池"
else
[ -n "$inpool" ] && echo "端口池：$inpool" || { [ -n "$portpool" ] && echo "端口池：$portpool" || echo "端口池：未设置"; }
fi
if [ -n "$addym" ]; then
echo "普通节点地址：$addym  输出=${addout:-replace}"
elif [ -n "$domain" ]; then
echo "普通节点地址：将默认使用服务域名 $domain"
else
echo "普通节点地址：服务器 IP"
fi
ui_dash
}

prompt_vps_mode(){
while :; do
echo "VPS 类型："
echo " 1. 普通 VPS（默认，端口即客户端访问端口）"
echo " 2. NAT VPS（需要公网端口映射到内网监听端口）"
echo " 0. 返回"
printf "请选择 [0-2]，当前 ${vpsmode:-normal}："
IFS= read -r val
case "$val" in
0) return 2 ;;
""|1)
vpsmode=normal
printf "%s\n" "$vpsmode" > "$HOME/lun/vps_mode"
echo "已设置为普通 VPS。"
return 0
;;
2)
vpsmode=nat
printf "%s\n" "$vpsmode" > "$HOME/lun/vps_mode"
echo "已设置为 NAT VPS。"
return 0
;;
*) echo "请输入 1、2 或 0。" ;;
esac
done
}

prompt_port_map(){
while :; do
echo "NAT VPS 端口映射只改客户端节点/订阅端口，不写 iptables。"
echo "格式：外网端口-内网监听端口，多个用空格分隔，例如：54834-2096 54835-8443"
printf "请输入映射；del 清除；回车保留/跳过；0 返回%s：" "${ptmap:+，当前 $ptmap}"
IFS= read -r val
[ "$val" = "0" ] && return 2
case "$val" in
"") return 0 ;;
del|none|off)
rm -f "$HOME/lun/port_map"
ptmap=
echo "NAT 端口映射已清除。"
return 0
;;
esac
normalized=$(normalize_ptmap "$val") || { echo "映射格式错误，请使用 外网端口-内网端口，例如：54834-2096"; continue; }
ptmap="$normalized"
vpsmode=nat
printf "%s\n" "$vpsmode" > "$HOME/lun/vps_mode"
printf "%s\n" "$ptmap" > "$HOME/lun/port_map"
echo "NAT 端口映射已保存：$ptmap"
return 0
done
}

prompt_port_pool(){
while :; do
echo "端口池用于协议端口和节点订阅分享端口随机取值。"
if is_nat_mode; then
echo "内网端口池：服务实际监听端口，例如 8080 1000+2000。"
echo "外网端口池：NAT 公网入口端口，例如 53273 49096+49100。按位置自动映射到内网池。"
echo "旧格式仍兼容：portpool=\"54834-2096 49096-1003\" 会自动补充手动 NAT 映射。"
printf "请输入内网端口池；del 清除；回车保留/跳过；0 返回%s：" "${inpool:+，当前 $inpool}"
else
echo "普通 VPS 只需要一个端口池，随机端口会直接作为客户端端口。"
printf "请输入端口池；del 清除；回车保留/跳过；0 返回%s：" "${inpool:+，当前 $inpool}"
fi
IFS= read -r val
[ "$val" = "0" ] && return 2
case "$val" in
"") ;;
del|none|off)
rm -f "$HOME/lun/inner_port_pool" "$HOME/lun/port_pool"
inpool=
portpool=
echo "内网端口池已清除。"
;;
*)
normalized=$(normalize_plain_portpool "$val") || { echo "内网端口池格式错误，请使用端口或范围 1000+2000。"; continue; }
inpool="$normalized"
portpool=
printf "%s\n" "$inpool" > "$HOME/lun/inner_port_pool"
rm -f "$HOME/lun/port_pool"
;;
esac
if ! is_nat_mode; then
load_port_pool_config
echo "端口池：${inpool:-未设置}"
return 0
fi
printf "请输入外网端口池；del 清除；回车保留/跳过；0 返回%s：" "${outpool:+，当前 $outpool}"
IFS= read -r val
[ "$val" = "0" ] && return 2
case "$val" in
"") ;;
del|none|off)
rm -f "$HOME/lun/outer_port_pool"
outpool=
echo "外网端口池已清除。"
;;
*)
normalized=$(normalize_plain_portpool "$val") || { echo "外网端口池格式错误，请使用端口或范围 49096+49100。"; continue; }
outpool="$normalized"
printf "%s\n" "$outpool" > "$HOME/lun/outer_port_pool"
;;
esac
load_port_pool_config
echo "内网端口池：${inpool:-未设置}"
echo "外网端口池：${outpool:-未设置}"
[ -n "$inpool" ] && [ -n "$outpool" ] && echo "提示：内外端口池会按顺序自动映射，例如第一个外网端口对应第一个内网端口。"
[ -n "$ptmap" ] && echo "手动 NAT 映射：$ptmap"
return 0
done
}

prompt_nat_vps(){
while :; do
if [ -n "$ptmap" ]; then
printf "是否为 NAT VPS？[Y/n]，当前手动映射：%s；输入 del 清除，0 返回：" "$ptmap"
elif [ -n "$inpool" ] && [ -n "$outpool" ]; then
printf "已设置内外端口池，将自动按位置映射。是否还要添加手动 NAT 映射？[y/N]，0 返回："
else
printf "是否为 NAT VPS，需要公网端口-内网端口映射？[y/N]，0 返回："
fi
IFS= read -r val
case "$val" in
0) return 2 ;;
del|none|off)
rm -f "$HOME/lun/port_map"
ptmap=
echo "NAT 端口映射已清除。"
return 0
;;
y|Y)
prompt_port_map
return $?
;;
n|N)
rm -f "$HOME/lun/port_map"
ptmap=
vpsmode=normal
printf "%s\n" "$vpsmode" > "$HOME/lun/vps_mode"
echo "按非 NAT VPS 处理。"
return 0
;;
"")
[ -n "$ptmap" ] && return 0
[ -n "$inpool" ] && [ -n "$outpool" ] && return 0
return 0
;;
*) echo "请输入 y、n、del 或 0。" ;;
esac
done
}

confirm_guided_install(){
while :; do
guided_summary
printf "确认开始安装/重建？回车确认，n 取消，0 返回上一步："
IFS= read -r val
case "$val" in
0) return 2 ;;
n|N) return 1 ;;
""|y|Y) return 0 ;;
*) echo "请输入回车、y、n 或 0。" ;;
esac
done
}

guided_install(){
load_installed_protocol_flags
step=1
while :; do
case "$step" in
1)
guided_summary
prompt_vps_mode
rc=$?
[ "$rc" = 0 ] && step=2 && continue
[ "$rc" = 2 ] && return 1
;;
2)
guided_summary
prompt_port_pool
rc=$?
[ "$rc" = 0 ] && step=3 && continue
[ "$rc" = 2 ] && step=1 && continue
;;
3)
guided_summary
pick_protocols
rc=$?
[ "$rc" = 0 ] && step=4 && continue
[ "$rc" = 2 ] && step=2 && continue
;;
4)
guided_summary
prompt_service_domain
rc=$?
[ "$rc" = 0 ] && { [ -n "$domain" ] && [ -z "$addym" ] && { addym="$domain"; addout=replace; load_addym_config; }; step=5; continue; }
[ "$rc" = 2 ] && step=3 && continue
;;
5)
guided_summary
prompt_cert_mode
rc=$?
[ "$rc" = 0 ] && step=6 && continue
[ "$rc" = 2 ] && step=4 && continue
;;
6)
guided_summary
prompt_subscription
rc=$?
[ "$rc" = 0 ] && step=7 && continue
[ "$rc" = 2 ] && step=5 && continue
;;
7)
confirm_guided_install
rc=$?
[ "$rc" = 0 ] && break
[ "$rc" = 2 ] && step=6 && continue
return 1
;;
esac
done
refresh_protocol_flags
}

certificate_menu(){
while :; do
ui_title "Lun 证书管理"
show_cert_summary
echo " 1. 恢复/重建自签证书"
echo " 2. 申请 Let’s Encrypt 域名证书（HTTP-01）"
echo " 3. 申请 Let’s Encrypt DNS API 证书"
echo " 4. 申请 Let’s Encrypt IP 证书（short-lived）"
echo " 5. 手动续期当前 ACME 证书"
echo " 6. 清除 DNS API 凭据"
echo " 0. 返回"
printf "请输入数字 [0-6]："
IFS= read -r c
case "$c" in
1) self_signed_cert && echo "已恢复自签证书。" || echo "自签证书生成失败。"; LUN_MENU_ACTION=list; ui_pause; return ;;
2)
prompt_service_domain; rc=$?
[ "$rc" = 2 ] && continue
[ -n "$domain" ] || { echo "当前没有服务域名，不能申请域名证书。"; continue; }
if reuse_local_cert_interactive; then echo "已复用本机证书，跳过申请。"; LUN_MENU_ACTION=list; ui_pause; return; fi
prompt_acme_email; rc=$?
[ "$rc" = 2 ] && continue
certmode=domain
printf "%s\n" "$certmode" > "$HOME/lun/cert_mode"
issue_acme_cert domain "$domain" && echo "域名证书申请完成。" || { echo "域名证书申请失败，已恢复自签。"; self_signed_cert; }
LUN_MENU_ACTION=list; ui_pause; return
;;
3)
prompt_service_domain; rc=$?
[ "$rc" = 2 ] && continue
[ -n "$domain" ] || { echo "当前没有服务域名，不能申请 DNS API 证书。"; continue; }
if reuse_local_cert_interactive; then echo "已复用本机证书，跳过申请。"; LUN_MENU_ACTION=list; ui_pause; return; fi
prompt_acme_email; rc=$?
[ "$rc" = 2 ] && continue
save_dns_env_interactive; rc=$?
[ "$rc" = 2 ] && continue
[ "$rc" = 0 ] || continue
certmode=dns
printf "%s\n" "$certmode" > "$HOME/lun/cert_mode"
issue_acme_cert dns "$domain" && echo "DNS API 证书申请完成。" || { echo "DNS API 证书申请失败，已恢复自签。"; self_signed_cert; }
LUN_MENU_ACTION=list; ui_pause; return
;;
4)
if reuse_local_cert_interactive; then echo "已复用本机证书，跳过申请。"; LUN_MENU_ACTION=list; ui_pause; return; fi
prompt_acme_email; rc=$?
[ "$rc" = 2 ] && continue
certmode=ip
printf "%s\n" "$certmode" > "$HOME/lun/cert_mode"
subject=$(local_public_ips | sed -n 1p)
issue_acme_cert ip "$subject" && echo "IP 证书申请完成。" || { echo "IP 证书申请失败，已恢复自签。"; self_signed_cert; }
LUN_MENU_ACTION=list; ui_pause; return
;;
5) subject=$(cat "$HOME/lun/cert_subject" 2>/dev/null); if [ -n "$subject" ] && [ -x "$HOME/.acme.sh/acme.sh" ]; then "$HOME/.acme.sh/acme.sh" --renew -d "$subject" --ecc --force && install_acme_cert "$subject" "$(cat "$HOME/lun/cert_mode" 2>/dev/null)" && echo "续期完成。"; else echo "当前没有可续期的 ACME 证书。"; fi; LUN_MENU_ACTION=list; ui_pause; return ;;
6) rm -f "$HOME/lun/cert.env" "$HOME/lun/acme_dns"; echo "DNS API 凭据已清除。"; ui_pause ;;
0|"") LUN_MENU_ACTION=menu; return ;;
*) echo "输入错误。" ;;
esac
done
}

config_menu(){
while :; do
ui_title "Lun 变更配置"
echo " 1. 修改 UUID"
echo " 2. 设置服务域名"
echo " 3. 管理证书"
echo " 4. 设置 Argo 隧道"
echo " 5. 设置 IP 输出优先级"
echo " 6. 设置 WARP 出站"
echo " 7. 节点订阅分享"
echo " 8. 设置 CDN Host / cfip"
echo " 9. 设置 addym/addout"
echo " 0. 返回"
printf "请选择 [0-9]："
IFS= read -r c
case "$c" in
1) printf "请输入新 UUID，回车随机生成："; IFS= read -r uuid; [ -z "$uuid" ] && uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$HOME/lun/xray" uuid 2>/dev/null || "$HOME/lun/sing-box" generate uuid); echo "$uuid" > "$HOME/lun/uuid"; echo "UUID 已更新：$uuid"; LUN_MENU_ACTION=list; return ;;
2) prompt_service_domain; rc=$?; [ "$rc" = 2 ] && continue; load_domain_cert_config; LUN_MENU_ACTION=list; return ;;
3) certificate_menu; return ;;
4) prompt_argo; rc=$?; [ "$rc" = 2 ] && continue; [ "$rc" = 0 ] || continue; load_installed_protocol_flags; LUN_MENU_ACTION=rep; return ;;
5) printf "输入 4 或 6，回车自动，0 返回："; IFS= read -r ippz; [ "$ippz" = 0 ] && continue; export ippz; LUN_MENU_ACTION=list; return ;;
6) prompt_warp; rc=$?; [ "$rc" = 2 ] && continue; load_installed_protocol_flags; LUN_MENU_ACTION=rep; return ;;
7) subscription_menu; return ;;
8) prompt_cdn; rc=$?; [ "$rc" = 2 ] && continue; LUN_MENU_ACTION=list; return ;;
9) configure_addym_menu; rc=$?; [ "$rc" = 2 ] && continue; LUN_MENU_ACTION=list; return ;;
0|"") LUN_MENU_ACTION=menu; return ;;
*) echo "输入错误。" ;;
esac
done
}

port_menu(){
while :; do
ui_title "Lun 端口管理"
echo "1. 修改协议端口并重建协议"
echo "2. NAT VPS 端口映射（只改客户端节点/订阅端口）"
echo "3. 内网/外网端口池（协议和节点订阅分享随机端口来源）"
echo "4. 节点订阅分享"
echo "0. 返回主菜单"
printf "请选择 [0-4]："
IFS= read -r c
case "$c" in
1)
echo "重新选择协议和端口后会执行 rep，重建当前协议组合。"
pick_protocols
rc=$?
[ "$rc" = 0 ] && LUN_MENU_ACTION=rep || LUN_MENU_ACTION=menu
return
;;
2)
prompt_port_map
rc=$?
[ "$rc" = 2 ] && continue
LUN_MENU_ACTION=list
return
;;
3)
prompt_port_pool
rc=$?
[ "$rc" = 2 ] && continue
LUN_MENU_ACTION=menu
return
;;
4)
prompt_subscription
rc=$?
[ "$rc" = 2 ] && continue
load_installed_protocol_flags
LUN_MENU_ACTION=rep
return
;;
0|"") LUN_MENU_ACTION=menu; return ;;
*) echo "输入错误。" ;;
esac
done
}

log_menu(){
ui_title "Lun 运行日志"
echo "Xray 进程："
pgrep -af 'lun/x|xray' 2>/dev/null || true
echo
echo "Sing-box 进程："
pgrep -af 'lun/s|sing-box' 2>/dev/null || true
echo
echo "Argo 日志："
tail -40 "$HOME/lun/argo.log" 2>/dev/null || echo "无 Argo 日志"
ui_pause
}

stop_lun_services(){
stop_lun_owned_processes
if pidof systemd >/dev/null 2>&1; then
systemctl stop xr sb argo >/dev/null 2>&1 || true
elif command -v rc-service >/dev/null 2>&1; then
rc-service xray stop >/dev/null 2>&1 || true
rc-service sing-box stop >/dev/null 2>&1 || true
rc-service argo stop >/dev/null 2>&1 || true
fi
}

install_protocol_menu(){
while :; do
ui_title "Lun 安装 / 协议管理"
echo " 1. 引导式安装 / 新建协议"
echo " 2. 增删改协议并重建"
echo " 3. 刷新并查看节点"
echo " 0. 返回"
printf "请选择 [0-3]："
IFS= read -r c
case "$c" in
1) guided_install; rc=$?; [ "$rc" = 0 ] && { [ -f "$HOME/lun/uuid" ] && LUN_MENU_ACTION=rep || LUN_MENU_ACTION=install; return; } ;;
2) pick_protocols; rc=$?; [ "$rc" = 0 ] && LUN_MENU_ACTION=rep || LUN_MENU_ACTION=menu; return ;;
3) LUN_MENU_ACTION=list; return ;;
0|"") LUN_MENU_ACTION=menu; return ;;
*) echo "输入错误。" ;;
esac
done
}

network_menu(){
while :; do
ui_title "Lun 入口网络管理"
if is_nat_mode; then
echo "当前 VPS 类型：NAT VPS"
[ -n "$inpool" ] && echo "内网端口池：$inpool"
[ -n "$outpool" ] && echo "外网端口池：$outpool"
[ -n "$ptmap" ] && echo "手动映射：$ptmap"
else
echo "当前 VPS 类型：普通 VPS"
[ -n "$inpool" ] && echo "端口池：$inpool"
fi
show_cdn_summary
[ -s "$HOME/lun/argoip" ] && echo "Argo优选：$(cat "$HOME/lun/argoip")" || echo "Argo优选：中性默认"
echo " 1. VPS 类型"
echo " 2. 端口池"
echo " 3. NAT 手动映射"
echo " 4. CDN / 优选 IP"
echo " 5. CF 隧道 / Argo"
echo " 6. Argo 优选 IP / 入口地址"
echo " 0. 返回"
printf "请选择 [0-6]："
IFS= read -r c
case "$c" in
1) prompt_vps_mode; rc=$?; [ "$rc" = 2 ] && continue ;;
2) prompt_port_pool; rc=$?; [ "$rc" = 2 ] && continue ;;
3) vpsmode=nat; printf "%s\n" "$vpsmode" > "$HOME/lun/vps_mode"; prompt_port_map; rc=$?; [ "$rc" = 2 ] && continue; LUN_MENU_ACTION=list; return ;;
4) prompt_cdn; rc=$?; [ "$rc" = 2 ] && continue; LUN_MENU_ACTION=list; return ;;
5) prompt_argo; rc=$?; [ "$rc" = 2 ] && continue; [ "$rc" = 0 ] || continue; load_installed_protocol_flags; LUN_MENU_ACTION=rep; return ;;
6) prompt_argo_ip; rc=$?; [ "$rc" = 2 ] && continue; LUN_MENU_ACTION=list; return ;;
0|"") LUN_MENU_ACTION=menu; return ;;
*) echo "输入错误。" ;;
esac
done
}

service_update_menu(){
while :; do
ui_title "Lun 服务与更新"
echo " 1. 刷新并查看节点"
echo " 2. 重启服务"
echo " 3. 停止服务"
echo " 4. 查看运行日志"
echo " 5. 更新 Lun 脚本"
echo " 6. 更新 Xray 内核"
echo " 7. 更新 Sing-box 内核"
echo " 0. 返回"
printf "请选择 [0-7]："
IFS= read -r c
case "$c" in
1) LUN_MENU_ACTION=list; return ;;
2) LUN_MENU_ACTION=res; return ;;
3) stop_lun_services; echo "已停止 Lun 服务。"; exit ;;
4) log_menu ;;
5) update_lun_script; exit ;;
6) LUN_MENU_ACTION=upx; return ;;
7) LUN_MENU_ACTION=ups; return ;;
0|"") LUN_MENU_ACTION=menu; return ;;
*) echo "输入错误。" ;;
esac
done
}

advanced_menu(){
while :; do
ui_title "Lun 高级设置"
echo " 1. 设置服务域名"
echo " 2. 管理证书"
echo " 3. WARP 出站"
echo " 4. addym/addout"
echo " 5. IP 输出优先级"
echo " 6. 修改 UUID"
echo " 7. 卸载 Lun"
echo " 0. 返回"
printf "请选择 [0-7]："
IFS= read -r c
case "$c" in
1) prompt_service_domain; rc=$?; [ "$rc" = 2 ] && continue; load_domain_cert_config; LUN_MENU_ACTION=list; return ;;
2) certificate_menu; [ "$LUN_MENU_ACTION" = "menu" ] && continue; return ;;
3) prompt_warp; rc=$?; [ "$rc" = 2 ] && continue; load_installed_protocol_flags; LUN_MENU_ACTION=rep; return ;;
4) configure_addym_menu; rc=$?; [ "$rc" = 2 ] && continue; LUN_MENU_ACTION=list; return ;;
5) printf "输入 4 或 6，回车自动，0 返回："; IFS= read -r ippz; [ "$ippz" = 0 ] && continue; export ippz; LUN_MENU_ACTION=list; return ;;
6) printf "请输入新 UUID，回车随机生成："; IFS= read -r uuid; [ -z "$uuid" ] && uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$HOME/lun/xray" uuid 2>/dev/null || "$HOME/lun/sing-box" generate uuid); echo "$uuid" > "$HOME/lun/uuid"; echo "UUID 已更新：$uuid"; LUN_MENU_ACTION=list; return ;;
7) LUN_MENU_ACTION=del; return ;;
0|"") LUN_MENU_ACTION=menu; return ;;
*) echo "输入错误。" ;;
esac
done
}

lun_menu(){
while :; do
lun_dashboard
echo " 1. 安装 / 协议管理"
printf " 2. %s节点订阅分享%s\n" "$LUN_GREEN" "$LUN_RESET"
echo " 3. 入口网络管理"
echo " 4. 服务与更新"
echo " 5. 高级设置"
echo " 0. 退出"
ui_line
printf "请输入数字【0-5】："
IFS= read -r menu_choice
case "$menu_choice" in
1) install_protocol_menu; [ "$LUN_MENU_ACTION" = "menu" ] && continue; break ;;
2) subscription_menu; [ "$LUN_MENU_ACTION" = "menu" ] && continue; break ;;
3) network_menu; [ "$LUN_MENU_ACTION" = "menu" ] && continue; break ;;
4) service_update_menu; [ "$LUN_MENU_ACTION" = "menu" ] && continue; break ;;
5) advanced_menu; [ "$LUN_MENU_ACTION" = "menu" ] && continue; break ;;
0|"") exit ;;
*) echo "输入错误，请重新选择。"; sleep 1 ;;
esac
done
}

if [ "$LUN_MENU_REQUEST" = yes ]; then
lun_menu
case "$LUN_MENU_ACTION" in
install) set -- ;;
rep) set -- rep ;;
list) set -- list ;;
res) set -- res ;;
upx) set -- upx ;;
ups) set -- ups ;;
del) set -- del ;;
*) exit ;;
esac
fi

if [ "$1" = "del" ]; then
cleandel
rm -rf sbx_update "$HOME/lun" "$HOME/weblun" "$HOME/agsbx" "$HOME/websbx"
echo "卸载完成"
echo "Lun 已卸载完成，欢迎下次使用。" && sleep 2
echo
showmode
exit
elif [ "$1" = "rep" ]; then
cleandel keep-entry
ensure_lun_command || true
rm -rf "$HOME/lun"/{sb.json,xr.json,sbargoym.log,sbargotoken.log,argo.log,argoport.log,name}
rm -f "$HOME/lun"/port_vl_re "$HOME/lun"/port_xh "$HOME/lun"/port_vx "$HOME/lun"/port_vw "$HOME/lun"/port_ss "$HOME/lun"/port_an "$HOME/lun"/port_ar "$HOME/lun"/port_vm_ws "$HOME/lun"/port_so "$HOME/lun"/port_hy2 "$HOME/lun"/port_tu
echo "Lun重置协议完成，开始更新相关协议变量……" && sleep 2
echo
elif [ "$1" = "list" ]; then
cip
exit
elif [ "$1" = "upx" ]; then
for P in /proc/[0-9]*; do [ -L "$P/exe" ] || continue; TARGET=$(readlink -f "$P/exe" 2>/dev/null) || continue; case "$TARGET" in *"/lun/x"*) kill "$(basename "$P")" 2>/dev/null ;; esac; done
upxray && xrestart && echo "Xray内核更新完成" && sleep 2 && cip
exit
elif [ "$1" = "ups" ]; then
for P in /proc/[0-9]*; do [ -L "$P/exe" ] || continue; TARGET=$(readlink -f "$P/exe" 2>/dev/null) || continue; case "$TARGET" in *"/lun/s"*) kill "$(basename "$P")" 2>/dev/null ;; esac; done
upsingbox && sbrestart && echo "Sing-box内核更新完成" && sleep 2 && cip
exit
elif [ "$1" = "res" ]; then
for P in /proc/[0-9]*; do
[ -L "$P/exe" ] || continue
TARGET=$(readlink -f "$P/exe" 2>/dev/null) || continue
case "$TARGET" in
*"/lun/s"*)
kill "$(basename "$P")" 2>/dev/null
sbrestart
;;
*"/lun/x"*)
kill "$(basename "$P")" 2>/dev/null
xrestart
;;
*"/lun/c"*)
kill "$(basename "$P")" 2>/dev/null
if [ -e "$HOME/lun/sbargotoken.log" ]; then
if pidof systemd >/dev/null 2>&1; then
systemctl restart argo >/dev/null 2>&1
elif command -v rc-service >/dev/null 2>&1; then
rc-service argo restart >/dev/null 2>&1
else
nohup $HOME/lun/cloudflared tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token $(cat $HOME/lun/sbargotoken.log 2>/dev/null) >/dev/null 2>&1 &
fi
else
nohup $HOME/lun/cloudflared tunnel --url http://localhost:$(cat $HOME/lun/argoport.log 2>/dev/null) --edge-ip-version auto --no-autoupdate --protocol http2 > $HOME/lun/argo.log 2>&1 &
fi
;;
esac
done
sleep 5 && echo "重启完成" && sleep 3 && cip
exit
fi
if ! find /proc/*/exe -type l 2>/dev/null | grep -E '/proc/[0-9]+/exe' | xargs -r readlink 2>/dev/null | grep -Eq 'lun/(s|x)'; then
stop_lun_owned_processes
if [ -z "$( (command -v curl >/dev/null 2>&1 && curl -s4m5 -k "$v46url" 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget -4 -qO- --tries=2 "$v46url" 2>/dev/null) )" ]; then
printf "nameserver 1.1.1.1\nnameserver 8.8.8.8\nnameserver 2606:4700:4700::1111\nnameserver 2001:4860:4860::8888\n" > /etc/resolv.conf
fi
if [ -n "$( (command -v curl >/dev/null 2>&1 && curl -s6m5 -k "$v46url" 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget -6 -qO- --tries=2 "$v46url" 2>/dev/null) )" ]; then
sendip="2606:4700:d0::a29f:c001"
xendip="[2606:4700:d0::a29f:c001]"
else
sendip="162.159.192.1"
xendip="162.159.192.1"
fi
echo "VPS系统：$op"
echo "CPU架构：$cpu"
echo "Lun脚本未安装，开始安装…………" && sleep 1
if [ -n "$oap" ]; then
setenforce 0 >/dev/null 2>&1
iptables -P INPUT ACCEPT >/dev/null 2>&1
iptables -P FORWARD ACCEPT >/dev/null 2>&1
iptables -P OUTPUT ACCEPT >/dev/null 2>&1
iptables -F >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
echo
echo "iptables执行开放所有端口"
fi
ins
if [ -n "$sub" ]; then
subtokenipsub(){
if [ -z "$subid" ]; then
subtoken="$(cat "$HOME/lun/uuid")"
else
subtoken="$subid"
fi
rm -rf $HOME/weblun/"$(cat $HOME/lun/subtoken.log 2>/dev/null)"
echo $subtoken > $HOME/lun/subtoken.log
}
subportipsub(){
if [ -z "$subpt" ]; then
if [ -n "$(cat "$HOME/lun/subport.log" 2>/dev/null)" ]; then
subport=$(cat $HOME/lun/subport.log)
else
subport=$(random_port 2>/dev/null || shuf -i 10000-65535 -n 1)
fi
else
subport="$subpt"
fi
mapped_inner=$(inner_port_from_public "$subport")
[ -n "$mapped_inner" ] && subport="$mapped_inner"
if ! port_valid "$subport"; then
echo "订阅端口 $subport 无效，已跳过订阅服务启动。"
return 1
fi
echo $subport > $HOME/lun/subport.log
}
subtokenipsub && subportipsub
echo "请稍后…………"
stop_subscription_service
mkdir -p $HOME/weblun/"$(cat $HOME/lun/subtoken.log 2>/dev/null)"
ln -sf $HOME/lun/clmi.yaml $HOME/weblun/"$(cat $HOME/lun/subtoken.log 2>/dev/null)"/clmi.yaml
ln -sf $HOME/lun/sbox.json $HOME/weblun/"$(cat $HOME/lun/subtoken.log 2>/dev/null)"/sbox.json
ln -sf $HOME/lun/jhsub.txt $HOME/weblun/"$(cat $HOME/lun/subtoken.log 2>/dev/null)"/jhsub.txt
if command -v apk >/dev/null 2>&1; then
busybox-extras httpd -f -p "$(cat $HOME/lun/subport.log 2>/dev/null)" -h $HOME/weblun > /dev/null 2>&1 &
else
busybox httpd -f -p "$(cat $HOME/lun/subport.log 2>/dev/null)" -h $HOME/weblun > /dev/null 2>&1 &
fi
sleep 5
if command -v apk >/dev/null 2>&1; then
cat > /etc/local.d/alpinesublun.start <<EOF
#!/bin/bash
sleep 10
busybox-extras httpd -f -p \$(cat $HOME/lun/subport.log 2>/dev/null) -h $HOME/weblun > /dev/null 2>&1 &
EOF
chmod +x /etc/local.d/alpinesublun.start
rc-update add local default >/dev/null 2>&1
else
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/weblun/d' /tmp/crontab.tmp
echo '@reboot sleep 10 && /bin/bash -c "busybox httpd -f -p $(cat $HOME/lun/subport.log 2>/dev/null) -h $HOME/weblun > /dev/null 2>&1 &"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
fi
echo "本地IP订阅链接已更新完成"
fi
if [ -n "$hyjpt" ] && [ -n "$hyp" ]; then
echo
echo "设置Hysteria2协议的跳跃端口：$hyjpt"
iptables -t nat -F PREROUTING >/dev/null 2>&1
ip6tables -t nat -F PREROUTING >/dev/null 2>&1
hyport=$(cat "$HOME/lun/port_hy2")
for port in $hyjpt; do
iptables -t nat -A PREROUTING -p udp --dport "$port" -j DNAT --to-destination :$hyport
ip6tables -t nat -A PREROUTING -p udp --dport "$port" -j DNAT --to-destination :$hyport
done
netfilter-persistent save >/dev/null 2>&1
if command -v rc-service >/dev/null 2>&1 && command -v rc-update >/dev/null 2>&1; then
rc-update show default 2>/dev/null | grep -q 'iptables' || rc-update add iptables >/dev/null 2>&1
rc-update show default 2>/dev/null | grep -q 'ip6tables' || rc-update add ip6tables >/dev/null 2>&1
rc-service iptables save >/dev/null 2>&1
rc-service ip6tables save >/dev/null 2>&1
fi
fi
cip
echo
else
if [ "$(id -u 2>/dev/null)" = "0" ]; then
ENTRY_PATH="/usr/bin/lun"
else
ENTRY_PATH="$HOME/bin/lun"
mkdir -p "$HOME/bin"
fi
install_lun_entry "$ENTRY_PATH" >/dev/null 2>&1 || true
echo "Lun脚本已安装"
echo
lunstatus
echo
echo "相关快捷方式如下："
showmode
exit
fi
