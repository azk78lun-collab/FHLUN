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
[ -z "${xupt+x}" ] || xup=yes
[ -z "${xcpt+x}" ] || xcp=yes
[ -z "${nvpt+x}" ] || nvp=yes
[ -n "${warp:-}" ] && wap=yes
[ -n "${cdnym:-}" ] && _lun_cdn_input=yes || _lun_cdn_input=no
LUN_MENU_REQUEST=
[ -z "$1" ] && [ "$vwp" != yes ] && [ "$sop" != yes ] && [ "$vxp" != yes ] && [ "$ssp" != yes ] && [ "$vlp" != yes ] && [ "$vmp" != yes ] && [ "$hyp" != yes ] && [ "$tup" != yes ] && [ "$xhp" != yes ] && [ "$anp" != yes ] && [ "$arp" != yes ] && [ "$xup" != yes ] && [ "$xcp" != yes ] && [ "$nvp" != yes ] && LUN_MENU_REQUEST=yes
_lun_proc_running=no
for _P in /proc/[0-9]*; do
[ -L "$_P/exe" ] || continue
_exe=$(readlink -f "$_P/exe" 2>/dev/null) || continue
case "$_exe" in */lun/sing-box*|*/lun/xray*) _lun_proc_running=yes; break ;; esac
done
[ "$_lun_proc_running" = "no" ] && pgrep -f 'lun/(sing-box|xray)([[:space:]]|$)' >/dev/null 2>&1 && _lun_proc_running=yes
[ "$_lun_proc_running" = "no" ] && { systemctl is-active --quiet xr 2>/dev/null || systemctl is-active --quiet sb 2>/dev/null; } && _lun_proc_running=yes
_lun_installed=no
{ [ -x "$HOME/lun/xray" ] || [ -x "$HOME/lun/sing-box" ] || [ -s "$HOME/lun/xr.json" ] || [ -s "$HOME/lun/sb.json" ]; } && _lun_installed=yes
if [ "$_lun_proc_running" = "yes" ] || [ "$_lun_installed" = "yes" ]; then
if [ "$1" = "rep" ]; then
[ "$vwp" = yes ] || [ "$sop" = yes ] || [ "$vxp" = yes ] || [ "$ssp" = yes ] || [ "$vlp" = yes ] || [ "$vmp" = yes ] || [ "$hyp" = yes ] || [ "$tup" = yes ] || [ "$xhp" = yes ] || [ "$anp" = yes ] || [ "$arp" = yes ] || [ "$xup" = yes ] || [ "$xcp" = yes ] || [ "$nvp" = yes ] || { echo "提示：rep重置协议时，请在脚本前至少设置一个协议变量哦，再见！"; exit; }
fi
else
[ "$LUN_MENU_REQUEST" = yes ] || [ "$1" = "del" ] || [ "$vwp" = yes ] || [ "$sop" = yes ] || [ "$vxp" = yes ] || [ "$ssp" = yes ] || [ "$vlp" = yes ] || [ "$vmp" = yes ] || [ "$hyp" = yes ] || [ "$tup" = yes ] || [ "$xhp" = yes ] || [ "$anp" = yes ] || [ "$arp" = yes ] || [ "$xup" = yes ] || [ "$xcp" = yes ] || [ "$nvp" = yes ] || { echo "提示：未安装 Lun，请先运行 lun 菜单安装，或在脚本前至少设置一个协议变量。"; exit; }
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
export port_xu=${xupt:-''}
export port_xc=${xcpt:-''}
export port_nv=${nvpt:-''}
export ym_vl_re=${reym:-''}
export cdnym=${cdnym:-''}
export cfip=${cfip:-''}
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
export cdnmode=${cdnmode:-''}
export cdnpt=${cdnpt:-''}
export cdnproto=${cdnproto:-''}
export addrmode=${addrmode:-''}
export domain=${domain:-''}
export certmode=${certmode:-''}
export acme_email=${acme_email:-''}
export acme_dns=${acme_dns:-''}
export coremirror=${coremirror:-${LUN_CORE_MIRROR:-"https://oracle1.1223344.xyz/fhlun"}}
v46url="https://icanhazip.com"
lunurl=${lunurl:-"https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh"}
showmode_short(){
echo "主脚本：bash <(curl -Ls https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh) 或 bash <(wget -qO- https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)"
echo "风火轮多协议交互面板命令：lun"
echo "---------------------------------------------------------"
echo
}
showmode(){
showmode_short
}
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Lun 项目地址：https://github.com/azk78lun-collab/FHLUN"
echo ""
echo ""
echo "风火轮一键无交互脚本"
echo "当前版本：V26.7.19.2"
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
esac
addr=$(normalize_host "$addr")
case "$addr" in
*:*) printf '%s' "$addr" | grep -Eq '^[0-9A-Fa-f:.]+$' ;;
*) return 0 ;;
esac
}

normalize_host(){
host=$1
case "$host" in
\[*\]) host=${host#\[}; host=${host%\]} ;;
esac
printf '%s\n' "$host"
}

host_is_ipv6(){
host=$(normalize_host "$1")
case "$host" in *:*) return 0 ;; *) return 1 ;; esac
}

uri_host(){
host=$(normalize_host "$1")
if host_is_ipv6 "$host"; then
printf '[%s]\n' "$host"
else
printf '%s\n' "$host"
fi
}

json_host(){
normalize_host "$1"
}

endpoint_kind(){
host=$(normalize_host "$1")
if host_is_ipv6 "$host"; then
printf 'V6\n'
elif printf '%s' "$host" | grep -Eq '^[0-9]+(\.[0-9]+){3}$'; then
printf 'V4\n'
else
printf 'DOMAIN\n'
fi
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
seen_ext=
seen_inner=
for pair in $1; do
valid_ptmap_pair "$pair" || return 1
ext=${pair%%-*}
inner=${pair#*-}
case " $seen_ext " in *" $ext "*) return 1 ;; esac
case " $seen_inner " in *" $inner "*) return 1 ;; esac
seen_ext="${seen_ext:+$seen_ext }$ext"
seen_inner="${seen_inner:+$seen_inner }$inner"
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
normalized=$(normalize_ptmap "$ptmap") || { echo "ptmap 格式错误或存在重复公网/内网端口，请使用 外网端口-内网端口，例如：54834-2096 54835-8443"; exit 1; }
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
normalized=
seen=
for one in $argoip; do
case "$one" in -1) bad=yes; continue ;; *) valid_addym "$one" || { bad=yes; continue; } ;; esac
one=$(normalize_host "$one")
case " $seen " in *" $one "*) continue ;; esac
seen="${seen:+$seen }$one"
normalized="${normalized:+$normalized }$one"
done
[ -z "$bad" ] || { echo "argoip 只接受 IP 或域名，多个值用空格分隔"; exit 1; }
argoip="$normalized"
printf "%s\n" "$argoip" > "$HOME/lun/argoip"
;;
esac
elif [ -s "$HOME/lun/argoip" ]; then
argoip=$(cat "$HOME/lun/argoip" 2>/dev/null)
fi
}

clear_cdn_ip_list(){
rm -f "$HOME/lun/cdnip" "$HOME/lun"/cdnip[0-9]* 2>/dev/null
}

save_cdn_ip_list(){
clear_cdn_ip_list
idx=1
list=
seen=
for one in $1; do
case "$one" in ""|-1) continue ;; esac
valid_addym "$one" || continue
one=$(normalize_host "$one")
case " $seen " in *" $one "*) continue ;; esac
seen="${seen:+$seen }$one"
list="${list:+$list }$one"
printf "%s\n" "$one" > "$HOME/lun/cdnip$idx"
idx=$((idx + 1))
done
[ -n "$list" ] && printf "%s\n" "$list" > "$HOME/lun/cdnip"
}

load_cdn_mode_config(){
[ -z "$cdnym" ] && [ -s "$HOME/lun/cdnym" ] && cdnym=$(cat "$HOME/lun/cdnym" 2>/dev/null)
if [ -n "$cfip" ]; then
case "$cfip" in
del|none|off) clear_cdn_ip_list; cfip= ;;
*) save_cdn_ip_list "$cfip" ;;
esac
fi
if [ -n "$cdnmode" ]; then
case "$cdnmode" in
standard|rewrite) printf '%s\n' "$cdnmode" > "$HOME/lun/cdn_mode" ;;
del|none|off) rm -f "$HOME/lun/cdn_mode" "$HOME/lun/cdn_edge_port"; cdnmode=standard; cdnpt= ;;
*) echo "cdnmode 只支持 standard 或 rewrite。"; exit 1 ;;
esac
elif [ -s "$HOME/lun/cdn_mode" ]; then
cdnmode=$(cat "$HOME/lun/cdn_mode" 2>/dev/null)
else
cdnmode=standard
fi
case "$cdnmode" in standard|rewrite) ;; *) cdnmode=standard ;; esac

if [ -n "$cdnpt" ]; then
case "$cdnpt" in
80|8080|8880|2052|2082|2086|2095|443|8443|2053|2083|2087|2096) printf '%s\n' "$cdnpt" > "$HOME/lun/cdn_edge_port" ;;
del|none|off) rm -f "$HOME/lun/cdn_edge_port"; cdnpt= ;;
*) echo "cdnpt 必须是 Cloudflare HTTP/HTTPS 官方代理端口。"; exit 1 ;;
esac
elif [ -s "$HOME/lun/cdn_edge_port" ]; then
cdnpt=$(cat "$HOME/lun/cdn_edge_port" 2>/dev/null)
fi
if [ -n "$cdnproto" ]; then
case "$cdnproto" in
xhttp|all) printf '%s\n' "$cdnproto" > "$HOME/lun/cdn_protocol" ;;
del|none|off) rm -f "$HOME/lun/cdn_protocol"; cdnproto=xhttp ;;
*) echo "cdnproto 只支持 xhttp 或 all。"; exit 1 ;;
esac
elif [ -s "$HOME/lun/cdn_protocol" ]; then
cdnproto=$(cat "$HOME/lun/cdn_protocol" 2>/dev/null)
elif [ "$_lun_installed" = yes ]; then
# 旧安装没有此文件时保留原来的多协议 CDN 输出；进入快速配置后迁移为 XHTTP。
cdnproto=all
else
cdnproto=xhttp
fi
case "$cdnproto" in xhttp|all) ;; *) cdnproto=xhttp ;; esac
[ "$cdnmode" = rewrite ] && [ -z "$cdnpt" ] && cdnpt=$(cdn_recommended_edge_port)
[ "$_lun_cdn_input" = yes ] && auto_configure_cdn_edge_port
}

load_address_mode_config(){
if [ -n "$addrmode" ]; then
case "$addrmode" in
domain|ipv4|ipv6|dual|all)
printf '%s\n' "$addrmode" > "$HOME/lun/address_mode"
;;
del|none|off|auto)
rm -f "$HOME/lun/address_mode"
addrmode=
;;
*) echo "addrmode 只支持 domain、ipv4、ipv6、dual、all。"; exit 1 ;;
esac
elif [ -s "$HOME/lun/address_mode" ]; then
addrmode=$(cat "$HOME/lun/address_mode" 2>/dev/null)
fi
case "$addrmode" in ""|domain|ipv4|ipv6|dual|all) ;; *) addrmode= ;; esac
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

cdn_rewrite_active(){
[ "$cdnmode" = rewrite ]
}

cdn_protocol_enabled(){
case "$cdnproto:$1" in
xhttp:xhttp|all:xhttp|all:ws|all:vmess) return 0 ;;
*) return 1 ;;
esac
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

is_cf_http_port(){
case "$1" in 80|8080|8880|2052|2082|2086|2095) return 0 ;; *) return 1 ;; esac
}

is_cf_https_port(){
case "$1" in 443|8443|2053|2083|2087|2096) return 0 ;; *) return 1 ;; esac
}

cf_http_port_list(){
printf '%s\n' 80 8080 8880 2052 2082 2086 2095
}

# 默认随机端口避开最常被占用的 443；需要 UDP 443 时由 Origin Rules 单独配置边缘端口。
cf_https_random_port_list(){
printf '%s\n' 8443 2053 2083 2087 2096
}

cf_port_kind_label(){
case "$1" in
http) printf 'Cloudflare HTTP' ;;
https) printf 'Cloudflare HTTPS' ;;
*) printf 'Cloudflare' ;;
esac
}

cf_port_matches_kind(){
case "$1:$2" in
http:*) is_cf_http_port "$2" ;;
https:*) is_cf_https_port "$2" ;;
*) return 1 ;;
esac
}

cdn_protocol_state_port(){
value=$1
file=$2
[ -n "$value" ] || [ ! -s "$file" ] || value=$(cat "$file" 2>/dev/null)
printf '%s\n' "$value"
}

cdn_has_xhttp_tls(){
[ "$xcp" = yes ] || [ -n "${port_xc:-}" ] || [ -s "$HOME/lun/port_xc" ]
}

cdn_has_generic_protocol(){
cdn_protocol_enabled xhttp && { [ "$vxp" = yes ] || [ -n "${port_vx:-}" ] || [ -s "$HOME/lun/port_vx" ]; } && return 0
cdn_protocol_enabled ws && { [ "$vwp" = yes ] || [ -n "${port_vw:-}" ] || [ -s "$HOME/lun/port_vw" ]; } && return 0
cdn_protocol_enabled vmess && { [ "$vmp" = yes ] || [ -n "${port_vm_ws:-}" ] || [ -s "$HOME/lun/port_vm_ws" ]; } && return 0
return 1
}

cdn_origin_is_xhttp_tls(){
origin=$1
xc_origin=$(cdn_protocol_state_port "${port_xc:-}" "$HOME/lun/port_xc")
[ -n "$xc_origin" ] && [ "$origin" = "$xc_origin" ]
}

cdn_recommended_edge_port(){
if cdn_has_generic_protocol; then printf '8080\n'; elif cdn_has_xhttp_tls; then printf '443\n'; else printf '8080\n'; fi
}

cdn_origin_ports_need_rewrite(){
if cdn_protocol_enabled xhttp && cdn_has_xhttp_tls; then
origin=$(cdn_protocol_state_port "${port_xc:-}" "$HOME/lun/port_xc")
[ -n "$origin" ] || return 0
is_cf_https_port "$(client_port "$origin")" || return 0
fi
if cdn_protocol_enabled xhttp && { [ "$vxp" = yes ] || [ -n "${port_vx:-}" ] || [ -s "$HOME/lun/port_vx" ]; }; then
origin=$(cdn_protocol_state_port "${port_vx:-}" "$HOME/lun/port_vx")
[ -n "$origin" ] || return 0
edge=$(client_port "$origin")
{ is_cf_http_port "$edge" || is_cf_https_port "$edge"; } || return 0
fi
if cdn_protocol_enabled ws && { [ "$vwp" = yes ] || [ -n "${port_vw:-}" ] || [ -s "$HOME/lun/port_vw" ]; }; then
origin=$(cdn_protocol_state_port "${port_vw:-}" "$HOME/lun/port_vw")
[ -n "$origin" ] || return 0
edge=$(client_port "$origin")
{ is_cf_http_port "$edge" || is_cf_https_port "$edge"; } || return 0
fi
if cdn_protocol_enabled vmess && { [ "$vmp" = yes ] || [ -n "${port_vm_ws:-}" ] || [ -s "$HOME/lun/port_vm_ws" ]; }; then
origin=$(cdn_protocol_state_port "${port_vm_ws:-}" "$HOME/lun/port_vm_ws")
[ -n "$origin" ] || return 0
edge=$(client_port "$origin")
{ is_cf_http_port "$edge" || is_cf_https_port "$edge"; } || return 0
fi
return 1
}

auto_configure_cdn_edge_port(){
[ -n "$cdnym" ] || [ -s "$HOME/lun/cdnym" ] || return 0
old_mode=${cdnmode:-standard}
old_port=${cdnpt:-}
old_tls=no
[ "$old_mode" = rewrite ] && is_cf_https_port "$old_port" && old_tls=yes

if [ "$cdnmode" = rewrite ]; then
if ! { is_cf_http_port "$cdnpt" || is_cf_https_port "$cdnpt"; }; then
cdnpt=$(cdn_recommended_edge_port)
elif cdn_has_xhttp_tls && ! cdn_has_generic_protocol && ! is_cf_https_port "$cdnpt"; then
cdnpt=443
fi
elif cdn_origin_ports_need_rewrite; then
cdnmode=rewrite
cdnpt=$(cdn_recommended_edge_port)
fi

[ "$cdnmode" = rewrite ] || return 0
printf '%s\n' "$cdnmode" > "$HOME/lun/cdn_mode"
printf '%s\n' "$cdnpt" > "$HOME/lun/cdn_edge_port"
export cdnmode cdnpt
new_tls=no
is_cf_https_port "$cdnpt" && new_tls=yes
[ "$old_tls" != "$new_tls" ] && CDN_REBUILD_REQUIRED=yes
[ "$old_mode:$old_port" != "$cdnmode:$cdnpt" ] && CDN_REBUILD_REQUIRED=yes
if [ "$old_mode:$old_port" != "$cdnmode:$cdnpt" ]; then
echo "已自动选择 Cloudflare 边缘端口 $cdnpt，并启用 Origin Rules 回源端口改写。"
fi
}

cdn_client_port(){
origin_inner=$1
if cdn_rewrite_active; then
edge=${cdnpt:-$(cdn_recommended_edge_port)}
if cdn_origin_is_xhttp_tls "$origin_inner" && ! is_cf_https_port "$edge"; then
printf '443\n'
else
printf '%s\n' "$edge"
fi
else
client_port "$origin_inner"
fi
}

cdn_origin_tls_for_port(){
[ -n "$cdnym" ] || [ -s "$HOME/lun/cdnym" ] || return 1
if cdn_rewrite_active; then
is_cf_https_port "$(cdn_client_port "$1")"
else
is_cf_https_port "$(client_port "$1")"
fi
}

effective_address_mode(){
if [ -n "$addrmode" ]; then
printf '%s\n' "$addrmode"
return
fi
if [ -n "$addym" ]; then
case "$addout" in
replace) printf 'domain\n' ;;
both)
case "$ippz" in
4) printf 'legacy-domain4\n' ;;
6) printf 'legacy-domain6\n' ;;
46) printf 'all\n' ;;
*) printf 'legacy-domain-auto\n' ;;
esac
;;
*) case "$ippz" in 4) printf 'ipv4\n' ;; 6) printf 'ipv6\n' ;; 46) printf 'dual\n' ;; *) printf 'auto\n' ;; esac ;;
esac
else
case "$ippz" in 4) printf 'ipv4\n' ;; 6) printf 'ipv6\n' ;; 46) printf 'dual\n' ;; *) printf 'auto\n' ;; esac
fi
}

direct_address_entries(){
mode=$(effective_address_mode)
domain_addr=$(normalize_host "${addym:-$domain}")
case "$mode" in
domain)
[ -n "$domain_addr" ] && printf '%s|DOMAIN\n' "$domain_addr"
;;
ipv4)
[ -n "$v4" ] && printf '%s|IPv4\n' "$v4"
;;
ipv6)
[ -n "$v6" ] && printf '%s|IPv6\n' "$v6"
;;
dual)
[ -n "$v4" ] && printf '%s|IPv4\n' "$v4"
[ -n "$v6" ] && printf '%s|IPv6\n' "$v6"
;;
all)
[ -n "$domain_addr" ] && printf '%s|DOMAIN\n' "$domain_addr"
[ -n "$v4" ] && [ "$v4" != "$domain_addr" ] && printf '%s|IPv4\n' "$v4"
[ -n "$v6" ] && [ "$v6" != "$domain_addr" ] && printf '%s|IPv6\n' "$v6"
;;
legacy-domain4)
[ -n "$v4" ] && printf '%s|IPv4\n' "$v4"
[ -n "$domain_addr" ] && [ "$domain_addr" != "$v4" ] && printf '%s|DOMAIN\n' "$domain_addr"
;;
legacy-domain6)
[ -n "$v6" ] && printf '%s|IPv6\n' "$v6"
[ -n "$domain_addr" ] && [ "$domain_addr" != "$v6" ] && printf '%s|DOMAIN\n' "$domain_addr"
;;
legacy-domain-auto)
if [ -n "$v4" ]; then printf '%s|IPv4\n' "$v4"; elif [ -n "$v6" ]; then printf '%s|IPv6\n' "$v6"; fi
[ -n "$domain_addr" ] && [ "$domain_addr" != "$v4" ] && [ "$domain_addr" != "$v6" ] && printf '%s|DOMAIN\n' "$domain_addr"
;;
*)
if [ -n "$v4" ]; then
printf '%s|IPv4\n' "$v4"
elif [ -n "$v6" ]; then
printf '%s|IPv6\n' "$v6"
elif [ -n "$domain_addr" ]; then
printf '%s|DOMAIN\n' "$domain_addr"
fi
;;
esac
}

address_mode_label(){
case "$(effective_address_mode)" in
domain) printf '仅域名\n' ;;
ipv4) printf '仅 IPv4\n' ;;
ipv6) printf '仅 IPv6\n' ;;
dual) printf 'IPv4 + IPv6\n' ;;
all) printf '域名 + IPv4 + IPv6\n' ;;
legacy-domain4) printf '域名 + IPv4（兼容模式）\n' ;;
legacy-domain6) printf '域名 + IPv6（兼容模式）\n' ;;
legacy-domain-auto) printf '域名 + 自动 IP（兼容模式）\n' ;;
*) printf '自动\n' ;;
esac
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

show_port_map_list(){
maps=${1:-$ptmap}
if [ -z "$maps" ]; then
echo "NAT端口映射：无"
return 0
fi
count=$(printf '%s\n' $maps | awk 'NF{n++} END{print n+0}')
echo "NAT端口映射：共 $count 组"
line=
column=0
for pair in $maps; do
line="$line  $pair"
column=$((column + 1))
if [ "$column" -ge 4 ]; then
echo "$line"
line=
column=0
fi
done
[ -z "$line" ] || echo "$line"
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
ext=${pair%%-*}
inner=${pair#*-}
for exist in $ptmap; do
[ "$exist" = "$pair" ] && return 0
exist_ext=${exist%%-*}
exist_inner=${exist#*-}
[ "$exist_ext" = "$ext" ] && return 1
[ "$exist_inner" = "$inner" ] && return 1
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
self|origin|ca|domain|dns|ip)
printf "%s\n" "$certmode" > "$HOME/lun/cert_mode"
;;
del|none)
rm -f "$HOME/lun/cert_mode" "$HOME/lun/cert_subject" "$HOME/lun/acme_dns"
certmode=self
;;
*)
echo "certmode 只支持 self、origin、ca、domain、dns、ip。"
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
addym=$(normalize_host "$addym")
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
load_address_mode_config
load_port_map_config
load_port_pool_config
load_vps_mode_config
load_cdn_mode_config
load_argoip_config
load_subip_mode_config
ensure_lun_command || true
dependency_marker="$HOME/lun/.dependencies_ready"
if [ -f sbx_update ] && [ ! -f "$dependency_marker" ]; then
touch "$dependency_marker"
fi
if [ ! -f "$dependency_marker" ]; then
echo "执行必要的脚本依赖中，请稍等10秒……"
if command -v apk >/dev/null 2>&1; then
apk update >/dev/null 2>&1 && apk add --no-cache bash busybox-extras gcompat libc6-compat iptables openssl >/dev/null 2>&1
elif command -v apt >/dev/null 2>&1; then
export DEBIAN_FRONTEND=noninteractive
printf 'iptables-persistent iptables-persistent/autosave_v4 boolean true\niptables-persistent iptables-persistent/autosave_v6 boolean true\n' | debconf-set-selections
apt update >/dev/null 2>&1 && apt install -y busybox coreutils util-linux iptables iptables-persistent cron openssl >/dev/null 2>&1
fi
touch "$dependency_marker"
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
core_network_detect(){
[ -n "$core_net_v4" ] && [ -n "$core_net_v6" ] && return
core_net_v4=no; core_net_v6=no
if command -v curl >/dev/null 2>&1; then
curl -4 -fsS --connect-timeout 5 --max-time 8 "$v46url" >/dev/null 2>&1 && core_net_v4=yes
curl -6 -fsS --connect-timeout 5 --max-time 8 "$v46url" >/dev/null 2>&1 && core_net_v6=yes
elif command -v wget >/dev/null 2>&1; then
timeout 8 wget -4 -qO- --tries=1 "$v46url" >/dev/null 2>&1 && core_net_v4=yes
timeout 8 wget -6 -qO- --tries=1 "$v46url" >/dev/null 2>&1 && core_net_v6=yes
fi
}

download_core_url(){
download_url=$1
download_out=$2
download_family=$3
rm -f "$download_out"
if command -v curl >/dev/null 2>&1; then
case "$download_family" in
4) curl -4 -fL --connect-timeout 10 --max-time 300 --retry 2 -o "$download_out" "$download_url" ;;
6) curl -6 -fL --connect-timeout 10 --max-time 300 --retry 2 -o "$download_out" "$download_url" ;;
*) curl -fL --connect-timeout 10 --max-time 300 --retry 2 -o "$download_out" "$download_url" ;;
esac
elif command -v wget >/dev/null 2>&1; then
case "$download_family" in
4) wget -4 -O "$download_out" --tries=2 --timeout=60 "$download_url" ;;
6) wget -6 -O "$download_out" --tries=2 --timeout=60 "$download_url" ;;
*) wget -O "$download_out" --tries=2 --timeout=60 "$download_url" ;;
esac
else
return 1
fi
[ -s "$download_out" ]
}

