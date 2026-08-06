# 风火轮

风火轮 是一个基于 Sing-box、Xray 和 Cloudflared 的终端代理节点脚本，核心逻辑基于开源项目二次开发/优化。它支持变量式无交互安装，也支持通过 `lun` 进入引导式菜单完成安装、证书、订阅、Argo、WARP、端口和节点输出管理。

当前脚本版本：`V26.8.5.12`。

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

## 终端菜单

无参数运行 `lun` 会进入风火轮多协议交互面板，顶部显示系统、IP、内核、协议、证书、节点订阅分享和 Argo 状态，下方提供：

```text
1. 安装 / 协议管理
2. 节点订阅分享
3. 入口网络管理
4. 服务与更新
5. 高级设置
6. 多用户管理
7. 网站访问监控
8. 服务器联动 / 节点集群
9. 使用说明 / 协议特点
0. 退出
```

引导式安装会按轻量流程询问 VPS 类型、端口池、协议/端口、服务域名、证书模式、节点订阅分享并最终确认。协议选择和增删改界面共用带边框的对齐表格，分别显示选择状态、监听/公网端口以及直连、CDN 优选、端口回源、CF 隧道能力，支持项使用绿色 `✓`；表格由脚本按终端显示宽度排版，不依赖系统 `column` 命令。中间步骤只显示单行进度，完整配置只在最终确认时显示一次；NAT 映射显示组数，不反复展开整张映射表。普通 VPS 只显示“端口/端口池”；只有选择 NAT VPS 后才显示“内网端口/公网端口/映射”。详细的 NAT、Cloudflare、证书和 14 项协议特点统一放在“使用说明 / 协议特点”。“入口网络管理”提供 VPS 类型/端口池、单协议快速改端口、CDN/CF 优选、Cloudflare Origin Rules（手动登记或 API 自动部署）、CF 隧道/Argo 和 CDN 诊断；普通 VPS 与 NAT VPS 均可使用 Origin Rules，只有操作系统/NAT 公网端口映射仍为 NAT 专用。每一步输入 `0` 返回上一级，非法域名或端口会停留在当前输入层。

“安装 / 协议管理”中的增删改操作会停止旧协议进程并重写 Xray/Sing-box 配置，这是让新增、删除和端口修改生效的必要步骤；已有内核、证书、UUID 与订阅设置会保留，只有所选协议需要的内核文件确实缺失时才下载。重建前会创建事务快照，SSH 断线、命令中断或新配置校验失败时自动恢复旧配置和服务，成功后保留 `~/lun/.last_good_rebuild`。状态区会区分“运行中”“已安装但未运行”“内核已安装但当前协议未使用”和“未安装”。

安装、重建、单协议改端口和订阅改端口时，脚本会按实际监听协议自动同步系统防火墙，只放行当前需要的 TCP/UDP 端口。支持启用中的 UFW、Firewalld，以及具有 DROP/REJECT 入站策略的 iptables/iptables-nft；端口改变时会删除由风火轮创建的旧规则，完整卸载时一并清理。脚本不会关闭防火墙，也不会修改用户已有规则。原生自定义 nftables 无法可靠定位规则链时会提示手动处理。云服务商安全组、NAT 服务商公网端口映射仍属于外部控制面，必须由用户放行或建立映射。

Argo 隧道可在“入口网络管理” → “CF 隧道 / Argo”里单独设置。若没有 VMess WS 或 VLESS WS，菜单会引导直接添加一个可绑定协议，普通 VPS 默认端口为 `8080`，NAT VPS 默认内网端口为 `8080`。Argo 优选入口使用独立变量 `argoip`，不会复用普通 CDN 的 `cfip`；每个入口都会导出 TLS 443 和 HTTP 80 节点。该菜单的“诊断隧道回源”会同时检查本机 WebSocket 和 Cloudflare 下发的 Public Hostname Service，若控制台仍指向旧端口，会直接显示应改成的 `http://localhost:端口`。

## 快捷操作

安装后运行 `lun` 即可进入交互面板。面板内提供安装/协议管理、节点订阅分享、入口网络管理、服务与更新、高级设置、可选多用户管理、独立网站访问监控以及集中说明模块。

“服务与更新 → 更新 Lun 脚本”会显示检查进度、当前/远端版本和明确结果；内置更新优先通过 GitHub Contents API 获取主分支原始脚本，`raw.githubusercontent.com` 作为回退，并附加防缓存参数，避免部分地区 raw 边缘缓存滞后导致误报“最新版”。下载后先校验脚本语法再原子替换；远端版本低于本机时拒绝降级，更新完成后返回菜单而不是直接退出。

