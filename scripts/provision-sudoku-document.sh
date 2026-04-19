#!/usr/bin/env zsh

set -euo pipefail

host="${RM2_HOST:-root@10.11.99.1}"
remote_xochitl_dir="${RM2_XOCHITL_DATA_DIR:-/home/root/.local/share/remarkable/xochitl}"
sudoku_document_id="${RM2_SUDOKU_DOCUMENT_ID:-6f2399b2-d847-4ff4-b361-0025f566783f}"
sudoku_page_id="${RM2_SUDOKU_PAGE_ID:-1f4f1d2e-f3de-4d7e-9e0b-3b9f1a5801f2}"
sudoku_document_name="${RM2_SUDOKU_DOCUMENT_NAME:-Sudoku}"
force_recreate="${RM2_SUDOKU_FORCE_DOCUMENT:-0}"
timestamp_ms="$(( $(date +%s) * 1000 ))"
tmp_dir="$(mktemp -d)"
document_dir="${tmp_dir}/${sudoku_document_id}"

cleanup() {
  rm -rf "${tmp_dir}"
}

trap cleanup EXIT

mkdir -p "${document_dir}"

cat > "${tmp_dir}/${sudoku_document_id}.metadata" <<EOF
{
    "createdTime": "${timestamp_ms}",
    "deleted": false,
    "lastModified": "${timestamp_ms}",
    "lastOpened": "${timestamp_ms}",
    "lastOpenedPage": 0,
    "metadatamodified": true,
    "modified": true,
    "new": false,
    "parent": "",
    "pinned": false,
    "source": "",
    "synced": false,
    "type": "DocumentType",
    "version": 0,
    "visibleName": "${sudoku_document_name}"
}
EOF

cat > "${tmp_dir}/${sudoku_document_id}.content" <<EOF
{
    "cPages": {
        "lastOpened": {
            "timestamp": "1:1",
            "value": "${sudoku_page_id}"
        },
        "original": {
            "timestamp": "0:0",
            "value": -1
        },
        "pages": [
            {
                "id": "${sudoku_page_id}",
                "idx": {
                    "timestamp": "1:1",
                    "value": "ba"
                },
                "template": {
                    "timestamp": "1:1",
                    "value": "Blank"
                }
            }
        ],
        "uuids": [
        ]
    },
    "coverPageNumber": -1,
    "customZoomCenterX": 0,
    "customZoomCenterY": 936,
    "customZoomOrientation": "portrait",
    "customZoomPageHeight": 1872,
    "customZoomPageWidth": 1404,
    "customZoomScale": 1,
    "documentMetadata": {
    },
    "dummyDocument": false,
    "extraMetadata": {
        "LastActiveTool": "secondary",
        "LastBallpointColor": "Black",
        "LastBallpointSize": "1",
        "LastBallpointv2Color": "Black",
        "LastBallpointv2Size": "2",
        "LastCalligraphyColor": "Black",
        "LastCalligraphySize": "1",
        "LastEraseSectionColor": "Black",
        "LastEraseSectionSize": "1",
        "LastEraserColor": "Black",
        "LastEraserSize": "1",
        "LastEraserTool": "EraseSection",
        "LastFinelinerv2Color": "Black",
        "LastFinelinerv2Size": "2",
        "LastHighlighterv2Color": "HighlighterYellow",
        "LastHighlighterv2Size": "1",
        "LastMarkerv2Color": "Black",
        "LastMarkerv2Size": "3",
        "LastPaintbrushv2Color": "Black",
        "LastPaintbrushv2Size": "3",
        "LastPen": "Finelinerv2",
        "LastPencilColor": "Black",
        "LastPencilSize": "2",
        "LastPencilv2Color": "Black",
        "LastPencilv2Size": "3",
        "LastSelectionToolColor": "Black",
        "LastSelectionToolSize": "1",
        "LastSharpPencilv2Color": "Black",
        "LastSharpPencilv2Size": "1",
        "LastTool": "Finelinerv2",
        "LastUndefinedColor": "Black",
        "LastUndefinedSize": "2",
        "SecondaryHighlighterv2Color": "ArgbCode",
        "SecondaryHighlighterv2ColorCode": "4294962549",
        "SecondaryHighlighterv2Size": "1",
        "SecondaryPen": "Highlighterv2"
    },
    "fileType": "notebook",
    "fontName": "",
    "formatVersion": 2,
    "lineHeight": -1,
    "margins": 125,
    "orientation": "portrait",
    "pageCount": 1,
    "pageTags": [
    ],
    "sizeInBytes": "0",
    "tags": [
    ],
    "textAlignment": "justify",
    "textScale": 1,
    "zoomMode": "bestFit"
}
EOF

printf 'Blank\n' > "${tmp_dir}/${sudoku_document_id}.pagedata"
printf '{}\n' > "${tmp_dir}/${sudoku_document_id}.local"
cat > "${document_dir}/${sudoku_page_id}-metadata.json" <<'EOF'
{
    "layers": [
        {
            "name": "Layer 1"
        }
    ]
}
EOF

printf 'reMarkable .lines file, version=5%10s\001\000\000\000\000\000\000\000' '' \
  > "${document_dir}/${sudoku_page_id}.rm"

if [[ "${force_recreate}" != "1" ]] && ssh "${host}" "
  test -f '${remote_xochitl_dir}/${sudoku_document_id}.metadata' &&
  test -s '${remote_xochitl_dir}/${sudoku_document_id}/${sudoku_page_id}.rm'
"; then
  echo "Reused backing Sudoku notebook at ${host}:${remote_xochitl_dir}/${sudoku_document_id}.metadata"
  exit 0
fi

ssh "${host}" "
  mkdir -p '${remote_xochitl_dir}' '${remote_xochitl_dir}/${sudoku_document_id}'
  if [ '${force_recreate}' = '1' ]; then
    rm -f '${remote_xochitl_dir}/${sudoku_document_id}.metadata' \
          '${remote_xochitl_dir}/${sudoku_document_id}.content' \
          '${remote_xochitl_dir}/${sudoku_document_id}.pagedata' \
          '${remote_xochitl_dir}/${sudoku_document_id}.local'
    rm -rf '${remote_xochitl_dir}/${sudoku_document_id}'
    mkdir -p '${remote_xochitl_dir}/${sudoku_document_id}'
  fi
"

scp "${tmp_dir}/${sudoku_document_id}.metadata" "${host}:${remote_xochitl_dir}/${sudoku_document_id}.metadata"
scp "${tmp_dir}/${sudoku_document_id}.content" "${host}:${remote_xochitl_dir}/${sudoku_document_id}.content"
scp "${tmp_dir}/${sudoku_document_id}.pagedata" "${host}:${remote_xochitl_dir}/${sudoku_document_id}.pagedata"
scp "${tmp_dir}/${sudoku_document_id}.local" "${host}:${remote_xochitl_dir}/${sudoku_document_id}.local"
scp "${document_dir}/${sudoku_page_id}-metadata.json" "${host}:${remote_xochitl_dir}/${sudoku_document_id}/${sudoku_page_id}-metadata.json"
scp "${document_dir}/${sudoku_page_id}.rm" "${host}:${remote_xochitl_dir}/${sudoku_document_id}/${sudoku_page_id}.rm"

echo "Provisioned backing Sudoku notebook ${sudoku_document_id} on ${host}:${remote_xochitl_dir}"