download_core_asset(){
asset_name=$1
asset_tmp=$2
asset_upstream=$3
core_network_detect
mirror_base=${coremirror%/}
[ "$mirror_base" = off ] && mirror_base=
if [ "$core_net_v4" = yes ]; then
echo "下载 $asset_name：GitHub Release（IPv4）"
download_core_url "$asset_upstream" "$asset_tmp" 4 && return 0
fi
if [ -n "$mirror_base" ]; then
if [ "$core_net_v6" = yes ]; then
echo "下载 $asset_name：Oracle 静态镜像（IPv6）"
download_core_url "$mirror_base/$asset_name" "$asset_tmp" 6 && return 0
fi
if [ "$core_net_v4" = yes ]; then
echo "下载 $asset_name：Oracle 静态镜像（IPv4）"
download_core_url "$mirror_base/$asset_name" "$asset_tmp" 4 && return 0
fi
fi
rm -f "$asset_tmp"
echo "下载 $asset_name 失败：IPv4=$core_net_v4，IPv6=$core_net_v6。"
if [ "$core_net_v6" = yes ] && [ "$core_net_v4" != yes ]; then
echo "已尝试 Oracle 静态镜像，请检查 oracle1.1223344.xyz/fhlun 服务和 IPv6 连通性。"
fi
return 1
}

upxray(){
out="$HOME/lun/xray"; tmp="${out}.tmp.$$"
url="https://github.com/azk78lun-collab/FHLUN/releases/download/lun/xray-$cpu"
download_core_asset "xray-$cpu" "$tmp" "$url" || return 1
chmod +x "$tmp" || { rm -f "$tmp"; return 1; }
sbcore=$("$tmp" version 2>/dev/null | awk '/^Xray/{print $2}')
[ -n "$sbcore" ] || { echo "下载的 Xray 文件无法执行，已保留原内核。"; rm -f "$tmp"; return 1; }
mv -f "$tmp" "$out"
echo "已安装Xray正式版内核：$sbcore"
}

upsingbox(){
out="$HOME/lun/sing-box"; tmp="${out}.tmp.$$"
url="https://github.com/azk78lun-collab/FHLUN/releases/download/lun/sing-box-$cpu"
download_core_asset "sing-box-$cpu" "$tmp" "$url" || return 1
chmod +x "$tmp" || { rm -f "$tmp"; return 1; }
sbcore=$("$tmp" version 2>/dev/null | awk '/version/{print $NF}')
[ -n "$sbcore" ] || { echo "下载的 Sing-box 文件无法执行，已保留原内核。"; rm -f "$tmp"; return 1; }
mv -f "$tmp" "$out"
echo "已安装Sing-box正式版内核：$sbcore"
}

upcloudflared(){
out="$HOME/lun/cloudflared"; tmp="${out}.tmp.$$"
url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$cpu"
download_core_asset "cloudflared-linux-$cpu" "$tmp" "$url" || return 1
chmod +x "$tmp" || { rm -f "$tmp"; return 1; }
argocore=$("$tmp" version 2>/dev/null | awk '{print $3}')
[ -n "$argocore" ] || { echo "下载的 Cloudflared 文件无法执行，已保留原内核。"; rm -f "$tmp"; return 1; }
mv -f "$tmp" "$out"
echo "已安装Cloudflared正式版内核：$argocore"
}

cert_hash_update(){
if [ -f "$HOME/lun/cert.crt" ]; then
SHA256=$(openssl x509 -in "$HOME/lun/cert.crt" -outform DER 2>/dev/null | sha256sum | awk '{print $1}')
[ -n "$SHA256" ] && echo "$SHA256" > "$HOME/lun/SHA256.txt"
fi
}

cert_mode_label(){
case "$1" in
self) printf '%s\n' "自签证书" ;;
origin) printf '%s\n' "服务商签发（Cloudflare Origin CA）" ;;
ca) printf '%s\n' "公开 CA / 服务商签发证书" ;;
domain) printf '%s\n' "Let's Encrypt 域名证书（HTTP-01）" ;;
dns) printf '%s\n' "Let's Encrypt 域名证书（DNS API）" ;;
ip) printf '%s\n' "Let's Encrypt IP 短期证书" ;;
*) printf '%s\n' "未知证书" ;;
esac
}

cert_issuer_text(){
openssl x509 -in "$1" -noout -issuer -nameopt RFC2253 2>/dev/null | sed 's/^issuer=//'
}

cert_name_matches_pattern(){ (
cert_match_name=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/^\[//; s/\]$//; s/\.$//')
cert_match_pattern=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]' | sed 's/^\[//; s/\]$//; s/\.$//')
[ -n "$cert_match_name" ] && [ -n "$cert_match_pattern" ] || return 1
case "$cert_match_pattern" in
\*.*)
cert_match_suffix=${cert_match_pattern#\*}
case "$cert_match_name" in
*"$cert_match_suffix")
cert_match_prefix=${cert_match_name%"$cert_match_suffix"}
[ -n "$cert_match_prefix" ] || return 1
case "$cert_match_prefix" in *.*) return 1 ;; *) return 0 ;; esac
;;
esac
;;
*) [ "$cert_match_name" = "$cert_match_pattern" ] && return 0 ;;
esac
return 1
) }

cert_covers_domain(){ (
cert_file=$1
cert_name=$(printf '%s' "$2" | sed 's/^\[//; s/\]$//; s/\.$//')
[ -n "$cert_name" ] || return 1

cert_san_output=$(openssl x509 -in "$cert_file" -noout -ext subjectAltName 2>/dev/null) || cert_san_output=
if [ -n "$cert_san_output" ]; then
cert_san_names=$(printf '%s\n' "$cert_san_output" | tr ',' '\n' | sed -n \
  -e 's/^[[:space:]]*DNS://p' \
  -e 's/^[[:space:]]*IP Address://p')
while IFS= read -r cert_san_name; do
[ -n "$cert_san_name" ] || continue
cert_name_matches_pattern "$cert_name" "$cert_san_name" && return 0
done <<EOF
$cert_san_names
EOF
# RFC 6125: when SAN exists, do not fall back to the Common Name.
return 1
fi

cert_cn=$(openssl x509 -in "$cert_file" -noout -subject -nameopt RFC2253 2>/dev/null | sed -n 's/^subject=.*CN=\([^,]*\).*$/\1/p')
cert_name_matches_pattern "$cert_name" "$cert_cn"
) }

cert_subject_from_file(){
cert_file=$1
preferred_name=$2
if cert_covers_domain "$cert_file" "$preferred_name"; then
printf '%s\n' "$preferred_name"
return
fi
sans=$(openssl x509 -in "$cert_file" -noout -ext subjectAltName 2>/dev/null | tr ',' '\n' | sed -n 's/^[[:space:]]*DNS://p')
subject=$(printf '%s\n' "$sans" | sed '/^\*/d; /^$/d' | sed -n 1p)
[ -z "$subject" ] && subject=$(printf '%s\n' "$sans" | sed '/^$/d' | sed -n 1p)
[ -z "$subject" ] && subject=$(openssl x509 -in "$cert_file" -noout -subject -nameopt RFC2253 2>/dev/null | sed -n 's/^subject=.*CN=\([^,]*\).*$/\1/p')
[ -z "$subject" ] && subject="未知"
printf '%s\n' "$subject"
}

cert_expiry_epoch(){
raw=$(openssl x509 -in "$1" -noout -enddate 2>/dev/null | cut -d= -f2-)
[ -n "$raw" ] && date -u -d "$raw" +%s 2>/dev/null
}

cert_expiry_cn(){
raw=$(openssl x509 -in "$1" -noout -enddate 2>/dev/null | cut -d= -f2-)
epoch=$(cert_expiry_epoch "$1")
if [ -n "$epoch" ]; then
date -u -d "@$epoch" '+%Y年%m月%d日 %H:%M:%S UTC' 2>/dev/null
else
printf '%s\n' "${raw:-未知}"
fi
}

cert_status_cn(){
epoch=$(cert_expiry_epoch "$1")
now=$(date -u +%s 2>/dev/null)
[ -n "$epoch" ] && [ -n "$now" ] || { printf '%s\n' "未知"; return; }
remaining=$((epoch - now))
if [ "$remaining" -le 0 ]; then
printf '%s\n' "已过期"
elif [ "$remaining" -le 2592000 ]; then
printf '即将到期（剩余 %s 天）\n' "$((remaining / 86400))"
else
printf '有效（剩余 %s 天）\n' "$((remaining / 86400))"
fi
}

cert_detect_mode(){
cert_file=$1
subject_dn=$(openssl x509 -in "$cert_file" -noout -subject -nameopt RFC2253 2>/dev/null | sed 's/^subject=//')
issuer_dn=$(openssl x509 -in "$cert_file" -noout -issuer -nameopt RFC2253 2>/dev/null | sed 's/^issuer=//')
if [ -n "$subject_dn" ] && [ "$subject_dn" = "$issuer_dn" ]; then
printf '%s\n' self
elif printf '%s\n%s\n' "$subject_dn" "$issuer_dn" | grep -Eqi 'CloudFlare Origin|Cloudflare Origin'; then
printf '%s\n' origin
else
printf '%s\n' ca
fi
}

cert_key_matches(){
cert_file=$1
key_file=$2
[ -f "$cert_file" ] && [ -f "$key_file" ] || return 1
cert_pub=$(openssl x509 -in "$cert_file" -pubkey -noout 2>/dev/null | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}')
key_pub=$(openssl pkey -in "$key_file" -pubout -outform DER 2>/dev/null | sha256sum | awk '{print $1}')
[ -n "$cert_pub" ] && [ "$cert_pub" = "$key_pub" ]
}

cert_find_matching_key(){
cert_file=$1
cert_dir=$(dirname "$cert_file")
cert_base=${cert_file%.*}
candidate_file="/tmp/lun-cert-keys.$$"
: > "$candidate_file"
printf '%s\n' "$cert_base.key" "$cert_base.pem" "$cert_dir/private.key" >> "$candidate_file"
find "$cert_dir" -maxdepth 1 -type f \( -name '*.key' -o -name '*.pem' \) -print 2>/dev/null >> "$candidate_file"
while IFS= read -r key_file; do
[ "$key_file" = "$cert_file" ] && continue
cert_key_matches "$cert_file" "$key_file" || continue
rm -f "$candidate_file"
printf '%s\n' "$key_file"
return 0
done < "$candidate_file"
rm -f "$candidate_file"
return 1
}

sync_cert_metadata(){
cert_file="$HOME/lun/cert.crt"
key_file="$HOME/lun/private.key"
cert_key_matches "$cert_file" "$key_file" || return 1
detected_mode=$(cert_detect_mode "$cert_file")
stored_mode=$(cat "$HOME/lun/cert_mode" 2>/dev/null)
case "$stored_mode" in domain|dns|ip) effective_mode=$stored_mode ;; *) effective_mode=$detected_mode ;; esac
preferred_name=${domain:-$(cat "$HOME/lun/cdnym" 2>/dev/null)}
subject=$(cert_subject_from_file "$cert_file" "$preferred_name")
printf '%s\n' "$effective_mode" > "$HOME/lun/cert_mode"
printf '%s\n' "$subject" > "$HOME/lun/cert_subject"
certmode=$effective_mode
cert_hash_update
}

import_local_certificate(){
cert_file=$1
key_file=$2
openssl x509 -in "$cert_file" -noout >/dev/null 2>&1 || { echo "无法解析证书：$cert_file"; return 1; }
cert_key_matches "$cert_file" "$key_file" || { echo "证书与私钥不匹配，已拒绝导入。"; return 1; }
openssl x509 -in "$cert_file" -noout -checkend 0 >/dev/null 2>&1 || { echo "证书已经过期，已拒绝导入。"; return 1; }
mkdir -p "$HOME/lun"
cp "$cert_file" "$HOME/lun/cert.crt.tmp" || return 1
cp "$key_file" "$HOME/lun/private.key.tmp" || { rm -f "$HOME/lun/cert.crt.tmp"; return 1; }
chmod 644 "$HOME/lun/cert.crt.tmp"
chmod 600 "$HOME/lun/private.key.tmp"
mv -f "$HOME/lun/cert.crt.tmp" "$HOME/lun/cert.crt"
mv -f "$HOME/lun/private.key.tmp" "$HOME/lun/private.key"
printf '%s\n' "$cert_file" > "$HOME/lun/cert_source"
sync_cert_metadata || return 1
echo "已导入证书与匹配私钥到 ~/lun。"
echo "证书类型：$(cert_mode_label "$(cat "$HOME/lun/cert_mode")")"
echo "证书到期：$(cert_expiry_cn "$HOME/lun/cert.crt")"
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
*) sync_cert_metadata || { echo "现有证书与私钥不匹配，不能复用。"; return 1; }; echo "已复用本机已有证书，跳过证书生成。"; return 0 ;;
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
rm -f "$HOME/lun/private.key" "$HOME/lun/cert.crt" "$HOME/lun/SHA256.txt" "$HOME/lun/cert_source"
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
ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1
ip -6 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | sed 's/%.*//'
} | sed '/^$/d; s/^\[//; s/\]$//' | grep -Ev '^(10\.|127\.|169\.254\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.|::1$|[fF][c-dC-D])' | sort -u
}

resolve_domain_ipv4(){
host=$1
{
command -v dig >/dev/null 2>&1 && dig +short A "$host" 2>/dev/null
getent ahostsv4 "$host" 2>/dev/null | awk '{print $1}'
} | awk '/^[0-9]+(\.[0-9]+){3}$/' | sort -u
}

resolve_domain_ipv6(){
host=$1
{
command -v dig >/dev/null 2>&1 && dig +short AAAA "$host" 2>/dev/null
getent ahostsv6 "$host" 2>/dev/null | awk '{print $1}'
} | sed 's/^\[//; s/\]$//; s/%.*//' | awk 'index($0, ":")' | sort -u
}

resolve_domain_ips(){
host=$1
{ resolve_domain_ipv4 "$host"; resolve_domain_ipv6 "$host"; } | sort -u
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

show_domain_acme_diagnostics(){
host=$1
resolved_v4=$(resolve_domain_ipv4 "$host")
resolved_v6=$(resolve_domain_ipv6 "$host")
local_ips=$(local_public_ips)
echo "ACME 域名诊断："
echo "  域名 A：${resolved_v4:-未设置}"
echo "  域名 AAAA：${resolved_v6:-未设置}"
echo "  本机公网地址：${local_ips:-检测失败}"
if command -v ss >/dev/null 2>&1; then
port80_owner=$(ss -lntp 2>/dev/null | awk '$4 ~ /(^|\]|:)80$/ {print; found=1} END{if(!found) print "未占用"}')
echo "  TCP 80：$port80_owner"
fi
if [ -n "$resolved_v6" ]; then
echo "  提示：Let's Encrypt 有 AAAA 时优先从 IPv6 验证，AAAA 必须指向本机且 TCP 80 可公网访问。"
fi
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
rm -f "$HOME/lun/cert_source"
cert_hash_update
}

issue_acme_cert(){
mode=$1
subject=$2
[ -z "$subject" ] && return 1
ensure_acme_sh || return 1
acme="$HOME/.acme.sh/acme.sh"
acme_log="$HOME/lun/acme_issue.log"
: > "$acme_log"
case "$mode" in
domain)
domain_matches_local_ip "$subject" || {
echo "域名 $subject 的 A/AAAA 未匹配本机公网地址，已停止申请。"
show_domain_acme_diagnostics "$subject"
echo "请修正 DNS；若域名使用 Cloudflare 橙云或无法开放 80，可改用 DNS API 证书。"
return 1
}
resolved_v4=$(resolve_domain_ipv4 "$subject")
resolved_v6=$(resolve_domain_ipv6 "$subject")
acme_listen=
[ -z "$resolved_v4" ] && [ -n "$resolved_v6" ] && acme_listen=--listen-v6
show_domain_acme_diagnostics "$subject"
if command -v ss >/dev/null 2>&1 && ss -lnt 2>/dev/null | awk '$4 ~ /(^|\]|:)80$/ {found=1} END{exit !found}'; then
echo "TCP 80 已被占用，acme.sh standalone 无法启动。请先释放 80 端口，或改用 DNS API 证书。"
return 1
fi
echo "开始申请证书，验证监听：${acme_listen:-系统默认（IPv4/IPv6）}"
if ! "$acme" --issue --server letsencrypt --keylength ec-256 -d "$subject" --standalone $acme_listen > "$acme_log" 2>&1; then
echo "域名证书申请失败，acme.sh 最后错误如下："
tail -30 "$acme_log" 2>/dev/null
echo "完整日志：$acme_log"
return 1
fi
;;
dns)
[ -s "$HOME/lun/cert.env" ] && . "$HOME/lun/cert.env"
[ -z "$acme_dns" ] && [ -s "$HOME/lun/acme_dns" ] && acme_dns=$(cat "$HOME/lun/acme_dns" 2>/dev/null)
[ -n "$acme_dns" ] || return 1
if ! "$acme" --issue --server letsencrypt --keylength ec-256 -d "$subject" --dns "$acme_dns" > "$acme_log" 2>&1; then
echo "DNS API 证书申请失败，acme.sh 最后错误如下："
tail -30 "$acme_log" 2>/dev/null
echo "完整日志：$acme_log"
return 1
fi
;;
ip)
ip_subject=$subject
ip_subject=$(printf '%s' "$ip_subject" | sed 's/^\[//; s/\]$//')
is_ip_literal "$ip_subject" || return 1
case "$ip_subject" in *:*) acme_listen=--listen-v6 ;; *) acme_listen= ;; esac
if ! "$acme" --issue --server letsencrypt --keylength ec-256 --cert-profile shortlived --days 3 -d "$ip_subject" --standalone $acme_listen > "$acme_log" 2>&1; then
echo "IP 证书申请失败，acme.sh 最后错误如下："
tail -30 "$acme_log" 2>/dev/null
echo "完整日志：$acme_log"
return 1
fi
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

ensure_cdn_origin_cert(){
origin_port=$1
cdn_origin_tls_for_port "$origin_port" || return 0
if [ ! -s "$HOME/lun/cert.crt" ] || [ ! -s "$HOME/lun/private.key" ]; then
prepare_runtime_cert
fi
}

cert_client_vars(){
cert_mode_current=$(cat "$HOME/lun/cert_mode" 2>/dev/null)
[ -z "$cert_mode_current" ] && cert_mode_current=self
cert_sni=$(cat "$HOME/lun/cert_subject" 2>/dev/null)
[ -z "$cert_sni" ] && cert_sni=www.bing.com
SHA256=$(cat "$HOME/lun/SHA256.txt" 2>/dev/null)
case "$cert_mode_current" in
self|origin)
hy2_pin_arg="&pinSHA256=$SHA256"
generic_tls_pin_arg="&hpkp=$SHA256&pcs=$SHA256"
hy2_link_insecure=0
generic_link_insecure=1
sbox_tls_insecure=true
clash_skip_verify=true
clash_disable_sni=true
;;
*)
hy2_pin_arg=
generic_tls_pin_arg=
hy2_link_insecure=0
generic_link_insecure=0
sbox_tls_insecure=false
clash_skip_verify=false
clash_disable_sni=false
;;
esac
}

naive_certificate_ready(){ (
naive_cert="$HOME/lun/cert.crt"
naive_key="$HOME/lun/private.key"
naive_host=$(normalize_host "${domain:-$(cat "$HOME/lun/cert_subject" 2>/dev/null)}")

cert_key_matches "$naive_cert" "$naive_key" || {
echo "NaiveProxy 启用失败：~/lun 中没有匹配的证书与私钥。"
echo "请运行 lun → 高级设置 → 管理证书 → 搜索并导入本机证书；脚本会搜索 /root/ygkkkca。"
return 1
}
openssl x509 -in "$naive_cert" -noout -checkend 0 >/dev/null 2>&1 || {
echo "NaiveProxy 启用失败：当前证书已经过期。"
return 1
}
case "$(cert_detect_mode "$naive_cert")" in
self|origin)
echo "NaiveProxy 启用失败：Naive 客户端不接受自签证书或 Cloudflare Origin CA。"
echo "请先导入与服务域名匹配的公开可信证书；可运行 lun → 高级设置 → 管理证书 → 搜索并导入本机证书。"
return 1
;;
esac
[ -n "$naive_host" ] && [ "$(endpoint_kind "$naive_host")" = DOMAIN ] && valid_domain "$naive_host" || {
echo "NaiveProxy 启用失败：需要设置与证书匹配的服务域名，不能只使用 IP。"
return 1
}
cert_covers_domain "$naive_cert" "$naive_host" || {
echo "NaiveProxy 启用失败：当前证书不覆盖服务域名 $naive_host。"
return 1
}

naive_leaf="/tmp/lun-naive-leaf.$$"
naive_chain="/tmp/lun-naive-chain.$$"
awk '
/-----BEGIN CERTIFICATE-----/ { block++ }
block == 1 { print }
' "$naive_cert" > "$naive_leaf"
awk '
/-----BEGIN CERTIFICATE-----/ { block++ }
block >= 2 { print }
' "$naive_cert" > "$naive_chain"
naive_ca=
for naive_ca_candidate in /etc/ssl/certs/ca-certificates.crt /etc/ssl/cert.pem /etc/pki/tls/certs/ca-bundle.crt; do
[ -s "$naive_ca_candidate" ] && { naive_ca=$naive_ca_candidate; break; }
done
if [ -n "$naive_ca" ]; then
if [ -s "$naive_chain" ]; then
openssl verify -purpose sslserver -CAfile "$naive_ca" -untrusted "$naive_chain" "$naive_leaf" >/dev/null 2>&1
else
openssl verify -purpose sslserver -CAfile "$naive_ca" "$naive_leaf" >/dev/null 2>&1
fi
else
if [ -s "$naive_chain" ]; then
openssl verify -purpose sslserver -untrusted "$naive_chain" "$naive_leaf" >/dev/null 2>&1
else
openssl verify -purpose sslserver "$naive_leaf" >/dev/null 2>&1
fi
fi
naive_verify_rc=$?
rm -f "$naive_leaf" "$naive_chain"
[ "$naive_verify_rc" = 0 ] || {
echo "NaiveProxy 启用失败：当前证书链无法通过本机公开 CA 信任库校验。"
echo "请导入完整证书链（fullchain）与匹配私钥后重试。"
return 1
}
return 0
) }

cdn_host_current(){
if [ -n "$cdnym" ]; then
printf '%s\n' "$cdnym"
else
cat "$HOME/lun/cdnym" 2>/dev/null
fi
}

xray_stream_security_block(){
origin_port=$1
if cdn_origin_tls_for_port "$origin_port"; then
cat <<EOF
        "security": "tls",
        "tlsSettings": {
          "alpn": ["h2", "http/1.1"],
          "certificates": [
            {
              "certificateFile": "$HOME/lun/cert.crt",
              "keyFile": "$HOME/lun/private.key"
            }
          ]
        },
EOF
else
printf '        "security": "none",\n'
fi
}