运行 `lun` 时会先完整显示一次原版 ASCII 轮胎开屏，并按终端空间自动选择小型 `72×12`、中型 `96×18` 或大型 `120×24` 版本。轮胎保持显示期间，脚本会把系统状态、协议、订阅信息和主菜单完整生成到受限临时缓冲区；全部准备好后自动清除开屏并一次性显示主菜单，不需要用户点击确认，也不依赖固定倒计时。主面板顶部永久保留紧凑主题“Lun · 风火轮多协议交互面板”和简介“多协议统一接入 · 多 VPS 集群联动 · 多用户精细管理”，不重复显示轮胎。开屏不设菜单选项，也不依赖 Kitty、WezTerm 或其它终端图片协议；非交互输出、`TERM=dumb` 或窗口空间不足时自动跳过，不影响 Lun 执行。

## 可选多用户管理

主菜单第 6 项是独立的可选模块。只有首次进入并确认安装后才会增加 Python 3、SQLite 用户数据库和 `lun-agent` 服务；不安装或停用模块时，普通风火轮的单用户协议、UUID 和 BusyBox 订阅行为保持不变。模块要求 systemd 或 OpenRC，无 init 环境会拒绝安装。

模块提供用户与设备、按指定日期重置的月额度、到期停用、协议权限、设备订阅、备份和诊断。用户列表与实时流量入口已合并为“用户与流量总览”，按“已用/月额度”显示并统一使用 G；内部仍兼容旧数据库中的永久总额度字段，但新界面不再配置或展示它。新增用户会自动创建第一台设备，每台设备使用独立 UUID、通用密码、Shadowsocks-2022 用户密钥和随机订阅 token。删除用户必须输入用户名称确认，并会立即撤销其设备、订阅及含该用户的自动数据库备份。

安装时会把现有 UUID 导入为 `legacy-admin / legacy-device`，服务器级 WS/XHTTP 路径和旧订阅 token 保持不变。Shadowsocks-2022 会优先从 NAT 映射或端口池自动选择一个空闲端口建立多用户入站，原端口继续服务旧客户端；没有空闲映射时不再阻塞整个模块，而是跳过多用户 Shadowsocks 节点并继续启用其他协议。

有匹配订阅地址的公开可信证书时，模块自动使用 HTTPS；否则会醒目提示风险并自动使用 HTTP 继续安装，不再要求输入文字口令。订阅服务只公开随机 token 路径，不提供目录列表或公网管理接口，并返回 `Subscription-Userinfo` 流量头。

多用户订阅启动前会停止占用同一端口的旧风火轮 BusyBox 订阅并清理其遗留自启动；因此升级后不会再由两个风火轮服务争抢 443。若端口仍被非风火轮程序占用，普通 VPS 会自动选择空闲端口，NAT VPS 只会从已有映射/端口池选择并同步公网端口、防火墙和订阅地址；没有可用映射时仅停止多用户订阅，不影响代理核心和独立网站监控。

启用多用户后，“节点订阅分享”的刷新入口会直接读取数据库中的本机设备 token 和多用户订阅端口，不再用旧 BusyBox 进程命令行判断状态，也不会继续读取可能过期的 `subtoken.log`。主界面只提示“token 按设备独立管理”；本机设备链接可直接刷新查看，其他设备的查看与轮换统一在“多用户管理”中完成。单用户 token/端口设置入口在多用户模式下会显示说明并拒绝覆盖设备级订阅。

Xray 使用本机 API 统计用户流量，配额或到期触发时优先动态移除 VLESS/VMess 用户；Xray Socks 和 Sing-box 结构变化会执行校验后的短暂重载。Sing-box 按用户流量统计需要同版本、增加 `with_v2ray_api` 标签的增强内核，可在模块维护菜单中安装。默认安全规则阻断私网、链路本地、云元数据和 TCP 25，TCP 465/587 保持允许；第一版只观察 BT，不自动处罚。

“动态公平带宽”对服务器到客户端的全部下载出口统一整形。用户填写全机总下载上限（Mbit/s），系统优先使用 CAKE 公平队列，不支持 CAKE 时回退 HTB 总量整形和 FQ-CoDel 公平排队。连接少时可借用剩余带宽，繁忙时自动公平共享。关闭模块限速或卸载模块时会删除根队列并恢复系统默认出口队列。

