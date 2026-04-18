# Xochitl UI Debugging

For `xochitl` UI work, the reliable source of truth is the live QMLDiff
hashtab, not direct `QFile(":/...")` reads of the embedded resources.

On reMarkable OS `3.27.0.87` and `3.27.0.91`, `qmldiff` can patch files such as
`Navigator.qml` and `Sidebar.qml`, but those same paths are not directly readable
through the Qt resource API from our extension. That means the practical workflow
for discovering UI components is:

1. Pull the live hashtab from the tablet.
2. Dump it into a readable text index with `qmldiff`.
3. Grep that index for file paths, ids, property names, and methods.
4. Build QML patches against those identifiers.

## Pull the live hashtab

The device-side hashtab lives at:

```sh
/home/root/xovi/exthome/qt-resource-rebuilder/hashtab
```

Copy it locally:

```sh
mkdir -p .tmp
scp root@10.11.99.1:/home/root/xovi/exthome/qt-resource-rebuilder/hashtab .tmp/device-hashtab
```

If `journalctl` reports that the cached hashtab is only valid for an older QML
environment version after a firmware update, rebuild it on the tablet first:

```sh
ssh root@10.11.99.1 'printf "\n" | /home/root/xovi/rebuild_hashtable'
```

Then pull the refreshed file again before inspecting it locally.

For the standard Sudoku recovery flow after a tablet update, prefer the repo
helper first:

```sh
./run xovi-post-update
```

That command rebuilds the hashtab, reapplies the version-gated Sudoku patch, and
restarts `xochitl` under XOVI before you start deeper UI debugging.

## Dump it into readable form

Use the vendored `qmldiff` binary in `.extras/`:

```sh
.extras/qmldiff/target/debug/qmldiff dump-hashtab .tmp/device-hashtab > .tmp/device-hashtab.txt
```

That gives you a flat index of:

- QML file paths
- ids
- property names
- method names
- enum values
- translatable labels

It is not raw source code, but it is enough to find the component surface that a
patch can target.

## Find the relevant UI components

The fastest pattern is to grep for the user-facing label first, then the related
ids or methods.

Examples:

```sh
rg -n "Filter by|Storage integrations|Favorites|Tags" .tmp/device-hashtab.txt
rg -n "searchLoader|showFilter|updateFiltersModel|populateInitialState" .tmp/device-hashtab.txt
rg -n "SidebarFoldout|SidebarFoldoutItem|SidebarFoldoutContentItem" .tmp/device-hashtab.txt
rg -n "Navigator.qml|Sidebar.qml|SidebarFilterItem.qml" .tmp/device-hashtab.txt
```

For the current sidebar work, the key findings were:

- `Navigator.qml` and `Sidebar.qml` are the patch targets.
- The stock `Filter by` flow hangs off `searchLoader`.
- The second-column menu behavior is built around `SidebarFoldoutItem` and
  `SidebarFoldoutContentItem`, not `SidebarFilterItem`.
- On `3.27.0.87` and `3.27.0.91`, assigning `foldoutItems` to `SidebarFilterItem` fails with
  `Cannot assign to non-existent property "foldoutItems"` and prevents
  `xochitl` from starting under XOVI.

## How to use that information

Use the hashtab as an index, then patch against the discovered ids and types.

Examples from this repo:

- `searchLoader`
- `filterColumn`
- `SidebarFoldoutItem`
- `SidebarFoldoutContentItem`
- `SidebarFoldout.Align.Bottom`

That is enough to make a targeted `.qmd` patch without having the full original
QML text checked into the repo.

## Limitations

- The hashtab does not preserve the full QML tree or source ordering.
- It tells you what names exist, not exactly how they are wired together.
- Direct runtime extraction of `:/qml/...` files from our extension has not been
  reliable on `3.27.0.87` or `3.27.0.91`, even though `qmldiff` can still patch
  those files.

Because of that, the workflow is:

1. Discover identifiers and file paths from the hashtab.
2. Make the smallest possible `.qmd` change.
3. Restart XOVI.
4. Read the `xochitl` journal for QML or `qmldiff` errors.
5. Iterate from the new evidence.

## Useful log queries

```sh
ssh root@10.11.99.1 \
  'journalctl -u xochitl --since "5 minutes ago" --no-pager | grep -E "qmldiff|QML|RemarkableSudokuXovi"'
```

That is usually enough to catch:

- missing ids in a `TRAVERSE` or `LOCATE`
- unknown properties on inserted components
- QML parse errors from a new patch
