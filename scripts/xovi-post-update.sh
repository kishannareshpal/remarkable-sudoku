#!/usr/bin/env zsh

set -euo pipefail

host="${RM2_HOST:-root@10.11.99.1}"
local_extension="${1:-build/libremarkable-sudoku-xovi.so}"
remote_xovi_root="${RM2_XOVI_ROOT:-/home/root/xovi}"
remote_rebuild_hashtab_path="${RM2_XOVI_REBUILD_HASHTAB_PATH:-${remote_xovi_root}/rebuild_hashtable}"
remote_qtrb_dir="${RM2_XOVI_QTRB_DIR:-${remote_xovi_root}/exthome/qt-resource-rebuilder}"
script_dir="${0:A:h}"

detect_xochitl_version() {
  ssh "${host}" "
    if [ -f /usr/share/remarkable/update.conf ]; then
      . /usr/share/remarkable/update.conf >/dev/null 2>&1 || true
      if [ -n \"\${REMARKABLE_RELEASE_VERSION:-}\" ]; then
        printf '%s\n' \"\${REMARKABLE_RELEASE_VERSION}\"
        exit 0
      fi
    fi

    if [ -f /etc/os-release ]; then
      . /etc/os-release >/dev/null 2>&1 || true
      if [ -n \"\${IMG_VERSION:-}\" ]; then
        printf '%s\n' \"\${IMG_VERSION}\"
        exit 0
      fi
    fi

    exit 1
  "
}

remote_xochitl_version="$(detect_xochitl_version)"

if [[ -z "${remote_xochitl_version}" ]]; then
  echo "Could not detect the tablet xochitl version." >&2
  exit 1
fi

ssh "${host}" "
  test -d '${remote_xovi_root}' || {
    echo 'XOVI is not installed under ${remote_xovi_root}.' >&2
    exit 1
  }
  test -x '${remote_rebuild_hashtab_path}' || {
    echo 'rebuild_hashtable is not available at ${remote_rebuild_hashtab_path}.' >&2
    exit 1
  }
  test -e '${remote_xovi_root}/extensions.d/qt-resource-rebuilder.so' || {
    echo 'qt-resource-rebuilder is not installed at ${remote_xovi_root}/extensions.d/qt-resource-rebuilder.so.' >&2
    exit 1
  }
  mkdir -p '${remote_qtrb_dir}'
"

echo "Detected tablet firmware ${remote_xochitl_version}."
echo "Rebuilding the XOVI hashtab for the current firmware."
echo "Unlock the tablet if rebuild_hashtable prompts on-device."
ssh -tt "${host}" "printf '\n' | '${remote_rebuild_hashtab_path}'"

if [[ -f "${local_extension}" ]]; then
  "${script_dir}/install-xovi-launcher.sh" "${local_extension}"
else
  echo "Local extension not found at ${local_extension}. Reusing the extension already installed on the tablet."
  RM2_XOVI_REUSE_REMOTE_EXTENSION=1 "${script_dir}/install-xovi-launcher.sh" "${local_extension}"
fi

echo "Recent xochitl log lines for verification:"
ssh "${host}" "journalctl -u xochitl --since '3 minutes ago' --no-pager | grep -E 'qmldiff|QML|RemarkableSudokuXovi|remarkable-sudoku' || true"