singbox_inbound_tls_block(){
origin_port=$1
cdn_origin_tls_for_port "$origin_port" || return 0
cat <<EOF
,
        "tls": {
            "enabled": true,
            "certificate_path": "$HOME/lun/cert.crt",
            "key_path": "$HOME/lun/private.key"
        }
EOF
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
upxray || { echo "Xray 内核下载失败，已停止生成协议配置。"; return 1; }
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
if [ -n "$xup" ] || [ -n "$xcp" ]; then
if cert_key_matches "$HOME/lun/cert.crt" "$HOME/lun/private.key"; then
sync_cert_metadata || { echo "XHTTP TLS 证书元数据同步失败。"; return 1; }
else
prepare_runtime_cert || { echo "XHTTP TLS 证书准备失败。"; return 1; }
fi
fi

if [ -n "$xhp" ]; then
xhp=xhpt
if [ -z "$port_xh" ] && [ ! -e "$HOME/lun/port_xh" ]; then
port_xh=$(random_port 2>/dev/null) || { echo "VLESS XHTTP Reality 无法取得可用端口，请扩容端口池或手动指定端口。"; exit 1; }
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
port_vx=$(random_cdn_port http 2>/dev/null) || { yellow_line "VLESS XHTTP 没有未占用的 Cloudflare HTTP 端口，将回退普通随机端口；后续使用 CDN 时需要 Origin Rules。"; port_vx=$(random_port 2>/dev/null) || { echo "VLESS XHTTP 无法取得可用端口，请扩容端口池或手动指定端口。"; exit 1; }; }
echo "$port_vx" > "$HOME/lun/port_vx"
elif [ -n "$port_vx" ]; then
echo "$port_vx" > "$HOME/lun/port_vx"
fi
port_vx=$(cat "$HOME/lun/port_vx")
ensure_cdn_origin_cert "$port_vx"
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
$(xray_stream_security_block "$port_vx")
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
if [ -n "$xup" ]; then
xup=xupt
if [ -z "$port_xu" ] && [ ! -e "$HOME/lun/port_xu" ]; then
port_xu=$(random_port 2>/dev/null) || { echo "VLESS XHTTP TLS UDP 无法取得可用端口，请扩容端口池或手动指定端口。"; exit 1; }
echo "$port_xu" > "$HOME/lun/port_xu"
elif [ -n "$port_xu" ]; then
echo "$port_xu" > "$HOME/lun/port_xu"
fi
port_xu=$(cat "$HOME/lun/port_xu")
echo "Vless-xhttp-tls-UDP端口：$port_xu"
cat >> "$HOME/lun/xr.json" <<EOF
    {
      "tag": "xhttp-h3",
      "listen": "::",
      "port": ${port_xu},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "flow": ""
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "tls",
        "xhttpSettings": {
          "mode": "auto",
          "path": "${uuid}-xu"
        },
        "tlsSettings": {
          "alpn": ["h3"],
          "certificates": [
            {
              "certificateFile": "$HOME/lun/cert.crt",
              "keyFile": "$HOME/lun/private.key"
            }
          ]
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
xup=xuptargo
fi
if [ -n "$xcp" ]; then
xcp=xcpt
if [ -z "$port_xc" ] && [ ! -e "$HOME/lun/port_xc" ]; then
port_xc=$(random_cdn_port https 2>/dev/null) || { yellow_line "VLESS XHTTP TLS TCP/UDP 没有未占用的 Cloudflare HTTPS 端口，将回退普通随机端口；后续使用 CDN 时需要 Origin Rules。"; port_xc=$(random_port 2>/dev/null) || { echo "VLESS XHTTP TLS TCP/UDP 无法取得可用端口，请扩容端口池或手动指定端口。"; exit 1; }; }
echo "$port_xc" > "$HOME/lun/port_xc"
elif [ -n "$port_xc" ]; then
echo "$port_xc" > "$HOME/lun/port_xc"
fi
port_xc=$(cat "$HOME/lun/port_xc")
echo "Vless-xhttp-tls-TCP/UDP端口：$port_xc"
if [ -n "$cdnym" ]; then
echo "$cdnym" > "$HOME/lun/cdnym"
echo "XHTTP TLS CDN 回源 Host：$cdnym"
fi
cat >> "$HOME/lun/xr.json" <<EOF
    {
      "tag": "xhttp-h23",
      "listen": "::",
      "port": ${port_xc},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "flow": ""
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "tls",
        "xhttpSettings": {
          "mode": "auto",
          "path": "${uuid}-xc"
        },
        "tlsSettings": {
          "alpn": ["h2", "http/1.1"],
          "certificates": [
            {
              "certificateFile": "$HOME/lun/cert.crt",
              "keyFile": "$HOME/lun/private.key"
            }
          ]
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
xcp=xcptargo
fi
if [ -n "$vwp" ]; then
vwp=vwpt
if [ -z "$port_vw" ] && [ ! -e "$HOME/lun/port_vw" ]; then
port_vw=$(random_cdn_port http 2>/dev/null) || { yellow_line "VLESS WS 没有未占用的 Cloudflare HTTP 端口，将回退普通随机端口；后续使用 CDN 时需要 Origin Rules。"; port_vw=$(random_port 2>/dev/null) || { echo "VLESS WS 无法取得可用端口，请扩容端口池或手动指定端口。"; exit 1; }; }
echo "$port_vw" > "$HOME/lun/port_vw"
elif [ -n "$port_vw" ]; then
echo "$port_vw" > "$HOME/lun/port_vw"
fi
port_vw=$(cat "$HOME/lun/port_vw")
ensure_cdn_origin_cert "$port_vw"
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
            "id": "${uuid}"
          }
        ],
        "decryption": "${dekey}"
      },
      "streamSettings": {
        "network": "ws",
$(xray_stream_security_block "$port_vw")
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
port_vl_re=$(random_port 2>/dev/null) || { echo "VLESS TCP Reality 无法取得可用端口，请扩容端口池或手动指定端口。"; exit 1; }
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
upsingbox || { echo "Sing-box 内核下载失败，已停止生成协议配置。"; return 1; }
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
if [ -n "$nvp" ]; then
naive_certificate_ready || return 1
nvp=nvpt
if [ -z "$port_nv" ] && [ ! -e "$HOME/lun/port_nv" ]; then
port_nv=$(random_port 2>/dev/null) || { echo "NaiveProxy 无法取得可用端口，请扩容端口池或手动指定端口。"; exit 1; }
echo "$port_nv" > "$HOME/lun/port_nv"
elif [ -n "$port_nv" ]; then
echo "$port_nv" > "$HOME/lun/port_nv"
fi
port_nv=$(cat "$HOME/lun/port_nv")
echo "NaiveProxy H2/H3端口：$port_nv"
cat >> "$HOME/lun/sb.json" <<EOF
    {
        "type": "naive",
        "tag": "naive-sb",
        "listen": "::",
        "listen_port": ${port_nv},
        "users": [
            {
                "username": "${uuid}",
                "password": "${uuid}"
            }
        ],
        "tls": {
            "enabled": true,
            "certificate_path": "$HOME/lun/cert.crt",
            "key_path": "$HOME/lun/private.key"
        }
    },
EOF
else
nvp=nvptargo
fi
if [ -n "$hyp" ]; then
hyp=hypt
if [ -z "$port_hy2" ] && [ ! -e "$HOME/lun/port_hy2" ]; then
port_hy2=$(random_port 2>/dev/null) || { echo "Hysteria2 无法取得可用端口，请扩容端口池或手动指定端口。"; exit 1; }
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
port_tu=$(random_port 2>/dev/null) || { echo "TUIC 无法取得可用端口，请扩容端口池或手动指定端口。"; exit 1; }
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
port_an=$(random_port 2>/dev/null) || { echo "AnyTLS 无法取得可用端口，请扩容端口池或手动指定端口。"; exit 1; }
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
port_ar=$(random_port 2>/dev/null) || { echo "Any-Reality 无法取得可用端口，请扩容端口池或手动指定端口。"; exit 1; }
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
port_ss=$(random_port 2>/dev/null) || { echo "Shadowsocks-2022 无法取得可用端口，请扩容端口池或手动指定端口。"; exit 1; }
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
port_vm_ws=$(random_cdn_port http 2>/dev/null) || { yellow_line "VMess WS 没有未占用的 Cloudflare HTTP 端口，将回退普通随机端口；后续使用 CDN 时需要 Origin Rules。"; port_vm_ws=$(random_port 2>/dev/null) || { echo "VMess WS 无法取得可用端口，请扩容端口池或手动指定端口。"; exit 1; }; }
echo "$port_vm_ws" > "$HOME/lun/port_vm_ws"
elif [ -n "$port_vm_ws" ]; then
echo "$port_vm_ws" > "$HOME/lun/port_vm_ws"
fi
port_vm_ws=$(cat "$HOME/lun/port_vm_ws")
ensure_cdn_origin_cert "$port_vm_ws"
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
$(xray_stream_security_block "$port_vm_ws")
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
        }$(singbox_inbound_tls_block "$port_vm_ws")
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
port_so=$(random_port 2>/dev/null) || { echo "Socks5 无法取得可用端口，请扩容端口池或手动指定端口。"; exit 1; }
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
ExecStart=$HOME/lun/xray run -c $HOME/lun/xr.json
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
command="$HOME/lun/xray"
command_args="run -c $HOME/lun/xr.json"
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
ExecStart=$HOME/lun/sing-box run -c $HOME/lun/sb.json
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
command="$HOME/lun/sing-box"
command_args="run -c $HOME/lun/sb.json"
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
if [ "$hyp" != yes ] && [ "$tup" != yes ] && [ "$anp" != yes ] && [ "$arp" != yes ] && [ "$ssp" != yes ] && [ "$nvp" != yes ]; then
installxray || return 1
xrsbvm
xrsbso
warpsx
xrsbout
hyp="hyptargo"; tup="tuptargo"; anp="anptargo"; arp="arptargo"; ssp="ssptargo"; nvp="nvptargo"
elif [ "$xhp" != yes ] && [ "$vlp" != yes ] && [ "$vxp" != yes ] && [ "$vwp" != yes ] && [ "$xup" != yes ] && [ "$xcp" != yes ]; then
installsb || return 1
xrsbvm
xrsbso
warpsx
xrsbout
xhp="xhptargo"; vlp="vlptargo"; vxp="vxptargo"; vwp="vwptargo"; xup="xuptargo"; xcp="xcptargo"
else
installsb || return 1
installxray || return 1
xrsbvm
xrsbso
warpsx
xrsbout
fi
if [ -n "$argo" ] && [ -n "$vmag" ]; then
echo
echo "=========启用Cloudflared-argo内核========="
if [ ! -e "$HOME/lun/cloudflared" ]; then
upcloudflared || { echo "Cloudflared 内核下载失败，已停止 Argo 配置。"; return 1; }
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
ExecStart=$HOME/lun/cloudflared tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token "${ARGO_AUTH}"
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
command="$HOME/lun/cloudflared tunnel"
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
if { find /proc/[0-9]*/exe -type l 2>/dev/null | xargs -r readlink 2>/dev/null | grep -Eq 'lun/(sing-box|xray)$'; } 2>/dev/null || pgrep -f 'lun/(sing-box|xray)([[:space:]]|$)' >/dev/null 2>&1 || systemctl is-active --quiet xr 2>/dev/null || systemctl is-active --quiet sb 2>/dev/null; then
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
echo "_lun_ok=no; for _P in /proc/[0-9]*; do [ -L \"\$_P/exe\" ] || continue; _exe=\$(readlink -f \"\$_P/exe\" 2>/dev/null) || continue; case \"\$_exe\" in */lun/sing-box*|*/lun/xray*) _lun_ok=yes; break ;; esac; done; [ \"\$_lun_ok\" = no ] && pgrep -f 'lun/(sing-box|xray)([[:space:]]|$)' >/dev/null 2>&1 && _lun_ok=yes; [ \"\$_lun_ok\" = no ] && { systemctl is-active --quiet xr 2>/dev/null || systemctl is-active --quiet sb 2>/dev/null; } && _lun_ok=yes; if [ \"\$_lun_ok\" = no ]; then echo '检测到系统可能中断过，或者变量格式错误？建议在SSH对话框输入 reboot 重启下服务器。现在自动执行Lun脚本的节点恢复操作，请稍等……'; sleep 6; export cfip=\"${cfip}\" hyjpt=\"${hyjpt}\" cdnym=\"${cdnym}\" cdnmode=\"${cdnmode}\" cdnpt=\"${cdnpt}\" cdnproto=\"${cdnproto}\" addrmode=\"${addrmode}\" addym=\"${addym}\" addout=\"${addout}\" ptmap=\"${ptmap}\" portpool=\"${portpool}\" inpool=\"${inpool}\" outpool=\"${outpool}\" vpsmode=\"${vpsmode}\" argoip=\"${argoip}\" subipmode=\"${subipmode}\" domain=\"${domain}\" certmode=\"${certmode}\" acme_email=\"${acme_email}\" acme_dns=\"${acme_dns}\" name=\"${name}\" ippz=\"${ippz}\" argo=\"${argo}\" uuid=\"${uuid}\" $wap=\"${warp}\" $xhp=\"${port_xh}\" $vxp=\"${port_vx}\" $xup=\"${port_xu}\" $xcp=\"${port_xc}\" $nvp=\"${port_nv}\" $ssp=\"${port_ss}\" $sop=\"${port_so}\" $anp=\"${port_an}\" $arp=\"${port_ar}\" $vlp=\"${port_vl_re}\" $vwp=\"${port_vw}\" $vmp=\"${port_vm_ws}\" $hyp=\"${port_hy2}\" $tup=\"${port_tu}\" reym=\"${ym_vl_re}\" agn=\"${ARGO_DOMAIN}\" agk=\"${ARGO_AUTH}\"; bash \"${SCRIPT_PATH}\"; fi" >> ~/.bashrc
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
_sb_running=no; _xr_running=no
for P in /proc/[0-9]*; do
[ -L "$P/exe" ] || continue
exe=$(readlink -f "$P/exe" 2>/dev/null) || continue
case "$exe" in */lun/sing-box*) _sb_running=yes ;; */lun/xray*) _xr_running=yes ;; esac
done
[ "$_sb_running" = "no" ] && pgrep -f 'lun/sing-box' >/dev/null 2>&1 && _sb_running=yes
[ "$_xr_running" = "no" ] && pgrep -f 'lun/xray' >/dev/null 2>&1 && _xr_running=yes
if [ "$_sb_running" = "yes" ]; then
echo '@reboot sleep 10 && /bin/sh -c "nohup $HOME/lun/sing-box run -c $HOME/lun/sb.json >/dev/null 2>&1 &"' >> /tmp/crontab.tmp
fi
if [ "$_xr_running" = "yes" ]; then
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
# cfip 变量：用户传入的 CDN 优选地址（多个值用空格分隔）
# 如果用户传了 cfip，保存为 cdnip 列表，并兼容写入 cdnip1/cdnip2/...
# 如果没传，优先保留已有配置；没有配置时尝试从已开启橙云的 CDN Host 解析边缘 IP
if [ -n "$cfip" ]; then
save_cdn_ip_list "$cfip"
elif [ -z "$(cdn_ip_list)" ] && [ -n "$cdnym" ]; then
cdn_default_ips || true
fi
}
lunstatus(){
echo "=========当前内核运行状态========="
sb_running=no
xr_running=no
for P in /proc/[0-9]*; do
[ -L "$P/exe" ] || continue
exe=$(readlink -f "$P/exe" 2>/dev/null) || continue
case "$exe" in
*/lun/sing-box*) sb_running=yes ;;
*/lun/xray*) xr_running=yes ;;
esac
done
if [ "$sb_running" = "no" ]; then
pgrep -f 'lun/sing-box' >/dev/null 2>&1 && sb_running=yes
fi
if [ "$sb_running" = "no" ]; then
systemctl is-active --quiet sb 2>/dev/null && sb_running=yes
fi
if [ "$sb_running" = "no" ] && rc-service sing-box status >/dev/null 2>&1; then
sb_running=yes
fi
if [ "$xr_running" = "no" ]; then
pgrep -f 'lun/xray' >/dev/null 2>&1 && xr_running=yes
fi
if [ "$xr_running" = "no" ]; then
systemctl is-active --quiet xr 2>/dev/null && xr_running=yes
fi
if [ "$xr_running" = "no" ] && rc-service xray status >/dev/null 2>&1; then
xr_running=yes
fi
if [ "$sb_running" = "yes" ]; then
echo "Sing-box (版本V$("$HOME/lun/sing-box" version 2>/dev/null | awk '/version/{print $NF}'))：运行中"
elif [ -s "$HOME/lun/sb.json" ] && [ -x "$HOME/lun/sing-box" ]; then
echo "Sing-box：已安装，当前未运行"
elif [ -x "$HOME/lun/sing-box" ]; then
echo "Sing-box：内核已安装，当前协议未使用"
else
echo "Sing-box：未安装"
fi
if [ "$xr_running" = "yes" ]; then
echo "Xray (版本V$("$HOME/lun/xray" version 2>/dev/null | awk '/^Xray/{print $2}'))：运行中"
elif [ -s "$HOME/lun/xr.json" ] && [ -x "$HOME/lun/xray" ]; then
echo "Xray：已安装，当前未运行"
elif [ -x "$HOME/lun/xray" ]; then
echo "Xray：内核已安装，当前协议未使用"
else
echo "Xray：未安装"
fi
}

