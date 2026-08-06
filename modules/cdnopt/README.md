# Lun 一键优选 CDN 节点

该模块只在用户进入“Lun 入口网络管理 → 一键优选 CDN 节点”后按需下载，不安装常驻服务。

工作流程：

1. VPS 从 [CM IP 候选库](https://github.com/cmliu/cmliu/blob/main/CF-CIDR.txt) 生成本轮待测 IP。
2. VPS 启动一个带随机 token、默认 15 分钟过期的临时 HTTP 页面。
3. 用户用真正需要优化的电脑/手机网络打开页面，浏览器测量“客户端 → Cloudflare 边缘”延迟和下载带宽。
4. 页面默认剔除延迟超过 `150 ms` 或带宽低于 `80 Mbps` 的结果，以带宽为主、延迟为惩罚返回综合最快节点。
5. 用户点击“应用到 Lun”后，临时服务结束，主脚本把结果写入现有 `~/lun/cdnip` 配置并重建订阅。

VPS 到 Cloudflare 的 ping/带宽不能代表客户端的线路。VPS 只负责临时页面、候选数据和结果校验；不会把“VPS 测得快”伪装成“用户本地快”。

在线探测协议参考 [cmliu/edgetunnel](https://github.com/cmliu/edgetunnel) 的 BestCF 在线优选，候选数据使用 CM IP 节点包；页面内保留 HiDNS、@ktff、@Lfreea 贡献致谢。本模块是独立轻量实现，没有复制 edgetunnel 的整套管理面板。
