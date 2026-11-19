# Lun 发布验证

- 发布到 `main` 前，用 Linux 运行完整的 `bash tests/run_offline_checks.sh`。Windows 上的部分 Shell 检查、语法检查或生产机抽测不能替代它。
- 本机没有可用的 Linux 环境时，先把候选提交推到临时分支，在 GitHub Actions 确认该提交的 `Offline regression checks` 通过，再把同一个提交推进 `main`。测试失败先修正，禁止跳过检查或用 `--force` 发布。
- 修改服务检测、更新入口或公共 Shell 函数时，同时检查隔离测试中对旧函数或命令的模拟。版本检查应核对发布文件是否一致，避免在多个测试里写死当前版本号。