“网站访问监控”是主菜单第 7 项，与多用户订阅服务独立。普通单用户也可直接选择“一键开启 / 修复监控”，无需输入 `ENABLE` 或在启用时填写保留天数。它复用 Xray、Sing-box 的原生访问日志、现有 Python 代码和 SQLite 数据库，但由不监听任何网络端口的 `lun-visit-monitor` 服务独立采集；多用户订阅端口或证书失败不会中断采集。单用户界面显示“本机用户 / 本机设备”，以后启用多用户时会复用同一内部身份。

SQLite 记录仅包含时间、用户、设备、目标域名/端口、内核和网络类型，不保存完整 URL、路径、查询参数、正文或订阅 token；仅有 IP 的目标会被丢弃。核心原始访问日志可能短暂包含连接源/目标 IP，达到大小上限并完成采集后会自动截断。默认逐条明细保留 7 天、每日汇总保留 30 天，即第 8～30 天只保留每天连接某域名的次数，不再保留逐条时间记录。默认“智能活动”会隐藏明确的广告/分析/遥测域名，并将同一设备对同一域名端口的 TCP、UDP 和重连按连续 10 分钟合并；过滤只影响界面，原始连接仍可查看，也不会阻断代理流量。保留期限、合并窗口和自定义隐藏/始终显示域名都可在独立设置中调整。

部分新版 Xray 在 `loglevel: none` 时不会创建 access 日志；监控启用期间会把错误日志级别最低提升为 `warning`，只为确保访问日志可写，停用监控时恢复启用前设置。

该监控统计的是域名连接次数，不是每个网站的精确流量；用户总流量仍以现有 Xray/Sing-box 统计为准。受加密 DNS、ECH、客户端复用连接和应用直连 IP 等因素影响，域名记录可能不完整。数据库、日志和备份均属于敏感数据，仅供 root 本机管理。

## 可选服务器联动 / 节点集群

主菜单第 8 项是默认关闭的可选模块。同一份 Lun 脚本可把一台 VPS 设为主 VPS（控制器），把其余 VPS 设为子 VPS（受管节点）。各节点仍能独立运行；主子机之间只在配置、同步、订阅快照或流量达到上报阈值时通信，不依赖 SSH，也不发心跳包。

主界面使用自适应荧光黄/火焰橙终端面板：宽终端显示完整风火轮主题，窄终端自动切换紧凑标题，不依赖图片协议、特殊字体或终端插件。

子 VPS 会生成有效期 15 分钟、仅能使用一次的 `lunjoin://` 加入地址。主 VPS 首次连接会校验该地址内的 TLS 指纹，随后签发独立的 P-256 节点证书；正式通信全部使用 TLS 1.2+ 双向证书校验。通信端口只需 TCP，普通 VPS 自动选择未占用高位端口；NAT VPS 只从现有公网端口→内网端口映射中分配。默认排除 443，并自动同步 Lun 防火墙规则。

主 VPS 可查看子机 IP、备注、地区、版本、最后成功时间和订阅快照，并执行固定白名单动作：协议变量重建、Xray/Sing-box/Argo/订阅/多用户/网站监控进程的状态、启动、停止和重启、Lun 主脚本与联动程序校验下发、内核更新、防火墙同步、快照和恢复。联动服务本身只允许远程查看或重启，不允许远程停止，避免主 VPS 自行切断控制通道。远程端不接受任意 Shell 文本。批量任务先在第一台金丝雀节点执行，成功后最多 3 台并行；失败时自动恢复本轮已成功节点的配置快照。清空配置和卸载只允许单机执行，且会先在 root 主目录留恢复快照。

服务器总览使用从 `01` 开始的持久节点编号（输入时 `1`、`01` 均可，`0` 固定返回），状态、类型和常用国家/城市均显示中文。编号首次分配后同时保存到主机、子机和集群数据库；移除服务器只留下空号，不会重排或复用，恢复备份后也保持不变。手动修改地区时只需选择节点编号并输入“日本-大阪”“美国-洛杉矶”等中文地区，不再分别填写国家代码、地区和城市。NAT 主机输出聚合订阅时会把订阅服务的内网监听端口转换为服务商公网映射端口，避免把内网 `443` 错误输出成不可用的公网链接。

