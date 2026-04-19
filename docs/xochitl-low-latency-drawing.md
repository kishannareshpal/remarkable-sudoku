# Xochitl Low-Latency Drawing Notes

This document captures the current reverse-engineered view of the low-latency
ink path inside `xochitl` on reMarkable 2.

It is based on live process inspection and trace output collected on
`2026-04-18` from a tablet running:

- kernel: `5.4.70-v1.6.3-rm11x`
- userspace: `Codex Linux 5.7.115 (scarthgap)`
- `xochitl` binary: `/usr/bin/xochitl`
- `xochitl` BuildID: `587ba69fa3bf5576532b3fef053db9ec1b56e11c`
- `libqsgepaper.so` BuildID: `0192d3451363521a3cceac294d389cec91aa8540`
- `libepaper.so` BuildID: `b8d5ba053b688622e4abd82569d6da6364d8a9da`

## What We Can Say With Confidence

- `xochitl` is not using a hidden QML ink item as the core low-latency path.
- The fast ink path runs through the e-paper scenegraph plugin
  `libqsgepaper.so`.
- `xochitl` has `/dev/fb0` mapped and keeps both `/tmp/epframebuffer.lock` and
  `/tmp/epd.lock` open while running.
- The low-latency path emits repeated `pen update` swaps with tiny dirty
  regions.
- Cleanup and consolidation happen separately through `grays`, `mono only`, and
  occasional `full update` passes.

## Live Process Evidence

The live `xochitl` process had these relevant resources open:

- `/dev/input/event1`
- `/dev/input/event2`
- `/dev/fb0`
- `/tmp/epframebuffer.lock`
- `/tmp/epd.lock`

The relevant mapped libraries were:

- `/usr/lib/plugins/platforms/libepaper.so`
- `/usr/lib/plugins/scenegraph/libqsgepaper.so`
- Qt 6 Quick, QML, and GUI libraries

This strongly suggests the pipeline is:

1. tablet events enter Qt through the platform plugin
2. `xochitl` pen-input code converts them into stroke updates
3. Qt Quick requests scenegraph updates
4. `libqsgepaper.so` classifies the dirty region
5. the framebuffer backend pushes the update to the display driver

## Named Internal Surfaces

Strings visible in `xochitl` expose the pen-input layer:

- `PenInput`
- `PenInputThread`
- `PenInputHandler`
- `PenInputLineHandler`
- `PenInputSurface`
- `PenInputSurfaceManager`
- `ScenePenInputHandler`
- `PenInputGesture`
- `strokeCompleted`
- `strokePending`
- `setStrokeRegion`
- `saveStroke`

Strings visible in `libqsgepaper.so` expose the e-paper render layer:

- `EPRenderLoop`
- `EPFramebuffer`
- `EPFramebufferSwtcon`
- `EPFramebufferFusion`
- `framebufferUpdated`
- `ghostControl`
- `showForWindow`
- `hideForWindow`

This gives a useful conceptual split:

- `xochitl` owns stroke creation and scene updates
- `libqsgepaper.so` owns classification and display update strategy

## Trace Workflow

Use the helper script:

```sh
./scripts/trace-rm2-low-latency.sh
```

It temporarily injects:

- `QT_LOGGING_RULES=rm.framebuffer.debug=true;rm.framebuffer.updates.debug=true;qt.scenegraph.general.debug=true;qt.qpa.input.debug=true`
- `QSG_INFO=1`

into the XOVI-managed `xochitl` service, restarts XOVI, tails the relevant
journal lines, and restores the original service state on exit.

## Key Trace Findings

### 1. Pen strokes use a dedicated update mode

During handwriting, `xochitl` emitted many updates like:

```text
swapBuffers: QFlags(0x2|0x8) QRegion(...)
 - pen update .....: QRegion(...)
```

The important part is that low-latency ink consistently used `QFlags(0x2|0x8)`.
That is the best current signature for the fast path.

### 2. Pen updates are tiny and frequent

Fast strokes generated many micro-updates such as:

```text
QRegion(505,1139 4x5)
QRegion(516,1153 9x6)
QRegion(253,1033 10x9)
QRegion(236,818 12x20)
```

Observed behavior:

- update rectangles are very small
- they follow the stroke tip closely
- they are often single rectangles rather than large composite regions
- they arrive at very high frequency compared with normal UI redraws

That is consistent with a stroke-preview path optimized for minimal EPD work
per sample.

### 3. Pen strokes are cleaned up by other passes

After or around pen activity, the plugin emitted larger non-pen updates:

- `- mono only ....:`
- `- grays ..........:`
- `- full update`

Examples observed:

- full-screen grayscale refreshes:
  - `QRegion(0,0 1404x1872)`
- localized grayscale cleanup:
  - `QRegion(size=13, bounds=(1226,44 130x32) - [...])`
- occasional full update:
  - `swapBuffers: QFlags(0x1) QRegion(0,0 1404x1872)`
  - `- full update`

This looks like a two-stage model:

1. very fast local pen preview updates
2. slower cleanup, consolidation, and ghost-management updates

### 4. The scenegraph plugin is deciding update class

The `swapBuffers` logs came from `libqsgepaper.so`, not from app-level QML.
That means the low-latency magic is downstream of normal Qt Quick rendering.

The plugin appears to take one dirty region and split it into one or more
display-specific buckets:

- pen update
- mono only
- grays
- full update

That split is likely the core of the paper feel.

## Current Best Model

The current best model for one pen stroke is:

1. stylus arrives on `/dev/input/event1`
2. Qt delivers tablet input into `xochitl`
3. `PenInput*` classes update the active stroke surface
4. Qt Quick requests a window update
5. `EPRenderLoop` / `EPFramebuffer` process the dirty region
6. `libqsgepaper.so` classifies it as a `pen update`
7. `EPFramebufferSwtcon` sends a tiny partial display update
8. later passes repair grayscale or perform larger refreshes

## What This Means For This Repo

If the goal is `xochitl`-like ink inside Sudoku, the most promising hook points
are not in stock QML ids. They are:

- pen-input side:
  - `PenInputSurface`
  - `PenInputSurfaceManager`
  - `PenInputLineHandler`
- display side:
  - `EPFramebuffer::swapBuffers`
  - `EPFramebufferSwtcon::update`

The display side is the easier place to observe and classify behavior. The
input side is the better place to integrate custom ink behavior if we want to
reuse more of `xochitl`'s existing machinery.

## Recommended Next Step

Build a small trace extension that hooks one or both of:

- `EPFramebuffer::swapBuffers`
- `EPFramebufferSwtcon::update`

and logs:

- update flags
- region bounds
- content classification
- timestamp deltas
- call stack hashes if cheap enough

That would move us from string-level reverse engineering to function-level
evidence without having to patch the binary.
