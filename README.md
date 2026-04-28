# SSR 服务器优化工具

适用于 Ubuntu / Debian 上老版 Python ShadowsocksR 的一键优化脚本。

这个项目会自动完成我们前面手动做过的那一套优化，包括：

- 将 SSR 的 `timeout` 调整为 `300`
- 将 SSR 的 `udp_timeout` 调整为 `120`
- 开启 SSR `fast_open`
- 优化内核 TCP 与 socket 缓冲参数，提升稳定性和吞吐表现
- 将 SSR 改为 `systemd` 托管，支持自动重启与开机自启
- 如果检测到 `/opt/ssr-admin-panel`，同步刷新面板设备统计服务
- 在修改前自动备份原配置文件

## 适用环境

- Ubuntu 20.04 及以上
- Debian 系发行版
- SSR 安装目录为 `/usr/local/shadowsocksr`
- 使用 `user-config.json` 的老版 Python SSR

## 一行命令使用

在目标服务器上以 `root` 身份执行：

```bash
curl -fsSL https://raw.githubusercontent.com/Elegying/ssr-server-optimizer/main/optimize-ssr.sh | bash
```

如果你想从本地直接远程执行：

```bash
ssh root@你的服务器IP "curl -fsSL https://raw.githubusercontent.com/Elegying/ssr-server-optimizer/main/optimize-ssr.sh | bash"
```

## 脚本会做什么

- 更新 `/usr/local/shadowsocksr/user-config.json`
  - `timeout = 300`
  - `udp_timeout = 120`
  - `fast_open = true`
- 写入 `/etc/sysctl.d/99-z-ssr-performance.conf`
- 如果系统里存在旧的 `tcp_max_syn_backlog = 1024` 覆盖项，会自动修正
- 创建 `/etc/systemd/system/ssr.service`
- 如已安装 SSR Admin Panel，创建或刷新 `ssr-device-stats.service`
- 重载 `sysctl` 与 `systemd`
- 用 `systemd` 重新拉起 SSR

## 安全性

- 修改前会创建带时间戳的备份
- 除必要优化项外，尽量保留原有 SSR 配置
- 自动识别实际安装的 `python` / `python3` 路径

## 项目文件

- `optimize-ssr.sh`：主优化脚本
- `LICENSE`：MIT 许可证

## 说明

- 当前版本不负责限制 SSR 管理面板访问来源
- 当前版本主要面向你现在使用的这类老版 Python SSR 架构
- 如果后续需要，我可以继续扩展批量多服务器执行、面板访问限制、日志检查等功能