主 VPS 菜单提供“主 VPS / 子 VPS 角色互换”。切换前会确认所有服务器在线且联动程序均支持新版交接；当前主机随后为其他子机建立短时双授权，再把数据库和集群 CA 分片传给目标子机。目标验证全部节点后接管，旧主机才降为子机；失败会撤销临时授权并恢复两端控制面。角色变化不改变服务器编号、地区、UUID、协议端口或节点名称；聚合订阅链接需要改用新主 VPS 的公网地址和订阅端口。

个人订阅、多用户订阅和多服务器聚合订阅共用统一节点名称：`[地区]协议[-线路信息][-地址变体]-服务器编号`。例如 `[德国-法兰克福]vless-xhttp-tls-tcp-01`、`[德国-法兰克福]vless-xhttp-tls-tcp-cdn-tcp-443-cf01-01`。主机名、自定义备注和旧的 `[DE-master]` 不再写入节点名称；备注只在管理界面显示。地区首次生成订阅时自动识别，可在“节点订阅分享 → 服务器身份 / 节点命名”修改；已配对子机由主 VPS 统一下发地区和编号。日本大阪府内识别为 `Minoh/箕面` 的节点统一按“日本-大阪”显示，避免线路名称粒度过细。同一集群存在多台同地区 VPS 时，主 VPS 按服务器编号顺序自动加地区序号，例如两台大阪节点显示为 `[日本-大阪1]` 和 `[日本-大阪2]`；只有一台时仍显示 `[日本-大阪]`。该规则同步应用于个人、多用户、聚合订阅及集群节点列表。

主 VPS 可把多用户账号按节点授权。被授权的用户凭据、协议权限、月额度和到期时间会通过 mTLS 下发；子机中这些账号标记为“主 VPS 托管”，禁止本地修改。各节点保持绝对流量计数，默认每增加 10 GiB 才上报；用量达月额度 80% 后改为 5 GiB，95% 后改为 1 GiB。主 VPS 按设备 UUID 和结算周期幂等合并，并为全部节点、各地区和每个授权设备生成独立订阅 token。

“集群备份 / 加载备份”保存节点清单、用户授权、订阅档案、流量台账、审计记录、配置和全部 PKI。备份使用 PBKDF2-HMAC-SHA256（30 万次）派生密钥、AES-256-CBC 加密并附加 HMAC-SHA256 完整性校验；加载前另外保留一份仅 root 可读的本机恢复包。

## 协议与域名变量

变量值为空表示随机端口，填写数字表示指定端口。

| 协议 | 变量 | CDN 优选 | Origin Rules 端口回源 | CF 隧道 / Argo |
| --- | --- | --- | --- | --- |
| VLESS TCP Reality Vision | `vlpt` | 否 | 否 | 否 |
| VLESS XHTTP Reality ENC | `xhpt` | 否 | 否 | 否 |
| VLESS XHTTP ENC | `vxpt` | 是 | 是 | 否 |
| VLESS WS ENC | `vwpt` | 是 | 是 | 是 |
| Shadowsocks-2022 | `sspt` | 否 | 否 | 否 |
| AnyTLS | `anpt` | 否 | 否 | 否 |
| Any-Reality | `arpt` | 否 | 否 | 否 |
| VMess WS | `vmpt` | 是 | 是 | 是 |
| Socks5 | `sopt` | 否 | 否 | 否 |
| Hysteria2 | `hypt` | 否 | 否 | 否 |
| TUIC | `tupt` | 否 | 否 | 否 |
| VLESS XHTTP TLS UDP（H3-only） | `xupt` | 否 | 否 | 否 |
| VLESS XHTTP TLS TCP/UDP | `xcpt` | 是（TCP；实验 UDP 443） | 是 | 否 |
| NaiveProxy H2/H3 | `nvpt` | 否 | 否 | 否 |

这里的“CF 隧道 / Argo”指当前 Lun 已实现的普通 Public Hostname 节点，只绑定 VLESS WS 或 VMess WS。Cloudflare Tunnel 理论上还能发布其它 HTTP/TCP 服务，但那些模式不属于本项目现有节点输出。Origin Rules 只作用于 Cloudflare HTTP(S) 请求，因此 Reality、任意 TCP/UDP、QUIC/H3-only 和 Naive CONNECT 不能因为改写了端口就自动变成可用 CDN 协议。

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

