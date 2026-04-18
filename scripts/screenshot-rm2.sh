#!/usr/bin/env zsh

set -euo pipefail

host="${RM2_HOST:-root@10.11.99.1}"
remote_xovi_root="${RM2_XOVI_ROOT:-/home/root/xovi}"
remote_extensions_dir="${RM2_XOVI_EXTENSIONS_DIR:-${remote_xovi_root}/extensions.d}"
remote_inactive_extensions_dir="${RM2_XOVI_INACTIVE_EXTENSIONS_DIR:-${remote_xovi_root}/inactive-extensions}"
repo_root="${0:A:h:h}"
default_output_dir="${repo_root}/.tmp/screenshots"
output_path="${1:-${default_output_dir}/rm2-$(date +%Y%m%d-%H%M%S).png}"
output_path="${output_path:A}"
block_size=4096
tmp_dir="$(mktemp -d)"

cleanup() {
  rm -rf "${tmp_dir}"
}

trap cleanup EXIT

require_command() {
  local name="$1"

  if ! command -v "${name}" >/dev/null 2>&1; then
    echo "Missing required command: ${name}" >&2
    exit 1
  fi
}

restart_xovi() {
  ssh "${host}" "systemctl stop xochitl >/dev/null 2>&1 || true; nohup '${remote_xovi_root}/start' >/tmp/remarkable-sudoku-screenshot.log 2>&1 </dev/null &"
}

ensure_capture_extensions() {
  local remote_state
  remote_state="$(ssh "${host}" "
    set -e
    xovi_root='${remote_xovi_root}'
    extensions_dir='${remote_extensions_dir}'
    inactive_dir='${remote_inactive_extensions_dir}'
    activated=0
    restart=0

    test -d \"\$xovi_root\" || {
      echo 'missing-xovi'
      exit 1
    }

    for name in framebuffer-spy.so xovi-message-broker.so; do
      if [ ! -e \"\$extensions_dir/\$name\" ]; then
        test -e \"\$inactive_dir/\$name\" || {
          echo \"missing-extension:\$name\"
          exit 1
        }
        cp \"\$inactive_dir/\$name\" \"\$extensions_dir/\$name\"
        activated=1
      fi
    done

    pid=\$(pidof xochitl 2>/dev/null || true)
    if [ -z \"\$pid\" ]; then
      restart=1
    elif ! tr '\\0' '\\n' </proc/\$pid/environ | grep -qx 'LD_PRELOAD=${remote_xovi_root}/xovi.so'; then
      restart=1
    elif [ ! -p /run/xovi-mb ] || [ ! -p /run/xovi-mb-out ]; then
      restart=1
    fi

    printf 'activated=%s restart=%s\n' \"\$activated\" \"\$restart\"
  ")"

  if [[ "${remote_state}" == missing-xovi* ]]; then
    echo "XOVI is not installed on ${host}." >&2
    exit 1
  fi

  if [[ "${remote_state}" == missing-extension:* ]]; then
    echo "Required screenshot extension ${remote_state#missing-extension:} is not available on the tablet." >&2
    exit 1
  fi

  if [[ "${remote_state}" == *"activated=1"* ]]; then
    echo "Activated framebuffer-spy and xovi-message-broker on the tablet." >&2
  fi

  if [[ "${remote_state}" == *"restart=1"* ]]; then
    echo "Restarting XOVI so screenshot capture is available..." >&2
    restart_xovi
  fi

  for attempt in {1..20}; do
    if ssh -o ConnectTimeout=5 "${host}" "
      pid=\$(pidof xochitl 2>/dev/null) &&
      tr '\\0' '\\n' </proc/\${pid}/environ | grep -qx 'LD_PRELOAD=${remote_xovi_root}/xovi.so' &&
      test -p /run/xovi-mb &&
      test -p /run/xovi-mb-out
    " >/dev/null 2>&1; then
      return
    fi

    sleep 1
  done

  echo "xochitl did not come back under XOVI with screenshot helpers enabled." >&2
  echo "Check /tmp/remarkable-sudoku-screenshot.log on the tablet." >&2
  exit 1
}

