import QtQuick
import QtQuick.Window

Window {
    id: window

    width: Screen.width
    height: Screen.height
    visible: true
    color: "#f7f5ef"
    title: "reMarkable Sudoku"

    SudokuAppView {
        id: sudokuAppView
        anchors.fill: parent
        backgroundColor: window.color
        sceneRoot: window.contentItem
        onRequestClose: Qt.quit()
    }

    Connections {
        target: tabletInputBridge

        function onPenPressed(scenePosition) {
            sudokuAppView.handleScenePress(scenePosition)
        }

        function onPenMoved(scenePosition) {
            sudokuAppView.handleSceneDrag(scenePosition)
        }
    }
}
