# Lun SAP 部署说明

本目录中的 SAP 脚本用于在 SAP BTP/Cloud Foundry 环境部署和保活 Lun 节点。该流程面向已经了解 SAP BTP 账号、Cloud Foundry API、组织、空间和应用配额的用户。

## 部署方式

### GitHub Actions

- 自动部署并启动：`.github/workflows/main.yml`
- 仅保活：`.github/workflows/mainh.yml`

请在自己的仓库中配置所需 secrets，并按 workflow 提示填写账号、区域、应用名和协议参数。

### VPS 执行

自动部署并启动：

```bash
curl -sSL https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/sap.sh -o sap.sh && chmod +x sap.sh && bash sap.sh
```

仅保活：

```bash
curl -sSL https://raw.githubusercontent.com/azk78lun-collab/FHLUN/main/saph.sh -o saph.sh && chmod +x saph.sh && bash saph.sh
```

没有 `curl` 时可使用 `wget -qO-` 替代。

### Docker 镜像

脚本默认镜像为：

```text
ghcr.io/azk78lun-collab/lun:latest
```

可通过环境变量覆盖：

```bash
DOCKER_IMAGE="your-registry/your-image:tag" bash sap.sh
```

注意：如果默认 GHCR 镜像尚未发布，必须先发布镜像或显式设置 `DOCKER_IMAGE`。

## 主要变量

多个账号或应用按空格分隔；某项留空时用 `no` 占位。

| 变量 | 必填 | 说明 |
| --- | --- | --- |
| `CF_USERNAMES` | 是 | SAP/Cloud Foundry 登录邮箱 |
| `CF_PASSWORDS` | 是 | 登录密码 |
| `REGIONS` | 是 | 区域代码 |
| `UUIDS` | 是 | 节点 UUID |
| `APP_NAMES` | 否 | 应用名，留空用区域和账号生成 |
| `VMPTS` | 否 | VMess/Argo 端口，`no` 表示关闭 |
| `AGNS` | 否 | Argo 固定隧道域名，`no` 表示临时隧道 |
| `AGKS` | 否 | Argo 固定隧道 token |
| `DELAPP` | 否 | 指定要删除的应用名 |
| `DOCKER_IMAGE` | 否 | 覆盖默认 Docker 镜像 |

## 说明

- SAP 免费账号存在平台策略和配额限制，部署前请自行确认账号状态。
- Argo 固定隧道需要同时提供 `AGNS` 和 `AGKS`。
- 本文档不包含第三方推广链接；如需更多 SAP/Cloud Foundry 细节，请参考 SAP 和 Cloud Foundry 官方文档。
