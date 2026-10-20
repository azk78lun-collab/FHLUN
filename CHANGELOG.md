# Lun 更新日志 Changelog

Lun 风火轮的中英文更新记录，最新日期在前；每项链接可查看对应代码差异。当前脚本版本为 `V26.10.20.2`。

Bilingual update history for Lun, newest date first. Each commit link opens the corresponding changes. The current script version is `V26.10.20.2`.

## 阅读说明 Reading guide

- 日期采用 Git 提交记录中的提交日期及其时区，不从版本号推算。例如 `V26.8.10.10` 实际提交于 2026 年 9 月 23 日。
- 版本取对应提交中的 `lun.sh`；同一版本可以包含多个修复或文档提交。合并记录不代表重复发布，也不另造版本号。
- 本日志补充历史说明，不修改原提交、哈希或顺序。历史实现可能已被后续版本替代；当前操作以 [README](README.md) 和模块文档为准。
- 覆盖仓库初始化至 `19c6e6e` 的全部 79 个提交，包括 5 个 PR 合并记录；之后的更新继续在顶部追加。

- Dates follow the Git commit date and its recorded timezone, not the date embedded in a version string. For example, `V26.8.10.10` was committed on September 23, 2026.
- Versions come from `lun.sh` at each commit. Several fixes or documentation changes may share a version. Merge entries are integration records, not additional releases.
- These notes preserve the original commits, hashes and order. Later versions may supersede historical behavior; follow the current [README](README.md) and module documentation for usage.
- The history covers all 79 commits from repository initialization through `19c6e6e`, including 5 PR merges. Future updates belong at the top.

## 2026 年 10 月 20 日

