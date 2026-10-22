# Lun Fenghuolun

[简体中文](README.md) | [English](README.en.md)

Lun is a VPS terminal script for multi-protocol proxies, CDN optimization, multi-user access and distributed server management.

Powered by Xray, sing-box and Cloudflared, with guided menus and environment-variable installation.
Current script version: `V26.10.20.3`.

## Features

| Feature | What it does |
| --- | --- |
| Protocols and subscriptions | Manage 14 protocols/combinations; export generic, Clash/Mihomo and Sing-box subscriptions where compatible. |
| Dual-path CDN testing | Rank client-to-CDN and VPS-to-CDN results separately; configure Cloudflare CDN, origin-port rules and WS tunnels. |
| NAT and certificates | Manage port pools, NAT mappings and system firewall rules; issue/import certificates and check renewal automatically. |
| Users and bandwidth | Manage users, devices, monthly quotas, expiry and protocol access, with server-wide fair bandwidth sharing. |
| Distributed cluster | Connect peer VPS members, aggregate subscriptions, distribute script updates and sync CDN pools; configure two-hop proxy chains. |
| Connection monitoring | Independently record proxy destination domains, with filtering, activity merging, queries and retention settings. |

Multi-user access, clustering and monitoring are optional; the CDN testing page runs on demand.
Proxy chains currently support two-hop VLESS TCP Reality for TCP traffic only.
See the [protocol capability table](docs/USAGE.zh-CN.md#协议与域名变量) for CDN, tunnel and subscription compatibility.

## Quick start

Connect to your VPS over SSH and run in Bash:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```

If `curl` is unavailable, use:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/lun.sh)
```

After installation, reconnect over SSH and run:

```bash
lun
```

Use the menu to configure protocols, certificates and subscriptions.
`Services & Updates → Update local Lun script` also checks compatible updates for installed cores.

## Documentation

Detailed guides are currently in Chinese; the changelog includes English summaries.

- [User guide: menus, variables, certificates, CDN and NAT](docs/USAGE.zh-CN.md)
- [Users, traffic and connection monitoring](modules/multiuser/README.md)
- [Distributed cluster and proxy chains](modules/cluster/README.md)
- [Dual-path CDN testing](modules/cdnopt/README.md)
- [SAP deployment](SAP.md)
- [Changelog / 更新日志](CHANGELOG.md)
- [Version verification report](docs/VERIFICATION_V26.10.20.3.md)

## Credits

Lun is derived from [yonggekkk/argosbx](https://github.com/yonggekkk/argosbx).
Thank you to yonggekkk and all contributors for their open-source work.

Thanks also to [Xray-core](https://github.com/XTLS/Xray-core),
[sing-box](https://github.com/SagerNet/sing-box),
[Cloudflared](https://github.com/cloudflare/cloudflared),
[BestCF](https://github.com/DustinWin/BestCF) and
[cmliu/edgetunnel](https://github.com/cmliu/edgetunnel).

## License

The original project license is retained. See [LICENSE](LICENSE).
