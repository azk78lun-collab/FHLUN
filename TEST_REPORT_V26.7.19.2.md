# 风火轮 V26.7.19.2 测试报告

测试日期：2026-07-19  
测试环境：Ubuntu 24.04.4 LTS，amd64，161.33.1.16  
测试目标：将 `xcpt` 献祭到 TCP 443，验证 XHTTP-TLS CDN-TCP 与实验 CDN-UDP 的 443 直回源路径。

## 结果

- 测试前已保存快照：`/root/fhlun-443-test-20260719T042737Z`。
- 已停止占用 443 的 Nginx；当前 443 由 Xray 接管，`xcpt=443`。
- Xray `run -test`：通过，返回 `Configuration OK`。
- Sing-box `check`：通过。
- Xray、Sing-box：运行中。
- Cloudflare 入口 `108.162.198.17`、`108.162.198.129`、`162.159.39.173` 的 HTTPS 443 请求均返回 Cloudflare 响应，并匹配 `Host + UUID-xc Path` 回源到 Xray。
- 三个入口均公布 `alt-svc: h3`；订阅生成 CDN-TCP-443 与实验 CDN-UDP-EXP-443 节点。
- 本次 443→443 直回源没有使用 Origin Rule。

## 本地检查

- `lun.sh` Shell 语法：通过。
- `index.html` 内嵌 JavaScript 语法：通过。
- `git diff --check`：通过。

## 限制

测试机自带 curl 8.5.0 未编译 HTTP/3 客户端支持，因此本报告确认的是 Cloudflare 443 回源、HTTP/3 广播和 Xray/Sing-box 配置；v2rayN 的真实 H3 代理访问仍需客户端导入 `CDN-UDP-EXP-443` 节点后实测。

测试期间 Nginx 保持停止，以便继续使用 443 验证。恢复原状态时，先在 `lun` → `入口网络管理` → `VPS 类型 / 端口池 / 快速改端口` 中把 `xcpt` 改回原端口 `2096`，确认 Xray 已释放 443 后再执行：

```bash
sudo systemctl start nginx
```