- [`19c6e6e`](https://github.com/azk78lun-collab/FHLUN/commit/19c6e6e) · `V26.10.20.2`
  - 中文：修复更新或快照推送后残留的“疑似离线”。直接、身份校验成功的 mTLS 通信会清除本机旧失败状态；业务错误不再误判为掉线，较早的失败不覆盖较新的在线证据。相同内容不重复写入或重启，更新后核验实际运行版本及哈希。已在 5 台活动成员验证，每日巡检频率不变。
  - English: Recover stale suspect states after updates and snapshot pushes. Successful identity-verified direct mTLS traffic clears local failures; application errors no longer imply offline status, and older failures cannot overwrite newer liveness evidence. Identical payloads avoid writes and restarts, and updates verify the running version and hash. Verified on five active members; daily checks remain unchanged.

- [`c5d5950`](https://github.com/azk78lun-collab/FHLUN/commit/c5d5950) · `V26.10.20.1` · 验证报告 / Verification report
  - 中文：补充两台真实联邦服务器的链式代理验收：流量从 B 出口访问，A→B 中断时链路失败且不回落 A 直出，普通节点和三种订阅仍正常。详细结果见 [加固与实测报告](docs/HARDENING_REPORT_2026-10-11.md)。
  - English: Record live two-member chain verification: traffic exits through B, an A→B outage fails closed without direct fallback through A, and ordinary nodes plus all three subscription formats remain functional. See the [hardening and verification report](docs/HARDENING_REPORT_2026-10-11.md).

- [`b64832b`](https://github.com/azk78lun-collab/FHLUN/commit/b64832b) · `V26.10.20.1`
  - 中文：新增可选、手动配置的 VLESS TCP Reality 两跳链式代理，位于分布式集群内。A 使用独立入口，B 使用独立中转凭据；个人、多用户和聚合订阅共用链路名称。首版仅转发 TCP，保留普通节点，部署和清理支持事务回滚。
  - English: Add optional manually configured two-hop VLESS TCP Reality chains inside the distributed cluster. A uses a separate entry port and B uses dedicated transit credentials. Personal, multi-user and aggregate subscriptions share chain names. The initial implementation carries TCP only, preserves ordinary nodes and supports transactional deployment and cleanup.

## 2026 年 10 月 11 日

- [`62b7727`](https://github.com/azk78lun-collab/FHLUN/commit/62b7727) · `V26.10.11.2`
  - 中文：完善公开证书的每日续期检查与 HTTPS 订阅恢复。优先复用兼容的 Nginx 验证路径，必要时临时借用 TCP 80 并恢复已知服务；续期部署失败回滚，保留订阅端口及 Token，记录检查结果。
  - English: Improve daily public-certificate renewal checks and HTTPS subscription recovery. Prefer compatible Nginx challenge handling, temporarily borrow TCP 80 when required and restore known services. Roll back failed deployments, preserve subscription ports and tokens, and record results.

- [`9e7235e`](https://github.com/azk78lun-collab/FHLUN/commit/9e7235e) · `V26.10.11.1`
  - 中文：修正脚本解释器为 Bash，解决直接执行 `lun` 时的重定向语法错误，并增加直接启动回归测试。
  - English: Use Bash as the script interpreter, fixing redirection syntax errors when running `lun` directly, and add an executable-entrypoint regression test.

- [`6574266`](https://github.com/azk78lun-collab/FHLUN/commit/6574266) · `V26.10.11.1`
  - 中文：绑定远端成员证书身份，实际操作支持 IPv6 回退；测速超时和停止覆盖下载正文，HTTP 80 降级结果明确标注。动态带宽只管理 Lun 自有队列，并加入离线回归工作流及保护测试。
  - English: Bind remote requests to member certificate identities and support IPv6 fallback for operations. Apply download deadlines and cancellation to response bodies, label HTTP 80 fallback accurately, manage only Lun-owned bandwidth queues, and add offline regression CI and protection tests.

- [`b31509e`](https://github.com/azk78lun-collab/FHLUN/commit/b31509e) · 脚本版本沿用 / Script version retained: `V26.8.10.12`
  - 中文：将订阅 TLS 握手移入限时工作线程，避免慢连接堵塞服务；Hysteria2 跳跃改用专属 NAT 链；保存完整远控结果以支持幂等重试；换密钥和删除用户失败时完整恢复数据库及配置。
  - English: Move subscription TLS handshakes into bounded worker threads, isolate Hysteria2 hopping in a dedicated NAT chain, retain full remote-operation results for idempotent retries, and restore database and configuration after failed credential rotation or user deletion.

## 2026 年 10 月 8 日

- [`b429a8f`](https://github.com/azk78lun-collab/FHLUN/commit/b429a8f) · `V26.8.10.12`
  - 中文：修复身份被撤销后无法重新打开集群面板的问题，保留恢复入口以生成新身份并重新加入。
  - English: Restore access to the cluster menu after identity revocation, allowing recovery with a new identity and a fresh join.

- [`d58cd37`](https://github.com/azk78lun-collab/FHLUN/commit/d58cd37) · `V26.8.10.11`
  - 中文：按功能分组精简主菜单、网站监控和集群菜单；将 CDN 池同步归入更新维护，并支持下发本机已审查的脚本。
  - English: Simplify and group the main, visit-monitor and cluster menus, move CDN-pool synchronization into maintenance, and support distributing reviewed local scripts.

## 2026 年 9 月 23 日

- [`d55a6a3`](https://github.com/azk78lun-collab/FHLUN/commit/d55a6a3) · `V26.8.10.10`
  - 中文：加入每日成员健康巡检、签名复核和撤销传播，撤销后剔除聚合节点；订阅生成后发布快照并按需补齐。CDN 页面保留已选 IP、应用后显示回执，并改善客户端并发及探测降级。
  - English: Add daily member checks, signed corroboration and revocation propagation, removing revoked nodes from aggregates. Publish snapshots after subscription generation and reconcile on demand. Preserve CDN selections, show apply receipts, and improve client concurrency and probe fallback.

## 2026 年 8 月 24 日

- [`52beaba`](https://github.com/azk78lun-collab/FHLUN/commit/52beaba) · `V26.8.10.6`
  - 中文：加强联邦通信及双栈监听，按地址族交叉确认公网 IPv4/IPv6，列表同时显示且 IPv4 优先；将 TLS 握手隔离，避免慢连接阻塞。
  - English: Harden federation transport and dual-stack listening, cross-check public IPv4/IPv6 per address family, display both with IPv4 first, and isolate TLS handshakes so slow connections do not block the listener.

- [`372d9f4`](https://github.com/azk78lun-collab/FHLUN/commit/372d9f4) · `V26.8.10.5`
  - 中文：让优选差异预览中的“保留”与“删除”可双向移动，旧 IP 不再无法取消。
  - English: Allow moving existing IPs between retained and removed lists in the CDN preview, so previously retained addresses can be deselected.

- [`f0fe86e`](https://github.com/azk78lun-collab/FHLUN/commit/f0fe86e) · `V26.8.10.4`
  - 中文：前端手工候选输入兼容 Lun 的空格、多行和备注格式；改善客户端网络展示、探测路径校验及旧 IP 保留操作。
  - English: Accept Lun-style space-separated, multiline and annotated manual candidates; improve client-network display, probe-path validation and controls for retaining existing IPs.

## 2026 年 8 月 19 日

- [`05cc292`](https://github.com/azk78lun-collab/FHLUN/commit/05cc292) · `V26.8.10.2`
  - 中文：升级按需 CDN 优选模块，接入 BestCF，分开显示客户端与 VPS 榜单、进度及差异预览。加入联邦公网 IP 自动核对与本人签名地址广播，并改进配对后的有界传播和地区识别。
  - English: Upgrade the on-demand CDN optimizer with BestCF, separate client/VPS rankings, progress and change previews. Add public-IP reconciliation with self-signed endpoint events, plus bounded post-pairing propagation and region detection.

## 2026 年 8 月 10 日

- [`8d2bdf5`](https://github.com/azk78lun-collab/FHLUN/commit/8d2bdf5) · `V26.8.9.8`
  - 中文：同步身份清理状态，完善联邦身份撤销及重新加入的清理边界。
  - English: Synchronize identity cleanup and refine cleanup boundaries around federation revocation and rejoining.

## 2026 年 8 月 9 日

- [`c70f3cc`](https://github.com/azk78lun-collab/FHLUN/commit/c70f3cc) · `V26.8.9.7`
  - 中文：完善粘贴一次加入地址的完整流程，自动重载信任、广播成员及补发订阅；扩大首次历史导入的读取时限，减少半配对超时。
  - English: Complete one-paste joining with automatic trust reload, member propagation and subscription catch-up; extend the initial history-import read timeout to reduce half-completed joins.

- [`c4db4d1`](https://github.com/azk78lun-collab/FHLUN/commit/c4db4d1) · `V26.8.9.6`
  - 中文：远程更新联邦程序后重启对应服务，使新代码实际生效。
  - English: Restart the federation service after updating its program so the new code becomes active.

- [`f0112d8`](https://github.com/azk78lun-collab/FHLUN/commit/f0112d8) · `V26.8.9.5`
  - 中文：修复联邦聚合订阅 Token 的收敛，避免成员之间继续输出不一致的 Token。
  - English: Converge aggregate subscription tokens across federation members, preventing inconsistent token output.

- [`b6eac19`](https://github.com/azk78lun-collab/FHLUN/commit/b6eac19) · `V26.8.9.4`
  - 中文：配对完成后传播新成员的信任信息，使其他成员能够识别和同步新加入节点。
  - English: Propagate newly paired members and their trust information so existing peers can recognize and synchronize with them.

- [`7a28885`](https://github.com/azk78lun-collab/FHLUN/commit/7a28885) · `V26.8.9.3`
  - 中文：旧集群迁移时复用原有通信端口，避免无必要的端口变更。
  - English: Reuse the existing communication port during legacy-cluster migration, avoiding unnecessary endpoint changes.

- [`21b7ef1`](https://github.com/azk78lun-collab/FHLUN/commit/21b7ef1) · `V26.8.9.2`
  - 中文：修复可信联邦成员的更新目标识别，恢复批量更新覆盖范围。
  - English: Correct update-target selection for trusted federation members and restore batch-update coverage.

- [`e5bea71`](https://github.com/azk78lun-collab/FHLUN/commit/e5bea71) · `V26.8.9.1`
  - 中文：将主子集群升级为 API v3 对等联邦。每台独立身份及私钥，通过签名事件链、mTLS、按需同步和可信快照实现聚合；加入一次即可传播，支持撤销、CDN 池同步和安全备份，不复制共享 CA 私钥。
  - English: Replace the controller/worker cluster with an API v3 peer federation. Independent identities and private keys use signed event chains, mTLS, on-demand synchronization and trusted snapshots. Add propagated joins, revocation, CDN-pool synchronization and secure backups without copying a shared CA private key.

- [`0c9b363`](https://github.com/azk78lun-collab/FHLUN/commit/0c9b363) · `V26.8.8.3`
  - 中文：完善域名/IP 公开证书申请与原子安装，失败保留旧证书；Cloudflare Token 引导留在 VPS 终端，支持重复配对替换旧授权，并补充优选测试进度。
  - English: Complete public domain/IP certificate issuance and atomic installation while preserving old certificates on failure. Keep Cloudflare-token guidance in the VPS terminal, allow re-pairing to replace old authorization, and improve optimizer progress reporting.

## 2026 年 8 月 7 日

- [`22c400d`](https://github.com/azk78lun-collab/FHLUN/commit/22c400d) · `V26.8.8.2`
  - 中文：修复本机实际命令入口和集群批量更新，复用已校验程序进行下发，避免更新到错误路径或各机重复下载。
  - English: Fix updates of the actual local command entrypoint and cluster-wide distribution, reusing validated programs instead of updating the wrong path or downloading separately on every node.

- [`438d39b`](https://github.com/azk78lun-collab/FHLUN/commit/438d39b) · `V26.8.8.1`
  - 中文：新增事务化 Cloudflare 一键配置，按可用端口组合证书、DNS、精确回源规则及 Tunnel；任一关键步骤失败回滚。
  - English: Add transactional one-click Cloudflare setup covering certificates, DNS, precise origin rules and tunnels according to available ports, with rollback on critical failures.

- [`5790358`](https://github.com/azk78lun-collab/FHLUN/commit/5790358) · `V26.8.7.1`
  - 中文：新增按需 CDN 优选网页模块，使用临时端口和 Token，测试客户端线路并将结果写回现有优选池；平时不运行常驻服务。
  - English: Add an on-demand CDN optimizer page with a temporary port and token, client-path testing and integration with the existing preferred-IP pool, without an always-running service.

## 2026 年 8 月 6 日

- [`07cd970`](https://github.com/azk78lun-collab/FHLUN/commit/07cd970) · `V26.8.5.12`
  - 中文：启用端口回源时，不适合橙云的直连节点自动使用源站 IP，避免把直连发往 Cloudflare 边缘。
  - English: Use origin IPs for direct nodes incompatible with proxied DNS when origin routing is enabled, avoiding accidental direct connections to Cloudflare edges.

- [`9c18a20`](https://github.com/azk78lun-collab/FHLUN/commit/9c18a20) · `V26.8.5.11`
  - 中文：重制 Lun 终端轮胎开屏与菜单缓冲显示；统一大阪地区名称，同地区多台 VPS 按服务器编号增加地区序号。
  - English: Refine the Lun wheel splash and buffered menu rendering, normalize Osaka region labels, and distinguish servers in the same region using stable region suffixes.

## 2026 年 8 月 5 日

- [`a4c8584`](https://github.com/azk78lun-collab/FHLUN/commit/a4c8584) · `V26.8.5.3`
  - 中文：加强主子角色交接和远程进程管理，改进数据库交接、失败恢复及操作说明。
  - English: Harden controller-role handoff and remote process management, improving database transfer, failure recovery and operational guidance.

- [`105c0c6`](https://github.com/azk78lun-collab/FHLUN/commit/105c0c6) · `V26.8.5.2`
  - 中文：个人、多用户及聚合订阅统一简洁命名，服务器编号永久保存且不复用；新增当时主子架构的角色互换与终端主题。
  - English: Unify concise names across personal, multi-user and aggregate subscriptions, persist non-reusable server numbers, and add role handoff plus a terminal theme for the then-current controller/worker architecture.

## 2026 年 8 月 4 日

- [`d23006d`](https://github.com/azk78lun-collab/FHLUN/commit/d23006d) · `V26.8.4.2`
  - 中文：新增可选多服务器联动，采用主子模式、一次性配对、mTLS 及结构化远控白名单；支持聚合订阅、用户授权、快照和恢复。
  - English: Introduce optional multi-server management with a controller/worker topology, one-time pairing, mTLS and structured remote-action allowlists, including aggregated subscriptions, user grants, snapshots and restore.

- [`bf7a322`](https://github.com/azk78lun-collab/FHLUN/commit/bf7a322) · `V26.8.2.1`
  - 中文：移除重复的 `argosbx.sh` 兼容入口，统一由 `lun.sh` 承接安装及菜单入口。
  - English: Remove the redundant `argosbx.sh` compatibility entrypoint and consolidate installation and menu access in `lun.sh`.

- [`8212d06`](https://github.com/azk78lun-collab/FHLUN/commit/8212d06) · `V26.8.2.1`
  - 中文：网站监控加入轻量标准过滤、自定义显隐规则及连续活动合并，保留原始记录；清理废弃报告、旧 Worker 和旧镜像配置。
  - English: Add lightweight standard filtering, custom domain visibility rules and continuous-activity merging to visit monitoring while retaining raw records; remove obsolete reports, the old Worker and an unused mirror configuration.

## 2026 年 7 月 31 日

- [`043786d`](https://github.com/azk78lun-collab/FHLUN/commit/043786d) · `V26.7.31.2`
  - 中文：网站监控拆成无监听端口的独立服务，单用户也能采集；明细保留 7 天、日汇总 30 天，并修复订阅与旧 BusyBox 的端口冲突。
  - English: Split visit monitoring into an independent service with no listening port, enabling single-user collection with seven-day details and thirty-day daily summaries; fix subscription-port conflicts with legacy BusyBox.

## 2026 年 7 月 30 日

- [`c16c7c6`](https://github.com/azk78lun-collab/FHLUN/commit/c16c7c6) · `V26.7.30.3`
  - 中文：脚本更新优先经 GitHub API 获取主分支内容，进一步规避 raw 缓存滞后。
  - English: Prefer the GitHub API for main-branch script updates to further avoid stale raw-content caches.

- [`0bdcdef`](https://github.com/azk78lun-collab/FHLUN/commit/0bdcdef) · `V26.7.30.2`
  - 中文：调整更新下载路径，尝试通过 GitHub 主站获取最新脚本。
  - English: Adjust the updater download path to retrieve the latest script through GitHub's main site.

- [`a2486a3`](https://github.com/azk78lun-collab/FHLUN/commit/a2486a3) · `V26.7.30.1`
  - 中文：为更新请求增加防缓存处理，修复旧缓存导致误报“最新版”。
  - English: Add cache-busting to update requests to prevent stale responses from being reported as the latest version.

- [`c2ec042`](https://github.com/azk78lun-collab/FHLUN/commit/c2ec042) · `V26.7.29.8`
  - 中文：修复不同终端中协议能力表格的显示宽度和列对齐。
  - English: Correct protocol-capability table widths and column alignment across terminals.

## 2026 年 7 月 29 日

- [`5c2ada0`](https://github.com/azk78lun-collab/FHLUN/commit/5c2ada0) · `V26.7.29.7`
  - 中文：新增手动登记与 API 自动部署回源规则，改进回源诊断及 Token 提示；协议面板改为直连、CDN、回源、隧道能力对照表。
  - English: Add manual registration and API deployment of origin rules, improve routing diagnostics and token guidance, and display protocol capabilities for direct, CDN, origin-rule and tunnel modes in a table.

- [`6b64812`](https://github.com/azk78lun-collab/FHLUN/commit/6b64812) · PR #5 合并 / Merge
  - 中文：合并 CDN 输入与更新体验分支到主分支，功能说明见 `c2a46a1`。
  - English: Merge the CDN-input and updater-UX branch into main; see `c2a46a1` for the functional changes.

- [`c2a46a1`](https://github.com/azk78lun-collab/FHLUN/commit/c2a46a1) · `V26.7.29.2`
  - 中文：CDN 地址输入支持带端口、测速备注及多行粘贴，自动清洗去重；更新菜单显示进度、版本和明确结果。
  - English: Accept CDN addresses with ports, test annotations and multiline input, cleaning and deduplicating them automatically; show updater progress, versions and explicit outcomes.

- [`3340ef3`](https://github.com/azk78lun-collab/FHLUN/commit/3340ef3) · PR #4 合并 / Merge
  - 中文：将自动防火墙端口管理功能合并到主分支。
  - English: Merge automatic firewall-port management into main.

- [`5f0ddda`](https://github.com/azk78lun-collab/FHLUN/commit/5f0ddda) · `V26.7.29.1`
  - 中文：安装和改端口时自动放行协议及订阅所需 TCP/UDP，支持常见系统防火墙，保留用户原有规则。
  - English: Automatically allow required protocol and subscription TCP/UDP ports during installation and port changes, supporting common system firewalls while preserving user rules.

## 2026 年 7 月 22 日

- [`d668e1e`](https://github.com/azk78lun-collab/FHLUN/commit/d668e1e) · PR #3 合并 / Merge
  - 中文：合并多用户构建工作流的 Bash 调用修复。
  - English: Merge the Bash-invocation fix for the multi-user build workflow.

- [`72024c5`](https://github.com/azk78lun-collab/FHLUN/commit/72024c5) · `V26.7.22.4`
  - 中文：GitHub Actions 明确通过 Bash 执行多用户内核构建脚本。
  - English: Explicitly run the multi-user core build script with Bash in GitHub Actions.

- [`72eb7d8`](https://github.com/azk78lun-collab/FHLUN/commit/72eb7d8) · PR #2 合并 / Merge
  - 中文：将当时的开发分支合并到主分支；对应阶段的多用户与带宽功能见 `6248469`。
  - English: Merge the development branch into main; see `6248469` for this stage's multi-user and bandwidth features.

- [`6248469`](https://github.com/azk78lun-collab/FHLUN/commit/6248469) · `V26.7.22.4`
  - 中文：新增多用户、设备凭据、月额度、到期及协议权限管理，接入流量统计和全机动态公平带宽；同时收敛 NAT 引导及说明入口。
  - English: Add multi-user accounts, device credentials, monthly allowances, expiry and protocol permissions, with traffic accounting and whole-machine dynamic fair bandwidth; also streamline NAT guidance and help access.

## 2026 年 7 月 20 日

- [`0295810`](https://github.com/azk78lun-collab/FHLUN/commit/0295810) · `V26.7.19.3`
  - 中文：README 增加甬哥原版项目链接及开源致谢。
  - English: Add the original yonggekkk project link and open-source acknowledgements to the README.

- [`7e56102`](https://github.com/azk78lun-collab/FHLUN/commit/7e56102) · PR #1 合并 / Merge
  - 中文：将 XHTTP TLS、NaiveProxy 及配套端口改进分支合并到主分支。
  - English: Merge the XHTTP TLS, NaiveProxy and related port-handling improvements into main.

## 2026 年 7 月 19 日

- [`5b94451`](https://github.com/azk78lun-collab/FHLUN/commit/5b94451) · `V26.7.19.3`
  - 中文：IPv6 内核镜像 HTTPS 服务迁移至 8443，释放 443 供协议测试。
  - English: Move the IPv6 core mirror's HTTPS service to 8443, freeing port 443 for protocol testing.

- [`6261bdc`](https://github.com/azk78lun-collab/FHLUN/commit/6261bdc) · `V26.7.19.2`
  - 中文：增加 `xcpt` 公网 443 实验模式说明和端口占用风险提醒。
  - English: Add guidance for experimental `xcpt` public-port-443 testing and warnings about conflicting listeners.

- [`4b1aa2c`](https://github.com/azk78lun-collab/FHLUN/commit/4b1aa2c) · `V26.7.19.1`
  - 中文：CDN 协议随机分配优先使用未占用的 Cloudflare 支持端口，补充 NAT 回源提醒。
  - English: Prefer free Cloudflare-supported ports when automatically allocating CDN protocol ports and add NAT-origin guidance.

- [`1a9eb0a`](https://github.com/azk78lun-collab/FHLUN/commit/1a9eb0a) · `V26.7.19.1`
  - 中文：回源验证不通过时不输出伪可用的 XHTTP TLS CDN 节点，并提供诊断提示。
  - English: Suppress unusable XHTTP TLS CDN nodes when origin validation fails and provide diagnostic guidance.

- [`16591f4`](https://github.com/azk78lun-collab/FHLUN/commit/16591f4) · `V26.7.19.1`
  - 中文：梳理 CF 端口和网络菜单，普通 VPS 也可登记回源规则，增加单协议快速改端口入口。
  - English: Refine Cloudflare port and network menus, allow ordinary VPS instances to register origin rules, and add a quick per-protocol port editor.

## 2026 年 7 月 18 日

- [`37d2b21`](https://github.com/azk78lun-collab/FHLUN/commit/37d2b21) · `V26.7.18.1` · 验证报告 / Verification report
  - 中文：记录完整卸载重装验证及新协议验收结果。
  - English: Document full uninstall/reinstall verification and acceptance results for the new protocols.

- [`535b9dd`](https://github.com/azk78lun-collab/FHLUN/commit/535b9dd) · `V26.7.18.1`
  - 中文：修复清理路径中的 POSIX Shell 兼容问题。
  - English: Fix POSIX-shell compatibility in cleanup paths.

- [`36a5723`](https://github.com/azk78lun-collab/FHLUN/commit/36a5723) · `V26.7.18.1`
  - 中文：移植 XHTTP TLS UDP、XHTTP TLS TCP/UDP 和 NaiveProxy，新增 `xupt`、`xcpt`、`nvpt` 及订阅输出；保留原有证书、NAT 和事务改进。
  - English: Port XHTTP TLS UDP, XHTTP TLS TCP/UDP and NaiveProxy through `xupt`, `xcpt` and `nvpt`, including subscription output while preserving existing certificate, NAT and transactional improvements.

## 2026 年 7 月 12 日

- [`f97f68c`](https://github.com/azk78lun-collab/FHLUN/commit/f97f68c) · `V26.7.12.5`
  - 中文：修正 VLESS WS 的 flow 字段兼容性。
  - English: Correct VLESS WS compatibility around the flow field.

- [`6aca694`](https://github.com/azk78lun-collab/FHLUN/commit/6aca694) · `V26.7.12.4`
  - 中文：修复订阅端口分配和公网映射，完善 Argo 节点导出及入口处理。
  - English: Fix subscription-port allocation and public mapping, and refine Argo node exports and endpoint handling.

- [`a63fefa`](https://github.com/azk78lun-collab/FHLUN/commit/a63fefa) · `V26.7.12.3`
  - 中文：IPv6 内核下载切换为甲骨文镜像服务，并加入镜像同步和 Nginx 配置。
  - English: Serve IPv6 core downloads from an Oracle-hosted mirror and add synchronization and Nginx configuration.

- [`2f31ad8`](https://github.com/azk78lun-collab/FHLUN/commit/2f31ad8) · `V26.7.12.2`
  - 中文：新增 IPv6 环境的内核下载镜像及下载回退路径。
  - English: Add a core-download mirror and fallback path for IPv6 environments.

- [`04b6634`](https://github.com/azk78lun-collab/FHLUN/commit/04b6634) · `V26.7.12.1`
  - 中文：协议重建加入事务快照和失败恢复，补充 IPv6 ACME 申请诊断。
  - English: Add transactional snapshots and rollback to protocol rebuilds, plus diagnostics for IPv6 ACME issuance.

- [`ee62cef`](https://github.com/azk78lun-collab/FHLUN/commit/ee62cef) · `V26.7.11.2`
  - 中文：新增本地证书目录检索、证书信息检查和导入功能。
  - English: Add local certificate discovery, certificate inspection and import.

## 2026 年 7 月 11 日

- [`ad6ec1c`](https://github.com/azk78lun-collab/FHLUN/commit/ad6ec1c) · `V26.7.11.1`
  - 中文：修复 CDN 节点客户端兼容性，将 NAT 回源规则和入口端口逻辑分开处理。
  - English: Fix client compatibility for CDN nodes and separate NAT origin-rule handling from edge-port logic.

- [`474efe2`](https://github.com/azk78lun-collab/FHLUN/commit/474efe2) · `V26.7.11`
  - 中文：修复 NAT 场景的 CDN 回源改写与双栈节点输出。
  - English: Fix CDN origin rewriting and dual-stack node output in NAT deployments.

- [`a5053d3`](https://github.com/azk78lun-collab/FHLUN/commit/a5053d3) · `V26.5.10`
  - 中文：修复端口池重复占用和 CDN 输出逻辑，并同步相关脚本下载路径。
  - English: Fix port-pool reuse and CDN output, and update related script download paths.

## 2026 年 7 月 10 日

- [`b30579d`](https://github.com/azk78lun-collab/FHLUN/commit/b30579d) · `V26.5.10`
  - 中文：CDN 优选入口支持域名和多个地址。
  - English: Support domain names and multiple addresses as preferred CDN entries.

- [`ce99750`](https://github.com/azk78lun-collab/FHLUN/commit/ce99750) · `V26.5.10`
  - 中文：澄清 README 中核心逻辑的上游来源。
  - English: Clarify the upstream source of the core logic in the README.

## 2026 年 7 月 9 日

- [`cadf237`](https://github.com/azk78lun-collab/FHLUN/commit/cadf237) · `V26.5.10`
  - 中文：文档统一风火轮品牌，注明 argosbx 来源并移除废弃命令说明。
  - English: Rebrand documentation as Fenghuolun, credit argosbx and remove deprecated command instructions.

- [`07f6735`](https://github.com/azk78lun-collab/FHLUN/commit/07f6735) · `V26.5.10`
  - 中文：增加双栈 IP 输出，修复节点列表检测，合并重复菜单并清理冗余内容。
  - English: Add dual-stack IP output, fix node-list detection, consolidate menus and clean up redundant content.

- [`99aac7f`](https://github.com/azk78lun-collab/FHLUN/commit/99aac7f) · `V26.5.10`
  - 中文：增强代理进程检测，减少状态面板误判。
  - English: Improve proxy-process detection to reduce incorrect dashboard status.

- [`55b9bd1`](https://github.com/azk78lun-collab/FHLUN/commit/55b9bd1) · `V26.5.10`
  - 中文：NAT 随机端口改从现有映射选择，增强证书检测和目录查找。
  - English: Choose random NAT ports from configured mappings and improve certificate detection and directory searches.

- [`3f11414`](https://github.com/azk78lun-collab/FHLUN/commit/3f11414) · `V26.5.10`
  - 中文：恢复安装确认函数，完善证书详情和订阅端口冲突检测；恢复出厂设置保留脚本、内核及服务框架。
  - English: Restore the installation-confirmation function, improve certificate details and subscription-port conflict checks, and preserve scripts, cores and service scaffolding during factory reset.

- [`63cff63`](https://github.com/azk78lun-collab/FHLUN/commit/63cff63) · `V26.5.10`
  - 中文：重做引导安装流程，增加恢复出厂设置，修正进程判断及服务主目录路径。
  - English: Redesign guided installation, add factory reset, and correct process checks and service home-directory paths.

- [`d7723f4`](https://github.com/azk78lun-collab/FHLUN/commit/d7723f4) · `V26.5.10`
  - 中文：重制终端横幅和颜色，精简装饰并强化端口及输入提示。
  - English: Redesign the terminal banner and colors, simplify decorations, and improve port and input hints.

- [`a716287`](https://github.com/azk78lun-collab/FHLUN/commit/a716287) · `V26.5.10`
  - 中文：统一使用 `C.UTF-8`，减少精简系统的区域设置警告。
  - English: Use `C.UTF-8` consistently to reduce locale warnings on minimal systems.

- [`7027f8c`](https://github.com/azk78lun-collab/FHLUN/commit/7027f8c) · `V26.5.10`
  - 中文：申请证书前可按需复用已有本地证书；未配置 ACME 邮箱时自动生成默认值。
  - English: Offer reuse of existing local certificates before issuance and generate a default ACME email when none is configured.

- [`ecc367f`](https://github.com/azk78lun-collab/FHLUN/commit/ecc367f) · `V26.5.10`
  - 中文：导入 argosbx 衍生脚本、容器和 SAP 配套文件，统一 FHLUN 仓库下载及安装路径。
  - English: Import the argosbx-derived scripts, container and SAP support files, and point download and installation paths to the FHLUN repository.

- [`1adde04`](https://github.com/azk78lun-collab/FHLUN/commit/1adde04) · 初始化 / Initialization
  - 中文：创建仓库，加入初始 README 和许可证。
  - English: Initialize the repository with a README and license.

## 来源与验证 Sources and verification

上游来源：[yonggekkk/argosbx](https://github.com/yonggekkk/argosbx)。感谢甬哥及所有开源贡献者。

Upstream: [yonggekkk/argosbx](https://github.com/yonggekkk/argosbx). Thanks to yonggekkk and all open-source contributors.

完整历史：[GitHub 提交列表 / GitHub commit history](https://github.com/azk78lun-collab/FHLUN/commits/main/)。近期详细验证：[可靠性修复、证书续期、链式代理与成员状态报告 / Hardening, renewal, chain and health verification](docs/HARDENING_REPORT_2026-10-11.md)。
