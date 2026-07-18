# 风火轮 V26.7.18.1 测试报告

- 日期：2026-07-18
- 分支：`codex/fhlun-xhttp-tls-naive`
- 测试机：`161.33.1.16:12222`
- 参考上游：`yonggekkk/argosbx@433f7be18f77c4bd51ccd817265f2c93da15353f`

## 范围

本次只移植并验证以下协议及必要配套：

- `xupt`：VLESS XHTTP TLS UDP
- `xcpt`：VLESS XHTTP TLS TCP/UDP
- `nvpt`：NaiveProxy H2/H3

未修改 `container/nodejs`、SAP/Cloud Foundry 脚本，也未同步上游附带的 Hysteria2 内核分配、CDN 默认地址和订阅 DNS 调整。FHLUN 与参考上游使用的 Xray、Sing-box Release 资产哈希一致，因此未更新内核；最终测试版本仍为 Xray `26.3.27`、Sing-box `1.13.14`。

## 本地检查

| 检查项 | 结果 |
| --- | --- |
| `lun.sh` Shell 语法 | PASS |
| `index.html` 内嵌 JavaScript 语法 | PASS |
| `index.html` HTML ID 唯一性 | PASS |
| 新变量、状态文件、入站标签和菜单/清理/恢复接线完整性 | PASS |
| `git diff --check` | PASS |

## 测试机部署

部署前保留了测试机原有节点并创建外部备份及事务快照。测试使用 `/root/ygkkkca` 中与服务域名匹配的公开 Let’s Encrypt 完整证书链；证书链通过系统 CA 信任库验证。

最终增量端口：

| 协议 | 端口与传输 | 入站标签 |
| --- | --- | --- |
| XHTTP TLS UDP | `16987/UDP` | `xhttp-h3` |
| XHTTP TLS TCP/UDP | `49751/TCP`（源站） | `xhttp-h23` |
| NaiveProxy H2/H3 | `60446/TCP+UDP` | `naive-sb` |

Xray `run -test` 与 Sing-box `check` 均通过，`xr.service`、`sb.service`、Nginx 和订阅 HTTP 服务保持正常。

## 新协议真实代理测试

所有测试均通过本机隔离 SOCKS 客户端访问外部 HTTPS 204 探测地址，不只做配置静态校验。

| 链路 | 结果 |
| --- | --- |
| XHTTP TLS TCP（ALPN `h2,http/1.1`） | PASS |
| XHTTP TLS H3/UDP（ALPN `h3`） | PASS |
| NaiveProxy H2/TCP | PASS |
| NaiveProxy H3/QUIC | PASS |

第一次 Naive 客户端测试发现服务器安装目录中的 Sing-box 单文件缺少客户端 Naive 出站所需的 `libcronet.so`。保护流程按约定完整回滚，确认旧节点恢复后重新部署；第二次使用 Sing-box `1.13.14` 官方 Linux 发行包中的客户端与 `libcronet.so` 完成测试并全部通过。该动态库只影响以 Sing-box 作为 Naive 客户端出站的场景，服务端 Naive 入站已由现有内核正常承载。

## 原有功能回归

| 项目 | 结果 |
| --- | --- |
| XHTTP Reality（原端口 `44937`）真实代理 | PASS |
| VLESS XHTTP ENC（原端口 `8080`）真实代理 | PASS |
| Hysteria2（原端口 `44440`）真实代理 | PASS |
| TUIC（原端口 `38925`）真实代理 | PASS |
| Nginx HTTP 80 / HTTPS 443 | PASS |
| Clash、Sing-box、聚合订阅 HTTP 端点 | PASS |
| 官方 Sing-box `check` 校验实际生成的 `sbox.json` | PASS |
| YAML 解析器校验实际生成的 `clmi.yaml` | PASS |
| 原有与新增 TCP/UDP 监听 | PASS |
| `.last_good_rebuild` 事务快照 | PASS |

订阅检查结果：

- 聚合订阅包含 XHTTP TLS UDP、XHTTP TLS TCP 和四种 Naive 分享链接。
- Clash/Mihomo 订阅包含 XHTTP TLS 节点，不包含不受支持的 Naive 节点。
- Sing-box 订阅包含 Naive H2/H3 节点，不生成当前 Sing-box 1.13 不支持的 VLESS XHTTP 出站伪配置。

## Cloudflare CDN 状态

测试时服务域名仍直接解析到源站地址，HTTPS 响应也未检测到 Cloudflare 代理标记。按测试计划未修改 Cloudflare DNS 或 HTTP/3 设置，因此 CDN-TCP 与实验性 CDN-UDP 的公网链路实测记为外部配置阻塞，不计为核心协议失败。

当前非 443 CDN 条件下，订阅中的实验性 CDN-UDP 节点数量为 `0`，符合“不满足 UDP 443、橙云和 HTTP/3 条件时不生成伪可用节点”的要求。

## 最终状态

- 测试机保留 `V26.7.18.1` 和三项新增协议。
- 测试机 `/usr/bin/lun` 与本地 `lun.sh` 的 SHA-256 完全一致。
- 原有节点、Nginx 与订阅服务均保持可用。
- 公开证书、服务配置和事务快照验证通过。
- 未推送 GitHub，未发布 Release，未修改 Cloudflare。
