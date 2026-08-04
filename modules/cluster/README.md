# Lun 服务器联动模块

该目录由 `lun.sh` 的“服务器联动 / 节点集群”菜单管理，不建议手工启动。模块默认未安装，启用后每台服务器运行同一份 `lun_cluster.py`：主 VPS 作为控制器，子 VPS 作为受管节点。

安全边界：

- 一次性 `lunjoin://` 地址有效 15 分钟，首次连接使用 SHA-256 证书指纹锁定。
- 配对后使用集群 CA 签发的 P-256 节点证书及 mTLS。
- 远程只接受结构化白名单动作，不接受任意 Shell 命令。
- 配置、数据库、私钥、快照和备份默认仅 root 可读写。

本地测试：

```bash
python3 -m unittest discover -s modules/cluster/tests -v
```

TLS 配对和加密备份用例需要系统安装 OpenSSL。
