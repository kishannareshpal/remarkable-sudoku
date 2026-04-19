#!/usr/bin/env zsh

set -euo pipefail

host="${RM2_HOST:-root@10.11.99.1}"
remote_xovi_root="${RM2_XOVI_ROOT:-/home/root/xovi}"
remote_service_dir="${RM2_XOVI_SERVICE_DIR:-${remote_xovi_root}/services/xochitl.service}"
remote_trace_conf="${remote_service_dir}/10-low-latency-trace.conf"
logging_rules="${RM2_LOW_LATENCY_LOGGING_RULES:-rm.framebuffer.debug=true;rm.framebuffer.updates.debug=true;qt.scenegraph.general.debug=true;qt.qpa.input.debug=true}"
start_marker="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cleanup() {
  echo
  echo "Removing low-latency trace config and restarting XOVI..."
  ssh "${host}" "
    set -e
    rm -f '${remote_trace_conf}'
    '${remote_xovi_root}/start' >/tmp/remarkable-sudoku-low-latency-restore.log 2>&1
  " || true
}

trap cleanup EXIT INT TERM

ssh "${host}" "
  set -e
  test -d '${remote_xovi_root}' || {
    echo 'XOVI is not installed under ${remote_xovi_root}.' >&2
    exit 1
  }

  mkdir -p '${remote_service_dir}'
  cat > '${remote_trace_conf}' <<EOF
[Service]
Environment=\"QT_LOGGING_RULES=${logging_rules}\"
Environment=\"QSG_INFO=1\"
EOF

  '${remote_xovi_root}/start' >/tmp/remarkable-sudoku-low-latency-trace.log 2>&1
"

echo "Tracing is active."
echo "Draw a few fast pen strokes on the tablet now."
echo "Press Ctrl-C here when you have enough samples."
echo

ssh -tt "${host}" "
  journalctl -u xochitl --since '${start_marker}' --follow --no-pager -o cat |
    awk 'match(\$0, /rm\\.framebuffer|pen update|update completed|scenegraph|Tablet(P|M|R)|qt\\.qpa\\.input|EPFramebuffer|EPRenderLoop/) { print; fflush() }'
"
