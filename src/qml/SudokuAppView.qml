import QtQuick
import RemarkableSudoku 1.0

Item {
    id: root

    property Item sceneRoot: root
    property color backgroundColor: "#f7f5ef"

    signal requestClose()

    function openMenu() {
        controller.showMenu()
    }

    function handleScenePress(scenePosition) {
        if (controller.showingMenu) {
            menuView.handleScenePress(scenePosition)
            return
        }

        sudokuView.handleScenePress(scenePosition)
    }

    function handleSceneDrag(scenePosition) {
        if (controller.showingMenu) {
            return
        }

        sudokuView.handleSceneDrag(scenePosition)
    }

    SudokuAppController {
        id: controller
    }

    SudokuMenuView {
        id: menuView
        anchors.fill: parent
        visible: controller.showingMenu
        controller: controller
        sceneRoot: root.sceneRoot
        backgroundColor: root.backgroundColor
        onRequestClose: root.requestClose()
    }

    SudokuView {
        id: sudokuView
        anchors.fill: parent
        visible: !controller.showingMenu
        backgroundColor: root.backgroundColor
        game: controller.game
        sessionController: controller
        sceneRoot: root.sceneRoot
        onRequestClose: controller.showMenu()
    }
}
