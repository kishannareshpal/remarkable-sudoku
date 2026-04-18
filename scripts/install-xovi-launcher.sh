#!/usr/bin/env zsh

set -euo pipefail

host="${RM2_HOST:-root@10.11.99.1}"
local_extension="${1:-build/libremarkable-sudoku-xovi.so}"
launcher_name="${RM2_XOVI_LAUNCHER_NAME:-remarkable-sudoku-sidebar}"
remote_xovi_root="${RM2_XOVI_ROOT:-/home/root/xovi}"
remote_qtrb_dir="${RM2_XOVI_QTRB_DIR:-${remote_xovi_root}/exthome/qt-resource-rebuilder}"
remote_extension_name="${RM2_XOVI_EXTENSION_NAME:-remarkable-sudoku-xovi.so}"
remote_extension_path="${RM2_XOVI_EXTENSION_PATH:-${remote_xovi_root}/extensions.d/${remote_extension_name}}"
template_dir="${0:A:h:h}/xovi/${launcher_name}"
remote_qmd_path="${remote_qtrb_dir}/${launcher_name}.qmd"
tmp_qmd="$(mktemp)"
reuse_remote_extension="${RM2_XOVI_REUSE_REMOTE_EXTENSION:-0}"
supported_xochitl_versions=(
  3.27.0.87
  3.27.0.91
)

cleanup() {
  rm -f "${tmp_qmd}"
}

trap cleanup EXIT

supports_xochitl_version() {
  local candidate="$1"
  local supported_version

  for supported_version in "${supported_xochitl_versions[@]}"; do
    if [[ "${supported_version}" == "${candidate}" ]]; then
      return 0
    fi
  done

  return 1
}

detect_xochitl_version() {
  local detected_version="${RM2_XOCHITL_VERSION:-}"

  if [[ -n "${detected_version}" ]]; then
    printf '%s\n' "${detected_version}"
    return 0
  fi

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

if [[ "${reuse_remote_extension}" != "1" && ! -f "${local_extension}" ]]; then
  echo "XOVI extension not found at ${local_extension}. Build it first with ./run build."
  exit 1
fi

if [[ ! -d "${template_dir}" ]]; then
  echo "XOVI launcher template not found at ${template_dir}"
  exit 1
fi

remote_xochitl_version="$(detect_xochitl_version)"

if [[ -z "${remote_xochitl_version}" ]]; then
  echo "Could not detect the tablet xochitl version. Set RM2_XOCHITL_VERSION and try again." >&2
  exit 1
fi

if ! supports_xochitl_version "${remote_xochitl_version}"; then
  echo "Unsupported xochitl version ${remote_xochitl_version}." >&2
  echo "Known compatible versions: ${supported_xochitl_versions[*]}" >&2
  echo "Inspect the live hashtab before widening support." >&2
  exit 1
fi

ssh "${host}" "
  test -d '${remote_xovi_root}' || {
    echo 'XOVI is not installed under ${remote_xovi_root}.' >&2
    exit 1
  }
  test -e '${remote_xovi_root}/extensions.d/qt-resource-rebuilder.so' || {
    echo 'qt-resource-rebuilder is not installed at ${remote_xovi_root}/extensions.d/qt-resource-rebuilder.so.' >&2
    exit 1
  }
  if [ '${reuse_remote_extension}' = '1' ]; then
    test -e '${remote_extension_path}' || {
      echo 'No installed Sudoku XOVI extension found at ${remote_extension_path}.' >&2
      exit 1
    }
  fi
  mkdir -p '${remote_qtrb_dir}'
  killall remarkable_sudoku >/dev/null 2>&1 || true
  systemctl stop xochitl >/dev/null 2>&1 || true
"

sed -E "1s/^VERSION .*/VERSION ${remote_xochitl_version}/" "${template_dir}/sidebar.qmd" > "${tmp_qmd}"

scp "${tmp_qmd}" "${host}:${remote_qmd_path}"

if [[ "${reuse_remote_extension}" != "1" ]]; then
  scp "${local_extension}" "${host}:${remote_extension_path}.new"
fi

ssh "${host}" "
  if [ '${reuse_remote_extension}' != '1' ]; then
    chmod 755 '${remote_extension_path}.new'
    mv '${remote_extension_path}.new' '${remote_extension_path}'
  fi
  rm -rf /home/root/.cache/remarkable/xochitl/qmlcache
"

if [[ "${reuse_remote_extension}" == "1" ]]; then
  echo "Reused installed XOVI extension at ${host}:${remote_extension_path}"
else
  echo "Installed XOVI extension to ${host}:${remote_extension_path}"
fi
echo "Installed embedded Apps patch to ${host}:${remote_qmd_path}"
echo "Applied launcher patch for xochitl ${remote_xochitl_version}"

echo "Restarting XOVI so the custom sidebar item appears..."
ssh "${host}" "nohup '${remote_xovi_root}/start' >/tmp/remarkable-sudoku-sidebar-install.log 2>&1 </dev/null &"

echo "Waiting for xochitl to come back under XOVI..."
ready=0
for attempt in {1..15}; do
  if ssh -o ConnectTimeout=5 "${host}" "
    systemctl is-active xochitl >/dev/null 2>&1 &&
    pid=\$(pidof xochitl 2>/dev/null) &&
    tr '\\0' '\\n' </proc/\${pid}/environ | grep -qx 'LD_PRELOAD=${remote_xovi_root}/xovi.so'
  "; then
    ready=1
    break
  fi

  sleep 2
done

if [[ "${ready}" != "1" ]]; then
  echo "The launcher files were installed, but xochitl did not report the expected XOVI environment in time." >&2
  echo "Check /tmp/remarkable-sudoku-sidebar-install.log on the tablet if the Sudoku entry is still missing." >&2
  exit 1
fi

echo "XOVI restarted and the sidebar launcher should now be available."
exit 0
