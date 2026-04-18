# reMarkable Sudoku

A small Sudoku game built for the reMarkable 2 with Qt Quick.

The current build is a playable prototype with a full-screen 9x9 board, pen and touch input, an on-screen number pad, clear and reset actions, and host-side tests for the core board logic.

## What Works

- Full-screen Sudoku board tuned for the reMarkable 2 display
- Cell selection with touch, mouse, or pen input
- Number pad entry for digits 1 through 9
- Clear and reset actions
- Incorrect entries stay visible and are marked as mistakes
- Host-side tests for the puzzle model

## Stack

- C++17
- CMake
- Qt 6.5 and Qt Quick
- Official reMarkable `rm2` SDK
- Docker wrapper for `linux/amd64` SDK installation and cross-builds

## Requirements

- A reMarkable 2 with SSH access over USB
- The public `rm2` SDK from the reMarkable developer portal
- An `x86_64` Linux environment for the SDK, or Docker on macOS/Linux

Useful official references:

- Developer portal: <https://developer.remarkable.com/>
- Qt Quick app guide: <https://developer.remarkable.com/documentation/qt_epaper>
- SDK downloads: <https://developer.remarkable.com/links>

## Quick Start

The repo ships with a `./run` helper that wraps the Docker workflow.

As of April 13, 2026, `./run` defaults to `RM2_SDK_VERSION=3.26.0.68`, which matches the latest public `rm2` SDK listed on the reMarkable links page.

### 1. Build the Docker image

```sh
./run image
```

### 2. Download the current public `rm2` SDK installer

```sh
mkdir -p .downloads
curl -L "https://storage.googleapis.com/remarkable-codex-toolchain/3.26.0.68/rm2/remarkable-production-image-5.6.75-rm2-public-x86_64-toolchain.sh" \
  -o .downloads/remarkable-production-image-5.6.75-rm2-public-x86_64-toolchain.sh
```

If reMarkable publishes a newer public `rm2` SDK, either update the path above or set `RM2_SDK_VERSION` before running the helper commands.

### 3. Install the SDK into the repo

```sh
./run sdk-install "$PWD/.downloads/remarkable-production-image-5.6.75-rm2-public-x86_64-toolchain.sh"
```

The default install location is:

```sh
.sdk/rm2/3.26.0.68
```

### 4. Build the app

```sh
./run build
```

The compiled binary is written to:

```sh
build/remarkable_sudoku
```

### 5. Run it on the tablet

```sh
./run run-device
```

When you are done testing, restore the stock UI with:

```sh
./run stop-device
```

## Embedding Sudoku Inside XOVI

This repo ships a version-gated XOVI sidebar patch for reMarkable OS `3.27.0.87`
and `3.27.0.91`.

The launcher files live in:

```sh
xovi/remarkable-sudoku-sidebar
```

It does three things:

- injects an `Apps` entry into `Sidebar.qml`
- opens an `Apps` panel inside Xochitl
- loads Sudoku as an embedded QML view inside `xochitl`

### Install the embedded XOVI extension

Build the app and embedded extension first:

```sh
./run build
```

Then install the launcher:

```sh
./run xovi-install
```

The installer copies the XOVI extension into:

```sh
/home/root/xovi/extensions.d/remarkable-sudoku-xovi.so
```

and installs the QML patch as:

```sh
/home/root/xovi/exthome/qt-resource-rebuilder/remarkable-sudoku-sidebar.qmd
```

It auto-detects the tablet firmware version, rewrites the `.qmd` version gate for
the current supported build, clears Xochitl's QML cache, and restarts XOVI so the
new `Apps` entry appears in the sidebar right away.

### Recover after a tablet firmware update

When the tablet firmware changes, the XOVI hashtab and the version-gated launcher
patch can both fall out of sync even if the Sudoku extension itself is still
installed on the tablet.

Run:

```sh
./run xovi-post-update
```

That helper:

- detects the current tablet firmware version
- rebuilds the XOVI hashtab for the new QML environment
- reapplies the Sudoku sidebar patch with the correct `VERSION` line
- reuses the extension already on the tablet when no local build artifact exists
- restarts `xochitl` under XOVI and prints recent verification logs

If the tablet prompts for a password during the hashtab rebuild, unlock it once
and let the helper continue.

Useful overrides:

- `RM2_XOVI_ROOT` changes the XOVI root. Default: `/home/root/xovi`
- `RM2_XOVI_LAUNCHER_NAME` changes the launcher directory name. Default: `remarkable-sudoku-sidebar`
- `RM2_XOVI_EXTENSION_NAME` changes the installed extension filename
- `RM2_XOVI_EXTENSION_PATH` changes the full remote extension path
- `RM2_XOVI_QTRB_DIR` changes the remote `qt-resource-rebuilder` directory
- `RM2_XOVI_REBUILD_HASHTAB_PATH` changes the remote `rebuild_hashtable` path
- `RM2_XOCHITL_VERSION` overrides the detected tablet firmware version when you
  need to force a known-compatible XOVI patch gate
