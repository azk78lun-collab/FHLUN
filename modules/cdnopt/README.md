# Lun 一键优选 CDN 节点 2.0

该模块只在用户进入“Lun 入口网络管理 → 一键优选 CDN 节点”后按需下载，不安装常驻服务。

工作流程：

1. VPS 实时读取 [BestCF 聚合库](https://github.com/DustinWin/BestCF)，也可切换 CMLiu、AS13335、AS209242 或手工候选；联网失败时使用仅 root 可读的最近成功缓存。
2. VPS 启动一个带随机 token、默认 15 分钟过期的临时 HTTP 页面。
3. 浏览器测量“客户端 → Cloudflare 边缘”，VPS 同时通过 `speed.cloudflare.com` 测量“服务器 → Cloudflare 边缘”。
4. 客户端榜和 VPS 榜分别按带宽降序、延迟升序排列，不合成分数；默认勾选客户端榜前 N 项，也可跨榜选择。
5. 应用前展示新增、保留和删除差异；预览摘要校验通过后，主脚本才把裸 IP 写入 `~/lun/cdnip` 并重建订阅。

VPS 测速不能代表客户端线路，所以两个榜单始终独立显示。页面支持 IPv4/IPv6、端口备注、CIDR、IP 区间、筛选排序、复制和 CSV；测试端口只用于探测，不会保存到 CDN 优选池。

客户端探测兼容 [cmliu/edgetunnel](https://github.com/cmliu/edgetunnel) 的 BestCF/HiDNS 方案；VPS 测速使用 [Cloudflare Speedtest](https://github.com/cloudflare/speedtest) 下载端点。本模块是独立轻量实现，没有复制第三方管理面板、广告或订阅功能。