argo_status_line(){
cf_running=no
for P in /proc/[0-9]*; do
[ -L "$P/exe" ] || continue
exe=$(readlink -f "$P/exe" 2>/dev/null) || continue
case "$exe" in
*/lun/cloudflared*) cf_running=yes ;;
esac
done
if [ "$cf_running" = "no" ]; then
pgrep -f 'lun/cloudflared' >/dev/null 2>&1 && cf_running=yes
fi
if [ "$cf_running" = "no" ]; then
systemctl is-active --quiet argo 2>/dev/null && cf_running=yes
fi
if [ "$cf_running" = "no" ] && rc-service argo status >/dev/null 2>&1; then
cf_running=yes
fi
if [ "$cf_running" = "yes" ]; then
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
requested_subport="$subpt"
elif [ -s "$HOME/lun/subport.log" ]; then
requested_subport=$(cat "$HOME/lun/subport.log" 2>/dev/null)
else
requested_subport=
fi
subport=$(select_subscription_port "$requested_subport") || { echo "订阅服务无法取得可用端口，已跳过。"; return 1; }
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
if [ -n "$v4" ]; then
server_ip="$v4"
printf '%s\n' "$server_ip" > "$HOME/lun/server_ip.log"
elif [ -n "$v6" ]; then
server_ip=$(uri_host "$v6")
printf '%s\n' "$server_ip" > "$HOME/lun/server_ip.log"
else
ipbest
fi
if [ -n "$v6" ]; then
server_ip6=$(uri_host "$v6")
printf '%s\n' "$server_ip6" > "$HOME/lun/server_ip6.log"
else
rm -f "$HOME/lun/server_ip6.log"
fi
}
ipchange
rm -rf "$HOME/lun/jhsub.txt"
rm -f "$HOME/lun/.cdn_sbox_entries" "$HOME/lun/.cdn_sbox_tags" "$HOME/lun/.cdn_clash_entries" "$HOME/lun/.cdn_clash_names"
uuid=$(cat "$HOME/lun/uuid")
server_ip=$(cat "$HOME/lun/server_ip.log")
sxname=$(cat "$HOME/lun/name" 2>/dev/null)
xvvmcdnym=$(cat "$HOME/lun/cdnym" 2>/dev/null)
argoip_cfg=$(cat "$HOME/lun/argoip" 2>/dev/null)
[ -z "$argoip_cfg" ] && argoip_cfg="162.159.192.1 162.159.192.2"
direct_entries=$(direct_address_entries)
if [ -z "$direct_entries" ]; then
echo "当前地址输出模式 $(address_mode_label) 没有可用地址，请在高级设置中重新选择。"
return 1
fi
primary_entry=$(printf '%s\n' "$direct_entries" | sed -n '1p')
client_addr_raw=${primary_entry%%|*}
primary_name_suffix=${primary_entry#*|}
client_addr=$(uri_host "$client_addr_raw")
client_addr_json=$(json_host "$client_addr_raw")
node_name_suffix="-$primary_name_suffix"
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
new_suffix=$3
old_uri=$(uri_host "$client_addr_raw")
new_uri=$(uri_host "$new_addr")
old_json=$(json_host "$client_addr_raw")
new_json=$(json_host "$new_addr")
old_uri_esc=$(sed_escape "$old_uri")
new_uri_esc=$(sed_replacement_escape "$new_uri")
old_json_esc=$(sed_escape "$old_json")
new_json_esc=$(sed_replacement_escape "$new_json")
old_suffix_esc=$(sed_escape "-$primary_name_suffix")
new_suffix_esc=$(sed_replacement_escape "-$new_suffix")
case "$link" in
vmess://*)
payload=${link#vmess://}
json=$(printf '%s' "$payload" | base64 -d 2>/dev/null)
[ -z "$json" ] && printf '%s\n' "$link" && return
json=$(printf '%s' "$json" | sed "s/\"add\": \"$old_json_esc\"/\"add\": \"$new_json_esc\"/g; s/$old_suffix_esc\"/$new_suffix_esc\"/g")
printf 'vmess://%s\n' "$(printf '%s' "$json" | base64 -w0)"
;;
ss://*)
body=${link#ss://}
encoded=${body%%#*}
label=${body#*#}
raw=$(printf '%s' "$encoded" | base64 -d 2>/dev/null)
[ -z "$raw" ] && printf '%s\n' "$link" && return
raw=$(printf '%s' "$raw" | sed "s/@$old_uri_esc:/@$new_uri_esc:/g")
label=$(printf '%s' "$label" | sed "s/$old_suffix_esc\$/$new_suffix_esc/")
printf 'ss://%s#%s\n' "$(printf '%s' "$raw" | base64 -w0)" "$label"
;;
*)
printf '%s\n' "$link" | sed "s/@$old_uri_esc:/@$new_uri_esc:/g; s/$old_suffix_esc\$/$new_suffix_esc/"
;;
esac
}

append_share_link(){
link=$1
for entry in $direct_entries; do
entry_addr=${entry%%|*}
entry_suffix=${entry#*|}
if [ "$entry_addr" = "$client_addr_raw" ] && [ "$entry_suffix" = "$primary_name_suffix" ]; then
output_link=$link
else
output_link=$(replace_link_addr "$link" "$entry_addr" "$entry_suffix")
fi
printf '%s\n' "$output_link" >> "$HOME/lun/jhsub.txt"
printf '%s\n' "$output_link"
done
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
echo "【 Vless-xhttp-reality-enc 】支持ENC加密，节点信息如下："
port_xh=$(cat "$HOME/lun/port_xh")
client_port_xh=$(client_port "$port_xh")
vl_xh_link="vless://$uuid@$client_addr:$client_port_xh?encryption=$enkey&flow=xtls-rprx-vision&security=reality&sni=$ym_vl_re&fp=chrome&pbk=$public_key_x&sid=$short_id_x&type=xhttp&path=$uuid-xh&mode=auto#${sxname}vl-xhttp-reality-enc-$hostname$node_name_suffix"
append_share_link "$vl_xh_link"
[ -f "$HOME/lun/cdnym" ] && cdn_skip "VLESS XHTTP Reality 不套用普通橙云 CDN，Reality SNI/回源逻辑保持独立，已保留直连节点。"
echo
fi
if grep vless-xhttp "$HOME/lun/xr.json" >/dev/null 2>&1; then
echo "【 Vless-xhttp-enc 】支持ENC加密，节点信息如下："
port_vx=$(cat "$HOME/lun/port_vx")
client_port_vx=$(client_port "$port_vx")
vx_direct_extra="&security=none"
if cdn_origin_tls_for_port "$port_vx"; then
vx_direct_extra="&host=$xvvmcdnym&security=tls&sni=$xvvmcdnym&fp=chrome&insecure=$generic_link_insecure&allowInsecure=$generic_link_insecure"
fi
vl_vx_link="vless://$uuid@$client_addr:$client_port_vx?encryption=$enkey&flow=xtls-rprx-vision&type=xhttp&path=$uuid-vx&mode=auto$vx_direct_extra#${sxname}vl-xhttp-enc-$hostname$node_name_suffix"
append_share_link "$vl_vx_link"
echo
if [ -f "$HOME/lun/cdnym" ] && cdn_protocol_enabled xhttp; then
append_vless_cdn_links "Vless-xhttp-enc-cdn" "vl-xhttp-enc" "$port_vx" "encryption=$enkey&flow=xtls-rprx-vision&type=xhttp&path=$uuid-vx&mode=auto"
fi
fi
if grep xhttp-h3 "$HOME/lun/xr.json" >/dev/null 2>&1; then
echo "【 Vless-xhttp-tls-UDP 】节点信息如下："
port_xu=$(cat "$HOME/lun/port_xu")
client_port_xu=$(client_port "$port_xu")
vl_xu_link="vless://$uuid@$client_addr:$client_port_xu?encryption=none&security=tls&sni=$cert_sni&alpn=h3&fp=chrome&insecure=$generic_link_insecure&allowInsecure=$generic_link_insecure$generic_tls_pin_arg&type=xhttp&path=$uuid-xu&mode=auto#${sxname}vless-xhttp-tls-udp-$hostname$node_name_suffix"
append_share_link "$vl_xu_link"
[ -f "$HOME/lun/cdnym" ] && cdn_skip "VLESS XHTTP TLS UDP 为直连 QUIC/UDP 协议，不生成普通 CDN 变体。"
echo
clxupt(){
cat <<EOF
- name: ${sxname}vless-xhttp-tls-udp-$hostname$node_name_suffix
  type: vless
  server: $client_addr
  port: $client_port_xu
  uuid: $uuid
  udp: true
  tls: true
  network: xhttp
  alpn:
    - h3
  servername: $cert_sni
  client-fingerprint: chrome
  skip-cert-verify: $clash_skip_verify
  xhttp-opts:
    path: "$uuid-xu"
    mode: auto
EOF
}
clxupt1(){
echo "- ${sxname}vless-xhttp-tls-udp-$hostname$node_name_suffix"
}
fi
if grep xhttp-h23 "$HOME/lun/xr.json" >/dev/null 2>&1; then
echo "【 Vless-xhttp-tls-TCP/UDP 】直连节点信息如下："
port_xc=$(cat "$HOME/lun/port_xc")
client_port_xc=$(client_port "$port_xc")
vl_xc_link="vless://$uuid@$client_addr:$client_port_xc?encryption=none&security=tls&sni=$cert_sni&alpn=h2,http/1.1&fp=chrome&insecure=$generic_link_insecure&allowInsecure=$generic_link_insecure$generic_tls_pin_arg&type=xhttp&path=$uuid-xc&mode=auto#${sxname}vless-xhttp-tls-tcp-$hostname$node_name_suffix"
append_share_link "$vl_xc_link"
echo
clxcpt(){
cat <<EOF
- name: ${sxname}vless-xhttp-tls-tcp-$hostname$node_name_suffix
  type: vless
  server: $client_addr
  port: $client_port_xc
  uuid: $uuid
  udp: true
  tls: true
  network: xhttp
  alpn:
    - h2
    - http/1.1
  servername: $cert_sni
  client-fingerprint: chrome
  skip-cert-verify: $clash_skip_verify
  xhttp-opts:
    path: "$uuid-xc"
    mode: auto
EOF
}
clxcpt1(){
echo "- ${sxname}vless-xhttp-tls-tcp-$hostname$node_name_suffix"
}
if [ -f "$HOME/lun/cdnym" ] && cdn_protocol_enabled xhttp; then
append_xhttp_tls_cdn_links "$port_xc"
fi
fi
if grep vless-ws "$HOME/lun/xr.json" >/dev/null 2>&1; then
echo "【 Vless-ws-enc 】支持ENC加密，节点信息如下："
port_vw=$(cat "$HOME/lun/port_vw")
client_port_vw=$(client_port "$port_vw")
vw_direct_extra="&security=none"
if cdn_origin_tls_for_port "$port_vw"; then
vw_direct_extra="&host=$xvvmcdnym&security=tls&sni=$xvvmcdnym&fp=chrome&insecure=$generic_link_insecure&allowInsecure=$generic_link_insecure"
fi
vl_vw_link="vless://$uuid@$client_addr:$client_port_vw?encryption=$enkey&type=ws&path=$uuid-vw$vw_direct_extra#${sxname}vl-ws-enc-$hostname$node_name_suffix"
append_share_link "$vl_vw_link"
echo
if [ -f "$HOME/lun/cdnym" ] && cdn_protocol_enabled ws; then
append_vless_cdn_links "Vless-ws-enc-cdn" "vl-ws-enc" "$port_vw" "encryption=$enkey&type=ws&path=$uuid-vw"
fi
fi
if grep reality-vision "$HOME/lun/xr.json" >/dev/null 2>&1; then
echo "【 Vless-tcp-reality-vision 】节点信息如下："
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
echo "【 Shadowsocks-2022 】节点信息如下："
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
echo "【 Vmess-ws 】节点信息如下："
port_vm_ws=$(cat "$HOME/lun/port_vm_ws")
client_port_vm_ws=$(client_port "$port_vm_ws")
vm_direct_host=www.bing.com
vm_direct_tls=
vm_direct_tls_enabled=false
if cdn_origin_tls_for_port "$port_vm_ws"; then
vm_direct_host=$xvvmcdnym
vm_direct_tls=tls
vm_direct_tls_enabled=true
fi
vm_link="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"${sxname}vm-ws-$hostname$node_name_suffix\", \"add\": \"$client_addr_json\", \"port\": \"$client_port_vm_ws\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$vm_direct_host\", \"path\": \"/$uuid-vm\", \"tls\": \"$vm_direct_tls\", \"sni\": \"$vm_direct_host\", \"allowInsecure\": \"$generic_link_insecure\"}" | base64 -w0)"
append_share_link "$vm_link"
echo
sbvmpt(){
cat <<EOF
{
            "server": "$client_addr",
            "server_port": $client_port_vm_ws,
            "tag": "${sxname}vmess-$hostname$node_name_suffix",
            "tls": {
                "enabled": $vm_direct_tls_enabled,
                "server_name": "$vm_direct_host",
                "insecure": $sbox_tls_insecure,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$vm_direct_host"
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
  tls: $vm_direct_tls_enabled
  network: ws
  servername: $vm_direct_host
  skip-cert-verify: $clash_skip_verify
  ws-opts:
    path: "$uuid-vm"
    headers:
      Host: $vm_direct_host
EOF
}
clvmpt1(){
echo "- ${sxname}vmess-ws-$hostname$node_name_suffix"
}
if [ -f "$HOME/lun/cdnym" ] && cdn_protocol_enabled vmess; then
append_vmess_cdn_links "$port_vm_ws"
fi
fi
if grep naive-sb "$HOME/lun/sb.json" >/dev/null 2>&1; then
echo "【 NaiveProxy H2/H3 】节点信息如下："
port_nv=$(cat "$HOME/lun/port_nv")
client_port_nv=$(client_port "$port_nv")
nv_https_link="naive+https://$uuid:$uuid@$client_addr:$client_port_nv?security=tls&sni=$cert_sni&insecure=0&allowInsecure=0#${sxname}naive-h2-$hostname$node_name_suffix"
nv_quic_link="naive+quic://$uuid:$uuid@$client_addr:$client_port_nv?congestion_control=bbr&security=tls&sni=$cert_sni&insecure=0&allowInsecure=0#${sxname}naive-h3-$hostname$node_name_suffix"
nv_http2_link="http2://$uuid:$uuid@$client_addr:$client_port_nv?security=tls&sni=$cert_sni&insecure=0&allowInsecure=0&padding=1&tfo=1#${sxname}naive-h2-$hostname$node_name_suffix"
nv_http3_link="http3://$uuid:$uuid@$client_addr:$client_port_nv?security=tls&sni=$cert_sni&insecure=0&allowInsecure=0&padding=1&tfo=1#${sxname}naive-h3-$hostname$node_name_suffix"
echo "V2rayN / Karing / NekoBox："
append_share_link "$nv_https_link"
append_share_link "$nv_quic_link"
echo "Shadowrocket："
append_share_link "$nv_http2_link"
append_share_link "$nv_http3_link"
[ -f "$HOME/lun/cdnym" ] && cdn_skip "NaiveProxy 使用公开域名证书直连，不生成普通 CDN 变体。"
echo "NaiveProxy 已写入 Sing-box 订阅；Clash/Mihomo 暂不支持 Naive，未写入 Clash 订阅。"
echo
sbnvpt(){
cat <<EOF
    {
      "type": "naive",
      "tag": "${sxname}naive-h3-$hostname$node_name_suffix",
      "server": "$client_addr",
      "server_port": $client_port_nv,
      "username": "$uuid",
      "password": "$uuid",
      "udp_over_tcp": false,
      "quic": true,
      "quic_congestion_control": "bbr",
      "tls": {
        "enabled": true,
        "server_name": "$cert_sni"
      }
    },
    {
      "type": "naive",
      "tag": "${sxname}naive-h2-$hostname$node_name_suffix",
      "server": "$client_addr",
      "server_port": $client_port_nv,
      "username": "$uuid",
      "password": "$uuid",
      "udp_over_tcp": true,
      "quic": false,
      "tls": {
        "enabled": true,
        "server_name": "$cert_sni"
      }
    },
EOF
}
sbnvpt1(){
echo "\"${sxname}naive-h3-$hostname$node_name_suffix\","
echo "\"${sxname}naive-h2-$hostname$node_name_suffix\","
}
fi
if grep anytls-sb "$HOME/lun/sb.json" >/dev/null 2>&1; then
echo "【 AnyTLS 】节点信息如下："
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
echo "【 Any-Reality 】节点信息如下："
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
echo "【 Hysteria2 】节点信息如下："
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
echo "【 Tuic 】节点信息如下："
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
echo "【 Socks5 】客户端信息如下："
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
argo_entries=
argo_index=0
argo_seen=
for argo_addr in $argoip_cfg; do
argo_addr=$(json_host "$argo_addr")
[ -n "$argo_addr" ] || continue
case " $argo_seen " in *" $argo_addr "*) continue ;; esac
argo_seen="${argo_seen:+$argo_seen }$argo_addr"
argo_index=$((argo_index + 1))
argo_suffix="$(endpoint_kind "$argo_addr")-$(printf '%02d' "$argo_index")"
argo_entries="$argo_entries $argo_addr|$argo_suffix"
done

argo_links_display=
if [ "$vlvm" = "Vmess" ]; then
for argo_entry in $argo_entries; do
argo_addr=${argo_entry%%|*}
argo_suffix=${argo_entry#*|}
tls_name="${sxname}vmess-ws-argo-TLS-443-$hostname-$argo_suffix"
http_name="${sxname}vmess-ws-argo-HTTP-80-$hostname-$argo_suffix"
tls_link="vmess://$(printf '%s' "{ \"v\": \"2\", \"ps\": \"$tls_name\", \"add\": \"$argo_addr\", \"port\": \"443\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$uuid-vm\", \"tls\": \"tls\", \"sni\": \"$argodomain\", \"fp\": \"chrome\"}" | base64 -w0)"
http_link="vmess://$(printf '%s' "{ \"v\": \"2\", \"ps\": \"$http_name\", \"add\": \"$argo_addr\", \"port\": \"80\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/$uuid-vm\", \"tls\": \"\"}" | base64 -w0)"
printf '%s\n%s\n' "$tls_link" "$http_link" >> "$HOME/lun/jhsub.txt"
argo_links_display="$argo_links_display
$tls_link
$http_link"
done
sbvmargopt(){
for argo_entry in $argo_entries; do
argo_addr=${argo_entry%%|*}; argo_suffix=${argo_entry#*|}
for argo_mode in tls http; do
if [ "$argo_mode" = tls ]; then argo_port=443; argo_tls=true; argo_label=TLS; else argo_port=80; argo_tls=false; argo_label=HTTP; fi
cat <<EOF
{
  "server": "$argo_addr",
  "server_port": $argo_port,
  "tag": "${sxname}vmess-ws-argo-$argo_label-$argo_port-$hostname-$argo_suffix",
  "tls": {"enabled": $argo_tls, "server_name": "$argodomain", "insecure": false, "utls": {"enabled": true, "fingerprint": "chrome"}},
  "packet_encoding": "packetaddr",
  "transport": {"headers": {"Host": ["$argodomain"]}, "path": "/$uuid-vm", "type": "ws"},
  "type": "vmess",
  "security": "auto",
  "uuid": "$uuid"
},
EOF
done
done
}
sbvmargopt1(){
for argo_entry in $argo_entries; do argo_suffix=${argo_entry#*|}; echo "\"${sxname}vmess-ws-argo-TLS-443-$hostname-$argo_suffix\","; echo "\"${sxname}vmess-ws-argo-HTTP-80-$hostname-$argo_suffix\","; done
}
clvmargopt(){
for argo_entry in $argo_entries; do
argo_addr=${argo_entry%%|*}; argo_suffix=${argo_entry#*|}
for argo_mode in tls http; do
if [ "$argo_mode" = tls ]; then argo_port=443; argo_tls=true; argo_label=TLS; else argo_port=80; argo_tls=false; argo_label=HTTP; fi
cat <<EOF
- name: ${sxname}vmess-ws-argo-$argo_label-$argo_port-$hostname-$argo_suffix
  type: vmess
  server: "$argo_addr"
  port: $argo_port
  uuid: $uuid
  alterId: 0
  cipher: auto
  udp: true
  tls: $argo_tls
  network: ws
  servername: $argodomain
  ws-opts:
    path: "/$uuid-vm"
    headers:
      Host: $argodomain
EOF
done
done
}
clvmargopt1(){
for argo_entry in $argo_entries; do argo_suffix=${argo_entry#*|}; echo "- ${sxname}vmess-ws-argo-TLS-443-$hostname-$argo_suffix"; echo "- ${sxname}vmess-ws-argo-HTTP-80-$hostname-$argo_suffix"; done
}
elif [ "$vlvm" = "Vless" ]; then
for argo_entry in $argo_entries; do
argo_addr=${argo_entry%%|*}
argo_suffix=${argo_entry#*|}
argo_uri=$(uri_host "$argo_addr")
tls_link="vless://$uuid@$argo_uri:443?encryption=$enkey&type=ws&host=$argodomain&path=/$uuid-vw&security=tls&sni=$argodomain&fp=chrome&insecure=0&allowInsecure=0#${sxname}vless-ws-argo-TLS-443-$hostname-$argo_suffix"
http_link="vless://$uuid@$argo_uri:80?encryption=$enkey&type=ws&host=$argodomain&path=/$uuid-vw&security=none#${sxname}vless-ws-argo-HTTP-80-$hostname-$argo_suffix"
printf '%s\n%s\n' "$tls_link" "$http_link" >> "$HOME/lun/jhsub.txt"
argo_links_display="$argo_links_display
$tls_link
$http_link"
done
sbvmargopt(){
for argo_entry in $argo_entries; do
argo_addr=${argo_entry%%|*}; argo_suffix=${argo_entry#*|}
for argo_mode in tls http; do
if [ "$argo_mode" = tls ]; then argo_port=443; argo_tls=true; argo_label=TLS; else argo_port=80; argo_tls=false; argo_label=HTTP; fi
cat <<EOF
{
  "server": "$argo_addr",
  "server_port": $argo_port,
  "tag": "${sxname}vless-ws-argo-$argo_label-$argo_port-$hostname-$argo_suffix",
  "type": "vless",
  "uuid": "$uuid",
  "tls": {"enabled": $argo_tls, "server_name": "$argodomain", "insecure": false, "utls": {"enabled": true, "fingerprint": "chrome"}},
  "transport": {"headers": {"Host": ["$argodomain"]}, "path": "/$uuid-vw", "type": "ws"}
},
EOF
done
done
}
sbvmargopt1(){
for argo_entry in $argo_entries; do argo_suffix=${argo_entry#*|}; echo "\"${sxname}vless-ws-argo-TLS-443-$hostname-$argo_suffix\","; echo "\"${sxname}vless-ws-argo-HTTP-80-$hostname-$argo_suffix\","; done
}
clvmargopt(){
for argo_entry in $argo_entries; do
argo_addr=${argo_entry%%|*}; argo_suffix=${argo_entry#*|}
for argo_mode in tls http; do
if [ "$argo_mode" = tls ]; then argo_port=443; argo_tls=true; argo_label=TLS; else argo_port=80; argo_tls=false; argo_label=HTTP; fi
cat <<EOF
- name: ${sxname}vless-ws-argo-$argo_label-$argo_port-$hostname-$argo_suffix
  type: vless
  server: "$argo_addr"
  port: $argo_port
  uuid: $uuid
  network: ws
  udp: true
  tls: $argo_tls
  servername: $argodomain
  client-fingerprint: chrome
  ws-opts:
    path: "/$uuid-vw"
    headers:
      Host: $argodomain
EOF
done
done
}
clvmargopt1(){
for argo_entry in $argo_entries; do argo_suffix=${argo_entry#*|}; echo "- ${sxname}vless-ws-argo-TLS-443-$hostname-$argo_suffix"; echo "- ${sxname}vless-ws-argo-HTTP-80-$hostname-$argo_suffix"; done
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

已按 Argo 优选地址导出 TLS 443 与 HTTP 80 节点：$argo_links_display
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
for entry in $direct_entries; do
entry_addr=${entry%%|*}
entry_suffix=${entry#*|}
client_addr=$(json_host "$entry_addr")
client_addr_json=$client_addr
node_name_suffix="-$entry_suffix"
out=$($f)
[ -n "$out" ] && printf "%s\n" "$out"
done
client_addr=$(uri_host "$client_addr_raw")
client_addr_json=$(json_host "$client_addr_raw")
node_name_suffix="-$primary_name_suffix"
fi
}
sbxy="$(get_func sbvlpt; get_func sbsspt; get_func sbanpt; get_func sbarpt; get_func sbvmpt; get_func sbhypt; get_func sbtupt; get_func sbnvpt; get_func sbvmargopt; cat "$HOME/lun/.cdn_sbox_entries" 2>/dev/null)"
clxy="$(get_func clxupt; get_func clxcpt; get_func clvlpt; get_func clsspt; get_func clanpt; get_func clvmpt; get_func clhypt; get_func cltupt; get_func clvmargopt; cat "$HOME/lun/.cdn_clash_entries" 2>/dev/null)"
sbgz="$(get_func sbvlpt1; get_func sbsspt1; get_func sbanpt1; get_func sbarpt1; get_func sbvmpt1; get_func sbhypt1; get_func sbtupt1; get_func sbnvpt1; get_func sbvmargopt1; cat "$HOME/lun/.cdn_sbox_tags" 2>/dev/null)"
clgz="$({ get_func clxupt1; get_func clxcpt1; get_func clvlpt1; get_func clsspt1; get_func clanpt1; get_func clvmpt1; get_func clhypt1; get_func cltupt1; get_func clvmargopt1; cat "$HOME/lun/.cdn_clash_names" 2>/dev/null; } | sed '2,$s/^/    /')"
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
rm -f "$HOME/lun/.cdn_sbox_entries" "$HOME/lun/.cdn_sbox_tags" "$HOME/lun/.cdn_clash_entries" "$HOME/lun/.cdn_clash_names"
restart_subscription_service
if [ -s $HOME/lun/subport.log ]; then
showsubport=$(cat $HOME/lun/subport.log)
if ps -ef 2>/dev/null | grep "$showsubport" | grep -v grep >/dev/null; then
show_subscription_links
fi
fi
echo
echo "---------------------------------------------------------"
echo "$argoshow"
echo
echo "---------------------------------------------------------"
echo "聚合节点信息，请进入 $HOME/lun/jhsub.txt 文件目录查看或者运行 cat $HOME/lun/jhsub.txt 查看"
echo "========================================================="
showmode_short
}
create_rebuild_snapshot(){
rebuild_snapshot="$HOME/lun/.rebuild_snapshot"
rm -rf "$rebuild_snapshot"
mkdir -p "$rebuild_snapshot/lun" "$rebuild_snapshot/services" || return 1
for rebuild_file in "$HOME/lun"/*.json "$HOME/lun"/port_* "$HOME/lun"/sbargo* "$HOME/lun"/argo* "$HOME/lun"/name "$HOME/lun"/vlvm; do
[ -e "$rebuild_file" ] || continue
cp -a "$rebuild_file" "$rebuild_snapshot/lun/" || return 1
done
[ -f "$HOME/.bashrc" ] && cp -a "$HOME/.bashrc" "$rebuild_snapshot/bashrc"
crontab -l > "$rebuild_snapshot/crontab" 2>/dev/null || :
for rebuild_service in /etc/systemd/system/xr.service /etc/systemd/system/sb.service /etc/systemd/system/argo.service /etc/init.d/xray /etc/init.d/sing-box /etc/init.d/argo; do
[ -e "$rebuild_service" ] || continue
cp -a "$rebuild_service" "$rebuild_snapshot/services/$(basename "$rebuild_service")" || return 1
done
printf '%s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null)" > "$rebuild_snapshot/created_at"
return 0
}

rollback_rebuild(){
trap - HUP INT TERM EXIT
[ -n "$rebuild_snapshot" ] && [ -d "$rebuild_snapshot" ] || return 1
echo
echo "协议重建未完成，正在自动恢复上一次可用配置……"
rm -f "$HOME/lun"/*.json "$HOME/lun"/port_* "$HOME/lun"/sbargo* "$HOME/lun"/argo* "$HOME/lun"/name "$HOME/lun"/vlvm
cp -a "$rebuild_snapshot/lun/." "$HOME/lun/" 2>/dev/null || true
[ -f "$rebuild_snapshot/bashrc" ] && cp -a "$rebuild_snapshot/bashrc" "$HOME/.bashrc"
[ -s "$rebuild_snapshot/crontab" ] && crontab "$rebuild_snapshot/crontab" >/dev/null 2>&1 || true
if pidof systemd >/dev/null 2>&1; then
for rebuild_service in xr sb argo; do
[ -f "$rebuild_snapshot/services/$rebuild_service.service" ] && cp -a "$rebuild_snapshot/services/$rebuild_service.service" "/etc/systemd/system/$rebuild_service.service"
done
systemctl daemon-reload >/dev/null 2>&1 || true
[ -s "$HOME/lun/xr.json" ] && systemctl enable --now xr >/dev/null 2>&1 || true
[ -s "$HOME/lun/sb.json" ] && systemctl enable --now sb >/dev/null 2>&1 || true
[ -s "$HOME/lun/sbargotoken.log" ] && systemctl enable --now argo >/dev/null 2>&1 || true
elif command -v rc-service >/dev/null 2>&1; then
for rebuild_service in xray sing-box argo; do
[ -f "$rebuild_snapshot/services/$rebuild_service" ] && cp -a "$rebuild_snapshot/services/$rebuild_service" "/etc/init.d/$rebuild_service" && chmod +x "/etc/init.d/$rebuild_service"
done
[ -s "$HOME/lun/xr.json" ] && rc-service xray restart >/dev/null 2>&1 || true
[ -s "$HOME/lun/sb.json" ] && rc-service sing-box restart >/dev/null 2>&1 || true
fi
restart_subscription_service >/dev/null 2>&1 || true
echo "已恢复上一次配置。"
return 0
}

validate_rebuild(){
rebuild_configs=0
if [ -s "$HOME/lun/xr.json" ]; then
rebuild_configs=$((rebuild_configs + 1))
"$HOME/lun/xray" run -test -c "$HOME/lun/xr.json" >/dev/null 2>&1 || { echo "Xray 新配置校验失败。"; return 1; }
fi
if [ -s "$HOME/lun/sb.json" ]; then
rebuild_configs=$((rebuild_configs + 1))
"$HOME/lun/sing-box" check -c "$HOME/lun/sb.json" >/dev/null 2>&1 || { echo "Sing-box 新配置校验失败。"; return 1; }
fi
[ "$rebuild_configs" -gt 0 ] || { echo "没有生成任何协议配置。"; return 1; }
return 0
}

commit_rebuild_snapshot(){
trap - HUP INT TERM EXIT
last_snapshot="$HOME/lun/.last_good_rebuild"
rm -rf "$last_snapshot"
mv "$rebuild_snapshot" "$last_snapshot" 2>/dev/null || rm -rf "$rebuild_snapshot"
echo "协议配置重建完成，已保留一份上次可用快照。"
}

cleandel(){
keep_entry=$1
stop_lun_owned_processes
[ -f ~/.bashrc ] || touch ~/.bashrc
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
rm -f /etc/systemd/system/xr.service /etc/systemd/system/sb.service /etc/systemd/system/argo.service
elif command -v rc-service >/dev/null 2>&1; then
for svc in sing-box xray argo; do
rc-service "$svc" stop >/dev/null 2>&1
rc-update del "$svc" default >/dev/null 2>&1
done
rm -f /etc/init.d/sing-box /etc/init.d/xray /etc/init.d/argo /etc/local.d/alpinelun.start /etc/local.d/alpinesublun.start
iptables -t nat -F PREROUTING >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
rc-service iptables save >/dev/null 2>&1
rc-service ip6tables save >/dev/null 2>&1
fi
}
factory_reset(){
printf "%s警告：此操作将清空所有配置（端口、域名、协议、UUID等），保留内核和脚本！%s\n" "$LUN_RED" "$LUN_RESET"
printf "确认清空配置？输入 yes 确认，其他取消："
IFS= read -r confirm
[ "$confirm" = "yes" ] || { echo "已取消。"; return 1; }
stop_lun_owned_processes
rm -f "$HOME/lun"/port_vl_re "$HOME/lun"/port_xh "$HOME/lun"/port_vx "$HOME/lun"/port_vw "$HOME/lun"/port_ss "$HOME/lun"/port_an "$HOME/lun"/port_ar "$HOME/lun"/port_vm_ws "$HOME/lun"/port_so "$HOME/lun"/port_hy2 "$HOME/lun"/port_tu "$HOME/lun"/port_xu "$HOME/lun"/port_xc "$HOME/lun"/port_nv
rm -f "$HOME/lun"/uuid "$HOME/lun"/domain "$HOME/lun"/cert_mode "$HOME/lun"/cert_subject "$HOME/lun"/cert_source "$HOME/lun"/cert.crt "$HOME/lun"/private.key "$HOME/lun"/SHA256.txt
rm -f "$HOME/lun"/vps_mode "$HOME/lun"/port_map "$HOME/lun"/port_pool "$HOME/lun"/inner_port_pool "$HOME/lun"/outer_port_pool
rm -f "$HOME/lun"/acme_email "$HOME/lun"/acme_dns "$HOME/lun"/cert.env
rm -f "$HOME/lun"/sub* "$HOME/lun"/cdn* "$HOME/lun"/argo* "$HOME/lun"/warp* "$HOME/lun"/name "$HOME/lun"/ipp*
rm -f "$HOME/lun/address_mode"
rm -f "$HOME/lun"/xr.json "$HOME/lun"/sb.json "$HOME/lun"/addym "$HOME/lun"/addout
rm -f "$HOME/lun"/cfip* "$HOME/lun"/xvvmcdnym "$HOME/lun"/ym_vl_re "$HOME/lun"/argoport.log "$HOME/lun"/argo.log "$HOME/lun"/sbargoym.log "$HOME/lun"/sbargotoken.log
rm -f "$HOME/lun"/subport.log "$HOME/lun"/subtoken.log "$HOME/lun"/subip_mode
rm -rf "$HOME/lun"/xrk "$HOME/weblun" "$HOME/agsbx" "$HOME/websbx" sbx_update
echo "配置已全部清空，内核和脚本已保留。"
echo "请重新运行 lun 引导式安装来配置协议。"
sleep 2
return 0
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
unset vlp vmp vwp hyp tup xhp vxp anp ssp arp sop xup xcp nvp vmag
unset port_vl_re port_vm_ws port_vw port_hy2 port_tu port_xh port_vx port_an port_ar port_ss port_so port_xu port_xc port_nv
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
[ -z "${xupt+x}" ] || { xup=yes; port_xu=$xupt; }
[ -z "${xcpt+x}" ] || { xcp=yes; port_xc=$xcpt; }
[ -z "${nvpt+x}" ] || { nvp=yes; port_nv=$nvpt; }
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
echo "12. VLESS XHTTP TLS UDP"
echo "13. VLESS XHTTP TLS TCP/UDP"
echo "14. NaiveProxy H2/H3（需公开可信证书）"
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
12) prompt_port "VLESS XHTTP TLS UDP" xupt ;;
13) prompt_port "VLESS XHTTP TLS TCP/UDP" xcpt ;;
14) prompt_port "NaiveProxy H2/H3" nvpt ;;
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
green_line "================================================================================"
yellow_line "  Lun 风火轮多协议交互面板"
green_line "================================================================================"
cyan_line " 1. 安装 Lun / 新建协议"
cyan_line " 2. 增删改协议变量组 (rep)"
cyan_line " 3. 查看节点与订阅 (list)"
cyan_line " 4. 设置自定义节点地址 addym/addout"
cyan_line " 5. 重启 Lun 进程"
cyan_line " 6. 更新 Xray 内核"
cyan_line " 7. 更新 Sing-box 内核"
cyan_line " 8. 更新 Lun 脚本"
cyan_line " 9. 卸载 Lun"
cyan_line " 0. 退出"
printf "请输入数字【0-9】（%s回车退出%s）：" "$LUN_YELLOW" "$LUN_RESET"
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
ui_pause(){ printf "%s按回车返回菜单%s：" "$LUN_YELLOW" "$LUN_RESET"; IFS= read -r _pause; }
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
LUN_RED=$(tput setaf 1 2>/dev/null)
LUN_GREEN=$(tput setaf 2 2>/dev/null)
LUN_YELLOW=$(tput setaf 3 2>/dev/null)
LUN_BLUE=$(tput setaf 4 2>/dev/null)
LUN_CYAN=$(tput setaf 6 2>/dev/null)
LUN_WHITE=$(tput setaf 7 2>/dev/null)
LUN_BOLD=$(tput bold 2>/dev/null)
LUN_RESET=$(tput sgr0 2>/dev/null)
else
LUN_RED=
LUN_GREEN=
LUN_YELLOW=
LUN_BLUE=
LUN_CYAN=
LUN_WHITE=
LUN_BOLD=
LUN_RESET=
fi
green_line(){ printf '%s%s%s\n' "$LUN_GREEN" "$1" "$LUN_RESET"; }
yellow_line(){ printf '%s%s%s\n' "$LUN_YELLOW" "$1" "$LUN_RESET"; }
red_line(){ printf '%s%s%s\n' "$LUN_RED" "$1" "$LUN_RESET"; }
cyan_line(){ printf '%s%s%s\n' "$LUN_CYAN" "$1" "$LUN_RESET"; }
yellow_hint(){ printf '%s%s%s' "$LUN_YELLOW" "$1" "$LUN_RESET"; }

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

protocol_port_reserved(){
p=$1
p_public=$(client_port "$p")
for used in "$port_xh" "$port_vx" "$port_vw" "$port_vl_re" "$port_ss" "$port_an" "$port_ar" "$port_vm_ws" "$port_so" "$port_hy2" "$port_tu" "$port_xu" "$port_xc" "$port_nv"; do
[ -n "$used" ] || continue
[ -n "${LUN_IGNORE_PROTOCOL_PORT:-}" ] && [ "$used" = "$LUN_IGNORE_PROTOCOL_PORT" ] && continue
used_public=$(client_port "$used")
[ "$used" = "$p" ] && return 0
[ "$used_public" = "$p" ] && return 0
[ "$used" = "$p_public" ] && return 0
[ "$used_public" = "$p_public" ] && return 0
done
for file in "$HOME/lun/port_xh" "$HOME/lun/port_vx" "$HOME/lun/port_vw" "$HOME/lun/port_vl_re" "$HOME/lun/port_ss" "$HOME/lun/port_an" "$HOME/lun/port_ar" "$HOME/lun/port_vm_ws" "$HOME/lun/port_so" "$HOME/lun/port_hy2" "$HOME/lun/port_tu" "$HOME/lun/port_xu" "$HOME/lun/port_xc" "$HOME/lun/port_nv"; do
[ -s "$file" ] || continue
used=$(cat "$file" 2>/dev/null)
[ -n "$used" ] || continue
[ -n "${LUN_IGNORE_PROTOCOL_PORT:-}" ] && [ "$used" = "$LUN_IGNORE_PROTOCOL_PORT" ] && continue
used_public=$(client_port "$used")
[ "$used" = "$p" ] && return 0
[ "$used_public" = "$p" ] && return 0
[ "$used" = "$p_public" ] && return 0
[ "$used_public" = "$p_public" ] && return 0
done
return 1
}

port_reserved(){
p=$1
protocol_port_reserved "$p" && return 0
p_public=$(client_port "$p")
for used in "$subpt" "$(cat "$HOME/lun/subport.log" 2>/dev/null)"; do
[ -n "$used" ] || continue
used_public=$(client_port "$used")
[ "$used" = "$p" ] && return 0
[ "$used_public" = "$p" ] && return 0
[ "$used" = "$p_public" ] && return 0
[ "$used_public" = "$p_public" ] && return 0
done
return 1
}

subscription_port_available(){
p=$1
port_valid "$p" || return 1
protocol_port_reserved "$p" && return 1
port_in_use "$p" && return 1
return 0
}

subscription_port_preferred(){
public=$(client_port "$1")
[ "$public" -ge 10000 ] 2>/dev/null
}

random_subscription_port(){
if is_nat_mode; then
candidates=
for pair in $ptmap; do
candidates="$candidates ${pair#*-}"
done
[ -n "$inpool" ] || [ -z "$portpool" ] || inpool=$portpool
if [ -n "$inpool" ]; then
candidates="$candidates $(port_pool_inner_candidates 2>/dev/null)"
fi
[ -n "$candidates" ] || {
echo "NAT VPS 没有可用映射，无法自动分配可访问的订阅端口。" >&2
return 1
}
shuffled=$(printf '%s\n' $candidates | awk 'NF && !seen[$0]++' | shuf 2>/dev/null)
for p in $shuffled; do
subscription_port_preferred "$p" || continue
subscription_port_available "$p" && { printf '%s\n' "$p"; return 0; }
done
for p in $shuffled; do
subscription_port_available "$p" && { printf '%s\n' "$p"; return 0; }
done
echo "NAT 映射中的端口都已被协议或其他进程占用，请增加映射。" >&2
return 1
fi

if [ -n "$inpool" ] || [ -n "$portpool" ]; then
shuffled=$(port_pool_inner_candidates | awk 'NF && !seen[$0]++' | shuf 2>/dev/null)
for p in $shuffled; do
subscription_port_preferred "$p" || continue
subscription_port_available "$p" && { printf '%s\n' "$p"; return 0; }
done
for p in $shuffled; do
subscription_port_available "$p" && { printf '%s\n' "$p"; return 0; }
done
fi
for _try in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
p=$(shuf -i 20000-65535 -n 1)
subscription_port_available "$p" && { printf '%s\n' "$p"; return 0; }
done
echo "没有找到可用的订阅端口，请手动设置端口或扩容端口池。" >&2
return 1
}

select_subscription_port(){
requested=$1
[ -n "$requested" ] && {
mapped_inner=$(inner_port_from_public "$requested")
[ -n "$mapped_inner" ] && requested=$mapped_inner
}
stop_subscription_service
sleep 1
if [ -n "$requested" ] && subscription_port_available "$requested"; then
printf '%s\n' "$requested"
return 0
fi
selected=$(random_subscription_port) || return 1
if [ -n "$requested" ] && [ "$selected" != "$requested" ]; then
old_public=$(client_port "$requested")
new_public=$(client_port "$selected")
if is_nat_mode; then
green_line "订阅端口冲突：已从公网 $old_public / 内网 $requested 自动改为公网 $new_public / 内网 $selected。" >&2
else
green_line "订阅端口 $requested 冲突，已自动改为 $selected。" >&2
fi
fi
printf '%s\n' "$selected"
}

random_nat_port(){
is_nat_mode || { random_port; return $?; }
nat_inner_ports=
for pair in $ptmap; do
nat_inner_ports="$nat_inner_ports ${pair#*-}"
done
if [ -n "$nat_inner_ports" ]; then
candidates=$(echo "$nat_inner_ports" | tr ' ' '\n' | shuf 2>/dev/null)
for p in $candidates; do
[ -n "$p" ] || continue
port_valid "$p" || continue
port_reserved "$p" && continue
port_in_use "$p" || { printf '%s\n' "$p"; return 0; }
done
fi
if [ -n "$inpool" ] || [ -n "$portpool" ]; then
candidates=$(port_pool_inner_candidates | shuf 2>/dev/null)
for p in $candidates; do
port_valid "$p" || continue
port_reserved "$p" && continue
port_in_use "$p" || { printf '%s\n' "$p"; return 0; }
done
fi
for _try in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
p=$(shuf -i 10000-65535 -n 1)
port_reserved "$p" && continue
port_in_use "$p" || { printf '%s\n' "$p"; return; }
done
echo "没有找到可用端口，请扩容端口池或手动输入端口。" >&2
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
for _try in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
p=$(shuf -i 10000-65535 -n 1)
port_reserved "$p" && continue
port_in_use "$p" || { printf '%s\n' "$p"; return; }
done
echo "没有找到可用端口，请扩容端口池或手动输入端口。" >&2
return 1
}

random_cdn_port(){
cdn_kind=$1
case "$cdn_kind" in
http) cf_candidates=$(cf_http_port_list) ;;
https) cf_candidates=$(cf_https_random_port_list) ;;
*) return 1 ;;
esac

if is_nat_mode; then
mapped_candidates=
for public_candidate in $cf_candidates; do
inner_candidate=$(inner_port_from_public "$public_candidate") || continue
[ -n "$inner_candidate" ] || continue
mapped_candidates="$mapped_candidates $inner_candidate"
done
[ -n "$mapped_candidates" ] || return 1
candidates=$(printf '%s\n' $mapped_candidates | awk 'NF && !seen[$0]++' | shuf 2>/dev/null)
elif [ -n "$inpool" ] || [ -n "$portpool" ]; then
pooled_candidates=
for pool_candidate in $(port_pool_inner_candidates); do
cf_port_matches_kind "$cdn_kind" "$pool_candidate" || continue
pooled_candidates="$pooled_candidates $pool_candidate"
done
[ -n "$pooled_candidates" ] || return 1
candidates=$(printf '%s\n' $pooled_candidates | awk 'NF && !seen[$0]++' | shuf 2>/dev/null)
else
candidates=$(printf '%s\n' $cf_candidates | shuf 2>/dev/null)
fi

for p in $candidates; do
port_valid "$p" || continue
port_reserved "$p" && continue
port_in_use "$p" && continue
public_candidate=$(client_port "$p")
cf_port_matches_kind "$cdn_kind" "$public_candidate" || continue
printf '%s\n' "$p"
return 0
done
return 1
}

prompt_port(){
label=$1
var=$2
LUN_IGNORE_PROTOCOL_PORT=${3:-}
cdn_kind=${4:-}
while :; do
if is_nat_mode; then
[ -n "$ptmap" ] && { show_port_map_list "$ptmap"; echo "这里请填写内网监听端口或对应公网端口。"; }
[ -n "$inpool" ] && echo "当前内网端口池：$inpool"
[ -n "$outpool" ] && echo "当前外网端口池：$outpool（按位置映射内网池）"
printf "请输入 %s 内网端口（%s回车随机%s，0 返回）：" "$label" "$LUN_YELLOW" "$LUN_RESET"
else
[ -n "$inpool" ] && echo "当前端口池：$inpool"
printf "请输入 %s 端口（%s回车随机%s，0 返回）：" "$label" "$LUN_YELLOW" "$LUN_RESET"
fi
IFS= read -r val
[ "$val" = "0" ] && { unset LUN_IGNORE_PROTOCOL_PORT; return 2; }
if [ -z "$val" ]; then
if [ -n "$cdn_kind" ]; then
if val=$(random_cdn_port "$cdn_kind" 2>/dev/null); then
public_candidate=$(client_port "$val")
echo "已优先选择未占用的 $(cf_port_kind_label "$cdn_kind")端口：$public_candidate"
else
yellow_line "$label 没有匹配的未占用 $(cf_port_kind_label "$cdn_kind")端口，将使用普通随机端口；后续使用 CDN 时必须配置 Cloudflare Origin Rules。"
if is_nat_mode && [ -n "$ptmap" ]; then
val=$(random_nat_port) || { echo "无法从NAT映射表取得可用端口。"; continue; }
echo "从NAT映射表随机内网端口：$val"
else
val=$(random_port) || { echo "无法从端口池取得可用端口。"; continue; }
echo "随机端口：$val"
fi
fi
elif is_nat_mode && [ -n "$ptmap" ]; then
val=$(random_nat_port) || { echo "无法从NAT映射表取得可用端口。"; continue; }
echo "从NAT映射表随机内网端口：$val"
else
val=$(random_port) || { echo "无法从端口池取得可用端口。"; continue; }
echo "随机端口：$val"
fi
fi
mapped_inner=$(inner_port_from_public "$val")
if [ -n "$mapped_inner" ]; then
echo "检测到你输入的是公网端口 $val，已转换为内网监听端口 $mapped_inner。"
val="$mapped_inner"
fi
if [ -n "${LUN_IGNORE_PROTOCOL_PORT:-}" ] && [ "$val" = "$LUN_IGNORE_PROTOCOL_PORT" ]; then
echo "$label 端口未改变。"
eval "export $var=\"\$val\""
unset LUN_IGNORE_PROTOCOL_PORT
return 3
fi
if ! port_valid "$val"; then
echo "端口必须是 1-65535 的数字。"
continue
fi
if [ -n "$cdn_kind" ]; then
public_val=$(client_port "$val")
if ! cf_port_matches_kind "$cdn_kind" "$public_val"; then
yellow_line "$label 当前公网端口 $public_val 不在 $(cf_port_kind_label "$cdn_kind")官方端口组内；后续使用 CDN 时必须按菜单配置 Origin Rules（Host + Path → 当前源站端口）。"
fi
fi
if port_reserved "$val"; then
public_val=$(client_port "$val")
if [ "$public_val" != "$val" ]; then
echo "端口 $val 或对应公网端口 $public_val 已被当前 Lun 协议/订阅占用，请换一个。"
else
echo "端口 $val 已被当前 Lun 协议/订阅占用，请换一个。"
fi
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
unset LUN_IGNORE_PROTOCOL_PORT
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
[ -s "$HOME/lun/port_xu" ] && { xupt=$(cat "$HOME/lun/port_xu"); xup=yes; port_xu=$xupt; }
[ -s "$HOME/lun/port_xc" ] && { xcpt=$(cat "$HOME/lun/port_xc"); xcp=yes; port_xc=$xcpt; }
[ -s "$HOME/lun/port_nv" ] && { nvpt=$(cat "$HOME/lun/port_nv"); nvp=yes; port_nv=$nvpt; }
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
"TUIC:$HOME/lun/port_tu" \
"VLESS XHTTP TLS UDP:$HOME/lun/port_xu" \
"VLESS XHTTP TLS TCP/UDP:$HOME/lun/port_xc" \
"NaiveProxy H2/H3:$HOME/lun/port_nv"; do
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
if [ -f "$HOME/lun/cert.crt" ] && openssl x509 -in "$HOME/lun/cert.crt" -noout >/dev/null 2>&1; then
detected=$(cert_detect_mode "$HOME/lun/cert.crt")
case "$mode" in domain|dns|ip) display_mode=$mode ;; *) display_mode=$detected ;; esac
preferred_name=${domain:-$(cat "$HOME/lun/cdnym" 2>/dev/null)}
subject=$(cert_subject_from_file "$HOME/lun/cert.crt" "$preferred_name")
issuer=$(cert_issuer_text "$HOME/lun/cert.crt")
end=$(cert_expiry_cn "$HOME/lun/cert.crt")
status=$(cert_status_cn "$HOME/lun/cert.crt")
printf "证书类型：%s\n" "$(cert_mode_label "$display_mode")"
printf "证书主体：%s  状态：%s\n" "$subject" "$status"
printf "签发者：%s\n" "${issuer:-未知}"
printf "到期时间：%s\n" "${end:-未知}"
else
printf "证书类型：%s  主体：%s  状态：未生成\n" "$(cert_mode_label "$mode")" "$subject"
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
# 返回 http 或 https；端口不在列表内时仅表示不属于 Cloudflare 橙云官方端口。
cf_port_mode(){
case "$1" in
80|8080|8880|2052|2082|2086|2095) printf 'http\n' ;;
443|8443|2053|2083|2087|2096) printf 'https\n' ;;
*) return 1 ;;
esac
}

# ============ 读取 CDN 优选 IP/域名列表 ============
# 优先读取新列表文件 cdnip；旧的 cdnip1/cdnip2/... 继续兼容
# 跳过空值和 "-1"（兼容旧版残留），并用 valid_addym 校验格式
# 返回值：逐行输出有效的优选地址
cdn_ip_list(){
if [ -s "$HOME/lun/cdnip" ]; then
files="$HOME/lun/cdnip"
else
files=$(ls "$HOME/lun"/cdnip[0-9]* 2>/dev/null)
fi
seen=
for f in $files; do
[ -s "$f" ] || continue
for one in $(cat "$f" 2>/dev/null); do
case "$one" in ""|-1) continue ;; esac
valid_addym "$one" || continue
one=$(normalize_host "$one")
case " $seen " in *" $one "*) continue ;; esac
seen="${seen:+$seen }$one"
printf '%s\n' "$one"
done
done
}

# ============ 自动发现 CDN 优选地址 ============
# 仅使用 CDN Host 解析出的、且不等于本机公网地址的 IP；不再注入未经验证的第三方域名。
cdn_resolved_edge_ips(){
host=${cdnym:-$(cat "$HOME/lun/cdnym" 2>/dev/null)}
[ -n "$host" ] || return 1
resolved=$(resolve_domain_ips "$host")
[ -n "$resolved" ] || return 1
locals=$(local_public_ips)
for one in $resolved; do
is_local=no
for local_ip in $locals; do
[ "$one" = "$local_ip" ] && { is_local=yes; break; }
done
[ "$is_local" = no ] && printf '%s\n' "$one"
done | awk 'NF && !seen[$0]++'
}

cdn_default_ips(){
[ -n "$(cdn_ip_list)" ] && return 0
auto_ips=$(cdn_resolved_edge_ips)
[ -n "$auto_ips" ] || return 1
save_cdn_ip_list "$(printf '%s\n' "$auto_ips" | tr '\n' ' ')"
}

prune_legacy_cdn_defaults(){
current=$(cdn_ip_list)
[ -n "$current" ] || return 0
kept=
removed=no
for one in $current; do
case "$one" in
cloudflare-ech.com|www.visa.com.sg) removed=yes ;;
*) kept="${kept:+$kept }$one" ;;
esac
done
[ "$removed" = yes ] || return 0
if [ -n "$kept" ]; then save_cdn_ip_list "$kept"; else clear_cdn_ip_list; fi
yellow_line "已移除旧版自动加入、但未验证可用性的第三方优选域名；已有 IP 入口已保留。"
}

# ============ CDN 跳过提示 ============
# 当协议不支持 CDN 或缺少必要配置时，输出黄色提示信息
cdn_skip(){
yellow_line "CDN提示：$1"
}

# ============ 显示 CDN 端口建议 ============
# 遍历所有支持 CDN 的协议（VLESS XHTTP、VLESS XHTTP TLS、VLESS WS、VMess WS）
# 检查它们的公网端口是否在 Cloudflare 橙云支持端口列表内。
# 不在列表内也会输出普通 CDN/优选入口节点，只是不适合直接套 CF 橙云。
show_cdn_port_advice(){
echo "Cloudflare HTTP 端口：80/8080/8880/2052/2082/2086/2095。"
echo "Cloudflare HTTPS 端口：443/8443/2053/2083/2087/2096。"
echo "Cloudflare 支持但缓存已禁用：2052/2053/2082/2083/2086/2087/2095/2096/8880/8443。"
if cdn_rewrite_active; then
echo "当前模式：Origin Rules 端口改写。客户端连接 Cloudflare 边缘端口 ${cdnpt:-8080}，Cloudflare 再回源到每个协议的源站端口。"
is_cf_https_port "${cdnpt:-8080}" && echo "${cdnpt:-8080} 为 HTTPS：Lun 会启用源站 TLS；Cloudflare 自签证书使用 Full，匹配域名的有效证书可使用 Full (Strict)。"
cdn_has_xhttp_tls && ! is_cf_https_port "${cdnpt:-8080}" && echo "VLESS XHTTP TLS 不使用 HTTP 边缘端口，将单独使用 HTTPS 443；请按 Host + UUID-xc Path 配置 Origin Rules。"
else
echo "当前模式：普通 CDN 优选。客户端直接连接优选入口，端口与协议公网端口相同；不使用 Origin Rules。"
fi
found=
for item in \
"VLESS XHTTP:$HOME/lun/port_vx" \
"VLESS XHTTP TLS:$HOME/lun/port_xc" \
"VLESS WS:$HOME/lun/port_vw" \
"VMess WS:$HOME/lun/port_vm_ws"; do
label=${item%%:*}
file=${item#*:}
case "$label" in
"VLESS XHTTP") cdn_protocol_enabled xhttp || continue ;;
"VLESS XHTTP TLS") cdn_protocol_enabled xhttp || continue ;;
"VLESS WS") cdn_protocol_enabled ws || continue ;;
"VMess WS") cdn_protocol_enabled vmess || continue ;;
esac
[ -s "$file" ] || continue
found=yes
inner=$(cat "$file" 2>/dev/null)
public=$(client_port "$inner")
edge=$(cdn_client_port "$inner")
mode=$(cf_port_mode "$edge" 2>/dev/null || true)
if [ "$label" = "VLESS XHTTP TLS" ] && [ "$mode" != https ]; then
yellow_line "$label 仅生成 HTTPS CDN 节点；当前边缘端口 $edge 不是 Cloudflare HTTPS 端口。"
elif cdn_rewrite_active; then
if is_nat_mode; then
green_line "$label：Cloudflare 边缘端口 $edge → NAT 公网端口 $public → 内网监听端口 $inner。"
else
green_line "$label：Cloudflare 边缘端口 $edge → VPS 源站监听端口 $inner。"
fi
elif [ -n "$mode" ]; then
green_line "$label 可生成 CDN 变体：协议端口 $inner，客户端公网/边缘端口 $public，CF 模式 $mode。"
else
    yellow_line "$label 当前公网端口 $public 不在 CF 橙云官方端口内；可启用 Origin Rules 端口改写，或仅用于支持该端口的其它反代。"
fi
done
[ -n "$found" ] || yellow_line "当前没有 VMess WS / VLESS WS / VLESS XHTTP 非 Reality / VLESS XHTTP TLS，普通 CDN/优选入口不会生成节点；可使用 CF 隧道/Argo。"
is_nat_mode && yellow_line "NAT VPS：请先完成公网端口映射；若公网端口不是上表 CF 端口，必须再配置 Origin Rules 回源到该公网端口。"
}

# ============ 生成 VLESS CDN 优选节点链接 ============
# 参数：$1=节点标签  $2=基础名称  $3=协议端口  $4=URL查询参数
# 流程：
#   1. 检查 cdnym（回源Host域名）是否存在，没有则跳过
#   2. 获取公网端口，并按协议原有逻辑生成链接；CF 端口模式仅用于提示与 tls 推断
#   3. 读取 CDN 优选地址列表（cdnip 或旧 cdnip1/cdnip2/...）
#   4. 为每个优选地址生成一条 CDN 节点链接
# CDN 节点原理：add=优选地址（客户端连CF入口），host=回源域名（CF回源到VPS）
append_vless_cdn_links(){
label=$1
base_name=$2
port=$3
query=$4
# 检查回源 Host 域名：CDN 需要一个解析到 VPS 的域名作为回源地址
[ -n "$xvvmcdnym" ] || { cdn_skip "$label 缺少 CDN 回源 Host，已跳过 CDN 变体。请在 lun → 入口网络管理 → CDN 中设置回源 Host 域名。"; return 0; }
origin_public_port=$(client_port "$port")
edge_port=$(cdn_client_port "$port")
mode=$(cf_port_mode "$edge_port" 2>/dev/null || true)
[ -z "$mode" ] && cdn_skip "$label 的客户端边缘端口 $edge_port 不在 Cloudflare 官方端口内；只适用于明确支持该端口的其它反代。"
# 读取 CDN 优选地址，为空则写入默认值
ips=$(cdn_ip_list)
[ -n "$ips" ] || { cdn_default_ips; ips=$(cdn_ip_list); }
[ -n "$ips" ] || { cdn_skip "$label 没有可验证的 Cloudflare 优选入口，已跳过 CDN 变体。请填写 cfip，或先让 CDN Host 开启橙云。"; return 0; }
echo "【 $label 】CDN 优选节点信息如下："
if cdn_rewrite_active; then
echo "注：客户端边缘端口 $edge_port，Cloudflare Origin Rule 目标端口 $origin_public_port，服务器出站仍直连 VPS。"
else
echo "注：客户端边缘端口与回源公网端口均为 $edge_port，服务器出站仍直连 VPS。"
fi
cdn_index=0
for cdn_ip in $ips; do
case "$cdn_ip" in ""|-1) continue ;; esac
cdn_index=$((cdn_index + 1))
cdn_no=$(printf '%02d' "$cdn_index")
cdn_kind=$(endpoint_kind "$cdn_ip")
cdn_raw=$(json_host "$cdn_ip")
cdn_uri=$(uri_host "$cdn_ip")
if [ "$mode" = "https" ]; then
cdn_edge_label="HTTPS-$edge_port"
cdn_name="${sxname}${base_name}-CDN-${cdn_edge_label}-${cdn_kind}-${cdn_no}-$hostname"
cdn_link="vless://$uuid@$cdn_uri:$edge_port?${query}&host=$xvvmcdnym&security=tls&sni=$xvvmcdnym&fp=chrome#$cdn_name"
cdn_tls=true
else
cdn_edge_label="HTTP-$edge_port"
cdn_name="${sxname}${base_name}-CDN-${cdn_edge_label}-${cdn_kind}-${cdn_no}-$hostname"
cdn_link="vless://$uuid@$cdn_uri:$edge_port?${query}&host=$xvvmcdnym&security=none#$cdn_name"
cdn_tls=false
fi
echo "$cdn_link" >> "$HOME/lun/jhsub.txt"
echo "$cdn_link"
if [ "$base_name" = "vl-xhttp-enc" ]; then
cat >> "$HOME/lun/.cdn_clash_entries" <<EOF
- name: "$cdn_name"
  type: vless
  server: "$cdn_raw"
  port: $edge_port
  uuid: $uuid
  flow: xtls-rprx-vision
  encryption: "$enkey"
  udp: true
  tls: $cdn_tls
  servername: $xvvmcdnym
  client-fingerprint: chrome
  network: xhttp
  xhttp-opts:
    path: "/$uuid-vx"
    host: $xvvmcdnym
    mode: auto
EOF
elif [ "$base_name" = "vl-ws-enc" ]; then
cat >> "$HOME/lun/.cdn_sbox_entries" <<EOF
    {
      "type": "vless",
      "tag": "$cdn_name",
      "server": "$cdn_raw",
      "server_port": $edge_port,
      "uuid": "$uuid",
      "tls": {
        "enabled": $cdn_tls,
        "server_name": "$xvvmcdnym"
      },
      "transport": {
        "type": "ws",
        "path": "/$uuid-vw",
        "headers": { "Host": "$xvvmcdnym" }
      }
    },
EOF
printf '"%s",\n' "$cdn_name" >> "$HOME/lun/.cdn_sbox_tags"
cat >> "$HOME/lun/.cdn_clash_entries" <<EOF
- name: "$cdn_name"
  type: vless
  server: "$cdn_raw"
  port: $edge_port
  uuid: $uuid
  encryption: "$enkey"
  udp: true
  tls: $cdn_tls
  servername: $xvvmcdnym
  client-fingerprint: chrome
  network: ws
  ws-opts:
    path: "/$uuid-vw"
    headers:
      Host: $xvvmcdnym
EOF
fi
printf -- '- "%s"\n' "$cdn_name" >> "$HOME/lun/.cdn_clash_names"
done
echo
}

cdn_xhttp_local_signature(){
_cdn_probe_host=$1
_cdn_probe_port=$2
_cdn_probe_path=$3
_cdn_probe_body="/tmp/lun-cdn-local-$$"
rm -f "$_cdn_probe_body"
_cdn_probe_code=$(curl -k -sS --connect-timeout 4 --max-time 8 --resolve "$_cdn_probe_host:$_cdn_probe_port:127.0.0.1" -o "$_cdn_probe_body" -w '%{http_code}' "https://$_cdn_probe_host:$_cdn_probe_port/$_cdn_probe_path" 2>/dev/null)
_cdn_probe_rc=$?
if [ "$_cdn_probe_rc" -ne 0 ]; then rm -f "$_cdn_probe_body"; return 1; fi
_cdn_probe_sum=$(cksum < "$_cdn_probe_body" | awk '{print $1 ":" $2}')
rm -f "$_cdn_probe_body"
printf '%s:%s\n' "$_cdn_probe_code" "$_cdn_probe_sum"
}

cdn_xhttp_edge_probe(){
_cdn_probe_host=$1
_cdn_probe_edge=$2
_cdn_probe_ip=$3
_cdn_probe_path=$4
_cdn_probe_connect=$(uri_host "$_cdn_probe_ip")
_cdn_probe_header="/tmp/lun-cdn-edge-header-$$"
_cdn_probe_body="/tmp/lun-cdn-edge-body-$$"
rm -f "$_cdn_probe_header" "$_cdn_probe_body"
_cdn_probe_code=$(curl -k -sS --connect-timeout 5 --max-time 12 -D "$_cdn_probe_header" -o "$_cdn_probe_body" -w '%{http_code}' --connect-to "$_cdn_probe_host:$_cdn_probe_edge:$_cdn_probe_connect:$_cdn_probe_edge" "https://$_cdn_probe_host:$_cdn_probe_edge/$_cdn_probe_path" 2>/dev/null)
_cdn_probe_rc=$?
if [ "$_cdn_probe_rc" -ne 0 ]; then rm -f "$_cdn_probe_header" "$_cdn_probe_body"; return 1; fi
_cdn_probe_sum=$(cksum < "$_cdn_probe_body" | awk '{print $1 ":" $2}')
if grep -Eqi '^(server:[[:space:]]*cloudflare|cf-ray:)' "$_cdn_probe_header"; then _cdn_probe_cf=yes; else _cdn_probe_cf=no; fi
if grep -Eqi '^alt-svc:.*h3' "$_cdn_probe_header"; then _cdn_probe_h3=yes; else _cdn_probe_h3=no; fi
rm -f "$_cdn_probe_header" "$_cdn_probe_body"
printf '%s:%s|%s|%s\n' "$_cdn_probe_code" "$_cdn_probe_sum" "$_cdn_probe_cf" "$_cdn_probe_h3"
}

append_xhttp_tls_cdn_links(){
port=$1
[ -n "$xvvmcdnym" ] || { cdn_skip "VLESS XHTTP TLS 缺少 CDN 回源 Host，已跳过 CDN 变体。请在 lun → 入口网络管理 → CDN 中设置回源 Host 域名。"; return 0; }
origin_public_port=$(client_port "$port")
edge_port=$(cdn_client_port "$port")
mode=$(cf_port_mode "$edge_port" 2>/dev/null || true)
if [ "$mode" != https ]; then
cdn_skip "VLESS XHTTP TLS CDN 只在 Cloudflare HTTPS 边缘端口生成；当前边缘端口 $edge_port 不是受支持的 HTTPS 端口。"
return 0
fi
ips=$(cdn_ip_list)
[ -n "$ips" ] || { cdn_default_ips; ips=$(cdn_ip_list); }
[ -n "$ips" ] || { cdn_skip "VLESS XHTTP TLS 没有可验证的 Cloudflare 优选入口，已跳过 CDN 变体。请填写 cfip，或先让 CDN Host 开启橙云。"; return 0; }
echo "【 Vless-xhttp-tls-CDN-TCP 】CDN 优选节点信息如下："
if cdn_rewrite_active; then
echo "注：客户端 HTTPS 边缘端口 $edge_port，Cloudflare Origin Rule 目标端口 $origin_public_port。"
else
echo "注：客户端 HTTPS 边缘端口与回源公网端口均为 $edge_port。"
fi
command -v curl >/dev/null 2>&1 || { cdn_skip "缺少 curl，无法确认 Cloudflare 443 是否真正回源到 XHTTP TLS 入站；已停止输出伪可用节点。"; return 0; }
local_signature=$(cdn_xhttp_local_signature "$xvvmcdnym" "$port" "$uuid-xc")
[ -n "$local_signature" ] || { cdn_skip "本机 XHTTP TLS 入站探测失败，已停止输出 CDN 节点。"; return 0; }
cdn_index=0
cdn_valid_count=0
cdn_udp_count=0
for cdn_ip in $ips; do
case "$cdn_ip" in ""|-1) continue ;; esac
edge_result=$(cdn_xhttp_edge_probe "$xvvmcdnym" "$edge_port" "$cdn_ip" "$uuid-xc")
edge_signature=${edge_result%%|*}
edge_rest=${edge_result#*|}
edge_through_cf=${edge_rest%%|*}
edge_h3=${edge_rest#*|}
if [ -z "$edge_result" ] || [ "$edge_through_cf" != yes ] || [ "$edge_signature" != "$local_signature" ]; then
cdn_skip "入口 $cdn_ip:$edge_port 未按 Host + UUID-xc Path 回源到源站端口 $origin_public_port，已跳过该 TCP/UDP 节点。请先配置 Cloudflare Origin Rule 后刷新订阅。"
continue
fi
cdn_index=$((cdn_index + 1))
cdn_valid_count=$((cdn_valid_count + 1))
cdn_no=$(printf '%02d' "$cdn_index")
cdn_kind=$(endpoint_kind "$cdn_ip")
cdn_raw=$(json_host "$cdn_ip")
cdn_uri=$(uri_host "$cdn_ip")
cdn_tcp_name="${sxname}vless-xhttp-tls-CDN-TCP-HTTPS-${edge_port}-${cdn_kind}-${cdn_no}-$hostname"
cdn_tcp_link="vless://$uuid@$cdn_uri:$edge_port?encryption=none&security=tls&sni=$xvvmcdnym&host=$xvvmcdnym&alpn=h2,http/1.1&fp=chrome&insecure=0&allowInsecure=0&type=xhttp&path=$uuid-xc&mode=auto#$cdn_tcp_name"
printf '%s\n' "$cdn_tcp_link" >> "$HOME/lun/jhsub.txt"
printf '%s\n' "$cdn_tcp_link"
cat >> "$HOME/lun/.cdn_clash_entries" <<EOF
- name: "$cdn_tcp_name"
  type: vless
  server: "$cdn_raw"
  port: $edge_port
  uuid: $uuid
  udp: true
  tls: true
  network: xhttp
  alpn:
    - h2
    - http/1.1
  servername: $xvvmcdnym
  client-fingerprint: chrome
  skip-cert-verify: false
  xhttp-opts:
    path: "/$uuid-xc"
    host: $xvvmcdnym
    mode: auto
EOF
printf -- '- "%s"\n' "$cdn_tcp_name" >> "$HOME/lun/.cdn_clash_names"

if [ "$edge_port" = 443 ] && [ "$edge_h3" = yes ]; then
cdn_udp_count=$((cdn_udp_count + 1))
cdn_udp_name="${sxname}vless-xhttp-tls-CDN-UDP-EXP-443-${cdn_kind}-${cdn_no}-$hostname"
cdn_udp_link="vless://$uuid@$cdn_uri:443?encryption=none&security=tls&sni=$xvvmcdnym&host=$xvvmcdnym&alpn=h3&fp=chrome&insecure=0&allowInsecure=0&type=xhttp&path=$uuid-xc&mode=auto#$cdn_udp_name"
printf '%s\n' "$cdn_udp_link" >> "$HOME/lun/jhsub.txt"
printf '%s\n' "$cdn_udp_link"
cat >> "$HOME/lun/.cdn_clash_entries" <<EOF
- name: "$cdn_udp_name"
  type: vless
  server: "$cdn_raw"
  port: 443
  uuid: $uuid
  udp: true
  tls: true
  network: xhttp
  alpn:
    - h3
  servername: $xvvmcdnym
  client-fingerprint: chrome
  skip-cert-verify: false
  xhttp-opts:
    path: "/$uuid-xc"
    host: $xvvmcdnym
    mode: auto
EOF
printf -- '- "%s"\n' "$cdn_udp_name" >> "$HOME/lun/.cdn_clash_names"
fi
done
if [ "$cdn_valid_count" -eq 0 ]; then
yellow_line "未输出 VLESS XHTTP TLS CDN 节点：Cloudflare 443 当前没有回源到 Xray 的 $origin_public_port。直连节点不受影响。"
elif [ "$cdn_udp_count" -gt 0 ]; then
yellow_line "实验性 CDN-UDP 仅为已验证回源且公布 HTTP/3 的入口生成；最终仍以客户端实测为准。"
else
yellow_line "未生成实验性 CDN-UDP：已验证的入口没有同时满足 UDP 443 / HTTP/3 条件。"
fi
echo
}

# ============ 生成 VMess WS CDN 优选节点链接 ============
# 参数：$1=协议端口
# 原理同 append_vless_cdn_links，针对 VMess WS 协议生成 base64 编码的 vmess:// 链接
append_vmess_cdn_links(){
port=$1
[ -n "$xvvmcdnym" ] || { cdn_skip "VMess WS 缺少 CDN 回源 Host，已跳过 CDN 变体。请在 lun → 入口网络管理 → CDN 中设置回源 Host 域名。"; return 0; }
origin_public_port=$(client_port "$port")
edge_port=$(cdn_client_port "$port")
mode=$(cf_port_mode "$edge_port" 2>/dev/null || true)
[ -z "$mode" ] && cdn_skip "VMess WS 的客户端边缘端口 $edge_port 不在 Cloudflare 官方端口内；只适用于明确支持该端口的其它反代。"
ips=$(cdn_ip_list)
[ -n "$ips" ] || { cdn_default_ips; ips=$(cdn_ip_list); }
[ -n "$ips" ] || { cdn_skip "VMess WS 没有可验证的 Cloudflare 优选入口，已跳过 CDN 变体。请填写 cfip，或先让 CDN Host 开启橙云。"; return 0; }
echo "【 Vmess-ws-cdn 】CDN 优选节点信息如下："
if cdn_rewrite_active; then
echo "注：客户端边缘端口 $edge_port，Cloudflare Origin Rule 目标端口 $origin_public_port，服务器出站仍直连 VPS。"
else
echo "注：客户端边缘端口与回源公网端口均为 $edge_port，服务器出站仍直连 VPS。"
fi
cdn_index=0
for cdn_ip in $ips; do
case "$cdn_ip" in ""|-1) continue ;; esac
cdn_index=$((cdn_index + 1))
cdn_no=$(printf '%02d' "$cdn_index")
cdn_kind=$(endpoint_kind "$cdn_ip")
cdn_raw=$(json_host "$cdn_ip")
if [ "$mode" = "https" ]; then
cdn_edge_label="HTTPS-$edge_port"
cdn_name="${sxname}vm-ws-CDN-${cdn_edge_label}-${cdn_kind}-${cdn_no}-$hostname"
vm_cdn_json="{ \"v\": \"2\", \"ps\": \"$cdn_name\", \"add\": \"$cdn_raw\", \"port\": \"$edge_port\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$xvvmcdnym\", \"path\": \"/$uuid-vm\", \"tls\": \"tls\", \"sni\": \"$xvvmcdnym\", \"fp\": \"chrome\"}"
cdn_tls=true
else
cdn_edge_label="HTTP-$edge_port"
cdn_name="${sxname}vm-ws-CDN-${cdn_edge_label}-${cdn_kind}-${cdn_no}-$hostname"
vm_cdn_json="{ \"v\": \"2\", \"ps\": \"$cdn_name\", \"add\": \"$cdn_raw\", \"port\": \"$edge_port\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$xvvmcdnym\", \"path\": \"/$uuid-vm\", \"tls\": \"\"}"
cdn_tls=false
fi
vm_cdn_link="vmess://$(printf '%s' "$vm_cdn_json" | base64 -w0)"
echo "$vm_cdn_link" >> "$HOME/lun/jhsub.txt"
echo "$vm_cdn_link"
cat >> "$HOME/lun/.cdn_sbox_entries" <<EOF
    {
      "type": "vmess",
      "tag": "$cdn_name",
      "server": "$cdn_raw",
      "server_port": $edge_port,
      "uuid": "$uuid",
      "security": "auto",
      "packet_encoding": "packetaddr",
      "tls": {
        "enabled": $cdn_tls,
        "server_name": "$xvvmcdnym"
      },
      "transport": {
        "type": "ws",
        "path": "/$uuid-vm",
        "headers": { "Host": "$xvvmcdnym" }
      }
    },
EOF
printf '"%s",\n' "$cdn_name" >> "$HOME/lun/.cdn_sbox_tags"
cat >> "$HOME/lun/.cdn_clash_entries" <<EOF
- name: "$cdn_name"
  type: vmess
  server: "$cdn_raw"
  port: $edge_port
  uuid: $uuid
  alterId: 0
  cipher: auto
  udp: true
  tls: $cdn_tls
  servername: $xvvmcdnym
  network: ws
  ws-opts:
    path: "/$uuid-vm"
    headers:
      Host: $xvvmcdnym
EOF
printf -- '- "%s"\n' "$cdn_name" >> "$HOME/lun/.cdn_clash_names"
done
echo
}

# ============ 显示 CDN 配置摘要 ============
# 在仪表板上显示当前 CDN 状态：是否启用、回源 Host、优选地址
show_cdn_summary(){
cdn_host=$(cat "$HOME/lun/cdnym" 2>/dev/null)
if [ -n "$cdn_host" ]; then
cdn_ips=$(cdn_ip_list | tr '\n' ' ' | sed 's/[[:space:]]*$//')
if cdn_rewrite_active; then
edge_summary=${cdnpt:-$(cdn_recommended_edge_port)}
xc_summary=
xc_origin=$(cdn_protocol_state_port "${port_xc:-}" "$HOME/lun/port_xc")
if [ -n "$xc_origin" ]; then
xc_edge=$(cdn_client_port "$xc_origin")
[ "$xc_edge" != "$edge_summary" ] && xc_summary="  XHTTP-TLS边缘=$xc_edge"
fi
echo "CDN：已启用  协议=${cdnproto:-xhttp}  模式=Origin Rules（端口回源）  默认边缘=$edge_summary$xc_summary  Host=$cdn_host  优选=${cdn_ips:-待自动发现}"
else
echo "CDN：已启用  协议=${cdnproto:-xhttp}  模式=普通优选  Host=$cdn_host  优选=${cdn_ips:-待自动发现}"
fi
else
echo "CDN：未启用"
fi
}

lun_dashboard(){
clear 2>/dev/null || true
ui_line
printf '%s%s%s\n' "$LUN_YELLOW" "  _      _   _ _   _            ___        ___        ___        ___ " "$LUN_RESET"
printf '%s%s%s\n' "$LUN_YELLOW" " | |    | | | | \\ | |          /\\__\\      /\\  \\      /\\  \\      /\\  \\" "$LUN_RESET"
printf '%s%s%s\n' "$LUN_YELLOW" " | |    | | | |  \\| |         /:/  /     /::\\  \\    /::\\  \\    /::\\  \\" "$LUN_RESET"
printf '%s%s%s\n' "$LUN_YELLOW" " | |___ | |_| | |\\  |        /:/  /     /:/\\:\\  \\  /:/\\:\\  \\  /:/\\:\\  \\" "$LUN_RESET"
printf '%s%s%s\n' "$LUN_YELLOW" " |_____| \\___/|_| \\_|       /:/  /  ___ \\:\\~\\ \\  \\/::\\~\\  \\/::\\~\\  \\" "$LUN_RESET"
printf '%s%s%s\n' "$LUN_YELLOW" "                            \\/__/  /\\__\\ \\:\\ \\ \\__/\\:\\ \\ \\__/\\:\\ \\ \\__" "$LUN_RESET"
printf '%s%s%s\n' "$LUN_YELLOW" "  风火轮多协议交互面板          \\/__/  \\:\\ \\ \\__\\/__\\:\\ \\/  \\:\\ \\/__/" "$LUN_RESET"
printf '%s%s%s\n' "$LUN_YELLOW" "                                   \\:\\_\\       \\:\\_\\     \\:\\_\\    \\:\\_\\" "$LUN_RESET"
printf '%s%s%s\n' "$LUN_YELLOW" "                                    \\/__/       \\/__/      \\/__/     \\/__/" "$LUN_RESET"
ui_line
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
dashboard_addresses=$(direct_address_entries | awk -F'|' '{printf "%s%s", sep, $1; sep=" "}')
printf "节点地址输出：%s  地址：%s\n" "$(address_mode_label)" "${dashboard_addresses:-暂不可用}"
if is_nat_mode; then
echo "VPS类型：NAT VPS"
[ -s "$HOME/lun/port_map" ] && show_port_map_list "$(cat "$HOME/lun/port_map")" || echo "NAT端口映射：无"
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
printf "请输入已解析服务域名（%s回车跳过/保留当前值%s，del 清除，0 返回）%s：" "$LUN_YELLOW" "$LUN_RESET" "${cur:+[$cur]}"
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
printf "ACME 账户邮箱，%s回车随机生成谷歌邮箱%s%s，0 返回：" "$LUN_YELLOW" "$LUN_RESET" "${cur:+[当前:$cur]}"
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
echo " 2. 域名证书（HTTP-01，要求域名解析到本机且 80 可访问，证书价值更高）"
echo " 3. DNS API 证书（acme.sh 原生 DNS provider）"
echo " 4. IP 证书（short-lived，HTTP-01）"
echo " 0. 返回上一步"
printf "请选择 [0-4]，%s回车默认 1%s：" "$LUN_YELLOW" "$LUN_RESET"
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
[ "$nvp" = yes ] && { echo "NaiveProxy 不能使用仅匹配 IP 的证书，请选择域名证书或导入公开域名证书。"; continue; }
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
printf "%s 内网端口（%s回车默认 8080%s，0 返回）：" "$target_label" "$LUN_YELLOW" "$LUN_RESET" "$target_label"
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
printf "Argo 优选 IP / 入口地址，可填多个 IP/域名；回车保留/使用中性默认；del 清除；0 返回%s：" "${cur:+，当前 $cur}"
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
case "$argo" in
vmpt) selected_argo_port="$vm_ws_port" ;;
vwpt) selected_argo_port="$vless_ws_port" ;;
esac
[ -z "$agn" ] || green_line "Cloudflare Tunnel 的 Public Hostname Service 请设置为：http://localhost:$selected_argo_port"
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
printf "节点订阅分享内网监听端口（%s回车从内网端口池/随机取%s，0 返回）：" "$LUN_YELLOW" "$LUN_RESET"
else
printf "节点订阅分享端口（%s回车从端口池/随机取%s，0 返回）：" "$LUN_YELLOW" "$LUN_RESET"
fi
IFS= read -r candidate_subpt
[ "$candidate_subpt" = "0" ] && return 2
if [ -z "$candidate_subpt" ]; then
candidate_subpt=$(select_subscription_port "$(cat "$HOME/lun/subport.log" 2>/dev/null)") || {
echo "无法自动取得可用订阅端口，请增加 NAT 映射/端口池。"
continue
}
subpt="$candidate_subpt"
green_line "节点订阅分享已选择可用端口：$(client_port "$subpt")"
show_port_mapping_hint "$subpt"
break
fi
mapped_inner=$(inner_port_from_public "$candidate_subpt")
if [ -n "$mapped_inner" ]; then
echo "检测到你输入的是公网端口 $candidate_subpt，已转换为订阅内网端口 $mapped_inner。"
candidate_subpt="$mapped_inner"
fi
if port_valid "$candidate_subpt"; then
subpt=$(select_subscription_port "$candidate_subpt") || {
echo "没有可自动替换的订阅端口，请增加 NAT 映射/端口池或手动换一个。"
continue
}
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
echo " 1. 刷新并查看节点信息"
echo " 2. 设置订阅 token / 端口"
echo " 3. 设置订阅 IPv4/IPv6 输出"
echo " 0. 返回"
printf "请选择 [0-3]："
IFS= read -r c
case "$c" in
1) LUN_MENU_ACTION=list; return ;;
2) prompt_subscription; rc=$?; [ "$rc" = 2 ] && continue; refresh_subscription_share; LUN_MENU_ACTION=menu; ui_pause; continue ;;
3) prompt_subscription_ip_mode; rc=$?; [ "$rc" = 2 ] && continue; refresh_subscription_share; LUN_MENU_ACTION=menu; ui_pause; continue ;;
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
#     举例：已验证的 Cloudflare 优选 IPv4、IPv6 或域名
#
# 数据流向：客户端 → cfip（CF入口）→ cdnym（你的域名）→ VPS服务
# 效果：隐藏 VPS 真实 IP，通过 CDN 中转提升连接稳定性和速度
# 限制：只有 VMess WS、VLESS WS、VLESS XHTTP（非Reality）与 VLESS XHTTP TLS 支持
show_cdn_origin_rules(){
host=$(cat "$HOME/lun/cdnym" 2>/dev/null)
[ -n "$host" ] || { echo "尚未设置 CDN Host。"; return 1; }
if ! cdn_rewrite_active; then
echo "当前使用普通同端口 CDN，没有启用 Origin Rules 端口改写。"
return 0
fi
rule_uuid=$(cat "$HOME/lun/uuid" 2>/dev/null)
base_edge=${cdnpt:-$(cdn_recommended_edge_port)}
echo "Cloudflare 默认边缘端口：$base_edge（XHTTP TLS 若遇到 HTTP 端口会自动改用 HTTPS 443；443 仅是边缘端口，不代表源站必须监听 443）"
echo "只按 HTTP/HTTPS 分流会把不同协议送到错误入站，请使用下面的 Host + Path 精确规则："
https_used=no
h3_edge=no
for item in \
"xhttp:VLESS XHTTP:$HOME/lun/port_vx:$rule_uuid-vx" \
"xhttp:VLESS XHTTP TLS:$HOME/lun/port_xc:$rule_uuid-xc" \
"ws:VLESS WS:$HOME/lun/port_vw:$rule_uuid-vw" \
"vmess:VMess WS:$HOME/lun/port_vm_ws:$rule_uuid-vm"; do
proto=${item%%:*}
cdn_protocol_enabled "$proto" || continue
rest=${item#*:}
label=${rest%%:*}
rest=${rest#*:}
file=${rest%%:*}
path=${rest#*:}
[ -s "$file" ] || continue
inner=$(cat "$file" 2>/dev/null)
origin_public=$(client_port "$inner")
edge=$(cdn_client_port "$inner")
is_cf_https_port "$edge" && https_used=yes
[ "$label" = "VLESS XHTTP TLS" ] && [ "$edge" = 443 ] && h3_edge=yes
printf '\n%s\n' "$label"
printf 'Cloudflare 边缘端口：%s\n' "$edge"
printf '匹配表达式：(http.host eq "%s" and starts_with(http.request.uri.path, "/%s"))\n' "$host" "$path"
if is_nat_mode; then
printf '目标端口：%s（NAT 公网端口，内网监听 %s）\n' "$origin_public" "$inner"
else
printf '目标端口：%s（普通 VPS 本机监听端口）\n' "$inner"
fi
done
if [ "$https_used" = yes ]; then
cert_mode_now=$(cat "$HOME/lun/cert_mode" 2>/dev/null)
cert_subject_now=$(cat "$HOME/lun/cert_subject" 2>/dev/null)
if [ "$cert_subject_now" = "$host" ] && [ "$cert_mode_now" != self ]; then
green_line "HTTPS 源站 TLS：证书与 Host 匹配，可在 Cloudflare 使用 Full (Strict)。"
else
yellow_line "HTTPS 源站 TLS：当前证书为自签或与 Host 不同，请在 Cloudflare 使用 Full，不要使用 Full (Strict)。"
fi
[ "$h3_edge" = yes ] && yellow_line "实验性 CDN-UDP 还要求该 DNS 记录开启橙云代理，并在 Cloudflare 开启 HTTP/3（QUIC/UDP 443）。"
fi
is_nat_mode && show_nat_cdn_hint
}

show_cdn_dns_hint(){
host=$(cat "$HOME/lun/cdnym" 2>/dev/null)
[ -n "$host" ] || return 0
resolved=$(resolve_domain_ips "$host")
locals=$(local_public_ips)
direct=no
for one in $resolved; do
printf '%s\n' "$locals" | grep -Fx "$one" >/dev/null 2>&1 && direct=yes
done
if [ "$direct" = yes ]; then
yellow_line "$host 当前直接解析到本机，属于灰云/DNS only。订阅若使用 CF 优选 IP 作为入口，仍会强制连接 Cloudflare 边缘，以实际诊断为准；直接使用该域名作为入口时应开启橙云。"
else
green_line "$host 未直接返回本机公网地址；使用域名入口时请在 Cloudflare 控制台确认已开启橙云。"
fi
}

cdn_probe_path(){
probe_uuid=$(cat "$HOME/lun/uuid" 2>/dev/null)
if cdn_protocol_enabled xhttp && [ -s "$HOME/lun/port_xc" ]; then
probe_xc_edge=$(cdn_client_port "$(cat "$HOME/lun/port_xc")")
is_cf_https_port "$probe_xc_edge" && { printf '%s\n' "$probe_uuid-xc"; return; }
fi
if cdn_protocol_enabled xhttp && [ -s "$HOME/lun/port_vx" ]; then printf '%s\n' "$probe_uuid-vx"; return; fi
if cdn_protocol_enabled ws && [ -s "$HOME/lun/port_vw" ]; then printf '%s\n' "$probe_uuid-vw"; return; fi
if cdn_protocol_enabled vmess && [ -s "$HOME/lun/port_vm_ws" ]; then printf '%s\n' "$probe_uuid-vm"; return; fi
}

diagnose_cdn_endpoints(){
command -v curl >/dev/null 2>&1 || { echo "缺少 curl，无法执行 CDN 连通诊断。"; return 1; }
host=$(cat "$HOME/lun/cdnym" 2>/dev/null)
path=$(cdn_probe_path)
[ -n "$host" ] && [ -n "$path" ] || { echo "需要先设置 CDN Host 并安装一个兼容协议。"; return 1; }
edge=
xc_diag_edge=
[ -s "$HOME/lun/port_xc" ] && xc_diag_edge=$(cdn_client_port "$(cat "$HOME/lun/port_xc")")
if cdn_protocol_enabled xhttp && [ -n "$xc_diag_edge" ] && is_cf_https_port "$xc_diag_edge"; then edge=$xc_diag_edge
elif cdn_rewrite_active; then edge=${cdnpt:-$(cdn_recommended_edge_port)}
elif cdn_protocol_enabled xhttp && [ -s "$HOME/lun/port_vx" ]; then edge=$(client_port "$(cat "$HOME/lun/port_vx")")
elif cdn_protocol_enabled ws && [ -s "$HOME/lun/port_vw" ]; then edge=$(client_port "$(cat "$HOME/lun/port_vw")")
elif cdn_protocol_enabled vmess && [ -s "$HOME/lun/port_vm_ws" ]; then edge=$(client_port "$(cat "$HOME/lun/port_vm_ws")")
fi
[ -n "$edge" ] || { echo "无法确定 CDN 边缘端口。"; return 1; }
if is_cf_https_port "$edge"; then scheme=https; else scheme=http; fi
ips=$(cdn_ip_list)
[ -n "$ips" ] || { echo "尚未设置 CDN 优选入口。"; return 1; }
echo "诊断 Host=$host，边缘端口=$edge，Path=/$path"
echo "说明：本项检查 Cloudflare HTTP 路由；400/404 只表示到达入站，不等于代理测速成功。"
for endpoint in $ips; do
connect_endpoint=$(uri_host "$endpoint")
errfile="/tmp/lun-cdn-diag.$$"
headerfile="/tmp/lun-cdn-header.$$"
code=$(curl -k -v -sS -D "$headerfile" -o /dev/null -w '%{http_code}' --connect-timeout 4 --max-time 10 --connect-to "$host:$edge:$connect_endpoint:$edge" "$scheme://$host:$edge/$path" 2>"$errfile")
rc=$?
err=$(cat "$errfile" 2>/dev/null)
if grep -Eqi '^(server:[[:space:]]*cloudflare|cf-ray:)' "$headerfile" 2>/dev/null; then through_cf=yes; else through_cf=no; fi
rm -f "$errfile" "$headerfile"
if [ "$rc" -ne 0 ]; then
case "$err" in
*SSL*|*TLS*|*certificate*) red_line "$endpoint：TLS 握手失败（检查橙云边缘证书、HTTPS 源站 TLS 和 Cloudflare SSL 模式）。" ;;
*Connected\ to*)
if [ "$scheme" = https ]; then
red_line "$endpoint：TCP 边缘端口可达，但 TLS/Host 握手未完成（检查橙云、边缘证书和 SNI）。"
else
if cdn_rewrite_active; then
red_line "$endpoint：TCP 边缘端口可达，但回源请求未完成（检查 Origin Rule 的 Host、Path 和目标端口）。"
else
red_line "$endpoint：TCP 边缘端口可达，但请求未完成（检查 Host 与普通 CDN 端口）。"
fi
fi
;;
*timed*out*|*Timeout*) red_line "$endpoint：边缘端口连接超时（入口 IP/域名或端口不可达）。" ;;
*) red_line "$endpoint：连接失败（curl 返回码 $rc）。" ;;
esac
elif [ "$code" -ge 520 ] 2>/dev/null && [ "$code" -le 527 ] 2>/dev/null; then
if cdn_rewrite_active; then
red_line "$endpoint：Cloudflare 返回 $code，边缘已到达但回源失败（检查精确 Path 规则、目标端口和源站 TLS）。"
else
red_line "$endpoint：Cloudflare 返回 $code，边缘已到达但普通回源失败（检查 Host、协议端口和源站 TLS）。"
fi
elif [ "$through_cf" != yes ]; then
red_line "$endpoint：收到 HTTP $code，但响应中没有 Cloudflare 标识，优选入口可能没有进入 CF 边缘。"
elif [ "$code" = 400 ] || [ "$code" = 404 ]; then
yellow_line "$endpoint：已进入 Cloudflare 并到达 HTTP 入站，状态 $code；这是 Xray 探测的常见响应，但仍需客户端实际连接验证。"
else
green_line "$endpoint：Cloudflare HTTP 路由可达，状态 $code；最终代理能力仍以外部客户端测试为准。"
fi
done
is_nat_mode && yellow_line "NAT VPS 在服务器自身发起 CF 回环测试时可能误判；客户端外部测试结果优先。"
}

prompt_cdn_host(){
cur_host=$(cat "$HOME/lun/cdnym" 2>/dev/null)
while :; do
default_host="${cdnym:-${domain:-$cur_host}}"
printf "CDN Host%s（回车保留，0 返回）：" "${default_host:+，当前 $default_host}"
IFS= read -r val
[ "$val" = 0 ] && return 2
[ -z "$val" ] && val="$default_host"
[ -z "$val" ] && { echo "启用 CDN 需要 Host 域名。"; continue; }
if valid_domain "$val"; then
cdnym="$val"
printf '%s\n' "$cdnym" > "$HOME/lun/cdnym"
return 0
fi
echo "域名格式错误，请只填写 example.com，不要带协议、端口或路径。"
done
}

prompt_cdn_ips(){
current_ips=$(cdn_ip_list | tr '\n' ' ' | sed 's/[[:space:]]*$//')
while :; do
printf "优选 IP/域名%s（多个空格分隔；空配置时回车自动解析橙云 Host；0 返回）：" "${current_ips:+，当前 $current_ips}"
IFS= read -r val
[ "$val" = 0 ] && return 2
if [ -z "$val" ]; then
[ -n "$current_ips" ] && return 0
if cdn_default_ips; then
current_ips=$(cdn_ip_list | tr '\n' ' ' | sed 's/[[:space:]]*$//')
cfip="$current_ips"
green_line "已从橙云 CDN Host 自动解析优选入口：$current_ips"
return 0
fi
yellow_line "没有从 CDN Host 发现 Cloudflare 边缘 IP。请先开启橙云，或手动填写已验证的 CF 优选 IP/域名。"
continue
fi
bad=
for one in $val; do
case "$one" in -1) bad=yes ;; *) valid_addym "$one" || bad=yes ;; esac
done
[ -z "$bad" ] || { echo "只接受 IPv4、IPv6 或域名。"; continue; }
cfip="$val"
save_cdn_ip_list "$cfip"
return 0
done
}

prompt_cdn(){
CDN_REBUILD_REQUIRED=no
while :; do
ui_title "Lun CDN / CF 优选"
echo "CDN：客户端 → 优选入口 → CDN Host → VPS；协议端口不适合 CF 时会自动启用 Origin Rules。"
echo "XHTTP TLS CDN-TCP 只用 HTTPS 端口组；实验 CDN-UDP 只用 UDP 443。xupt/NaiveProxy 不套普通 CDN。"
show_cdn_summary
show_cdn_port_advice
echo " 1. 一键启用 / 修复 XHTTP CDN"
echo " 2. 仅修改优选 IP / 域名"
echo " 3. 关闭 CDN 节点"
echo " 0. 返回"
printf "请选择 [0-3]："
IFS= read -r choice
case "$choice" in
1)
{ [ -s "$HOME/lun/port_vx" ] || [ -s "$HOME/lun/port_xc" ]; } || { yellow_line "尚未安装 VLESS XHTTP 或 VLESS XHTTP TLS，请先到“安装 / 协议管理”添加。"; return 1; }
prompt_cdn_host || return $?
prune_legacy_cdn_defaults
prompt_cdn_ips || return $?
cdnproto=xhttp
printf '%s\n' "$cdnproto" > "$HOME/lun/cdn_protocol"
[ -n "$cdnmode" ] || cdnmode=standard
printf '%s\n' "$cdnmode" > "$HOME/lun/cdn_mode"
auto_configure_cdn_edge_port
export cdnym cfip cdnmode cdnpt cdnproto
show_cdn_dns_hint
if cdn_rewrite_active; then
green_line "XHTTP CDN 已保存：边缘端口 $cdnpt；请按 Origin Rules 页面显示的 Host + Path 规则回源。"
else
green_line "XHTTP CDN 已保存：当前协议端口可直接使用 Cloudflare 同端口代理。"
fi
return 0
;;
2)
[ -s "$HOME/lun/cdnym" ] || { yellow_line "尚未设置 CDN Host，请先使用选项 1。"; continue; }
prompt_cdn_ips || return $?
export cfip
return 0
;;
3)
rm -f "$HOME/lun/cdnym" "$HOME/lun/cdn_mode" "$HOME/lun/cdn_edge_port" "$HOME/lun/cdn_protocol"
clear_cdn_ip_list
cdnym=; cfip=; cdnmode=standard; cdnpt=; cdnproto=xhttp
CDN_REBUILD_REQUIRED=yes
echo "CDN 节点已关闭，普通直连节点不受影响。"
return 0
;;
0|"") return 2 ;;
*) echo "输入错误。" ;;
esac
done
}

prompt_origin_rules(){
CDN_REBUILD_REQUIRED=no
{ [ -s "$HOME/lun/port_vx" ] || [ -s "$HOME/lun/port_xc" ]; } || { yellow_line "Origin Rules 需要 VLESS XHTTP 或 VLESS XHTTP TLS，请先安装协议。"; return 1; }
[ -s "$HOME/lun/cdnym" ] || { yellow_line "请先在 CDN / CF 优选中设置 Host。"; return 1; }
while :; do
recommended_edge=$(cdn_recommended_edge_port)
ui_title "Lun Cloudflare Origin Rules（端口回源）"
echo "普通 VPS 与 NAT VPS 均可把 Cloudflare 边缘端口改写到各协议源站端口。"
echo "HTTP：80/8080/8880/2052/2082/2086/2095"
echo "HTTPS：443/8443/2053/2083/2087/2096"
echo " 1. 自动选择（当前推荐 $recommended_edge）"
cdn_has_xhttp_tls && cdn_has_generic_protocol && yellow_line "混合协议将使用 HTTP $recommended_edge；XHTTP TLS 单独使用 HTTPS 443。随机源站端口默认避开 443，需按下方 Host + Path 规则回源。"
cdn_has_xhttp_tls && is_nat_mode && yellow_line "NAT VPS：Origin Rule 的目标端口填写公网映射端口，不是内网监听端口；Cloudflare 不能替代服务商的端口映射。"
echo " 2. 手动填写 Cloudflare 官方边缘端口"
echo " 3. 显示精确 Host + Path 规则"
echo " 4. 关闭端口改写，恢复普通同端口 CDN"
echo " 0. 返回"
printf "请选择 [0-4]："
IFS= read -r choice
case "$choice" in
1|2)
old_mode=${cdnmode:-standard}
old_port=${cdnpt:-}
if [ "$choice" = 1 ]; then
new_edge=$recommended_edge
else
printf "请输入 Cloudflare 边缘端口（0 返回）："
IFS= read -r new_edge
[ "$new_edge" = 0 ] && continue
{ is_cf_http_port "$new_edge" || is_cf_https_port "$new_edge"; } || { yellow_line "该端口不在 Cloudflare HTTP/HTTPS 官方代理端口组内。"; continue; }
if cdn_has_xhttp_tls && ! cdn_has_generic_protocol && ! is_cf_https_port "$new_edge"; then
yellow_line "当前只有 xcpt，边缘端口必须来自 HTTPS 端口组；推荐 443 仅用于需要实验 CDN-UDP 的回源规则。"
continue
fi
fi
cdnpt=$new_edge
cdnmode=rewrite
cdnproto=xhttp
printf '%s\n' "$cdnmode" > "$HOME/lun/cdn_mode"
printf '%s\n' "$cdnpt" > "$HOME/lun/cdn_edge_port"
printf '%s\n' "$cdnproto" > "$HOME/lun/cdn_protocol"
[ "$old_mode:$old_port" != "$cdnmode:$cdnpt" ] && CDN_REBUILD_REQUIRED=yes
export cdnmode cdnpt cdnproto
show_cdn_origin_rules
return 0
;;
3) show_cdn_origin_rules; ui_pause ;;
4)
old_mode=${cdnmode:-standard}
old_port=${cdnpt:-}
cdnmode=standard; cdnpt=
printf '%s\n' "$cdnmode" > "$HOME/lun/cdn_mode"
rm -f "$HOME/lun/cdn_edge_port"
[ "$old_mode:$old_port" != "$cdnmode:" ] && CDN_REBUILD_REQUIRED=yes
export cdnmode cdnpt
echo "已恢复普通同端口 CDN；Origin Rules 不再参与节点生成。"
return 0
;;
0|"") return 2 ;;
*) echo "输入错误。" ;;
esac
done
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

prompt_address_mode(){
v4v6
current_mode=$(address_mode_label)
current_domain=$(normalize_host "${addym:-$domain}")
if [ -z "$current_domain" ] || [ "$(endpoint_kind "$current_domain")" != DOMAIN ]; then current_domain=$(normalize_host "$domain"); fi
[ -z "$current_domain" ] || [ "$(endpoint_kind "$current_domain")" = DOMAIN ] || current_domain=
echo "节点地址输出（当前：$current_mode）"
echo " 1. 仅域名"
echo " 2. 仅 IPv4"
echo " 3. 仅 IPv6"
echo " 4. IPv4 + IPv6"
echo " 5. 域名 + IPv4 + IPv6"
echo " 0. 返回"
printf "请选择 [0-5]："
IFS= read -r mode_choice
case "$mode_choice" in
0) return 2 ;;
1) new_addrmode=domain ;;
2) new_addrmode=ipv4 ;;
3) new_addrmode=ipv6 ;;
4) new_addrmode=dual ;;
5) new_addrmode=all ;;
*) echo "输入错误。"; return 1 ;;
esac
case "$new_addrmode" in
domain|all)
while [ -z "$current_domain" ]; do
printf "请输入节点域名（不带协议、端口或路径，0 返回）："
IFS= read -r current_domain
[ "$current_domain" = 0 ] && return 2
if ! valid_domain "$current_domain" || [ "$(endpoint_kind "$current_domain")" != DOMAIN ] || [ "$current_domain" = del ] || [ "$current_domain" = none ]; then
echo "域名格式不正确。"
current_domain=
fi
done
current_domain=$(normalize_host "$current_domain")
addym="$current_domain"
if [ "$new_addrmode" = domain ]; then addout=replace; else addout=both; fi
printf '%s\n' "$addym" > "$HOME/lun/addym"
printf '%s\n' "$addout" > "$HOME/lun/addout"
;;
ipv4)
[ -n "$v4" ] || { echo "当前未检测到可用公网 IPv4，设置未更改。"; return 1; }
ippz=4
;;
ipv6)
[ -n "$v6" ] || { echo "当前未检测到可用公网 IPv6，设置未更改。"; return 1; }
ippz=6
;;
dual)
[ -n "$v4" ] || [ -n "$v6" ] || { echo "当前未检测到公网 IPv4/IPv6，设置未更改。"; return 1; }
[ -z "$v4" ] && yellow_line "当前没有 IPv4，将只输出 IPv6。"
[ -z "$v6" ] && yellow_line "当前没有 IPv6，将只输出 IPv4。"
ippz=46
;;
esac
addrmode=$new_addrmode
printf '%s\n' "$addrmode" > "$HOME/lun/address_mode"
export addrmode ippz addym addout
echo "节点地址输出已设置为：$(address_mode_label)"
return 0
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
12) echo "VLESS XHTTP TLS UDP" ;;
13) echo "VLESS XHTTP TLS TCP/UDP" ;;
14) echo "NaiveProxy H2/H3" ;;
esac
}

protocol_note(){
case "$1" in
3) echo "（支持后续CF优选CDN）" ;;
4) echo "（支持后续Argo隧道/CF优选CDN）" ;;
8) echo "（支持后续Argo隧道/CF优选CDN）" ;;
12) echo "（UDP/QUIC，需放行 UDP 端口）" ;;
13) echo "（源站 TCP；支持 HTTPS CDN / 实验 UDP 443）" ;;
14) echo "（同端口 H2/H3；需公开可信域名证书）" ;;
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
12) echo xupt ;;
13) echo xcpt ;;
14) echo nvpt ;;
esac
}

protocol_cf_port_kind(){
case "$1" in
3|4|8) printf 'http\n' ;;
13) printf 'https\n' ;;
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
12) unset xupt xup port_xu ;;
13) unset xcpt xcp port_xc ;;
14) unset nvpt nvp port_nv ;;
esac
}

clear_all_protocol_picks(){
for id in 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do
clear_protocol_pick "$id"
done
}

protocol_count(){
count=0
for id in 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do
[ -n "$(protocol_current_port "$id")" ] && count=$((count + 1))
done
printf '%s\n' "$count"
}

show_protocol_picker(){
echo "当前协议选择："
for id in 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do
label=$(protocol_label "$id")
note=$(protocol_note "$id")
port=$(protocol_current_port "$id")
if [ -n "$port" ]; then
if is_nat_mode; then
printf "%2s. [已选] %s，内网端口：%s" "$id" "$label$note" "$port"
public=$(client_port "$port")
[ "$public" != "$port" ] && printf "，公网端口：%s" "$public"
else
printf "%2s. [已选] %s，端口：%s" "$id" "$label$note" "$port"
fi
printf "\n"
else
printf "%2s. [未选] %s\n" "$id" "$label$note"
fi
done
}

prompt_protocol_by_id(){
id=$1
label=$(protocol_label "$id")
var=$(protocol_var "$id")
[ -n "$label" ] && [ -n "$var" ] || { echo "忽略未知协议编号：$id"; return 0; }
prompt_port "$label" "$var" "" "$(protocol_cf_port_kind "$id")"
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
if [ "$(protocol_count)" -gt 0 ]; then
echo "协议端口已选择完毕，进入下一步。"
return 0
fi
done
}

quick_change_protocol_port(){
load_installed_protocol_flags
while :; do
ui_title "Lun 快速修改单个协议端口"
found=
for id in 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do
current=$(protocol_current_port "$id")
[ -n "$current" ] || continue
found=yes
label=$(protocol_label "$id")
if is_nat_mode; then
public=$(client_port "$current")
printf '%2s. %s：内网 %s' "$id" "$label" "$current"
[ "$public" != "$current" ] && printf ' / 公网 %s' "$public"
printf '\n'
else
printf '%2s. %s：%s\n' "$id" "$label" "$current"
fi
done
[ -n "$found" ] || { yellow_line "当前没有已安装协议。"; return 1; }
printf "请选择一个协议编号（0 返回）："
IFS= read -r id
[ "$id" = 0 ] && return 2
current=$(protocol_current_port "$id")
label=$(protocol_label "$id")
var=$(protocol_var "$id")
[ -n "$current" ] && [ -n "$label" ] && [ -n "$var" ] || { echo "请输入上方已安装协议的编号。"; continue; }
echo "当前 $label 端口：$current"
prompt_port "$label" "$var" "$current" "$(protocol_cf_port_kind "$id")"
rc=$?
[ "$rc" = 2 ] && continue
[ "$rc" = 3 ] && return 2
[ "$rc" = 0 ] || continue
refresh_protocol_flags
auto_configure_cdn_edge_port
new_port=$(protocol_current_port "$id")
green_line "$label 将从 $current 改为 $new_port；其它协议端口保持不变。"
return 0
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
"TUIC:$port_tu" \
"VLESS XHTTP TLS UDP:$port_xu" \
"VLESS XHTTP TLS TCP/UDP:$port_xc" \
"NaiveProxy H2/H3:$port_nv"; do
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
[ -n "$ptmap" ] && show_port_map_list "$ptmap" || yellow_line "NAT端口映射：未设置（可在入口网络管理中配置）"
[ -n "$inpool" ] && echo "内网端口池：$inpool" || { [ -n "$portpool" ] && echo "内网端口池：$portpool" || echo "内网端口池：未设置（可在入口网络管理中配置）"; }
[ -n "$outpool" ] && echo "外网端口池：$outpool" || echo "外网端口池：未设置（可在入口网络管理中配置）"
[ -n "$inpool" ] && [ -n "$outpool" ] && echo "NAT自动映射：外网端口池按顺序对应内网端口池"
else
[ -n "$inpool" ] && echo "端口池：$inpool" || { [ -n "$portpool" ] && echo "端口池：$portpool" || echo "端口池：未设置（可在入口网络管理中配置）"; }
fi
echo "节点地址输出：$(address_mode_label)"
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
show_nat_cdn_hint
return 0
;;
*) echo "请输入 1、2 或 0。" ;;
esac
done
}

show_nat_cdn_hint(){
yellow_line "NAT VPS 使用 Cloudflare CDN 时，客户端访问的是公网映射端口；内网监听端口本身不需要属于 CF 端口组。"
yellow_line "操作步骤：先配置 外网 CF 端口-内网监听端口 映射并放行公网端口；再到 Cloudflare Origin Rules 按菜单输出的 Host + Path 回源到该公网端口；最后刷新订阅。"
yellow_line "若没有对应的公网 CF 端口，仍可使用任意公网映射，但必须使用 Origin Rules，不能把内网端口直接写成 CDN 节点端口。"
}

show_first_install_port_hint(){
yellow_line "首次端口提醒：支持后续 Cloudflare CDN 的协议，端口回车随机时会优先匹配未占用的 CF 官方端口。"
yellow_line "HTTP 端口：80、8080、8880、2052、2082、2086、2095。HTTPS 端口：443、8443、2053、2083、2087、2096。"
yellow_line "自动随机会排除热门的 443；XHTTP TLS TCP/UDP 优先使用其它 HTTPS 端口，实验 CDN-UDP 需要 Cloudflare 边缘 443，非 443 源站端口时还需要 Origin Rules。"
red_line "激进测试模式：若要让 XHTTP TLS CDN-UDP 走 443 直回源，请在协议端口处手动输入 443；回车随机不会选择 443。"
red_line "443 是献祭端口：设置前请用 ss -ltnp 或 lsof -i:443 检查占用，必要时先停止 Nginx/其他服务，确认 PID 后再 kill；脚本不会擅自杀掉未知进程。"
red_line "xcpt=443 时可免 Origin Rule 直接测试 443→443；若保留其他服务占用 443，请改用 HTTPS 端口并按菜单配置 Origin Rule。"
}

prompt_port_map(){
while :; do
echo "NAT VPS 端口映射只改客户端节点/订阅端口，不写 iptables。"
yellow_line "格式：外网端口-内网监听端口，多个用空格分隔，例如：54834-2096 54835-8443"
yellow_line "CDN 建议把外网端口选为 CF 官方端口；若没有对应端口，请使用 Cloudflare Origin Rules 将边缘端口回源到这里的公网端口。"
printf "请输入映射；%sdel 清除；回车保留/跳过；0 返回%s%s：" "$LUN_YELLOW" "$LUN_RESET" "${ptmap:+，当前 $ptmap}"
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
normalized=$(normalize_ptmap "$val") || { echo "映射格式错误或存在重复公网/内网端口，请使用 外网端口-内网端口，例如：54834-2096"; continue; }
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
yellow_line "格式说明：单个端口 8080；连续端口 1000+2000；NAT映射 外网端口-内网端口 例如 54834-2096"
echo "内网端口池：服务实际监听端口，例如 8080 1000+2000。"
echo "外网端口池：NAT 公网入口端口，例如 53273 49096+49100。按位置自动映射到内网池。"
echo "旧格式仍兼容：portpool=\"54834-2096 49096-1003\" 会自动补充手动 NAT 映射。"
printf "请输入内网端口池；%sdel 清除；回车保留/跳过；0 返回%s%s：" "$LUN_YELLOW" "${inpool:+，当前 $inpool}" "$LUN_RESET"
else
yellow_line "格式说明：单个端口 8080；连续端口 1000+2000；NAT映射 外网端口-内网端口 例如 54834-2096"
echo "普通 VPS 只需要一个端口池，随机端口会直接作为客户端端口。"
printf "请输入端口池；%sdel 清除；回车保留/跳过；0 返回%s%s：" "$LUN_YELLOW" "${inpool:+，当前 $inpool}" "$LUN_RESET"
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

prompt_cert_mode_guided(){
cert_found=no
if cert_key_matches "$HOME/lun/cert.crt" "$HOME/lun/private.key"; then
cert_found=yes
echo "$LUN_GREEN"
echo "=============================="
echo "  检测到 Lun 已加载证书"
show_cert_summary
echo "=============================="
echo "$LUN_RESET"
else
echo "$LUN_YELLOW"
echo "=============================="
echo "  Lun 目录内没有可用的证书与匹配私钥"
echo "  可使用选项 5 搜索本机证书"
echo "  建议将证书和私钥放入 ~/lun/import/ 后再搜索"
echo "=============================="
echo "$LUN_RESET"
fi
echo "证书模式："
if [ "$cert_found" = "yes" ]; then
echo " 1. 保留已有证书（默认，检测到上述证书可用）"
else
echo " 1. 自签证书（默认，立即可用）"
fi
if [ -n "$domain" ]; then
echo " 2. 域名证书（HTTP-01，要求域名解析到本机且 80 可访问，证书价值更高）"
else
echo " 2. 域名证书（需先设置服务域名）"
fi
echo " 3. DNS API 证书（acme.sh 原生 DNS provider）"
echo " 4. IP 证书（short-lived，HTTP-01）"
echo " 5. 搜索并导入本机证书（自动匹配私钥）"
[ "$nvp" = yes ] && yellow_line "已选择 NaiveProxy：必须使用与服务域名匹配的公开可信证书，不能使用自签或 Cloudflare Origin CA。"
echo " 0. 返回上一步"
printf "请选择 [0-5]，%s回车默认 1%s：" "$LUN_YELLOW" "$LUN_RESET"
IFS= read -r c
case "$c" in
0) return 2 ;;
2)
[ -n "$domain" ] || { echo "域名证书需要先设置服务域名。"; continue; }
prompt_acme_email
rc=$?
[ "$rc" = 2 ] && return 2
certmode=domain
;;
3)
[ -n "$domain" ] || { echo "DNS API 证书需要先设置服务域名。"; continue; }
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
5)
find_certificates auto
rc=$?
[ "$rc" = 2 ] && continue
if [ "$rc" = 0 ]; then
certmode=$(cat "$HOME/lun/cert_mode" 2>/dev/null)
show_cert_summary
[ "$nvp" = yes ] && { naive_certificate_ready || continue; }
return 0
fi
continue
;;
""|1)
if cert_key_matches "$HOME/lun/cert.crt" "$HOME/lun/private.key"; then
sync_cert_metadata || continue
certmode=$(cat "$HOME/lun/cert_mode" 2>/dev/null)
echo "已保留 Lun 当前证书：$(cert_mode_label "$certmode")，到期 $(cert_expiry_cn "$HOME/lun/cert.crt")。"
else
certmode=self
echo "将使用自签证书。"
fi
;;
*) echo "输入错误，请重新选择。"; continue ;;
esac
[ "$nvp" = yes ] && case "$certmode" in
domain|dns) ;;
*) naive_certificate_ready || continue ;;
esac
printf "%s\n" "$certmode" > "$HOME/lun/cert_mode"
return 0
}

guided_auto_defaults(){
if [ -z "$sub" ]; then
sub=y
subid=
candidate_subpt=$(select_subscription_port "$(cat "$HOME/lun/subport.log" 2>/dev/null)") || candidate_subpt=
if [ -n "$candidate_subpt" ]; then
subpt="$candidate_subpt"
green_line "已自动启用节点订阅分享，可用端口：$(client_port "$subpt")"
else
sub=
echo "节点订阅分享没有取得可用端口，已跳过；可稍后在菜单里手动设置订阅端口。"
fi
fi
if [ -z "$uuid" ] || [ ! -s "$HOME/lun/uuid" ]; then
uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$HOME/lun/xray" uuid 2>/dev/null || "$HOME/lun/sing-box" generate uuid 2>/dev/null) || uuid="lun-$(date +%s 2>/dev/null)"
printf "%s\n" "$uuid" > "$HOME/lun/uuid"
echo "已自动生成 UUID：$uuid"
fi
if [ -z "$subipmode" ]; then
subipmode=ipv4
printf "%s\n" "$subipmode" > "$HOME/lun/subip_mode"
fi
export sub subid subpt uuid subipmode
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
if [ "$rc" = 0 ]; then
show_first_install_port_hint
if is_nat_mode; then
if [ -z "$ptmap" ] && [ -z "$inpool" ]; then
prompt_port_map
rc=$?
[ "$rc" = 2 ] && { step=1; continue; }
fi
fi
step=2 && continue
fi
[ "$rc" = 2 ] && return 1
;;
2)
guided_summary
pick_protocols
rc=$?
[ "$rc" = 0 ] && step=3 && continue
[ "$rc" = 2 ] && step=1 && continue
;;
3)
guided_summary
prompt_service_domain
rc=$?
[ "$rc" = 0 ] && { [ -n "$domain" ] && [ -z "$addym" ] && { addym="$domain"; addout=replace; load_addym_config; }; step=4; continue; }
[ "$rc" = 2 ] && step=2 && continue
;;
4)
guided_summary
prompt_cert_mode_guided
rc=$?
[ "$rc" = 0 ] && step=5 && continue
[ "$rc" = 2 ] && step=3 && continue
;;
5)
guided_auto_defaults
step=6 && continue
;;
6)
confirm_guided_install
rc=$?
[ "$rc" = 0 ] && break
[ "$rc" = 2 ] && step=4 && continue
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
echo " 2. 申请域名证书（HTTP-01）"
echo " 3. 申请 DNS API 证书"
echo " 4. 申请 IP 证书（short-lived）"
echo " 5. 手动续期当前 ACME 证书"
echo " 6. 清除 DNS API 凭据"
echo " 7. 搜索并导入本机证书"
echo " 0. 返回"
printf "请输入数字 [0-7]："
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
7)
find_certificates
rc=$?
[ "$rc" = 2 ] && continue
if [ "$rc" = 0 ]; then
LUN_MENU_ACTION=res
return
fi
ui_pause
;;
0|"") LUN_MENU_ACTION=menu; return ;;
*) echo "输入错误。" ;;
esac
done
}

find_certificates(){
search_mode=$1
echo "建议将待导入的证书和私钥放入 ~/lun/import/，脚本会通过公钥自动配对，不要求文件名相同。"
if [ "$search_mode" = auto ]; then
search_dir=
else
printf "搜索目录（%s回车自动搜索常用目录%s，0 返回）：" "$LUN_YELLOW" "$LUN_RESET"
IFS= read -r search_dir
[ "$search_dir" = 0 ] && return 2
fi

roots_file="/tmp/lun-cert-roots.$$"
raw_file="/tmp/lun-cert-raw.$$"
rows_file="/tmp/lun-cert-rows.$$"
: > "$roots_file"; : > "$raw_file"; : > "$rows_file"
if [ -n "$search_dir" ]; then
[ -d "$search_dir" ] || { echo "目录不存在：$search_dir"; rm -f "$roots_file" "$raw_file" "$rows_file"; return 1; }
printf '%s\n' "$search_dir" > "$roots_file"
else
for cert_root in "$HOME/lun" "$HOME/key" "$HOME/cert" "$HOME/.acme.sh" /root/key /root/cert /root/ygkkkca /etc/letsencrypt/live; do
[ -d "$cert_root" ] && printf '%s\n' "$cert_root" >> "$roots_file"
done
fi

echo "正在搜索本机证书..."
while IFS= read -r cert_root; do
find -L "$cert_root" -maxdepth 5 -type f \( -name '*.crt' -o -name '*.cer' -o -name '*.pem' \) -print 2>/dev/null
done < "$roots_file" | awk '!seen[$0]++' | head -100 > "$raw_file"

target_name=${domain:-$(cat "$HOME/lun/cdnym" 2>/dev/null)}
found_count=0
while IFS= read -r cert_file; do
openssl x509 -in "$cert_file" -noout >/dev/null 2>&1 || continue
found_count=$((found_count + 1))
key_file=$(cert_find_matching_key "$cert_file" 2>/dev/null) || key_file=-
detected_mode=$(cert_detect_mode "$cert_file")
subject=$(cert_subject_from_file "$cert_file" "$target_name")
issuer=$(cert_issuer_text "$cert_file" | tr '|' '/')
expiry=$(cert_expiry_cn "$cert_file")
status=$(cert_status_cn "$cert_file")
score=0
[ "$key_file" != - ] && score=$((score + 500))
cert_covers_domain "$cert_file" "$target_name" && score=$((score + 1000))
case "$detected_mode" in ca) score=$((score + 220)) ;; origin) score=$((score + 200)) ;; self) score=$((score + 10)) ;; esac
case "$cert_file" in *fullchain*) score=$((score + 20)) ;; esac
case "$status" in 已过期*) score=$((score - 2000)) ;; *) score=$((score + 100)) ;; esac
printf '%s|%s|%s|%s|%s|%s|%s|%s\n' "$score" "$cert_file" "$key_file" "$detected_mode" "$subject" "$issuer" "$expiry" "$status" >> "$rows_file"
done < "$raw_file"

sort -t '|' -k1,1nr "$rows_file" -o "$rows_file"
echo "------------------------------"
echo "检索完成，找到 $found_count 个证书文件。"
[ "$found_count" -gt 0 ] || { echo "没有发现可解析的证书。"; rm -f "$roots_file" "$raw_file" "$rows_file"; return 1; }

idx=0
recommended=
while IFS='|' read -r score cert_file key_file detected_mode subject issuer expiry status; do
idx=$((idx + 1))
if [ -z "$recommended" ] && [ "$key_file" != - ]; then
case "$status" in 已过期*) ;; *) recommended=$idx ;; esac
fi
marker=
[ "$idx" = "$recommended" ] && marker=" [推荐]"
echo
printf '%s. %s%s\n' "$idx" "$cert_file" "$marker"
[ "$key_file" = - ] && key_display="未找到匹配私钥" || key_display=$key_file
echo "   私钥：$key_display"
echo "   类型：$(cert_mode_label "$detected_mode")"
echo "   主体：$subject"
echo "   签发者：${issuer:-未知}"
echo "   到期时间：$expiry"
echo "   状态：$status"
done < "$rows_file"

if [ -z "$recommended" ]; then
echo "未找到同时满足“证书有效且私钥匹配”的可导入项。"
rm -f "$roots_file" "$raw_file" "$rows_file"
return 1
fi

while :; do
printf "输入编号导入；%s回车导入推荐项；0 返回%s：" "$LUN_YELLOW" "$LUN_RESET"
IFS= read -r selection
[ "$selection" = 0 ] && { rm -f "$roots_file" "$raw_file" "$rows_file"; return 2; }
[ -z "$selection" ] && selection=$recommended
case "$selection" in *[!0-9]*|"") echo "请输入列表编号。"; continue ;; esac
selected=$(sed -n "${selection}p" "$rows_file")
[ -n "$selected" ] || { echo "编号不存在。"; continue; }
old_ifs=$IFS; IFS='|'; set -- $selected; IFS=$old_ifs
cert_file=$2; key_file=$3; status=$8
[ "$key_file" != - ] || { echo "该证书没有匹配私钥，不能导入。"; continue; }
case "$status" in 已过期*) echo "该证书已经过期，不能导入。"; continue ;; esac
import_local_certificate "$cert_file" "$key_file"
rc=$?
rm -f "$roots_file" "$raw_file" "$rows_file"
return "$rc"
done
}

config_menu(){
while :; do
ui_title "Lun 变更配置"
echo " 1. 修改 UUID"
echo " 2. 设置服务域名"
echo " 3. 管理证书"
echo " 4. 设置 Argo 隧道"
echo " 5. 节点地址输出（域名 / IPv4 / IPv6）"
echo " 6. 设置 WARP 出站"
echo " 7. 节点订阅分享"
echo " 8. 设置 CDN Host / cfip"
echo " 9. 设置 addym/addout"
echo " 0. 返回"
printf "请选择 [0-9]："
IFS= read -r c
case "$c" in
1) printf "请输入新 UUID（%s回车随机生成%s）：" "$LUN_YELLOW" "$LUN_RESET"; IFS= read -r uuid; [ -z "$uuid" ] && uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$HOME/lun/xray" uuid 2>/dev/null || "$HOME/lun/sing-box" generate uuid); echo "$uuid" > "$HOME/lun/uuid"; echo "UUID 已更新：$uuid"; LUN_MENU_ACTION=list; return ;;
2) prompt_service_domain; rc=$?; [ "$rc" = 2 ] && continue; load_domain_cert_config; LUN_MENU_ACTION=list; return ;;
3) certificate_menu; return ;;
4) prompt_argo; rc=$?; [ "$rc" = 2 ] && continue; [ "$rc" = 0 ] || continue; load_installed_protocol_flags; LUN_MENU_ACTION=rep; return ;;
5) prompt_address_mode; rc=$?; [ "$rc" = 2 ] && continue; [ "$rc" = 0 ] || continue; LUN_MENU_ACTION=list; return ;;
6) prompt_warp; rc=$?; [ "$rc" = 2 ] && continue; load_installed_protocol_flags; LUN_MENU_ACTION=rep; return ;;
7) subscription_menu; return ;;
8) prompt_cdn; rc=$?; [ "$rc" = 2 ] && continue; if [ "$CDN_REBUILD_REQUIRED" = yes ]; then load_installed_protocol_flags; LUN_MENU_ACTION=rep; else LUN_MENU_ACTION=list; fi; return ;;
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
echo " 2. 增删改协议（保留内核，仅重建配置）"
echo " 0. 返回"
printf "请选择 [0-2]："
IFS= read -r c
case "$c" in
1) guided_install; rc=$?; [ "$rc" = 0 ] && { { [ -x "$HOME/lun/xray" ] || [ -x "$HOME/lun/sing-box" ]; } && LUN_MENU_ACTION=rep || LUN_MENU_ACTION=install; return; } ;;
2) pick_protocols; rc=$?; [ "$rc" = 0 ] && LUN_MENU_ACTION=rep || LUN_MENU_ACTION=menu; return ;;
0|"") LUN_MENU_ACTION=menu; return ;;
*) echo "输入错误。" ;;
esac
done
}

vps_port_menu(){
while :; do
ui_title "Lun VPS / 端口"
is_nat_mode && echo "当前：NAT VPS" || echo "当前：普通 VPS"
echo " 1. VPS 类型"
echo " 2. 端口池"
echo " 3. 快速修改单个协议端口"
is_nat_mode && echo " 4. NAT 公网端口映射"
echo " 0. 返回"
printf "请选择："
IFS= read -r c
case "$c" in
1) prompt_vps_mode; rc=$?; [ "$rc" = 2 ] && continue; return 0 ;;
2) prompt_port_pool; rc=$?; [ "$rc" = 2 ] && continue; return 0 ;;
3)
quick_change_protocol_port; rc=$?; [ "$rc" = 2 ] && continue; [ "$rc" = 0 ] && return 3
;;
4)
is_nat_mode || { echo "普通 VPS 不需要 NAT 端口映射。"; continue; }
prompt_port_map; rc=$?; [ "$rc" = 2 ] && continue; return 0
;;
0|"") return 2 ;;
*) echo "输入错误。" ;;
esac
done
}

probe_argo_remote_service(){
[ -x "$HOME/lun/cloudflared" ] || return 1
[ -s "$HOME/lun/sbargotoken.log" ] || return 1
probe_log="$HOME/lun/.argo-probe-$$.log"
rm -f "$probe_log"
"$HOME/lun/cloudflared" tunnel --no-autoupdate --edge-ip-version auto --protocol http2 --loglevel info --logfile "$probe_log" run --token "$(cat "$HOME/lun/sbargotoken.log")" >/dev/null 2>&1 &
probe_pid=$!
for _try in 1 2 3 4 5 6 7 8; do
grep -q 'Updated to new configuration' "$probe_log" 2>/dev/null && break
sleep 1
done
kill "$probe_pid" 2>/dev/null || true
wait "$probe_pid" 2>/dev/null || true
remote_service=$(grep 'Updated to new configuration' "$probe_log" 2>/dev/null | grep -o '\\"service\\":\\"[^\\"]*' | head -1 | sed 's/^\\"service\\":\\"//')
rm -f "$probe_log"
[ -n "$remote_service" ] || return 1
printf '%s\n' "$remote_service"
}

diagnose_argo_tunnel(){
ui_title "Lun CF 隧道 / Argo 回源诊断"
argo_port=$(cat "$HOME/lun/argoport.log" 2>/dev/null)
argo_type=$(cat "$HOME/lun/vlvm" 2>/dev/null)
argo_domain=$(cat "$HOME/lun/sbargoym.log" 2>/dev/null)
[ -n "$argo_port" ] || { red_line "未找到 Argo 绑定端口，请先配置隧道。"; return 1; }
[ "$argo_type" = Vmess ] && argo_path="/$(cat "$HOME/lun/uuid")-vm" || argo_path="/$(cat "$HOME/lun/uuid")-vw"
expected_service="http://localhost:$argo_port"
echo "Lun 当前协议：$argo_type WS"
echo "本机应使用的 Tunnel 服务：$expected_service"
echo "WebSocket 路径：$argo_path"
if command -v curl >/dev/null 2>&1; then
local_code=$(curl -sm 8 -o /dev/null -w '%{http_code}' "$expected_service$argo_path" -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' 2>/dev/null)
if [ "$local_code" = 101 ]; then
green_line "本机回源：正常（WebSocket 101）"
else
red_line "本机回源：异常（HTTP ${local_code:-连接失败}），请先检查协议服务。"
fi
fi
echo "正在读取 Cloudflare 下发的 Tunnel 配置，约需数秒……"
remote_service=$(probe_argo_remote_service 2>/dev/null)
if [ -n "$remote_service" ]; then
echo "Cloudflare 控制台当前服务：$remote_service"
if [ "$remote_service" = "$expected_service" ]; then
green_line "控制台回源与本机端口一致。"
else
red_line "端口不一致：请在 Cloudflare Tunnel 的 Public Hostname 中把 Service 改为 $expected_service。"
fi
else
yellow_line "未能读取远端服务配置；请手动确认 Public Hostname 的 Service 为 $expected_service。"
fi
if [ -n "$argo_domain" ] && command -v curl >/dev/null 2>&1; then
edge_code=$(curl --http1.1 -skm 12 -o /dev/null -w '%{http_code}' "https://$argo_domain$argo_path" -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' 2>/dev/null)
case "$edge_code" in
101) green_line "Cloudflare 边缘回源：正常（WebSocket 101）" ;;
502) red_line "Cloudflare 边缘回源：502，通常就是控制台 Service 的协议或端口不匹配。" ;;
*) yellow_line "Cloudflare 边缘返回：${edge_code:-连接失败}" ;;
esac
fi
}

argo_network_menu(){
while :; do
ui_title "Lun CF 隧道 / Argo"
if [ -s "$HOME/lun/argoport.log" ]; then
echo "当前本机回源：http://localhost:$(cat "$HOME/lun/argoport.log")"
fi
echo " 1. 配置 / 修改隧道"
echo " 2. Argo 优选 IP / 入口地址"
echo " 3. 诊断隧道回源（检查 Cloudflare 控制台端口）"
echo " 0. 返回"
printf "请选择 [0-3]："
IFS= read -r c
case "$c" in
1)
prompt_argo; rc=$?; [ "$rc" = 2 ] && continue; [ "$rc" = 0 ] || continue
load_installed_protocol_flags; LUN_MENU_ACTION=rep; return 0
;;
2)
prompt_argo_ip; rc=$?; [ "$rc" = 2 ] && continue
LUN_MENU_ACTION=list; return 0
;;
3)
diagnose_argo_tunnel
ui_pause
continue
;;
0|"") return 2 ;;
*) echo "输入错误。" ;;
esac
done
}

network_menu(){
while :; do
ui_title "Lun 入口网络管理"
is_nat_mode && echo "当前 VPS：NAT" || echo "当前 VPS：普通"
show_cdn_summary
[ -s "$HOME/lun/argoip" ] && echo "Argo优选：$(cat "$HOME/lun/argoip")" || echo "Argo优选：中性默认"
echo " 1. VPS 类型 / 端口池 / 快速改端口"
echo " 2. CDN / CF 优选（入口地址与 Host）"
echo " 3. Cloudflare Origin Rules（边缘端口 → 源站端口）"
echo " 4. CF 隧道 / Argo（独立链路，不使用 2/3 的设置）"
echo " 5. CDN 连通诊断"
echo " 0. 返回"
printf "请选择 [0-5]："
IFS= read -r c
case "$c" in
1)
vps_port_menu; rc=$?; [ "$rc" = 2 ] && continue
[ "$rc" = 3 ] && LUN_MENU_ACTION=rep || LUN_MENU_ACTION=list
return
;;
2)
prompt_cdn; rc=$?; [ "$rc" = 2 ] && continue; [ "$rc" = 0 ] || continue
if [ "$CDN_REBUILD_REQUIRED" = yes ]; then load_installed_protocol_flags; LUN_MENU_ACTION=rep; else LUN_MENU_ACTION=list; fi
return
;;
3)
prompt_origin_rules; rc=$?; [ "$rc" = 2 ] && continue; [ "$rc" = 0 ] || { ui_pause; continue; }
if [ "$CDN_REBUILD_REQUIRED" = yes ]; then load_installed_protocol_flags; LUN_MENU_ACTION=rep; else LUN_MENU_ACTION=list; fi
return
;;
4)
argo_network_menu; rc=$?; [ "$rc" = 2 ] && continue
return
;;
5) diagnose_cdn_endpoints; ui_pause ;;
0|"") LUN_MENU_ACTION=menu; return ;;
*) echo "输入错误。" ;;
esac
done
}

service_update_menu(){
while :; do
ui_title "Lun 服务与更新"
echo " 1. 重启服务"
echo " 2. 停止服务"
echo " 3. 查看运行日志"
echo " 4. 更新 Lun 脚本"
echo " 5. 更新 Xray 内核"
echo " 6. 更新 Sing-box 内核"
echo " 0. 返回"
printf "请选择 [0-6]："
IFS= read -r c
case "$c" in
1) LUN_MENU_ACTION=res; return ;;
2) stop_lun_services; echo "已停止 Lun 服务。"; exit ;;
3) log_menu ;;
4) update_lun_script; exit ;;
5) LUN_MENU_ACTION=upx; return ;;
6) LUN_MENU_ACTION=ups; return ;;
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
echo " 4. 节点地址输出（域名 / IPv4 / IPv6）"
echo " 5. 修改 UUID"
echo " 6. 卸载 Lun"
echo " 7. 清空配置恢复出厂设置"
echo " 0. 返回"
printf "请选择 [0-7]："
IFS= read -r c
case "$c" in
1) prompt_service_domain; rc=$?; [ "$rc" = 2 ] && continue; load_domain_cert_config; LUN_MENU_ACTION=list; return ;;
2) certificate_menu; [ "$LUN_MENU_ACTION" = "menu" ] && continue; return ;;
3) prompt_warp; rc=$?; [ "$rc" = 2 ] && continue; load_installed_protocol_flags; LUN_MENU_ACTION=rep; return ;;
4) prompt_address_mode; rc=$?; [ "$rc" = 2 ] && continue; [ "$rc" = 0 ] || continue; LUN_MENU_ACTION=list; return ;;
5) printf "请输入新 UUID（%s回车随机生成%s）：" "$LUN_YELLOW" "$LUN_RESET"; IFS= read -r uuid; [ -z "$uuid" ] && uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$HOME/lun/xray" uuid 2>/dev/null || "$HOME/lun/sing-box" generate uuid); echo "$uuid" > "$HOME/lun/uuid"; echo "UUID 已更新：$uuid"; LUN_MENU_ACTION=list; return ;;
6) LUN_MENU_ACTION=del; return ;;
7) factory_reset; [ $? = 0 ] && { LUN_MENU_ACTION=install; return; } ;;
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
showmode_short
exit
elif [ "$1" = "rep" ]; then
_lun_rebuild_request=yes
_lun_rebuild_existing=no
{ [ -x "$HOME/lun/xray" ] || [ -x "$HOME/lun/sing-box" ]; } && _lun_rebuild_existing=yes
create_rebuild_snapshot || { echo "无法创建重建快照，已取消操作，原服务未改动。"; exit 1; }
trap 'rollback_rebuild' EXIT
trap 'exit 130' HUP INT TERM
cleandel keep-entry
ensure_lun_command || true
rm -f "$HOME/lun/sb.json" "$HOME/lun/xr.json" "$HOME/lun/sbargoym.log" "$HOME/lun/sbargotoken.log" "$HOME/lun/argo.log" "$HOME/lun/argoport.log" "$HOME/lun/name"
rm -f "$HOME/lun"/port_vl_re "$HOME/lun"/port_xh "$HOME/lun"/port_vx "$HOME/lun"/port_vw "$HOME/lun"/port_ss "$HOME/lun"/port_an "$HOME/lun"/port_ar "$HOME/lun"/port_vm_ws "$HOME/lun"/port_so "$HOME/lun"/port_hy2 "$HOME/lun"/port_tu "$HOME/lun"/port_xu "$HOME/lun"/port_xc "$HOME/lun"/port_nv
if [ "$_lun_rebuild_existing" = yes ]; then
echo "旧协议进程已停止，正在重建配置；现有内核、证书、UUID 与订阅设置均保留。"
else
echo "未检测到可用内核，当前按首次安装继续。"
fi
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
_lun_proc_running2=no
for _P in /proc/[0-9]*; do
[ -L "$_P/exe" ] || continue
_exe=$(readlink -f "$_P/exe" 2>/dev/null) || continue
case "$_exe" in */lun/sing-box*|*/lun/xray*) _lun_proc_running2=yes; break ;; esac
done
[ "$_lun_proc_running2" = "no" ] && pgrep -f 'lun/(sing-box|xray)([[:space:]]|$)' >/dev/null 2>&1 && _lun_proc_running2=yes
[ "$_lun_proc_running2" = "no" ] && { systemctl is-active --quiet xr 2>/dev/null || systemctl is-active --quiet sb 2>/dev/null; } && _lun_proc_running2=yes
if [ "$_lun_proc_running2" = "no" ]; then
stop_lun_owned_processes
_lun_net_v4=$( (command -v curl >/dev/null 2>&1 && curl -s4m5 -k "$v46url" 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget -4 -qO- --tries=2 "$v46url" 2>/dev/null) )
_lun_net_v6=$( (command -v curl >/dev/null 2>&1 && curl -s6m5 -k "$v46url" 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget -6 -qO- --tries=2 "$v46url" 2>/dev/null) )
if [ -z "$_lun_net_v4" ] && [ -z "$_lun_net_v6" ]; then
printf "nameserver 1.1.1.1\nnameserver 8.8.8.8\nnameserver 2606:4700:4700::1111\nnameserver 2001:4860:4860::8888\n" > /etc/resolv.conf
fi
if [ -n "$_lun_net_v6" ]; then
sendip="2606:4700:d0::a29f:c001"
xendip="[2606:4700:d0::a29f:c001]"
else
sendip="162.159.192.1"
xendip="162.159.192.1"
fi
echo "VPS系统：$op"
echo "CPU架构：$cpu"
if [ "$_lun_rebuild_request" = yes ] && [ "$_lun_rebuild_existing" = yes ]; then
echo "Lun 已安装：仅重建协议配置，不重复下载现有 Xray/Sing-box 内核。"
elif [ -s "$HOME/lun/uuid" ] && { [ -x "$HOME/lun/xray" ] || [ -x "$HOME/lun/sing-box" ]; }; then
echo "检测到 Lun 已安装但服务未运行，正在使用现有内核修复配置并启动。"
else
echo "首次安装 Lun：仅在所选协议需要且本机缺少内核时下载。"
fi
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
if ! ins; then
echo "Lun 内核安装失败，未覆盖已有内核或启动不完整服务。"
exit 1
fi
if [ "$_lun_rebuild_request" = yes ]; then
if ! validate_rebuild; then
rollback_rebuild
exit 1
fi
commit_rebuild_snapshot
fi
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
requested_subport=$(cat "$HOME/lun/subport.log")
else
requested_subport=
fi
else
requested_subport="$subpt"
fi
subport=$(select_subscription_port "$requested_subport") || return 1
printf '%s\n' "$subport" > "$HOME/lun/subport.log"
}
if subportipsub && subtokenipsub; then
echo "请稍后…………"
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
else
echo "订阅端口不可用，已保留协议服务并跳过订阅 httpd 启动。"
fi
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
showmode_short
exit
fi