启用 Origin Rules 端口回源后，如果普通节点地址与 `cdnym` 使用同一个域名，Lun 会自动让直连节点改用源站 IP；CDN/回源节点仍使用 `cdnym` 和 `cfip`。这样可避免橙云域名把 Reality、直连 TLS 等连接送到 Cloudflare 边缘。该保护同时适用于 NAT VPS 和普通 VPS，不改变 UUID、端口、证书、TLS SNI 或 HTTP Host。若确实需要域名直连，请单独准备一个 DNS-only（灰云）域名作为 `addym`。

**使用条件：**
1. 设置 `cdnym`：Cloudflare 接收请求时使用的 Host 域名。
2. 设置 `cfip`：可混合填写多个 IPv4、IPv6 或域名，也可直接粘贴 `108.162.198.211:2083#JP 电信优选[64ms 160Mbps]` 一类单行或多行测速结果。脚本会自动删除端口、`#` 备注、延迟/带宽说明并去重，只保存干净地址；原有 `1.1.1.1 2.2.2.2` 格式保持兼容。留空时只采用从已橙云 `cdnym` 解析到且不等于本机公网地址的 IP；无法确认橙云时不会再自动塞入第三方优选域名。
3. 客户端直接连接 `cfip` 时，不依赖客户端把 `cdnym` 解析到哪个地址，但 Host 对应的 DNS 记录仍必须开启橙云，Cloudflare 才会承载该 Host 并执行 Origin Rules。脚本以实际 CF 边缘诊断为准。
4. 一键 CDN 在只安装 XHTTP 类协议时使用 `cdnproto=xhttp`；检测到 VLESS WS 或 VMess WS 时自动切换为 `cdnproto=all`，同时生成对应 WS CDN 节点。`xcpt` 只在 Cloudflare HTTPS 边缘端口生成 CDN-TCP。

**`cdnproto=xhttp`：** VLESS XHTTP（非 Reality）与已启用的 VLESS XHTTP TLS
**`cdnproto=all`：** 在上项基础上额外生成 VMess WS、VLESS WS；菜单检测到已安装 WS 类协议时自动采用
**不支持普通 CDN 的协议：** Reality、XHTTP TLS UDP（`xupt`）、NaiveProxy、AnyTLS、Hysteria2、TUIC、Shadowsocks、Socks5（保留直连节点）

Cloudflare 橙云支持端口：

```text
HTTP（明文）：80、8080、8880、2052、2082、2086、2095
HTTPS（加密）：443、8443、2053、2083、2087、2096
支持但缓存已禁用：2052、2053、2082、2083、2086、2087、2095、2096、8880、8443
```

首次设置或新增支持 CDN 的协议时，端口回车随机会优先从未占用的 CF 官方端口中匹配：VLESS XHTTP、VLESS WS、VMess WS 使用 HTTP 端口组，XHTTP TLS TCP/UDP 使用 HTTPS 端口组；自动随机默认排除热门的 `443`。若端口池中没有可用 CF 端口，脚本会回退普通随机端口并用黄色提示后续必须配置 Origin Rules。`xupt`、Reality 和 NaiveProxy 仍按普通端口处理，不套普通 CDN。

**激进 443 测试模式：** 如果要测试 XHTTP TLS CDN-UDP 的 443 直回源，必须在协议端口提示处手动输入 `443`，不能依赖回车随机。443 可能已被 Nginx、Web 面板或其他服务占用；首次设置前请使用 `ss -ltnp` 或 `lsof -i:443` 查明 PID，确认业务影响后手动停止服务或 `kill` 对应 PID。Lun 不会自动杀掉未知占用进程。`xcpt=443` 时为 443→443，不需要 Origin Rule；若 443 不能献祭，则使用其他 HTTPS 源站端口，并为 Cloudflare 边缘 443 配置 Origin Rule。

普通 VPS 在协议端口本身属于 Cloudflare 官方端口时可以继续使用同端口 CDN；协议端口不适合 CF 时，脚本自动启用 Origin Rules。XHTTP TLS 的实验 CDN-UDP 固定需要 Cloudflare 边缘 `443`，但源站不必监听 `443`，可用 Origin Rule 将 `443` 回源到随机 HTTPS 源站端口。普通 VPS 的规则目标是本机协议监听端口，NAT VPS 的规则目标是该协议的 NAT 公网映射端口。例如 `xcpt` 为内网 `8080`、映射 `56567 → 8080` 时，XHTTP TLS 节点使用 Cloudflare 边缘 `443`，而 Origin Rule 的目标端口填写公网 `56567`。不要把内网 `8080` 当成 TLS 节点边缘端口，也不要只按 HTTP/HTTPS 分流；必须使用菜单输出的 `http.host + ssl + UUID-xc Path` 精确表达式。普通明文 `vxpt` 才使用 `UUID-vx` 及其对应的 HTTP 边缘端口。

