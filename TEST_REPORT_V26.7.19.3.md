# 风火轮 V26.7.19.3 测试报告

测试日期：2026-07-19  
测试环境：Ubuntu 24.04.4 LTS，amd64，161.33.1.16  
测试目标：将 FHLUN IPv4/IPv6 核心镜像 Nginx 的 HTTPS 从 443 迁移到 8443，为 Xray XHTTP-TLS CDN-UDP 保留 443。

## 结果

- Nginx 配置已保存快照：`/root/fhlun-nginx-8443-test-20260719T050448Z`。
- Nginx `nginx -t`：通过，服务运行中且已启用开机启动。
- Nginx HTTPS 监听：`0.0.0.0:8443` 与 `[::]:8443`。
- Nginx HTTP 80 与 `[::]:80` 保留，用于 ACME HTTP-01。
- Xray 继续监听 TCP 443；与 Nginx 8443 无端口冲突。
- `https://oracle1.1223344.xyz:8443/fhlun/cloudflared-linux-amd64` IPv4 返回 200，下载大小 39261733 字节。
- 同一 URL IPv6 返回 200，下载大小 39261733 字节；IPv4/IPv6 SHA-256 均为 `ec905ea7b7e327ff8abdde8cb64697a2152de74dbcdbf6aec9db8364eb3886cd`。
- IPv6 解析到 `2603:c023:14:567e:0:ab78:78ff:87d1`，直连下载验证通过。

## 项目同步

- `coremirror` 默认地址已改为 `https://oracle1.1223344.xyz:8443/fhlun`。
- 仓库新增 [`deploy/nginx/fhlun-core-mirror-8443.conf`](deploy/nginx/fhlun-core-mirror-8443.conf)。
- 443 继续保留给 `xcpt` 的 XHTTP-TLS CDN-UDP 测试。

