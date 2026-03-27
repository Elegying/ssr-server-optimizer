#!/usr/bin/env bash
set -euo pipefail

SSR_DIR="/usr/local/shadowsocksr"
SSR_CONFIG="$SSR_DIR/user-config.json"
SYSCTL_FILE="/etc/sysctl.d/99-z-ssr-performance.conf"
SERVICE_FILE="/etc/systemd/system/ssr.service"
TIMESTAMP="$(date +%F-%H%M%S)"

log() {
  printf '[ssr-opt] %s\n' "$*"
}

fail() {
  printf '[ssr-opt] ERROR: %s\n' "$*" >&2
  exit 1
}

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || fail "run as root"
}

require_tools() {
  command -v systemctl >/dev/null 2>&1 || fail "systemctl not found"
  command -v python3 >/dev/null 2>&1 || fail "python3 not found"
}

backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    cp -a "$file" "${file}.bak.${TIMESTAMP}"
  fi
}

detect_python() {
  if command -v python >/dev/null 2>&1; then
    command -v python
  else
    command -v python3
  fi
}

validate_layout() {
  [[ -d "$SSR_DIR" ]] || fail "$SSR_DIR not found"
  [[ -f "$SSR_CONFIG" ]] || fail "$SSR_CONFIG not found"
}

patch_ssr_config() {
  log "updating SSR config"
  backup_file "$SSR_CONFIG"
  python3 - "$SSR_CONFIG" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
raw = path.read_text(encoding="utf-8-sig")
data = json.loads(raw)
data["timeout"] = 300
data["udp_timeout"] = 120
data["fast_open"] = True
path.write_text(json.dumps(data, indent=4) + "\n", encoding="utf-8")
PY
}

write_sysctl() {
  log "writing sysctl tuning"
  backup_file "$SYSCTL_FILE"
  cat > "$SYSCTL_FILE" <<'EOF'
fs.file-max = 1048576
net.core.somaxconn = 8192
net.core.netdev_max_backlog = 16384
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.ip_local_port_range = 10240 65535
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_rmem = 4096 262144 16777216
net.ipv4.tcp_wmem = 4096 262144 16777216
net.netfilter.nf_conntrack_max = 262144
EOF
}

fix_conflicting_backlog() {
  for file in /etc/sysctl.conf /etc/sysctl.d/99-sysctl.conf; do
    if [[ -f "$file" ]] && grep -Eq '^[[:space:]]*net\.ipv4\.tcp_max_syn_backlog[[:space:]]*=[[:space:]]*1024([[:space:]]*)$' "$file"; then
      log "fixing old backlog override in $file"
      backup_file "$file"
      sed -i 's/^[[:space:]]*net\.ipv4\.tcp_max_syn_backlog[[:space:]]*=.*/net.ipv4.tcp_max_syn_backlog = 8192/' "$file"
    fi
  done
}

write_systemd_unit() {
  local pybin
  pybin="$(detect_python)"
  log "writing systemd service"
  backup_file "$SERVICE_FILE"
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=ShadowsocksR Python Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$SSR_DIR
ExecStart=$pybin $SSR_DIR/server.py a
Restart=always
RestartSec=3
LimitNOFILE=1048576
TasksMax=infinity

[Install]
WantedBy=multi-user.target
EOF
}

apply_sysctl() {
  log "reloading sysctl"
  sysctl --system >/tmp/ssr-optimizer-sysctl.log 2>&1 || true
}

restart_ssr() {
  log "reloading systemd"
  systemctl daemon-reload
  systemctl stop ssr >/dev/null 2>&1 || true
  if pgrep -f "$SSR_DIR/server.py a" >/dev/null 2>&1; then
    log "stopping existing SSR process"
    pkill -f "$SSR_DIR/server.py a" || true
    sleep 2
  fi
  log "enabling and starting ssr.service"
  systemctl enable ssr >/dev/null 2>&1 || true
  systemctl start ssr
  sleep 3
}

verify() {
  log "verifying SSR state"
  systemctl is-active --quiet ssr || fail "ssr.service is not active"

  python3 - "$SSR_CONFIG" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8-sig"))
assert data.get("timeout") == 300, data
assert data.get("udp_timeout") == 120, data
assert bool(data.get("fast_open")) is True, data
PY

  local current_backlog
  current_backlog="$(sysctl -n net.ipv4.tcp_max_syn_backlog 2>/dev/null || true)"
  log "ssr.service is active"
  log "tcp_max_syn_backlog=${current_backlog}"
  log "completed successfully"
}

main() {
  require_root
  require_tools
  validate_layout
  patch_ssr_config
  write_sysctl
  fix_conflicting_backlog
  write_systemd_unit
  apply_sysctl
  restart_ssr
  verify
}

main "$@"
