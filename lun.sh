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
export coremirror=${coremirror:-${LUN_CORE_MIRROR:-"https://oracle1.1223344.xyz:8443/fhlun"}}
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
if [ "$1" != "cluster-service-control" ]; then
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Lun 项目地址：https://github.com/azk78lun-collab/FHLUN"
echo ""
echo ""
echo "风火轮一键无交互脚本"
echo "当前版本：V26.8.8.2"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
fi
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

normalize_server_number(){
number=$1
printf '%s\n' "$number" | grep -Eq '^[0-9]+$' || return 1
number=$(printf '%s\n' "$number" | sed 's/^0*//')
[ -n "$number" ] || number=0
[ "$number" -ge 1 ] 2>/dev/null || return 1
if [ "$number" -lt 100 ]; then
printf '%02d\n' "$number"
else
printf '%d\n' "$number"
fi
}

sanitize_server_place(){
place=$(printf '%s' "$1" | tr '\r\n\t' '   ' | sed 's/\[//g; s/\]//g; s#[/#?@]#-#g; s/[[:space:]][[:space:]]*/-/g; s/--*/-/g; s/^-//; s/-$//')
[ -n "$place" ] || return 1
[ "${#place}" -le 48 ] || return 1
case "$place" in 日本-箕面) place=日本-大阪 ;; esac
printf '%s\n' "$place"
}

server_country_zh(){
case "$1" in
AU) printf '澳大利亚\n' ;; CA) printf '加拿大\n' ;; DE) printf '德国\n' ;;
FR) printf '法国\n' ;; GB) printf '英国\n' ;; HK) printf '中国香港\n' ;;
JP) printf '日本\n' ;; KR) printf '韩国\n' ;; NL) printf '荷兰\n' ;;
SG) printf '新加坡\n' ;; TW) printf '中国台湾\n' ;; US) printf '美国\n' ;;
*) return 1 ;;
esac
}

server_city_zh(){
city=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
case "$city" in
frankfurt) printf '法兰克福\n' ;; "hong kong") printf '香港\n' ;;
"los angeles") printf '洛杉矶\n' ;; minoh) printf '大阪\n' ;;
osaka) printf '大阪\n' ;; seoul) printf '首尔\n' ;;
singapore) printf '新加坡\n' ;; tokyo) printf '东京\n' ;;
*) return 1 ;;
esac
}

detect_server_place(){
identity_host=${v4:-${v6:-}}
[ -n "$identity_host" ] || identity_host=$(cat "$HOME/lun/server_ip.log" 2>/dev/null)
identity_host=${identity_host#\[}; identity_host=${identity_host%\]}
[ -n "$identity_host" ] || { printf '未设置地区\n'; return; }
identity_url="https://ipwho.is/$(printf '%s' "$identity_host" | sed 's/:/%3A/g')"
identity_json=$( (command -v curl >/dev/null 2>&1 && curl -fsSL --connect-timeout 3 --max-time 6 "$identity_url" 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 7 wget -qO- "$identity_url" 2>/dev/null) )
identity_code=$(printf '%s' "$identity_json" | sed -n 's/.*"country_code"[[:space:]]*:[[:space:]]*"\([A-Za-z][A-Za-z]\)".*/\1/p' | tr '[:lower:]' '[:upper:]')
identity_city=$(printf '%s' "$identity_json" | sed -n 's/.*"city"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
identity_country=$(server_country_zh "$identity_code" 2>/dev/null || true)
identity_city_zh=$(server_city_zh "$identity_city" 2>/dev/null || true)
if [ -n "$identity_country" ] && [ -n "$identity_city_zh" ] && [ "$identity_country" != "$identity_city_zh" ]; then
printf '%s-%s\n' "$identity_country" "$identity_city_zh"
elif [ -n "$identity_country" ]; then
printf '%s\n' "$identity_country"
else
printf '未设置地区\n'
fi
}

load_server_identity(){
server_number=$(normalize_server_number "$(cat "$HOME/lun/server_number" 2>/dev/null)" 2>/dev/null || printf '01\n')
server_place=$(sanitize_server_place "$(cat "$HOME/lun/server_place" 2>/dev/null)" 2>/dev/null || true)
}

save_server_identity(){
identity_number=$(normalize_server_number "${2:-${server_number:-01}}") || return 1
identity_place=$(sanitize_server_place "$1") || return 1
printf '%s\n' "$identity_number" > "$HOME/lun/server_number"
printf '%s\n' "$identity_place" > "$HOME/lun/server_place"
chmod 600 "$HOME/lun/server_number" "$HOME/lun/server_place" 2>/dev/null || true
server_number=$identity_number
server_place=$identity_place
}

ensure_server_identity(){
load_server_identity
if [ -z "$server_place" ]; then
server_place=$(detect_server_place)
save_server_identity "$server_place" "$server_number" || return 1
fi
node_name_prefix="[$server_place]"
[ "$server_place" != "未设置地区" ] || yellow_line "未能自动识别服务器地区；节点暂用 [未设置地区]，可在“节点订阅分享 → 服务器身份 / 节点命名”中修改。"
}

address_variant_code(){
case "$1" in
DOMAIN) printf 'D4\n' ;; IPv4|V4) printf 'V4\n' ;; IPv6|V6) printf 'V6\n' ;;
*) return 1 ;;
esac
}

direct_node_suffix(){
variant=$1
if [ "${direct_entry_count:-1}" -gt 1 ]; then
variant=$(address_variant_code "$variant") || return 1
printf -- '-%s-%s\n' "$variant" "$server_number"
else
printf -- '-%s\n' "$server_number"
fi
}

direct_node_name(){
printf '%s%s%s\n' "$node_name_prefix" "$1" "$node_name_suffix"
}

routed_node_name(){
printf '%s%s-%s\n' "$node_name_prefix" "$1" "$server_number"
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
if ! valid_ptmap_pair "$pair"; then
printf '%sNAT 映射格式错误：%s；请使用 公网端口-内网端口。%s\n' "$LUN_RED" "$pair" "$LUN_RESET" >&2
return 1
fi
ext=${pair%%-*}
inner=${pair#*-}
skip=
for exist in $out; do
exist_ext=${exist%%-*}
exist_inner=${exist#*-}
if [ "$exist" = "$pair" ]; then
printf '%s重复映射 %s 已忽略。%s\n' "$LUN_YELLOW" "$pair" "$LUN_RESET" >&2
skip=yes
break
fi
if [ "$exist_ext" = "$ext" ]; then
printf '%s公网端口 %s 已映射到内网端口 %s，不能再映射到 %s。%s\n' "$LUN_RED" "$ext" "$exist_inner" "$inner" "$LUN_RESET" >&2
return 1
fi
if [ "$exist_inner" = "$inner" ]; then
printf '%s内网端口 %s 已使用公网端口 %s；保留首项并忽略 %s。%s\n' "$LUN_YELLOW" "$inner" "$exist_ext" "$pair" "$LUN_RESET" >&2
skip=yes
break
fi
done
[ -n "$skip" ] && continue
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
normalized=$(normalize_ptmap "$ptmap") || exit 1
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

valid_ipv4_value(){
printf '%s\n' "$1" | awk -F. '
NF != 4 { exit 1 }
{
  for (i = 1; i <= 4; i++) {
    if ($i !~ /^[0-9]+$/ || $i < 0 || $i > 255) exit 1
  }
 }'
}

valid_cdn_endpoint(){
cdn_endpoint=$(normalize_host "$1")
case "$cdn_endpoint" in
""|*[!0-9A-Za-z:.-]*) return 1 ;;
esac
case "$cdn_endpoint" in
*:*)
printf '%s\n' "$cdn_endpoint" | grep -Eq '^[0-9A-Fa-f:]+$'
;;
*[!0-9.]*)
printf '%s\n' "$cdn_endpoint" | grep -Eq '^[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z0-9][A-Za-z0-9-]*)+$'
;;
*)
valid_ipv4_value "$cdn_endpoint"
;;
esac
}

clean_cdn_endpoint_token(){
cdn_token=$(printf '%s' "$1" | tr -d '\r')
while :; do
case "$cdn_token" in
\**|\"*|\'*|\(*|\{*|\<*) cdn_token=${cdn_token#?} ;;
*) break ;;
esac
done
case "$cdn_token" in *://*) cdn_token=${cdn_token#*://} ;; esac
cdn_token=${cdn_token%%#*}
cdn_token=${cdn_token%%\?*}
cdn_token=${cdn_token%%/*}
while :; do
case "$cdn_token" in
*\*|*\"|*\'|*\)|*\}|*\>|*,|*";") cdn_token=${cdn_token%?} ;;
*) break ;;
esac
done
[ -n "$cdn_token" ] || return 1
case "$cdn_token" in
\[*\]*)
cdn_host=${cdn_token#\[}
cdn_host=${cdn_host%%\]*}
;;
*)
cdn_host=$cdn_token
cdn_colons=$(printf '%s' "$cdn_host" | tr -cd ':' | wc -c | tr -d ' ')
if [ "$cdn_colons" = 1 ]; then
cdn_suffix=${cdn_host##*:}
valid_port_value "$cdn_suffix" && cdn_host=${cdn_host%:*}
fi
;;
esac
cdn_host=$(normalize_host "$cdn_host")
valid_cdn_endpoint "$cdn_host" || return 1
printf '%s\n' "$cdn_host"
}

normalize_cdn_ip_input(){
cdn_normalized=
cdn_seen=
for cdn_token in $(printf '%s\n' "$1" | tr ',;\r\n\t' '     '); do
cdn_host=$(clean_cdn_endpoint_token "$cdn_token") || continue
case " $cdn_seen " in *" $cdn_host "*) continue ;; esac
cdn_seen="${cdn_seen:+$cdn_seen }$cdn_host"
cdn_normalized="${cdn_normalized:+$cdn_normalized }$cdn_host"
done
printf '%s\n' "$cdn_normalized"
}

save_cdn_ip_list(){
normalized_cdn_ips=$(normalize_cdn_ip_input "$1")
[ -n "$normalized_cdn_ips" ] || return 1
clear_cdn_ip_list
idx=1
list=
seen=
for one in $normalized_cdn_ips; do
case " $seen " in *" $one "*) continue ;; esac
seen="${seen:+$seen }$one"
list="${list:+$list }$one"
printf "%s\n" "$one" > "$HOME/lun/cdnip$idx"
idx=$((idx + 1))
done
printf "%s\n" "$list" > "$HOME/lun/cdnip"
cfip="$list"
}

load_cdn_mode_config(){
[ -z "$cdnym" ] && [ -s "$HOME/lun/cdnym" ] && cdnym=$(cat "$HOME/lun/cdnym" 2>/dev/null)
if [ -n "$cfip" ]; then
case "$cfip" in
del|none|off|-1) clear_cdn_ip_list; cfip= ;;
*) save_cdn_ip_list "$cfip" || { echo "cfip 未识别到有效的 IPv4、IPv6 或域名。"; exit 1; } ;;
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

cloudflare_manual_rule_file(){
printf '%s\n' "$HOME/lun/cdn_cloudflare_manual"
}

cloudflare_manual_edge_for_inner(){
manual_inner=$1
manual_host=${cdnym:-$(cat "$HOME/lun/cdnym" 2>/dev/null)}
manual_file=$(cloudflare_manual_rule_file)
[ -n "$manual_host" ] && [ -s "$manual_file" ] || return 1
for manual_item in \
"3:$HOME/lun/port_vx" \
"13:$HOME/lun/port_xc" \
"4:$HOME/lun/port_vw" \
"8:$HOME/lun/port_vm_ws"; do
manual_id=${manual_item%%:*}
manual_port_file=${manual_item#*:}
[ -s "$manual_port_file" ] || continue
[ "$(cat "$manual_port_file" 2>/dev/null)" = "$manual_inner" ] || continue
manual_line=$(awk -F'|' -v host="$manual_host" -v id="$manual_id" \
'$1 == host && $2 == id { print $3 "|" $4; exit }' "$manual_file" 2>/dev/null)
[ -n "$manual_line" ] || continue
manual_edge=${manual_line%%|*}
manual_origin=${manual_line#*|}
[ "$manual_origin" = "$(client_port "$manual_inner")" ] || continue
{ is_cf_http_port "$manual_edge" || is_cf_https_port "$manual_edge"; } || continue
printf '%s\n' "$manual_edge"
return 0
done
return 1
}

cloudflare_manual_rule_matches(){
manual_match_id=$1
manual_match_edge=$2
manual_match_origin=$3
manual_match_path=$4
manual_match_host=${cdnym:-$(cat "$HOME/lun/cdnym" 2>/dev/null)}
manual_match_file=$(cloudflare_manual_rule_file)
[ -n "$manual_match_host" ] && [ -s "$manual_match_file" ] || return 1
awk -F'|' -v host="$manual_match_host" -v id="$manual_match_id" \
    -v edge="$manual_match_edge" -v origin="$manual_match_origin" -v path="$manual_match_path" \
'$1 == host && $2 == id && $3 == edge && $4 == origin && $5 == path { found=1; exit }
 END { exit(found ? 0 : 1) }' "$manual_match_file"
}

cdn_first_endpoint(){
for first_endpoint in $1; do
case "$first_endpoint" in ""|-1) continue ;; esac
printf '%s\n' "$first_endpoint"
return 0
done
return 1
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

cdn_has_origin_rule_protocol(){
{ [ "$vxp" = yes ] || [ -n "${port_vx:-}" ] || [ -s "$HOME/lun/port_vx" ]; } && return 0
{ [ "$vwp" = yes ] || [ -n "${port_vw:-}" ] || [ -s "$HOME/lun/port_vw" ]; } && return 0
{ [ "$vmp" = yes ] || [ -n "${port_vm_ws:-}" ] || [ -s "$HOME/lun/port_vm_ws" ]; } && return 0
{ [ "$xcp" = yes ] || [ -n "${port_xc:-}" ] || [ -s "$HOME/lun/port_xc" ]; } && return 0
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
if cdn_has_generic_protocol && ! is_cf_http_port "$cdnpt"; then
cdnpt=$(cdn_recommended_edge_port)
elif ! { is_cf_http_port "$cdnpt" || is_cf_https_port "$cdnpt"; }; then
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
manual_edge=$(cloudflare_manual_edge_for_inner "$origin_inner" 2>/dev/null || true)
if [ -n "$manual_edge" ]; then
printf '%s\n' "$manual_edge"
return
fi
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
origin_inner=$1
origin_enabled=no
if cdn_protocol_enabled xhttp; then
[ "$origin_inner" = "$(cdn_protocol_state_port "${port_xc:-}" "$HOME/lun/port_xc")" ] && origin_enabled=yes
[ "$origin_inner" = "$(cdn_protocol_state_port "${port_vx:-}" "$HOME/lun/port_vx")" ] && origin_enabled=yes
fi
if cdn_protocol_enabled ws && [ "$origin_inner" = "$(cdn_protocol_state_port "${port_vw:-}" "$HOME/lun/port_vw")" ]; then origin_enabled=yes; fi
if cdn_protocol_enabled vmess && [ "$origin_inner" = "$(cdn_protocol_state_port "${port_vm_ws:-}" "$HOME/lun/port_vm_ws")" ]; then origin_enabled=yes; fi
[ "$origin_enabled" = yes ] || return 1
if cdn_rewrite_active; then
is_cf_https_port "$(cdn_client_port "$origin_inner")"
else
is_cf_https_port "$(client_port "$origin_inner")"
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

direct_mode_uses_domain(){
case "${1:-$(effective_address_mode)}" in
domain|all|legacy-domain4|legacy-domain6|legacy-domain-auto|auto) return 0 ;;
*) return 1 ;;
esac
}

direct_domain_matches_rewrite_host(){
cdn_rewrite_active || return 1
direct_host=$(normalize_host "${addym:-$domain}")
rewrite_host=$(normalize_host "${cdnym:-$(cat "$HOME/lun/cdnym" 2>/dev/null)}")
[ -n "$direct_host" ] && [ -n "$rewrite_host" ] || return 1
[ "$(endpoint_kind "$direct_host")" = DOMAIN ] || return 1
[ "$(endpoint_kind "$rewrite_host")" = DOMAIN ] || return 1
direct_host_key=$(printf '%s' "$direct_host" | tr '[:upper:]' '[:lower:]' | sed 's/\.$//')
rewrite_host_key=$(printf '%s' "$rewrite_host" | tr '[:upper:]' '[:lower:]' | sed 's/\.$//')
[ "$direct_host_key" = "$rewrite_host_key" ]
}

direct_domain_ip_guard_active(){
direct_mode_uses_domain "${1:-}" && direct_domain_matches_rewrite_host
}

direct_origin_ip_entries(){
origin_preference=${1:-auto}
origin_v4=$(normalize_host "${v4:-}")
origin_v6=$(normalize_host "${v6:-}")
[ "$(endpoint_kind "$origin_v4")" = V4 ] || origin_v4=
[ "$(endpoint_kind "$origin_v6")" = V6 ] || origin_v6=
if [ -z "$origin_v4" ] || [ -z "$origin_v6" ]; then
origin_logged=$(normalize_host "$(cat "$HOME/lun/server_ip.log" 2>/dev/null)")
case "$(endpoint_kind "$origin_logged")" in
V4) [ -n "$origin_v4" ] || origin_v4=$origin_logged ;;
V6) [ -n "$origin_v6" ] || origin_v6=$origin_logged ;;
esac
fi
case "$origin_preference" in
dual)
[ -n "$origin_v4" ] && printf '%s|IPv4\n' "$origin_v4"
[ -n "$origin_v6" ] && printf '%s|IPv6\n' "$origin_v6"
;;
ipv4)
if [ -n "$origin_v4" ]; then printf '%s|IPv4\n' "$origin_v4"; elif [ -n "$origin_v6" ]; then printf '%s|IPv6\n' "$origin_v6"; fi
;;
ipv6)
if [ -n "$origin_v6" ]; then printf '%s|IPv6\n' "$origin_v6"; elif [ -n "$origin_v4" ]; then printf '%s|IPv4\n' "$origin_v4"; fi
;;
*)
if [ -n "$origin_v4" ]; then printf '%s|IPv4\n' "$origin_v4"; elif [ -n "$origin_v6" ]; then printf '%s|IPv6\n' "$origin_v6"; fi
;;
esac
}

direct_address_entries(){
mode=$(effective_address_mode)
domain_addr=$(normalize_host "${addym:-$domain}")
direct_guard=no
direct_domain_ip_guard_active "$mode" && direct_guard=yes
case "$mode" in
domain)
if [ "$direct_guard" = yes ]; then
direct_origin_ip_entries auto
else
[ -n "$domain_addr" ] && printf '%s|DOMAIN\n' "$domain_addr"
fi
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
if [ "$direct_guard" = yes ]; then
direct_origin_ip_entries dual
else
[ -n "$domain_addr" ] && printf '%s|DOMAIN\n' "$domain_addr"
[ -n "$v4" ] && [ "$v4" != "$domain_addr" ] && printf '%s|IPv4\n' "$v4"
[ -n "$v6" ] && [ "$v6" != "$domain_addr" ] && printf '%s|IPv6\n' "$v6"
fi
;;
legacy-domain4)
if [ "$direct_guard" = yes ]; then
direct_origin_ip_entries ipv4
else
[ -n "$v4" ] && printf '%s|IPv4\n' "$v4"
[ -n "$domain_addr" ] && [ "$domain_addr" != "$v4" ] && printf '%s|DOMAIN\n' "$domain_addr"
fi
;;
legacy-domain6)
if [ "$direct_guard" = yes ]; then
direct_origin_ip_entries ipv6
else
[ -n "$v6" ] && printf '%s|IPv6\n' "$v6"
[ -n "$domain_addr" ] && [ "$domain_addr" != "$v6" ] && printf '%s|DOMAIN\n' "$domain_addr"
fi
;;
legacy-domain-auto)
if [ "$direct_guard" = yes ]; then
direct_origin_ip_entries auto
else
if [ -n "$v4" ]; then printf '%s|IPv4\n' "$v4"; elif [ -n "$v6" ]; then printf '%s|IPv6\n' "$v6"; fi
[ -n "$domain_addr" ] && [ "$domain_addr" != "$v4" ] && [ "$domain_addr" != "$v6" ] && printf '%s|DOMAIN\n' "$domain_addr"
fi
;;
*)
if [ "$direct_guard" = yes ]; then
direct_origin_ip_entries auto
elif [ -n "$v4" ]; then
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
if direct_domain_ip_guard_active "$(effective_address_mode)"; then
printf '源站 IP（端口回源自动保护）\n'
return
fi
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

port_map_count(){
maps=$1
[ -n "$maps" ] || { printf '0\n'; return; }
set -- $maps
printf '%s\n' "$#"
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
source_mode=${2:-configured}
tmp="${target}.tmp.$$"
if [ "$source_mode" = official ]; then
download_url="https://api.github.com/repos/azk78lun-collab/FHLUN/contents/lun.sh?ref=main"
fallback_url="https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh"
else
download_url=$lunurl
fallback_url=
case "$download_url" in
https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
fallback_url=$download_url
download_url="https://api.github.com/repos/azk78lun-collab/FHLUN/contents/lun.sh?ref=main"
;;
esac
fi
case "$download_url" in
https://raw.githubusercontent.com/*|https://github.com/*/raw/*|https://api.github.com/*)
case "$download_url" in
*\?*) download_url="${download_url}&fhlun_nocache=$(date +%s)" ;;
*) download_url="${download_url}?fhlun_nocache=$(date +%s)" ;;
esac
;;
esac
rm -f "$tmp"
if command -v curl >/dev/null 2>&1 && curl -fsSL -H 'Accept: application/vnd.github.raw+json' -H 'Cache-Control: no-cache' --connect-timeout 10 --max-time 30 --retry 2 "$download_url" -o "$tmp"; then
:
elif command -v wget >/dev/null 2>&1 && wget -qO "$tmp" --header='Accept: application/vnd.github.raw+json' --header='Cache-Control: no-cache' --timeout=30 --tries=2 "$download_url"; then
:
elif [ -n "$fallback_url" ] && command -v curl >/dev/null 2>&1 && curl -fsSL -H 'Cache-Control: no-cache' --connect-timeout 10 --max-time 30 --retry 2 "${fallback_url}?fhlun_nocache=$(date +%s)" -o "$tmp"; then
:
elif [ -n "$fallback_url" ] && command -v wget >/dev/null 2>&1 && wget -qO "$tmp" --header='Cache-Control: no-cache' --timeout=30 --tries=2 "${fallback_url}?fhlun_nocache=$(date +%s)" -o "$tmp"; then
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
apk update >/dev/null 2>&1 && apk add --no-cache bash busybox-extras curl gcompat libc6-compat iptables openssl >/dev/null 2>&1
elif command -v apt >/dev/null 2>&1; then
export DEBIAN_FRONTEND=noninteractive
printf 'iptables-persistent iptables-persistent/autosave_v4 boolean true\niptables-persistent iptables-persistent/autosave_v6 boolean true\n' | debconf-set-selections
apt update >/dev/null 2>&1 && apt install -y busybox coreutils curl util-linux iptables iptables-persistent cron openssl >/dev/null 2>&1
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
echo "$name" > "$HOME/lun/name"
echo
echo "服务器备注：$name（仅用于管理界面，不加入节点名称）"
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
echo "已尝试 Oracle 静态镜像，请检查 oracle1.1223344.xyz:8443/fhlun 服务和 IPv6 连通性。"
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
case "$detected_mode" in
ca)
case "$stored_mode" in domain|dns|ip) effective_mode=$stored_mode ;; *) effective_mode=ca ;; esac
;;
*) effective_mode=$detected_mode ;;
esac
preferred_name=${domain:-$(cat "$HOME/lun/cdnym" 2>/dev/null)}
subject=$(cert_subject_from_file "$cert_file" "$preferred_name")
printf '%s\n' "$effective_mode" > "$HOME/lun/cert_mode"
printf '%s\n' "$subject" > "$HOME/lun/cert_subject"
certmode=$effective_mode
cert_hash_update
}

cert_publicly_trusted_for_domain(){ (
cert_file=$1
host=$2
[ -s "$cert_file" ] && [ -n "$host" ] || return 1
[ "$(cert_detect_mode "$cert_file")" = ca ] || return 1
cert_covers_domain "$cert_file" "$host" || return 1
openssl x509 -in "$cert_file" -noout -checkend 0 >/dev/null 2>&1 || return 1
leaf="/tmp/lun-public-leaf.$$"
chain="/tmp/lun-public-chain.$$"
awk '
/-----BEGIN CERTIFICATE-----/ { block++ }
block == 1 { print }
' "$cert_file" > "$leaf"
awk '
/-----BEGIN CERTIFICATE-----/ { block++ }
block >= 2 { print }
' "$cert_file" > "$chain"
ca_file=
for candidate in /etc/ssl/certs/ca-certificates.crt /etc/ssl/cert.pem /etc/pki/tls/certs/ca-bundle.crt; do
[ -s "$candidate" ] && { ca_file=$candidate; break; }
done
if [ -n "$ca_file" ]; then
if [ -s "$chain" ]; then
openssl verify -purpose sslserver -CAfile "$ca_file" -untrusted "$chain" "$leaf" >/dev/null 2>&1
else
openssl verify -purpose sslserver -CAfile "$ca_file" "$leaf" >/dev/null 2>&1
fi
verify_rc=$?
else
verify_rc=1
fi
rm -f "$leaf" "$chain"
[ "$verify_rc" = 0 ]
) }

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
if [ "${ONECLICK_FORCE_CERT:-no}" != yes ] && reuse_local_cert_interactive; then return 0; fi
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
if [ "${ONECLICK_FORCE_CERT:-no}" = yes ]; then
prepare_runtime_cert || { echo "XHTTP TLS 证书准备失败。"; return 1; }
elif cert_key_matches "$HOME/lun/cert.crt" "$HOME/lun/private.key"; then
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
if cluster_enabled; then
if { pidof systemd >/dev/null 2>&1 && systemctl is-active --quiet lun-cluster-agent 2>/dev/null; } \
|| { command -v rc-service >/dev/null 2>&1 && rc-service lun-cluster-agent status >/dev/null 2>&1; }; then
echo "服务器联动：$(cluster_role) / 运行中"
else
echo "服务器联动：$(cluster_role) / 未运行"
fi
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

multiuser_module_dir(){
printf '%s\n' "$HOME/lun/modules/multiuser"
}

multiuser_agent(){
printf '%s\n' "$(multiuser_module_dir)/lun-agent"
}

multiuser_installed(){
[ -x "$(multiuser_agent)" ] && [ -s "$(multiuser_module_dir)/lun_agent.py" ] && [ -s "$(multiuser_module_dir)/config.json" ]
}

multiuser_enabled(){
multiuser_installed || return 1
grep -Eq '"enabled"[[:space:]]*:[[:space:]]*true' "$(multiuser_module_dir)/config.json" 2>/dev/null
}

multiuser_cmd(){
agent=$(multiuser_agent)
[ -x "$agent" ] || { echo "多用户代理程序未安装。" >&2; return 1; }
"$agent" --root "$HOME/lun" "$@"
}

multiuser_sync_subscription_state(){
multiuser_enabled || return 0
multiuser_cmd sync-subscription-state >/dev/null
}

multiuser_service_stop(){
if pidof systemd >/dev/null 2>&1; then
systemctl stop lun-agent >/dev/null 2>&1 || true
elif command -v rc-service >/dev/null 2>&1; then
rc-service lun-agent stop >/dev/null 2>&1 || true
fi
for P in /proc/[0-9]*; do
[ -r "$P/cmdline" ] || continue
PID=$(basename "$P")
CMD=$(tr '\0' ' ' < "$P/cmdline" 2>/dev/null)
case "$CMD" in *"/lun/modules/multiuser/lun_agent.py"*" serve"*) kill "$PID" 2>/dev/null || true ;; esac
done
}

multiuser_clear_legacy_subscription_autostart(){
mu_cron_tmp="/tmp/lun-crontab-$$"
if crontab -l > "$mu_cron_tmp" 2>/dev/null; then
sed -i '/weblun/d' "$mu_cron_tmp"
crontab "$mu_cron_tmp" >/dev/null 2>&1 || true
fi
rm -f "$mu_cron_tmp"
rm -f /etc/local.d/alpinesublun.start
}

multiuser_prepare_service_port(){
multiuser_enabled || return 0
stop_subscription_service
multiuser_clear_legacy_subscription_autostart
sleep 1
mu_service_port=$(multiuser_config_value port)
valid_port_value "$mu_service_port" || {
red_line "多用户订阅端口配置无效。"
return 1
}
if ! port_in_use "$mu_service_port"; then
return 0
fi
yellow_line "多用户订阅端口 $mu_service_port 被非风火轮进程占用，正在自动选择可用端口。"
mu_service_new=$(select_subscription_port "") || {
red_line "没有可用的订阅端口；网站访问监控仍会独立运行。"
is_nat_mode && yellow_line "请先增加一组未占用的公网端口 → 内网端口映射，再重新启动多用户订阅。"
return 1
}
mu_service_public=$(client_port "$mu_service_new")
if is_nat_mode && [ "$mu_service_public" = "$mu_service_new" ]; then
red_line "新内网端口 $mu_service_new 没有 NAT 公网映射，已拒绝写入。"
return 1
fi
multiuser_cmd set-subscription-port --port "$mu_service_new" --public-port "$mu_service_public" >/dev/null || return 1
printf '%s\n' "$mu_service_new" > "$HOME/lun/subport.log"
green_line "多用户订阅端口已迁移：内网 $mu_service_new / 公网 $mu_service_public。"
apply_lun_firewall_rules quiet || true
}

multiuser_service_start(){
multiuser_enabled || return 0
multiuser_service_stop
multiuser_prepare_service_port || return 1
if pidof systemd >/dev/null 2>&1; then
systemctl enable --now lun-agent >/dev/null 2>&1 || return 1
sleep 1
systemctl is-active --quiet lun-agent
elif command -v rc-service >/dev/null 2>&1; then
rc-update add lun-agent default >/dev/null 2>&1 || true
rc-service lun-agent start >/dev/null 2>&1 || return 1
rc-service lun-agent status >/dev/null 2>&1
else
echo "多用户模块要求 systemd 或 OpenRC，未启动不可靠的无 init 常驻进程。" >&2
return 1
fi
}

multiuser_service_restart(){
multiuser_enabled || return 0
multiuser_service_stop
multiuser_service_start
}

multiuser_install_service(){
python_bin=$(command -v python3) || return 1
agent_py="$(multiuser_module_dir)/lun_agent.py"
if pidof systemd >/dev/null 2>&1; then
cat > /etc/systemd/system/lun-agent.service <<EOF
[Unit]
Description=FHLUN multi-user and subscription agent
After=network.target xr.service sb.service

[Service]
Type=simple
User=root
ExecStart=$python_bin $agent_py --root $HOME/lun serve
Restart=on-failure
RestartSec=5s
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=full
ReadWritePaths=$HOME/lun
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >/dev/null 2>&1
systemctl enable lun-agent >/dev/null 2>&1
elif command -v rc-service >/dev/null 2>&1; then
cat > /etc/init.d/lun-agent <<EOF
#!/sbin/openrc-run
description="FHLUN multi-user and subscription agent"
command="$python_bin"
command_args="$agent_py --root $HOME/lun serve"
command_background=yes
pidfile="/run/lun-agent.pid"
output_log="/var/log/lun-agent.log"
error_log="/var/log/lun-agent.log"
depend() {
need net
after xray sing-box
}
EOF
chmod +x /etc/init.d/lun-agent
rc-update add lun-agent default >/dev/null 2>&1
else
red_line "多用户模块要求 systemd 或 OpenRC；当前系统不提供可靠的服务管理，已拒绝安装。"
return 1
fi
}

multiuser_remove_service(){
multiuser_service_stop
if pidof systemd >/dev/null 2>&1; then
systemctl disable lun-agent >/dev/null 2>&1 || true
rm -f /etc/systemd/system/lun-agent.service
systemctl daemon-reload >/dev/null 2>&1 || true
elif command -v rc-service >/dev/null 2>&1; then
rc-update del lun-agent default >/dev/null 2>&1 || true
rm -f /etc/init.d/lun-agent
fi
}

visit_monitor_enabled(){
[ -x "$(multiuser_agent)" ] || return 1
multiuser_cmd --json visit-status 2>/dev/null | grep -Eq '"enabled"[[:space:]]*:[[:space:]]*true'
}

visit_monitor_service_stop(){
if pidof systemd >/dev/null 2>&1; then
systemctl stop lun-visit-monitor >/dev/null 2>&1 || true
elif command -v rc-service >/dev/null 2>&1; then
rc-service lun-visit-monitor stop >/dev/null 2>&1 || true
fi
for P in /proc/[0-9]*; do
[ -r "$P/cmdline" ] || continue
PID=$(basename "$P")
CMD=$(tr '\0' ' ' < "$P/cmdline" 2>/dev/null)
case "$CMD" in *"/lun/modules/multiuser/lun_agent.py"*" visit-serve"*) kill "$PID" 2>/dev/null || true ;; esac
done
}

visit_monitor_service_start(){
visit_monitor_enabled || return 0
if pidof systemd >/dev/null 2>&1; then
systemctl enable --now lun-visit-monitor >/dev/null 2>&1 || return 1
sleep 1
systemctl is-active --quiet lun-visit-monitor
elif command -v rc-service >/dev/null 2>&1; then
rc-update add lun-visit-monitor default >/dev/null 2>&1 || true
rc-service lun-visit-monitor start >/dev/null 2>&1 || return 1
rc-service lun-visit-monitor status >/dev/null 2>&1
else
echo "网站访问监控要求 systemd 或 OpenRC，未启动不可靠的无 init 常驻进程。" >&2
return 1
fi
}

visit_monitor_service_restart(){
visit_monitor_service_stop
visit_monitor_service_start
}

visit_monitor_install_service(){
python_bin=$(command -v python3) || return 1
agent_py="$(multiuser_module_dir)/lun_agent.py"
if pidof systemd >/dev/null 2>&1; then
cat > /etc/systemd/system/lun-visit-monitor.service <<EOF
[Unit]
Description=FHLUN website visit monitor
After=network.target xr.service sb.service

[Service]
Type=simple
User=root
ExecStart=$python_bin $agent_py --root $HOME/lun visit-serve
Restart=on-failure
RestartSec=5s
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=full
ReadWritePaths=$HOME/lun
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >/dev/null 2>&1
systemctl enable lun-visit-monitor >/dev/null 2>&1
elif command -v rc-service >/dev/null 2>&1; then
cat > /etc/init.d/lun-visit-monitor <<EOF
#!/sbin/openrc-run
description="FHLUN website visit monitor"
command="$python_bin"
command_args="$agent_py --root $HOME/lun visit-serve"
command_background=yes
pidfile="/run/lun-visit-monitor.pid"
output_log="/var/log/lun-visit-monitor.log"
error_log="/var/log/lun-visit-monitor.log"
depend() {
need net
after xray sing-box
}
EOF
chmod +x /etc/init.d/lun-visit-monitor
rc-update add lun-visit-monitor default >/dev/null 2>&1
else
red_line "网站访问监控要求 systemd 或 OpenRC；当前系统无法提供可靠常驻服务。"
return 1
fi
}

visit_monitor_remove_service(){
visit_monitor_service_stop
if pidof systemd >/dev/null 2>&1; then
systemctl disable lun-visit-monitor >/dev/null 2>&1 || true
rm -f /etc/systemd/system/lun-visit-monitor.service
systemctl daemon-reload >/dev/null 2>&1 || true
elif command -v rc-service >/dev/null 2>&1; then
rc-update del lun-visit-monitor default >/dev/null 2>&1 || true
rm -f /etc/init.d/lun-visit-monitor
fi
}

cluster_module_dir(){
printf '%s\n' "$HOME/lun/modules/cluster"
}

cluster_agent(){
printf '%s\n' "$(cluster_module_dir)/lun-cluster"
}

cluster_installed(){
[ -x "$(cluster_agent)" ] && [ -s "$(cluster_module_dir)/lun_cluster.py" ] && [ -s "$(cluster_module_dir)/config.json" ]
}

cluster_enabled(){
cluster_installed || return 1
grep -Eq '"enabled"[[:space:]]*:[[:space:]]*true' "$(cluster_module_dir)/config.json" 2>/dev/null
}

cluster_config_value(){
cluster_key=$1
cluster_file="$(cluster_module_dir)/config.json"
[ -s "$cluster_file" ] || return 1
if command -v python3 >/dev/null 2>&1; then
python3 - "$cluster_file" "$cluster_key" <<'PY'
import json
import sys
try:
    value = json.load(open(sys.argv[1], encoding="utf-8")).get(sys.argv[2], "")
except (OSError, ValueError):
    value = ""
print(str(value).lower() if isinstance(value, bool) else value)
PY
else
sed -n "s/^[[:space:]]*\"$cluster_key\"[[:space:]]*:[[:space:]]*[\"']*\([^\"',}]*\).*/\1/p" "$cluster_file" | head -n1
fi
}

cluster_role(){
cluster_config_value role
}

cluster_cmd(){
cluster_exec=$(cluster_agent)
[ -x "$cluster_exec" ] || { echo "服务器联动程序未安装。" >&2; return 1; }
"$cluster_exec" --root "$HOME/lun" "$@"
}

cluster_service_stop(){
if pidof systemd >/dev/null 2>&1; then
systemctl stop lun-cluster-agent >/dev/null 2>&1 || true
elif command -v rc-service >/dev/null 2>&1; then
rc-service lun-cluster-agent stop >/dev/null 2>&1 || true
fi
for P in /proc/[0-9]*; do
[ -r "$P/cmdline" ] || continue
PID=$(basename "$P")
CMD=$(tr '\0' ' ' < "$P/cmdline" 2>/dev/null)
case "$CMD" in *"/lun/modules/cluster/lun_cluster.py"*" serve"*) kill "$PID" 2>/dev/null || true ;; esac
done
}

cluster_service_start(){
cluster_enabled || return 0
if pidof systemd >/dev/null 2>&1; then
systemctl enable --now lun-cluster-agent >/dev/null 2>&1 || return 1
sleep 1
systemctl is-active --quiet lun-cluster-agent
elif command -v rc-service >/dev/null 2>&1; then
rc-update add lun-cluster-agent default >/dev/null 2>&1 || true
rc-service lun-cluster-agent restart >/dev/null 2>&1 || return 1
rc-service lun-cluster-agent status >/dev/null 2>&1
else
return 1
fi
}

cluster_service_restart(){
cluster_service_stop
cluster_service_start
}

cluster_install_service(){
python_bin=$(command -v python3) || return 1
agent_py="$(cluster_module_dir)/lun_cluster.py"
if pidof systemd >/dev/null 2>&1; then
cat > /etc/systemd/system/lun-cluster-agent.service <<EOF
[Unit]
Description=FHLUN on-demand cluster controller and managed-node agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Environment=LUN_SCRIPT=/usr/bin/lun
ExecStart=$python_bin $agent_py --root $HOME/lun serve
Restart=always
RestartSec=3s
PrivateTmp=yes
UMask=0077
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >/dev/null 2>&1
systemctl enable lun-cluster-agent >/dev/null 2>&1
elif command -v rc-service >/dev/null 2>&1; then
cat > /etc/init.d/lun-cluster-agent <<EOF
#!/sbin/openrc-run
description="FHLUN on-demand cluster controller and managed-node agent"
command="$python_bin"
command_args="$agent_py --root $HOME/lun serve"
supervisor="supervise-daemon"
respawn_delay=3
respawn_max=0
pidfile="/run/lun-cluster-agent.pid"
output_log="/var/log/lun-cluster-agent.log"
error_log="/var/log/lun-cluster-agent.log"
export LUN_SCRIPT="/usr/bin/lun"
depend() {
need net
}
EOF
chmod +x /etc/init.d/lun-cluster-agent
rc-update add lun-cluster-agent default >/dev/null 2>&1
else
red_line "服务器联动要求 systemd 或 OpenRC；当前系统无法安装可靠服务。"
return 1
fi
}

cluster_remove_service(){
cluster_service_stop
if pidof systemd >/dev/null 2>&1; then
systemctl disable lun-cluster-agent >/dev/null 2>&1 || true
rm -f /etc/systemd/system/lun-cluster-agent.service
systemctl daemon-reload >/dev/null 2>&1 || true
elif command -v rc-service >/dev/null 2>&1; then
rc-update del lun-cluster-agent default >/dev/null 2>&1 || true
rm -f /etc/init.d/lun-cluster-agent
fi
}

cluster_download_agent(){
cluster_dir=$(cluster_module_dir)
cluster_target="$cluster_dir/lun_cluster.py"
cluster_tmp="$cluster_target.tmp.$$"
mkdir -p "$cluster_dir"
rm -f "$cluster_tmp"
if [ -n "${LUN_CLUSTER_AGENT_SOURCE:-}" ] && [ -s "$LUN_CLUSTER_AGENT_SOURCE" ]; then
cp "$LUN_CLUSTER_AGENT_SOURCE" "$cluster_tmp" || return 1
else
cluster_fallback=
if [ -n "${LUN_CLUSTER_AGENT_URL:-}" ]; then
cluster_url=$LUN_CLUSTER_AGENT_URL
else
cluster_url="https://api.github.com/repos/azk78lun-collab/FHLUN/contents/modules/cluster/lun_cluster.py?ref=main&fhlun_nocache=$(date +%s)"
cluster_fallback="https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/modules/cluster/lun_cluster.py?fhlun_nocache=$(date +%s)"
fi
if command -v curl >/dev/null 2>&1 && curl -fL -H 'Accept: application/vnd.github.raw+json' -H 'Cache-Control: no-cache' \
--connect-timeout 10 --max-time 120 --retry 2 -o "$cluster_tmp" "$cluster_url"; then
:
elif command -v wget >/dev/null 2>&1 && wget -O "$cluster_tmp" --header='Accept: application/vnd.github.raw+json' \
--header='Cache-Control: no-cache' --tries=2 --timeout=60 "$cluster_url"; then
:
elif [ -n "$cluster_fallback" ] && command -v curl >/dev/null 2>&1 && curl -fL -H 'Cache-Control: no-cache' \
--connect-timeout 10 --max-time 120 --retry 2 -o "$cluster_tmp" "$cluster_fallback"; then
:
elif [ -n "$cluster_fallback" ] && command -v wget >/dev/null 2>&1 && wget -O "$cluster_tmp" \
--header='Cache-Control: no-cache' --tries=2 --timeout=60 "$cluster_fallback"; then
:
else
rm -f "$cluster_tmp"
return 1
fi
fi
python3 -m py_compile "$cluster_tmp" >/dev/null 2>&1 || { rm -f "$cluster_tmp"; red_line "服务器联动程序语法校验失败。"; return 1; }
mv -f "$cluster_tmp" "$cluster_target"
chmod 700 "$cluster_target"
cat > "$cluster_dir/lun-cluster" <<EOF
#!/bin/sh
exec python3 "$cluster_target" "\$@"
EOF
chmod 700 "$cluster_dir/lun-cluster"
}

cluster_pick_port(){
cluster_existing=$(cluster_config_value internal_port 2>/dev/null)
if port_valid "$cluster_existing" && { [ "$cluster_existing" != 443 ] || [ "${LUN_CLUSTER_ALLOW_443:-no}" = yes ]; }; then
printf '%s\n' "$cluster_existing"
return 0
fi
for cluster_try in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
if is_nat_mode; then
cluster_candidate=$(random_nat_port 2>/dev/null) || return 1
else
cluster_candidate=$(random_port 2>/dev/null) || return 1
fi
[ "$cluster_candidate" = 443 ] && continue
port_reserved "$cluster_candidate" && continue
port_in_use "$cluster_candidate" && continue
printf '%s\n' "$cluster_candidate"
return 0
done
return 1
}

cluster_detect_public_host(){
cluster_host=$(cat "$HOME/lun/server_ip.log" 2>/dev/null)
cluster_host=${cluster_host#\[}; cluster_host=${cluster_host%\]}
if [ -z "$cluster_host" ]; then
cluster_host=$(local_public_ips | sed -n '1p')
fi
printf '%s\n' "$cluster_host"
}

cluster_push_event(){
[ "$(cluster_role 2>/dev/null)" = child ] || return 0
cluster_cmd push >/dev/null 2>&1 || true
}

cluster_refresh_profiles(){
[ "$(cluster_role 2>/dev/null)" = master ] || return 1
cluster_cmd refresh-profiles || return 1
if multiuser_enabled; then
multiuser_service_restart || true
else
restart_subscription_service >/dev/null 2>&1 || true
fi
}

cluster_install(){
cluster_new_role=$1
[ "$(id -u 2>/dev/null)" = 0 ] || { red_line "服务器联动安装需要 root。"; return 1; }
{ pidof systemd >/dev/null 2>&1 || command -v rc-service >/dev/null 2>&1; } || {
red_line "服务器联动只支持 systemd 或 OpenRC。"
return 1
}
[ -s "$HOME/lun/uuid" ] || { red_line "请先完成至少一个风火轮代理协议安装。"; return 1; }
multiuser_install_python || return 1
multiuser_download_agent || { red_line "服务器联动需要的多用户程序下载 / 复制失败。"; return 1; }
command -v openssl >/dev/null 2>&1 || { red_line "服务器联动需要 OpenSSL。"; return 1; }
cluster_download_agent || { red_line "服务器联动程序下载 / 复制失败。"; return 1; }
cluster_host=$(cluster_detect_public_host)
[ -n "$cluster_host" ] || { red_line "未检测到公网 IP，请先在节点地址设置中指定本机地址。"; return 1; }
cluster_default_port=$(cluster_pick_port) || {
red_line "没有可用于服务器联动的空闲端口。"
is_nat_mode && yellow_line "NAT VPS 必须先增加一组未被协议占用的公网端口 → 内网端口映射。"
return 1
}
cluster_default_public=$(client_port "$cluster_default_port")
if is_nat_mode; then
echo "自动分配：内网端口 $cluster_default_port / 公网端口 $cluster_default_public"
else
echo "自动分配通信端口：$cluster_default_port"
fi
printf "内网监听端口（回车使用自动值 %s，输入 0 返回）：" "$cluster_default_port"
IFS= read -r cluster_input_port
[ "$cluster_input_port" = 0 ] && return 1
[ -n "$cluster_input_port" ] && cluster_default_port=$cluster_input_port
port_valid "$cluster_default_port" || { red_line "通信端口无效。"; return 1; }
[ "$cluster_default_port" = 443 ] && { red_line "服务器联动默认禁止使用热门端口 443，请换一个高位 TCP 端口。"; return 1; }
port_reserved "$cluster_default_port" && { red_line "端口已被风火轮协议或订阅占用。"; return 1; }
port_in_use "$cluster_default_port" && { red_line "端口已被其他服务占用。"; return 1; }
cluster_default_public=$(client_port "$cluster_default_port")
if is_nat_mode && [ "$cluster_default_public" = "$cluster_default_port" ]; then
cluster_mapped=no
for cluster_pair in $ptmap; do
[ "${cluster_pair#*-}" = "$cluster_default_port" ] && cluster_mapped=yes
done
[ "$cluster_mapped" = yes ] || {
red_line "内网端口 $cluster_default_port 没有公网 NAT 映射。"
yellow_line "请在服务商面板新增 公网 TCP 端口 → $cluster_default_port，再更新 Lun NAT 映射。"
return 1
}
fi
printf "节点备注（可留空）："
IFS= read -r cluster_remark
if [ "$cluster_new_role" = master ]; then
cluster_cmd init-master --host "$cluster_host" --port "$cluster_default_port" --public-port "$cluster_default_public" --remark "$cluster_remark" || return 1
else
cluster_cmd init-child --host "$cluster_host" --port "$cluster_default_port" --public-port "$cluster_default_public" --remark "$cluster_remark" || return 1
fi
cluster_install_service || return 1
apply_lun_firewall_rules || true
cluster_service_start || { red_line "服务器联动服务启动失败。"; return 1; }
if [ "$cluster_new_role" = master ]; then
cluster_refresh_profiles >/dev/null 2>&1 || true
green_line "主 VPS 集群控制器已启用。"
else
green_line "子 VPS 联动服务已启用；把上方整条 lunjoin:// 加入地址粘贴到主 VPS。"
is_nat_mode && yellow_line "还需确认服务商公网 TCP $cluster_default_public 已映射到内网 $cluster_default_port。"
fi
return 0
}

cluster_read_password_file(){
cluster_password_prompt=$1
cluster_password_file=$(mktemp 2>/dev/null) || return 1
chmod 600 "$cluster_password_file"
printf "%s" "$cluster_password_prompt" >&2
if [ -t 0 ]; then stty -echo 2>/dev/null || true; fi
IFS= read -r cluster_password
if [ -t 0 ]; then stty echo 2>/dev/null || true; echo >&2; fi
printf '%s' "$cluster_password" > "$cluster_password_file"
unset cluster_password
printf '%s\n' "$cluster_password_file"
}

cluster_backup_ui(){
while :; do
ui_title "Lun 集群备份 / 加载备份"
echo " 1. 创建加密备份"
echo " 2. 加载备份"
echo " 3. 查看集群状态"
echo " 0. 返回"
printf "请选择 [0-3]："
IFS= read -r cluster_choice
case "$cluster_choice" in
1)
cluster_backup_path="$HOME/lun-cluster-backup-$(date +%Y%m%d-%H%M%S).lcb"
cluster_password_file=$(cluster_read_password_file "输入备份口令（至少8位，输入不显示）：") || continue
cluster_cmd backup --path "$cluster_backup_path" --password-file "$cluster_password_file"
cluster_rc=$?
rm -f "$cluster_password_file"
[ "$cluster_rc" = 0 ] && green_line "集群备份已保存：$cluster_backup_path"
ui_pause
;;
2)
printf "备份文件绝对路径（输入 0 返回）："
IFS= read -r cluster_backup_path
[ "$cluster_backup_path" = 0 ] && continue
[ -s "$cluster_backup_path" ] || { red_line "备份文件不存在。"; ui_pause; continue; }
cluster_password_file=$(cluster_read_password_file "输入备份口令（输入不显示）：") || continue
cluster_cmd restore --path "$cluster_backup_path" --password-file "$cluster_password_file"
cluster_rc=$?
rm -f "$cluster_password_file"
if [ "$cluster_rc" = 0 ]; then
cluster_install_service && cluster_service_restart
apply_lun_firewall_rules || true
green_line "备份已加载；请运行立即同步更新所有子机的主 VPS 地址。"
fi
ui_pause
;;
3) cluster_cmd status; ui_pause ;;
0|"") return ;;
*) echo "输入错误。" ;;
esac
done
}

cluster_show_subscription_links(){
cluster_refresh_profiles >/dev/null || return 1
cluster_host=$(cat "$HOME/lun/server_ip.log" 2>/dev/null)
cluster_host=${cluster_host#\[}; cluster_host=${cluster_host%\]}
cluster_scheme=http
cluster_sub_port=$(cat "$HOME/lun/subport.log" 2>/dev/null)
if multiuser_enabled; then
cluster_scheme=$(multiuser_config_value scheme)
cluster_host=$(multiuser_config_value public_host)
cluster_sub_port=$(multiuser_config_value public_port)
else
cluster_sub_port=$(client_port "$cluster_sub_port")
fi
[ -n "$cluster_host" ] && [ -n "$cluster_sub_port" ] || { red_line "没有可用于输出订阅的地址或端口。"; return 1; }
cluster_profiles_file=$(mktemp 2>/dev/null) || return 1
cluster_cmd --json profiles > "$cluster_profiles_file" 2>/dev/null || { rm -f "$cluster_profiles_file"; return 1; }
python3 - "$cluster_scheme" "$cluster_host" "$cluster_sub_port" "$cluster_profiles_file" <<'PY'
import json
import sys
try:
    with open(sys.argv[4], encoding="utf-8") as handle:
        rows = json.load(handle)
except ValueError:
    rows = []
scheme, host, port = sys.argv[1:4]
if ":" in host and not host.startswith("["):
    host = f"[{host}]"
for row in rows:
    base = f"{scheme}://{host}:{port}/{row['token']}"
    print(f"\n{row['name']}：")
    print(f"  v2rayN：{base}/jhsub.txt")
    print(f"  Clash： {base}/clmi.yaml")
    print(f"  Sing-box：{base}/sbox.json")
PY
cluster_rc=$?
rm -f "$cluster_profiles_file"
return "$cluster_rc"
}

cluster_parse_action_payload(){
cluster_pairs=$1
python3 - "$cluster_pairs" <<'PY'
import json
import shlex
import sys
result = {}
for item in shlex.split(sys.argv[1]):
    if "=" not in item:
        raise SystemExit("每项必须使用 变量=值")
    key, value = item.split("=", 1)
    result[key] = value
print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
PY
}

cluster_service_is_active(){
cluster_systemd_name=$1
cluster_openrc_name=$2
if pidof systemd >/dev/null 2>&1; then
systemctl is-active --quiet "$cluster_systemd_name" 2>/dev/null
elif command -v rc-service >/dev/null 2>&1; then
rc-service "$cluster_openrc_name" status >/dev/null 2>&1
else
return 1
fi
}

cluster_stop_core_process(){
cluster_core_name=$1
for cluster_proc in /proc/[0-9]*; do
[ -L "$cluster_proc/exe" ] || continue
cluster_exe=$(readlink -f "$cluster_proc/exe" 2>/dev/null) || continue
case "$cluster_exe" in
*"/lun/$cluster_core_name") kill "$(basename "$cluster_proc")" 2>/dev/null || true ;;
esac
done
}

cluster_argo_start(){
[ -x "$HOME/lun/cloudflared" ] || { echo "Argo/Cloudflared 未安装。" >&2; return 1; }
if pidof systemd >/dev/null 2>&1 && [ -s /etc/systemd/system/argo.service ]; then
systemctl start argo
elif command -v rc-service >/dev/null 2>&1 && [ -x /etc/init.d/argo ]; then
rc-service argo start
elif [ -s "$HOME/lun/sbargotoken.log" ]; then
nohup "$HOME/lun/cloudflared" tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run \
--token "$(cat "$HOME/lun/sbargotoken.log")" >/dev/null 2>&1 &
elif [ -s "$HOME/lun/argoport.log" ] && valid_port_value "$(cat "$HOME/lun/argoport.log")"; then
nohup "$HOME/lun/cloudflared" tunnel --url "http://localhost:$(cat "$HOME/lun/argoport.log")" \
--edge-ip-version auto --no-autoupdate --protocol http2 > "$HOME/lun/argo.log" 2>&1 &
else
echo "Argo 未配置 Token 或本地入口端口。" >&2
return 1
fi
}

cluster_argo_stop(){
if pidof systemd >/dev/null 2>&1; then
systemctl stop argo >/dev/null 2>&1 || true
elif command -v rc-service >/dev/null 2>&1; then
rc-service argo stop >/dev/null 2>&1 || true
fi
cluster_stop_core_process cloudflared
}

cluster_service_status(){
cluster_component=$1
case "$cluster_component" in
xray) lunstatus | sed -n '/^Xray/p' ;;
singbox) lunstatus | sed -n '/^Sing-box/p' ;;
argo) argo_status_line ;;
subscription)
if multiuser_enabled; then
cluster_service_is_active lun-agent lun-agent && echo "订阅服务：由多用户服务承载 / 运行中" || echo "订阅服务：由多用户服务承载 / 未运行"
elif pgrep -f "httpd.*-h $HOME/weblun" >/dev/null 2>&1; then
echo "订阅服务：运行中"
else
echo "订阅服务：未运行"
fi
;;
multiuser)
cluster_service_is_active lun-agent lun-agent && echo "多用户服务：运行中" || echo "多用户服务：未运行"
;;
visit)
cluster_service_is_active lun-visit-monitor lun-visit-monitor && echo "网站访问监控：运行中" || echo "网站访问监控：未运行"
;;
esac
return 0
}

cluster_service_control_local(){
cluster_component=$1
cluster_operation=$2
case "$cluster_component" in xray|singbox|argo|subscription|multiuser|visit) ;; *) echo "服务名称无效。" >&2; return 1 ;; esac
case "$cluster_operation" in status|start|stop|restart) ;; *) echo "服务操作无效。" >&2; return 1 ;; esac
[ "$cluster_operation" = status ] && { cluster_service_status "$cluster_component"; return; }
if [ "$cluster_operation" = stop ] || [ "$cluster_operation" = restart ]; then
case "$cluster_component" in
xray)
if pidof systemd >/dev/null 2>&1; then systemctl stop xr >/dev/null 2>&1 || true
elif command -v rc-service >/dev/null 2>&1; then rc-service xray stop >/dev/null 2>&1 || true; fi
cluster_stop_core_process xray
;;
singbox)
if pidof systemd >/dev/null 2>&1; then systemctl stop sb >/dev/null 2>&1 || true
elif command -v rc-service >/dev/null 2>&1; then rc-service sing-box stop >/dev/null 2>&1 || true; fi
cluster_stop_core_process sing-box
;;
argo) cluster_argo_stop ;;
subscription)
if multiuser_enabled; then
echo "当前订阅由多用户服务承载，请直接控制“多用户服务”。" >&2
return 1
fi
stop_subscription_service
;;
multiuser) multiuser_service_stop ;;
visit) visit_monitor_service_stop ;;
esac
[ "$cluster_operation" = stop ] && { cluster_service_status "$cluster_component"; return; }
fi
case "$cluster_component" in
xray) [ -x "$HOME/lun/xray" ] && [ -s "$HOME/lun/xr.json" ] || { echo "Xray 内核或配置不存在。" >&2; return 1; }; xrestart ;;
singbox) [ -x "$HOME/lun/sing-box" ] && [ -s "$HOME/lun/sb.json" ] || { echo "Sing-box 内核或配置不存在。" >&2; return 1; }; sbrestart ;;
argo) cluster_argo_start ;;
subscription) restart_subscription_service ;;
multiuser) multiuser_installed || { echo "多用户模块未安装。" >&2; return 1; }; multiuser_service_start ;;
visit) visit_monitor_enabled || { echo "网站访问监控未启用。" >&2; return 1; }; visit_monitor_service_start ;;
esac
cluster_service_status "$cluster_component"
}

cluster_write_install_payload(){
cluster_source_file=$1
cluster_payload_file=$2
[ -s "$cluster_source_file" ] || { echo "本机源文件不存在：$cluster_source_file" >&2; return 1; }
python3 - "$cluster_source_file" "$cluster_payload_file" <<'PY'
import base64
import hashlib
import json
import pathlib
import sys
content = pathlib.Path(sys.argv[1]).read_bytes()
payload = {"content": base64.b64encode(content).decode(), "sha256": hashlib.sha256(content).hexdigest()}
pathlib.Path(sys.argv[2]).write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
PY
chmod 600 "$cluster_payload_file"
}

cluster_remote_update_ui(){
cluster_update_node=$1
cluster_update_kind=$2
case "$cluster_update_kind" in
lun)
cluster_update_source=$(command -v lun 2>/dev/null)
[ -s "$cluster_update_source" ] || cluster_update_source=/usr/bin/lun
cluster_update_action=script.install
cluster_update_label="Lun 主脚本"
;;
agent) cluster_update_source="$(cluster_module_dir)/lun_cluster.py"; cluster_update_action=agent.install; cluster_update_label="服务器联动程序" ;;
*) return 1 ;;
esac
cluster_update_payload=$(mktemp "$HOME/lun/.cluster-update.XXXXXX") || return 1
if cluster_write_install_payload "$cluster_update_source" "$cluster_update_payload" \
&& cluster_cmd action --node-id "$cluster_update_node" --action "$cluster_update_action" --payload-file "$cluster_update_payload"; then
rm -f "$cluster_update_payload"
green_line "$cluster_update_label 已通过 mTLS 校验下发。"
return 0
fi
rm -f "$cluster_update_payload"
return 1
}

cluster_update_all_ui(){
ui_title "Lun 一键更新全部集群服务器"
cluster_cmd nodes || return 1
yellow_line "本机先从官方 main 检查一次更新；随后复用本机脚本，通过 mTLS 推送给主 VPS 与全部子 VPS。"
yellow_line "远端服务器不再分别访问 GitHub；脚本和联动程序均执行语法、SHA-256 与原子替换校验。"
printf "排除的服务器编号（多个用空格或逗号分隔；回车不排除；输入 0 返回）："
IFS= read -r cluster_update_exclude
[ "$cluster_update_exclude" = 0 ] && return 2

if ! update_lun_script; then
red_line "本机主脚本未能更新，已停止集群推送。"
return 1
fi
cluster_update_source=$(lun_update_target)
[ -s "$cluster_update_source" ] && bash -n "$cluster_update_source" 2>/dev/null || {
red_line "本机生效入口不是有效的 Lun 脚本：$cluster_update_source"
return 1
}
cluster_agent_source="$(cluster_module_dir)/lun_cluster.py"
if [ -s "$cluster_agent_source" ] \
&& python3 -m py_compile "$cluster_agent_source" >/dev/null 2>&1 \
&& grep -q 'update-all' "$cluster_agent_source"; then
green_line "已复用本机通过校验的服务器联动程序。"
elif ! cluster_download_agent; then
red_line "服务器联动程序下载失败，且本机缓存不支持集群更新。"
return 1
else
cluster_agent_source="$(cluster_module_dir)/lun_cluster.py"
[ -s "$cluster_agent_source" ] && python3 -m py_compile "$cluster_agent_source" >/dev/null 2>&1 && grep -q 'update-all' "$cluster_agent_source" || {
red_line "下载的服务器联动程序不支持集群更新，已停止推送。"
return 1
}
fi
cluster_install_service || return 1
cluster_service_restart || { red_line "本机服务器联动服务重启失败。"; return 1; }

cluster_script_payload=$(mktemp "$HOME/lun/.cluster-script.XXXXXX") || return 1
cluster_agent_payload=$(mktemp "$HOME/lun/.cluster-agent.XXXXXX") || { rm -f "$cluster_script_payload"; return 1; }
if cluster_write_install_payload "$cluster_update_source" "$cluster_script_payload" \
&& cluster_write_install_payload "$(cluster_module_dir)/lun_cluster.py" "$cluster_agent_payload" \
&& cluster_cmd update-all --script-payload "$cluster_script_payload" \
    --agent-payload "$cluster_agent_payload" --exclude "$cluster_update_exclude"; then
cluster_update_rc=0
else
cluster_update_rc=1
fi
rm -f "$cluster_script_payload" "$cluster_agent_payload"
if [ "$cluster_update_rc" = 0 ]; then
green_line "集群一键更新完成；主 VPS 与全部未排除子 VPS 已使用同一份本机脚本。"
cluster_role_now=$(cluster_role 2>/dev/null)
[ "$cluster_role_now" = child ] && cluster_cmd push >/dev/null 2>&1 || true
[ "$cluster_role_now" = master ] && cluster_refresh_profiles >/dev/null 2>&1 || true
return 0
fi
red_line "至少一台服务器更新失败；已成功的服务器保持新版本，请按上方编号重试。"
return 1
}

cluster_node_service_ui(){
cluster_target_node=$1
while :; do
ui_title "Lun 远程进程 / 服务控制"
echo " 1. Xray"
echo " 2. Sing-box"
echo " 3. Argo / Cloudflared"
echo " 4. 订阅服务"
echo " 5. 多用户服务"
echo " 6. 网站访问监控"
echo " 7. 服务器联动服务（可查看/重启）"
echo " 0. 返回"
printf "请选择 [0-7]："
IFS= read -r cluster_service_choice
case "$cluster_service_choice" in
1) cluster_component=xray ;;
2) cluster_component=singbox ;;
3) cluster_component=argo ;;
4) cluster_component=subscription ;;
5) cluster_component=multiuser ;;
6) cluster_component=visit ;;
7) cluster_component=cluster ;;
0|"") return ;;
*) red_line "输入错误。"; continue ;;
esac
echo " 1. 查看状态"
if [ "$cluster_component" = cluster ]; then
echo " 2. 重启联动服务"
echo " 0. 返回"
printf "请选择 [0-2]："
else
echo " 2. 启动"
echo " 3. 停止"
echo " 4. 重启"
echo " 0. 返回"
printf "请选择 [0-4]："
fi
IFS= read -r cluster_operation_choice
if [ "$cluster_component" = cluster ]; then
case "$cluster_operation_choice" in 1) cluster_operation=status ;; 2) cluster_operation=restart ;; 0|"") continue ;; *) red_line "输入错误。"; continue ;; esac
else
case "$cluster_operation_choice" in 1) cluster_operation=status ;; 2) cluster_operation=start ;; 3) cluster_operation=stop ;; 4) cluster_operation=restart ;; 0|"") continue ;; *) red_line "输入错误。"; continue ;; esac
fi
cluster_cmd action --node-id "$cluster_target_node" --action service.control \
--payload "{\"component\":\"$cluster_component\",\"operation\":\"$cluster_operation\"}"
ui_pause
done
}

cluster_node_action_ui(){
printf "子 VPS 节点编号（输入 0 返回）："
IFS= read -r cluster_node_id
[ "$cluster_node_id" = 0 ] && return
while :; do
ui_title "Lun 远程配置子 VPS"
echo "目标节点：$cluster_node_id"
echo " 1. 刷新状态"
echo " 2. 进程 / 服务控制"
echo " 3. 重启全部代理服务"
echo " 4. 下发当前 Lun 主脚本"
echo " 5. 下发当前服务器联动程序"
echo " 6. 更新 Xray 内核"
echo " 7. 更新 Sing-box 内核"
echo " 8. 同步防火墙"
echo " 9. 应用协议变量组"
echo "10. 创建远程快照"
echo "11. 清空配置（危险）"
echo "12. 卸载 Lun（危险）"
echo " 0. 返回"
printf "请选择 [0-12]："
IFS= read -r cluster_choice
case "$cluster_choice" in
1) cluster_cmd sync --node-id "$cluster_node_id" ;;
2) cluster_node_service_ui "$cluster_node_id" ;;
3) cluster_cmd action --node-id "$cluster_node_id" --action service.restart ;;
4) cluster_remote_update_ui "$cluster_node_id" lun ;;
5) cluster_remote_update_ui "$cluster_node_id" agent ;;
6) cluster_cmd action --node-id "$cluster_node_id" --action core.update --payload '{"core":"xray"}' ;;
7) cluster_cmd action --node-id "$cluster_node_id" --action core.update --payload '{"core":"singbox"}' ;;
8) cluster_cmd action --node-id "$cluster_node_id" --action firewall.apply ;;
9)
yellow_line "格式示例：vlpt=443 vxpt=8080 vpsmode=nat ptmap='52581-443 56567-8080'"
yellow_line "只接受 Lun 公开变量，不执行命令文本；敏感 Token 仅当次加密转交。"
printf "变量组（输入 0 返回）："
IFS= read -r cluster_pairs
[ "$cluster_pairs" = 0 ] && continue
cluster_payload=$(cluster_parse_action_payload "$cluster_pairs") || { red_line "变量组格式错误。"; ui_pause; continue; }
cluster_cmd action --node-id "$cluster_node_id" --action protocol.apply --payload "$cluster_payload"
;;
10) cluster_cmd action --node-id "$cluster_node_id" --action snapshot.create --payload '{"label":"manual-remote"}' ;;
11|12)
cluster_action=$([ "$cluster_choice" = 11 ] && echo lun.factory-reset || echo lun.uninstall)
red_line "危险操作只能单机执行；子机将先创建快照。"
printf "再次输入目标节点编号确认（输入 0 返回）："
IFS= read -r cluster_confirm
[ "$cluster_confirm" = 0 ] && continue
cluster_cmd action --node-id "$cluster_node_id" --action "$cluster_action" --payload "{\"confirm\":\"$cluster_confirm\"}"
;;
0|"") return ;;
*) echo "输入错误。" ;;
esac
ui_pause
done
}

cluster_add_node_ui(){
ui_title "Lun 添加子 VPS"
yellow_line "在子 VPS 进入同一模块并生成 lunjoin:// 地址，然后整条粘贴到这里。"
printf "加入地址（输入 0 返回）："
IFS= read -r cluster_join_uri
[ "$cluster_join_uri" = 0 ] && return
printf "节点备注（可留空）："
IFS= read -r cluster_remark
printf "预期代理 UUID（可留空，仅用于防止加错服务器）："
IFS= read -r cluster_expected_uuid
set -- add-node --uri "$cluster_join_uri" --remark "$cluster_remark"
[ -n "$cluster_expected_uuid" ] && set -- "$@" --expected-uuid "$cluster_expected_uuid"
if cluster_cmd "$@"; then
cluster_service_restart || true
cluster_refresh_profiles >/dev/null 2>&1 || true
green_line "子 VPS 已加入；其一次性加入地址已经失效。"
fi
ui_pause
}

cluster_assignment_ui(){
ui_title "Lun 用户与服务器授权"
multiuser_enabled || { yellow_line "多用户管理未启用；当前使用单用户全部/地区聚合订阅。"; ui_pause; return; }
multiuser_cmd list-users
cluster_cmd nodes
printf "用户 ID（输入 0 返回）："
IFS= read -r cluster_user_id
[ "$cluster_user_id" = 0 ] && return
printf "允许的节点编号，多个用逗号分隔；留空表示不开放子机："
IFS= read -r cluster_node_ids
cluster_cmd assign-user --user-id "$cluster_user_id" --nodes "$cluster_node_ids"
if [ $? = 0 ]; then
yellow_line "正在把该用户凭据、协议权限和订阅下发到授权节点……"
cluster_cmd sync-users || red_line "授权已保存，但有子 VPS 未完成同步；请在服务器总览检查通信。"
fi
ui_pause
}

cluster_batch_action_ui(){
ui_title "Lun 批量配置（金丝雀）"
cluster_cmd nodes
yellow_line "第一台为金丝雀；只有它成功后才会继续，其余最多 3 台并行。"
printf "子 VPS 节点编号（多个用空格或逗号分隔，输入 0 返回）："
IFS= read -r cluster_node_ids
[ "$cluster_node_ids" = 0 ] && return
echo " 1. 重启代理服务"
echo " 2. 同步防火墙"
echo " 3. 更新 Xray 内核"
echo " 4. 更新 Sing-box 内核"
echo " 5. 应用同一组协议变量"
echo " 0. 返回"
printf "请选择 [0-5]："
IFS= read -r cluster_choice
cluster_payload='{}'
case "$cluster_choice" in
1) cluster_action=service.restart ;;
2) cluster_action=firewall.apply ;;
3) cluster_action=core.update; cluster_payload='{"core":"xray"}' ;;
4) cluster_action=core.update; cluster_payload='{"core":"singbox"}' ;;
5)
printf "变量组（例如 vlpt=443 vxpt=8080，输入 0 返回）："
IFS= read -r cluster_pairs
[ "$cluster_pairs" = 0 ] && return
cluster_payload=$(cluster_parse_action_payload "$cluster_pairs") || { red_line "变量组格式错误。"; ui_pause; return; }
cluster_action=protocol.apply
;;
0|"") return ;;
*) red_line "输入错误。"; ui_pause; return ;;
esac
cluster_cmd batch-action --nodes "$cluster_node_ids" --action "$cluster_action" --payload "$cluster_payload"
cluster_rc=$?
[ "$cluster_rc" = 0 ] && cluster_refresh_profiles >/dev/null 2>&1 || true
ui_pause
}

cluster_switch_master_ui(){
ui_title "Lun 主 VPS / 子 VPS 角色互换"
cluster_cmd nodes || return 1
yellow_line "请选择要提升为新主 VPS 的子机；当前主 VPS 会在成功后自动降为子机。"
yellow_line "服务器编号、地区和节点名称保持不变，不会因角色变化重新编号。"
red_line "聚合订阅地址会改为新主 VPS；切换期间请勿关闭 SSH 或重启任一服务器。"
printf "目标子 VPS 编号（输入 0 返回）："
IFS= read -r cluster_node_id
[ "$cluster_node_id" = 0 ] && return 2
case "$cluster_node_id" in ''|*[!0-9]*) red_line "请输入服务器编号。"; return 1 ;; esac
cluster_number=$(printf '%s' "$cluster_node_id" | sed 's/^0*//')
[ -n "$cluster_number" ] || cluster_number=0
[ "$cluster_number" -gt 0 ] 2>/dev/null || { red_line "服务器编号无效。"; return 1; }
if [ "$cluster_number" -lt 100 ]; then cluster_number=$(printf '%02d' "$cluster_number"); fi
red_line "将转移集群数据库和 CA 私钥，并更新全部子机的主控授权；失败会自动回滚。"
printf "输入 SWITCH-%s 确认（输入 0 返回）：" "$cluster_number"
IFS= read -r cluster_confirm
[ "$cluster_confirm" = 0 ] && return 2
if cluster_cmd switch-master --node-id "$cluster_node_id" --confirm "$cluster_confirm"; then
cluster_service_restart || yellow_line "本机已降为子 VPS，但联动服务重启失败；请执行 systemctl restart lun-cluster-agent。"
apply_lun_firewall_rules >/dev/null 2>&1 || true
green_line "角色互换完成。请登录新主 VPS 查看新的聚合订阅地址。"
return 0
fi
return 1
}

cluster_master_menu(){
while :; do
ui_title "Lun 节点集群 / 主 VPS"
cluster_cmd nodes
ui_dash
echo " 1. 刷新服务器总览"
echo " 2. 添加子 VPS"
echo " 3. 配置单台子 VPS"
echo " 4. 批量配置（金丝雀 + 失败回滚）"
echo " 5. 立即同步子 VPS"
printf " 6. %s刷新并查看聚合订阅%s\n" "$LUN_GREEN" "$LUN_RESET"
echo " 7. 用户与服务器授权"
echo " 8. 地区设置"
echo " 9. 集群备份 / 加载备份"
echo "10. 通信状态 / 修复服务"
echo "11. 一键更新全部集群服务器"
echo "12. 更新本机服务器联动程序"
echo "13. 移除子 VPS / 撤销访问"
echo "14. 停用并卸载服务器联动模块"
printf "15. %s主 VPS / 子 VPS 角色互换%s\n" "$LUN_RED" "$LUN_RESET"
echo " 0. 返回"
printf "请选择 [0-15]："
IFS= read -r cluster_choice
case "$cluster_choice" in
1) cluster_cmd nodes; ui_pause ;;
2) cluster_add_node_ui ;;
3) cluster_node_action_ui ;;
4) cluster_batch_action_ui ;;
5)
printf "节点编号（输入 all 同步全部，输入 0 返回）："
IFS= read -r cluster_node_id
[ "$cluster_node_id" = 0 ] && continue
if [ "$cluster_node_id" = all ]; then
cluster_cmd sync-users || true
cluster_cmd --json nodes 2>/dev/null | python3 -c 'import json,sys; print(" ".join(x["id"] for x in json.load(sys.stdin) if x["role"]=="child"))' | while read -r cluster_ids; do
for cluster_id in $cluster_ids; do cluster_cmd sync --node-id "$cluster_id" || true; done
done
else
cluster_cmd sync-users --node-id "$cluster_node_id" || true
cluster_cmd sync --node-id "$cluster_node_id"
fi
cluster_refresh_profiles >/dev/null 2>&1 || true
ui_pause
;;
6) cluster_show_subscription_links; ui_pause ;;
7) cluster_assignment_ui ;;
8)
printf "节点编号（输入 0 返回）："; IFS= read -r cluster_node_id; [ "$cluster_node_id" = 0 ] && continue
printf "地区（如 日本-大阪 / 美国-洛杉矶 / 德国）："; IFS= read -r cluster_region
[ -n "$cluster_region" ] || { red_line "地区不能为空。"; ui_pause; continue; }
cluster_cmd set-location --node-id "$cluster_node_id" --region "$cluster_region"
cluster_refresh_profiles >/dev/null 2>&1 || true
ui_pause
;;
9) cluster_backup_ui ;;
10) cluster_cmd status; cluster_install_service; cluster_service_restart; apply_lun_firewall_rules; ui_pause ;;
11) cluster_update_all_ui; ui_pause ;;
12) cluster_download_agent && cluster_install_service && cluster_service_restart && green_line "服务器联动程序已更新。"; ui_pause ;;
13)
cluster_cmd nodes
printf "要移除的子 VPS 节点编号（输入 0 返回）："; IFS= read -r cluster_node_id
[ "$cluster_node_id" = 0 ] && continue
printf "再次输入该节点编号确认（输入 0 返回）："; IFS= read -r cluster_confirm
[ "$cluster_confirm" = 0 ] && continue
if cluster_cmd remove-node --node-id "$cluster_node_id" --confirm "$cluster_confirm"; then
cluster_cmd sync-users >/dev/null 2>&1 || true
cluster_refresh_profiles >/dev/null 2>&1 || true
fi
ui_pause
;;
14)
red_line "卸载只移除本机集群控制面；不会卸载代理协议或远端子 VPS。"
printf "输入 REMOVE 确认（输入 0 返回）："; IFS= read -r cluster_confirm
[ "$cluster_confirm" = REMOVE ] || continue
cluster_remove_service
rm -rf "$(cluster_module_dir)"
apply_lun_firewall_rules quiet || true
green_line "服务器联动模块已卸载。"
return
;;
15)
if cluster_switch_master_ui; then
ui_pause
return
fi
ui_pause
;;
0|"") return ;;
*) echo "输入错误。" ;;
esac
done
}

cluster_child_menu(){
while :; do
ui_title "Lun 节点集群 / 子 VPS"
cluster_cmd status
ui_dash
echo " 1. 生成新的一次性加入地址"
echo " 2. 立即向主 VPS 推送配置与订阅"
echo " 3. 修复 / 重启联动服务"
echo " 4. 集群备份 / 加载备份"
echo " 5. 一键更新全部集群服务器"
echo " 6. 更新本机服务器联动程序"
echo " 7. 解除并卸载本机联动模块"
echo " 0. 返回"
printf "请选择 [0-7]："
IFS= read -r cluster_choice
case "$cluster_choice" in
1) cluster_cmd join-code; ui_pause ;;
2) cluster_cmd push; ui_pause ;;
3) cluster_install_service; cluster_service_restart; apply_lun_firewall_rules; ui_pause ;;
4) cluster_backup_ui ;;
5) cluster_update_all_ui; ui_pause ;;
6) cluster_download_agent && cluster_install_service && cluster_service_restart && green_line "服务器联动程序已更新。"; ui_pause ;;
7)
red_line "解除后主 VPS 不能再管理本机；代理协议不会删除。"
printf "输入 REMOVE 确认（输入 0 返回）："; IFS= read -r cluster_confirm
[ "$cluster_confirm" = REMOVE ] || continue
cluster_remove_service
rm -rf "$(cluster_module_dir)"
apply_lun_firewall_rules quiet || true
green_line "本机服务器联动模块已卸载。"
return
;;
0|"") return ;;
*) echo "输入错误。" ;;
esac
done
}

cluster_menu(){
if ! cluster_installed; then
ui_title "Lun 节点集群（服务器联动）"
echo "可选模块；不开启时不会安装 Python 服务或开放通信端口。"
echo "服务器之间使用专用 TCP + mTLS，仅按需通信，不需要 SSH 密钥。"
echo " 1. 本机作为主 VPS / 控制器"
echo " 2. 本机作为子 VPS / 受管节点"
echo " 0. 返回"
printf "请选择 [0-2]："
IFS= read -r cluster_choice
case "$cluster_choice" in
1) cluster_install master || { ui_pause; return; } ;;
2) cluster_install child || { ui_pause; return; } ;;
0|"") return ;;
*) echo "输入错误。"; return ;;
esac
fi
case "$(cluster_role 2>/dev/null)" in
master) cluster_master_menu ;;
child) cluster_child_menu ;;
*) red_line "集群角色配置无效，请卸载模块后重新初始化。"; ui_pause ;;
esac
}

multiuser_reconcile_configs(){
multiuser_enabled || return 0
multiuser_cmd reconcile
}

firewall_append_port(){
local fw_proto=$1 fw_port=$2 fw_output=$3
valid_port_value "$fw_port" || return 0
case "$fw_proto" in tcp|udp) printf '%s:%s\n' "$fw_proto" "$fw_port" >> "$fw_output" ;; esac
}

firewall_append_file(){
local fw_proto=$1 fw_file=$2 fw_output=$3 fw_port
[ -s "$fw_file" ] || return 0
fw_port=$(sed -n '1{s/[[:space:]]//g;p;}' "$fw_file" 2>/dev/null)
firewall_append_port "$fw_proto" "$fw_port" "$fw_output"
}

collect_lun_firewall_ports(){
local fw_root=${1:-"$HOME/lun"} fw_output=$2 fw_spec fw_proto fw_file fw_config fw_values fw_sorted
[ -n "$fw_output" ] || return 1
: > "$fw_output" || return 1
for fw_spec in \
"tcp port_vl_re" \
"tcp port_xh" \
"tcp port_vx" \
"tcp port_vw" \
"tcp port_ss" "udp port_ss" \
"tcp port_an" \
"tcp port_ar" \
"tcp port_vm_ws" \
"tcp port_so" "udp port_so" \
"udp port_hy2" \
"udp port_tu" \
"udp port_xu" \
"tcp port_xc" "udp port_xc" \
"tcp port_nv" "udp port_nv"; do
set -- $fw_spec
fw_proto=$1
fw_file=$2
firewall_append_file "$fw_proto" "$fw_root/$fw_file" "$fw_output"
done
firewall_append_file tcp "$fw_root/subport.log" "$fw_output"
firewall_append_file tcp "$fw_root/subport_legacy.log" "$fw_output"
firewall_append_file tcp "$fw_root/cdnopt_port" "$fw_output"

fw_config="$fw_root/modules/multiuser/config.json"
if [ -s "$fw_config" ]; then
if command -v python3 >/dev/null 2>&1; then
fw_values=$(python3 - "$fw_config" <<'PY'
import json
import sys

try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
except (OSError, ValueError):
    data = {}
for key, protocols in (
    ("port", ("tcp",)),
    ("legacy_http_port", ("tcp",)),
    ("ss_port", ("tcp", "udp")),
):
    try:
        port = int(data.get(key) or 0)
    except (TypeError, ValueError):
        continue
    if 1 <= port <= 65535:
        for protocol in protocols:
            print(f"{protocol}:{port}")
PY
)
[ -n "$fw_values" ] && printf '%s\n' "$fw_values" >> "$fw_output"
else
for fw_spec in "tcp port" "tcp legacy_http_port" "tcp ss_port" "udp ss_port"; do
set -- $fw_spec
fw_port=$(sed -n "s/^[[:space:]]*\"$2\"[[:space:]]*:[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p" "$fw_config" 2>/dev/null | head -n 1)
firewall_append_port "$1" "$fw_port" "$fw_output"
done
fi
fi
fw_config="$fw_root/modules/cluster/config.json"
if [ -s "$fw_config" ]; then
if command -v python3 >/dev/null 2>&1; then
fw_values=$(python3 - "$fw_config" <<'PY'
import json
import sys
try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
    port = int(data.get("internal_port") or 0)
    enabled = bool(data.get("enabled"))
except (OSError, TypeError, ValueError):
    port = 0
    enabled = False
if enabled and 1 <= port <= 65535:
    print(f"tcp:{port}")
PY
)
[ -n "$fw_values" ] && printf '%s\n' "$fw_values" >> "$fw_output"
else
fw_port=$(sed -n 's/^[[:space:]]*"internal_port"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$fw_config" | head -n1)
grep -Eq '"enabled"[[:space:]]*:[[:space:]]*true' "$fw_config" && firewall_append_port tcp "$fw_port" "$fw_output"
fi
fi
fw_sorted=$(mktemp 2>/dev/null) || return 1
sort -u "$fw_output" > "$fw_sorted" || { rm -f "$fw_sorted"; return 1; }
mv "$fw_sorted" "$fw_output"
}

firewall_record_owned(){
local fw_backend=$1 fw_family=$2 fw_proto=$3 fw_port=$4 fw_owned="$HOME/lun/firewall_rules.log"
mkdir -p "$HOME/lun"
grep -qxF "$fw_backend $fw_family $fw_proto $fw_port" "$fw_owned" 2>/dev/null || \
printf '%s %s %s %s\n' "$fw_backend" "$fw_family" "$fw_proto" "$fw_port" >> "$fw_owned"
}

firewall_remove_record(){
local fw_backend=$1 fw_family=$2 fw_proto=$3 fw_port=$4
case "$fw_backend" in
ufw)
command -v ufw >/dev/null 2>&1 && ufw --force delete allow "$fw_port/$fw_proto" >/dev/null 2>&1 || true
;;
firewalld)
if command -v firewall-cmd >/dev/null 2>&1; then
firewall-cmd --query-port="$fw_port/$fw_proto" >/dev/null 2>&1 && firewall-cmd --remove-port="$fw_port/$fw_proto" >/dev/null 2>&1 || true
firewall-cmd --permanent --query-port="$fw_port/$fw_proto" >/dev/null 2>&1 && firewall-cmd --permanent --remove-port="$fw_port/$fw_proto" >/dev/null 2>&1 || true
fi
;;
iptables|ip6tables)
command -v "$fw_backend" >/dev/null 2>&1 && \
"$fw_backend" -C INPUT -p "$fw_proto" --dport "$fw_port" -m comment --comment FHLUN -j ACCEPT >/dev/null 2>&1 && \
"$fw_backend" -D INPUT -p "$fw_proto" --dport "$fw_port" -m comment --comment FHLUN -j ACCEPT >/dev/null 2>&1 || true
;;
esac
}

firewall_save_iptables(){
if command -v netfilter-persistent >/dev/null 2>&1; then
netfilter-persistent save >/dev/null 2>&1 || true
fi
if command -v rc-service >/dev/null 2>&1; then
rc-service iptables save >/dev/null 2>&1 || true
rc-service ip6tables save >/dev/null 2>&1 || true
fi
}

firewall_prune_owned(){
local fw_desired=$1 fw_owned="$HOME/lun/firewall_rules.log" fw_keep fw_backend fw_family fw_proto fw_port fw_changed
[ -s "$fw_owned" ] || return 0
fw_keep=$(mktemp 2>/dev/null) || return 1
fw_changed=no
while read -r fw_backend fw_family fw_proto fw_port; do
[ -n "$fw_backend" ] || continue
if grep -qxF "$fw_proto:$fw_port" "$fw_desired" 2>/dev/null; then
printf '%s %s %s %s\n' "$fw_backend" "$fw_family" "$fw_proto" "$fw_port" >> "$fw_keep"
else
firewall_remove_record "$fw_backend" "$fw_family" "$fw_proto" "$fw_port"
fw_changed=yes
fi
done < "$fw_owned"
mv "$fw_keep" "$fw_owned"
[ "$fw_changed" = yes ] && firewall_save_iptables
}

firewall_iptables_global_restrictive(){
local fw_command=$1 fw_rules fw_line
command -v "$fw_command" >/dev/null 2>&1 || return 1
fw_rules=$("$fw_command" -S INPUT 2>/dev/null) || return 1
printf '%s\n' "$fw_rules" | grep -Eq -- '^-P INPUT (DROP|REJECT)$' && return 0
while IFS= read -r fw_line; do
case "$fw_line" in
"-A INPUT -j DROP"|"-A INPUT -j REJECT") return 0 ;;
esac
done <<EOF
$fw_rules
EOF
return 1
}

firewall_iptables_port_restricted(){
local fw_command=$1 fw_proto=$2 fw_port=$3 fw_line fw_rules
fw_rules=$("$fw_command" -S INPUT 2>/dev/null) || return 1
while IFS= read -r fw_line; do
case "$fw_line" in
*" -s "*|*" -d "*|*" -i "*|*" -o "*) continue ;;
esac
case "$fw_line" in
*"-p $fw_proto "*"--dport $fw_port "*"-j DROP"*|*"-p $fw_proto "*"--dport $fw_port "*"-j REJECT"*) return 0 ;;
esac
done <<EOF
$fw_rules
EOF
return 1
}

firewall_native_nft_restrictive(){
command -v nft >/dev/null 2>&1 || return 1
nft list ruleset 2>/dev/null | grep -Eq 'hook input[^;]*;[^}]*policy (drop|reject)'
}

firewall_apply_ufw(){
local fw_desired=$1 fw_proto fw_port fw_fail=0
while IFS=: read -r fw_proto fw_port; do
[ -n "$fw_proto" ] || continue
if ufw status 2>/dev/null | awk -v rule="$fw_port/$fw_proto" '$1 == rule { found=1 } END { exit !found }'; then
continue
fi
if ufw allow "$fw_port/$fw_proto" comment FHLUN >/dev/null 2>&1 || ufw allow "$fw_port/$fw_proto" >/dev/null 2>&1; then
firewall_record_owned ufw any "$fw_proto" "$fw_port"
else
fw_fail=1
fi
done < "$fw_desired"
return "$fw_fail"
}

firewall_apply_firewalld(){
local fw_desired=$1 fw_proto fw_port fw_fail=0 fw_owned
while IFS=: read -r fw_proto fw_port; do
[ -n "$fw_proto" ] || continue
fw_owned=no
if ! firewall-cmd --permanent --query-port="$fw_port/$fw_proto" >/dev/null 2>&1; then
if firewall-cmd --permanent --add-port="$fw_port/$fw_proto" >/dev/null 2>&1; then
fw_owned=yes
else
fw_fail=1
fi
fi
firewall-cmd --query-port="$fw_port/$fw_proto" >/dev/null 2>&1 || \
firewall-cmd --add-port="$fw_port/$fw_proto" >/dev/null 2>&1 || fw_fail=1
[ "$fw_owned" = yes ] && firewall_record_owned firewalld any "$fw_proto" "$fw_port"
done < "$fw_desired"
return "$fw_fail"
}

firewall_apply_iptables_family(){
local fw_command=$1 fw_desired=$2 fw_proto fw_port fw_fail=0 fw_applied=no fw_global=no
command -v "$fw_command" >/dev/null 2>&1 || return 2
"$fw_command" -S INPUT >/dev/null 2>&1 || return 2
firewall_iptables_global_restrictive "$fw_command" && fw_global=yes
while IFS=: read -r fw_proto fw_port; do
[ -n "$fw_proto" ] || continue
[ "$fw_global" = yes ] || firewall_iptables_port_restricted "$fw_command" "$fw_proto" "$fw_port" || continue
fw_applied=yes
if "$fw_command" -C INPUT -p "$fw_proto" --dport "$fw_port" -j ACCEPT >/dev/null 2>&1 || \
"$fw_command" -C INPUT -p "$fw_proto" --dport "$fw_port" -m comment --comment FHLUN -j ACCEPT >/dev/null 2>&1; then
continue
fi
if "$fw_command" -I INPUT 1 -p "$fw_proto" --dport "$fw_port" -m comment --comment FHLUN -j ACCEPT >/dev/null 2>&1; then
firewall_record_owned "$fw_command" "$([ "$fw_command" = ip6tables ] && echo ipv6 || echo ipv4)" "$fw_proto" "$fw_port"
else
fw_fail=1
fi
done < "$fw_desired"
[ "$fw_applied" = yes ] || return 2
return "$fw_fail"
}

apply_lun_firewall_rules(){
local fw_mode=${1:-normal} fw_desired fw_backend=none fw_fail=0 fw_v4_rc=2 fw_v6_rc=2 fw_tcp fw_udp
fw_desired=$(mktemp 2>/dev/null) || return 1
collect_lun_firewall_ports "$HOME/lun" "$fw_desired" || { rm -f "$fw_desired"; return 1; }
cp -p "$fw_desired" "$HOME/lun/firewall_ports.log" 2>/dev/null || true
if [ "$(id -u 2>/dev/null)" != 0 ]; then
[ "$fw_mode" = quiet ] || yellow_line "当前不是 root，无法自动同步系统防火墙端口。"
rm -f "$fw_desired"
return 1
fi
firewall_prune_owned "$fw_desired" || true
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q '^Status: active'; then
fw_backend=UFW
firewall_apply_ufw "$fw_desired" || fw_fail=1
elif command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
fw_backend=Firewalld
firewall_apply_firewalld "$fw_desired" || fw_fail=1
else
firewall_apply_iptables_family iptables "$fw_desired"
fw_v4_rc=$?
firewall_apply_iptables_family ip6tables "$fw_desired"
fw_v6_rc=$?
if [ "$fw_v4_rc" -ne 2 ] || [ "$fw_v6_rc" -ne 2 ]; then
fw_backend=iptables
if [ "$fw_v4_rc" -eq 1 ] || [ "$fw_v6_rc" -eq 1 ]; then
fw_fail=1
fi
firewall_save_iptables
elif firewall_native_nft_restrictive; then
fw_backend="原生 nftables"
fw_fail=1
fi
fi
fw_tcp=$(grep -c '^tcp:' "$fw_desired" 2>/dev/null || true)
fw_udp=$(grep -c '^udp:' "$fw_desired" 2>/dev/null || true)
rm -f "$fw_desired"
[ "$fw_mode" = quiet ] && return "$fw_fail"
if [ "$fw_fail" -ne 0 ]; then
yellow_line "$fw_backend 防火墙未能完整自动放行，请手动核对 $HOME/lun/firewall_ports.log。"
elif [ "$fw_backend" = none ]; then
green_line "未检测到启用中的限制型系统防火墙；协议/订阅端口无需新增本机规则。"
else
green_line "$fw_backend 已同步风火轮端口：TCP $fw_tcp 项，UDP $fw_udp 项。"
fi
if is_nat_mode; then
yellow_line "系统防火墙只放行内网监听端口；服务商 NAT 公网端口映射和云安全组仍需手动配置。"
else
yellow_line "系统防火墙已处理；云服务商安全组仍需放行对应公网 TCP/UDP 端口。"
fi
return "$fw_fail"
}

remove_lun_firewall_rules(){
local fw_owned="$HOME/lun/firewall_rules.log" fw_backend fw_family fw_proto fw_port
[ -s "$fw_owned" ] || { rm -f "$HOME/lun/firewall_ports.log"; return 0; }
while read -r fw_backend fw_family fw_proto fw_port; do
[ -n "$fw_backend" ] || continue
firewall_remove_record "$fw_backend" "$fw_family" "$fw_proto" "$fw_port"
done < "$fw_owned"
firewall_save_iptables
rm -f "$fw_owned" "$HOME/lun/firewall_ports.log"
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
[ -s "$(multiuser_module_dir)/config.json" ] && multiuser_enabled && {
multiuser_sync_subscription_state || return 1
multiuser_cmd reconcile >/dev/null 2>&1 || return 1
if pidof systemd >/dev/null 2>&1; then
systemctl is-active --quiet lun-agent 2>/dev/null || multiuser_service_start
elif command -v rc-service >/dev/null 2>&1; then
rc-service lun-agent status >/dev/null 2>&1 || multiuser_service_start
fi
apply_lun_firewall_rules quiet || true
return 0
}
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
apply_lun_firewall_rules quiet || true
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
ensure_server_identity || { red_line "服务器身份初始化失败，请在节点订阅分享中重新设置地区。"; return 1; }
rm -rf "$HOME/lun/jhsub.txt"
rm -f "$HOME/lun/.cdn_sbox_entries" "$HOME/lun/.cdn_sbox_tags" "$HOME/lun/.cdn_clash_entries" "$HOME/lun/.cdn_clash_names"
uuid=$(cat "$HOME/lun/uuid")
server_ip=$(cat "$HOME/lun/server_ip.log")
xvvmcdnym=$(cat "$HOME/lun/cdnym" 2>/dev/null)
argoip_cfg=$(cat "$HOME/lun/argoip" 2>/dev/null)
[ -z "$argoip_cfg" ] && argoip_cfg="162.159.192.1 162.159.192.2"
direct_entries=$(direct_address_entries)
if [ -z "$direct_entries" ]; then
if direct_domain_ip_guard_active "$(effective_address_mode)"; then
red_line "Origin Rules 使用的橙云域名不能作为直连入口，且当前未检测到可用源站 IP；已停止生成订阅，避免输出必然失败的节点。"
fi
echo "当前地址输出模式 $(address_mode_label) 没有可用地址，请在高级设置中重新选择。"
return 1
fi
if direct_domain_ip_guard_active "$(effective_address_mode)"; then
yellow_line "已识别端口回源 Host ${cdnym:-$(cat "$HOME/lun/cdnym" 2>/dev/null)}：直连节点自动使用源站 IP；CDN/回源节点继续使用该域名与 CF 优选入口。"
fi
direct_entry_count=$(printf '%s\n' "$direct_entries" | sed '/^$/d' | wc -l | tr -d ' ')
primary_entry=$(printf '%s\n' "$direct_entries" | sed -n '1p')
client_addr_raw=${primary_entry%%|*}
primary_name_suffix=${primary_entry#*|}
client_addr=$(uri_host "$client_addr_raw")
client_addr_json=$(json_host "$client_addr_raw")
node_name_suffix=$(direct_node_suffix "$primary_name_suffix")
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
old_suffix_esc=$(sed_escape "$node_name_suffix")
new_name_suffix=$(direct_node_suffix "$new_suffix")
new_suffix_esc=$(sed_replacement_escape "$new_name_suffix")
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
vl_xh_link="vless://$uuid@$client_addr:$client_port_xh?encryption=$enkey&flow=xtls-rprx-vision&security=reality&sni=$ym_vl_re&fp=chrome&pbk=$public_key_x&sid=$short_id_x&type=xhttp&path=$uuid-xh&mode=auto#$(direct_node_name vless-xhttp-reality)"
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
vl_vx_link="vless://$uuid@$client_addr:$client_port_vx?encryption=$enkey&flow=xtls-rprx-vision&type=xhttp&path=$uuid-vx&mode=auto$vx_direct_extra#$(direct_node_name vless-xhttp)"
append_share_link "$vl_vx_link"
echo
if [ -f "$HOME/lun/cdnym" ] && cdn_protocol_enabled xhttp; then
append_vless_cdn_links "Vless-xhttp-enc-cdn" "vless-xhttp" "$port_vx" "encryption=$enkey&flow=xtls-rprx-vision&type=xhttp&path=$uuid-vx&mode=auto"
fi
fi
if grep xhttp-h3 "$HOME/lun/xr.json" >/dev/null 2>&1; then
echo "【 Vless-xhttp-tls-UDP 】节点信息如下："
port_xu=$(cat "$HOME/lun/port_xu")
client_port_xu=$(client_port "$port_xu")
vl_xu_link="vless://$uuid@$client_addr:$client_port_xu?encryption=none&security=tls&sni=$cert_sni&alpn=h3&fp=chrome&insecure=$generic_link_insecure&allowInsecure=$generic_link_insecure$generic_tls_pin_arg&type=xhttp&path=$uuid-xu&mode=auto#$(direct_node_name vless-xhttp-tls-udp)"
append_share_link "$vl_xu_link"
[ -f "$HOME/lun/cdnym" ] && cdn_skip "VLESS XHTTP TLS UDP 为直连 QUIC/UDP 协议，不生成普通 CDN 变体。"
echo
clxupt(){
cat <<EOF
- name: $(direct_node_name vless-xhttp-tls-udp)
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
echo "- $(direct_node_name vless-xhttp-tls-udp)"
}
fi
if grep xhttp-h23 "$HOME/lun/xr.json" >/dev/null 2>&1; then
echo "【 Vless-xhttp-tls-TCP/UDP 】直连节点信息如下："
port_xc=$(cat "$HOME/lun/port_xc")
client_port_xc=$(client_port "$port_xc")
vl_xc_link="vless://$uuid@$client_addr:$client_port_xc?encryption=none&security=tls&sni=$cert_sni&alpn=h2,http/1.1&fp=chrome&insecure=$generic_link_insecure&allowInsecure=$generic_link_insecure$generic_tls_pin_arg&type=xhttp&path=$uuid-xc&mode=auto#$(direct_node_name vless-xhttp-tls-tcp)"
append_share_link "$vl_xc_link"
echo
clxcpt(){
cat <<EOF
- name: $(direct_node_name vless-xhttp-tls-tcp)
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
echo "- $(direct_node_name vless-xhttp-tls-tcp)"
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
vl_vw_link="vless://$uuid@$client_addr:$client_port_vw?encryption=$enkey&type=ws&path=$uuid-vw$vw_direct_extra#$(direct_node_name vless-ws)"
append_share_link "$vl_vw_link"
echo
if [ -f "$HOME/lun/cdnym" ] && cdn_protocol_enabled ws; then
append_vless_cdn_links "Vless-ws-enc-cdn" "vless-ws" "$port_vw" "encryption=$enkey&type=ws&path=$uuid-vw"
fi
fi
if grep reality-vision "$HOME/lun/xr.json" >/dev/null 2>&1; then
echo "【 Vless-tcp-reality-vision 】节点信息如下："
port_vl_re=$(cat "$HOME/lun/port_vl_re")
client_port_vl_re=$(client_port "$port_vl_re")
vl_link="vless://$uuid@$client_addr:$client_port_vl_re?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$ym_vl_re&fp=chrome&pbk=$public_key_x&sid=$short_id_x&type=tcp&headerType=none#$(direct_node_name vless-tcp-reality)"
append_share_link "$vl_link"
[ -f "$HOME/lun/cdnym" ] && cdn_skip "VLESS TCP Reality 不是 HTTP/WS 回源协议，不生成普通橙云 CDN 变体。"
echo
sbvlpt(){
cat <<EOF
    {
      "type": "vless",
      "tag": "$(direct_node_name vless-tcp-reality)",
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
echo "\"$(direct_node_name vless-tcp-reality)\","
}
clvlpt(){
cat <<EOF
- name: $(direct_node_name vless-tcp-reality)
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
echo "- $(direct_node_name vless-tcp-reality)"
}
fi
if grep ss-2022 "$HOME/lun/sb.json" >/dev/null 2>&1; then
echo "【 Shadowsocks-2022 】节点信息如下："
port_ss=$(cat "$HOME/lun/port_ss")
client_port_ss=$(client_port "$port_ss")
ss_link="ss://$(echo -n "2022-blake3-aes-128-gcm:$sskey@$client_addr:$client_port_ss" | base64 -w0)#$(direct_node_name shadowsocks-2022)"
append_share_link "$ss_link"
[ -f "$HOME/lun/cdnym" ] && cdn_skip "Shadowsocks-2022 不是 HTTP/WS 回源协议，不生成普通橙云 CDN 变体。"
echo
sbsspt(){
cat <<EOF
{
       "type": "shadowsocks",
       "tag": "$(direct_node_name shadowsocks-2022)",
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
echo "\"$(direct_node_name shadowsocks-2022)\","
}
clsspt(){
cat <<EOF
- name: "$(direct_node_name shadowsocks-2022)"
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
echo "- $(direct_node_name shadowsocks-2022)"
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
vm_link="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$(direct_node_name vmess-ws)\", \"add\": \"$client_addr_json\", \"port\": \"$client_port_vm_ws\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$vm_direct_host\", \"path\": \"/$uuid-vm\", \"tls\": \"$vm_direct_tls\", \"sni\": \"$vm_direct_host\", \"allowInsecure\": \"$generic_link_insecure\"}" | base64 -w0)"
append_share_link "$vm_link"
echo
sbvmpt(){
cat <<EOF
{
            "server": "$client_addr",
            "server_port": $client_port_vm_ws,
            "tag": "$(direct_node_name vmess-ws)",
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
echo "\"$(direct_node_name vmess-ws)\","
}
clvmpt(){
cat <<EOF
- name: $(direct_node_name vmess-ws)
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
echo "- $(direct_node_name vmess-ws)"
}
if [ -f "$HOME/lun/cdnym" ] && cdn_protocol_enabled vmess; then
append_vmess_cdn_links "$port_vm_ws"
fi
fi
if grep naive-sb "$HOME/lun/sb.json" >/dev/null 2>&1; then
echo "【 NaiveProxy H2/H3 】节点信息如下："
port_nv=$(cat "$HOME/lun/port_nv")
client_port_nv=$(client_port "$port_nv")
nv_https_link="naive+https://$uuid:$uuid@$client_addr:$client_port_nv?security=tls&sni=$cert_sni&insecure=0&allowInsecure=0#$(direct_node_name naive-h2-native)"
nv_quic_link="naive+quic://$uuid:$uuid@$client_addr:$client_port_nv?congestion_control=bbr&security=tls&sni=$cert_sni&insecure=0&allowInsecure=0#$(direct_node_name naive-h3-native)"
nv_http2_link="http2://$uuid:$uuid@$client_addr:$client_port_nv?security=tls&sni=$cert_sni&insecure=0&allowInsecure=0&padding=1&tfo=1#$(direct_node_name naive-h2-http2)"
nv_http3_link="http3://$uuid:$uuid@$client_addr:$client_port_nv?security=tls&sni=$cert_sni&insecure=0&allowInsecure=0&padding=1&tfo=1#$(direct_node_name naive-h3-http3)"
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
      "tag": "$(direct_node_name naive-h3)",
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
      "tag": "$(direct_node_name naive-h2)",
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
echo "\"$(direct_node_name naive-h3)\","
echo "\"$(direct_node_name naive-h2)\","
}
fi
if grep anytls-sb "$HOME/lun/sb.json" >/dev/null 2>&1; then
echo "【 AnyTLS 】节点信息如下："
port_an=$(cat "$HOME/lun/port_an")
client_port_an=$(client_port "$port_an")
an_link="anytls://$uuid@$client_addr:$client_port_an?sni=$cert_sni&insecure=$generic_link_insecure&allowInsecure=$generic_link_insecure#$(direct_node_name anytls)"
append_share_link "$an_link"
[ -f "$HOME/lun/cdnym" ] && cdn_skip "AnyTLS 不是普通 HTTP/WS 回源协议，不生成普通橙云 CDN 变体。"
echo
sbanpt(){
cat <<EOF
         {
            "type": "anytls",
            "tag": "$(direct_node_name anytls)",
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
echo "\"$(direct_node_name anytls)\","
}
clanpt(){
cat <<EOF
- name: $(direct_node_name anytls)
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
echo "- $(direct_node_name anytls)"
}
fi
if grep anyreality-sb "$HOME/lun/sb.json" >/dev/null 2>&1; then
echo "【 Any-Reality 】节点信息如下："
port_ar=$(cat "$HOME/lun/port_ar")
client_port_ar=$(client_port "$port_ar")
ar_link="anytls://$uuid@$client_addr:$client_port_ar?security=reality&sni=$ym_vl_re&fp=chrome&pbk=$public_key_s&sid=$short_id_s&type=tcp&headerType=none#$(direct_node_name any-reality)"
append_share_link "$ar_link"
[ -f "$HOME/lun/cdnym" ] && cdn_skip "Any-Reality 不套用普通橙云 CDN，Reality SNI/回源逻辑保持独立。"
echo
sbarpt(){
cat <<EOF
    {
        "type": "anytls",
        "tag": "$(direct_node_name any-reality)",
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
echo "\"$(direct_node_name any-reality)\","
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
hy2_link="hysteria2://$uuid@$client_addr:$client_port_hy2?security=tls&alpn=h3&insecure=$hy2_link_insecure&allowInsecure=$hy2_link_insecure$hyps&sni=$cert_sni$hy2_pin_arg#$(direct_node_name hysteria2)"
append_share_link "$hy2_link"
[ -f "$HOME/lun/cdnym" ] && cdn_skip "Hysteria2 使用 UDP/QUIC 语义，不走 Cloudflare 普通橙云 CDN。"
echo
sbhypt(){
cat <<EOF
    {
        "type": "hysteria2",
        "tag": "$(direct_node_name hysteria2)",
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
echo "\"$(direct_node_name hysteria2)\","
}
clhypt(){
cat <<EOF
- name: $(direct_node_name hysteria2)
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
echo "- $(direct_node_name hysteria2)"
}
fi
if grep tuic5-sb "$HOME/lun/sb.json" >/dev/null 2>&1; then
echo "【 Tuic 】节点信息如下："
port_tu=$(cat "$HOME/lun/port_tu")
client_port_tu=$(client_port "$port_tu")
tuic5_link="tuic://$uuid:$uuid@$client_addr:$client_port_tu?congestion_control=bbr&udp_relay_mode=native&alpn=h3&sni=$cert_sni&insecure=$generic_link_insecure&allowInsecure=$generic_link_insecure&allow_insecure=$generic_link_insecure#$(direct_node_name tuic)"
append_share_link "$tuic5_link"
[ -f "$HOME/lun/cdnym" ] && cdn_skip "TUIC 使用 UDP/QUIC 语义，不走 Cloudflare 普通橙云 CDN。"
echo
sbtupt(){
cat <<EOF
        {
            "type":"tuic",
            "tag": "$(direct_node_name tuic)",
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
echo "\"$(direct_node_name tuic)\","
}
cltupt(){
cat <<EOF
- name: $(direct_node_name tuic)
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
echo "- $(direct_node_name tuic)"
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
argo_suffix=$(printf '%02d' "$argo_index")
argo_entries="$argo_entries $argo_addr|$argo_suffix"
done

argo_links_display=
if [ "$vlvm" = "Vmess" ]; then
for argo_entry in $argo_entries; do
argo_addr=${argo_entry%%|*}
argo_suffix=${argo_entry#*|}
tls_name=$(routed_node_name "vmess-ws-argo-tls-443-ar$argo_suffix")
http_name=$(routed_node_name "vmess-ws-argo-http-80-ar$argo_suffix")
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
  "tag": "$(routed_node_name "vmess-ws-argo-$(printf '%s' "$argo_label" | tr '[:upper:]' '[:lower:]')-$argo_port-ar$argo_suffix")",
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
for argo_entry in $argo_entries; do argo_suffix=${argo_entry#*|}; echo "\"$(routed_node_name "vmess-ws-argo-tls-443-ar$argo_suffix")\","; echo "\"$(routed_node_name "vmess-ws-argo-http-80-ar$argo_suffix")\","; done
}
clvmargopt(){
for argo_entry in $argo_entries; do
argo_addr=${argo_entry%%|*}; argo_suffix=${argo_entry#*|}
for argo_mode in tls http; do
if [ "$argo_mode" = tls ]; then argo_port=443; argo_tls=true; argo_label=TLS; else argo_port=80; argo_tls=false; argo_label=HTTP; fi
cat <<EOF
- name: $(routed_node_name "vmess-ws-argo-$(printf '%s' "$argo_label" | tr '[:upper:]' '[:lower:]')-$argo_port-ar$argo_suffix")
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
for argo_entry in $argo_entries; do argo_suffix=${argo_entry#*|}; echo "- $(routed_node_name "vmess-ws-argo-tls-443-ar$argo_suffix")"; echo "- $(routed_node_name "vmess-ws-argo-http-80-ar$argo_suffix")"; done
}
elif [ "$vlvm" = "Vless" ]; then
for argo_entry in $argo_entries; do
argo_addr=${argo_entry%%|*}
argo_suffix=${argo_entry#*|}
argo_uri=$(uri_host "$argo_addr")
tls_link="vless://$uuid@$argo_uri:443?encryption=$enkey&type=ws&host=$argodomain&path=/$uuid-vw&security=tls&sni=$argodomain&fp=chrome&insecure=0&allowInsecure=0#$(routed_node_name "vless-ws-argo-tls-443-ar$argo_suffix")"
http_link="vless://$uuid@$argo_uri:80?encryption=$enkey&type=ws&host=$argodomain&path=/$uuid-vw&security=none#$(routed_node_name "vless-ws-argo-http-80-ar$argo_suffix")"
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
  "tag": "$(routed_node_name "vless-ws-argo-$(printf '%s' "$argo_label" | tr '[:upper:]' '[:lower:]')-$argo_port-ar$argo_suffix")",
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
for argo_entry in $argo_entries; do argo_suffix=${argo_entry#*|}; echo "\"$(routed_node_name "vless-ws-argo-tls-443-ar$argo_suffix")\","; echo "\"$(routed_node_name "vless-ws-argo-http-80-ar$argo_suffix")\","; done
}
clvmargopt(){
for argo_entry in $argo_entries; do
argo_addr=${argo_entry%%|*}; argo_suffix=${argo_entry#*|}
for argo_mode in tls http; do
if [ "$argo_mode" = tls ]; then argo_port=443; argo_tls=true; argo_label=TLS; else argo_port=80; argo_tls=false; argo_label=HTTP; fi
cat <<EOF
- name: $(routed_node_name "vless-ws-argo-$(printf '%s' "$argo_label" | tr '[:upper:]' '[:lower:]')-$argo_port-ar$argo_suffix")
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
for argo_entry in $argo_entries; do argo_suffix=${argo_entry#*|}; echo "- $(routed_node_name "vless-ws-argo-tls-443-ar$argo_suffix")"; echo "- $(routed_node_name "vless-ws-argo-http-80-ar$argo_suffix")"; done
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
node_name_suffix=$(direct_node_suffix "$entry_suffix")
out=$($f)
[ -n "$out" ] && printf "%s\n" "$out"
done
client_addr=$(uri_host "$client_addr_raw")
client_addr_json=$(json_host "$client_addr_raw")
node_name_suffix=$(direct_node_suffix "$primary_name_suffix")
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
if restart_subscription_service; then
show_subscription_links
elif [ -s "$HOME/lun/subport.log" ]; then
yellow_line "订阅服务未启动，暂不输出不可用链接；请进入“节点订阅分享”重试。"
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
[ -s "$HOME/lun/oneclick_full_pending" ] && [ -f "$rebuild_snapshot/oneclick_prepared" ] && return 0
rm -rf "$rebuild_snapshot"
mkdir -p "$rebuild_snapshot/lun" "$rebuild_snapshot/services" || return 1
for rebuild_file in \
"$HOME/lun"/*.json "$HOME/lun"/port_* "$HOME/lun"/sbargo* "$HOME/lun"/argo* \
"$HOME/lun"/uuid "$HOME/lun"/domain "$HOME/lun"/cert_* "$HOME/lun"/cert.crt "$HOME/lun"/private.key "$HOME/lun"/SHA256.txt \
"$HOME/lun"/acme_* "$HOME/lun"/cert.env "$HOME/lun"/vps_mode "$HOME/lun"/port_map "$HOME/lun"/port_pool \
"$HOME/lun"/inner_port_pool "$HOME/lun"/outer_port_pool "$HOME/lun"/sub* "$HOME/lun"/cdn* "$HOME/lun"/cfip* \
"$HOME/lun"/xvvmcdnym "$HOME/lun"/address_mode "$HOME/lun"/addym "$HOME/lun"/addout "$HOME/lun"/ipp* \
"$HOME/lun"/warp* "$HOME/lun"/ym_vl_re "$HOME/lun"/name "$HOME/lun"/server_number "$HOME/lun"/server_place "$HOME/lun"/vlvm; do
[ -f "$rebuild_file" ] || continue
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
if [ -s "$HOME/lun/oneclick_full_pending" ]; then
oneclick_cloud_rollback >/dev/null 2>&1 || true
fi
rm -f "$HOME/lun"/*.json "$HOME/lun"/port_* "$HOME/lun"/sbargo* "$HOME/lun"/argo* \
"$HOME/lun"/uuid "$HOME/lun"/domain "$HOME/lun"/cert_* "$HOME/lun"/cert.crt "$HOME/lun"/private.key "$HOME/lun"/SHA256.txt \
"$HOME/lun"/acme_* "$HOME/lun"/cert.env "$HOME/lun"/vps_mode "$HOME/lun"/port_map "$HOME/lun"/port_pool \
"$HOME/lun"/inner_port_pool "$HOME/lun"/outer_port_pool "$HOME/lun"/sub* "$HOME/lun"/cdn* "$HOME/lun"/cfip* \
"$HOME/lun"/xvvmcdnym "$HOME/lun"/address_mode "$HOME/lun"/addym "$HOME/lun"/addout "$HOME/lun"/ipp* \
"$HOME/lun"/warp* "$HOME/lun"/ym_vl_re "$HOME/lun"/name "$HOME/lun"/server_number "$HOME/lun"/server_place "$HOME/lun"/vlvm \
"$HOME/lun"/oneclick_*
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
visit_monitor_service_start >/dev/null 2>&1 || true
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
multiuser_service_stop
visit_monitor_service_stop
if [ "$keep_entry" != "keep-entry" ]; then
cluster_remove_service
remove_lun_firewall_rules
if [ -s "$(multiuser_module_dir)/data/lun.db" ]; then
multiuser_backup_path="$HOME/lun-multiuser-backup-$(date +%Y%m%d-%H%M%S).sqlite3"
cp -p "$(multiuser_module_dir)/data/lun.db" "$multiuser_backup_path" 2>/dev/null && echo "多用户数据库已备份：$multiuser_backup_path"
fi
multiuser_bandwidth_remove
multiuser_remove_service
visit_monitor_remove_service
fi
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
if cluster_enabled && [ "${LUN_CLUSTER_DESTRUCTIVE:-no}" != yes ]; then
red_line "本机已加入服务器联动；请先在主 VPS 中解除，或从联动模块执行带快照的远程清空。"
return 1
fi
if multiuser_installed; then
red_line "检测到多用户模块。为避免用户数据库与新 UUID/端口失配，请先在多用户管理中停用或卸载模块。"
return 1
fi
if visit_monitor_enabled; then
red_line "检测到网站访问监控。为避免本机身份与新 UUID 失配，请先在网站访问监控中停用。"
return 1
fi
printf "%s警告：此操作将清空所有配置（端口、域名、协议、UUID等），保留内核和脚本！%s\n" "$LUN_RED" "$LUN_RESET"
if [ "${LUN_CLUSTER_DESTRUCTIVE:-no}" = yes ]; then
confirm=yes
else
printf "确认清空配置？输入 yes 确认，其他取消："
IFS= read -r confirm
fi
[ "$confirm" = "yes" ] || { echo "已取消。"; return 1; }
remove_lun_firewall_rules
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
printf "服务器管理备注（不加入节点名称），回车不设置："
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

lun_version_is_older(){
awk -v candidate="$1" -v current="$2" 'BEGIN {
  gsub(/^V/, "", candidate)
  gsub(/^V/, "", current)
  nc = split(candidate, c, ".")
  nn = split(current, n, ".")
  total = nc > nn ? nc : nn
  for (i = 1; i <= total; i++) {
    cv = (i <= nc ? c[i] + 0 : 0)
    nv = (i <= nn ? n[i] + 0 : 0)
    if (cv < nv) exit 0
    if (cv > nv) exit 1
  }
  exit 1
 }'
}

lun_script_version(){
grep -Eo 'V[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$1" 2>/dev/null | head -n 1
}

lun_update_target(){
resolved=$(command -v lun 2>/dev/null || true)
case "$resolved" in
/*)
if command -v readlink >/dev/null 2>&1; then
resolved_real=$(readlink -f "$resolved" 2>/dev/null || true)
[ -n "$resolved_real" ] && resolved=$resolved_real
fi
printf '%s\n' "$resolved"
return 0
;;
esac
if [ "$(id -u 2>/dev/null)" = "0" ]; then
printf '/usr/bin/lun\n'
else
printf '%s/bin/lun\n' "$HOME"
fi
}

lun_install_update_stage(){
stage=$1
target=$2
target_dir=$(dirname "$target")
target_tmp="${target}.replace.$$"
target_backup="${target}.update-backup"
if { [ -e "$target" ] && [ -w "$target" ] && [ -w "$target_dir" ]; } || { [ ! -e "$target" ] && [ -w "$target_dir" ]; }; then
[ ! -e "$target" ] || cp -p "$target" "$target_backup" 2>/dev/null || return 1
cp "$stage" "$target_tmp" || return 1
chmod 755 "$target_tmp" || { rm -f "$target_tmp"; return 1; }
mv -f "$target_tmp" "$target" || { rm -f "$target_tmp"; return 1; }
elif command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
sudo mkdir -p "$target_dir" || return 1
if sudo test -e "$target"; then sudo cp -p "$target" "$target_backup" || return 1; fi
sudo cp "$stage" "$target_tmp" || return 1
sudo chmod 755 "$target_tmp" || { sudo rm -f "$target_tmp"; return 1; }
sudo mv -f "$target_tmp" "$target" || { sudo rm -f "$target_tmp"; return 1; }
else
return 1
fi
expected_hash=$(sha256sum "$stage" 2>/dev/null | awk '{print $1}')
actual_hash=$(sha256sum "$target" 2>/dev/null | awk '{print $1}')
[ -n "$expected_hash" ] && [ "$expected_hash" = "$actual_hash" ]
}

lun_sync_secondary_entry(){
source=$1
primary=$2
secondary="$HOME/bin/lun"
[ -f "$secondary" ] || return 0
[ "$secondary" != "$primary" ] || return 0
mkdir -p "$HOME/bin" 2>/dev/null || return 0
secondary_tmp="${secondary}.replace.$$"
cp "$source" "$secondary_tmp" 2>/dev/null || return 0
chmod 755 "$secondary_tmp" 2>/dev/null || { rm -f "$secondary_tmp"; return 0; }
mv -f "$secondary_tmp" "$secondary" 2>/dev/null || rm -f "$secondary_tmp"
}

update_lun_script(){
target=$(lun_update_target)
mkdir -p "$HOME/bin" 2>/dev/null || true
if [ -w "$(dirname "$target")" ]; then
update_stage="${target}.update.$$"
else
update_stage="${TMPDIR:-/tmp}/lun.update.$$"
fi
rm -f "$update_stage"
current_lun_version=$(lun_script_version "$target")
yellow_line "正在检查 Lun 更新，请稍候……"
if ! download_lun_script "$update_stage" official; then
rm -f "$update_stage"
red_line "Lun 脚本更新失败：无法下载远端脚本，请检查网络后重试。"
return 1
fi
new_lun_version=$(lun_script_version "$update_stage")
if [ -z "$new_lun_version" ] || ! grep -q 'Lun 项目地址' "$update_stage" 2>/dev/null || ! bash -n "$update_stage" 2>/dev/null; then
rm -f "$update_stage"
red_line "远端文件不是有效的 Lun 脚本，已拒绝覆盖当前版本。"
return 1
fi
if [ -n "$current_lun_version" ] && lun_version_is_older "$new_lun_version" "$current_lun_version"; then
rm -f "$update_stage"
yellow_line "远端版本 $new_lun_version 低于当前 $current_lun_version，已拒绝降级。"
return 0
fi
if [ -s "$target" ] && cmp -s "$target" "$update_stage" 2>/dev/null; then
lun_sync_secondary_entry "$update_stage" "$target"
rm -f "$update_stage"
green_line "当前已是最新版：${current_lun_version:-$new_lun_version}"
return 0
fi
if ! lun_install_update_stage "$update_stage" "$target"; then
rm -f "$update_stage"
red_line "Lun 脚本替换失败：$target。请使用 root 或为当前用户配置免密 sudo 后重试。"
return 1
fi
lun_sync_secondary_entry "$update_stage" "$target"
rm -f "$update_stage"
green_line "Lun 脚本更新完成：${current_lun_version:-未知} → $new_lun_version"
green_line "生效入口：$target"
yellow_line "新版本将在下次运行 lun 时完全生效。"
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
cyan_line " 8. 更新本机 Lun 脚本"
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
8) update_lun_script; ui_pause ;;
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
LUN_COLOR_COUNT=$(tput colors 2>/dev/null || printf 0)
if [ "$LUN_COLOR_COUNT" -ge 256 ] 2>/dev/null; then
LUN_ORANGE=$(tput setaf 208 2>/dev/null)
LUN_LIME=$(tput setaf 226 2>/dev/null)
LUN_BANNER_CYAN=$(tput setaf 51 2>/dev/null)
LUN_BANNER_WHITE=$(tput setaf 230 2>/dev/null)
else
LUN_ORANGE=$LUN_YELLOW
LUN_LIME=$LUN_YELLOW
LUN_BANNER_CYAN=$LUN_CYAN
LUN_BANNER_WHITE=$LUN_WHITE
fi
LUN_RESET=$(tput sgr0 2>/dev/null)
else
LUN_RED=
LUN_GREEN=
LUN_YELLOW=
LUN_BLUE=
LUN_CYAN=
LUN_WHITE=
LUN_BOLD=
LUN_ORANGE=
LUN_LIME=
LUN_BANNER_CYAN=
LUN_BANNER_WHITE=
LUN_COLOR_COUNT=0
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
case "$cmd" in *"/lun/modules/cluster/lun_cluster.py"*" serve"*) return 1 ;; esac
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
for used in "$subpt" "$(cat "$HOME/lun/subport.log" 2>/dev/null)" "$(cluster_config_value internal_port 2>/dev/null)"; do
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
[ -n "${multiuser_legacy_subport:-}" ] && [ "$p" = "$multiuser_legacy_subport" ] && return 1
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
echo "NAT 映射和端口池中没有空闲内网端口，请先增加一组映射。" >&2
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
if [ "$label" = "VLESS XHTTP TLS TCP/UDP" ] && [ "$val" = 443 ]; then
red_line "该协议将监听本机 443；请先确认 Nginx、面板或其它服务未占用，脚本不会自动结束未知进程。"
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
if multiuser_enabled; then
subport=$(multiuser_config_value port)
sub_public_port=$(multiuser_config_value public_port)
if is_nat_mode && [ "$sub_public_port" != "$subport" ]; then
green_line "多用户节点订阅：内网端口：$subport  公网端口：$sub_public_port  token：按设备独立管理"
else
green_line "多用户节点订阅：端口：$subport  token：按设备独立管理"
fi
return
fi
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
if multiuser_enabled; then
multiuser_sync_subscription_state || {
red_line "多用户订阅状态同步失败，无法输出有效链接。"
return 1
}
echo "**********************************************************"
multiuser_cmd show-local-subscription
rc=$?
echo "**********************************************************"
return "$rc"
fi
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
    cdn_has_xhttp_tls && ! is_cf_https_port "${cdnpt:-8080}" && echo "VLESS XHTTP TLS 不使用 HTTP 边缘端口，将单独使用 HTTPS 443；Origin Rules 一键部署会自动按 Host + UUID-xc Path 配置。"
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
cdn_name=$(routed_node_name "${base_name}-cdn-https-${edge_port}-cf${cdn_no}")
cdn_link="vless://$uuid@$cdn_uri:$edge_port?${query}&host=$xvvmcdnym&security=tls&sni=$xvvmcdnym&fp=chrome#$cdn_name"
cdn_tls=true
else
cdn_edge_label="HTTP-$edge_port"
cdn_name=$(routed_node_name "${base_name}-cdn-http-${edge_port}-cf${cdn_no}")
cdn_link="vless://$uuid@$cdn_uri:$edge_port?${query}&host=$xvvmcdnym&security=none#$cdn_name"
cdn_tls=false
fi
echo "$cdn_link" >> "$HOME/lun/jhsub.txt"
echo "$cdn_link"
if [ "$base_name" = "vless-xhttp" ]; then
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
elif [ "$base_name" = "vless-ws" ]; then
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
_cdn_probe_code=$(curl -k -sS --connect-timeout 2 --max-time 4 --resolve "$_cdn_probe_host:$_cdn_probe_port:127.0.0.1" -o "$_cdn_probe_body" -w '%{http_code}' "https://$_cdn_probe_host:$_cdn_probe_port/$_cdn_probe_path" 2>/dev/null)
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
_cdn_probe_code=$(curl -k -sS --connect-timeout 3 --max-time 6 -D "$_cdn_probe_header" -o "$_cdn_probe_body" -w '%{http_code}' --connect-to "$_cdn_probe_host:$_cdn_probe_edge:$_cdn_probe_connect:$_cdn_probe_edge" "https://$_cdn_probe_host:$_cdn_probe_edge/$_cdn_probe_path" 2>/dev/null)
_cdn_probe_rc=$?
if [ "$_cdn_probe_rc" -ne 0 ]; then rm -f "$_cdn_probe_header" "$_cdn_probe_body"; return 1; fi
_cdn_probe_sum=$(cksum < "$_cdn_probe_body" | awk '{print $1 ":" $2}')
if grep -Eqi '^(server:[[:space:]]*cloudflare|cf-ray:)' "$_cdn_probe_header"; then _cdn_probe_cf=yes; else _cdn_probe_cf=no; fi
if grep -Eqi '^alt-svc:.*h3' "$_cdn_probe_header"; then _cdn_probe_h3=yes; else _cdn_probe_h3=no; fi
if grep -Eqi '^via:.*apple\.com' "$_cdn_probe_header"; then _cdn_probe_route=reality-apple; else _cdn_probe_route=expected-or-unknown; fi
rm -f "$_cdn_probe_header" "$_cdn_probe_body"
printf '%s:%s|%s|%s|%s\n' "$_cdn_probe_code" "$_cdn_probe_sum" "$_cdn_probe_cf" "$_cdn_probe_h3" "$_cdn_probe_route"
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
edge_h3=no
if cloudflare_manual_rule_matches 13 "$edge_port" "$origin_public_port" "$uuid-xc"; then
yellow_line "已按手动登记的 Origin Rule 生成 CDN-TCP 节点；本次不逐个探测优选 IP。实验 CDN-UDP 仍需通过 HTTP/3 实测后才生成。"
else
command -v curl >/dev/null 2>&1 || { cdn_skip "缺少 curl，无法确认 Cloudflare 是否真正回源到 XHTTP TLS 入站；已停止输出伪可用节点。"; return 0; }
local_signature=$(cdn_xhttp_local_signature "$xvvmcdnym" "$port" "$uuid-xc")
[ -n "$local_signature" ] || { cdn_skip "本机 XHTTP TLS 入站探测失败，已停止输出 CDN 节点。"; return 0; }
probe_ip=$(cdn_first_endpoint "$ips")
[ -n "$probe_ip" ] || { cdn_skip "没有可用于快速验证的 Cloudflare 优选入口。"; return 0; }
edge_result=$(cdn_xhttp_edge_probe "$xvvmcdnym" "$edge_port" "$probe_ip" "$uuid-xc")
edge_signature=${edge_result%%|*}
edge_rest=${edge_result#*|}
edge_through_cf=${edge_rest%%|*}
edge_rest=${edge_rest#*|}
edge_h3=${edge_rest%%|*}
edge_route=${edge_rest#*|}
if [ -z "$edge_result" ] || [ "$edge_through_cf" != yes ] || [ "$edge_signature" != "$local_signature" ]; then
if [ "$edge_route" = reality-apple ]; then
reality_public=
[ -s "$HOME/lun/port_xh" ] && reality_public=$(client_port "$(cat "$HOME/lun/port_xh" 2>/dev/null)")
if cdn_rewrite_active; then
cdn_skip "首个入口 $probe_ip:$edge_port 已进入 Cloudflare，但回源落到了 Reality/Apple 伪装${reality_public:+（公网端口 $reality_public）}，不是 XHTTP TLS。已停止检测其余入口；请删除旧 tls/nottls 宽泛规则，并把 UUID-xc 精确规则指向 $origin_public_port。"
else
cdn_skip "首个入口 $probe_ip:$edge_port 已进入 Cloudflare，但没有到达同端口 XHTTP TLS 入站，反而落到 Reality/Apple 伪装。当前是同端口 CDN，不需要 Origin Rule；请开启 Host 橙云并停用旧的端口改写/宽泛规则。"
fi
else
if cdn_rewrite_active; then
cdn_skip "首个入口 $probe_ip:$edge_port 未按 Host + UUID-xc Path 回源到 $origin_public_port，已停止检测其余入口。可在 Origin Rules 菜单手动登记现有规则，或使用 API 自动部署。"
else
cdn_skip "首个入口 $probe_ip:$edge_port 未到达同端口 XHTTP TLS 入站，已停止检测其余入口。当前是同端口 CDN，不需要 Origin Rule；请确认 Host 已开启橙云，并检查源站 $origin_public_port、TLS、系统防火墙及旧规则。"
fi
fi
return 0
fi
green_line "首个入口 $probe_ip:$edge_port 验证成功；其余优选 IP 复用同一 Host 与规则，不再逐个检测。"
fi
cdn_index=0
cdn_valid_count=0
cdn_udp_count=0
for cdn_ip in $ips; do
case "$cdn_ip" in ""|-1) continue ;; esac
cdn_index=$((cdn_index + 1))
cdn_valid_count=$((cdn_valid_count + 1))
cdn_no=$(printf '%02d' "$cdn_index")
cdn_kind=$(endpoint_kind "$cdn_ip")
cdn_raw=$(json_host "$cdn_ip")
cdn_uri=$(uri_host "$cdn_ip")
cdn_tcp_name=$(routed_node_name "vless-xhttp-tls-tcp-cdn-tcp-${edge_port}-cf${cdn_no}")
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
cdn_udp_name=$(routed_node_name "vless-xhttp-tls-tcp-cdn-udp-exp-443-cf${cdn_no}")
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
cdn_name=$(routed_node_name "vmess-ws-cdn-https-${edge_port}-cf${cdn_no}")
vm_cdn_json="{ \"v\": \"2\", \"ps\": \"$cdn_name\", \"add\": \"$cdn_raw\", \"port\": \"$edge_port\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$xvvmcdnym\", \"path\": \"/$uuid-vm\", \"tls\": \"tls\", \"sni\": \"$xvvmcdnym\", \"fp\": \"chrome\"}"
cdn_tls=true
else
cdn_edge_label="HTTP-$edge_port"
cdn_name=$(routed_node_name "vmess-ws-cdn-http-${edge_port}-cf${cdn_no}")
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

# BEGIN Lun banner UI
lun_banner_dimensions(){
banner_cols=${LUN_BANNER_TEST_COLS:-$(tput cols 2>/dev/null || printf '80')}
banner_lines=${LUN_BANNER_TEST_LINES:-$(tput lines 2>/dev/null || printf '32')}
case "$banner_cols" in ''|*[!0-9]*) banner_cols=80 ;; esac
case "$banner_lines" in ''|*[!0-9]*) banner_lines=32 ;; esac
[ "$banner_cols" -gt 0 ] 2>/dev/null || banner_cols=80
[ "$banner_lines" -gt 0 ] 2>/dev/null || banner_lines=32
}

lun_banner_ascii_size(){
lun_banner_dimensions
if [ "$banner_cols" -ge 120 ] 2>/dev/null && [ "$banner_lines" -ge 37 ] 2>/dev/null; then
printf 'large\n'
elif [ "$banner_cols" -ge 96 ] 2>/dev/null && [ "$banner_lines" -ge 31 ] 2>/dev/null; then
printf 'medium\n'
elif [ "$banner_cols" -ge 72 ] 2>/dev/null && [ "$banner_lines" -ge 25 ] 2>/dev/null; then
printf 'small\n'
else
printf 'compact\n'
fi
}

lun_banner_ascii_data(){
case "$1" in
small)
cat <<'LUN_ASCII_SMALL'
          @C@...-+#####@W@#######**@O@+-...... ..
       @C@..+*##@#**@W@++*##@O@*++@W@+*###@#@O@+---++--....... ....... ..   ..
     @C@.-+#@@**+@W@-..@O@..@W@.#*@O@*...@W@.+@O@+++@W@#@#@O@#*****++-..  ........ .. ....... .....
   @C@..+#@@**#.. .   @W@#*@O@*#      .@W@##@O@-@W@#@#@O@##**++-.-++--..  . ......  ..
 @C@..-+*@#*####@W@##**+*#@O@-@W@+@O@++@W@-+**#####@O@-#@W@@@#@O@##**+-++-+++*+++-..  .  .......
 @C@.-+*#@**-..@W@+***+-++++-+**@O@+@W@#*+.@O@.+*-@W@#@##@O@#**+-+--....... ....-......    ..
@C@..-+*#@**-..   @W@.#-.*.-+++**   @O@..@W@*#@O@-#@W@@@O@##*++-.--+.-........ ...    ..
 @C@..-*#@#+*-.. .@W@##+**++*#**#. @O@..@W@-#+@O@+@W@@@#@O@##**+-++++++----....-......
 @C@...-+#@#+**+##*@W@**+.  .+*#*#*@O@-@W@*#@O@++@W@@#@O@#***++---+--........... .....  ..
   @C@...+*##**#*@W@**-@C@.@W@.@C@.@W@....@O@.@W@.##@O@*@W@#*@O@+@W@#@@O@**+--................. ... ..  .    .
      @C@...+*#**+++@W@********#**@O@*@W@##@O@#+-+++--+---..... .... ...    ..
          @C@...-+++-++-@W@+-++-+*+@O@-............        .   .
LUN_ASCII_SMALL
;;
medium)
cat <<'LUN_ASCII_MEDIUM'
                @C@....+-**###@W@#*#*##+*---@O@--....  ..  . .
            @C@...++##@@#@*#+@W@**+*+***@#@@##@O@++.-....+-+....-.....   ...
          @C@.--*#@W@@@C@@@*+++@W@+.--#@##+@O@++-+-@W@++#@#@@O@**+-+--.-...      .-.   ....... ...     ..
        @C@.-+*#@W@@@C@##+*@W@+-- @O@....@W@*#+# @O@....@W@.+@O@+*--@W@##@@O@#*#+***+*+-*-...   .  ..       ... ......
      @C@..**#@##-++.. .     @W@#*+@O@#.      ..*@W@+@O@--@W@#@#@O@#*#++++-.-...   ..--.-.....           .... ... ..
    @C@..--#@@W@@@C@#**##.        @W@.@++@O@#+        .+@W@@*@O@-+@W@@@##@O@*@W@#@O@***++----++++--..   .  .......   ..
   @C@..-**@@***@*#@W@###*-@C@.  .@W@##@O@-@W@-@O@-*-   @W@.-*######@O@-+@W@@@@@O@*@W@#@O@***+*++--+.--++-*++--+..    .   .-......
 @C@...-+*#@****++**@W@#@C@*@W@*###*#.@O@.@W@+*.@O@.@W@+**#*#*+#@O@***@W@#@O@--*@W@@@@O@##***+*-++-+----+-+--......       .          ..
 @C@..+-**#@*+#.. . @W@.+**+--*+++-+*-#+*@O@+@W@*@O@+@W@+@O@.   *@W@#@O@.+@W@#@###@O@**+*+++-+.----.-...  ....+-+-.-.....
@C@...+-**#@*+*.-..    .@W@#+..*.   *.+**@O@.     . *@W@#@O@.+@W@#@@O@##***-+--+-+-+--+.-.-....-. ...
@C@...++**#@*+*-+.-     @W@##.***+-**##+#      @O@..@W@##@O@-+@W@@@##@O@***-+.---+-++-+-+---....  ....      ...
   @C@..+**@#*+*+...  .@W@##*+*-**+***+-##.  @O@...@W@*@@O@-.@W@#@@@O@##***+*-+--+-----...-.--....+---......
  @C@...-+-#@#*-*-+..*#*+@W@#**-.  .-*#**+#* @O@..@W@##+@O@-*@W@@@O@##**++*+*----+.....   .... .. .  .......  -..
   @C@...-.**##+*+*#@*+@W@#*+          +##+@O@*@W@####@O@--@W@#@@O@#+*++---.-..-----....+.-....   ..               .
     @C@...+-+*##+*-**@W@#@C@+@W@-@C@-.@W@........@O@..@W@-*@@O@*+*-+*@W@@#@O@**++-+-.-........       ....   .-.  ..    .
        @C@...--*##*+-+*-@W@**#*******#*#*#@O@+-*@W@#@@O@#+++*+*-+---.+.--.....     .. ....      .@C@.
            @C@...++**++---*@W@+**+*+*+.+@O@-*@W@*##@O@++..........--....       . ..   .
               @C@.....--+-+.--.@W@-.-+-+--.@O@...........
LUN_ASCII_MEDIUM
;;
large)
cat <<'LUN_ASCII_LARGE'
                         @C@......--.--.@W@........@O@..
                  @C@.---+*#@@@##@W@@@@######@#@######@O@**+--... ....  . .
               @C@...-**#@@@##*+@W@+--....@O@...-+@W@*+++##@@#+@O@+----.. .-++-------.......    ...
            @C@..-++*@@W@@@@C@##+*+*@W@+---+*@@##@O@#@W@+@O@+++@W@+@O@+---@W@*##@@#@O@#*+--+-----....        .+.    ........  ...       ..
           @C@.+++##@W@@@C@##*+.@W@+*+.@O@..... @W@##+** @O@... .@W@.+*@O@+--+@W@##@#@O@#**********++*++-...    .   ..         .-.  ..-....
        @C@..++*##@W@@@C@#**+++@W@+@C@..@O@.@W@.      @+*@O@+#        .-@W@**@O@.--@W@*@@#@O@#*+***+-+---....     ..------...-..   .          .... .. . . .
       @C@..-+*#@W@@@C@@**-**...  .      @W@+@+*@O@+@W@#          @O@..*@W@#@O@.-+@W@#@#@O@#####*++-++--....--+-.         .    ..
     @C@...-+*#@#**.*#@W@#@C@.           @W@##@O@-@W@+@O@-*+          .+@W@#@+@O@.-@W@#@##*#@O@#*+*@W@+@O@+++-...-++++-+--..       ..........    ..
   @C@..--+**#@W@@@C@@#++@##@W@@####+@C@.     @W@+@+@O@-@W@+@O@.-@W@#@O@.      @W@-###@##@#@O@++@W@#@@@@#@O@#*##*#**+--++-+.-+++**+++++++.      .    .+........
  @C@....-++*@@*+.#**@W@#@C@#++@W@+@C@*@W@####**##.@O@.@W@-*.@O@..*@W@***#*###*+@O@+@W@*@O@*@W@##@O@.-.@W@#@##@O@**+*++++---.--++---+++++----... .         .
  @C@.++****@@##+#... .@W@*#*##*#+...@O@.@W@.****-@O@.@W@.+**++**#***  @O@.*@W@#@O@.-+@W@@@@@####@O@###**++++++--+----....  .....--++++--.....        ..
  @C@...--++#@**.*.. .     @W@+#*..+***.   .#+#*+@O@.-@W@**@O@.     .*@W@#@O@.--@W@#@#@O@#*+++---........  .                ...
 @C@..-++***@@##.#-- -       @W@#*--.*+     #--#-#@O@-       . #@W@#-@O@--@W@#@@@O@###*****+++++++*--++++---..-.---.  ...
 @C@....--+*#@**.*.- ..      .@W@#@C@.@W@-.+*+-++*+-*#@O@-@W@#       @O@...@W@##@O@.-.@W@#@#@O@#*++--.. .  ............  .         ...       ....
  @C@...++**#@W@@@C@##++*--.-     .@W@#@+@C@.@W@###.-. .###*@O@+@W@#      @O@.- +@W@@#@O@---@W@@@@####@O@###***+++***++-+++++----.-....-+++--......
    @C@....++#@W@@@C@#*.*+--..   .@W@@#++++-**+*+**+-*@O@.*@W@#+   @O@.. @W@-#@@O@.--@W@#@@O@##*++++-+---..---+-.---.....---....
   @C@.----++*@@*+-+*++ ..#@W@@@C@*+@W@*@C@+@W@*#*.    .*##*++@O@+@W@##  @O@. +@W@#@-@O@--@W@#@#@O@###*******++-----....      --..  .. .   .........  .-..
   @C@.......+*@@++--***#@#++@W@*#*.          -##*-+*@***##.@O@--@W@#@@O@#****+++--+-.....--+---...--......    ...
     @C@.....-+*#@*++-*##+.*@W@#+ @C@..           @O@.@W@.*#*@O@.+@W@###-@O@.-+@W@@@@O@*+++--......   .....-...  .........    ...                  .
       @C@....+***##***-**#@W@#@C@+@W@*-@C@..@W@..@C@.@W@.......@O@..@W@.-#@#@O@**-@W@-@O@+-@W@#@@@O@**++++++--.--... ....         ......    --   ...    .
          @C@.....--###---.-+*@W@*******++-++**###**+@O@-@W@+@O@-+@W@*##@O@+++---+++-----++------..        ..    . .
            @C@....--*##**++++.-@W@*+***##***#***--@O@+@W@+@O@*@W@###@O@*+++--.--.-....---...   . ...  . ..    ..          ..@C@.
                  @C@....++***-..+++-@W@----+++-.-***#@O@*++-.---...--.. .....               .     .
                      @C@.....---+++@W@-@C@.@W@-.--+++-@O@.....
LUN_ASCII_LARGE
;;
*) return 1 ;;
esac
}

lun_banner_render_ascii(){
banner_ascii_size=$1
lun_banner_ascii_data "$banner_ascii_size" | awk -v c="$LUN_BANNER_CYAN" -v w="$LUN_BANNER_WHITE" -v o="$LUN_ORANGE" -v r="$LUN_RESET" '{gsub(/@C@/,c); gsub(/@W@/,w); gsub(/@O@/,o); print $0 r}'
}

lun_banner_caption(){
printf '%s%sLun%s %s· 风火轮多协议交互面板%s\n' "$LUN_BOLD" "$LUN_BANNER_CYAN" "$LUN_RESET" "$LUN_BANNER_WHITE" "$LUN_RESET"
printf '%s多协议统一接入 · 多 VPS 集群联动 · 多用户精细管理%s\n' "$LUN_ORANGE" "$LUN_RESET"
}

lun_panel_header(){
printf '%s%sLun%s %s· 风火轮多协议交互面板%s\n' "$LUN_BOLD" "$LUN_BANNER_CYAN" "$LUN_RESET" "$LUN_BANNER_WHITE" "$LUN_RESET"
printf '%s多协议统一接入 · 多 VPS 集群联动 · 多用户精细管理%s\n' "$LUN_ORANGE" "$LUN_RESET"
}

lun_splash(){
if { [ ! -t 0 ] || [ ! -t 1 ]; } && [ "${LUN_BANNER_ALLOW_NONTTY:-}" != 1 ]; then
return
fi
[ "${TERM:-}" != dumb ] || return 0
banner_ascii_size=$(lun_banner_ascii_size)
[ "$banner_ascii_size" != compact ] || return 0
clear 2>/dev/null || true
lun_banner_render_ascii "$banner_ascii_size"
lun_banner_caption
printf '\n%s正在准备主面板，完成后自动进入…%s' "$LUN_BANNER_WHITE" "$LUN_RESET"
}
# END Lun banner UI

lun_dashboard_render(){
lun_panel_header
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

lun_menu_options(){
echo " 1. 安装 / 协议管理"
printf " 2. %s节点订阅分享%s\n" "$LUN_GREEN" "$LUN_RESET"
echo " 3. 入口网络管理"
echo " 4. 服务与更新"
echo " 5. 高级设置"
printf " 6. %s多用户管理%s\n" "$LUN_GREEN" "$LUN_RESET"
printf " 7. %s网站访问监控%s\n" "$LUN_GREEN" "$LUN_RESET"
printf " 8. %s服务器联动 / 节点集群%s\n" "$LUN_GREEN" "$LUN_RESET"
printf " 9. %s使用说明 / 协议特点%s\n" "$LUN_YELLOW" "$LUN_RESET"
echo " 0. 退出"
}

lun_menu_prepare(){
LUN_MENU_PREFILL_FILE=
menu_prefill=$(mktemp "${TMPDIR:-/tmp}/lun-menu.XXXXXX" 2>/dev/null) || return 0
chmod 600 "$menu_prefill" 2>/dev/null || true
if { lun_dashboard_render; lun_menu_options; } > "$menu_prefill"; then
LUN_MENU_PREFILL_FILE=$menu_prefill
else
rm -f "$menu_prefill"
fi
}

lun_menu_screen(){
clear 2>/dev/null || true
if [ -n "${LUN_MENU_PREFILL_FILE:-}" ] && [ -s "$LUN_MENU_PREFILL_FILE" ]; then
cat "$LUN_MENU_PREFILL_FILE"
rm -f "$LUN_MENU_PREFILL_FILE"
LUN_MENU_PREFILL_FILE=
else
[ -z "${LUN_MENU_PREFILL_FILE:-}" ] || rm -f "$LUN_MENU_PREFILL_FILE"
LUN_MENU_PREFILL_FILE=
lun_dashboard_render
lun_menu_options
fi
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
if multiuser_enabled; then
yellow_line "当前为多用户模式：订阅 token 按设备独立管理，不能用单一 token/端口覆盖。"
green_line "请用“刷新并查看节点信息”查看本机设备链接；其他设备在“多用户管理”中查看或轮换。"
return 3
fi
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

refresh_identity_subscriptions(){
cip || return 1
if multiuser_enabled; then
multiuser_cmd apply >/dev/null 2>&1 || return 1
multiuser_service_restart >/dev/null 2>&1 || true
fi
if cluster_enabled; then
case "$(cluster_role 2>/dev/null)" in
child) cluster_cmd push >/dev/null 2>&1 || true ;;
master) cluster_refresh_profiles >/dev/null 2>&1 || true ;;
esac
fi
}

server_identity_menu(){
while :; do
ensure_server_identity || return 1
ui_title "Lun 服务器身份 / 节点命名"
echo "当前地区：$server_place"
echo "服务器编号：$server_number"
echo "节点示例：$(routed_node_name vless-xhttp-tls-tcp)"
[ -s "$HOME/lun/name" ] && echo "管理备注：$(cat "$HOME/lun/name" 2>/dev/null)"
echo " 1. 自动重新识别地区"
echo " 2. 手动设置地区"
echo " 0. 返回"
printf "请选择 [0-2]："
IFS= read -r identity_choice
case "$identity_choice" in
1|2)
if cluster_enabled && [ "$(cluster_role 2>/dev/null)" = child ]; then
yellow_line "当前是已配对子 VPS；地区和编号由主 VPS 统一管理，请在主 VPS 的“地区设置”中修改。"
ui_pause
continue
fi
if [ "$identity_choice" = 1 ]; then
v4v6
identity_place=$(detect_server_place)
[ "$identity_place" != "未设置地区" ] || { red_line "自动地区识别失败，请使用手动设置。"; ui_pause; continue; }
else
printf "地区（例如 德国-法兰克福，输入 0 返回）："
IFS= read -r identity_place
[ "$identity_place" = 0 ] && continue
identity_place=$(sanitize_server_place "$identity_place") || { red_line "地区格式无效。"; ui_pause; continue; }
fi
if cluster_enabled && [ "$(cluster_role 2>/dev/null)" = master ]; then
identity_node_id=$(cluster_config_value node_id)
cluster_cmd set-location --node-id "$identity_node_id" --region "$identity_place" || { ui_pause; continue; }
else
save_server_identity "$identity_place" "$server_number" || { red_line "服务器身份保存失败。"; ui_pause; continue; }
refresh_identity_subscriptions || { red_line "订阅重建失败，旧代理配置未改变。"; ui_pause; continue; }
fi
green_line "服务器身份已保存，个人、多用户和聚合订阅名称已刷新。"
ui_pause
;;
0|"") return ;;
*) echo "输入错误。" ;;
esac
done
}

subscription_menu(){
while :; do
ui_title "Lun 节点订阅分享"
show_subscription_summary
echo " 1. 刷新并查看节点信息"
if multiuser_enabled; then
echo " 2. 多用户订阅说明（token 按设备管理）"
else
echo " 2. 设置订阅 token / 端口"
fi
echo " 3. 设置订阅 IPv4/IPv6 输出"
echo " 4. 服务器身份 / 节点命名"
echo " 0. 返回"
printf "请选择 [0-4]："
IFS= read -r c
case "$c" in
1) LUN_MENU_ACTION=list; return ;;
2) prompt_subscription; rc=$?; [ "$rc" = 2 ] && continue; [ "$rc" = 3 ] && { ui_pause; continue; }; refresh_subscription_share; LUN_MENU_ACTION=menu; ui_pause; continue ;;
3) prompt_subscription_ip_mode; rc=$?; [ "$rc" = 2 ] && continue; refresh_subscription_share; LUN_MENU_ACTION=menu; ui_pause; continue ;;
4) server_identity_menu ;;
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
ensure_cloudflare_origin_helper(){
command -v python3 >/dev/null 2>&1 || {
yellow_line "自动配置 Cloudflare 需要 Python 3，正在安装……"
if command -v apk >/dev/null 2>&1; then
apk add --no-cache python3 >/dev/null 2>&1
elif command -v apt-get >/dev/null 2>&1; then
apt-get update -y >/dev/null 2>&1 && DEBIAN_FRONTEND=noninteractive apt-get install -y python3 >/dev/null 2>&1
elif command -v dnf >/dev/null 2>&1; then
dnf install -y python3 >/dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
yum install -y python3 >/dev/null 2>&1
fi
}
command -v python3 >/dev/null 2>&1 || { red_line "Python 3 安装失败，无法调用 Cloudflare API。"; return 1; }
mkdir -p "$HOME/lun"
cat > "$HOME/lun/cdn_cloudflare_api.py" <<'PY'
#!/usr/bin/env python3
import datetime
import hashlib
import ipaddress
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, OSError):
    pass

BASE = os.environ.get("CF_LUN_API_BASE", "https://api.cloudflare.com/client/v4").rstrip("/")
TOKEN = os.environ.get("CF_LUN_TOKEN", "").strip()
HOST = os.environ.get("CF_LUN_HOST", "").strip().lower().rstrip(".")
ZONE_NAME = os.environ.get("CF_LUN_ZONE", "").strip().lower().rstrip(".")
ORIGIN_IPS = os.environ.get("CF_LUN_ORIGIN_IPS", "").split()
BACKUP = os.environ.get("CF_LUN_BACKUP", "")
STATE = os.environ.get("CF_LUN_STATE", "")
TUNNEL_HOST = os.environ.get("CF_LUN_TUNNEL_HOST", "").strip().lower().rstrip(".")
TUNNEL_NAME = os.environ.get("CF_LUN_TUNNEL_NAME", "").strip()
TUNNEL_PORT = os.environ.get("CF_LUN_TUNNEL_PORT", "").strip()
TUNNEL_STATE = os.environ.get("CF_LUN_TUNNEL_STATE", "")


class ApiError(RuntimeError):
    pass


def api(method, path, payload=None):
    data = None if payload is None else json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        BASE + path,
        data=data,
        method=method,
        headers={
            "Authorization": "Bearer " + TOKEN,
            "Content-Type": "application/json",
            "User-Agent": "FHLUN-Origin-Rules/1",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=25) as response:
            raw = response.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        try:
            doc = json.loads(raw)
            messages = "; ".join(str(item.get("message", "")) for item in doc.get("errors", []))
        except (ValueError, AttributeError):
            messages = raw[:300]
        raise ApiError("HTTP %s: %s" % (exc.code, messages or exc.reason))
    except urllib.error.URLError as exc:
        raise ApiError("连接 Cloudflare API 失败: %s" % exc.reason)
    try:
        doc = json.loads(raw)
    except ValueError:
        raise ApiError("Cloudflare API 返回了无效 JSON")
    if not doc.get("success"):
        messages = "; ".join(str(item.get("message", "")) for item in doc.get("errors", []))
        raise ApiError(messages or "Cloudflare API 请求失败")
    return doc.get("result"), doc


def atomic_json(path, value):
    if not path:
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    temp = path + ".tmp"
    with open(temp, "w", encoding="utf-8") as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    os.chmod(temp, 0o600)
    os.replace(temp, path)


def find_zone():
    zones = []
    page = 1
    while True:
        query = urllib.parse.urlencode({"per_page": 50, "page": page})
        result, doc = api("GET", "/zones?" + query)
        zones.extend(result or [])
        pages = int((doc.get("result_info") or {}).get("total_pages") or 1)
        if page >= pages:
            break
        page += 1
    matches = [
        zone for zone in zones
        if HOST == str(zone.get("name", "")).lower()
        or HOST.endswith("." + str(zone.get("name", "")).lower())
    ]
    if not matches:
        raise ApiError("Token 看不到 %s 所属区域，请检查 Zone Read 权限和区域范围" % HOST)
    return max(matches, key=lambda zone: len(str(zone.get("name", ""))))


def clean_rule(rule):
    allowed = ("action", "action_parameters", "description", "enabled", "expression", "ref", "logging")
    cleaned = {key: rule[key] for key in allowed if key in rule}
    cleaned.setdefault("enabled", True)
    return cleaned


def parse_specs():
    specs = []
    for line in os.environ.get("CF_LUN_RULES", "").splitlines():
        if not line.strip():
            continue
        parts = line.split("|", 5)
        if len(parts) != 6:
            raise ApiError("内部规则格式错误")
        proto, edge, origin, tls, path, label = parts
        edge, origin = int(edge), int(origin)
        if not 1 <= edge <= 65535 or not 1 <= origin <= 65535:
            raise ApiError("规则端口超出范围")
        if not re.fullmatch(r"[0-9A-Za-z_-]+", path):
            raise ApiError("协议 Path 包含不安全字符")
        specs.append({
            "proto": proto,
            "edge": edge,
            "origin": origin,
            "tls": tls == "yes",
            "path": path,
            "label": label,
        })
    if not specs:
        raise ApiError("没有可自动配置的 CDN 协议")
    return specs


def expression_quote(value):
    return value.replace("\\", "\\\\").replace('"', '\\"')


def desired_rules(specs):
    grouped = {}
    for spec in specs:
        grouped.setdefault(spec["origin"], []).append(spec)
    rules = []
    quoted_host = expression_quote(HOST)
    for origin, items in grouped.items():
        clauses = []
        for item in items:
            clause = '(http.host eq "%s" and cf.edge.server_port eq %d' % (quoted_host, item["edge"])
            if item["tls"]:
                clause += " and ssl"
            clause += ' and starts_with(http.request.uri.path, "/%s"))' % expression_quote(item["path"])
            clauses.append(clause)
        expression = clauses[0] if len(clauses) == 1 else "(" + " or ".join(clauses) + ")"
        labels = ", ".join(item["label"] for item in items)
        ref_hash = hashlib.sha256((HOST + "|" + str(origin)).encode()).hexdigest()[:20]
        rules.append({
            "action": "route",
            "action_parameters": {"origin": {"port": origin}},
            "description": "FHLUN %s 自动回源 %d [%s]" % (HOST, origin, labels),
            "enabled": True,
            "expression": expression,
            "ref": "fhlun_" + ref_hash,
        })
    return rules


def legacy_conflict(rule):
    description = re.sub(r"\s+", "", str(rule.get("description", "")).lower())
    expression = str(rule.get("expression", ""))
    host_marker = 'http.host eq "%s"' % expression_quote(HOST)
    return (
        description in {"tls", "nottls", "notls"}
        and host_marker in expression
        and "http.request.uri.path" not in expression
        and isinstance((rule.get("action_parameters") or {}).get("origin"), dict)
    )


def prepare_dns(zone_id, origin_ips):
    query = urllib.parse.urlencode({"name": HOST, "per_page": 100})
    records, _ = api("GET", "/zones/%s/dns_records?%s" % (zone_id, query))
    records = records or []
    usable = [
        record for record in records
        if record.get("type") in {"A", "AAAA", "CNAME"} and record.get("proxiable", True)
    ]
    create = []
    if not usable:
        seen = set()
        for value in origin_ips:
            value = value.strip().strip("[]")
            if not value or value in seen:
                continue
            try:
                address = ipaddress.ip_address(value)
            except ValueError:
                continue
            seen.add(value)
            create.append({
                "type": "A" if address.version == 4 else "AAAA",
                "name": HOST,
                "content": value,
                "ttl": 1,
                "proxied": True,
            })
        if not create:
            raise ApiError("%s 没有可代理的 A/AAAA/CNAME，且未检测到本机公网 IP" % HOST)
    return records, usable, create


def zone_setting(zone_id, setting_id):
    result, _ = api("GET", "/zones/%s/settings/%s" % (zone_id, setting_id))
    return result or {}


def rollback(zone_id, original_ruleset, created_ruleset_id, changed_settings, changed_dns, created_dns):
    errors = []
    try:
        if original_ruleset:
            payload = {
                "description": original_ruleset.get("description", "Zone-level origin rules"),
                "rules": [clean_rule(rule) for rule in original_ruleset.get("rules", [])],
            }
            api("PUT", "/zones/%s/rulesets/%s" % (zone_id, original_ruleset["id"]), payload)
        elif created_ruleset_id:
            api("DELETE", "/zones/%s/rulesets/%s" % (zone_id, created_ruleset_id))
    except Exception as exc:
        errors.append("规则回滚失败: %s" % exc)
    for setting_id, old_value in reversed(changed_settings):
        try:
            api("PATCH", "/zones/%s/settings/%s" % (zone_id, setting_id), {"value": old_value})
        except Exception as exc:
            errors.append("%s 回滚失败: %s" % (setting_id, exc))
    for record_id, old_proxied in reversed(changed_dns):
        try:
            api("PATCH", "/zones/%s/dns_records/%s" % (zone_id, record_id), {"proxied": old_proxied})
        except Exception as exc:
            errors.append("DNS 回滚失败: %s" % exc)
    for record_id in reversed(created_dns):
        try:
            api("DELETE", "/zones/%s/dns_records/%s" % (zone_id, record_id))
        except Exception as exc:
            errors.append("新 DNS 删除失败: %s" % exc)
    return errors


def deploy():
    specs = parse_specs()
    zone = find_zone()
    zone_id = zone["id"]
    origin_ips = os.environ.get("CF_LUN_ORIGIN_IPS", "").split()
    dns_records, dns_usable, dns_create = prepare_dns(zone_id, origin_ips)
    ssl_target = os.environ.get("CF_LUN_SSL_MODE", "").strip()
    http3_target = os.environ.get("CF_LUN_HTTP3", "") == "yes"
    settings = {}
    if ssl_target:
        settings["ssl"] = zone_setting(zone_id, "ssl")
    if http3_target:
        settings["http3"] = zone_setting(zone_id, "http3")

    rulesets, _ = api("GET", "/zones/%s/rulesets" % zone_id)
    phase = next(
        (
            item for item in (rulesets or [])
            if item.get("kind") == "zone" and item.get("phase") == "http_request_origin"
        ),
        None,
    )
    original_ruleset = None
    if phase:
        original_ruleset, _ = api("GET", "/zones/%s/rulesets/%s" % (zone_id, phase["id"]))
    desired = desired_rules(specs)
    retained = []
    if original_ruleset:
        prefix = "FHLUN %s " % HOST
        for rule in original_ruleset.get("rules", []):
            if str(rule.get("description", "")).startswith(prefix) or legacy_conflict(rule):
                continue
            retained.append(clean_rule(rule))

    atomic_json(BACKUP, {
        "created_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "zone": zone,
        "dns_records": dns_records,
        "settings": settings,
        "ruleset": original_ruleset,
    })

    created_ruleset_id = None
    changed_settings = []
    changed_dns = []
    created_dns = []
    try:
        if original_ruleset:
            ruleset_result, _ = api(
                "PUT",
                "/zones/%s/rulesets/%s" % (zone_id, original_ruleset["id"]),
                {
                    "description": original_ruleset.get("description", "Zone-level origin rules"),
                    "rules": retained + desired,
                },
            )
        else:
            ruleset_result, _ = api(
                "POST",
                "/zones/%s/rulesets" % zone_id,
                {
                    "name": "FHLUN Origin Rules",
                    "description": "FHLUN 自动端口回源",
                    "kind": "zone",
                    "phase": "http_request_origin",
                    "rules": desired,
                },
            )
            created_ruleset_id = ruleset_result["id"]

        if ssl_target:
            current = str(settings["ssl"].get("value", ""))
            rank = {"off": 0, "flexible": 1, "full": 2, "strict": 3, "origin_pull": 4}
            if rank.get(current, 0) < rank.get(ssl_target, 0):
                api("PATCH", "/zones/%s/settings/ssl" % zone_id, {"value": ssl_target})
                changed_settings.append(("ssl", current))
        if http3_target and settings["http3"].get("value") != "on":
            old_value = settings["http3"].get("value", "off")
            api("PATCH", "/zones/%s/settings/http3" % zone_id, {"value": "on"})
            changed_settings.append(("http3", old_value))

        for record in dns_usable:
            if not record.get("proxied"):
                api(
                    "PATCH",
                    "/zones/%s/dns_records/%s" % (zone_id, record["id"]),
                    {"proxied": True},
                )
                changed_dns.append((record["id"], False))
        for record in dns_create:
            created, _ = api("POST", "/zones/%s/dns_records" % zone_id, record)
            created_dns.append(created["id"])
    except Exception as exc:
        rollback_errors = rollback(
            zone_id, original_ruleset, created_ruleset_id,
            changed_settings, changed_dns, created_dns,
        )
        suffix = ("；" + "；".join(rollback_errors)) if rollback_errors else "；已自动回滚"
        raise ApiError(str(exc) + suffix)

    atomic_json(STATE, {
        "updated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "zone_id": zone_id,
        "zone_name": zone.get("name"),
        "host": HOST,
        "ruleset_id": ruleset_result.get("id"),
        "rule_refs": [rule["ref"] for rule in desired],
        "dns_created_ids": created_dns,
        "dns_changed": [
            {"id": record_id, "proxied": old_proxied}
            for record_id, old_proxied in changed_dns
        ],
        "settings_changed": [
            {"id": setting_id, "value": old_value}
            for setting_id, old_value in changed_settings
        ],
        "targets": [
            {"edge": item["edge"], "origin": item["origin"], "path": item["path"]}
            for item in specs
        ],
    })
    print("ZONE=" + str(zone.get("name", "")))
    print("HOST=" + HOST)
    print("DNS=proxied")
    print("RULES=" + str(len(desired)))
    if ssl_target:
        print("SSL=" + ssl_target)
    if http3_target:
        print("HTTP3=on")
    for item in specs:
        print("ROUTE=%s:%d -> %d /%s" % (item["proto"], item["edge"], item["origin"], item["path"]))


def remove():
    zone = find_zone()
    zone_id = zone["id"]
    rulesets, _ = api("GET", "/zones/%s/rulesets" % zone_id)
    phase = next(
        (
            item for item in (rulesets or [])
            if item.get("kind") == "zone" and item.get("phase") == "http_request_origin"
        ),
        None,
    )
    removed = 0
    if phase:
        details, _ = api("GET", "/zones/%s/rulesets/%s" % (zone_id, phase["id"]))
        prefix = "FHLUN %s " % HOST
        kept = []
        for rule in details.get("rules", []):
            if str(rule.get("description", "")).startswith(prefix):
                removed += 1
            else:
                kept.append(clean_rule(rule))
        if removed:
            api(
                "PUT",
                "/zones/%s/rulesets/%s" % (zone_id, phase["id"]),
                {"description": details.get("description", "Zone-level origin rules"), "rules": kept},
            )
    print("REMOVED=" + str(removed))


def all_zones():
    zones = []
    page = 1
    while True:
        query = urllib.parse.urlencode({"per_page": 50, "page": page, "status": "active"})
        result, doc = api("GET", "/zones?" + query)
        zones.extend(result or [])
        pages = int((doc.get("result_info") or {}).get("total_pages") or 1)
        if page >= pages:
            return zones
        page += 1


def find_zone_name(name):
    matches = [zone for zone in all_zones() if str(zone.get("name", "")).lower() == name]
    if not matches:
        raise ApiError("Token 看不到区域 %s" % name)
    return matches[0]


def list_zones_action():
    zones = all_zones()
    if not zones:
        raise ApiError("Token 没有可用区域")
    for zone in sorted(zones, key=lambda item: str(item.get("name", ""))):
        account = zone.get("account") or {}
        account_name = str(account.get("name", "")).replace("|", " ")
        print("ZONE=%s|%s|%s|%s" % (
            zone.get("name", ""), zone.get("id", ""), account.get("id", ""), account_name,
        ))


def discover_hosts_action():
    if not ZONE_NAME:
        raise ApiError("未指定区域")
    zone = find_zone_name(ZONE_NAME)
    records, _ = api("GET", "/zones/%s/dns_records?%s" % (
        zone["id"], urllib.parse.urlencode({"per_page": 500}),
    ))
    local = {value.strip().strip("[]") for value in ORIGIN_IPS if value.strip()}
    seen = set()
    for record in records or []:
        if record.get("type") not in {"A", "AAAA"}:
            continue
        content = str(record.get("content", "")).strip().strip("[]")
        if content not in local:
            continue
        name = str(record.get("name", "")).lower().rstrip(".")
        if not name or name in seen:
            continue
        seen.add(name)
        print("HOST=%s|%s|%s" % (name, record.get("type", ""), "yes" if record.get("proxied") else "no"))


def preflight_action():
    if not HOST:
        raise ApiError("未提供服务域名")
    zone = find_zone()
    zone_id = zone["id"]
    account_id = str((zone.get("account") or {}).get("id", ""))
    api("GET", "/zones/%s/dns_records?%s" % (zone_id, urllib.parse.urlencode({"name": HOST, "per_page": 10})))
    api("GET", "/zones/%s/rulesets" % zone_id)
    api("GET", "/zones/%s/settings/ssl" % zone_id)
    if not account_id:
        raise ApiError("区域没有返回账户 ID")
    api("GET", "/accounts/%s/cfd_tunnel?%s" % (
        account_id, urllib.parse.urlencode({"is_deleted": "false", "per_page": 1}),
    ))
    print("PREFLIGHT=ok")
    print("ZONE=" + str(zone.get("name", "")))
    print("ACCOUNT=" + account_id)


def dns_payload(record):
    allowed = ("type", "name", "content", "ttl", "proxied", "comment", "tags", "settings")
    return {key: record[key] for key in allowed if key in record}


def tunnel_paths(account_id, tunnel_id=""):
    base = "/accounts/%s/cfd_tunnel" % account_id
    return base + (("/" + tunnel_id) if tunnel_id else "")


def tunnel_rollback_payload(payload):
    account_id = str(payload.get("account_id", ""))
    tunnel_id = str(payload.get("tunnel_id", ""))
    zone_id = str(payload.get("zone_id", ""))
    errors = []
    old_dns = payload.get("old_dns")
    created_dns_id = str(payload.get("created_dns_id", ""))
    try:
        if created_dns_id:
            api("DELETE", "/zones/%s/dns_records/%s" % (zone_id, created_dns_id))
        elif isinstance(old_dns, dict) and old_dns.get("id"):
            api("PUT", "/zones/%s/dns_records/%s" % (zone_id, old_dns["id"]), dns_payload(old_dns))
    except Exception as exc:
        errors.append("Tunnel DNS 回滚失败: %s" % exc)
    try:
        if payload.get("created_tunnel") and tunnel_id:
            api("DELETE", tunnel_paths(account_id, tunnel_id))
        elif tunnel_id and isinstance(payload.get("old_config"), dict):
            api("PUT", tunnel_paths(account_id, tunnel_id) + "/configurations", payload["old_config"])
    except Exception as exc:
        errors.append("Tunnel 配置回滚失败: %s" % exc)
    return errors


def tunnel_deploy_action():
    if not HOST or not TUNNEL_HOST or not TUNNEL_STATE:
        raise ApiError("Tunnel 参数不完整")
    try:
        tunnel_port = int(TUNNEL_PORT)
    except ValueError:
        raise ApiError("Tunnel 本机端口无效")
    if not 1 <= tunnel_port <= 65535:
        raise ApiError("Tunnel 本机端口超出范围")
    if not re.fullmatch(r"[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?", TUNNEL_HOST):
        raise ApiError("Tunnel 域名格式无效")
    zone = find_zone()
    zone_id = zone["id"]
    account_id = str((zone.get("account") or {}).get("id", ""))
    if not account_id:
        raise ApiError("区域没有返回账户 ID")
    name = TUNNEL_NAME or ("fhlun-" + hashlib.sha256((HOST + "|" + TUNNEL_HOST).encode()).hexdigest()[:12])
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", name):
        raise ApiError("Tunnel 名称格式无效")
    query = urllib.parse.urlencode({"is_deleted": "false", "name": name, "per_page": 100})
    tunnels, _ = api("GET", tunnel_paths(account_id) + "?" + query)
    matches = [item for item in (tunnels or []) if str(item.get("name", "")) == name]
    if len(matches) > 1:
        raise ApiError("检测到多个同名 Tunnel，已停止以免覆盖")
    tunnel = matches[0] if matches else None
    created_tunnel = False
    old_config = None
    if tunnel:
        tunnel_id = str(tunnel["id"])
        old_config, _ = api("GET", tunnel_paths(account_id, tunnel_id) + "/configurations")
    else:
        tunnel, _ = api("POST", tunnel_paths(account_id), {"name": name, "config_src": "cloudflare"})
        tunnel_id = str(tunnel["id"])
        created_tunnel = True
    target = tunnel_id + ".cfargotunnel.com"
    dns_query = urllib.parse.urlencode({"name": TUNNEL_HOST, "per_page": 100})
    dns_records, _ = api("GET", "/zones/%s/dns_records?%s" % (zone_id, dns_query))
    dns_records = dns_records or []
    if len(dns_records) > 1:
        if created_tunnel:
            api("DELETE", tunnel_paths(account_id, tunnel_id))
        raise ApiError("Tunnel 域名存在多条 DNS 记录，已停止以免覆盖")
    old_dns = dns_records[0] if dns_records else None
    if old_dns and not (
        old_dns.get("type") == "CNAME" and str(old_dns.get("content", "")).lower().rstrip(".") == target
    ):
        if created_tunnel:
            api("DELETE", tunnel_paths(account_id, tunnel_id))
        raise ApiError("Tunnel 域名已被非本 Tunnel 的 DNS 记录占用")
    rollback_data = {
        "account_id": account_id, "zone_id": zone_id, "tunnel_id": tunnel_id,
        "created_tunnel": created_tunnel, "old_config": old_config,
        "old_dns": old_dns, "created_dns_id": "",
    }
    try:
        desired_config = {"config": {"ingress": [
            {"hostname": TUNNEL_HOST, "service": "http://localhost:%d" % tunnel_port},
            {"service": "http_status:404"},
        ]}}
        api("PUT", tunnel_paths(account_id, tunnel_id) + "/configurations", desired_config)
        record_payload = {"type": "CNAME", "name": TUNNEL_HOST, "content": target, "ttl": 1, "proxied": True}
        if old_dns:
            api("PUT", "/zones/%s/dns_records/%s" % (zone_id, old_dns["id"]), record_payload)
        else:
            created_dns, _ = api("POST", "/zones/%s/dns_records" % zone_id, record_payload)
            rollback_data["created_dns_id"] = str(created_dns["id"])
        token, _ = api("GET", tunnel_paths(account_id, tunnel_id) + "/token")
        if not isinstance(token, str) or not token.strip():
            raise ApiError("Cloudflare 未返回 Tunnel token")
    except Exception as exc:
        rollback_errors = tunnel_rollback_payload(rollback_data)
        suffix = ("；" + "；".join(rollback_errors)) if rollback_errors else "；已自动回滚"
        raise ApiError(str(exc) + suffix)
    rollback_data.update({
        "updated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "host": HOST, "tunnel_host": TUNNEL_HOST, "tunnel_name": name,
    })
    atomic_json(TUNNEL_STATE, rollback_data)
    print("TUNNEL_ID=" + tunnel_id)
    print("TUNNEL_HOST=" + TUNNEL_HOST)
    print("TUNNEL_TOKEN=" + token.strip())
    print("TUNNEL_SERVICE=http://localhost:%d" % tunnel_port)


def tunnel_rollback_action():
    if not TUNNEL_STATE or not os.path.isfile(TUNNEL_STATE):
        print("TUNNEL_ROLLBACK=none")
        return
    with open(TUNNEL_STATE, "r", encoding="utf-8") as handle:
        payload = json.load(handle)
    errors = tunnel_rollback_payload(payload)
    if errors:
        raise ApiError("；".join(errors))
    print("TUNNEL_ROLLBACK=ok")


def restore_origin_action():
    if not BACKUP or not STATE or not os.path.isfile(BACKUP):
        print("RESTORE=none")
        return
    with open(BACKUP, "r", encoding="utf-8") as handle:
        backup = json.load(handle)
    with open(STATE, "r", encoding="utf-8") as handle:
        state = json.load(handle)
    zone_id = str((backup.get("zone") or {}).get("id") or state.get("zone_id") or "")
    original_ruleset = backup.get("ruleset")
    if original_ruleset:
        api("PUT", "/zones/%s/rulesets/%s" % (zone_id, original_ruleset["id"]), {
            "description": original_ruleset.get("description", "Zone-level origin rules"),
            "rules": [clean_rule(rule) for rule in original_ruleset.get("rules", [])],
        })
    elif state.get("ruleset_id"):
        api("DELETE", "/zones/%s/rulesets/%s" % (zone_id, state["ruleset_id"]))
    for item in state.get("settings_changed", []):
        api("PATCH", "/zones/%s/settings/%s" % (zone_id, item["id"]), {"value": item["value"]})
    for item in state.get("dns_changed", []):
        api("PATCH", "/zones/%s/dns_records/%s" % (zone_id, item["id"]), {"proxied": item["proxied"]})
    for record_id in state.get("dns_created_ids", []):
        api("DELETE", "/zones/%s/dns_records/%s" % (zone_id, record_id))
    print("RESTORE=ok")


def main():
    if not TOKEN:
        raise ApiError("未提供 Cloudflare API Token")
    action = sys.argv[1] if len(sys.argv) > 1 else ""
    if action == "verify":
        result, _ = api("GET", "/user/tokens/verify")
        if str((result or {}).get("status", "")).lower() not in {"active", ""}:
            raise ApiError("Token 状态不是 active")
        print("TOKEN=valid")
    elif action == "zones":
        list_zones_action()
    elif action == "hosts":
        discover_hosts_action()
    elif action == "preflight":
        preflight_action()
    elif action == "deploy":
        if not HOST:
            raise ApiError("未提供 CDN Host")
        deploy()
    elif action == "restore":
        restore_origin_action()
    elif action == "tunnel-deploy":
        tunnel_deploy_action()
    elif action == "tunnel-rollback":
        tunnel_rollback_action()
    elif action == "remove":
        if not HOST:
            raise ApiError("未提供 CDN Host")
        remove()
    else:
        raise ApiError("未知操作")


try:
    main()
except (ApiError, ValueError) as exc:
    print("ERROR=" + str(exc))
    sys.exit(1)
PY
chmod 700 "$HOME/lun/cdn_cloudflare_api.py"
}

cloudflare_token_file(){
printf '%s\n' "$HOME/lun/cdn_cloudflare_token"
}

cloudflare_prompt_token(){
ensure_cloudflare_origin_helper || return 1
token_file=$(cloudflare_token_file)
echo "首次自动配置需要 Cloudflare API Token，之后不再重复询问。"
echo "创建位置：我的个人资料 → API 令牌 → 创建自定义令牌（不要使用“账户 API 令牌”）。"
echo "傻瓜式全配置建议：直接给该用户令牌全部账户、全部区域的最大可用编辑权限，避免逐项补权限。"
echo "这里只需要令牌正文；Token ID、用户 ID、账户 ID 和邮箱都不用填写。Lun 会先自检，再事务化修改。"
printf "粘贴 Token（输入会显示，0 返回）："
IFS= read -r cf_token
[ "$cf_token" = 0 ] && return 2
case "$cf_token" in
*CF_Token=*) cf_token=${cf_token#*CF_Token=}; cf_token=${cf_token%%[[:space:]]*} ;;
esac
cf_token=$(printf '%s' "$cf_token" | tr -d "\"'[:space:]")
printf '%s' "$cf_token" | grep -Eq '^[A-Za-z0-9_-]{20,}$' || { red_line "Token 格式不正确。"; return 1; }
token_check="/tmp/lun-cf-token.$$"
if CF_LUN_TOKEN="$cf_token" python3 "$HOME/lun/cdn_cloudflare_api.py" verify > "$token_check" 2>&1; then
umask 077
printf '%s\n' "$cf_token" > "$token_file"
chmod 600 "$token_file"
rm -f "$token_check"
green_line "Cloudflare API Token 已验证并安全保存。"
return 0
fi
red_line "$(sed -n 's/^ERROR=//p' "$token_check" | sed -n 1p)"
yellow_line "请确认粘贴的是“用户 API 令牌”的令牌正文；创建结果里的 Token ID/ID 不需要填写。"
rm -f "$token_check"
return 1
}

cloudflare_require_token(){
token_file=$(cloudflare_token_file)
if [ -s "$token_file" ]; then
return 0
fi
cloudflare_prompt_token
}

cloudflare_protocol_state(){
case "$1" in
3) printf 'xhttp|VLESS XHTTP|%s|%s-vx\n' "$HOME/lun/port_vx" "$(cat "$HOME/lun/uuid" 2>/dev/null)" ;;
4) printf 'ws|VLESS WS|%s|%s-vw\n' "$HOME/lun/port_vw" "$(cat "$HOME/lun/uuid" 2>/dev/null)" ;;
8) printf 'vmess|VMess WS|%s|%s-vm\n' "$HOME/lun/port_vm_ws" "$(cat "$HOME/lun/uuid" 2>/dev/null)" ;;
13) printf 'xhttp-tls|VLESS XHTTP TLS|%s|%s-xc\n' "$HOME/lun/port_xc" "$(cat "$HOME/lun/uuid" 2>/dev/null)" ;;
esac
}

cloudflare_origin_rule_specs(){
override_id=$1
override_port=$2
for id in 3 13 4 8; do
state=$(cloudflare_protocol_state "$id")
[ -n "$state" ] || continue
proto=${state%%|*}; rest=${state#*|}
label=${rest%%|*}; rest=${rest#*|}
file=${rest%%|*}; path=${rest#*|}
[ -s "$file" ] || continue
case "$id" in
3|13) cdn_protocol_enabled xhttp || continue ;;
4) cdn_protocol_enabled ws || continue ;;
8) cdn_protocol_enabled vmess || continue ;;
esac
inner=$(protocol_current_port "$id")
[ -n "$inner" ] || inner=$(cat "$file" 2>/dev/null)
origin=$(client_port "$inner")
[ "$id" = "$override_id" ] && [ -n "$override_port" ] && origin=$override_port
edge=$(cdn_client_port "$inner")
tls=no
is_cf_https_port "$edge" && tls=yes
printf '%s|%s|%s|%s|%s|%s\n' "$proto" "$edge" "$origin" "$tls" "$path" "$label"
done
}

cloudflare_reset_protocol_changes(){
CF_CHANGED_PROTOCOLS=
CLOUDFLARE_PROTOCOL_PORT_CHANGED=no
}

cloudflare_restore_protocol_changes(){
[ -n "$CF_CHANGED_PROTOCOLS" ] || return 0
for change in $CF_CHANGED_PROTOCOLS; do
change_rest=${change#*:}
change_var=${change_rest%%:*}
change_old=${change_rest#*:}
eval "export $change_var=\"\$change_old\""
done
refresh_protocol_flags
CF_CHANGED_PROTOCOLS=
CLOUDFLARE_PROTOCOL_PORT_CHANGED=no
}

cloudflare_record_protocol_change(){
change_id=$1
change_var=$2
change_old=$3
case " $CF_CHANGED_PROTOCOLS " in
*" $change_id:"*) ;;
*) CF_CHANGED_PROTOCOLS="$CF_CHANGED_PROTOCOLS $change_id:$change_var:$change_old" ;;
esac
}

cloudflare_validate_origin_port(){
id=$1
origin=$2
state=$(cloudflare_protocol_state "$id")
[ -n "$state" ] || return 1
rest=${state#*|}; rest=${rest#*|}
file=${rest%%|*}
[ -s "$file" ] || return 1
inner=$(protocol_current_port "$id")
[ -n "$inner" ] || inner=$(cat "$file" 2>/dev/null)
if is_nat_mode; then
mapped=$(inner_port_from_public "$origin")
[ -n "$mapped" ] || { red_line "公网端口 $origin 不在当前 NAT 映射中；请先在 VPS 类型 / 端口池中添加该映射。"; return 1; }
target_inner=$mapped
else
target_inner=$origin
fi
[ "$target_inner" = "$inner" ] && return 0
if port_reserved "$target_inner"; then
red_line "目标内网端口 $target_inner 已分配给其它协议或订阅，无法自动迁移。"
return 1
fi
if port_in_use "$target_inner"; then
red_line "目标内网端口 $target_inner 正被其它进程监听，无法自动迁移。"
port_owner_lines "$target_inner" | sed 's/^/  /'
return 1
fi
var=$(protocol_var "$id")
[ -n "$var" ] || return 1
cloudflare_record_protocol_change "$id" "$var" "$inner"
eval "export $var=\"\$target_inner\""
refresh_protocol_flags
CDN_REBUILD_REQUIRED=yes
CLOUDFLARE_PROTOCOL_PORT_CHANGED=yes
if is_nat_mode; then
green_line "已自动迁移协议监听：公网 $origin → 内网 $target_inner（原内网 $inner）；无需再到其它菜单改端口。"
else
green_line "已自动把协议监听端口从 $inner 改为 $target_inner；无需再到其它菜单改端口。"
fi
return 0
}

cloudflare_origin_port_use_count(){
count=0
needle=$1
for count_id in 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do
[ "$(protocol_current_port "$count_id")" = "$needle" ] && count=$((count + 1))
done
printf '%s\n' "$count"
}

cloudflare_origin_replacement_port(){
replace_id=$1
kind=$(protocol_cf_port_kind "$replace_id")
if is_nat_mode; then
for pass in preferred any; do
for pair in $ptmap; do
candidate=${pair#*-}
port_valid "$candidate" || continue
[ "$candidate" = 22 ] && continue
if [ "$pass" = preferred ] && [ -n "$kind" ]; then
cf_port_matches_kind "$kind" "$candidate" || continue
fi
port_reserved "$candidate" && continue
port_in_use "$candidate" && continue
printf '%s\n' "$candidate"
return 0
done
done
return 1
fi
if [ -n "$kind" ]; then
random_cdn_port "$kind" 2>/dev/null && return 0
fi
random_port 2>/dev/null
}

cloudflare_auto_repair_origin_collisions(){
for repair_id in 3 13 4 8; do
state=$(cloudflare_protocol_state "$repair_id")
[ -n "$state" ] || continue
rest=${state#*|}; rest=${rest#*|}
file=${rest%%|*}
[ -s "$file" ] || continue
case "$repair_id" in
3|13) cdn_protocol_enabled xhttp || continue ;;
4) cdn_protocol_enabled ws || continue ;;
8) cdn_protocol_enabled vmess || continue ;;
esac
current=$(protocol_current_port "$repair_id")
[ -n "$current" ] || current=$(cat "$file" 2>/dev/null)
[ "$(cloudflare_origin_port_use_count "$current")" -gt 1 ] || continue
replacement=$(cloudflare_origin_replacement_port "$repair_id")
[ -n "$replacement" ] || {
red_line "$(protocol_label "$repair_id") 与其它协议共用内网端口 $current，且没有可自动迁移的空闲映射端口。"
return 1
}
if is_nat_mode; then replacement_origin=$(client_port "$replacement"); else replacement_origin=$replacement; fi
yellow_line "$(protocol_label "$repair_id") 与其它协议共用内网端口 $current，正在自动拆分到 $replacement。"
cloudflare_validate_origin_port "$repair_id" "$replacement_origin" || return 1
done
return 0
}

cloudflare_origin_api_deploy(){
override_id=$1
override_port=$2
cloudflare_require_token || return $?
ensure_cloudflare_origin_helper || return 1
host=$(cat "$HOME/lun/cdnym" 2>/dev/null)
[ -n "$host" ] || { red_line "尚未设置 CDN Host。"; return 1; }
specs=$(cloudflare_origin_rule_specs "$override_id" "$override_port")
[ -n "$specs" ] || { red_line "当前 CDN 范围没有兼容协议。"; return 1; }
ssl_mode=
http3=no
printf '%s\n' "$specs" | while IFS='|' read -r _proto _edge _origin _tls _path _label; do
[ "$_tls" = yes ] && printf 'tls\n'
[ "$_proto" = xhttp-tls ] && [ "$_edge" = 443 ] && printf 'h3\n'
done > "/tmp/lun-cf-features.$$"
if grep -q '^tls$' "/tmp/lun-cf-features.$$"; then
cert_mode_now=$(cat "$HOME/lun/cert_mode" 2>/dev/null)
cert_subject_now=$(cat "$HOME/lun/cert_subject" 2>/dev/null)
if [ "$cert_subject_now" = "$host" ] && [ "$cert_mode_now" != self ]; then ssl_mode=strict; else ssl_mode=full; fi
fi
grep -q '^h3$' "/tmp/lun-cf-features.$$" && http3=yes
rm -f "/tmp/lun-cf-features.$$"
api_result="/tmp/lun-cf-deploy.$$"
if CF_LUN_TOKEN="$(cat "$(cloudflare_token_file)")" \
CF_LUN_HOST="$host" \
CF_LUN_RULES="$specs" \
CF_LUN_ORIGIN_IPS="$(local_public_ips)" \
CF_LUN_SSL_MODE="$ssl_mode" \
CF_LUN_HTTP3="$http3" \
CF_LUN_BACKUP="$HOME/lun/cdn_cloudflare_backup.json" \
CF_LUN_STATE="$HOME/lun/cdn_cloudflare_state.json" \
python3 "$HOME/lun/cdn_cloudflare_api.py" deploy > "$api_result" 2>&1; then
green_line "Cloudflare 已自动配置：DNS 橙云、精确端口回源规则和所需协议设置均已部署。"
sed -n 's/^ROUTE=/  /p' "$api_result"
rm -f "$(cloudflare_manual_rule_file)"
rm -f "$api_result"
return 0
fi
api_error=$(sed -n 's/^ERROR=//p' "$api_result" | sed -n 1p)
[ -n "$api_error" ] || api_error=$(tail -n 1 "$api_result" 2>/dev/null)
red_line "Cloudflare 自动配置失败：$api_error"
rm -f "$api_result"
return 1
}

cloudflare_origin_quick_verify(){
command -v curl >/dev/null 2>&1 || return 1
host=$(cat "$HOME/lun/cdnym" 2>/dev/null)
path=$(cdn_probe_path)
[ -n "$host" ] && [ -n "$path" ] || return 1
edge=
[ -s "$HOME/lun/port_xc" ] && edge=$(cdn_client_port "$(cat "$HOME/lun/port_xc")")
[ -n "$edge" ] || edge=${cdnpt:-$(cdn_recommended_edge_port)}
is_cf_https_port "$edge" && scheme=https || scheme=http
endpoints=$(cdn_ip_list)
[ -n "$endpoints" ] || endpoints=$host
checked=0
for endpoint in $endpoints; do
checked=$((checked + 1))
connect_endpoint=$(uri_host "$endpoint")
headerfile="/tmp/lun-cf-quick-header.$$"
code=$(curl -k -sS -D "$headerfile" -o /dev/null -w '%{http_code}' --connect-timeout 3 --max-time 5 --connect-to "$host:$edge:$connect_endpoint:$edge" "$scheme://$host:$edge/$path" 2>/dev/null)
rc=$?
if [ "$rc" -eq 0 ] &&
   grep -Eqi '^(server:[[:space:]]*cloudflare|cf-ray:)' "$headerfile" 2>/dev/null &&
   ! grep -Eqi '^via:.*apple\.com' "$headerfile" 2>/dev/null &&
   { [ "$code" -lt 520 ] 2>/dev/null || [ "$code" -gt 527 ] 2>/dev/null; }; then
rm -f "$headerfile"
return 0
fi
rm -f "$headerfile"
[ "$checked" -ge 1 ] && break
done
return 1
}

cloudflare_origin_wait_verify(){
for wait_seconds in 2 4; do
sleep "$wait_seconds"
cloudflare_origin_quick_verify && return 0
done
return 1
}

cloudflare_origin_finalize_pending(){
[ -s "$HOME/lun/cdn_cloudflare_pending" ] || return 0
rm -f "$HOME/lun/cdn_cloudflare_pending"
echo "正在等待 Cloudflare 新规则生效……"
if cloudflare_origin_wait_verify; then
green_line "Cloudflare 端口回源验证成功，订阅已按新规则刷新。"
cip
return 0
fi
red_line "Cloudflare API 已部署，但边缘验证尚未通过；请稍后在入口网络管理中选择“一键自动部署 / 修复”重试。"
return 1
}

cloudflare_origin_api_remove(){
cloudflare_require_token || return $?
ensure_cloudflare_origin_helper || return 1
host=$(cat "$HOME/lun/cdnym" 2>/dev/null)
[ -n "$host" ] || return 0
result_file="/tmp/lun-cf-remove.$$"
if CF_LUN_TOKEN="$(cat "$(cloudflare_token_file)")" CF_LUN_HOST="$host" \
python3 "$HOME/lun/cdn_cloudflare_api.py" remove > "$result_file" 2>&1; then
removed=$(sed -n 's/^REMOVED=//p' "$result_file" | sed -n 1p)
rm -f "$result_file"
rm -f "$HOME/lun/cdn_cloudflare_state.json"
green_line "Cloudflare 中由 Lun 创建的回源规则已删除（$removed 条）；DNS 橙云保持不变。"
return 0
fi
api_error=$(sed -n 's/^ERROR=//p' "$result_file" | sed -n 1p)
rm -f "$result_file"
red_line "Cloudflare 规则删除失败：$api_error"
return 1
}

oneclick_snapshot_restore_files(){
snapshot_dir="$HOME/lun/.rebuild_snapshot"
[ -d "$snapshot_dir/lun" ] || return 0
rm -f "$HOME/lun"/*.json "$HOME/lun"/port_* "$HOME/lun"/sbargo* "$HOME/lun"/argo* \
"$HOME/lun"/uuid "$HOME/lun"/domain "$HOME/lun"/cert_* "$HOME/lun"/cert.crt "$HOME/lun"/private.key "$HOME/lun"/SHA256.txt \
"$HOME/lun"/acme_* "$HOME/lun"/cert.env "$HOME/lun"/vps_mode "$HOME/lun"/port_map "$HOME/lun"/port_pool \
"$HOME/lun"/inner_port_pool "$HOME/lun"/outer_port_pool "$HOME/lun"/sub* "$HOME/lun"/cdn* "$HOME/lun"/cfip* \
"$HOME/lun"/xvvmcdnym "$HOME/lun"/address_mode "$HOME/lun"/addym "$HOME/lun"/addout "$HOME/lun"/ipp* \
"$HOME/lun"/warp* "$HOME/lun"/ym_vl_re "$HOME/lun"/name "$HOME/lun"/server_number "$HOME/lun"/server_place "$HOME/lun"/vlvm \
"$HOME/lun"/oneclick_*
cp -a "$snapshot_dir/lun/." "$HOME/lun/" 2>/dev/null || true
rm -rf "$snapshot_dir"
}

oneclick_reload_state(){
clear_all_protocol_picks
refresh_protocol_flags
load_installed_protocol_flags
ptmap=$(cat "$HOME/lun/port_map" 2>/dev/null)
vpsmode=$(cat "$HOME/lun/vps_mode" 2>/dev/null); [ -n "$vpsmode" ] || vpsmode=normal
domain=$(cat "$HOME/lun/domain" 2>/dev/null)
cdnym=$(cat "$HOME/lun/cdnym" 2>/dev/null)
cfip=$(cdn_ip_list | tr '\n' ' ' | sed 's/[[:space:]]*$//')
cdnmode=$(cat "$HOME/lun/cdn_mode" 2>/dev/null); [ -n "$cdnmode" ] || cdnmode=standard
cdnpt=$(cat "$HOME/lun/cdn_edge_port" 2>/dev/null)
cdnproto=$(cat "$HOME/lun/cdn_protocol" 2>/dev/null); [ -n "$cdnproto" ] || cdnproto=xhttp
certmode=$(cat "$HOME/lun/cert_mode" 2>/dev/null); [ -n "$certmode" ] || certmode=self
acme_email=$(cat "$HOME/lun/acme_email" 2>/dev/null)
acme_dns=$(cat "$HOME/lun/acme_dns" 2>/dev/null)
addym=$(cat "$HOME/lun/addym" 2>/dev/null)
addout=$(cat "$HOME/lun/addout" 2>/dev/null)
addrmode=$(cat "$HOME/lun/address_mode" 2>/dev/null)
if [ -s "$HOME/lun/subport.log" ]; then sub=y; subpt=$(cat "$HOME/lun/subport.log"); else sub=; subpt=; fi
subid=$(cat "$HOME/lun/subtoken.log" 2>/dev/null)
ARGO_DOMAIN=$(cat "$HOME/lun/sbargoym.log" 2>/dev/null)
ARGO_AUTH=$(cat "$HOME/lun/sbargotoken.log" 2>/dev/null)
case "$(cat "$HOME/lun/vlvm" 2>/dev/null)" in Vless) argo=vwpt ;; Vmess) argo=vmpt ;; *) argo= ;; esac
export ptmap vpsmode domain cdnym cfip cdnmode cdnpt cdnproto certmode acme_email acme_dns
export addym addout addrmode sub subpt subid ARGO_DOMAIN ARGO_AUTH argo
}

oneclick_cancel_restore(){
oneclick_snapshot_restore_files
oneclick_reload_state
}

cloudflare_origin_api_restore(){
[ -f "$HOME/lun/oneclick_origin_deployed" ] || return 0
token_file=$(cloudflare_token_file)
[ -s "$token_file" ] || return 1
host=$(sed -n 's/^HOST=//p' "$HOME/lun/oneclick_full_pending" | sed -n 1p)
CF_LUN_TOKEN="$(cat "$token_file")" CF_LUN_HOST="$host" \
CF_LUN_BACKUP="$HOME/lun/cdn_cloudflare_backup.json" CF_LUN_STATE="$HOME/lun/cdn_cloudflare_state.json" \
python3 "$HOME/lun/cdn_cloudflare_api.py" restore >/dev/null 2>&1
}

cloudflare_tunnel_rollback(){
token_file=$(cloudflare_token_file)
[ -s "$token_file" ] && [ -s "$HOME/lun/oneclick_tunnel_state.json" ] || return 0
CF_LUN_TOKEN="$(cat "$token_file")" CF_LUN_TUNNEL_STATE="$HOME/lun/oneclick_tunnel_state.json" \
python3 "$HOME/lun/cdn_cloudflare_api.py" tunnel-rollback >/dev/null 2>&1
}

oneclick_cloud_rollback(){
cloudflare_origin_api_restore || true
cloudflare_tunnel_rollback || true
rm -f "$HOME/lun/oneclick_origin_deployed" "$HOME/lun/oneclick_cloud_verified" "$HOME/lun/oneclick_full_pending"
}

oneclick_cloudflare_zones(){
ensure_cloudflare_origin_helper || return 1
cloudflare_require_token || return $?
zone_file="/tmp/lun-oneclick-zones.$$"
if ! CF_LUN_TOKEN="$(cat "$(cloudflare_token_file)")" python3 "$HOME/lun/cdn_cloudflare_api.py" zones > "$zone_file" 2>&1; then
red_line "Cloudflare 区域读取失败：$(sed -n 's/^ERROR=//p' "$zone_file" | sed -n 1p)"
rm -f "$zone_file"
return 1
fi
zone_count=$(grep -c '^ZONE=' "$zone_file" 2>/dev/null)
[ "$zone_count" -gt 0 ] 2>/dev/null || { red_line "Token 没有返回可用区域。"; rm -f "$zone_file"; return 1; }
if [ "$zone_count" -eq 1 ]; then
ONECLICK_ZONE=$(sed -n 's/^ZONE=//p' "$zone_file" | sed -n 1p | cut -d'|' -f1)
green_line "已识别 Cloudflare 区域：$ONECLICK_ZONE"
rm -f "$zone_file"
return 0
fi
echo "Token 可用区域："
grep '^ZONE=' "$zone_file" | sed 's/^ZONE=//' | awk -F'|' '{printf " %2d. %s（%s）\n", NR, $1, $4}'
printf "请选择区域编号（输入 0 返回）："
IFS= read -r zone_choice
[ "$zone_choice" = 0 ] && { rm -f "$zone_file"; return 2; }
case "$zone_choice" in ''|*[!0-9]*) rm -f "$zone_file"; red_line "区域编号无效。"; return 1 ;; esac
ONECLICK_ZONE=$(sed -n 's/^ZONE=//p' "$zone_file" | sed -n "${zone_choice}p" | cut -d'|' -f1)
rm -f "$zone_file"
[ -n "$ONECLICK_ZONE" ] || { red_line "区域编号不存在。"; return 1; }
}

oneclick_cloudflare_host(){
host_file="/tmp/lun-oneclick-hosts.$$"
CF_LUN_TOKEN="$(cat "$(cloudflare_token_file)")" CF_LUN_ZONE="$ONECLICK_ZONE" \
CF_LUN_ORIGIN_IPS="$(local_public_ips)" python3 "$HOME/lun/cdn_cloudflare_api.py" hosts > "$host_file" 2>&1 || {
red_line "Cloudflare 域名识别失败：$(sed -n 's/^ERROR=//p' "$host_file" | sed -n 1p)"
rm -f "$host_file"
return 1
}
ONECLICK_HOST=$(sed -n 's/^HOST=//p' "$host_file" | sed -n 1p | cut -d'|' -f1)
rm -f "$host_file"
if [ -n "$ONECLICK_HOST" ]; then
green_line "已识别绑定本机公网 IP 的域名：$ONECLICK_HOST"
else
ensure_server_identity >/dev/null 2>&1 || true
oneclick_number=${server_number:-01}
ONECLICK_HOST="lun-${oneclick_number}.${ONECLICK_ZONE}"
yellow_line "该区域没有绑定本机公网 IP 的记录；将自动创建橙云域名 $ONECLICK_HOST。"
fi
}

oneclick_cloudflare_preflight(){
preflight_file="/tmp/lun-oneclick-preflight.$$"
if CF_LUN_TOKEN="$(cat "$(cloudflare_token_file)")" CF_LUN_HOST="$ONECLICK_HOST" \
python3 "$HOME/lun/cdn_cloudflare_api.py" preflight > "$preflight_file" 2>&1; then
rm -f "$preflight_file"
green_line "Cloudflare 区域、DNS、Origin Rules、区域设置和 Tunnel 读取自检通过。"
yellow_line "Cloudflare 不提供无副作用的写权限预检；实际写入会在确认后事务化验证，失败自动回滚。"
return 0
fi
red_line "Cloudflare 权限自检失败：$(sed -n 's/^ERROR=//p' "$preflight_file" | sed -n 1p)"
yellow_line "请换用覆盖全部账户和全部区域、具有最大可用编辑权限的用户 API Token。"
rm -f "$preflight_file"
return 1
}

oneclick_lun_owned_port(){
needle=$1
for file in "$HOME/lun"/port_*; do
[ -s "$file" ] || continue
[ "$(cat "$file" 2>/dev/null)" = "$needle" ] && return 0
done
[ "$(cat "$HOME/lun/subport.log" 2>/dev/null)" = "$needle" ] && return 0
return 1
}

oneclick_port_safe(){
candidate=$1
port_valid "$candidate" || return 1
[ "$candidate" = 22 ] && return 1
cluster_port=$(cluster_config_value internal_port 2>/dev/null)
[ -n "$cluster_port" ] && [ "$candidate" = "$cluster_port" ] && return 1
if port_in_use "$candidate" && ! oneclick_lun_owned_port "$candidate"; then return 1; fi
return 0
}

oneclick_collect_ports(){
ONECLICK_MAP=
ONECLICK_PORTS=
echo "端口按自动套餐顺序使用：CDN回源、CF隧道、Reality直连、订阅；只有 2/3 个端口时自动精简。"
if [ "$ONECLICK_MODE" = nat ]; then
yellow_line "NAT 格式为 公网端口-内网端口，例如 56567-8080；至少 2 组，脚本最多取前 4 组。"
printf "粘贴 NAT 映射（回车复用当前映射，输入 0 返回）："
IFS= read -r port_input
[ "$port_input" = 0 ] && return 2
[ -n "$port_input" ] || port_input="$ptmap"
ONECLICK_MAP=$(normalize_ptmap "$port_input") || return 1
[ -n "$ONECLICK_MAP" ] || { red_line "NAT 一键全配置至少需要 2 组映射。"; return 1; }
for pair in $ONECLICK_MAP; do
inner=${pair#*-}
oneclick_port_safe "$inner" || { yellow_line "映射 $pair 的内网端口不可用，已跳过。"; continue; }
ONECLICK_PORTS="${ONECLICK_PORTS:+$ONECLICK_PORTS }$inner"
current_count=$(printf '%s\n' $ONECLICK_PORTS | awk 'NF{n++} END{print n+0}')
[ "$current_count" -ge 4 ] && break
done
else
printf "输入 2-4 个本机端口（空格分隔；回车自动分配 4 个；输入 0 返回）："
IFS= read -r port_input
[ "$port_input" = 0 ] && return 2
if [ -n "$port_input" ]; then
for candidate in $port_input; do
case " $ONECLICK_PORTS " in *" $candidate "*) red_line "端口 $candidate 重复。"; return 1 ;; esac
oneclick_port_safe "$candidate" || { red_line "端口 $candidate 无效、被集群占用或被非 Lun 进程监听。"; return 1; }
ONECLICK_PORTS="${ONECLICK_PORTS:+$ONECLICK_PORTS }$candidate"
done
else
for _oneclick_n in 1 2 3 4; do
candidate=$(random_port 2>/dev/null) || return 1
while case " $ONECLICK_PORTS " in *" $candidate "*) true ;; *) false ;; esac; do
candidate=$(random_port 2>/dev/null) || return 1
done
ONECLICK_PORTS="${ONECLICK_PORTS:+$ONECLICK_PORTS }$candidate"
done
green_line "已自动分配端口：$ONECLICK_PORTS"
fi
fi
ONECLICK_PORT_COUNT=$(printf '%s\n' $ONECLICK_PORTS | awk 'NF{n++} END{print n+0}')
[ "$ONECLICK_PORT_COUNT" -ge 2 ] && [ "$ONECLICK_PORT_COUNT" -le 4 ] || {
red_line "一键全配置需要 2-4 个可用端口；当前只有 $ONECLICK_PORT_COUNT 个。"
return 1
}
set -- $ONECLICK_PORTS
case "$ONECLICK_PORT_COUNT" in
4) ONECLICK_PROFILE=full; ONECLICK_CDN_PORT=$1; ONECLICK_WS_PORT=$2; ONECLICK_REALITY_PORT=$3; ONECLICK_SUB_PORT=$4 ;;
3) ONECLICK_PROFILE=cdn-tunnel; ONECLICK_CDN_PORT=$1; ONECLICK_WS_PORT=$2; ONECLICK_REALITY_PORT=; ONECLICK_SUB_PORT=$3 ;;
2) ONECLICK_PROFILE=shared-ws; ONECLICK_CDN_PORT=$1; ONECLICK_WS_PORT=$1; ONECLICK_REALITY_PORT=; ONECLICK_SUB_PORT=$2 ;;
esac
}

oneclick_prompt_cdn_ips(){
printf "粘贴 CDN 优选 IP/域名（支持 IP:端口#备注；回车直接使用服务域名；输入 0 返回）："
IFS= read -r cdn_input
[ "$cdn_input" = 0 ] && return 2
case "$cdn_input" in
*#*|*"Mbps"*|*"ms]"*)
yellow_line "可继续粘贴剩余行，最后输入空行结束。"
while IFS= read -r extra_line; do
[ -n "$extra_line" ] || break
cdn_input="$cdn_input
$extra_line"
done
;;
esac
[ -n "$cdn_input" ] || cdn_input="$ONECLICK_HOST"
ONECLICK_CDN_IPS=$(normalize_cdn_ip_input "$cdn_input")
[ -n "$ONECLICK_CDN_IPS" ] || { red_line "没有识别到有效 CDN 入口。"; return 1; }
}

oneclick_profile_label(){
case "$1" in
full) printf '四端口完整套餐' ;;
cdn-tunnel) printf '三端口 CDN + 隧道套餐' ;;
shared-ws) printf '双端口 WS 共享套餐' ;;
esac
}

oneclick_apply_local_state(){
clear_all_protocol_picks
ONECLICK_FORCE_CERT=yes
case "$ONECLICK_PROFILE" in
full) xcpt=$ONECLICK_CDN_PORT; vwpt=$ONECLICK_WS_PORT; vlpt=$ONECLICK_REALITY_PORT; cdnproto=xhttp; cdnpt=443 ;;
cdn-tunnel) xcpt=$ONECLICK_CDN_PORT; vwpt=$ONECLICK_WS_PORT; cdnproto=xhttp; cdnpt=443 ;;
shared-ws) vwpt=$ONECLICK_WS_PORT; cdnproto=all; cdnpt=8080 ;;
esac
refresh_protocol_flags
vpsmode=$ONECLICK_MODE
[ "$vpsmode" = nat ] && ptmap=$ONECLICK_MAP
domain=$ONECLICK_HOST
cdnym=$ONECLICK_HOST
cdnmode=rewrite
certmode=dns
acme_dns=dns_cf
[ -n "$acme_email" ] || acme_email=$(gen_random_gmail)
sub=y
subid=
subpt=$ONECLICK_SUB_PORT
subipmode=ipv4
addym=$ONECLICK_HOST
addout=replace
addrmode=domain
mkdir -p "$HOME/lun"
printf '%s\n' "$vpsmode" > "$HOME/lun/vps_mode"
[ "$vpsmode" = nat ] && printf '%s\n' "$ptmap" > "$HOME/lun/port_map"
printf '%s\n' "$domain" > "$HOME/lun/domain"
printf '%s\n' "$cdnym" > "$HOME/lun/cdnym"
printf '%s\n' "$cdnmode" > "$HOME/lun/cdn_mode"
printf '%s\n' "$cdnpt" > "$HOME/lun/cdn_edge_port"
printf '%s\n' "$cdnproto" > "$HOME/lun/cdn_protocol"
printf '%s\n' "$certmode" > "$HOME/lun/cert_mode"
printf '%s\n' "$acme_dns" > "$HOME/lun/acme_dns"
printf '%s\n' "$acme_email" > "$HOME/lun/acme_email"
printf 'export CF_Token=%s\n' "$(cat "$(cloudflare_token_file)")" > "$HOME/lun/cert.env"
printf '%s\n' "$subipmode" > "$HOME/lun/subip_mode"
printf '%s\n' "$addym" > "$HOME/lun/addym"
printf '%s\n' "$addout" > "$HOME/lun/addout"
printf '%s\n' "$addrmode" > "$HOME/lun/address_mode"
chmod 600 "$HOME/lun/cert.env" "$HOME/lun/acme_dns" "$(cloudflare_token_file)" 2>/dev/null
save_cdn_ip_list "$ONECLICK_CDN_IPS" || return 1
export vpsmode ptmap domain cdnym cdnmode cdnpt cdnproto certmode acme_dns acme_email
export sub subid subpt subipmode addym addout addrmode vlpt vwpt xcpt ONECLICK_FORCE_CERT
}

oneclick_deploy_tunnel(){
ensure_server_identity >/dev/null 2>&1 || true
oneclick_number=${server_number:-01}
ONECLICK_TUNNEL_HOST="argo-${oneclick_number}.${ONECLICK_ZONE}"
tunnel_result="/tmp/lun-oneclick-tunnel.$$"
if ! CF_LUN_TOKEN="$(cat "$(cloudflare_token_file)")" CF_LUN_HOST="$ONECLICK_HOST" \
CF_LUN_TUNNEL_HOST="$ONECLICK_TUNNEL_HOST" CF_LUN_TUNNEL_PORT="$ONECLICK_WS_PORT" \
CF_LUN_TUNNEL_STATE="$HOME/lun/oneclick_tunnel_state.json" \
python3 "$HOME/lun/cdn_cloudflare_api.py" tunnel-deploy > "$tunnel_result" 2>&1; then
tunnel_error=$(sed -n 's/^ERROR=//p' "$tunnel_result" | sed -n 1p)
case "$tunnel_error" in
*"HTTP 403"*|*"Authentication error"*)
red_line "Cloudflare Tunnel 自动配置失败：当前 Token 缺少账户级 Cloudflare Tunnel 编辑权限。"
yellow_line "请换用覆盖全部账户与区域、具有最大可用编辑权限的用户 API Token；无需填写任何 ID。"
;;
*) red_line "Cloudflare Tunnel 自动配置失败：$tunnel_error" ;;
esac
rm -f "$tunnel_result"
return 1
fi
ARGO_DOMAIN=$(sed -n 's/^TUNNEL_HOST=//p' "$tunnel_result" | sed -n 1p)
ARGO_AUTH=$(sed -n 's/^TUNNEL_TOKEN=//p' "$tunnel_result" | sed -n 1p)
rm -f "$tunnel_result"
[ -n "$ARGO_DOMAIN" ] && [ -n "$ARGO_AUTH" ] || return 1
argo=vwpt
umask 077
printf '%s\n' "$ARGO_DOMAIN" > "$HOME/lun/sbargoym.log"
printf '%s\n' "$ARGO_AUTH" > "$HOME/lun/sbargotoken.log"
printf '%s\n' Vless > "$HOME/lun/vlvm"
chmod 600 "$HOME/lun/sbargoym.log" "$HOME/lun/sbargotoken.log" "$HOME/lun/oneclick_tunnel_state.json"
export argo ARGO_DOMAIN ARGO_AUTH
green_line "Cloudflare Tunnel 已创建/修复：$ARGO_DOMAIN → http://localhost:$ONECLICK_WS_PORT"
}

oneclick_full_setup(){
ui_title "Lun 一键全配置"
yellow_line "保留 UUID 与内核，协议组合切换为自动精选套餐；任一步失败都会恢复操作前快照。"
create_rebuild_snapshot || { red_line "无法创建一键配置前快照。"; return 1; }
touch "$HOME/lun/.rebuild_snapshot/oneclick_prepared"
echo "VPS 类型：1. 普通 VPS  2. NAT VPS"
printf "请选择 [回车沿用当前 %s，输入 0 返回]：" "${vpsmode:-normal}"
IFS= read -r mode_choice
case "$mode_choice" in
0) oneclick_cancel_restore; return 2 ;;
1) ONECLICK_MODE=normal ;;
2) ONECLICK_MODE=nat ;;
"") ONECLICK_MODE=${vpsmode:-normal} ;;
*) red_line "VPS 类型输入无效。"; oneclick_cancel_restore; return 1 ;;
esac
oneclick_collect_ports
rc=$?
[ "$rc" = 0 ] || { oneclick_cancel_restore; return "$rc"; }
cloudflare_require_token
rc=$?
[ "$rc" = 0 ] || { oneclick_cancel_restore; return "$rc"; }
oneclick_cloudflare_zones
rc=$?
[ "$rc" = 0 ] || { oneclick_cancel_restore; return "$rc"; }
oneclick_cloudflare_host || { oneclick_cancel_restore; return 1; }
oneclick_cloudflare_preflight || { oneclick_cancel_restore; return 1; }
oneclick_prompt_cdn_ips
rc=$?
[ "$rc" = 0 ] || { oneclick_cancel_restore; return "$rc"; }
echo
ui_title "一键全配置确认"
echo "套餐：$(oneclick_profile_label "$ONECLICK_PROFILE")"
echo "VPS：$ONECLICK_MODE${ONECLICK_MAP:+  映射=$ONECLICK_MAP}"
echo "协议端口：CDN回源=$ONECLICK_CDN_PORT  CF隧道=$ONECLICK_WS_PORT${ONECLICK_REALITY_PORT:+  Reality=$ONECLICK_REALITY_PORT}  订阅=$ONECLICK_SUB_PORT"
echo "服务域名：$ONECLICK_HOST"
echo "CDN入口：$ONECLICK_CDN_IPS"
echo "证书：Let's Encrypt DNS-01（Cloudflare）"
if [ "$ONECLICK_PROFILE" = shared-ws ]; then oneclick_edge=8080; else oneclick_edge=443; fi
oneclick_origin_public=$ONECLICK_CDN_PORT
if [ "$ONECLICK_MODE" = nat ]; then
for oneclick_pair in $ONECLICK_MAP; do
[ "${oneclick_pair#*-}" = "$ONECLICK_CDN_PORT" ] && { oneclick_origin_public=${oneclick_pair%%-*}; break; }
done
fi
echo "Origin Rules：边缘 $oneclick_edge → 源站 $oneclick_origin_public"
echo "Tunnel：自动创建独立域名并回源 http://localhost:$ONECLICK_WS_PORT"
printf "确认执行？输入 YES（输入 0 返回）："
IFS= read -r confirm
[ "$confirm" = YES ] || { oneclick_cancel_restore; return 2; }
oneclick_apply_local_state || { oneclick_cancel_restore; return 1; }
oneclick_deploy_tunnel || { cloudflare_tunnel_rollback || true; oneclick_cancel_restore; return 1; }
if ! cat > "$HOME/lun/oneclick_full_pending" <<EOF
PROFILE=$ONECLICK_PROFILE
ZONE=$ONECLICK_ZONE
HOST=$ONECLICK_HOST
CDN_PORT=$ONECLICK_CDN_PORT
WS_PORT=$ONECLICK_WS_PORT
REALITY_PORT=$ONECLICK_REALITY_PORT
SUB_PORT=$ONECLICK_SUB_PORT
TUNNEL_HOST=$ARGO_DOMAIN
EDGE_PORT=$cdnpt
EOF
then
cloudflare_tunnel_rollback || true
oneclick_cancel_restore
return 1
fi
chmod 600 "$HOME/lun/oneclick_full_pending"
green_line "云端隧道准备完成；现在开始事务化安装/重建、申请证书并部署 Origin Rules。"
return 0
}

oneclick_full_finalize(){
[ -s "$HOME/lun/oneclick_full_pending" ] || return 0
host=$(sed -n 's/^HOST=//p' "$HOME/lun/oneclick_full_pending" | sed -n 1p)
cert_mode_now=$(cat "$HOME/lun/cert_mode" 2>/dev/null)
cert_subject_now=$(cat "$HOME/lun/cert_subject" 2>/dev/null)
if [ "$cert_subject_now" != "$host" ] || [ "$cert_mode_now" != dns ] || \
! cert_key_matches "$HOME/lun/cert.crt" "$HOME/lun/private.key" || \
! cert_publicly_trusted_for_domain "$HOME/lun/cert.crt" "$host"; then
red_line "DNS-01 公开证书未成功生成，已拒绝继续云端回源配置。"
return 1
fi
cloudflare_origin_api_deploy "" "" || return 1
touch "$HOME/lun/oneclick_origin_deployed"
echo "正在验证 Cloudflare 精确端口回源……"
if ! cloudflare_origin_wait_verify; then
red_line "Cloudflare 端口回源未通过快速验证，一键全配置将自动回滚。"
return 1
fi
touch "$HOME/lun/oneclick_cloud_verified" || return 1
green_line "Cloudflare 证书、端口回源和 Tunnel 云端配置已验证；继续检查本地订阅。"
return 0
}

oneclick_full_complete(){
[ -s "$HOME/lun/oneclick_full_pending" ] || return 0
[ -f "$HOME/lun/oneclick_cloud_verified" ] || { red_line "Cloudflare 云端验证状态缺失。"; return 1; }
host=$(sed -n 's/^HOST=//p' "$HOME/lun/oneclick_full_pending" | sed -n 1p)
tunnel_host=$(sed -n 's/^TUNNEL_HOST=//p' "$HOME/lun/oneclick_full_pending" | sed -n 1p)
cert_mode_now=$(cat "$HOME/lun/cert_mode" 2>/dev/null)
cert_subject_now=$(cat "$HOME/lun/cert_subject" 2>/dev/null)
if [ "$cert_subject_now" != "$host" ] || [ "$cert_mode_now" != dns ] || \
! cert_key_matches "$HOME/lun/cert.crt" "$HOME/lun/private.key" || \
! cert_publicly_trusted_for_domain "$HOME/lun/cert.crt" "$host"; then
red_line "DNS-01 公开证书最终校验失败，已拒绝生成成功报告。"
return 1
fi
sub_port=$(cat "$HOME/lun/subport.log" 2>/dev/null)
sub_token=$(cat "$HOME/lun/subtoken.log" 2>/dev/null)
[ -n "$sub_port" ] && [ -n "$sub_token" ] || { red_line "订阅端口或订阅令牌未生成。"; return 1; }
subscription_check="/tmp/lun-oneclick-subscription.$$"
if ! curl -fsS --connect-timeout 3 --max-time 8 \
"http://127.0.0.1:$sub_port/$sub_token/jhsub.txt" > "$subscription_check" 2>/dev/null; then
rm -f "$subscription_check"
red_line "本地订阅服务未通过 HTTP 验证。"
return 1
fi
if ! grep -Fq "$host" "$subscription_check" || ! grep -Fq "$tunnel_host" "$subscription_check"; then
rm -f "$subscription_check"
red_line "订阅文件缺少 CDN 或 Tunnel 节点。"
return 1
fi
rm -f "$subscription_check"
if pidof systemd >/dev/null 2>&1; then
systemctl is-active --quiet argo || { red_line "Cloudflare Tunnel 服务未运行。"; return 1; }
else
pgrep -f "$HOME/lun/cloudflared.*tunnel" >/dev/null 2>&1 || { red_line "Cloudflare Tunnel 进程未运行。"; return 1; }
fi
report="$HOME/lun/oneclick_full_report.txt"
{
echo "Lun 一键全配置测试报告"
echo "完成时间：$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
cat "$HOME/lun/oneclick_full_pending"
echo "CERT_MODE=$cert_mode_now"
echo "CERT_SUBJECT=$cert_subject_now"
echo "CERT_TRUST=public"
echo "XRAY_CONFIG=$([ -s "$HOME/lun/xr.json" ] && echo ok || echo unused)"
echo "SINGBOX_CONFIG=$([ -s "$HOME/lun/sb.json" ] && echo ok || echo unused)"
echo "ORIGIN_RULES=verified"
echo "TUNNEL=configured"
echo "SUBSCRIPTION_HTTP=verified"
echo "SUBSCRIPTION_CONTENT=verified"
echo "RESULT=PASS"
} > "$report"
chmod 600 "$report"
rm -f "$HOME/lun/oneclick_origin_deployed" "$HOME/lun/oneclick_cloud_verified" "$HOME/lun/oneclick_full_pending"
green_line "一键全配置已通过：证书、CDN 优选、端口回源和 Tunnel 均已生效。"
green_line "测试报告：$report"
return 0
}

show_cdn_origin_rules(){
host=$(cat "$HOME/lun/cdnym" 2>/dev/null)
[ -n "$host" ] || { echo "尚未设置 CDN Host。"; return 1; }
if ! cdn_rewrite_active; then
echo "当前使用普通同端口 CDN，没有启用 Origin Rules 端口改写。"
return 0
fi
rule_uuid=$(cat "$HOME/lun/uuid" 2>/dev/null)
base_edge=${cdnpt:-$(cdn_recommended_edge_port)}
[ -s "$(cloudflare_manual_rule_file)" ] && green_line "当前含手动登记规则：Lun 信任控制台现有配置，不会调用 API 或逐个探测优选 IP。"
green_line "一键自动部署会把以下规则直接写入 Cloudflare，并自动开启该 Host 的橙云。"
yellow_line "旧 tls/nottls 宽泛规则会由自动部署识别并替换；其它用户规则保持不变。"
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
if [ "$label" = "VLESS XHTTP TLS" ]; then
printf '匹配表达式：(http.host eq "%s" and ssl and starts_with(http.request.uri.path, "/%s"))\n' "$host" "$path"
else
printf '匹配表达式：(http.host eq "%s" and starts_with(http.request.uri.path, "/%s"))\n' "$host" "$path"
fi
if is_nat_mode; then
printf '目标端口：%s（NAT 公网端口，内网监听 %s）\n' "$origin_public" "$inner"
else
printf '目标端口：%s（普通 VPS 本机监听端口）\n' "$inner"
fi
echo "Cloudflare 动作：重写 Destination port / 目标端口；不要改写 Host、SNI 或 URI Path。"
done
if [ "$https_used" = yes ]; then
cert_mode_now=$(cat "$HOME/lun/cert_mode" 2>/dev/null)
cert_subject_now=$(cat "$HOME/lun/cert_subject" 2>/dev/null)
if [ "$cert_subject_now" = "$host" ] && [ "$cert_mode_now" != self ]; then
green_line "HTTPS 源站 TLS：证书与 Host 匹配，可在 Cloudflare 使用 Full (Strict)。"
else
yellow_line "HTTPS 源站 TLS：当前证书为自签或与 Host 不同，请在 Cloudflare 使用 Full，不要使用 Full (Strict)。"
fi
[ "$h3_edge" = yes ] && yellow_line "实验性 CDN-UDP 还要求 Cloudflare 开启 HTTP/3（QUIC/UDP 443）。手动优选 IP 只能指定边缘入口，不能替灰云 Host 创建路由；灰云兼容不受官方保证，必须以诊断结果为准。"
fi
is_nat_mode && show_nat_cdn_hint
yellow_line "自动部署完成后 Lun 会等待 Cloudflare 生效、验证边缘回源并刷新订阅。"
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
yellow_line "$host 当前直接解析到本机，属于灰云/DNS only。手动 CF 优选 IP 只改变客户端连接地址，不能保证 Cloudflare 已承载该 Host；官方稳定用法是开启橙云，并以连通诊断为准。"
else
    green_line "$host 未直接返回本机公网地址；Origin Rules 一键部署会核对并开启该 Host 的橙云。"
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
yellow_line "快速诊断只检查首个优选入口；首项不通时不会继续等待其余 IP。"
for endpoint in $ips; do
connect_endpoint=$(uri_host "$endpoint")
errfile="/tmp/lun-cdn-diag.$$"
headerfile="/tmp/lun-cdn-header.$$"
code=$(curl -k -v -sS -D "$headerfile" -o /dev/null -w '%{http_code}' --connect-timeout 3 --max-time 6 --connect-to "$host:$edge:$connect_endpoint:$edge" "$scheme://$host:$edge/$path" 2>"$errfile")
rc=$?
err=$(cat "$errfile" 2>/dev/null)
if grep -Eqi '^(server:[[:space:]]*cloudflare|cf-ray:)' "$headerfile" 2>/dev/null; then through_cf=yes; else through_cf=no; fi
if grep -Eqi '^via:.*apple\.com' "$headerfile" 2>/dev/null; then edge_route=reality-apple; else edge_route=expected-or-unknown; fi
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
elif [ "$edge_route" = reality-apple ]; then
reality_public=
[ -s "$HOME/lun/port_xh" ] && reality_public=$(client_port "$(cat "$HOME/lun/port_xh" 2>/dev/null)")
red_line "$endpoint：已进入 Cloudflare，但回源落到了 Reality/Apple 伪装${reality_public:+（公网端口 $reality_public）}。请停用旧 tls/nottls 宽泛规则，并将 UUID-xc 精确规则指向 $(client_port "$(cat "$HOME/lun/port_xc" 2>/dev/null)")。"
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
break
done
is_nat_mode && yellow_line "NAT VPS 在服务器自身发起 CF 回环测试时可能误判；客户端外部测试结果优先。"
}

cdnopt_module_dir(){
printf '%s\n' "$HOME/lun/modules/cdnopt"
}

cdnopt_agent(){
printf '%s/lun_cdn_optimizer.py\n' "$(cdnopt_module_dir)"
}

cdnopt_install_python(){
command -v python3 >/dev/null 2>&1 && return 0
yellow_line "一键优选 CDN 模块需要 Python 3（仅在测速时运行），正在安装……"
if command -v apk >/dev/null 2>&1; then
apk add --no-cache python3 >/dev/null 2>&1
elif command -v apt-get >/dev/null 2>&1; then
apt-get update -y >/dev/null 2>&1 && DEBIAN_FRONTEND=noninteractive apt-get install -y python3 >/dev/null 2>&1
elif command -v dnf >/dev/null 2>&1; then
dnf install -y python3 >/dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
yum install -y python3 >/dev/null 2>&1
else
red_line "当前系统无法自动安装 Python 3，请先手动安装。"
return 1
fi
command -v python3 >/dev/null 2>&1
}

cdnopt_download_agent(){
cdnopt_dir=$(cdnopt_module_dir)
cdnopt_target=$(cdnopt_agent)
cdnopt_tmp="$cdnopt_target.tmp.$$"
mkdir -p "$cdnopt_dir" || return 1
rm -f "$cdnopt_tmp"
if [ -n "${LUN_CDNOPT_SOURCE:-}" ] && [ -s "$LUN_CDNOPT_SOURCE" ]; then
cp "$LUN_CDNOPT_SOURCE" "$cdnopt_tmp" || return 1
else
if [ -n "${LUN_CDNOPT_URL:-}" ]; then
cdnopt_url=$LUN_CDNOPT_URL
cdnopt_fallback=
else
cdnopt_url="https://api.github.com/repos/azk78lun-collab/FHLUN/contents/modules/cdnopt/lun_cdn_optimizer.py?ref=main&fhlun_nocache=$(date +%s)"
cdnopt_fallback="https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/modules/cdnopt/lun_cdn_optimizer.py?fhlun_nocache=$(date +%s)"
fi
if command -v curl >/dev/null 2>&1 && curl -fL -H 'Accept: application/vnd.github.raw+json' -H 'Cache-Control: no-cache' \
--connect-timeout 10 --max-time 120 --retry 2 -o "$cdnopt_tmp" "$cdnopt_url"; then
:
elif command -v wget >/dev/null 2>&1 && wget -O "$cdnopt_tmp" --header='Accept: application/vnd.github.raw+json' \
--header='Cache-Control: no-cache' --tries=2 --timeout=60 "$cdnopt_url"; then
:
elif [ -n "$cdnopt_fallback" ] && command -v curl >/dev/null 2>&1 && curl -fL -H 'Cache-Control: no-cache' \
--connect-timeout 10 --max-time 120 --retry 2 -o "$cdnopt_tmp" "$cdnopt_fallback"; then
:
elif [ -n "$cdnopt_fallback" ] && command -v wget >/dev/null 2>&1 && wget -O "$cdnopt_tmp" \
--header='Cache-Control: no-cache' --tries=2 --timeout=60 "$cdnopt_fallback"; then
:
else
rm -f "$cdnopt_tmp"
return 1
fi
fi
python3 - "$cdnopt_tmp" >/dev/null 2>&1 <<'PY' || {
import sys
import tokenize

path = sys.argv[1]
with tokenize.open(path) as source:
    compile(source.read(), path, "exec")
PY
rm -f "$cdnopt_tmp"
red_line "下载的 CDN 优选模块语法校验失败，已拒绝运行。"
return 1
}
cdnopt_version=$(python3 "$cdnopt_tmp" --version 2>/dev/null)
[ "$cdnopt_version" = 1.0.0 ] || {
rm -f "$cdnopt_tmp"
red_line "下载的 CDN 优选模块版本不匹配，已拒绝运行。"
return 1
}
mv -f "$cdnopt_tmp" "$cdnopt_target"
chmod 700 "$cdnopt_target"
}

cdnopt_public_host(){
cdnopt_host=$(cat "$HOME/lun/server_ip.log" 2>/dev/null)
[ -n "$cdnopt_host" ] || cdnopt_host=${v4:-${v6:-}}
[ -n "$cdnopt_host" ] || cdnopt_host=$(local_public_ips | sed -n '1p')
cdnopt_host=${cdnopt_host#\[}
cdnopt_host=${cdnopt_host%\]}
[ -n "$cdnopt_host" ] || return 1
printf '%s\n' "$cdnopt_host"
}

cdnopt_prompt_count(){
while :; do
printf "返回综合最快节点数量 [默认 5，1-20，输入 0 返回]："
IFS= read -r cdnopt_count
[ "$cdnopt_count" = 0 ] && return 2
[ -n "$cdnopt_count" ] || cdnopt_count=5
case "$cdnopt_count" in *[!0-9]*|'') echo "请输入 1-20。"; continue ;; esac
if [ "$cdnopt_count" -ge 1 ] 2>/dev/null && [ "$cdnopt_count" -le 20 ] 2>/dev/null; then
CDNOPT_TOP_COUNT=$cdnopt_count
return 0
fi
echo "请输入 1-20。"
done
}

cdnopt_cleanup_session(){
rm -f "$HOME/lun/cdnopt_port"
apply_lun_firewall_rules quiet >/dev/null 2>&1 || true
}

cdnopt_run(){
ui_title "Lun 一键优选 CDN 节点"
echo "CM IP 提供候选库；真实测速由您打开的电脑/手机浏览器执行。"
echo "默认剔除延迟 >150 ms 或带宽 <80 Mbps 的 IP，速度为主、延迟辅助排名。"
yellow_line "VPS 到优选 IP 的 ping 不代表您本地线路，因此 VPS 不伪装成最终带宽测试。"
cdnopt_prompt_count || return $?
cdnopt_top=$CDNOPT_TOP_COUNT
cdnopt_install_python || return 1
yellow_line "正在按需下载独立 CDN 优选模块……"
cdnopt_download_agent || { red_line "CDN 优选模块下载失败，未修改现有优选 IP。"; return 1; }
cdnopt_internal=$(random_subscription_port) || {
red_line "没有可用于临时测速页的空闲端口。"
is_nat_mode && yellow_line "NAT VPS 需要至少一组尚未被协议占用的“公网端口-内网端口”映射。"
return 1
}
cdnopt_public=$(client_port "$cdnopt_internal")
cdnopt_host=$(cdnopt_public_host) || { red_line "无法识别 VPS 公网 IP，未启动测速页。"; return 1; }
cdnopt_result_dir=$(cdnopt_module_dir)
cdnopt_result="$cdnopt_result_dir/result.$$.json"
rm -f "$cdnopt_result"
printf '%s\n' "$cdnopt_internal" > "$HOME/lun/cdnopt_port"
apply_lun_firewall_rules quiet >/dev/null 2>&1 || yellow_line "系统防火墙未能自动放行临时 TCP $cdnopt_internal，如页面打不开请检查防火墙/安全组。"
if is_nat_mode; then
green_line "临时页面使用 NAT 映射：公网 $cdnopt_public → 内网 $cdnopt_internal。"
else
yellow_line "如页面无法打开，请在云安全组临时放行 TCP $cdnopt_public；测速结束后 Lun 会删除自己的系统防火墙规则。"
fi
if [ -n "${LUN_CDNOPT_CANDIDATE_FILE:-}" ]; then
python3 "$(cdnopt_agent)" serve \
--port "$cdnopt_internal" --public-host "$cdnopt_host" --public-port "$cdnopt_public" \
--result-file "$cdnopt_result" --top "$cdnopt_top" --latency-max 150 --speed-min 80 \
--source-file "$LUN_CDNOPT_CANDIDATE_FILE"
else
python3 "$(cdnopt_agent)" serve \
--port "$cdnopt_internal" --public-host "$cdnopt_host" --public-port "$cdnopt_public" \
--result-file "$cdnopt_result" --top "$cdnopt_top" --latency-max 150 --speed-min 80
fi
cdnopt_rc=$?
cdnopt_cleanup_session
case "$cdnopt_rc" in
0) ;;
2) yellow_line "已取消优选，未修改现有节点。"; rm -f "$cdnopt_result"; return 2 ;;
*) red_line "CDN 优选未完成，现有节点保持不变。"; rm -f "$cdnopt_result"; return 1 ;;
esac
python3 "$(cdnopt_agent)" extract --result-file "$cdnopt_result" --format table || {
red_line "测速结果校验失败，现有节点保持不变。"
rm -f "$cdnopt_result"
return 1
}
cdnopt_ips=$(python3 "$(cdnopt_agent)" extract --result-file "$cdnopt_result" --format ips | tr '\n' ' ')
[ -n "$cdnopt_ips" ] && save_cdn_ip_list "$cdnopt_ips" || {
red_line "结果中没有可应用的 IP，现有节点保持不变。"
rm -f "$cdnopt_result"
return 1
}
rm -f "$cdnopt_result"
export cfip
green_line "已应用到 Lun CDN 优选入口：$cfip"
if [ -s "$HOME/lun/cdnym" ]; then
green_line "订阅将立即重建，已启用的 CDN 协议节点会直接使用新 IP。"
else
yellow_line "尚未设置 CDN Host；结果已保存，以后启用 CDN 协议时会直接复用。"
fi
return 0
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
printf "优选 IP/域名%s（支持 IP:端口#测速备注；空配置时回车自动解析橙云 Host；0 返回）：" "${current_ips:+，当前 $current_ips}"
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
case "$val" in
*#*|*"Mbps"*|*"ms]"*)
yellow_line "检测到测速列表格式：继续粘贴剩余行，最后输入空行完成。"
while IFS= read -r extra_line; do
[ -n "$extra_line" ] || break
val="$val
$extra_line"
done
;;
esac
cfip=$(normalize_cdn_ip_input "$val")
[ -n "$cfip" ] || { echo "没有识别到有效的 IPv4、IPv6 或域名。"; continue; }
save_cdn_ip_list "$cfip" || continue
green_line "优选入口已清洗并保存：$cfip"
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
echo " 1. 一键启用 / 修复 HTTP CDN（XHTTP / WS）"
echo " 2. 仅修改优选 IP / 域名"
echo " 3. 关闭 CDN 节点"
echo " 0. 返回"
printf "请选择 [0-3]："
IFS= read -r choice
case "$choice" in
1)
cdn_has_origin_rule_protocol || { yellow_line "尚未安装支持普通 CDN 的协议；请先添加 3.VLESS XHTTP、4.VLESS WS、8.VMess WS 或 13.VLESS XHTTP TLS TCP/UDP。"; return 1; }
prompt_cdn_host || return $?
prune_legacy_cdn_defaults
prompt_cdn_ips || return $?
if { [ "${vwp:-}" = yes ] || [ -n "${port_vw:-}" ] || [ -s "$HOME/lun/port_vw" ]; } ||
   { [ "${vmp:-}" = yes ] || [ -n "${port_vm_ws:-}" ] || [ -s "$HOME/lun/port_vm_ws" ]; }; then
cdnproto=all
else
cdnproto=xhttp
fi
printf '%s\n' "$cdnproto" > "$HOME/lun/cdn_protocol"
[ -n "$cdnmode" ] || cdnmode=standard
printf '%s\n' "$cdnmode" > "$HOME/lun/cdn_mode"
auto_configure_cdn_edge_port
export cdnym cfip cdnmode cdnpt cdnproto
show_cdn_dns_hint
if cdn_rewrite_active; then
green_line "CDN 已保存：协议范围=$cdnproto，边缘端口 $cdnpt；进入 Origin Rules 选择“一键自动部署 / 修复”即可完成回源。"
else
green_line "CDN 已保存：协议范围=$cdnproto；当前协议端口可直接使用 Cloudflare 同端口代理。"
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
rm -f "$HOME/lun/cdnym" "$HOME/lun/cdn_mode" "$HOME/lun/cdn_edge_port" "$HOME/lun/cdn_protocol" "$(cloudflare_manual_rule_file)"
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

cloudflare_prepare_rewrite_mode(){
preferred_edge=$1
CF_PREV_CDN_MODE=${cdnmode:-standard}
CF_PREV_CDN_PORT=${cdnpt:-}
CF_PREV_CDN_PROTO=${cdnproto:-xhttp}
if [ "${cdnproto:-xhttp}" = xhttp ] &&
   { [ -s "$HOME/lun/port_vw" ] || [ -s "$HOME/lun/port_vm_ws" ]; } &&
   { [ ! -s "$HOME/lun/port_vx" ] && [ ! -s "$HOME/lun/port_xc" ]; }; then
cdnproto=all
yellow_line "检测到仅安装 WS 类 CDN 协议，已自动纳入 VLESS WS / VMess WS。"
fi
cdnmode=rewrite
if [ -n "$preferred_edge" ]; then
cdnpt=$preferred_edge
elif cdn_has_generic_protocol && ! is_cf_http_port "${cdnpt:-}"; then
cdnpt=$(cdn_recommended_edge_port)
elif ! { is_cf_http_port "${cdnpt:-}" || is_cf_https_port "${cdnpt:-}"; }; then
cdnpt=$(cdn_recommended_edge_port)
fi
if cdn_has_xhttp_tls && ! cdn_has_generic_protocol && ! is_cf_https_port "$cdnpt"; then
cdnpt=443
fi
printf '%s\n' "$cdnmode" > "$HOME/lun/cdn_mode"
printf '%s\n' "$cdnpt" > "$HOME/lun/cdn_edge_port"
printf '%s\n' "$cdnproto" > "$HOME/lun/cdn_protocol"
if [ "$CF_PREV_CDN_MODE:$CF_PREV_CDN_PORT:$CF_PREV_CDN_PROTO" != "$cdnmode:$cdnpt:$cdnproto" ]; then
CDN_REBUILD_REQUIRED=yes
fi
export cdnmode cdnpt cdnproto
}

cloudflare_restore_rewrite_mode(){
cdnmode=$CF_PREV_CDN_MODE
cdnpt=$CF_PREV_CDN_PORT
cdnproto=$CF_PREV_CDN_PROTO
printf '%s\n' "$cdnmode" > "$HOME/lun/cdn_mode"
printf '%s\n' "$cdnproto" > "$HOME/lun/cdn_protocol"
if [ -n "$cdnpt" ]; then printf '%s\n' "$cdnpt" > "$HOME/lun/cdn_edge_port"; else rm -f "$HOME/lun/cdn_edge_port"; fi
CDN_REBUILD_REQUIRED=no
export cdnmode cdnpt cdnproto
}

cloudflare_finish_auto_deploy(){
override_id=$1
override_port=$2
if ! cloudflare_origin_api_deploy "$override_id" "$override_port"; then
cloudflare_restore_protocol_changes
cloudflare_restore_rewrite_mode
return 1
fi
if [ "$CDN_REBUILD_REQUIRED" = yes ]; then
printf '%s\n' pending > "$HOME/lun/cdn_cloudflare_pending"
green_line "Cloudflare 已部署；现在自动重建本机 TLS/端口配置，完成后会继续验证并刷新订阅。"
return 0
fi
echo "正在等待 Cloudflare 新规则生效……"
if cloudflare_origin_wait_verify; then
green_line "Cloudflare 端口回源验证成功；正在刷新订阅。"
return 0
fi
red_line "规则已通过 API 部署，但边缘尚未在等待时间内生效。请直接再次选择“一键自动部署 / 修复”，脚本会继续修复并验证。"
return 1
}

cloudflare_save_manual_rule(){
manual_save_id=$1
manual_save_edge=$2
manual_save_origin=$3
manual_save_state=$(cloudflare_protocol_state "$manual_save_id")
[ -n "$manual_save_state" ] || return 1
manual_save_rest=${manual_save_state#*|}
manual_save_rest=${manual_save_rest#*|}
manual_save_rest=${manual_save_rest#*|}
manual_save_path=$manual_save_rest
manual_save_host=$(cat "$HOME/lun/cdnym" 2>/dev/null)
manual_save_file=$(cloudflare_manual_rule_file)
manual_save_tmp="$manual_save_file.tmp.$$"
umask 077
if [ -s "$manual_save_file" ]; then
awk -F'|' -v host="$manual_save_host" -v id="$manual_save_id" \
'$1 != host || $2 != id' "$manual_save_file" > "$manual_save_tmp"
else
: > "$manual_save_tmp"
fi
printf '%s|%s|%s|%s|%s\n' "$manual_save_host" "$manual_save_id" "$manual_save_edge" "$manual_save_origin" "$manual_save_path" >> "$manual_save_tmp"
mv "$manual_save_tmp" "$manual_save_file"
chmod 600 "$manual_save_file"
}

cloudflare_prompt_manual_origin(){
echo "已安装且支持端口回源的协议："
for manual_id in 3 4 8 13; do
manual_state=$(cloudflare_protocol_state "$manual_id")
[ -n "$manual_state" ] || continue
manual_rest=${manual_state#*|}; manual_label=${manual_rest%%|*}; manual_rest=${manual_rest#*|}; manual_port_file=${manual_rest%%|*}
[ -s "$manual_port_file" ] || continue
manual_inner=$(cat "$manual_port_file" 2>/dev/null)
printf " %2s. %-24s 监听 %s" "$manual_id" "$manual_label" "$manual_inner"
is_nat_mode && printf " / NAT 公网 %s" "$(client_port "$manual_inner")"
printf "\n"
done
printf "协议编号（输入 0 返回）："
IFS= read -r manual_id
[ "$manual_id" = 0 ] && return 2
case "$manual_id" in 3|4|8|13) ;; *) red_line "请输入上方已安装的协议编号。"; return 1 ;; esac
manual_state=$(cloudflare_protocol_state "$manual_id")
manual_rest=${manual_state#*|}; manual_label=${manual_rest%%|*}; manual_rest=${manual_rest#*|}; manual_port_file=${manual_rest%%|*}; manual_path=${manual_rest#*|}
[ -s "$manual_port_file" ] || { red_line "该协议未安装。"; return 1; }
manual_inner=$(cat "$manual_port_file" 2>/dev/null)
manual_expected_origin=$(client_port "$manual_inner")
manual_existing=$(awk -F'|' -v host="$(cat "$HOME/lun/cdnym" 2>/dev/null)" -v id="$manual_id" \
'$1 == host && $2 == id { print $3 "|" $4; exit }' "$(cloudflare_manual_rule_file)" 2>/dev/null)
manual_default_edge=${manual_existing%%|*}
[ "$manual_existing" = "$manual_default_edge" ] && manual_default_edge=
manual_default_origin=${manual_existing#*|}
[ -n "$manual_default_edge" ] || {
if [ "$manual_id" = 13 ]; then manual_default_edge=443
elif { is_cf_http_port "${cdnpt:-}" || is_cf_https_port "${cdnpt:-}"; }; then manual_default_edge=$cdnpt
else manual_default_edge=8080
fi
}
[ -n "$manual_default_origin" ] || manual_default_origin=$manual_expected_origin
printf "Cloudflare 边缘端口（客户端连接，回车默认 %s，0 返回）：" "$manual_default_edge"
IFS= read -r manual_edge
[ "$manual_edge" = 0 ] && return 2
[ -n "$manual_edge" ] || manual_edge=$manual_default_edge
{ is_cf_http_port "$manual_edge" || is_cf_https_port "$manual_edge"; } || { red_line "边缘端口必须是 Cloudflare 官方 HTTP/HTTPS 代理端口。"; return 1; }
if [ "$manual_id" = 13 ] && ! is_cf_https_port "$manual_edge"; then
red_line "VLESS XHTTP TLS 的边缘端口必须使用 Cloudflare HTTPS 端口。"
return 1
fi
printf "Cloudflare 规则中的回源目标端口（Destination port，回车默认 %s，0 返回）：" "$manual_default_origin"
IFS= read -r manual_origin
[ "$manual_origin" = 0 ] && return 2
[ -n "$manual_origin" ] || manual_origin=$manual_default_origin
port_valid "$manual_origin" || { red_line "回源目标端口必须是 1-65535。"; return 1; }
if is_nat_mode; then
manual_mapped_inner=$(inner_port_from_public "$manual_origin")
[ "$manual_mapped_inner" = "$manual_inner" ] || {
red_line "NAT 映射不匹配：公网 $manual_origin 当前没有映射到该协议监听端口 $manual_inner。"
return 1
}
else
[ "$manual_origin" = "$manual_inner" ] || {
red_line "普通 VPS 的回源目标端口必须等于协议监听端口 $manual_inner；当前没有服务监听 $manual_origin。"
return 1
}
fi
cloudflare_save_manual_rule "$manual_id" "$manual_edge" "$manual_origin" || { red_line "手动规则保存失败。"; return 1; }
if [ "$manual_id" = 13 ]; then cloudflare_prepare_rewrite_mode ""; else cloudflare_prepare_rewrite_mode "$manual_edge"; fi
case "$manual_id" in
4|8)
cdnproto=all
printf '%s\n' "$cdnproto" > "$HOME/lun/cdn_protocol"
export cdnproto
;;
esac
CDN_REBUILD_REQUIRED=yes
green_line "已登记：$manual_label，Cloudflare 边缘 $manual_edge → 回源目标 $manual_origin → 本机监听 $manual_inner。"
yellow_line "本操作不调用 Cloudflare API；Lun 将信任你已在控制台设置好的规则，并在重建后直接输出对应节点。"
return 0
}

prompt_origin_rules(){
CDN_REBUILD_REQUIRED=no
load_installed_protocol_flags
cloudflare_reset_protocol_changes
cdn_has_origin_rule_protocol || { yellow_line "Origin Rules 只适用于 3.VLESS XHTTP、4.VLESS WS、8.VMess WS 或 13.VLESS XHTTP TLS TCP/UDP；请先安装其中一项。"; return 1; }
[ -s "$HOME/lun/cdnym" ] || { yellow_line "请先在 CDN / CF 优选中设置 Host。"; return 1; }
while :; do
recommended_edge=$(cdn_recommended_edge_port)
ui_title "Lun Cloudflare Origin Rules 端口回源"
[ -s "$(cloudflare_manual_rule_file)" ] && green_line "手动规则：已登记；可直接生成对应节点，不需要 API Token。"
if [ -s "$(cloudflare_token_file)" ]; then
green_line "Cloudflare API：已授权；输入端口后可直接部署。"
else
yellow_line "Cloudflare API：未授权；手动登记不受影响，自动部署才需要 Token。"
fi
echo " 1. 手动登记已设置的规则（无需 API，已有规则推荐）"
echo " 2. 一键自动部署 / 修复（需要用户 API Token）"
echo " 3. 输入单协议回源端口并自动迁移 / 部署"
echo " 4. 快速验证当前回源（只测首个优选入口）"
echo " 5. 查看精确规则与端口"
echo " 6. 设置 / 更换 Cloudflare 用户 API Token"
echo " 7. 关闭端口改写并清除 Lun 规则状态"
echo " 0. 返回"
printf "请选择 [0-7]："
IFS= read -r choice
case "$choice" in
1) cloudflare_prompt_manual_origin || continue; return 0 ;;
2)
cloudflare_reset_protocol_changes
cloudflare_prepare_rewrite_mode ""
cloudflare_auto_repair_origin_collisions || {
cloudflare_restore_protocol_changes
cloudflare_restore_rewrite_mode
ui_pause
continue
}
cloudflare_finish_auto_deploy "" "" || { ui_pause; continue; }
return 0
;;
3)
echo "可指定回源端口的已安装协议："
for id in 3 4 8 13; do
state=$(cloudflare_protocol_state "$id")
[ -n "$state" ] || continue
rest=${state#*|}; label=${rest%%|*}; rest=${rest#*|}; file=${rest%%|*}
[ -s "$file" ] || continue
inner=$(cat "$file" 2>/dev/null)
printf " %2s. %s：内网 %s" "$id" "$label" "$inner"
is_nat_mode && printf " / 公网 %s" "$(client_port "$inner")"
printf "\n"
done
printf "协议编号（0 返回）："
IFS= read -r origin_id
[ "$origin_id" = 0 ] && continue
case "$origin_id" in 3|4|8|13) ;; *) echo "请输入上方协议编号。"; continue ;; esac
state=$(cloudflare_protocol_state "$origin_id")
rest=${state#*|}; label=${rest%%|*}; rest=${rest#*|}; file=${rest%%|*}
[ -s "$file" ] || { red_line "该协议未安装。"; continue; }
inner=$(cat "$file" 2>/dev/null)
expected_origin=$(client_port "$inner")
printf "%s 回源目标端口（回车自动使用 %s，0 返回）：" "$label" "$expected_origin"
IFS= read -r origin_port
[ "$origin_port" = 0 ] && continue
[ -n "$origin_port" ] || origin_port=$expected_origin
port_valid "$origin_port" || { red_line "端口必须是 1-65535。"; continue; }
cloudflare_reset_protocol_changes
cloudflare_validate_origin_port "$origin_id" "$origin_port" || continue
if [ "$origin_id" = 13 ]; then preferred_edge=443; else preferred_edge=; fi
cloudflare_prepare_rewrite_mode "$preferred_edge"
case "$origin_id" in
4|8)
if [ "$cdnproto" != all ]; then
cdnproto=all
printf '%s\n' "$cdnproto" > "$HOME/lun/cdn_protocol"
CDN_REBUILD_REQUIRED=yes
export cdnproto
fi
;;
esac
cloudflare_finish_auto_deploy "$origin_id" "$origin_port" || { ui_pause; continue; }
return 0
;;
4) diagnose_cdn_endpoints; ui_pause ;;
5) show_cdn_origin_rules; ui_pause ;;
6) cloudflare_prompt_token; ui_pause ;;
7)
if [ -s "$HOME/lun/cdn_cloudflare_state.json" ]; then
if [ -s "$(cloudflare_token_file)" ]; then
cloudflare_origin_api_remove || { ui_pause; continue; }
else
yellow_line "缺少用户 API Token，无法删除云端规则；只清除本机状态，Cloudflare 控制台中的规则请手动删除。"
fi
fi
cdnmode=standard; cdnpt=
printf '%s\n' "$cdnmode" > "$HOME/lun/cdn_mode"
rm -f "$HOME/lun/cdn_edge_port" "$(cloudflare_manual_rule_file)"
CDN_REBUILD_REQUIRED=yes
export cdnmode cdnpt
green_line "已恢复普通同端口 CDN；即将自动重建配置并刷新订阅。"
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
if direct_domain_ip_guard_active "$new_addrmode"; then
yellow_line "该域名同时用于 Cloudflare Origin Rules；直连节点将自动使用源站 IP，TLS SNI/Host 仍保留域名。需要域名直连时，请另设一个 DNS-only 域名。"
fi
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

protocol_route_capabilities(){
case "$1" in
3) echo "直连 / CDN优选 / 端口回源" ;;
4|8) echo "直连 / CDN优选 / 端口回源 / CF隧道" ;;
13) echo "直连 / CDN优选(TCP、UDP需公网443) / 端口回源" ;;
10|11|12) echo "仅直连UDP/QUIC（无CDN、回源、隧道）" ;;
*) echo "仅直连（无CDN、回源、隧道）" ;;
esac
}

protocol_capability_mark(){
id=$1
capability=$2
case "$capability" in
direct) printf '✓' ;;
cdn|origin)
case "$id" in 3|4|8|13) printf '✓' ;; *) printf '—' ;; esac
;;
tunnel)
case "$id" in 4|8) printf '✓' ;; *) printf '—' ;; esac
;;
esac
}

protocol_table_rows(){
printf '编号|状态|协议|监听端口|公网端口|直连|CDN优选|端口回源|CF隧道\n'
for id in 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do
label=$(protocol_label "$id")
port=$(protocol_current_port "$id")
if [ -n "$port" ]; then
status=✓
public=$(client_port "$port")
else
status=—
port=—
public=—
fi
cdn_mark=$(protocol_capability_mark "$id" cdn)
[ "$id" = 13 ] && [ "$cdn_mark" = ✓ ] && cdn_mark='✓*'
printf '%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
"$id" "$status" "$label" "$port" "$public" \
"$(protocol_capability_mark "$id" direct)" "$cdn_mark" \
"$(protocol_capability_mark "$id" origin)" "$(protocol_capability_mark "$id" tunnel)"
done
}

render_protocol_table(){
table_border='+------+------+---------------------------+-------+-------+------+---------+------+--------+'
{
printf '%s\n' "$table_border"
printf '| 编号 | 状态 | 协议                      | 监听  | 公网  | 直连 | CDN优选 | 回源 | CF隧道 |\n'
printf '%s\n' "$table_border"
protocol_table_rows | sed '1d' | while IFS='|' read -r id status label inner public direct cdn origin tunnel; do
case "$status" in ✓) status_cell='✓   ' ;; *) status_cell='—   ' ;; esac
case "$inner" in —) inner='—    ' ;; esac
case "$public" in —) public='—    ' ;; esac
case "$direct" in ✓) direct_cell='✓   ' ;; *) direct_cell='—   ' ;; esac
case "$cdn" in '✓*') cdn_cell='✓*     ' ;; ✓) cdn_cell='✓      ' ;; *) cdn_cell='—      ' ;; esac
case "$origin" in ✓) origin_cell='✓   ' ;; *) origin_cell='—   ' ;; esac
case "$tunnel" in ✓) tunnel_cell='✓     ' ;; *) tunnel_cell='—     ' ;; esac
printf '| %-4s | %s | %-25s | %-5s | %-5s | %s | %s | %s | %s |\n' \
"$id" "$status_cell" "$label" "$inner" "$public" \
"$direct_cell" "$cdn_cell" "$origin_cell" "$tunnel_cell"
done
printf '%s\n' "$table_border"
} | sed "s/✓/${LUN_GREEN}✓${LUN_RESET}/g"
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
render_protocol_table
yellow_line "绿色 ✓ 表示已选择或支持；— 表示未选择或不支持。"
yellow_line "能力：CDN优选=Cloudflare HTTP(S)；端口回源=Origin Rules；CF隧道=当前 Lun 的 WS/Argo。"
yellow_line "* 编号13 的 CDN 优选包含 TCP 与UDP。但是UDP必需献祭本机公网443端口，否则单输出TCP节点。"
}

prompt_protocol_by_id(){
id=$1
label=$(protocol_label "$id")
var=$(protocol_var "$id")
[ -n "$label" ] && [ -n "$var" ] || { echo "忽略未知协议编号：$id"; return 0; }
case "$id" in
3|4|8|13) green_line "$label 能力：$(protocol_route_capabilities "$id")" ;;
*) yellow_line "$label 能力：$(protocol_route_capabilities "$id")" ;;
esac
case "$id" in
10|11|12) yellow_line "$label 使用 UDP/QUIC，请确认公网端口及服务商映射已放行 UDP。" ;;
14) yellow_line "NaiveProxy 必须使用与服务域名匹配的公开可信证书。" ;;
esac
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

guided_progress(){
mode_label="普通 VPS"
is_nat_mode && mode_label="NAT VPS"
proto_total=$(protocol_count)
printf '当前：%s | 已选协议 %s 项 | 域名 %s | 证书 %s' "$mode_label" "$proto_total" "${domain:-未设置}" "${certmode:-未选择}"
if is_nat_mode; then
printf ' | NAT 映射 %s 组' "$(port_map_count "$ptmap")"
fi
printf '\n'
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
[ -n "$ptmap" ] && echo "NAT端口映射：$(port_map_count "$ptmap") 组" || yellow_line "NAT端口映射：未设置（可在入口网络管理中配置）"
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
green_line "已设置为普通 VPS。"
return 0
;;
2)
vpsmode=nat
printf "%s\n" "$vpsmode" > "$HOME/lun/vps_mode"
green_line "已设置为 NAT VPS。"
return 0
;;
*) echo "请输入 1、2 或 0。" ;;
esac
done
}

show_nat_cdn_hint(){
yellow_line "NAT VPS 使用 Cloudflare CDN 时，客户端访问的是公网映射端口；内网监听端口本身不需要属于 CF 端口组。"
yellow_line "操作步骤：先在服务商完成 公网端口→内网监听端口 映射；再到 Cloudflare Origin Rules 选择一键自动部署，Lun 会自动写规则、验证并刷新订阅。"
yellow_line "若没有对应的公网 CF 端口，仍可使用任意公网映射，但必须使用 Origin Rules，不能把内网端口直接写成 CDN 节点端口。"
}

prompt_port_map(){
while :; do
yellow_line "格式：外网端口-内网监听端口，多个用空格分隔，例如：54834-2096 54835-8443"
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
normalized=$(normalize_ptmap "$val") || continue
ptmap="$normalized"
vpsmode=nat
printf "%s\n" "$vpsmode" > "$HOME/lun/vps_mode"
printf "%s\n" "$ptmap" > "$HOME/lun/port_map"
green_line "NAT 端口映射已保存：$(port_map_count "$ptmap") 组"
return 0
done
}

prompt_port_pool(){
while :; do
echo "端口池用于协议端口和节点订阅分享端口随机取值。"
if is_nat_mode; then
yellow_line "内网池是监听端口，外网池是公网入口；范围写成 1000+2000，两组按顺序映射。"
printf "请输入内网端口池；%sdel 清除；回车保留/跳过；0 返回%s%s：" "$LUN_YELLOW" "${inpool:+，当前 $inpool}" "$LUN_RESET"
else
yellow_line "端口池格式：单个端口 8080；连续范围 1000+2000。"
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
guided_progress
prompt_vps_mode
rc=$?
if [ "$rc" = 0 ]; then
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
guided_progress
pick_protocols
rc=$?
[ "$rc" = 0 ] && step=3 && continue
[ "$rc" = 2 ] && step=1 && continue
;;
3)
guided_progress
prompt_service_domain
rc=$?
[ "$rc" = 0 ] && { [ -n "$domain" ] && [ -z "$addym" ] && { addym="$domain"; addout=replace; load_addym_config; }; step=4; continue; }
[ "$rc" = 2 ] && step=2 && continue
;;
4)
guided_progress
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
[ "$rc" = 3 ] && { ui_pause; continue; }
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
multiuser_service_stop
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
printf " 3. %s一键全配置（CDN / 域名证书 / 隧道 / 端口回源）%s\n" "$LUN_GREEN" "$LUN_RESET"
echo " 0. 返回"
printf "请选择 [0-3]："
IFS= read -r c
case "$c" in
1) guided_install; rc=$?; [ "$rc" = 0 ] && { { [ -x "$HOME/lun/xray" ] || [ -x "$HOME/lun/sing-box" ]; } && LUN_MENU_ACTION=rep || LUN_MENU_ACTION=install; return; } ;;
2) pick_protocols; rc=$?; [ "$rc" = 0 ] && LUN_MENU_ACTION=rep || LUN_MENU_ACTION=menu; return ;;
3) oneclick_full_setup; rc=$?; [ "$rc" = 0 ] && LUN_MENU_ACTION=rep || LUN_MENU_ACTION=menu; return ;;
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
echo " 3. 一键优选 CDN 节点（按需下载，浏览器实测）"
echo " 4. Cloudflare Origin Rules（手动登记 / API 自动部署）"
echo " 5. CF 隧道 / Argo（独立链路，不使用 2/4 的设置）"
echo " 6. CDN 连通诊断"
echo " 0. 返回"
printf "请选择 [0-6]："
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
cdnopt_run; rc=$?; [ "$rc" = 2 ] && continue; [ "$rc" = 0 ] || { ui_pause; continue; }
LUN_MENU_ACTION=list
return
;;
4)
prompt_origin_rules; rc=$?; [ "$rc" = 2 ] && continue; [ "$rc" = 0 ] || { ui_pause; continue; }
if [ "$CDN_REBUILD_REQUIRED" = yes ]; then
[ "$CLOUDFLARE_PROTOCOL_PORT_CHANGED" = yes ] || load_installed_protocol_flags
LUN_MENU_ACTION=rep
else
LUN_MENU_ACTION=list
fi
return
;;
5)
argo_network_menu; rc=$?; [ "$rc" = 2 ] && continue
return
;;
6) diagnose_cdn_endpoints; ui_pause ;;
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
echo " 4. 更新本机 Lun 脚本"
echo " 5. 更新 Xray 内核"
echo " 6. 更新 Sing-box 内核"
echo " 0. 返回"
printf "请选择 [0-6]："
IFS= read -r c
case "$c" in
1) LUN_MENU_ACTION=res; return ;;
2) stop_lun_services; echo "已停止 Lun 服务。"; exit ;;
3) log_menu ;;
4) update_lun_script; ui_pause ;;
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

multiuser_install_python(){
command -v python3 >/dev/null 2>&1 && return 0
yellow_line "多用户模块需要 Python 3（仅模块使用），正在安装……"
if command -v apk >/dev/null 2>&1; then
apk add --no-cache python3 >/dev/null 2>&1
elif command -v apt-get >/dev/null 2>&1; then
apt-get update -y >/dev/null 2>&1 && DEBIAN_FRONTEND=noninteractive apt-get install -y python3 >/dev/null 2>&1
else
red_line "当前系统没有 apk/apt-get，请先手动安装 Python 3。"
return 1
fi
command -v python3 >/dev/null 2>&1
}

multiuser_download_agent(){
mu_dir=$(multiuser_module_dir)
mu_target="$mu_dir/lun_agent.py"
mu_tmp="$mu_target.tmp.$$"
mkdir -p "$mu_dir"
rm -f "$mu_tmp"
if [ -n "${LUN_MULTIUSER_AGENT_SOURCE:-}" ] && [ -s "$LUN_MULTIUSER_AGENT_SOURCE" ]; then
cp "$LUN_MULTIUSER_AGENT_SOURCE" "$mu_tmp" || return 1
else
mu_fallback=
if [ -n "${LUN_MULTIUSER_AGENT_URL:-}" ]; then
mu_url=$LUN_MULTIUSER_AGENT_URL
else
mu_url="https://api.github.com/repos/azk78lun-collab/FHLUN/contents/modules/multiuser/lun_agent.py?ref=main&fhlun_nocache=$(date +%s)"
mu_fallback="https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/modules/multiuser/lun_agent.py?fhlun_nocache=$(date +%s)"
fi
if command -v curl >/dev/null 2>&1 && curl -fL -H 'Accept: application/vnd.github.raw+json' -H 'Cache-Control: no-cache' \
--connect-timeout 10 --max-time 120 --retry 2 -o "$mu_tmp" "$mu_url"; then
:
elif command -v wget >/dev/null 2>&1 && wget -O "$mu_tmp" --header='Accept: application/vnd.github.raw+json' \
--header='Cache-Control: no-cache' --tries=2 --timeout=60 "$mu_url"; then
:
elif [ -n "$mu_fallback" ] && command -v curl >/dev/null 2>&1 && curl -fL -H 'Cache-Control: no-cache' \
--connect-timeout 10 --max-time 120 --retry 2 -o "$mu_tmp" "$mu_fallback"; then
:
elif [ -n "$mu_fallback" ] && command -v wget >/dev/null 2>&1 && wget -O "$mu_tmp" \
--header='Cache-Control: no-cache' --tries=2 --timeout=60 "$mu_fallback"; then
:
else
rm -f "$mu_tmp"
return 1
fi
fi
python3 -m py_compile "$mu_tmp" >/dev/null 2>&1 || { rm -f "$mu_tmp"; red_line "下载的多用户代理程序语法校验失败。"; return 1; }
mv -f "$mu_tmp" "$mu_target"
chmod 700 "$mu_target"
cat > "$mu_dir/lun-agent" <<EOF
#!/bin/sh
exec python3 "$mu_target" "\$@"
EOF
chmod 700 "$mu_dir/lun-agent"
}

visit_monitor_prepare(){
[ "$(id -u 2>/dev/null)" = 0 ] || { red_line "网站访问监控安装需要 root。"; return 1; }
{ pidof systemd >/dev/null 2>&1 || command -v rc-service >/dev/null 2>&1; } || {
red_line "网站访问监控只支持 systemd 或 OpenRC。"
return 1
}
[ -s "$HOME/lun/uuid" ] || {
red_line "请先完成至少一个风火轮代理协议安装。"
return 1
}
multiuser_install_python || return 1
if [ ! -x "$(multiuser_agent)" ] || ! "$(multiuser_agent)" --help 2>/dev/null | grep -q 'visit-serve'; then
multiuser_download_agent || { red_line "网站监控程序下载 / 复制失败。"; return 1; }
fi
multiuser_cmd visit-init >/dev/null || return 1
visit_monitor_install_service || return 1
}

visit_monitor_enable(){
visit_was_enabled=no
visit_monitor_enabled && visit_was_enabled=yes
visit_monitor_prepare || return 1
multiuser_cmd backup >/dev/null 2>&1 || true
multiuser_cmd visit-config --enabled yes >/dev/null || return 1
if ! multiuser_cmd visit-apply; then
if [ "$visit_was_enabled" = no ]; then
multiuser_cmd visit-config --enabled no >/dev/null 2>&1 || true
multiuser_cmd visit-apply >/dev/null 2>&1 || true
fi
red_line "网站监控配置未能应用，核心配置已保留 / 回滚。"
return 1
fi
if ! visit_monitor_service_restart; then
if [ "$visit_was_enabled" = no ]; then
multiuser_cmd visit-config --enabled no >/dev/null 2>&1 || true
multiuser_cmd visit-apply >/dev/null 2>&1 || true
fi
red_line "网站监控常驻服务启动失败。"
return 1
fi
green_line "网站访问监控已启用。"
multiuser_cmd visit-status
}

visit_monitor_disable(){
visit_monitor_enabled || { yellow_line "网站访问监控当前未启用。"; return 0; }
visit_monitor_service_stop
multiuser_cmd visit-config --enabled no >/dev/null || return 1
if multiuser_cmd visit-apply; then
yellow_line "网站访问监控已停用；已有记录仍保留。"
return 0
fi
multiuser_cmd visit-config --enabled yes >/dev/null 2>&1 || true
multiuser_cmd visit-apply >/dev/null 2>&1 || true
visit_monitor_service_start >/dev/null 2>&1 || true
red_line "停用时核心配置校验失败，已恢复监控设置。"
return 1
}

visit_monitor_reapply(){
visit_monitor_enabled || return 0
multiuser_cmd visit-apply || return 1
visit_monitor_service_restart
}

multiuser_pick_local_api_port(){
mu_api_start=$1
mu_api_end=$((mu_api_start + 40))
mu_api=$mu_api_start
while [ "$mu_api" -le "$mu_api_end" ]; do
if ! port_in_use "$mu_api" && ! protocol_port_reserved "$mu_api"; then
printf '%s\n' "$mu_api"
return 0
fi
mu_api=$((mu_api + 1))
done
return 1
}

multiuser_prepare_subscription(){
mu_scheme=http
mu_host=
mu_cert_args=
if cert_key_matches "$HOME/lun/cert.crt" "$HOME/lun/private.key" && sync_cert_metadata; then
mu_cert_mode=$(cat "$HOME/lun/cert_mode" 2>/dev/null)
case "$mu_cert_mode" in
ca|domain|dns|ip)
mu_preferred=$(cat "$HOME/lun/domain" 2>/dev/null)
[ -n "$mu_preferred" ] && cert_covers_domain "$HOME/lun/cert.crt" "$mu_preferred" || mu_preferred=$(cat "$HOME/lun/cert_subject" 2>/dev/null)
if [ -n "$mu_preferred" ] && [ "$mu_preferred" != "未知" ] && cert_covers_domain "$HOME/lun/cert.crt" "$mu_preferred"; then
mu_scheme=https
mu_host=$(uri_host "$mu_preferred")
mu_cert_args="--certificate $HOME/lun/cert.crt --private-key $HOME/lun/private.key"
fi
;;
esac
fi
if [ -z "$mu_host" ]; then
mu_host=$(cat "$HOME/lun/domain" 2>/dev/null)
[ -z "$mu_host" ] && mu_host=$(cat "$HOME/lun/addym" 2>/dev/null)
if [ -z "$mu_host" ]; then
v4v6
[ -n "$v4" ] && mu_host=$(uri_host "$v4") || mu_host=$(uri_host "$v6")
fi
fi
[ -n "$mu_host" ] || { red_line "没有可用于订阅输出的域名或公网 IP。"; return 1; }
if [ "$mu_scheme" = http ]; then
red_line "当前没有匹配订阅地址的公开可信证书，多用户订阅只能使用 HTTP。"
yellow_line "已自动使用 HTTP 继续安装；订阅 token 会明文传输，建议稍后申请域名证书升级 HTTPS。"
else
green_line "检测到公开可信证书，多用户订阅将使用 HTTPS。"
fi
mu_sub_requested=$(cat "$HOME/lun/subport.log" 2>/dev/null)
mu_legacy_http_internal=0
mu_legacy_http_public=0
if [ "$mu_scheme" = https ] && [ -n "$mu_sub_requested" ]; then
mu_legacy_http_internal=$mu_sub_requested
mu_legacy_http_public=$(client_port "$mu_legacy_http_internal")
multiuser_legacy_subport=$mu_legacy_http_internal
mu_sub_internal=$(select_subscription_port "") || { multiuser_legacy_subport=; return 1; }
multiuser_legacy_subport=
[ "$mu_sub_internal" != "$mu_legacy_http_internal" ] || { red_line "HTTPS 订阅没有取得第二个空闲端口。"; return 1; }
printf '%s\n' "$mu_legacy_http_internal" > "$HOME/lun/subport_legacy.log"
else
mu_sub_internal=$(select_subscription_port "$mu_sub_requested") || return 1
fi
mu_sub_public=$(client_port "$mu_sub_internal")
if is_nat_mode && [ "$mu_sub_public" = "$mu_sub_internal" ]; then
red_line "NAT VPS 没有为订阅内网端口 $mu_sub_internal 配置公网映射。"
yellow_line "请先在入口网络管理增加一组 公网端口-$mu_sub_internal，再安装多用户模块。"
return 1
fi
printf '%s\n' "$mu_sub_internal" > "$HOME/lun/subport.log"
return 0
}

multiuser_config_value(){
mu_config_key=$1
python3 - "$(multiuser_module_dir)/config.json" "$mu_config_key" <<'PY'
import json, sys
try:
    print(json.load(open(sys.argv[1], encoding="utf-8")).get(sys.argv[2], ""))
except (OSError, ValueError):
    pass
PY
}

multiuser_restore_legacy_subscription_port(){
if [ -s "$HOME/lun/subport_legacy.log" ]; then
cp -p "$HOME/lun/subport_legacy.log" "$HOME/lun/subport.log"
fi
}

multiuser_abort_install(){
mu_abort_dir=$(multiuser_module_dir)
multiuser_service_stop
if [ -s "$mu_abort_dir/backups/preinstall-xr.json" ]; then
cp -p "$mu_abort_dir/backups/preinstall-xr.json" "$HOME/lun/xr.json"
xrestart
fi
if [ -s "$mu_abort_dir/backups/preinstall-sb.json" ]; then
cp -p "$mu_abort_dir/backups/preinstall-sb.json" "$HOME/lun/sb.json"
sbrestart
fi
[ -x "$mu_abort_dir/lun-agent" ] && "$mu_abort_dir/lun-agent" --root "$HOME/lun" set-module --enabled no >/dev/null 2>&1 || true
multiuser_remove_service
multiuser_restore_legacy_subscription_port
if [ "${multiuser_had_visit:-no}" = yes ]; then
rm -f "$mu_abort_dir/config.json" "$mu_abort_dir/lun-sb-stats"
rm -rf "$mu_abort_dir/generated"
else
rm -rf "$mu_abort_dir"
fi
restart_subscription_service >/dev/null 2>&1 || true
visit_monitor_service_start >/dev/null 2>&1 || true
}

multiuser_install(){
[ "$(id -u 2>/dev/null)" = 0 ] || { red_line "多用户模块安装需要 root。"; return 1; }
{ pidof systemd >/dev/null 2>&1 || command -v rc-service >/dev/null 2>&1; } || {
red_line "多用户模块只支持 systemd 或 OpenRC；当前无 init 模式已拒绝安装。"
return 1
}
[ -s "$HOME/lun/uuid" ] || { red_line "请先完成至少一个风火轮协议安装。"; return 1; }
multiuser_had_visit=no
visit_monitor_enabled && multiuser_had_visit=yes
visit_monitor_service_stop
multiuser_install_python || return 1
multiuser_download_agent || { red_line "多用户代理程序下载/复制失败。"; multiuser_abort_install; return 1; }
multiuser_prepare_subscription || { multiuser_abort_install; return 1; }

mu_xapi_port=$(multiuser_pick_local_api_port 10085) || { red_line "无法分配 Xray 本机 API 端口。"; multiuser_abort_install; return 1; }
mu_sapi_port=$(multiuser_pick_local_api_port $((mu_xapi_port + 1))) || { red_line "无法分配 Sing-box 本机 API 端口。"; multiuser_abort_install; return 1; }
mu_ss_port=0
mu_ss_public=0
if grep -q '"tag":"ss-2022"' "$HOME/lun/sb.json" 2>/dev/null; then
if mu_ss_port=$(random_nat_port 2>/dev/null); then
mu_ss_public=$(client_port "$mu_ss_port")
green_line "Shadowsocks-2022 多用户端口已自动分配：内网 $mu_ss_port / 公网 $mu_ss_public。"
else
mu_ss_port=0
mu_ss_public=0
yellow_line "没有空闲 NAT 映射，已跳过 Shadowsocks-2022 多用户节点；其他协议继续安装，原 Shadowsocks 不受影响。"
fi
fi

mu_dir=$(multiuser_module_dir)
mkdir -p "$mu_dir/backups"
[ -s "$HOME/lun/xr.json" ] && cp -p "$HOME/lun/xr.json" "$mu_dir/backups/preinstall-xr.json"
[ -s "$HOME/lun/sb.json" ] && cp -p "$HOME/lun/sb.json" "$mu_dir/backups/preinstall-sb.json"
stop_subscription_service
multiuser_service_stop
set -- --port "$mu_sub_internal" --public-port "$mu_sub_public" --scheme "$mu_scheme" --public-host "$mu_host" \
--xray-api "127.0.0.1:$mu_xapi_port" --singbox-api "127.0.0.1:$mu_sapi_port" \
--ss-port "$mu_ss_port" --ss-public-port "$mu_ss_public" \
--legacy-http-port "$mu_legacy_http_internal" --legacy-http-public-port "$mu_legacy_http_public"
if [ -n "$mu_cert_args" ]; then
set -- "$@" --certificate "$HOME/lun/cert.crt" --private-key "$HOME/lun/private.key"
fi
if ! multiuser_cmd init "$@"; then
red_line "多用户数据库初始化失败。"
multiuser_abort_install
return 1
fi
if ! multiuser_cmd apply; then
red_line "多用户配置校验或应用失败，正在恢复安装前核心配置。"
multiuser_abort_install
return 1
fi
multiuser_install_service || { multiuser_abort_install; return 1; }
multiuser_service_start || { multiuser_abort_install; return 1; }
visit_monitor_service_start || true
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/weblun/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1 || true
rm -f /tmp/crontab.tmp /etc/local.d/alpinesublun.start
apply_lun_firewall_rules || true
green_line "多用户模块安装完成；旧用户、旧 UUID、旧订阅 token 与旧 Shadowsocks 端口均已保留。"
[ "$mu_scheme" = http ] && yellow_line "当前设备订阅使用 HTTP；节点协议本身不受影响，申请公开可信证书后可升级 HTTPS。"
[ "$mu_legacy_http_internal" -gt 0 ] 2>/dev/null && yellow_line "旧 token 继续使用原 HTTP 端口：内网 $mu_legacy_http_internal / 公网 $mu_legacy_http_public；新设备使用 HTTPS 端口 $mu_sub_public。"
[ "$mu_ss_port" -gt 0 ] 2>/dev/null && green_line "Shadowsocks 多用户并行端口：内网 $mu_ss_port / 公网 $mu_ss_public。"
multiuser_cmd doctor
}

multiuser_apply_changes(){
multiuser_service_stop
if multiuser_cmd apply; then
multiuser_service_start || true
green_line "多用户配置已校验并生效。"
if cluster_enabled && [ "$(cluster_role 2>/dev/null)" = master ]; then
yellow_line "正在同步已授权子 VPS 的用户与订阅……"
cluster_cmd sync-users || yellow_line "本机已生效，但至少一台子 VPS 暂未同步。"
fi
return 0
fi
multiuser_service_start || true
red_line "应用失败；核心校验未通过，请运行诊断。"
return 1
}

multiuser_transaction(){
multiuser_cmd backup >/dev/null 2>&1 || { red_line "无法创建操作前数据库快照。"; return 1; }
mu_snapshot=$(ls -1t "$(multiuser_module_dir)"/backups/db-*.sqlite3 2>/dev/null | head -n 1)
[ -n "$mu_snapshot" ] || { red_line "没有找到操作前数据库快照。"; return 1; }
multiuser_cmd "$@" || return 1
multiuser_apply_changes && return 0
yellow_line "正在恢复本次操作前的数据库与核心配置……"
multiuser_service_stop
if multiuser_cmd restore-database --path "$mu_snapshot" >/dev/null 2>&1 && multiuser_cmd apply >/dev/null 2>&1; then
multiuser_service_start || true
green_line "本次操作已完整回滚。"
else
multiuser_service_start || true
red_line "自动回滚未完成，请立即运行 多用户管理 → 备份/诊断。"
fi
return 1
}

multiuser_quota_g(){
mu_quota_value=$1
case "$mu_quota_value" in
""|0) printf '0\n' ;;
*[!0-9.]*) printf '%s\n' "$mu_quota_value" ;;
*) printf '%sG\n' "$mu_quota_value" ;;
esac
}

multiuser_add_user_ui(){
ui_title "Lun 新增用户"
printf "用户名称（唯一，输入 0 返回）："
IFS= read -r mu_name
[ "$mu_name" = 0 ] && return
[ -n "$mu_name" ] || { red_line "用户名称不能为空。"; return; }
mu_lifetime=0
printf "每月额度（只输入数字按 G 计算，0/回车不限）："
IFS= read -r mu_monthly
[ -n "$mu_monthly" ] || mu_monthly=0
mu_monthly=$(multiuser_quota_g "$mu_monthly")
printf "每月重置日 [1-28，默认 1]："
IFS= read -r mu_reset
[ -n "$mu_reset" ] || mu_reset=1
printf "到期日 [YYYY-MM-DD，回车永久]："
IFS= read -r mu_expire
[ -n "$mu_expire" ] || mu_expire=never
printf "最大设备数 [默认 3]："
IFS= read -r mu_max
[ -n "$mu_max" ] || mu_max=3
printf "首台设备名称 [默认 device-1]："
IFS= read -r mu_device
[ -n "$mu_device" ] || mu_device=device-1
if multiuser_transaction add-user --name "$mu_name" --lifetime-quota "$mu_lifetime" --monthly-quota "$mu_monthly" \
--reset-day "$mu_reset" --expires "$mu_expire" --max-devices "$mu_max" --device-name "$mu_device"; then
green_line "用户与首台设备已创建。"
fi
ui_pause
}

multiuser_device_ui(){
ui_title "Lun 用户 / 设备凭据"
multiuser_cmd list-users
printf "输入用户 ID（输入 0 返回）："
IFS= read -r mu_uid
[ "$mu_uid" = 0 ] && return
multiuser_cmd show-user --user-id "$mu_uid" || { ui_pause; return; }
echo " 1. 新增设备"
echo " 2. 重命名设备"
echo " 3. 启用设备"
echo " 4. 停用设备"
echo " 5. 轮换设备全部凭据"
echo " 6. 硬删除设备"
echo " 7. 再次查看凭据"
echo " 0. 返回"
printf "请选择（输入 0 返回）："
IFS= read -r mu_choice
case "$mu_choice" in
1)
printf "设备名称："
IFS= read -r mu_device
[ -n "$mu_device" ] && multiuser_transaction add-device --user-id "$mu_uid" --name "$mu_device"
;;
2)
printf "设备 ID（输入 0 返回）："; IFS= read -r mu_did
[ "$mu_did" = 0 ] && return
printf "新设备名称："; IFS= read -r mu_device
[ -n "$mu_device" ] && multiuser_transaction update-device --device-id "$mu_did" --name "$mu_device"
;;
3) printf "设备 ID（输入 0 返回）："; IFS= read -r mu_did; [ "$mu_did" = 0 ] && return; multiuser_transaction update-device --device-id "$mu_did" --enable ;;
4) printf "设备 ID（输入 0 返回）："; IFS= read -r mu_did; [ "$mu_did" = 0 ] && return; multiuser_transaction update-device --device-id "$mu_did" --disable ;;
5)
printf "设备 ID（输入 0 返回）："; IFS= read -r mu_did
[ "$mu_did" = 0 ] && return
printf "%s轮换会立即撤销旧 UUID、密码、SS 密钥和订阅 token。请输入设备名称确认：%s" "$LUN_RED" "$LUN_RESET"
IFS= read -r mu_confirm
multiuser_cmd rotate-device --device-id "$mu_did" --confirm "$mu_confirm" && multiuser_apply_changes
;;
6)
printf "设备 ID（输入 0 返回）："; IFS= read -r mu_did
[ "$mu_did" = 0 ] && return
printf "%s硬删除会清除该设备凭据、订阅及含旧凭据的自动备份。请输入设备名称确认：%s" "$LUN_RED" "$LUN_RESET"
IFS= read -r mu_confirm
multiuser_cmd delete-device --device-id "$mu_did" --confirm "$mu_confirm" && multiuser_apply_changes
;;
7) multiuser_cmd show-user --user-id "$mu_uid" ;;
esac
ui_pause
}

multiuser_policy_ui(){
ui_title "Lun 月额度 / 到期 / 停用"
multiuser_cmd list-users
printf "输入用户 ID（输入 0 返回）："
IFS= read -r mu_uid
[ "$mu_uid" = 0 ] && return
echo " 1. 修改每月额度与重置日"
echo " 2. 修改到期日"
echo " 3. 修改最大设备数"
echo " 4. 启用用户"
echo " 5. 停用用户"
echo " 6. 硬删除用户"
echo " 0. 返回"
printf "请选择（输入 0 返回）："
IFS= read -r mu_choice
case "$mu_choice" in
1)
printf "每月额度（只输入数字按 G 计算，0 不限）："; IFS= read -r mu_monthly
mu_monthly=$(multiuser_quota_g "$mu_monthly")
printf "每月重置日 [1-28]："; IFS= read -r mu_reset
[ -n "$mu_reset" ] || mu_reset=1
multiuser_transaction update-user --user-id "$mu_uid" --lifetime-quota 0 --monthly-quota "$mu_monthly" --reset-day "$mu_reset"
;;
2) printf "到期日 [YYYY-MM-DD/never]："; IFS= read -r mu_expire; multiuser_transaction update-user --user-id "$mu_uid" --expires "$mu_expire" ;;
3) printf "最大设备数 [1-64]："; IFS= read -r mu_max; multiuser_transaction update-user --user-id "$mu_uid" --max-devices "$mu_max" ;;
4) multiuser_transaction update-user --user-id "$mu_uid" --enable ;;
5) multiuser_transaction update-user --user-id "$mu_uid" --disable ;;
6)
printf "%s硬删除会撤销所有凭据、订阅和含该用户的自动数据库备份。%s\n" "$LUN_RED" "$LUN_RESET"
printf "请输入用户名称确认："
IFS= read -r mu_confirm
multiuser_cmd delete-user --user-id "$mu_uid" --confirm "$mu_confirm" && multiuser_apply_changes
;;
0|"") return ;;
*) echo "已取消。" ;;
esac
ui_pause
}

multiuser_protocol_ui(){
ui_title "Lun 用户协议权限 / 安全策略"
multiuser_cmd list-users
printf "输入用户 ID（输入 0 返回）："
IFS= read -r mu_uid
[ "$mu_uid" = 0 ] && return
echo "协议：vl xh vx vw ss an ar vm so hy tu xu xc nv"
printf "输入协议代码（输入 0 返回）："
IFS= read -r mu_protocol
[ "$mu_protocol" = 0 ] && return
printf "启用该协议？[y/N]："
IFS= read -r mu_enable
case "$mu_enable" in y|Y|yes|YES) mu_enable=yes ;; *) mu_enable=no ;; esac
multiuser_transaction set-protocol --user-id "$mu_uid" --protocol "$mu_protocol" --enabled "$mu_enable"
yellow_line "固定安全策略：阻断私网/链路本地/云元数据和 TCP 25；TCP 465/587 保持允许。"
ui_pause
}

multiuser_bandwidth_runner(){
printf '%s\n' "$(multiuser_module_dir)/fair-bandwidth.sh"
}

multiuser_bandwidth_config(){
printf '%s\n' "$(multiuser_module_dir)/bandwidth.conf"
}

multiuser_install_tc(){
command -v tc >/dev/null 2>&1 && command -v ip >/dev/null 2>&1 && return 0
yellow_line "动态公平带宽需要 iproute2，正在安装……"
if command -v apt-get >/dev/null 2>&1; then
apt-get update -y >/dev/null 2>&1 && DEBIAN_FRONTEND=noninteractive apt-get install -y iproute2 >/dev/null 2>&1
elif command -v apk >/dev/null 2>&1; then
apk add --no-cache iproute2 >/dev/null 2>&1
elif command -v dnf >/dev/null 2>&1; then
dnf install -y iproute >/dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
yum install -y iproute >/dev/null 2>&1
else
return 1
fi
command -v tc >/dev/null 2>&1 && command -v ip >/dev/null 2>&1
}

multiuser_bandwidth_write_runner(){
mu_bw_runner=$(multiuser_bandwidth_runner)
mu_bw_config=$(multiuser_bandwidth_config)
cat > "$mu_bw_runner" <<EOF
#!/bin/sh
set -u
CONFIG="$mu_bw_config"
[ -r "\$CONFIG" ] || { echo "动态公平带宽配置不存在" >&2; exit 1; }
. "\$CONFIG"
case "\${RATE_MBIT:-}" in ''|*[!0-9]*) echo "总带宽必须是整数 Mbit/s" >&2; exit 1 ;; esac
[ "\$RATE_MBIT" -ge 1 ] 2>/dev/null && [ "\$RATE_MBIT" -le 100000 ] 2>/dev/null || { echo "总带宽范围应为 1-100000 Mbit/s" >&2; exit 1; }
IFACE=\${INTERFACE:-auto}
if [ "\$IFACE" = auto ]; then
IFACE=\$(ip -4 route show default 2>/dev/null | awk '/ dev / {for(i=1;i<=NF;i++) if(\$i=="dev"){print \$(i+1); exit}}')
[ -n "\$IFACE" ] || IFACE=\$(ip -6 route show default 2>/dev/null | awk '/ dev / {for(i=1;i<=NF;i++) if(\$i=="dev"){print \$(i+1); exit}}')
fi
case "\$IFACE" in ''|*[!A-Za-z0-9_.:-]*) echo "无法识别出口网卡" >&2; exit 1 ;; esac
ip link show dev "\$IFACE" >/dev/null 2>&1 || { echo "出口网卡不存在：\$IFACE" >&2; exit 1; }
MODE_FILE="\${CONFIG}.mode"
case "\${1:-status}" in
apply)
modprobe sch_cake >/dev/null 2>&1 || true
if tc qdisc replace dev "\$IFACE" root cake bandwidth "\${RATE_MBIT}mbit" besteffort dual-dsthost 2>/dev/null; then
printf '%s\n' cake > "\$MODE_FILE"
echo "已启用 CAKE：\$IFACE / \${RATE_MBIT} Mbit/s"
exit 0
fi
tc qdisc del dev "\$IFACE" root >/dev/null 2>&1 || true
if tc qdisc add dev "\$IFACE" root handle 1: htb default 10 2>/dev/null && \
tc class add dev "\$IFACE" parent 1: classid 1:10 htb rate "\${RATE_MBIT}mbit" ceil "\${RATE_MBIT}mbit" 2>/dev/null && \
tc qdisc add dev "\$IFACE" parent 1:10 handle 10: fq_codel 2>/dev/null; then
printf '%s\n' htb-fq_codel > "\$MODE_FILE"
echo "已启用 HTB + FQ-CoDel：\$IFACE / \${RATE_MBIT} Mbit/s"
exit 0
fi
tc qdisc del dev "\$IFACE" root >/dev/null 2>&1 || true
rm -f "\$MODE_FILE"
echo "CAKE 与 HTB + FQ-CoDel 均启用失败，已恢复系统默认队列" >&2
exit 1
;;
clear)
tc qdisc del dev "\$IFACE" root >/dev/null 2>&1 || true
rm -f "\$MODE_FILE"
echo "动态公平带宽已关闭：\$IFACE"
;;
status)
echo "出口网卡：\$IFACE"
echo "总下载上限：\$RATE_MBIT Mbit/s"
if command -v python3 >/dev/null 2>&1 && tc -j -s qdisc show dev "\$IFACE" >/dev/null 2>&1; then
tc -j -s qdisc show dev "\$IFACE" | python3 -c '
import json, sys
items = json.load(sys.stdin)
root = next((item for item in items if item.get("root")), items[0] if items else {})
kind = root.get("kind", "")
labels = {
    "cake": "CAKE 公平队列（已启用）",
    "htb": "HTB 总量整形 + FQ-CoDel 公平队列（已启用）",
    "fq_codel": "系统默认 FQ-CoDel（动态公平带宽未启用）",
}
print("调度算法：" + labels.get(kind, "未启用或无法识别"))
print("累计发送：{} 字节 / {} 个数据包".format(int(root.get("bytes", 0)), int(root.get("packets", 0))))
print("丢弃数据包：{}".format(int(root.get("drops", 0))))
print("触发带宽整形：{} 次".format(int(root.get("overlimits", 0))))
print("当前排队：{} 字节".format(int(root.get("backlog", 0))))
' 2>/dev/null || echo "调度状态：暂时无法读取"
else
echo "调度状态：当前系统不支持中文统计解析"
fi
;;
*) echo "用法：\$0 apply|clear|status" >&2; exit 2 ;;
esac
EOF
chmod 700 "$mu_bw_runner"
}

multiuser_bandwidth_install_service(){
mu_bw_runner=$(multiuser_bandwidth_runner)
if pidof systemd >/dev/null 2>&1; then
cat > /etc/systemd/system/lun-fair-bandwidth.service <<EOF
[Unit]
Description=风火轮动态公平下载带宽
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$mu_bw_runner apply
ExecStop=$mu_bw_runner clear

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >/dev/null 2>&1
elif command -v rc-service >/dev/null 2>&1; then
cat > /etc/init.d/lun-fair-bandwidth <<EOF
#!/sbin/openrc-run
description="风火轮动态公平下载带宽"
depend() { need net; }
start() { ebegin "启动风火轮动态公平带宽"; $mu_bw_runner apply; eend \$?; }
stop() { ebegin "关闭风火轮动态公平带宽"; $mu_bw_runner clear; eend \$?; }
EOF
chmod +x /etc/init.d/lun-fair-bandwidth
else
red_line "动态公平带宽要求 systemd 或 OpenRC。"
return 1
fi
}

multiuser_bandwidth_enable(){
multiuser_install_tc || { red_line "iproute2 安装失败，无法启用真实带宽调度。"; return 1; }
mu_bw_old_rate=
mu_bw_old_iface=auto
mu_bw_config=$(multiuser_bandwidth_config)
if [ -r "$mu_bw_config" ]; then
mu_bw_old_rate=$(sed -n 's/^RATE_MBIT=//p' "$mu_bw_config" | head -n 1)
mu_bw_old_iface=$(sed -n 's/^INTERFACE=//p' "$mu_bw_config" | head -n 1)
fi
[ -n "$mu_bw_old_rate" ] || mu_bw_old_rate=1000
[ -n "$mu_bw_old_iface" ] || mu_bw_old_iface=auto
yellow_line "这是全机下载出口公平调度，不是严格的单用户限速。"
echo "总上限建议填写服务器实测下载出口的 90%-95%。"
printf "总下载带宽上限 Mbit/s [默认 %s]：" "$mu_bw_old_rate"
IFS= read -r mu_bw_rate
[ -n "$mu_bw_rate" ] || mu_bw_rate=$mu_bw_old_rate
case "$mu_bw_rate" in *[!0-9]*|"") red_line "请输入整数 Mbit/s。"; return 1 ;; esac
[ "$mu_bw_rate" -ge 1 ] 2>/dev/null && [ "$mu_bw_rate" -le 100000 ] 2>/dev/null || { red_line "范围应为 1-100000 Mbit/s。"; return 1; }
printf "出口网卡 [默认 %s，auto 自动识别]：" "$mu_bw_old_iface"
IFS= read -r mu_bw_iface
[ -n "$mu_bw_iface" ] || mu_bw_iface=$mu_bw_old_iface
case "$mu_bw_iface" in *[!A-Za-z0-9_.:-]*|"") red_line "出口网卡名称无效。"; return 1 ;; esac
cat > "$mu_bw_config" <<EOF
RATE_MBIT=$mu_bw_rate
INTERFACE=$mu_bw_iface
EOF
chmod 600 "$mu_bw_config"
multiuser_bandwidth_write_runner || return 1
multiuser_bandwidth_install_service || return 1
if pidof systemd >/dev/null 2>&1; then
systemctl enable lun-fair-bandwidth >/dev/null 2>&1
systemctl restart lun-fair-bandwidth || { red_line "动态公平带宽启动失败，已恢复系统默认队列。"; return 1; }
else
rc-update add lun-fair-bandwidth default >/dev/null 2>&1 || true
rc-service lun-fair-bandwidth restart || { red_line "动态公平带宽启动失败，已恢复系统默认队列。"; return 1; }
fi
green_line "动态公平带宽已启用：全机下载上限 ${mu_bw_rate} Mbit/s，空闲连接可借用剩余带宽。"
}

multiuser_bandwidth_disable(){
mu_bw_runner=$(multiuser_bandwidth_runner)
if pidof systemd >/dev/null 2>&1; then
systemctl disable --now lun-fair-bandwidth >/dev/null 2>&1 || true
elif command -v rc-service >/dev/null 2>&1; then
rc-service lun-fair-bandwidth stop >/dev/null 2>&1 || true
rc-update del lun-fair-bandwidth default >/dev/null 2>&1 || true
fi
[ -x "$mu_bw_runner" ] && "$mu_bw_runner" clear >/dev/null 2>&1 || true
green_line "动态公平带宽已关闭，出口队列已恢复系统默认设置。"
}

multiuser_bandwidth_remove(){
multiuser_bandwidth_disable >/dev/null 2>&1 || true
rm -f /etc/systemd/system/lun-fair-bandwidth.service /etc/init.d/lun-fair-bandwidth
pidof systemd >/dev/null 2>&1 && systemctl daemon-reload >/dev/null 2>&1 || true
rm -f "$(multiuser_bandwidth_runner)" "$(multiuser_bandwidth_config)" "$(multiuser_bandwidth_config).mode"
}

multiuser_bandwidth_ui(){
while :; do
ui_title "Lun 动态公平带宽"
echo "按全机下载出口公平分配：人少时可使用更多，繁忙时活跃连接自动均分。"
mu_bw_runner=$(multiuser_bandwidth_runner)
if [ -x "$mu_bw_runner" ] && [ -r "$(multiuser_bandwidth_config)" ]; then
"$mu_bw_runner" status 2>/dev/null || echo "当前：配置存在，但尚未启用。"
else
echo "当前：未配置"
fi
echo " 1. 启用 / 修改总下载带宽"
echo " 2. 刷新调度状态与统计"
echo " 3. 关闭动态公平带宽"
echo " 0. 返回"
printf "请选择 [0-3]（输入 0 返回）："
IFS= read -r mu_choice
case "$mu_choice" in
1) multiuser_bandwidth_enable; ui_pause ;;
2) [ -x "$mu_bw_runner" ] && "$mu_bw_runner" status || echo "尚未配置。"; ui_pause ;;
3) multiuser_bandwidth_disable; ui_pause ;;
0|"") return ;;
*) echo "输入错误。" ;;
esac
done
}

multiuser_install_enhanced_singbox(){
[ -x "$HOME/lun/sing-box" ] || { red_line "Sing-box 未安装。"; return 1; }
if "$HOME/lun/sing-box" version 2>/dev/null | grep -q with_v2ray_api; then
green_line "当前 Sing-box 已支持按用户统计流量。"
return 0
fi
mu_sb_tmp="$HOME/lun/sing-box.multiuser.tmp.$$"
mu_helper_tmp="$(multiuser_module_dir)/lun-sb-stats.tmp.$$"
mu_sb_url="https://github.com/azk78lun-collab/FHLUN/releases/download/lun/sing-box-multiuser-$cpu"
mu_helper_url="https://github.com/azk78lun-collab/FHLUN/releases/download/lun/lun-sb-stats-$cpu"
download_core_asset "sing-box-multiuser-$cpu" "$mu_sb_tmp" "$mu_sb_url" || return 1
download_core_asset "lun-sb-stats-$cpu" "$mu_helper_tmp" "$mu_helper_url" || { rm -f "$mu_sb_tmp"; return 1; }
chmod +x "$mu_sb_tmp"
chmod 700 "$mu_helper_tmp"
if ! "$mu_sb_tmp" version 2>/dev/null | grep -q with_v2ray_api; then
rm -f "$mu_sb_tmp" "$mu_helper_tmp"
red_line "下载的 Sing-box 不支持按用户统计流量，已拒绝替换。"
return 1
fi
"$mu_helper_tmp" --help >/dev/null 2>&1 || { rm -f "$mu_sb_tmp" "$mu_helper_tmp"; red_line "Sing-box 统计辅助程序校验失败。"; return 1; }
cp -p "$HOME/lun/sing-box" "$HOME/lun/sing-box.pre-multiuser"
[ -s "$(multiuser_module_dir)/lun-sb-stats" ] && cp -p "$(multiuser_module_dir)/lun-sb-stats" "$(multiuser_module_dir)/lun-sb-stats.pre-multiuser"
mv -f "$mu_sb_tmp" "$HOME/lun/sing-box"
mv -f "$mu_helper_tmp" "$(multiuser_module_dir)/lun-sb-stats"
if ! multiuser_apply_changes; then
mv -f "$HOME/lun/sing-box.pre-multiuser" "$HOME/lun/sing-box"
if [ -s "$(multiuser_module_dir)/lun-sb-stats.pre-multiuser" ]; then
mv -f "$(multiuser_module_dir)/lun-sb-stats.pre-multiuser" "$(multiuser_module_dir)/lun-sb-stats"
else
rm -f "$(multiuser_module_dir)/lun-sb-stats"
fi
sbrestart
return 1
fi
rm -f "$(multiuser_module_dir)/lun-sb-stats.pre-multiuser"
green_line "Sing-box 增强内核安装完成；协议版本不变，已增加用户统计能力。"
}

multiuser_visit_refresh(){
multiuser_cmd visit-collect >/dev/null 2>&1 || true
}

multiuser_visit_filter_ui(){
echo "查看方式：1. 智能活动（过滤并合并）  2. 原始连接明细"
printf "请选择 [默认 1，输入 0 返回]："
IFS= read -r mu_visit_view
[ "$mu_visit_view" = 0 ] && return
case "$mu_visit_view" in
""|1) mu_visit_view=smart; mu_visit_noise=auto ;;
2) mu_visit_view=raw; mu_visit_noise=show ;;
*) red_line "请输入 1 或 2。"; return ;;
esac
printf "查看最近几天 [默认 7，输入 0 返回]："
IFS= read -r mu_visit_days
[ "$mu_visit_days" = 0 ] && return
[ -n "$mu_visit_days" ] || mu_visit_days=7
case "$mu_visit_days" in *[!0-9]*) red_line "天数必须是整数。"; return ;; esac
printf "用户 ID [回车全部，输入 0 返回]："
IFS= read -r mu_visit_uid
[ "$mu_visit_uid" = 0 ] && return
case "$mu_visit_uid" in ""|*[!0-9]*) [ -z "$mu_visit_uid" ] || { red_line "用户 ID 必须是整数。"; return; } ;; esac
printf "设备 ID [回车全部，输入 0 返回]："
IFS= read -r mu_visit_did
[ "$mu_visit_did" = 0 ] && return
case "$mu_visit_did" in ""|*[!0-9]*) [ -z "$mu_visit_did" ] || { red_line "设备 ID 必须是整数。"; return; } ;; esac
printf "域名关键字 [回车全部，输入 0 返回]："
IFS= read -r mu_visit_domain
[ "$mu_visit_domain" = 0 ] && return
set -- visit-recent --days "$mu_visit_days" --limit 100 --view "$mu_visit_view" --noise "$mu_visit_noise"
[ -n "$mu_visit_uid" ] && set -- "$@" --user-id "$mu_visit_uid"
[ -n "$mu_visit_did" ] && set -- "$@" --device-id "$mu_visit_did"
[ -n "$mu_visit_domain" ] && set -- "$@" --domain "$mu_visit_domain"
multiuser_visit_refresh
multiuser_cmd "$@"
ui_pause
}

visit_monitor_filter_ui(){
while :; do
ui_title "网站监控过滤与合并设置"
multiuser_cmd visit-filter
echo " 1. 使用标准过滤（推荐）"
echo " 2. 关闭过滤"
echo " 3. 修改活动合并分钟数"
echo " 4. 添加自定义隐藏域名"
echo " 5. 删除自定义隐藏域名"
echo " 6. 添加始终显示域名"
echo " 7. 删除始终显示域名"
echo " 8. 清空自定义规则并恢复默认"
echo " 0. 返回"
printf "请选择 [0-8]（输入 0 返回）："
IFS= read -r visit_filter_choice
case "$visit_filter_choice" in
1) multiuser_cmd visit-filter --mode standard ;;
2) multiuser_cmd visit-filter --mode off ;;
3)
printf "同一设备、域名和端口的合并窗口 [1-60 分钟，输入 0 返回]："
IFS= read -r visit_merge_minutes
[ "$visit_merge_minutes" = 0 ] && continue
case "$visit_merge_minutes" in
""|*[!0-9]*) red_line "合并窗口必须是 1-60 的整数。"; ui_pause; continue ;;
esac
if [ "$visit_merge_minutes" -lt 1 ] || [ "$visit_merge_minutes" -gt 60 ]; then
red_line "合并窗口必须是 1-60 分钟。"
ui_pause
continue
fi
multiuser_cmd visit-filter --merge-minutes "$visit_merge_minutes"
;;
4|5|6|7)
printf "输入完整域名（输入 0 返回）："
IFS= read -r visit_filter_domain
[ "$visit_filter_domain" = 0 ] && continue
[ -n "$visit_filter_domain" ] || { red_line "域名不能为空。"; ui_pause; continue; }
case "$visit_filter_choice" in
4) visit_filter_action=add-hide ;;
5) visit_filter_action=remove-hide ;;
6) visit_filter_action=add-show ;;
7) visit_filter_action=remove-show ;;
esac
multiuser_cmd visit-filter --action "$visit_filter_action" --domain "$visit_filter_domain"
;;
8)
printf "输入 RESET 清空自定义隐藏/显示规则（输入 0 返回）："
IFS= read -r visit_filter_reset
[ "$visit_filter_reset" = 0 ] && continue
[ "$visit_filter_reset" = RESET ] && multiuser_cmd visit-filter --action reset || red_line "未输入 RESET，设置未变更。"
;;
0|"") return ;;
*) echo "输入错误。" ;;
esac
ui_pause
done
}

visit_monitor_status_ui(){
if [ ! -x "$(multiuser_agent)" ]; then
echo "监控状态：尚未初始化"
return 0
fi
multiuser_cmd visit-status
if pidof systemd >/dev/null 2>&1; then
if systemctl is-active --quiet lun-visit-monitor 2>/dev/null; then
green_line "采集服务：运行中（不监听网络端口）"
elif visit_monitor_enabled; then
red_line "采集服务：未运行"
else
echo "采集服务：未启用"
fi
elif command -v rc-service >/dev/null 2>&1; then
if rc-service lun-visit-monitor status >/dev/null 2>&1; then
green_line "采集服务：运行中（不监听网络端口）"
elif visit_monitor_enabled; then
red_line "采集服务：未运行"
else
echo "采集服务：未启用"
fi
fi
if visit_monitor_enabled; then
if [ -s "$HOME/lun/xr.json" ]; then
grep -Fq "$(multiuser_module_dir)/data/xray-access.log" "$HOME/lun/xr.json" \
&& green_line "Xray 日志接入：正常" || red_line "Xray 日志接入：未生效"
fi
if [ -s "$HOME/lun/sb.json" ]; then
grep -Fq "$(multiuser_module_dir)/data/singbox-access.log" "$HOME/lun/sb.json" \
&& green_line "Sing-box 日志接入：正常" || red_line "Sing-box 日志接入：未生效"
fi
fi
}

visit_monitor_storage_ui(){
visit_monitor_enabled && visit_storage_enabled=yes || visit_storage_enabled=no
multiuser_cmd visit-status
printf "逐条明细保留天数 [1-30，回车保持当前，输入 0 返回]："
IFS= read -r visit_detail
[ "$visit_detail" = 0 ] && return
printf "每日汇总保留天数 [1-365，回车保持当前，输入 0 返回]："
IFS= read -r visit_summary
[ "$visit_summary" = 0 ] && return
case "$visit_detail:$visit_summary" in
*[!0-9:]*)
red_line "保留天数只能输入整数。"
return 1
;;
esac
set -- visit-config --enabled "$visit_storage_enabled"
[ -n "$visit_detail" ] && set -- "$@" --detail-days "$visit_detail"
[ -n "$visit_summary" ] && set -- "$@" --summary-days "$visit_summary"
multiuser_cmd "$@" || return 1
green_line "存储设置已保存。"
}

visit_monitor_ui(){
while :; do
ui_title "Lun 网站访问监控"
visit_monitor_status_ui
yellow_line "这里记录的是代理连接，不是浏览器点击历史；不记录网页路径、查询参数或传输内容。"
echo " 1. 一键开启 / 修复监控"
echo " 2. 运行状态 / 自检"
echo " 3. 今日智能活动（过滤并合并）"
echo " 4. 今日原始连接明细"
echo " 5. 七天热门域名（过滤后）"
echo " 6. 七天用户 / 设备活动汇总"
echo " 7. 按用户 / 设备 / 域名筛选"
echo " 8. 过滤与合并设置"
echo " 9. 立即采集"
echo "10. 存储设置"
echo "11. 清空全部连接记录"
echo "12. 停用监控（保留已有记录）"
echo " 0. 返回"
printf "请选择 [0-12]（输入 0 返回）："
IFS= read -r mu_choice
case "$mu_choice" in
1) visit_monitor_enable; ui_pause ;;
2) visit_monitor_status_ui; ui_pause ;;
3) multiuser_visit_refresh; multiuser_cmd visit-recent --days 1 --limit 100 --view smart --noise auto; ui_pause ;;
4) multiuser_visit_refresh; multiuser_cmd visit-recent --days 1 --limit 100 --view raw --noise show; ui_pause ;;
5) multiuser_visit_refresh; multiuser_cmd visit-top --days 7 --limit 50 --group domain --noise auto; ui_pause ;;
6) multiuser_visit_refresh; multiuser_cmd visit-top --days 7 --limit 50 --group user --noise auto; ui_pause ;;
7) multiuser_visit_filter_ui ;;
8) visit_monitor_filter_ui ;;
9) multiuser_cmd visit-collect; ui_pause ;;
10) visit_monitor_storage_ui; ui_pause ;;
11)
printf "%s此操作不可恢复。输入 CLEAR 清空数据库访问记录和原始日志（输入 0 返回）：%s" "$LUN_RED" "$LUN_RESET"
IFS= read -r mu_visit_clear
[ "$mu_visit_clear" = 0 ] && continue
multiuser_cmd visit-clear --confirm "$mu_visit_clear"
ui_pause
;;
12) visit_monitor_disable; ui_pause ;;
0|"") return ;;
*) echo "输入错误。" ;;
esac
done
}

multiuser_visit_monitor_ui(){
visit_monitor_ui
}

multiuser_module_ui(){
while :; do
ui_title "Lun 多用户模块维护"
multiuser_enabled && echo "当前：已启用" || echo "当前：已停用"
echo " 1. 备份用户数据库"
echo " 2. 检查模块运行状态"
echo " 3. 更新多用户管理程序"
echo " 4. 启用 / 停用模块"
echo " 5. 安装支持用户流量统计的 Sing-box 内核"
echo " 6. 卸载多用户模块"
echo " 0. 返回"
printf "请选择 [0-6]（输入 0 返回）："
IFS= read -r mu_choice
case "$mu_choice" in
1) multiuser_cmd backup; ui_pause ;;
2) multiuser_cmd doctor; ui_pause ;;
3)
if multiuser_download_agent; then
multiuser_service_restart || true
visit_monitor_service_restart || true
green_line "多用户管理 / 网站监控程序已更新。"
fi
ui_pause
;;
4)
if multiuser_enabled; then
multiuser_cmd set-module --enabled no && multiuser_service_stop
multiuser_bandwidth_disable
multiuser_restore_legacy_subscription_port
yellow_line "模块已停用；将重建为原单用户配置，数据库和增强 Sing-box 保留。"
LUN_MENU_ACTION=rep
return 3
else
mu_primary_port=$(multiuser_config_value port)
[ -n "$mu_primary_port" ] && printf '%s\n' "$mu_primary_port" > "$HOME/lun/subport.log"
multiuser_cmd set-module --enabled yes && multiuser_apply_changes && multiuser_service_start
fi
ui_pause
;;
5) multiuser_install_enhanced_singbox; ui_pause ;;
6)
printf "%s卸载模块将恢复单用户配置。输入 PURGE 会连数据库一起删除，其他输入会先备份数据库：%s" "$LUN_RED" "$LUN_RESET"
IFS= read -r mu_purge
if [ "$mu_purge" != PURGE ] && [ -s "$(multiuser_module_dir)/data/lun.db" ]; then
mu_saved="$HOME/lun-multiuser-backup-$(date +%Y%m%d-%H%M%S).sqlite3"
cp -p "$(multiuser_module_dir)/data/lun.db" "$mu_saved" && green_line "数据库已保留：$mu_saved"
fi
multiuser_cmd set-module --enabled no >/dev/null 2>&1 || true
multiuser_bandwidth_remove
multiuser_remove_service
multiuser_restore_legacy_subscription_port
if visit_monitor_enabled; then
rm -f "$(multiuser_module_dir)/config.json" "$(multiuser_module_dir)/lun-sb-stats"
rm -rf "$(multiuser_module_dir)/generated"
yellow_line "网站访问监控仍在使用共享程序和数据库；已仅移除多用户订阅服务。"
else
rm -rf "$(multiuser_module_dir)"
fi
LUN_MENU_ACTION=rep
return 3
;;
0|"") return 0 ;;
*) echo "输入错误。" ;;
esac
done
}

multiuser_menu(){
if ! multiuser_installed; then
ui_title "Lun 多用户管理"
echo "这是可选模块；不安装时普通风火轮行为完全不变。"
echo "模块将导入当前 UUID 为 legacy-admin/legacy-device，并保留原订阅。"
printf "现在安装多用户模块？[y/N]："
IFS= read -r mu_install
case "$mu_install" in y|Y|yes|YES) multiuser_install || { ui_pause; return; } ;; *) return ;; esac
fi
while :; do
ui_title "Lun 多用户管理"
multiuser_cmd maintenance >/dev/null 2>&1 || true
multiuser_cmd status
ui_dash
echo " 1. 刷新用户与流量总览"
echo " 2. 新增用户（自动创建首台设备）"
echo " 3. 用户 / 设备凭据"
echo " 4. 月额度 / 到期 / 停用 / 删除"
echo " 5. 查看设备订阅"
echo " 6. 用户协议权限 / 安全策略"
echo " 7. 备份 / 运行状态检查"
echo " 8. 动态公平带宽"
echo " 9. 模块更新 / 停用 / 卸载"
echo " 0. 返回"
printf "请选择 [0-9]（输入 0 返回）："
IFS= read -r mu_choice
case "$mu_choice" in
1) multiuser_cmd maintenance >/dev/null 2>&1 || true; multiuser_cmd list-users; ui_pause ;;
2) multiuser_add_user_ui ;;
3) multiuser_device_ui ;;
4) multiuser_policy_ui ;;
5)
printf "设备 ID（输入 0 返回）："; IFS= read -r mu_did
[ "$mu_did" = 0 ] && continue
multiuser_cmd show-subscription --device-id "$mu_did"; ui_pause
;;
6) multiuser_protocol_ui ;;
7) multiuser_cmd backup; multiuser_cmd doctor; ui_pause ;;
8) multiuser_bandwidth_ui ;;
9) multiuser_module_ui; mu_rc=$?; [ "$mu_rc" = 3 ] && return 3 ;;
0|"") return 0 ;;
*) echo "输入错误。" ;;
esac
done
}

show_protocol_help(){
ui_title "Lun 协议特点"
green_line "新手优先：1 VLESS TCP Reality；需 CDN/隧道优先：3 VLESS XHTTP 或 4 VLESS WS；弱网高速优先：10 Hysteria2。"
yellow_line "“隐蔽性”只表示流量特征更接近常见 TLS/HTTP/QUIC，不代表无法识别，也不代表匿名。"
echo " 1. VLESS TCP Reality  【首选】直连稳定，无需证书；适合大多数 VPS 和日常主节点。隐蔽：高（Reality TLS 伪装）。要求：TCP。｜$(protocol_route_capabilities 1)"
echo " 2. VLESS XHTTP Reality【进阶】直连 XHTTP+Reality；适合想测试 HTTP 形态且客户端支持较新的场景。隐蔽：高。要求：TCP。｜$(protocol_route_capabilities 2)"
echo " 3. VLESS XHTTP         【CDN首选】适合橙云、优选 IP 和端口回源。隐蔽：较高（HTTP Host+Path）。要求：域名、路径正确。｜$(protocol_route_capabilities 3)"
echo " 4. VLESS WS            【兼容首选】客户端覆盖广，适合 CDN 或 CF 隧道。隐蔽：中等（WebSocket 特征较明显）。｜$(protocol_route_capabilities 4)"
echo " 5. Shadowsocks-2022   【简单高效】TCP/UDP 直连，适合私用、游戏和小型设备。隐蔽：中等，不是 HTTP 伪装。｜$(protocol_route_capabilities 5)"
echo " 6. AnyTLS              【移动端备选】TLS over TCP 直连，适合 Sing-box 生态。隐蔽：较高。要求：客户端支持 AnyTLS。｜$(protocol_route_capabilities 6)"
echo " 7. Any-Reality         【Sing-box 进阶】Reality 直连，适合不用 Xray 客户端的场景。隐蔽：高。兼容性不如 VLESS Reality 广。｜$(protocol_route_capabilities 7)"
echo " 8. VMess WS            【旧客户端兼容】适合必须使用 VMess 的 CDN/隧道环境；新建节点更推荐 VLESS WS。｜$(protocol_route_capabilities 8)"
echo " 9. Socks5              【调试/信任网络】适合本人临时使用或内网转发。隐蔽：低，不建议裸露给不可信用户。｜$(protocol_route_capabilities 9)"
echo "10. Hysteria2           【弱网高速】适合高延迟、丢包和移动网络。速度：高。特征：QUIC/UDP；必须放行 UDP。｜$(protocol_route_capabilities 10)"
echo "11. TUIC                【低延迟 UDP】适合移动网络、游戏和频繁切网。特征：QUIC/UDP；客户端兼容性略窄。｜$(protocol_route_capabilities 11)"
echo "12. VLESS XHTTP TLS UDP 【实验】H3-only 直连，适合测试 XHTTP/QUIC。某些手机客户端不显延迟或重置，不建议做唯一主节点。｜$(protocol_route_capabilities 12)"
echo "13. VLESS XHTTP TLS TCP/UDP【进阶】直连兼顾 TCP/UDP，并可生成 CDN-TCP。UDP 必须献祭本机公网443端口，否则只输出 TCP 节点。隐蔽：较高。｜$(protocol_route_capabilities 13)"
echo "14. NaiveProxy H2/H3   【公开证书场景】HTTP CONNECT 特征接近普通 Web TLS，适合有正式域名证书的直连节点。｜$(protocol_route_capabilities 14)"
yellow_line "UDP/QUIC 协议需同时放行服务商 UDP、云安全组、系统防火墙；NAT 还需 UDP 映射。"
red_line "NaiveProxy 必须使用与域名匹配的公开可信证书，不接受自签或 Cloudflare Origin CA。"
}

show_nat_help(){
ui_title "Lun NAT / 端口池说明"
echo "Lun 统一使用：公网端口-内网端口。示例：4444-80。"
echo "含义：客户端连接公网 4444，服务商把流量转到 VPS 内网 80，Lun 协议实际监听 80。"
echo "多组映射用空格分隔：4444-80 5555-443 6666-8080。"
echo "端口池也是按位置对应：第 1 个公网端口对第 1 个内网端口。"
yellow_line "同一内网端口配了多个公网端口时，Lun 只保留第一组；完全重复的映射自动去重。"
red_line "同一公网端口不能指向两个内网端口；此类冲突会被拒绝。"
green_line "Lun 会放行协议和订阅的内网监听端口。"
yellow_line "Lun 不能代替服务商创建 4444→80；请先在服务商面板建好，再把同样的映射填入 Lun。"
}

show_cdn_help(){
ui_title "Lun Cloudflare 端口回源操作"
green_line "优选 IP：进入“入口网络管理 → 一键优选 CDN 节点”，用本地浏览器实测后可直接应用；原有手工输入仍保留。"
echo "1. 在 Lun 选择支持 CDN 的协议：VLESS XHTTP、VLESS WS、VMess WS，或 XHTTP TLS TCP/UDP 的 TCP 节点。"
echo "2. 记下 Lun 显示的服务域名、Path、Cloudflare 边缘端口和源站端口。"
echo "3. 在 Cloudflare DNS 中让该域名指向 VPS 公网 IP，并开启橙云；灰云不会经过 Cloudflare，Origin Rule 不会执行。"
echo "4. 进入 Cloudflare 网站 → 规则 → Origin Rules（源站规则）→ 创建规则。"
echo "5. 匹配条件使用：主机名等于服务域名；多协议共用域名时，再加 URI Path 匹配对应 UUID 路径。"
echo "6. 操作选择“重写目标端口”，填入源站端口：普通 VPS 填 Lun 监听端口；NAT 机填服务商的公网映射端口。"
echo "7. NAT 示例：服务商已配 56567-8080，Cloudflare 边缘用 443，则 Origin Rule 目标端口填 56567，Lun 仍监听 8080。"
echo "8. 回到 Lun 选择“手动登记已有规则”，填边缘端口和目标端口，然后刷新订阅并运行连通检测。"
green_line "通过标准：订阅中出现 CDN 节点，且 Host + Path 诊断能回源到 Lun 协议。"
red_line "Reality、Shadowsocks、AnyTLS、Socks5、Hysteria2、TUIC 和 H3-only 不能靠 Origin Rules 变成 Cloudflare CDN 节点。"
}

show_certificate_help(){
ui_title "Lun 域名 / 证书说明"
echo "自签证书：适合直连测试；客户端需要跳过校验或使用证书指纹。"
echo "Cloudflare Origin CA：适合橙云回源，不是客户端直接信任的公网证书。"
echo "公开可信证书：域名必须匹配，可通过 HTTP-01、DNS API 或本机证书导入获得。"
yellow_line "HTTP-01 要求域名解析到本机且 TCP 80 可从公网访问。"
red_line "NaiveProxy 必须使用与服务域名匹配的公开可信证书。"
}

help_menu(){
while :; do
ui_title "Lun 使用说明 / 协议特点"
echo " 1. 协议特点"
echo " 2. NAT / 端口池"
echo " 3. Cloudflare / Origin Rules"
echo " 4. 域名 / 证书"
echo " 0. 返回"
printf "请选择 [0-4]："
IFS= read -r c
case "$c" in
1) show_protocol_help; ui_pause ;;
2) show_nat_help; ui_pause ;;
3) show_cdn_help; ui_pause ;;
4) show_certificate_help; ui_pause ;;
0|"") return ;;
*) echo "输入错误。" ;;
esac
done
}

lun_menu(){
while :; do
lun_menu_screen
ui_line
printf "请输入数字【0-9】："
IFS= read -r menu_choice
case "$menu_choice" in
1) install_protocol_menu; [ "$LUN_MENU_ACTION" = "menu" ] && continue; break ;;
2) subscription_menu; [ "$LUN_MENU_ACTION" = "menu" ] && continue; break ;;
3) network_menu; [ "$LUN_MENU_ACTION" = "menu" ] && continue; break ;;
4) service_update_menu; [ "$LUN_MENU_ACTION" = "menu" ] && continue; break ;;
5) advanced_menu; [ "$LUN_MENU_ACTION" = "menu" ] && continue; break ;;
6) multiuser_menu; mu_rc=$?; [ "$mu_rc" = 3 ] && break ;;
7) visit_monitor_ui ;;
8) cluster_menu ;;
9) help_menu ;;
0|"") exit ;;
*) echo "输入错误，请重新选择。"; sleep 1 ;;
esac
done
}

if [ "$LUN_MENU_REQUEST" = yes ]; then
lun_splash
lun_menu_prepare
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

if [ "$1" = "self-update" ]; then
update_lun_script
exit $?
elif [ "$1" = "cluster-refresh-identity" ]; then
cip || exit $?
if multiuser_enabled; then
multiuser_cmd apply >/dev/null 2>&1 || exit $?
multiuser_service_restart >/dev/null 2>&1 || true
fi
exit 0
elif [ "$1" = "cluster-service-control" ]; then
cluster_service_control_local "$2" "$3"
exit $?
elif [ "$1" = "cluster-prepare-multiuser" ]; then
if multiuser_enabled; then
exit 0
fi
multiuser_install
exit $?
elif [ "$1" = "cluster-firewall" ]; then
apply_lun_firewall_rules
exit $?
elif [ "$1" = "cluster-factory-reset" ]; then
sleep 3
LUN_CLUSTER_DESTRUCTIVE=yes
export LUN_CLUSTER_DESTRUCTIVE
factory_reset
exit $?
elif [ "$1" = "cluster-uninstall" ]; then
sleep 3
LUN_CLUSTER_DESTRUCTIVE=yes
export LUN_CLUSTER_DESTRUCTIVE
cleandel
rm -rf sbx_update "$HOME/lun" "$HOME/weblun" "$HOME/agsbx" "$HOME/websbx"
exit 0
elif [ "$1" = "del" ]; then
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
sleep 5
echo "重启完成"
apply_lun_firewall_rules || true
sleep 3
cip
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
yellow_line "oap 兼容参数不再清空防火墙；本版会按实际协议和订阅端口精确放行。"
fi
if ! ins; then
echo "Lun 内核安装失败，未覆盖已有内核或启动不完整服务。"
exit 1
fi
if multiuser_enabled; then
if ! multiuser_reconcile_configs; then
echo "多用户配置注入失败，正在恢复重建前配置。"
[ "$_lun_rebuild_request" = yes ] && rollback_rebuild
exit 1
fi
elif visit_monitor_enabled; then
if ! multiuser_cmd visit-apply; then
echo "网站监控配置注入失败，正在恢复重建前配置。"
[ "$_lun_rebuild_request" = yes ] && rollback_rebuild
exit 1
fi
fi
if [ "$_lun_rebuild_request" = yes ]; then
if ! validate_rebuild; then
rollback_rebuild
exit 1
fi
_oneclick_rebuild_active=no
[ -s "$HOME/lun/oneclick_full_pending" ] && _oneclick_rebuild_active=yes
if ! oneclick_full_finalize; then
rollback_rebuild
exit 1
fi
[ "$_oneclick_rebuild_active" = yes ] || commit_rebuild_snapshot
if multiuser_enabled; then
[ -s "$HOME/lun/xr.json" ] && xrestart
[ -s "$HOME/lun/sb.json" ] && sbrestart
multiuser_service_start || yellow_line "多用户代理服务未能自动启动，请进入多用户管理 → 诊断。"
fi
visit_monitor_service_start || yellow_line "网站监控服务未能自动启动，请进入网站访问监控 → 运行状态 / 自检。"
fi
if [ -n "$sub" ] && ! multiuser_enabled; then
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
if ! apply_lun_firewall_rules; then
if [ "$_oneclick_rebuild_active" = yes ]; then
rollback_rebuild
exit 1
fi
fi
if ! cip; then
if [ "$_oneclick_rebuild_active" = yes ]; then
rollback_rebuild
exit 1
fi
fi
cloudflare_origin_finalize_pending || true
if [ "$_oneclick_rebuild_active" = yes ]; then
if ! oneclick_full_complete; then
rollback_rebuild
exit 1
fi
commit_rebuild_snapshot
fi
if cluster_enabled; then
cluster_service_start || yellow_line "服务器联动服务未能自动启动。"
cluster_push_event >/dev/null 2>&1 || true
[ "$(cluster_role 2>/dev/null)" = master ] && cluster_refresh_profiles >/dev/null 2>&1 || true
fi
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