NAT VPS 需要先在服务商/端口转发处建立“公网端口 → 内网监听端口”。随后进入 `lun → 入口网络管理 → Cloudflare Origin Rules`：已经在 Cloudflare 控制台建好规则时选“手动登记已设置的规则”，输入客户端使用的 CF 边缘端口和规则里的 Destination port；尚未配置时可选“一键自动部署 / 修复”。Lun 会核对 NAT 公网端口确实映射到所选协议，风火轮则自动放行系统防火墙中的内网监听端口；服务商安全组与公网 NAT 映射仍属于外部控制面。若公网映射本身不是 CF 官方边缘端口，也可以作为 Origin Rules 的回源目标，不能把内网端口直接写成 CDN 节点端口。

手动登记不需要 Cloudflare API Token。自动配置应从“我的个人资料 → API 令牌 → 创建自定义令牌”创建**用户 API 令牌**，不要使用账户 API 令牌。按 Cloudflare 当前界面添加四行：`区域 → 区域 → 读取`、`区域 → Origin Rules → 编辑`、`区域 → DNS → 编辑`、`区域 → 区域设置 → 编辑`，区域资源只选择当前域名。脚本只需要创建结果中的令牌正文，不需要 Token ID、用户 ID、账户 ID或邮箱；输入时会直接显示。令牌之后保存在 `~/lun/cdn_cloudflare_token`（权限 `600`）。

一键部署会自动开启该 Host 的橙云，按 `Host + 边缘端口 + TLS + UUID Path` 写入精确回源规则，将规则排在现有规则之后，按证书设置 Full/Full (Strict)，在 XHTTP TLS 443 模式开启 HTTP/3，等待生效后验证并刷新订阅。脚本只替换同一 Host 的旧 `tls/nottls` 宽泛规则及自身创建的规则，其它用户规则会保留；更新规则前会在 `~/lun/cdn_cloudflare_backup.json` 保存快照，API 中途失败会自动回滚。

“手动登记已设置的规则”会保存 Host、协议、CF 边缘端口、回源目标端口和 UUID Path，不修改 Cloudflare。以 NAT 映射 `56567→8080` 为例：VLESS XHTTP 的控制台规则若已设置为边缘 `8080`、Destination port `56567`，就在菜单输入 `8080` 和 `56567`。重建后 Lun 信任这项登记并直接输出对应 CDN-TCP 节点；XHTTP TLS 的实验 CDN-UDP 仍必须经过 HTTP/3 实测，不会仅凭手动登记伪造。

“输入单协议回源端口”支持直接粘贴 NAT 公网端口。例如输入 `56567` 且现有映射为 `56567→8080` 时，Lun 会自动把所选协议的真实监听端口迁移到内网 `8080`，重建配置并将 Cloudflare 回源目标设为公网 `56567`；普通 VPS 则直接迁移到输入端口。若多个协议错误共用同一内网端口，“一键自动部署 / 修复”会优先从未占用的 NAT 映射和对应 CF HTTP/HTTPS 端口中自动拆分，避免 Xray `SO_REUSEPORT` 随机命中错误入站。

HTTPS 端口组会让 Lun 为 CDN 兼容入站启用源站 TLS。自签证书在 Cloudflare 使用 Full；匹配 Host 的公开 CA 或 Cloudflare Origin CA 证书可使用 Full (Strict)。切换边缘端口只重建配置并重启服务，不重新下载内核。

