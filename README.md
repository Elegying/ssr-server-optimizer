# SSR Server Optimizer

One-command tuning for legacy Python-based ShadowsocksR servers on Ubuntu/Debian.

This project applies the same optimization set we used on your servers:

- Raise SSR `timeout` to `300`
- Raise SSR `udp_timeout` to `120`
- Enable SSR `fast_open`
- Tune kernel TCP and socket buffers for better stability and throughput
- Move SSR into `systemd` with auto-restart and higher `nofile` limits
- Keep backups of files before changing them

## What it supports

- Ubuntu 20.04+ and Debian-like systems
- Legacy SSR installs located at `/usr/local/shadowsocksr`
- Existing `user-config.json` setups managed by SSR panel / `mudb.json`

## One-line usage

Run this on the target server as `root`:

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/ssr-server-optimizer/main/optimize-ssr.sh | bash
```

If you prefer to login from your local machine and execute remotely in one line:

```bash
ssh root@YOUR_SERVER_IP "curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/ssr-server-optimizer/main/optimize-ssr.sh | bash"
```

## What the script changes

- Updates `/usr/local/shadowsocksr/user-config.json`
  - `timeout = 300`
  - `udp_timeout = 120`
  - `fast_open = true`
- Writes `/etc/sysctl.d/99-z-ssr-performance.conf`
- Fixes old conflicting `tcp_max_syn_backlog = 1024` lines when present
- Creates `/etc/systemd/system/ssr.service`
- Reloads `sysctl` and `systemd`
- Restarts SSR under `systemd`

## Safety

- Creates timestamped backups before modifying files
- Preserves existing SSR JSON fields other than the tuned keys
- Chooses the actual installed `python` or `python3` binary automatically

## Files

- `optimize-ssr.sh`: main one-command optimizer
- `LICENSE`: MIT

## Notes

- The script does not lock down the SSR admin panel. If you want, a later version can also restrict the panel to trusted IPs.
- This project is intentionally focused on the older Python SSR layout you are using now.

