# V26.10.20.3 验收记录 / Verification

日期：2026-10-20。主脚本 `V26.10.20.3`，集群程序 `0.3.3`；多用户程序保持 `0.4.2`，CDN 优选程序保持 `2.0.5`。没有发布或替换 Release 内核。

## 自动回归

- 在甲骨文的隔离目录运行完整 Linux 离线入口：多用户 61、集群 128、CDN 18、Cloudflare/网络隔离 3，共 210 项 Python 用例；其中 2 项可选真实内核用例在第二轮单独启用，链路专项 25 项全部通过。浏览器 JavaScript 检查通过。
- 13 组 Shell 测试全部通过，包括原生符号链接、可执行入口、菜单、证书、端口跳跃、防火墙归属、带宽队列及事务保护；没有使用 Windows 符号链接跳过开关。
- 新增覆盖：两端缺少 Reality 的自动准备顺序、NAT 映射不足、普通端口池范围及耗尽、旧 UUID/SNI/协议/Argo 参数保留、配置追加保护和启动失败回滚。
- 更新测试覆盖：摘要相同跳过、配置拒绝、校验失败、停止状态保留、启动失败恢复、拒绝降级、预发布版本保护、增强 Sing-box 资产以及合并后的菜单入口。

## 两台甲骨文灰度

| 服务器 | 编号 | 结果 |
| --- | --- | --- |
| `161.33.1.16` | 01 | 主脚本与集群升级成功；直接运行 Lun 菜单通过 |
| `161.33.24.201` | 06 | 主脚本与集群升级成功；直接运行 Lun 菜单通过 |

- 双向身份绑定 mTLS 状态请求确认对方实际运行 `V26.10.20.3 / 0.3.3`，而不只是检查磁盘文件。
- 真实预检识别既有 Reality：01 使用 `25270`，06 使用 `31687`；自动选择的临时链式端口避开既有协议和管理服务。
- 通过真实联邦接口创建临时 01→06 链路，入口 `46971`。Windows 独立 Xray 客户端访问 `example.com` 返回 200，`api.ipify.org` 返回第二跳 `161.33.24.201`。测试后删除两端临时角色和凭据，保留原链路 `45c44c…`。
- 原有链路 `52919` 实测出口为第二跳；临时阻断 A→B `31687` 后链路失败，不回落 A 直出，A 普通节点仍可用；撤除临时规则后恢复。临时规则有自动清理保险，已清理。
- 两端既有 XHTTP ENC 均实际访问成功。Generic、Clash、Sing-box 三种公开 HTTPS 聚合订阅均返回 200，包含原链式节点。
- 两台已安装内核与配套 Release 摘要相同，实际检查没有下载、替换或重启；01 未安装 Sing-box，正确跳过；06 的 Xray/Sing-box 都正确跳过。检查前后内核哈希和服务 PID 相同。
- 原 UUID、证书、协议端口及订阅地址保持。临时链路清理后，原核心配置与链路元数据恢复；JSON 允许只有序列化空白差异。数据库检查 `ok`，代理、订阅及联邦服务正常。

两台原本已有普通 Reality，因此真实生产测试没有删除它们来制造缺失场景；“缺失协议自动准备”和 NAT 不足的拒绝路径由隔离回归验证，不将其描述为生产机上的首次安装实测。TUIC 保持原配置、配置校验和服务正常，本轮未进行 TUIC 客户端测速。

## CDN 地址库核验

在 VPS 上使用模块现有获取函数读取综合、移动、联通、电信四个 BestCF 地址库，分别解析 12、33、24、31 个候选，全部 `cached=false`。刷新入口已实时请求上游当前库，并有失败缓存回退，不需要再增加更新按钮；没有替换用户现有优选池。

## 回滚点与范围

- 01：`/root/lun-deploy-backups/bundle-20261020-125043`。
- 06：`/root/lun-deploy-backups/bundle-20261020-125053`。
- 快照仅 root 可读；没有在仓库、报告或命令输出中发布订阅 Token、中转凭据或私钥。
- 本轮只灰度这两台 VPS。其他成员仍可使用现有协议；需要新链路自动准备时，先从集群更新维护入口同步配套脚本与集群程序。

English summary: Native Linux regression and real-core chain checks passed, followed by a two-member Oracle canary. A newly created temporary federated chain exited through B and was removed after verification. Existing ordinary proxies, the retained chain, and all three HTTPS subscription formats remained functional. Compatible-core checks were no-ops, live CDN sources were confirmed, and no credentials or Release binaries were published.
