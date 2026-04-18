#!/usr/bin/env zsh

set -euo pipefail

host="${RM2_HOST:-root@10.11.99.1}"
local_binary="${1:-build/remarkable_sudoku}"
bundle_name="${RM2_APPLOAD_BUNDLE_NAME:-remarkable-sudoku}"
remote_appload_root="${RM2_APPLOAD_ROOT:-/home/root/xovi/exthome/appload}"
remote_bundle_dir="${RM2_APPLOAD_DIR:-${remote_appload_root}/${bundle_name}}"
template_dir="${0:A:h:h}/appload/${bundle_name}"
refresh_ui="${RM2_APPLOAD_REFRESH_UI:-1}"

if [[ ! -f "${local_binary}" ]]; then
  echo "Binary not found at ${local_binary}. Build it first with ./run build."
  exit 1
fi

if [[ ! -d "${template_dir}" ]]; then
  echo "AppLoad bundle template not found at ${template_dir}"
  exit 1
fi

ssh "${host}" "
  test -d /home/root/xovi || {
    echo 'XOVI is not installed under /home/root/xovi.' >&2
    exit 1
  }
  test -e /home/root/xovi/extensions.d/appload.so || {
    echo 'AppLoad is not installed at /home/root/xovi/extensions.d/appload.so.' >&2
    exit 1
  }
  test -e /home/root/xovi/extensions.d/qt-resource-rebuilder.so || {
    echo 'qt-resource-rebuilder is not installed at /home/root/xovi/extensions.d/qt-resource-rebuilder.so.' >&2
    exit 1
  }
  mkdir -p '${remote_bundle_dir}'
"

scp \
  "${template_dir}/external.manifest.json" \
  "${template_dir}/launch.sh" \
  "${template_dir}/run-foreground.sh" \
  "${template_dir}/icon.png" \
  "${host}:${remote_bundle_dir}/"

scp "${local_binary}" "${host}:${remote_bundle_dir}/remarkable_sudoku"

ssh "${host}" "
  chmod 755 \
    '${remote_bundle_dir}/launch.sh' \
    '${remote_bundle_dir}/run-foreground.sh' \
    '${remote_bundle_dir}/remarkable_sudoku'
"

echo "Installed AppLoad bundle to ${host}:${remote_bundle_dir}"

if [[ "${refresh_ui}" == "0" ]]; then
  echo "Skipped XOVI refresh because RM2_APPLOAD_REFRESH_UI=0."
  echo "Run /home/root/xovi/rebuild_hashtable and then /home/root/xovi/start on the tablet when you want the launcher to appear."
  exit 0
fi

echo "Rebuilding XOVI resource hashtable so AppLoad picks up the new launcher..."
ssh -tt "${host}" "printf '\n' | /home/root/xovi/rebuild_hashtable"

echo "Starting XOVI..."
ssh "${host}" "nohup /home/root/xovi/start >/tmp/xovi-start.log 2>&1 </dev/null &"

echo "Waiting for xochitl to come back..."
for attempt in {1..12}; do
  if ssh -o ConnectTimeout=5 "${host}" "systemctl is-active xochitl >/dev/null 2>&1"; then
    echo "XOVI restarted and xochitl is active."
    exit 0
  fi

  sleep 2
done

echo "AppLoad bundle installed, but xochitl did not report active within the expected time." >&2
echo "Check the tablet UI, then inspect /tmp/xovi-start.log on the device if the AppLoad entry is still missing." >&2
exit 1
