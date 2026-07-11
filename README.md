# 风火轮

风火轮 是一个基于 Sing-box、Xray 和 Cloudflared 的终端代理节点脚本，核心逻辑基于开源项目二次开发/优化。它支持变量式无交互安装，也支持通过 `lun` 进入引导式菜单完成安装、证书、订阅、Argo、WARP、端口和节点输出管理。

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
0. 退出
```

引导式安装会按轻量流程询问 VPS 类型、端口池、协议/端口、服务域名、证书模式、节点订阅分享并最终确认。普通 VPS 只显示“端口/端口池”；只有选择 NAT VPS 后才显示“内网端口/公网端口/映射”。CDN / 优选 IP 和 CF 隧道 / Argo 都在“入口网络管理”里单独配置。每一步都会显示当前已选内容；输入 `0` 返回上一级，非法域名或端口会停留在当前输入层。二次进入引导时可保留、新增、改端口或删除已有协议。

Argo 隧道可在“入口网络管理” → “CF 隧道 / Argo”里单独设置。若没有 VMess WS 或 VLESS WS，菜单会引导直接添加一个可绑定协议，普通 VPS 默认端口为 `8080`，NAT VPS 默认内网端口为 `8080`。Argo 优选入口使用独立变量 `argoip`，不会复用普通 CDN 的 `cfip`。

## 快捷操作

安装后运行 `lun` 即可进入交互面板。面板内提供安装/协议管理、节点订阅分享、入口网络管理、服务与更新、高级设置等功能。

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

示例：

```bash
vlpt="" vmpt="" hypt="" bash <(curl -Ls https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```

服务域名与证书：

| 变量 | 用途 |
| --- | --- |
| `domain` | 服务域名，用于 ACME 域名证书、TLS 节点 SNI，并默认作为普通节点客户端地址 |
| `certmode` | `self`、`domain`、`dns`、`ip`，默认 `self` |
| `acme_email` | Let’s Encrypt 账户邮箱 |
| `acme_dns` | acme.sh DNS provider，例如 `dns_cf`、`dns_ali` |

`certmode=self` 会生成本地 ECDSA 自签证书。`domain` 使用 HTTP-01，要求域名 A/AAAA 已解析到本机且 80 端口可访问。`dns` 使用 acme.sh 原生 DNS API。`ip` 使用 Let’s Encrypt short-lived IP 证书，仅走 HTTP-01。

DNS API 凭据按 acme.sh 原生环境变量保存到 `/root/lun/cert.env`，权限为 `600`。

Reality、Argo 和 CDN 仍然独立：

| 变量 | 用途 |
| --- | --- |
| `reym` | Reality / Any-Reality 的 SNI 伪装域名 |
| `cdnym` | CDN 回源 Host 域名（已解析到 VPS 的域名，CF 通过它回源到你的服务器） |
| `argo` | 填写 `vmpt` 或 `vwpt` 启用 Argo |
| `agn` | Argo 固定隧道域名 |
| `agk` | Argo 固定隧道 token |
| `cfip` | CDN 优选 IP 或域名（客户端连接的 CF 入口地址），可填多个值，推荐 `cloudflare-ech.com` |
| `argoip` | Argo 优选 IP 或域名（与 cfip 独立），可填多个值 |
| `cdnmode` | `standard` 同端口模式；`rewrite` 为 NAT 回源端口改写模式 |
| `cdnpt` | NAT 改写模式的 Cloudflare 边缘端口：`8080` 或 `2096` |
| `addrmode` | 普通节点地址输出：`domain`、`ipv4`、`ipv6`、`dual`、`all` |

`agk` 可直接粘贴完整的 `cloudflared.exe service install ey...` 命令，脚本会自动提取 `ey...` token。

### CDN 优选 IP 加速说明

CDN 优选 IP 的工作原理：客户端连接 Cloudflare 优选地址（节点里的 `add/cfip`），Cloudflare 通过回源域名（`host/cdnym`）回源到你的 VPS。服务器访问外网默认仍直连 VPS；只有启用 WARP 出站时，目标网站才可能显示 WARP/Cloudflare IP。

启用 CDN Host 不会强制把普通节点地址改回服务器 IP；如果你设置了 `domain/addym`，订阅里的直连节点仍可继续使用域名。CDN 节点会额外使用 `cfip` 作为 Cloudflare 入口地址。

**使用条件：**
1. 设置 `cdnym`：一个已解析到 VPS IP 的域名（用于 CF 回源）
2. 在 Cloudflare 为该域名开启橙云；灰云只做 DNS 解析，不能把手动填写的 Cloudflare 优选 IP 回源到 VPS
3. 设置 `cfip`（可选）：可混合填写多个 IPv4、IPv6 或域名，脚本会去重并为每个入口生成唯一节点名
4. 选择同端口或 NAT 端口改写模式

**支持 CDN 的协议：** VMess WS、VLESS WS、VLESS XHTTP（非 Reality）
**不支持 CDN 的协议：** Reality、AnyTLS、Hysteria2、TUIC、Shadowsocks、Socks5（保留直连节点）

Cloudflare 橙云支持端口：

```text
HTTP（明文）：80、8080、8880、2052、2082、2086、2095
HTTPS（加密）：443、8443、2053、2083、2087、2096
```

**推荐 CDN 优选域名：** `cloudflare-ech.com`、`www.visa.com.sg`、`www.wto.org`、`www.web.com`（也可使用 CF 优选 IP）

同端口模式下，客户端连接端口与 NAT 公网回源端口相同，该公网端口必须在上述 Cloudflare 列表内。

NAT 端口改写模式用于运营商没有分配 CF 官方公网端口的情况：客户端连接 Cloudflare 的 `8080` 或 `2096`，再通过 Cloudflare Origin Rule 按 Host 和协议 Path 把目标端口改写为 NAT 公网映射端口。例如协议映射为 `56567 → 8080` 时，客户端节点使用边缘端口 `8080`，Origin Rule 的目标端口填写 `56567`。脚本会在 CDN 菜单中显示每个协议对应的准确规则。

`2096` 会让 Lun 为 CDN 兼容入站启用源站 TLS。自签证书在 Cloudflare 使用 Full；证书有效且主体与回源 Host 一致时可使用 Full (Strict)。切换 `8080/2096` 只重建配置并重启服务，不重新下载内核。

**示例：**

```bash
vmpt="" cdnym="proxy.example.com" cfip="108.162.198.31 2606:4700::6810:1234 cloudflare-ech.com" cdnmode="rewrite" cdnpt="8080" bash <(curl -Ls https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```

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

安装后也可通过 `lun` → `入口网络管理` → `NAT 手动映射` 修改或清除。

## 端口池

普通 VPS 只需要设置一个端口池，协议端口和节点订阅分享端口随机时会直接从池内取值。NAT VPS 推荐使用 `inpool/outpool` 分别设置内网端口池和外网端口池；设置外网端口池后，会按位置自动映射到内网端口池，只改变客户端看到的端口，不写 iptables。随机取端口时会跳过已被当前协议、订阅服务或 NAT 映射占用的端口；手动输入重复端口或重复映射会被拒绝并要求重填。

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

订阅地址默认只输出 IPv4。可在 `lun` → `节点订阅分享` 中修改订阅 token/端口，或切换为 `ipv4`、`ipv6`、`both`；无 IPv6 时会自动跳过 IPv6 订阅地址。NAT VPS 下订阅 URL 会显示公网端口，服务仍监听内网端口。修改订阅 token、端口或 IP 输出模式时只刷新分享文件、软链和本地 httpd，不会重装内核或重建协议。

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
- **sing-box** ([SagerNet/sing-box](https://github.com/SagerNet/sing-box)) — 提供 Hysteria2 / Tuic / AnyTLS / Shadowsocks 等协议内核
- **甬哥的 argosbx** ([yonggekkk/argosbx](https://github.com/yonggekkk/argosbx)) — 本项目原始脚本来源，感谢甬哥（@yonggekkk）开源的 argosbx 脚本框架

感谢以上项目的开发者与维护者，正是他们的开源精神让本项目成为可能。
