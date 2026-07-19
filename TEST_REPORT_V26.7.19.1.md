# 风火轮 V26.7.19.1 测试报告

测试日期：2026-07-19

## 本轮范围

- Cloudflare 官方 HTTP/HTTPS 端口完整校验与自动选择。
- 普通 VPS 和 NAT VPS 共用 Origin Rules 回源端口改写。
- 混合协议自动拆分边缘端口：原有 XHTTP 使用 HTTP `8080`，XHTTP TLS 使用 HTTPS `443`。
- 节点订阅分享菜单合并重复的刷新入口。
- 入口网络管理增加单协议快速改端口。
- 停止自动注入未经验证的第三方 CDN 域名入口。
- 修复 `pgrep -f 'lun/(s|x)'` 会把 `/root/lun/sub...` 误判为内核进程的问题。

## 本地检查

- `bash -n lun.sh`：通过。
- `index.html` 内嵌 JavaScript `node --check`：通过。
- `git diff --check`：通过。
- CDN 端口单元场景：通过。
  - 仅 `xcpt` 随机/非 CF 源站端口：自动 `rewrite:443`。
  - `xcpt` 源站端口为 CF HTTPS 端口：保留 `standard`。
  - 原有 XHTTP 非 CF 源站端口：自动 `rewrite:8080`。
  - 原有 XHTTP `8080`：保留 `standard`。
  - XHTTP + XHTTP TLS 混装：默认边缘 `8080`，XHTTP TLS 单独使用 `443`。
  - NAT 公网端口已经是 CF HTTPS 端口：保留 `standard`。

## 测试机验证

测试机：`161.33.1.16:12222`

- 事务重建：通过；`~/lun/.last_good_rebuild` 存在。
- 首次自动化调用因旧进程正则误判而触发回滚，原配置和服务成功恢复；修复正则后再次事务重建成功。
- Xray `run -test`：通过。
- Sing-box `check`：通过。
- `xr`、`sb`、`nginx`：均为 `active`。
- 监听回归：
  - TCP：`8080`、`44937`、`49751`、`60446`。
  - UDP：`16987`、`38925`、`44440`、`60446`。
- CDN 订阅输出：
  - 原有 XHTTP HTTP `8080` V4 节点：3 条。
  - XHTTP TLS CDN-TCP HTTPS `443` V4 节点：3 条。
  - 实验 XHTTP TLS CDN-UDP `443` V4 节点：3 条。
  - CDN `DOMAIN` 节点：0 条。
- 快速改端口菜单：选择 `xcpt` 并输入原端口时正确提示“端口未改变”，未停止服务；`xr`、`sb` 仍为 `active`。
- 测试前脚本备份：`/root/lun/lun.V26.7.18.1.pre-V26.7.19.1`。

## 待用户外部测评

- XHTTP TLS CDN-TCP `443` 需要在 Cloudflare 配置菜单输出的 Host + `UUID-xc` Path 规则，把目标端口改写到源站 `49751`。
- 实验 CDN-UDP 还需要橙云代理和 Cloudflare HTTP/3；当前脚本只生成满足 UDP `443` 条件的节点，不代表外部 Cloudflare 配置已经完成。
- 当前未修改 Cloudflare 控制台，也未推送 GitHub。

## v2rayN `-1` 复测与修正

用户外部测评反馈三组 XHTTP TLS CDN-TCP/UDP 以及旧 `DOMAIN` 节点均显示 `-1`。服务器复测结果：

- 当前 `jhsub.txt` 的 CDN `DOMAIN` 节点计数已经是 0；v2rayN 中的旧 `DOMAIN` 名称属于客户端缓存或以前手动导入的节点。
- 本机 `xcpt:49751` 的 Xray 探测响应为 HTTP `404`、空响应体。
- 三个 Cloudflare HTTPS 443 入口均返回带 `server: cloudflare` 的 HTTP `404`，但响应体为 162 字节，与 Xray 入站不一致，证明请求落到了其它 443 服务而不是 `xcpt:49751`。
- 根因是 Cloudflare 尚未配置或尚未命中 Host + `UUID-xc` Path → `49751` 的 Origin Rule，不是 Xray 配置或端口监听故障。

修正后，订阅生成器会逐个比较 Cloudflare 边缘响应与本机 Xray 入站指纹；未真正回源到 Xray 的入口不再输出 CDN-TCP/UDP 节点。实验 UDP 还额外要求该已验证入口公布 HTTP/3。

修正版已部署到测试机并重新执行 `lun list`：

- XHTTP TLS CDN-TCP：0 条。
- XHTTP TLS CDN-UDP：0 条。
- CDN `DOMAIN`：0 条。
- 原有 XHTTP-ENC HTTP `8080` V4：3 条。
- XHTTP TLS 直连 UDP/TCP：各 1 条。
- Xray `run -test` 与 Sing-box `check` 再次通过，`xr`、`sb`、`nginx` 均为 `active`。
- Cloudflare Origin Rule 生效后重新刷新订阅，只有通过回源探测的入口才会恢复输出 CDN 节点。
