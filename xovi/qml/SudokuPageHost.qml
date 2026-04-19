import QtQuick
import RemarkableSudoku 1.0

Item {
    id: root

    signal requestClose()

    property string currentPanel: "sudoku"

    readonly property bool showingSudoku: root.currentPanel === "sudoku"
    readonly property bool showingInkDebug: root.currentPanel === "ink-debug"
    readonly property color backgroundColor: "#f7f5ef"

    function tryActivateLiveDocumentSudoku(expectedDocumentId) {
        const targetDocumentId = expectedDocumentId || ""

        for (let index = 0; index < 16; index += 1) {
            const liveDocumentView = inspector.applicationObjectWithProperty(
                "remarkableSudokuActive",
                index)
            if (!liveDocumentView) {
                break
            }

            const liveDocument = inspector.objectProperty(liveDocumentView, "document")
            const liveDocumentId = liveDocument
                ? inspector.propertyValue(liveDocument, "id")
                : ""

            if (targetDocumentId && liveDocumentId && liveDocumentId !== targetDocumentId) {
                continue
            }

            const panelReady = inspector.writeProperty(
                liveDocumentView,
                "remarkableSudokuPanel",
                "sudoku")
            const activated = inspector.writeProperty(
                liveDocumentView,
                "remarkableSudokuActive",
                true)

            if (panelReady && activated) {
                console.log(
                    "[RemarkableSudokuXovi] Activated live DocumentView Sudoku",
                    liveDocumentId,
                    inspector.summary(liveDocumentView),
                    inspector.objectPathString(liveDocumentView))
                return true
            }
        }

        console.log(
            "[RemarkableSudokuXovi] No live DocumentView accepted Sudoku activation",
            targetDocumentId)
        return false
    }

    function showSudoku() {
        if (root.tryActivateLiveDocumentSudoku()) {
            root.requestClose()
            return
        }

        sudokuHost.openMenu()
        root.currentPanel = "sudoku"
    }

    function showInkDebug() {
        root.currentPanel = "ink-debug"
    }

    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
    }

    QmlObjectInspector {
        id: inspector
    }

    SudokuAppView {
        id: sudokuHost
        anchors.fill: parent
        visible: root.showingSudoku
        backgroundColor: root.backgroundColor
        sceneRoot: root
        onRequestClose: root.requestClose()
        onRequestInkDebug: root.showInkDebug()
    }

    InkDebugAppView {
        id: inkDebugHost
        anchors.fill: parent
        visible: root.showingInkDebug
        onRequestClose: root.showSudoku()
    }
}