framebuffer_config() {
  local config=""

  for attempt in {1..10}; do
    config="$(ssh "${host}" "
      pid=\$(pidof xochitl 2>/dev/null || true)
      test -n \"\$pid\" || exit 0
      journalctl _PID=\"\$pid\" --no-pager | grep 'Found framebuffer! Config string is' | tail -n 1 | sed 's/.* is //'
    ")"
    config="${config//$'\r'/}"
    config="${config//$'\n'/}"

    if [[ -n "${config}" ]]; then
      echo "${config}"
      return
    fi

    sleep 1
  done

  echo "Could not find framebuffer-spy output for the current xochitl process." >&2
  exit 1
}

fetch_raw_framebuffer() {
  local address="$1"
  local byte_count="$2"
  local aligned_raw="$3"
  local raw_output="$4"

  local address_offset=$((address))
  local prefix=$((address_offset % block_size))
  local block_skip=$((address_offset / block_size))
  local block_count=$(((prefix + byte_count + block_size - 1) / block_size))
  local raw_size

  ssh "${host}" "dd if=/proc/\$(pidof xochitl)/mem bs=${block_size} skip=${block_skip} count=${block_count} 2>/dev/null" > "${aligned_raw}"
  dd if="${aligned_raw}" of="${raw_output}" bs=1 skip="${prefix}" count="${byte_count}" status=none
  raw_size="$(wc -c < "${raw_output}")"
  raw_size="${raw_size//[[:space:]]/}"

  if (( raw_size != byte_count )); then
    echo "Framebuffer capture returned an unexpected byte count." >&2
    exit 1
  fi
}

write_png() {
  local pixel_type="$1"
  local width="$2"
  local height="$3"
  local raw_input="$4"
  local png_output="$5"
  local rgba_output="$6"

  case "${pixel_type}" in
    2)
      magick -size "${width}x${height}" -depth 8 "bgra:${raw_input}" "${png_output}"
      ;;
    1)
      python3 - "${raw_input}" "${rgba_output}" <<'PY'
import sys

raw_path, rgba_path = sys.argv[1:3]

with open(raw_path, "rb") as raw_file:
    raw = raw_file.read()

pixels = len(raw) // 2
rgba = bytearray(pixels * 4)
cursor = 0

for index in range(0, len(raw), 2):
    value = raw[index] | (raw[index + 1] << 8)
    red = ((value >> 11) & 0x1F) * 255 // 31
    green = ((value >> 5) & 0x3F) * 255 // 63
    blue = (value & 0x1F) * 255 // 31
    rgba[cursor:cursor + 4] = bytes((red, green, blue, 255))
    cursor += 4

with open(rgba_path, "wb") as rgba_file:
    rgba_file.write(rgba)
PY
      magick -size "${width}x${height}" -depth 8 "rgba:${rgba_output}" "${png_output}"
      ;;
    *)
      echo "Unsupported framebuffer type ${pixel_type}." >&2
      exit 1
      ;;
  esac
}

main() {
  require_command ssh
  require_command dd
  require_command magick
  require_command python3

  mkdir -p "${output_path:h}"
  ensure_capture_extensions

  local config
  config="$(framebuffer_config)"

  local -a fields
  fields=(${(s:,:)config})

  if (( ${#fields} != 6 )); then
    echo "Unexpected framebuffer config: ${config}" >&2
    exit 1
  fi

  local address="${fields[1]}"
  local width="${fields[2]}"
  local height="${fields[3]}"
  local pixel_type="${fields[4]}"
  local bytes_per_line="${fields[5]}"
  local byte_count=$((bytes_per_line * height))
  local aligned_raw="${tmp_dir}/framebuffer-aligned.raw"
  local raw_output="${tmp_dir}/framebuffer.raw"
  local rgba_output="${tmp_dir}/framebuffer.rgba"

  fetch_raw_framebuffer "${address}" "${byte_count}" "${aligned_raw}" "${raw_output}"
  write_png "${pixel_type}" "${width}" "${height}" "${raw_output}" "${output_path}" "${rgba_output}"

  echo "${output_path}"
}

main "$@"
