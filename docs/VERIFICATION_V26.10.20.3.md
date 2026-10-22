# V26.10.20.3 验收记录 / Verification

日期：2026-10-20。主脚本 `V26.10.20.3`，集群程序 `0.3.3`；多用户程序 `0.4.2`，CDN 优选程序 `2.0.5`。没有发布或替换 Release 内核。

服务器以 A/B 匿名表示；具体地址、服务端口、节点身份及回滚路径不在公开报告中记录。

## 自动回归

- 原生 Linux 离线回归覆盖多用户 61、集群 128、CDN 18、Cloudflare/网络隔离 3，共 210 项 Python 用例；其中 2 项可选真实内核用例另行启用，链路专项 25 项通过。浏览器 JavaScript 检查通过。
- 13 组 Shell 测试通过，涵盖原生符号链接、可执行入口、菜单、证书、防火墙、带宽队列及事务保护。
- 新增覆盖：缺少 Reality 的两端准备顺序、NAT 映射不足、普通端口池耗尽、已有参数保留、配置追加及启动失败回滚。
- 内核更新覆盖：摘要相同跳过、配置拒绝、校验失败、停止状态保留、启动失败恢复、拒绝降级、预发布版本保护、增强 Sing-box 资产及合并后的菜单。

## 两台服务器灰度

| 服务器 | 结果 |
| --- | --- |
| A | 主脚本与集群升级成功，直接启动 Lun 菜单通过 |
| B | 主脚本与集群升级成功，直接启动 Lun 菜单通过 |

- 双向身份绑定 mTLS 请求确认实际运行 `V26.10.20.3 / 0.3.3`；预检识别两端已有 Reality，并避开已占用端口。
- 创建临时 A→B 链路，独立 Xray 客户端访问测试网站返回 200，出口查询确认为 B；随后删除临时角色和凭据。
- 既有链路正常；临时阻断 A→B 后连接失败且不回落 A 直出，A 普通代理仍可用。解除阻断后恢复，临时规则已清理。
- 两端既有 XHTTP ENC 均访问成功；Generic、Clash、Sing-box 三种 HTTPS 聚合订阅返回 200，保留既有链式节点。
- 已安装内核与配套 Release 摘要相同，没有下载、替换或重启；未安装的内核正确跳过。检查前后摘要和进程 PID 不变。
- UUID、证书、协议端口和订阅地址保持。临时链路清理后配置与元数据恢复，数据库检查通过，代理、订阅和联邦服务正常。

两端原本已有 Reality；缺失协议自动准备及 NAT 不足路径通过隔离测试验证，不能视为生产首次安装实测。TUIC 配置与服务正常，本轮未进行 TUIC 客户端测速。

## CDN 地址库核验

现有模块实时获取 BestCF 综合、移动、联通、电信池，分别解析 12、33、24、31 个候选，均为非缓存数据。没有替换现有优选池。

## 回滚与范围

两端分别保存仅 root 可读的回滚快照；公开报告不记录凭据、订阅链接或私有备份位置。灰度仅涉及 A/B；其他成员使用新链路自动准备功能前，应同步配套脚本与集群程序。

English summary: Native Linux regression and two-server canary checks passed. A temporary A→B chain used B's egress and was removed afterward. Existing proxies and HTTPS subscriptions remained functional. Core checks skipped matching binaries, and live CDN sources were verified. Missing-Reality provisioning was tested in isolation; TUIC client traffic was not tested.