- `RM2_XOVI_REUSE_REMOTE_EXTENSION=1` skips the extension upload and reuses the
  already-installed tablet copy
- `docs/xochitl-ui-debugging.md` documents the hashtab-based workflow for finding `xochitl` UI components and patch targets.

## Running Without Docker

If you already have a compatible `x86_64` Linux environment with the SDK installed, you can build directly:

```sh
export RM2_SDK_ENV="$PWD/.sdk/rm2/3.26.0.68/environment-setup-cortexa7hf-neon-remarkable-linux-gnueabi"
./scripts/build-rm2.sh
```

## Local Tests

The board logic can be tested on the host without the reMarkable SDK:

```sh
/usr/bin/cmake -S . -B build-tests -DBUILD_APP=OFF
/usr/bin/cmake --build build-tests --target sudoku_board_tests
ctest --test-dir build-tests --output-on-failure
```

## Developer Workflow

- `./run shell` opens a shell inside the Docker image, and loads the SDK environment when available.
- `./run build` cross-compiles the Qt Quick app for the tablet.
- `./run xovi-install [local-extension-path]` installs the embedded XOVI extension and restarts `xochitl`.
- `./run xovi-post-update [local-extension-path]` rebuilds the XOVI hashtab after a tablet firmware update, then reapplies the Sudoku launcher patch.
- `./run run-device [local-binary-path]` copies the binary to the tablet, stops `xochitl`, launches the app with the e-paper backend, and restores `xochitl` when the app exits.
- `./run screenshot [output-path]` saves a PNG of the current `xochitl` screen. The first run enables `framebuffer-spy` and `xovi-message-broker` inside XOVI and restarts `xochitl`.
- `./run stop-device` stops the app and starts `xochitl` again.

Useful environment variables:

- `RM2_SDK_VERSION` changes the default SDK version under `.sdk/rm2`.
- `RM2_SDK_DIR` points the build to an existing SDK directory.
- `RM2_HOST` overrides the tablet SSH target. The default is `root@10.11.99.1`.
- `RM2_REMOTE_BINARY` changes the upload path on the tablet.
- `RM2_XOVI_ROOT` changes the remote XOVI root. The default is `/home/root/xovi`.
- `RM2_XOVI_LAUNCHER_NAME` changes the custom launcher directory name under `xovi/`.
- `RM2_XOVI_EXTENSION_NAME` changes the installed embedded extension filename.
- `RM2_XOVI_EXTENSION_PATH` changes the full remote install path for the embedded extension.
- `RM2_XOVI_QTRB_DIR` changes the full remote `qt-resource-rebuilder` directory.
- `RM2_XOVI_REBUILD_HASHTAB_PATH` changes the remote `rebuild_hashtable` path used by `./run xovi-post-update`.
- `RM2_XOCHITL_VERSION` overrides the detected tablet firmware version when a known-compatible patch needs to be forced.
- `RM2_XOVI_REUSE_REMOTE_EXTENSION=1` reuses the extension already installed on the tablet instead of uploading a local build.
- `RM_INPUT_DEBUG=1` enables extra pen input logging in the app.

## Project Layout

- `src/main.cpp` boots the standalone Qt Quick wrapper.
- `src/qml/Main.qml` hosts the standalone window for direct testing.
- `src/qml/SudokuView.qml` is the embeddable game view used by both the standalone app and XOVI.
- `src/game/sudoku_board.*` contains the puzzle state and validation logic.
- `src/game/sudoku_game.*` exposes the board to QML through a list model.
- `src/input/tablet_mouse_bridge.*` translates tablet pen events into scene coordinates.
- `xovi/qml/AppsDrawer.qml` defines the embedded `Apps` panel shown inside Xochitl.
- `xovi/remarkable_sudoku_xovi.cpp` registers the embedded Sudoku types when XOVI loads the extension.
- `xovi/remarkable-sudoku-sidebar/*` contains the direct XOVI sidebar launcher.
- `tests/sudoku_board_test.cpp` covers the core board behavior.
- `scripts/build-rm2.sh` builds against the reMarkable SDK.
- `scripts/install-xovi-launcher.sh` installs the direct XOVI sidebar launcher on the tablet.
- `scripts/xovi-post-update.sh` repairs the XOVI launcher setup after a tablet firmware update.
- `scripts/run-rm2.sh` uploads and launches the binary on the tablet.
- `docs/xochitl-ui-debugging.md` explains how to inspect the live `xochitl` UI surface through the QMLDiff hashtab.
- `run` provides the Docker-based workflow.

## License

MIT. See [LICENSE](LICENSE).
