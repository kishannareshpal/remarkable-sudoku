# AGENTS.md

## Overview

- Target device: reMarkable 2
- UI stack: Qt 6.5 + Qt Quick
- Build system: CMake
- Cross-build flow: Docker wrapper via `./run`
- Embedded integration target: `xochitl` through XOVI
- Current reMarkable OS target for XOVI patches: `3.27.0.87`

## Working Style

- Keep code modular. Do not bundle unrelated fixes together.
- Prefer self-documenting code. Add comments only when the code would otherwise be hard to review.
- Use `zsh` for shell commands.
- Do not revert unrelated user changes in the worktree.

## Primary Commands

- Build cross-compiled app and XOVI extension: `./run build`
- Install embedded XOVI extension on tablet: `./run xovi-install`
- Run standalone app on tablet: `./run run-device`
- Restore stock `xochitl` after standalone run: `./run stop-device`
- Open Docker shell with SDK when available: `./run shell`

## Build Notes

- `./run` uses `docker run -it`, so it expects a TTY.
- The default SDK path is `.sdk/rm2/3.26.0.68`.
- The app binary is built at `build/remarkable_sudoku`.
- The embedded XOVI extension is built at `build/libremarkable-sudoku-xovi.so`.

## Device Install Notes

- Default tablet host: `root@10.11.99.1`
- XOVI root on device: `/home/root/xovi`
- Installed extension path: `/home/root/xovi/extensions.d/remarkable-sudoku-xovi.so`
- Installed sidebar patch path: `/home/root/xovi/exthome/qt-resource-rebuilder/remarkable-sudoku-sidebar.qmd`

## Relevant Repo Areas

- Standalone wrapper: `src/main.cpp`
- Shared game UI: `src/qml/SudokuView.qml`
- Standalone QML shell: `src/qml/Main.qml`
- Game model: `src/game/sudoku_game.*`
- Pen bridge: `src/input/tablet_mouse_bridge.*`
- Embedded full-screen host: `xovi/qml/AppsDrawer.qml`
- XOVI extension entrypoint: `xovi/remarkable_sudoku_xovi.cpp`
- Sidebar patch: `xovi/remarkable-sudoku-sidebar/sidebar.qmd`
- XOVI installer: `scripts/install-xovi-launcher.sh`
- Xochitl UI discovery notes: `docs/xochitl-ui-debugging.md`

## Xochitl UI Discovery

- Do not assume the stock `xochitl` QML structure.
- Use the live QMLDiff hashtab as the source of truth for discoverability.
- Pull the hashtab from `/home/root/xovi/exthome/qt-resource-rebuilder/hashtab`.
- Dump it locally with `.extras/qmldiff/target/debug/qmldiff dump-hashtab`.
- Grep the dumped output for:
  - user-facing labels
  - QML file paths
  - ids
  - methods
  - foldout-related types and properties

### Important current findings

- `Navigator.qml` and `Sidebar.qml` are the main patch targets for the library sidebar.
- On `3.27.0.87`, `SidebarFilterItem { foldoutItems: ... }` crashes `xochitl`
  with `Cannot assign to non-existent property "foldoutItems"`.

## Verification

- Host tests:
  - `/usr/bin/cmake -S . -B build-tests -DBUILD_APP=OFF`
  - `/usr/bin/cmake --build build-tests --target sudoku_board_tests`
  - `ctest --test-dir build-tests --output-on-failure`
- For XOVI patch work, also inspect:
  - `ssh root@10.11.99.1 'journalctl -u xochitl --since "5 minutes ago" --no-pager | grep -E "qmldiff|QML|RemarkableSudokuXovi"'`

## Current Direction

- Sudoku should behave as an embedded `xochitl` view, not as a separate foreground process.
- The `Apps` entry should match stock sidebar interaction patterns as closely as possible.
- Prefer stock `xochitl` primitives over custom overlay geometry whenever possible.
