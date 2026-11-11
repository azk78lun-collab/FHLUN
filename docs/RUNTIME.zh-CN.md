# 按需组件与旧系统兼容

Lun 不再把“存在安装标记”当作依赖安装成功。每次启动检查基础命令，缺失时仅补装对应包；软件源失败会明确停止，不写入就绪标记，也不修改软件源或关闭 TLS 校验。

## 加载规则

| 使用场景 | 运行环境 |
| --- | --- |
| 主菜单、基础检查 | 系统基础命令，不下载可选模块 |
| 普通代理、证书、普通订阅 | 按需检查 Python 3.6+；BusyBox httpd 可用时继续复用 |
| 多用户、网站监控、分布式集群、CDN 测速、Cloudflare 自动配置 | 按需检查 Python 3.10+、SQLite 3.25+ 和 TLS 能力 |

优先复用满足要求的已安装解释器。旧系统不满足模块要求时，安装 Lun 私有的 Python 运行环境，不改 `/usr/bin/python*`、系统包依赖或全局 PATH。

私有环境位于 `~/lun/runtime/`，仅在 Lun 及其服务中使用。下载固定为 Astral 官方 Python Build Standalone 的 `20261110 / CPython 3.12.16`，按架构和 libc 选择包，SHA-256 固定在脚本中；通过归档路径检查、解释器启动、TLS/SQLite 功能检查后才原子切换。失败保留旧入口，删除临时下载，不启动半成品服务。

首次下载约 28–35 MB，要求至少 256 MiB 可用磁盘；后续复用本机环境，不重复下载。不编译 Python，不创建 Swap，不通过 pip 安装额外第三方包。

## 支持边界

- 系统需支持 Bash、可用的软件包源或已具备基础命令，并能访问官方 HTTPS 下载源。
- 便携包支持 Linux x86_64/aarch64，分别匹配 glibc/musl。glibc 包的上游最低要求为 2.17，适用于 CentOS 7 等旧环境；实际启动验证失败时不会强制接管。
- 多用户、监控和集群服务仍要求 systemd 或 OpenRC；端口映射和云安全组仍需按菜单要求配置。
- 便携 Python 不替换系统 OpenSSL 命令；链式 Reality 的公钥计算仍需 OpenSSL 支持 X25519（1.1.1+）。旧内核或旧 OpenSSL 不支持某项协议/算法时，不能把主菜单可运行等同于全部高级功能均可用。
- 旧发行版已停止安全维护时，补齐 Lun 运行环境不代表操作系统重新获得安全支持。建议安排系统升级，但 Lun 不会自动重装 VPS。
- 旧版 Lun 需先更新主脚本；已存在的模块不自动启用、不清空数据库，也不修改 UUID、端口、证书或订阅令牌。

需要单独检查或预装时运行 `lun runtime-ensure basic` 或 `lun runtime-ensure modules`。安装日志为 `~/lun/dependencies-install.log`；包源失败需修复软件源后重试。

上游说明：[Python Build Standalone](https://github.com/astral-sh/python-build-standalone)、[运行条件](https://github.com/astral-sh/python-build-standalone/blob/main/docs/running.rst)。
