#!/usr/bin/env zsh

set -euo pipefail

host="${RM2_HOST:-root@10.11.99.1}"
local_binary="${1:-build/remarkable_sudoku}"
remote_binary="${RM2_REMOTE_BINARY:-~/remarkable_sudoku}"

if [[ ! -f "${local_binary}" ]]; then
  echo "Binary not found at ${local_binary}. Build it first with ./scripts/build-rm2.sh."
  exit 1
fi

ssh "${host}" "killall remarkable_sudoku >/dev/null 2>&1 || true"
scp "${local_binary}" "${host}:${remote_binary}"

ssh -t "${host}" <<EOF
set -e
systemctl stop xochitl
trap 'systemctl start xochitl' EXIT
export QT_QPA_EVDEV_TOUCHSCREEN_PARAMETERS="/dev/input/event2:rotate=180:invertx"
export QT_QPA_GENERIC_PLUGINS="evdevtablet:/dev/input/event1"
QT_QUICK_BACKEND=epaper ${remote_binary} -platform epaper
EOF
