# 风火轮

风火轮 是一个基于 Sing-box、Xray 和 Cloudflared 的终端代理节点脚本，核心逻辑基于开源项目二次开发/优化。它支持变量式无交互安装，也支持通过 `lun` 进入引导式菜单完成安装、证书、订阅、Argo、WARP、端口和节点输出管理。

当前脚本版本：`V26.7.22.4`。

## 致谢与上游

风火轮最初基于甬哥开源项目 [yonggekkk/argosbx](https://github.com/yonggekkk/argosbx) 进行二次开发，并在此基础上持续改进协议、证书、CDN、NAT、订阅和事务重建等功能。感谢甬哥及所有开源贡献者的长期维护、无私分享与开源奉献。

## 快速开始

```bash
bash <(curl -Ls https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```
如果系统没有 `curl`：

```bash
bash <(wget -qO- https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```

安装完成后，root 环境会创建 `/usr/bin/lun`，非 root 环境会创建 `$HOME/bin/lun`。重新登录 SSH 后可直接运行：

```bash
lun
```

旧入口 `argosbx.sh` 仅保留为兼容包装器，会自动转到 `lun.sh`。

## 终端菜单

无参数运行 `lun` 会进入风火轮多协议交互面板，顶部显示系统、IP、内核、协议、证书、节点订阅分享和 Argo 状态，下方提供：

```text
1. 安装 / 协议管理
2. 节点订阅分享
3. 入口网络管理
4. 服务与更新
5. 高级设置
6. 多用户管理
7. 使用说明 / 协议特点
0. 退出
```

引导式安装会按轻量流程询问 VPS 类型、端口池、协议/端口、服务域名、证书模式、节点订阅分享并最终确认。中间步骤只显示单行进度，完整配置只在最终确认时显示一次；NAT 映射显示组数，不反复展开整张映射表。普通 VPS 只显示“端口/端口池”；只有选择 NAT VPS 后才显示“内网端口/公网端口/映射”。详细的 NAT、Cloudflare、证书和 14 项协议特点统一放在“使用说明 / 协议特点”。“入口网络管理”提供 VPS 类型/端口池、单协议快速改端口、CDN/CF 优选、Cloudflare Origin Rules（端口回源）、CF 隧道/Argo 和 CDN 诊断；普通 VPS 与 NAT VPS 均可使用 Origin Rules，只有操作系统/NAT 公网端口映射仍为 NAT 专用。每一步输入 `0` 返回上一级，非法域名或端口会停留在当前输入层。

“安装 / 协议管理”中的增删改操作会停止旧协议进程并重写 Xray/Sing-box 配置，这是让新增、删除和端口修改生效的必要步骤；已有内核、证书、UUID 与订阅设置会保留，只有所选协议需要的内核文件确实缺失时才下载。重建前会创建事务快照，SSH 断线、命令中断或新配置校验失败时自动恢复旧配置和服务，成功后保留 `~/lun/.last_good_rebuild`。状态区会区分“运行中”“已安装但未运行”“内核已安装但当前协议未使用”和“未安装”。

Argo 隧道可在“入口网络管理” → “CF 隧道 / Argo”里单独设置。若没有 VMess WS 或 VLESS WS，菜单会引导直接添加一个可绑定协议，普通 VPS 默认端口为 `8080`，NAT VPS 默认内网端口为 `8080`。Argo 优选入口使用独立变量 `argoip`，不会复用普通 CDN 的 `cfip`；每个入口都会导出 TLS 443 和 HTTP 80 节点。该菜单的“诊断隧道回源”会同时检查本机 WebSocket 和 Cloudflare 下发的 Public Hostname Service，若控制台仍指向旧端口，会直接显示应改成的 `http://localhost:端口`。

## 快捷操作

安装后运行 `lun` 即可进入交互面板。面板内提供安装/协议管理、节点订阅分享、入口网络管理、服务与更新、高级设置、可选多用户管理以及集中说明模块。

## 可选多用户管理

主菜单第 6 项是独立的可选模块。只有首次进入并确认安装后才会增加 Python 3、SQLite 用户数据库和 `lun-agent` 服务；不安装或停用模块时，普通风火轮的单用户协议、UUID 和 BusyBox 订阅行为保持不变。模块要求 systemd 或 OpenRC，无 init 环境会拒绝安装。

模块提供用户与设备、按指定日期重置的月额度、到期停用、协议权限、设备订阅、备份和诊断。用户列表与实时流量入口已合并为“用户与流量总览”，按“已用/月额度”显示并统一使用 G；内部仍兼容旧数据库中的永久总额度字段，但新界面不再配置或展示它。新增用户会自动创建第一台设备，每台设备使用独立 UUID、通用密码、Shadowsocks-2022 用户密钥和随机订阅 token。删除用户必须输入用户名称确认，并会立即撤销其设备、订阅及含该用户的自动数据库备份。

安装时会把现有 UUID 导入为 `legacy-admin / legacy-device`，服务器级 WS/XHTTP 路径和旧订阅 token 保持不变。Shadowsocks-2022 会使用额外端口建立多用户入站，原端口继续服务旧客户端；NAT VPS 必须先给订阅端口和额外 Shadowsocks 端口准备公网映射。

有匹配订阅地址的公开可信证书时，模块自动使用 HTTPS；否则会以红色警告 HTTP token 明文风险并要求二次确认。订阅服务只公开随机 token 路径，不提供目录列表或公网管理接口，并返回 `Subscription-Userinfo` 流量头。

Xray 使用本机 API 统计用户流量，配额或到期触发时优先动态移除 VLESS/VMess 用户；Xray Socks 和 Sing-box 结构变化会执行校验后的短暂重载。Sing-box 按用户流量统计需要同版本、增加 `with_v2ray_api` 标签的增强内核，可在模块维护菜单中安装。默认安全规则阻断私网、链路本地、云元数据和 TCP 25，TCP 465/587 保持允许；第一版只观察 BT，不自动处罚。

“动态公平带宽”对服务器到客户端的全部下载出口统一整形。用户填写全机总下载上限（Mbit/s），系统优先使用 CAKE 公平队列，不支持 CAKE 时回退 HTB 总量整形和 FQ-CoDel 公平排队。连接少时可借用剩余带宽，繁忙时自动公平共享。关闭模块限速或卸载模块时会删除根队列并恢复系统默认出口队列。

## 协议与域名变量

变量值为空表示随机端口，填写数字表示指定端口。

| 协议 | 变量 |
| --- | --- |
| VLESS TCP Reality Vision | `vlpt` |
| VLESS XHTTP Reality ENC | `xhpt` |
| VLESS XHTTP ENC | `vxpt` |
| VLESS WS ENC | `vwpt` |
| Shadowsocks-2022 | `sspt` |
| AnyTLS | `anpt` |
| Any-Reality | `arpt` |
| VMess WS | `vmpt` |
| Socks5 | `sopt` |
| Hysteria2 | `hypt` |
| TUIC | `tupt` |
| VLESS XHTTP TLS UDP | `xupt` |
| VLESS XHTTP TLS TCP/UDP | `xcpt` |
| NaiveProxy H2/H3 | `nvpt` |

示例：

```bash
vlpt="" vmpt="" hypt="" bash <(curl -Ls https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```

服务域名与证书：

| 变量 | 用途 |
| --- | --- |
| `domain` | 服务域名，用于 ACME 域名证书、TLS 节点 SNI，并默认作为普通节点客户端地址 |
| `certmode` | `self`、`origin`、`ca`、`domain`、`dns`、`ip`，默认 `self` |
| `acme_email` | Let’s Encrypt 账户邮箱 |
| `acme_dns` | acme.sh DNS provider，例如 `dns_cf`、`dns_ali` |

`certmode=self` 会生成本地 ECDSA 自签证书。`origin` 表示 Cloudflare Origin CA 等仅供服务商回源验证的证书，`ca` 表示公开 CA 签发证书。`domain` 使用 HTTP-01，`dns` 使用 acme.sh 原生 DNS API，`ip` 使用 Let’s Encrypt short-lived IP 证书。

### XHTTP TLS 与 NaiveProxy

三个新变量默认都不启用，只有显式设置变量或在菜单中勾选后才会安装：

| 协议 | 监听与放行要求 | 证书与订阅 |
| --- | --- | --- |
| `xupt` | Xray XHTTP + TLS + ALPN `h3`；放行对应 UDP 端口 | 路径 `UUID-xu`；支持自签、Origin CA 和公开 CA；输出分享链接与 Clash/Mihomo 节点 |
| `xcpt` | Xray XHTTP + TLS + ALPN `h2,http/1.1`；源站监听并放行 TCP 端口 | 路径 `UUID-xc`；支持风火轮全部证书模式；实验 CDN-UDP 仅要求客户端到 Cloudflare 边缘的 UDP 443，回源仍为 TCP |
| `nvpt` | Sing-box Naive，同一端口提供 H2/TCP 与 H3/UDP；必须同时放行 TCP/UDP | 用户名、密码均沿用 UUID；只接受与服务域名匹配、未过期且可由系统公开 CA 信任库验证的完整证书链 |

NaiveProxy 会在配置生成前拒绝自签证书、Cloudflare Origin CA、IP-only 证书、域名不匹配或不可信的证书链，并提示先从证书管理导入。运行状态分别保存在 `~/lun/port_xu`、`~/lun/port_xc`、`~/lun/port_nv`。

Sing-box 1.13 原生 VLESS 出站不支持 XHTTP transport，因此 `xupt/xcpt` 不写入 `sbox.json` 伪兼容项；它们仍会写入通用分享链接和 `clmi.yaml`。NaiveProxy 会写入 H2/H3 两种 Sing-box 节点，但不会写入当前不支持 Naive 的 Clash/Mihomo 订阅。Linux 客户端使用 Sing-box Naive 出站时，还要同时部署官方发行包中的 `libcronet.so`；服务端 Naive 入站不依赖该动态库。

IPv6-only VPS 可以使用 HTTP-01。脚本检测到域名只有 AAAA 时会让 acme.sh 使用 IPv6 监听；AAAA 必须指向本机公网 IPv6，并且公网 TCP 80 必须可达且未被其他进程占用。域名同时存在 A 和 AAAA 时，Let’s Encrypt 会优先验证 IPv6，因此错误的 AAAA 也会导致申请失败。失败时菜单会显示 A/AAAA、本机地址、80 端口占用，并把 acme.sh 完整输出保存到 `~/lun/acme_issue.log`。无法开放 80 或域名使用橙云时建议使用 DNS API 模式。

引导式安装的证书步骤和“证书管理”菜单都支持搜索并导入本机证书。建议将证书与私钥放入 `~/lun/import/`；脚本也会自动搜索 `~/lun`、`/root/key`、`/root/cert`、`/root/ygkkkca`、acme.sh 与 Let’s Encrypt 常用目录，通过公钥匹配证书和私钥。发现多个证书时会优先推荐“域名匹配、未过期、私钥匹配、服务商/CA 签发”的证书；输入编号可自行选择，输入 `0` 返回，直接回车导入推荐项。

DNS API 凭据按 acme.sh 原生环境变量保存到 `/root/lun/cert.env`，权限为 `600`。

### IPv6 内核下载

GitHub Release 下载入口 `github.com` 可能只返回 IPv4，因此纯 IPv6 VPS 会自动改用 `https://oracle1.1223344.xyz:8443/fhlun` 静态镜像。该镜像由 Oracle 双栈服务器通过 IPv4 同步 FHLUN 的 Xray/Sing-box 与 Cloudflared 文件，再通过 HTTPS 8443 同时提供 IPv4/IPv6 下载；443 保留给 XHTTP-TLS CDN-UDP 测试，不再由 Nginx 占用。不使用 Cloudflare Worker 或第三方代理。可通过 `coremirror="https://your-mirror.example:8443/fhlun"` 覆盖，填写 `coremirror=off` 则只使用 GitHub Release。

镜像主机使用 Nginx 提供文件：HTTP 80 继续保留给 ACME，HTTPS 使用 8443 并同时监听 `[::]:8443`，由 `fhlun-core-mirror.timer` 每日执行同步；可在镜像主机运行 `systemctl status fhlun-core-mirror.timer` 查看状态，或运行 `systemctl start fhlun-core-mirror.service` 立即同步最新 Release。可复用仓库中的 [`deploy/nginx/fhlun-core-mirror-8443.conf`](deploy/nginx/fhlun-core-mirror-8443.conf)。

Reality、Argo 和 CDN 仍然独立：

| 变量 | 用途 |
| --- | --- |
| `reym` | Reality / Any-Reality 的 SNI 伪装域名 |
| `cdnym` | CDN 回源 Host 域名（已解析到 VPS 的域名，CF 通过它回源到你的服务器） |
| `argo` | 填写 `vmpt` 或 `vwpt` 启用 Argo |
| `agn` | Argo 固定隧道域名 |
| `agk` | Argo 固定隧道 token |
| `cfip` | CDN 优选 IP 或域名（客户端连接的 CF 入口地址），可填多个；留空时尝试从已橙云的 `cdnym` 自动解析 CF 边缘 IP |
| `argoip` | Argo 优选 IP 或域名（与 cfip 独立），可填多个值 |
| `cdnmode` | `standard` 同端口模式；`rewrite` 为普通/NAT VPS 通用的 Origin Rules 回源端口改写模式 |
| `cdnpt` | 改写模式的 Cloudflare 边缘端口；支持下列全部官方 HTTP/HTTPS 代理端口 |
| `cdnproto` | CDN 节点协议：默认 `xhttp`；`all` 兼容输出 XHTTP、VLESS WS、VMess WS |
| `addrmode` | 普通节点地址输出：`domain`、`ipv4`、`ipv6`、`dual`、`all` |

`agk` 可直接粘贴完整的 `cloudflared.exe service install ey...` 命令，脚本会自动提取 `ey...` token。

### CDN 优选 IP 加速说明

CDN 优选 IP 的工作原理：客户端连接 Cloudflare 优选地址（节点里的 `add/cfip`），Cloudflare 通过回源域名（`host/cdnym`）回源到你的 VPS。服务器访问外网默认仍直连 VPS；只有启用 WARP 出站时，目标网站才可能显示 WARP/Cloudflare IP。

启用 CDN Host 不会强制把普通节点地址改回服务器 IP；如果你设置了 `domain/addym`，订阅里的直连节点仍可继续使用域名。CDN 节点会额外使用 `cfip` 作为 Cloudflare 入口地址。

**使用条件：**
1. 设置 `cdnym`：Cloudflare 接收请求时使用的 Host 域名。
2. 设置 `cfip`：可混合填写多个 IPv4、IPv6 或域名，脚本会去重并生成唯一节点名。留空时只采用从已橙云 `cdnym` 解析到且不等于本机公网地址的 IP；无法确认橙云时不会再自动塞入第三方优选域名。
3. 客户端直接连接 `cfip` 时，不依赖客户端把 `cdnym` 解析到哪个地址；脚本以实际 CF 边缘诊断为准。直接使用 `cdnym` 作为入口时应开启橙云。
4. 默认生成 VLESS XHTTP CDN；`xcpt` 只在 Cloudflare HTTPS 边缘端口生成 CDN-TCP，WS 协议保留直连；需要旧式多协议输出时设置 `cdnproto=all`。

**默认 CDN 协议：** VLESS XHTTP（非 Reality）与已启用的 VLESS XHTTP TLS
**高级兼容协议：** 设置 `cdnproto=all` 后额外生成 VMess WS、VLESS WS
**不支持 CDN 的协议：** Reality、XHTTP TLS UDP（`xupt`）、NaiveProxy、AnyTLS、Hysteria2、TUIC、Shadowsocks、Socks5（保留直连节点）

Cloudflare 橙云支持端口：

```text
HTTP（明文）：80、8080、8880、2052、2082、2086、2095
HTTPS（加密）：443、8443、2053、2083、2087、2096
支持但缓存已禁用：2052、2053、2082、2083、2086、2087、2095、2096、8880、8443
```

首次设置或新增支持 CDN 的协议时，端口回车随机会优先从未占用的 CF 官方端口中匹配：VLESS XHTTP、VLESS WS、VMess WS 使用 HTTP 端口组，XHTTP TLS TCP/UDP 使用 HTTPS 端口组；自动随机默认排除热门的 `443`。若端口池中没有可用 CF 端口，脚本会回退普通随机端口并用黄色提示后续必须配置 Origin Rules。`xupt`、Reality 和 NaiveProxy 仍按普通端口处理，不套普通 CDN。

**激进 443 测试模式：** 如果要测试 XHTTP TLS CDN-UDP 的 443 直回源，必须在协议端口提示处手动输入 `443`，不能依赖回车随机。443 可能已被 Nginx、Web 面板或其他服务占用；首次设置前请使用 `ss -ltnp` 或 `lsof -i:443` 查明 PID，确认业务影响后手动停止服务或 `kill` 对应 PID。Lun 不会自动杀掉未知占用进程。`xcpt=443` 时为 443→443，不需要 Origin Rule；若 443 不能献祭，则使用其他 HTTPS 源站端口，并为 Cloudflare 边缘 443 配置 Origin Rule。

普通 VPS 在协议端口本身属于 Cloudflare 官方端口时可以继续使用同端口 CDN；协议端口不适合 CF 时，脚本自动启用 Origin Rules。XHTTP TLS 的实验 CDN-UDP 固定需要 Cloudflare 边缘 `443`，但源站不必监听 `443`，可用 Origin Rule 将 `443` 回源到随机分配的 `8443/2053/2083/2087/2096` 等 HTTPS 源站端口。普通 VPS 的规则目标是本机协议监听端口，NAT VPS 的规则目标是该协议的 NAT 公网映射端口。例如映射为 `56567 → 8080` 时，节点使用边缘端口 `8080`，规则目标端口填写 `56567`。不要只按 HTTP/HTTPS 分流；必须使用菜单输出的 `http.host + URI Path` 精确表达式。`xcpt` 使用 `UUID-xc` 路径，菜单会与原有 `UUID-vx` 分别输出规则及边缘端口。

NAT VPS 需要三层设置：先在服务商/端口转发处建立“公网端口 → 内网监听端口”，再在 `lun → 入口网络管理 → Cloudflare Origin Rules` 使用菜单显示的 Host + Path 规则；Origin Rule 目标填写公网 NAT 端口，不是内网端口，Cloudflare 不能代替服务商映射。最后确认安全组放行公网端口并刷新订阅。若公网映射本身不是 CF 官方端口，也必须使用 Origin Rules 回源，不能把内网端口直接当成 CDN 节点端口。

HTTPS 端口组会让 Lun 为 CDN 兼容入站启用源站 TLS。自签证书在 Cloudflare 使用 Full；匹配 Host 的公开 CA 或 Cloudflare Origin CA 证书可使用 Full (Strict)。切换边缘端口只重建配置并重启服务，不重新下载内核。

`xcpt` 的 CDN-TCP 只会在 Cloudflare 官方 HTTPS 边缘端口生成。实验性 CDN-UDP 只会在边缘端口严格为 `443` 时生成；还必须让 DNS 记录保持橙云代理状态并在 Cloudflare 开启 HTTP/3，因为 HTTP/3 使用 QUIC/UDP 443。若条件不满足，脚本只显示警告，不会把 UDP 节点伪装成可用配置。参考 [Cloudflare HTTP/3](https://developers.cloudflare.com/speed/optimization/protocol/http3/) 与 [Cloudflare 代理端口](https://developers.cloudflare.com/fundamentals/reference/network-ports/)。

刷新订阅时，脚本还会比较“本机 Xray 入站响应”与每个 Cloudflare HTTPS 入口的实际响应。只有入口确实经过 Cloudflare，且 Host + `UUID-xc` Path 已按默认同端口或 Origin Rule 回源到 `xcpt` 源站端口时，才输出对应 CDN-TCP；同一入口还公布 HTTP/3 时才输出实验 CDN-UDP。源站不是 443 却未配置 Origin Rule、请求落到 Nginx 443 或边缘探测失败时会明确跳过，不再生成在 v2rayN 中显示 `-1` 的伪可用节点。

**示例：**

普通 VPS：

```bash
vxpt="" cdnym="proxy.example.com" cfip="108.162.198.31 2606:4700::6810:1234" cdnproto="xhttp" bash <(curl -Ls https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```

普通 VPS 的 XHTTP TLS 随机源站端口会优先分配未占用的 Cloudflare HTTPS 端口（默认排除 443）；可直接测试 HTTPS CDN-TCP：

```bash
xcpt="" cdnym="proxy.example.com" cfip="108.162.198.31" bash <(curl -Ls https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```

需要实验 CDN-UDP 时，若 `xcpt` 不是 443，在 Origin Rules 中将边缘 `443` 按 `UUID-xc` Path 回源到该 XHTTP TLS 源站端口；若 `xcpt=443` 则使用默认 443→443。两种模式都要开启橙云与 HTTP/3。

NAT VPS Origin Rules：

```bash
vpsmode="nat" vxpt="8080" ptmap="56567-8080" cdnym="proxy.example.com" cfip="108.162.198.31" cdnmode="rewrite" cdnpt="8080" cdnproto="xhttp" bash <(curl -Ls https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```

XHTTP TLS + NaiveProxy（`24443/UDP`、`25443/TCP`、`26443/TCP+UDP`）：

```bash
domain="proxy.example.com" certmode="domain" xupt="24443" xcpt="25443" nvpt="26443" bash <(curl -Ls https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```

HTTP 端口组节点会显式写入 `security=none`，HTTPS 端口组节点写入 TLS。节点名称同时包含边缘模式和端口，避免 v2rayN 在切换模式后沿用旧的 TLS/Reality/PublicKey 字段。CDN 名称中的 `DOMAIN` 只表示 `cfip` 是域名入口，并不是另一种旧协议；新版不再自动生成未经验证的第三方 `DOMAIN` 入口，显式填写的域名仍会保留。

如果 v2rayN 仍显示旧的 `vl-xhttp-enc-CDN-HTTP-8080-DOMAIN-*`，但服务器 `~/lun/jhsub.txt` 已无该名称，它属于客户端缓存或以前手动导入的节点，需要在 v2rayN 删除旧节点后重新更新订阅；服务端无法远程删除客户端本地缓存。

## 普通节点地址输出

菜单路径：`lun` → `高级设置` → `节点地址输出`。可选择仅域名、仅 IPv4、仅 IPv6、IPv4+IPv6、域名+IPv4+IPv6。选择结果保存到 `$HOME/lun/address_mode`，刷新订阅后仍然有效。

| `addrmode` | 输出内容 |
| --- | --- |
| `domain` | 仅域名 |
| `ipv4` | 仅 IPv4 |
| `ipv6` | 仅 IPv6 |
| `dual` | IPv4 和 IPv6 |
| `all` | 域名、IPv4 和 IPv6 |

生成的节点名称会带 `DOMAIN`、`IPv4`、`IPv6` 后缀。CDN 节点继续只使用 `cfip`，Argo 节点继续只使用 `argoip`。

### 兼容 addym/addout

`addym` 用于把普通节点客户端里的 `address/server/add` 从 VPS IP 替换为你自己的域名或 IP。它不会改变 Reality SNI、WS/XHTTP Host、Argo 域名或 Argo 优选地址。

```bash
vlpt="" addym="proxy.example.com" addout="replace" bash <(curl -Ls https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```

`addout` 支持：

| 值 | 行为 |
| --- | --- |
| `off` | 只输出 VPS IP |
| `replace` | 普通节点地址替换为 `addym` |
| `both` | 同时输出 IP 和 DOMAIN 普通节点 |

旧变量继续兼容；设置 `addrmode` 后以新的统一地址模式为准。未设置 `addrmode` 时仍按原有 `addym/addout/ippz` 行为读取。

## NAT VPS 端口映射

`ptmap` 用于 NAT VPS 的外网端口到内网监听端口映射，只影响节点链接、订阅链接、`jhsub.txt`、`sbox.json`、`clmi.yaml` 里的客户端端口，不写本机 iptables。

格式为 `外网端口-内网监听端口`，多个映射用空格分隔：

```bash
ptmap="54834-2096 54835-8443" vlpt="2096" anpt="8443" bash <(curl -Ls https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```

安装后也可通过 `lun` → `入口网络管理` → `VPS 类型 / 端口池 / 快速改端口` → `NAT 公网端口映射` 修改或清除。

映射必须保持公网端口唯一。同一个内网端口对应多个公网端口时，脚本会保留首次出现的映射，并用黄色提示跳过后续项；完全重复的映射会自动去重。同一个公网端口若指向不同内网端口，会用红色指出冲突并拒绝整次输入。例如 `31620-80 63337-80` 会保留 `31620-80`、忽略 `63337-80`。

## 端口池

普通 VPS 只需要设置一个端口池，协议端口和节点订阅分享端口随机时会直接从池内取值。NAT VPS 推荐使用 `inpool/outpool` 分别设置内网端口池和外网端口池；设置外网端口池后，会按位置自动映射到内网端口池，只改变客户端看到的端口，不写 iptables。随机取端口时会跳过已被当前协议、订阅服务或 NAT 映射占用的端口；手动映射按上一节的公网唯一、内网保留首项规则处理。

```bash
inpool="1000+1010 8080" outpool="49096+49106 51046" vwpt="" sub="y" bash <(curl -Ls https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```

规则：

| 格式 | 行为 |
| --- | --- |
| `2096` | 普通端口 |
| `1000+1010` | 连续端口范围，表示 1000 到 1010 |
| `1000..1010` | 兼容的连续端口范围 |

旧变量 `portpool` 仍兼容，NAT 模式下支持 `54834-2096` 这种 `公网端口-内网监听端口` 映射项，并会自动补充到 `$HOME/lun/port_map`。安装后可通过 `lun` → `入口网络管理` → `端口池` 修改。

## 本地订阅

安装时启用：

```bash
sub="y" subid="mytoken" subpt="30080" vlpt="" bash <(curl -Ls https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```

订阅地址默认只输出 IPv4。可在 `lun` → `节点订阅分享` 中修改订阅 token/端口，或切换为 `ipv4`、`ipv6`、`both`；无 IPv6 时会自动跳过 IPv6 订阅地址。NAT VPS 下订阅 URL 会显示公网端口，服务仍监听内网端口。刷新时会识别订阅自身的 httpd，不会把原端口误判为协议占用；若确实撞到协议或外部进程，会从完整映射/端口池中自动选择空闲端口，普通 VPS 的自动随机端口使用 `20000-65535`。修改订阅 token、端口或 IP 输出模式时只刷新分享文件、软链和本地 httpd，不会重装内核或重建协议。

生成内容包括：

```text
$HOME/lun/jhsub.txt
$HOME/lun/clmi.yaml
$HOME/lun/sbox.json
```

## 二进制资产

风火轮 使用本仓库 release tag `lun` 下的资产：

```text
xray-amd64
xray-arm64
sing-box-amd64
sing-box-arm64
```

如需自行发布 Docker/SAP 镜像，默认建议使用：

```text
ghcr.io/azk78lun-collab/lun:latest
```

## 许可

本项目保留原许可证，详见 `LICENSE`。

## 来源说明

本项目基于以下优秀开源项目构建：

- **Xray-core** ([XTLS/Xray-core](https://github.com/XTLS/Xray-core)) — 提供 VLESS / VMess / Reality / XHTTP 等协议内核
- **sing-box** ([SagerNet/sing-box](https://github.com/SagerNet/sing-box)) — 提供 NaiveProxy / Hysteria2 / Tuic / AnyTLS / Shadowsocks 等协议内核

感谢以上核心项目的开发者与维护者。
