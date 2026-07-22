# FHLUN 可选多用户模块

该目录提供风火轮的可选“多用户管理”模块。未安装模块时，`lun.sh` 的单用户协议、订阅、证书、CDN、NAT 与 Argo 行为保持不变。

## 组件

- `lun_agent.py`：仅依赖 Python 3 标准库，管理 SQLite 用户数据库、配额、配置注入、订阅服务和 30 秒维护任务。
- `build-singbox-enhanced.sh`：以相同 Sing-box 版本构建带 `with_v2ray_api` 的增强内核和非驻留统计查询工具。
- `sb_stats_helper.go`：只允许连接回环地址的 Sing-box gRPC 统计查询工具源码。
- `tests/`：数据库、配额、核心配置和订阅渲染单元测试。

服务端口、证书、服务域名、NAT 映射和协议开关仍由 `lun.sh` 管理。模块将当前 UUID 导入为 `legacy-admin / legacy-device`，保留原服务器级传输路径和旧订阅 token。Shadowsocks-2022 使用额外端口并行迁移，避免改变旧客户端密码格式。

## 本地测试

```bash
python3 -m unittest discover -s modules/multiuser/tests -v
bash -n lun.sh
```

## 安全边界

- 管理操作只通过 root 本地 CLI，不开放公网管理 API。
- 每台设备使用独立 UUID、密码、SS 用户密钥与 32 字节随机订阅 token。
- 订阅目录不可枚举，请求日志不记录 token。
- 默认阻断私网、链路本地、云元数据和 TCP 25；TCP 465/587 不受影响。
- 数据库与配置修改使用 SQLite 事务、原子替换和核心配置校验。
- systemd/OpenRC 之外的无 init 环境拒绝安装常驻模块。

## 动态公平带宽

菜单中的动态公平带宽作用于服务器下载出口。配置值是全机总上限，单位为 Mbit/s。实现优先采用 CAKE 公平队列，内核不支持 CAKE 时回退到 HTB 总量整形和 FQ-CoDel 公平排队。配置通过 systemd/OpenRC 开机恢复；关闭或卸载模块会移除该队列。

## Sing-box 增强内核

普通 Sing-box 仍可承载多用户，但无法提供按用户流量统计。增强构建保持版本不变，只在原有构建标签中增加 `with_v2ray_api`，并配套 `lun-sb-stats` 查询工具。查询工具拒绝非回环 API 地址，不是公网管理接口。构建产物经测试后再作为 Release 资产提供。
