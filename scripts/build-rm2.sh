#!/usr/bin/env zsh

set -euo pipefail

if [[ -z "${RM2_SDK_ENV:-}" ]]; then
  echo "Set RM2_SDK_ENV to your reMarkable 2 SDK environment file."
  echo "Example: export RM2_SDK_ENV=\$HOME/codex-sdk/rm2/3.26.0.68/environment-setup-cortexa7hf-neon-remarkable-linux-gnueabi"
  exit 1
fi

source "${RM2_SDK_ENV}"

export LANG="C.UTF-8"
export LC_ALL="C.UTF-8"

cmake_bin="${HOST_CMAKE:-/usr/bin/cmake}"

"${cmake_bin}" -S . -B build -DBUILD_TESTING=OFF
"${cmake_bin}" --build build
