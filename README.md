# Lun 风火轮

[简体中文](README.md) | [English](README.en.md)

Lun 风火轮：集多协议代理、CDN 优选、多用户与分布式服务器管理于一体的 VPS 终端脚本。

基于 Xray、sing-box 与 Cloudflared，支持菜单引导和环境变量安装。
当前脚本版本：`V26.10.20.3`。

## 核心功能

| 功能 | 说明 |
| --- | --- |
| 协议与订阅 | 管理 14 种协议/组合，按客户端兼容性导出通用、Clash/Mihomo、Sing-box 订阅。 |
| CDN 双向优选 | 客户端与 VPS 分别测速排行；支持 Cloudflare CDN、端口回源及 WS 隧道。 |
| NAT 与证书 | 管理端口池、NAT 映射及系统防火墙；申请、导入证书并自动检查续期。 |
| 多用户与带宽 | 管理用户、设备、月额度、到期和协议权限，提供全机动态公平带宽。 |
| 分布式集群 | 多 VPS 对等联动、聚合订阅、脚本更新与 CDN 池同步；支持手动两跳链式代理。 |
| 网站访问监控 | 独立采集代理连接域名，支持过滤、重复合并、查询与保留期限设置。 |

多用户、集群和监控按需开启；CDN 优选网页按需启动。
链式代理目前仅支持 VLESS TCP Reality 两跳与 TCP 业务；
CDN、隧道和订阅兼容范围见[协议能力表](docs/USAGE.zh-CN.md#协议与域名变量)。

## 快速开始

通过 SSH 登录 VPS 后，在 Bash 中执行：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```

没有 `curl` 时可使用：

```bash
bash <(wget -qO- https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```

安装完成后，重新登录 SSH 并运行：

```bash
lun
```

在菜单中配置协议、证书和订阅。
`服务与更新 → 更新本机 Lun 脚本` 同时检查已安装内核的配套更新。

## 文档

- [使用指南：菜单、参数、证书、CDN 与 NAT](docs/USAGE.zh-CN.md)
- [多用户、流量与网站监控](modules/multiuser/README.md)
- [分布式集群与链式代理](modules/cluster/README.md)
- [CDN 双向优选](modules/cdnopt/README.md)
- [SAP 部署](SAP.md)
- [更新日志 / Changelog](CHANGELOG.md)
- [版本验收记录](docs/VERIFICATION_V26.10.20.3.md)

## 来源与致谢

本项目基于甬哥的 [yonggekkk/argosbx](https://github.com/yonggekkk/argosbx) 二次开发。
感谢甬哥及所有贡献者的开源奉献。

同时感谢 [Xray-core](https://github.com/XTLS/Xray-core)、
[sing-box](https://github.com/SagerNet/sing-box)、
[Cloudflared](https://github.com/cloudflare/cloudflared)、
[BestCF](https://github.com/DustinWin/BestCF) 与
[cmliu/edgetunnel](https://github.com/cmliu/edgetunnel)。

## 许可证

保留项目原许可证，详见 [LICENSE](LICENSE)。