`xcpt` 的 CDN-TCP 只会在 Cloudflare 官方 HTTPS 边缘端口生成。实验性 CDN-UDP 只会在边缘端口严格为 `443` 且实测入口公布 HTTP/3 时生成，因为 HTTP/3 使用 QUIC/UDP 443。手动填写 CF 优选 IP 只会改变客户端连接的边缘地址，不能替灰云 Host 创建 Cloudflare 路由；灰云偶尔命中仍留存的边缘配置不属于官方保证。稳定用法是让 Host 开启橙云，并以 Lun 的实际连通诊断为准。若条件不满足，脚本只显示警告，不会把 UDP 节点伪装成可用配置。参考 [Cloudflare HTTP/3](https://developers.cloudflare.com/speed/optimization/protocol/http3/) 与 [Cloudflare 代理端口](https://developers.cloudflare.com/fundamentals/reference/network-ports/)。

刷新订阅时，未手动登记的 XHTTP TLS 会用首个 Cloudflare HTTPS 入口作为快速样本，对比本机 Xray 与边缘响应。首项失败会立即停止，不再逐个等待全部优选 IP；首项成功后其余 IP 复用同一 Host 和规则直接生成。只有实测入口公布 HTTP/3 时才输出实验 CDN-UDP。手动登记的规则直接生成 CDN-TCP，但不会据此伪造 CDN-UDP。

**示例：**

普通 VPS：

```bash
vxpt="" cdnym="proxy.example.com" cfip="108.162.198.31 2606:4700::6810:1234" cdnproto="xhttp" bash <(curl -Ls https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```

普通 VPS 的 XHTTP TLS 随机源站端口会优先分配未占用的 Cloudflare HTTPS 端口（默认排除 443）；可直接测试 HTTPS CDN-TCP：

```bash
xcpt="" cdnym="proxy.example.com" cfip="108.162.198.31" bash <(curl -Ls https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```

需要实验 CDN-UDP 时，进入 Origin Rules 选择一键部署即可：若 `xcpt` 不是 443，Lun 自动把边缘 `443` 按 `UUID-xc` Path 回源到该 XHTTP TLS 源站端口；若 `xcpt=443` 则使用 443→443，并自动开启 HTTP/3。手动 CF 优选 IP 不能替灰云 Host 建立边缘路由，一键部署会自动开启橙云并执行连通诊断。

NAT VPS Origin Rules：

```bash
vpsmode="nat" vxpt="8080" ptmap="56567-8080" cdnym="proxy.example.com" cfip="108.162.198.31" cdnmode="rewrite" cdnpt="8080" cdnproto="xhttp" bash <(curl -Ls https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```

XHTTP TLS + NaiveProxy（`24443/UDP`、`25443/TCP`、`26443/TCP+UDP`）：

```bash
domain="proxy.example.com" certmode="domain" xupt="24443" xcpt="25443" nvpt="26443" bash <(curl -Ls https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```

HTTP 端口组节点会显式写入 `security=none`，HTTPS 端口组节点写入 TLS。节点名称同时包含边缘模式、端口和 `cf01/cf02` 优选入口序号，避免 v2rayN 在切换模式后沿用旧的 TLS/Reality/PublicKey 字段。新版 CDN 名称不再显示冗长的 `DOMAIN/IPv4/IPv6` 和主机名；显式填写的域名入口仍会正常保留。

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

只输出一种地址时，节点名不显示地址类型；同一协议同时输出多个地址时，使用紧凑的 `D4`、`V4`、`V6` 区分域名、IPv4 和 IPv6。CDN 节点继续只使用 `cfip`，Argo 节点继续只使用 `argoip`，并分别使用 `cf01`、`ar01` 这类候选编号区分入口。

当 `cdnmode=rewrite` 且所选直连域名与 Origin Rules 的 `cdnym` 相同时，橙云域名不会写入直连节点：`domain` 自动切换为可用源站 IPv4（无 IPv4 时用 IPv6），`all` 只保留源站 IPv4/IPv6。NAT VPS 使用映射后的公网端口，普通 VPS 使用协议监听端口；两者都使用源站 IP 作为直连地址。CDN 和端口回源节点不受此切换影响。

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

订阅地址默认只输出 IPv4。单用户模式可在 `lun` → `节点订阅分享` 中修改订阅 token/端口、切换 `ipv4`、`ipv6`、`both`，或进入“服务器身份 / 节点命名”查看编号、自动识别及手动修正地区；多用户模式的 token 按设备管理，应在“多用户管理”中查看或轮换。无 IPv6 时会自动跳过 IPv6 订阅地址。NAT VPS 下订阅 URL 会显示公网端口，服务仍监听内网端口。刷新时会识别订阅自身的 httpd 或 `lun-agent`，不会把原端口误判为协议占用；若确实撞到协议或外部进程，会从完整映射/端口池中自动选择空闲端口，普通 VPS 的自动随机端口使用 `20000-65535`。修改订阅或服务器身份时只刷新分享文件和相关服务，不会改变 UUID、协议端口、证书或代理参数。

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
