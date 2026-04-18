import QtQuick

Item {
    id: root

    required property var controller
    property Item sceneRoot: root
    property color backgroundColor: "#f7f5ef"
    property bool showingConfirmDialog: false
    property string pendingDifficultyId: ""
    property string pendingDifficultyTitle: ""

    signal requestClose()

    readonly property real pageMargin: Math.round(Math.min(width, height) * 0.05)
    readonly property real sectionGap: Math.max(16, Math.round(pageMargin * 0.55))
    readonly property real titleBottomGap: Math.max(28, Math.round(pageMargin * 0.42))
    readonly property real titleWidth: Math.min(width - (pageMargin * 2), 980)
    readonly property real titleGraphicWidth: Math.min(root.titleWidth, 820)
    readonly property real titleGraphicHeight: Math.round(root.titleGraphicWidth * 0.75)
    readonly property real listWidth: Math.min(width - (pageMargin * 2), 440)
    readonly property real rowHeight: Math.max(74, Math.round(Math.min(width, height) * 0.068))
    readonly property real rowBorderWidth: 2
    readonly property real listLabelSize: Math.max(22, Math.round(rowHeight * 0.34))
    readonly property real listStatusSize: Math.max(14, Math.round(rowHeight * 0.2))
    readonly property real continueHeight: Math.max(138, Math.round(root.rowHeight * 1.78))
    readonly property real exitButtonWidth: root.listWidth
    readonly property real exitButtonHeight: Math.max(62, Math.round(root.rowHeight * 0.82))
    readonly property real continueInset: Math.max(18, Math.round(root.rowHeight * 0.24))
    readonly property real continueTitleSize: Math.max(28, Math.round(root.listLabelSize * 1.08))
    readonly property real continueMetaSize: Math.max(18, Math.round(root.listStatusSize * 1.42))
    readonly property real continueActionSize: Math.max(21, Math.round(root.listStatusSize * 1.55))
    readonly property real continueActionGap: Math.max(10, Math.round(root.rowHeight * 0.16))
    readonly property real continueIconSize: Math.max(42, Math.round(root.rowHeight * 0.6))
    readonly property real confirmDialogWidth: Math.min(width - (pageMargin * 2), 520)
    readonly property real confirmDialogPadding: Math.max(24, Math.round(root.rowHeight * 0.32))
    readonly property real confirmDialogGap: Math.max(18, Math.round(root.rowHeight * 0.24))
    readonly property real confirmButtonHeight: Math.max(64, Math.round(root.rowHeight * 0.86))
    readonly property real confirmDialogMinHeight: Math.max(236, Math.round(root.rowHeight * 3.2))
    readonly property var difficultyEntries: controller.difficulties

    function itemContainsScenePoint(item, scenePosition) {
        const itemPoint = item.mapFromItem(root.sceneRoot, scenePosition.x, scenePosition.y)
        return itemPoint.x >= 0 && itemPoint.x < item.width && itemPoint.y >= 0 && itemPoint.y < item.height
    }

    function difficultyIndexAtScenePosition(scenePosition) {
        const listPoint = difficultyList.mapFromItem(root.sceneRoot, scenePosition.x, scenePosition.y)
        if (listPoint.x < 0 || listPoint.x >= difficultyList.width || listPoint.y < 0 || listPoint.y >= difficultyList.height) {
            return -1
        }

        const index = Math.floor(listPoint.y / root.rowHeight)
        return index >= 0 && index < root.difficultyEntries.length ? index : -1
    }

    function handleScenePress(scenePosition) {
        if (root.showingConfirmDialog) {
            if (root.itemContainsScenePoint(confirmCancelButton, scenePosition)) {
                root.showingConfirmDialog = false
                root.pendingDifficultyId = ""
                root.pendingDifficultyTitle = ""
            } else if (root.itemContainsScenePoint(confirmStartButton, scenePosition)) {
                root.confirmPendingGame()
            }
            return
        }

        if (root.itemContainsScenePoint(exitButton, scenePosition)) {
            root.requestClose()
            return
        }

        if (controller.hasActiveSession && root.itemContainsScenePoint(resumeRow, scenePosition)) {
            controller.resumeGame()
            return
        }

        const difficultyIndex = root.difficultyIndexAtScenePosition(scenePosition)
        if (difficultyIndex === -1) {
            return
        }

        const entry = root.difficultyEntries[difficultyIndex]
        if (entry.ready) {
            root.beginNewGame(entry.id, entry.title)
        }
    }

    function beginNewGame(difficultyId, difficultyTitle) {
        if (controller.hasActiveSession) {
            root.pendingDifficultyId = difficultyId
            root.pendingDifficultyTitle = difficultyTitle
            root.showingConfirmDialog = true
            return
        }

        controller.startNewGame(difficultyId)
    }

    function confirmPendingGame() {
        if (!root.pendingDifficultyId.length) {
            root.showingConfirmDialog = false
            return
        }

        const difficultyId = root.pendingDifficultyId
        root.showingConfirmDialog = false
        root.pendingDifficultyId = ""
        root.pendingDifficultyTitle = ""
        controller.startNewGame(difficultyId)
    }

    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: root.pageMargin

        Column {
            anchors.centerIn: parent
            spacing: root.sectionGap
            width: root.titleWidth

            Item {
                id: titleArea
                width: parent.width
                height: root.titleGraphicHeight

                Image {
                    anchors.centerIn: parent
                    width: root.titleGraphicWidth
                    height: root.titleGraphicHeight
                    fillMode: Image.PreserveAspectFit
                    source: "qrc:/remarkable-sudoku/assets/src/assets/title.png"
                }
            }

            Item {
                width: parent.width
                height: root.titleBottomGap
            }

            Item {
                visible: controller.hasActiveSession
                width: parent.width
                height: visible ? root.continueHeight : 0

                Rectangle {
                    id: resumePanel
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.listWidth
                    height: root.continueHeight
                    color: "#111111"
                    border.color: "#111111"
                    border.width: root.rowBorderWidth

                    Item {
                        id: resumeRow
                        anchors.fill: parent

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: root.continueInset
                            anchors.right: playBadge.left
                            anchors.rightMargin: root.continueInset
                            anchors.top: parent.top
                            anchors.topMargin: root.continueInset
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: root.continueInset
                            spacing: Math.max(4, Math.round(root.rowHeight * 0.07))

                            Text {
                                color: "#f7f5ef"
                                font.bold: true
                                font.pixelSize: root.continueTitleSize
                                text: controller.activeDifficultyLabel
                            }

                            Text {
                                color: "#f7f5ef"
                                font.pixelSize: root.continueMetaSize
                                text: "Points: " + controller.game.score
                            }

                            Text {
                                color: "#f7f5ef"
                                font.pixelSize: root.continueMetaSize
                                text: "Played for: " + controller.resumePlayedText
                            }

                            Item {
                                width: 1
                                height: root.continueActionGap
                            }

                            Text {
                                color: "#f7f5ef"
                                font.bold: true
                                font.pixelSize: root.continueActionSize
                                text: "Tap to resume"
                            }
                        }

                        Rectangle {
                            id: playBadge
                            anchors.top: parent.top
                            anchors.topMargin: root.continueInset
                            anchors.right: parent.right
                            anchors.rightMargin: root.continueInset
                            width: root.continueIconSize
                            height: root.continueIconSize
                            radius: width / 2
                            color: "#fcfbf8"
                            border.width: 0

                            Canvas {
                                anchors.fill: parent

                                onPaint: {
                                    const context = getContext("2d")
                                    context.clearRect(0, 0, width, height)
                                    context.fillStyle = "#111111"
                                    context.beginPath()
                                    context.moveTo(width * 0.36, height * 0.24)
                                    context.lineTo(width * 0.74, height * 0.5)
                                    context.lineTo(width * 0.36, height * 0.76)
                                    context.closePath()
                                    context.fill()
                                }
                            }
                        }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchScreen | PointerDevice.Stylus
                            enabled: !root.showingConfirmDialog
                            onTapped: controller.resumeGame()
                        }
                    }
                }
            }

            Item {
                visible: controller.hasActiveSession
                width: parent.width
                height: visible ? Math.max(10, Math.round(root.sectionGap * 0.55)) : 0
            }

            Item {
                width: parent.width
                height: startLabel.implicitHeight + Math.max(10, Math.round(root.sectionGap * 0.35)) + difficultyListPanel.height

                Text {
                    id: startLabel
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.listWidth
                    color: "#111111"
                    font.bold: true
                    font.pixelSize: Math.max(18, Math.round(root.listStatusSize * 1.35))
                    text: controller.hasActiveSession ? "or start a new game:" : "Start a new game:"
                }

                Rectangle {
                    id: difficultyListPanel
                    anchors.top: startLabel.bottom
                    anchors.topMargin: Math.max(10, Math.round(root.sectionGap * 0.35))
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.listWidth
                    height: root.rowHeight * root.difficultyEntries.length
                    color: "#ffffff"
                    border.color: "#111111"
                    border.width: root.rowBorderWidth

                    Column {
                        id: difficultyList
                        anchors.fill: parent
                        spacing: 0

                        Repeater {
                            model: root.difficultyEntries

                            delegate: Rectangle {
                                required property int index
                                required property var modelData

                                width: difficultyList.width
                                height: root.rowHeight
                                color: "#ffffff"
                                opacity: modelData.ready ? 1 : 0.7

                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 20
                                    anchors.right: actionText.left
                                    anchors.rightMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Math.max(2, Math.round(root.listStatusSize * 0.16))

                                    Text {
                                        width: parent.width
                                        color: "#111111"
                                        font.bold: true
                                        font.pixelSize: root.listLabelSize
                                        text: modelData.title
                                    }

                                    Text {
                                        width: parent.width
                                        color: "#666666"
                                        font.pixelSize: root.listStatusSize
                                        font.bold: true
                                        visible: modelData.status.length > 0
                                        text: modelData.status
                                    }
                                }

                                Text {
                                    id: actionText
                                    anchors.right: parent.right
                                    anchors.rightMargin: 20
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: "#111111"
                                    font.bold: true
                                    font.pixelSize: Math.round(root.listLabelSize * 1.08)
                                    text: modelData.ready ? "+" : "..."
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: root.rowBorderWidth
                                    color: "#111111"
                                    visible: index < root.difficultyEntries.length - 1
                                }

                                TapHandler {
                                    acceptedButtons: Qt.LeftButton
                                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchScreen | PointerDevice.Stylus
                                    enabled: modelData.ready
                                        && !root.showingConfirmDialog
                                    onTapped: root.beginNewGame(modelData.id, modelData.title)
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: "#111111"
                        border.width: root.rowBorderWidth
                    }
                }
            }

            Item {
                width: parent.width
                height: root.exitButtonHeight

                Rectangle {
                    id: exitButton
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.exitButtonWidth
                    height: root.exitButtonHeight
                    color: "transparent"
                    border.color: "#111111"
                    border.width: 0

                    Text {
                        anchors.centerIn: parent
                        color: "#111111"
                        font.bold: true
                        font.pixelSize: Math.max(18, Math.round(parent.height * 0.36))
                        text: "Exit"
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchScreen | PointerDevice.Stylus
                        enabled: !root.showingConfirmDialog
                        onTapped: root.requestClose()
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: root.showingConfirmDialog ? 0.12 : 0
            visible: root.showingConfirmDialog
            z: 4
        }

        MouseArea {
            anchors.fill: parent
            visible: root.showingConfirmDialog
            enabled: root.showingConfirmDialog
            acceptedButtons: Qt.LeftButton
            z: 4
        }

        Rectangle {
            id: confirmDialog
            anchors.centerIn: parent
            width: root.confirmDialogWidth
            height: Math.max(root.confirmDialogMinHeight, confirmContent.implicitHeight + (root.confirmDialogPadding * 2))
            color: "#fcfbf8"
            border.color: "#111111"
            border.width: root.rowBorderWidth
            visible: root.showingConfirmDialog
            z: 5

            Column {
                id: confirmContent
                anchors.fill: parent
                anchors.margins: root.confirmDialogPadding
                spacing: root.confirmDialogGap

                Text {
                    width: parent.width
                    color: "#111111"
                    font.bold: true
                    font.pixelSize: Math.max(24, Math.round(root.listLabelSize * 1.05))
                    text: "Start a new game?"
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: "#111111"
                    font.pixelSize: Math.max(18, Math.round(root.listStatusSize * 1.32))
                    text: "Starting a new game will reset your current progress."
                }

                Row {
                    width: parent.width
                    spacing: 12

                    Rectangle {
                        id: confirmCancelButton
                        width: (parent.width - parent.spacing) / 2
                        height: root.confirmButtonHeight
                        color: "#ffffff"
                        border.color: "#111111"
                        border.width: root.rowBorderWidth

                        Text {
                            anchors.centerIn: parent
                            color: "#111111"
                            font.bold: true
                            font.pixelSize: Math.max(18, Math.round(parent.height * 0.32))
                            text: "Cancel"
                        }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchScreen | PointerDevice.Stylus
                            onTapped: {
                                root.showingConfirmDialog = false
                                root.pendingDifficultyId = ""
                                root.pendingDifficultyTitle = ""
                            }
                        }
                    }

                    Rectangle {
                        id: confirmStartButton
                        width: (parent.width - parent.spacing) / 2
                        height: root.confirmButtonHeight
                        color: "#111111"
                        border.color: "#111111"
                        border.width: root.rowBorderWidth

                        Text {
                            anchors.centerIn: parent
                            color: "#fcfbf8"
                            font.bold: true
                            font.pixelSize: Math.max(18, Math.round(parent.height * 0.32))
                            text: "Start new game"
                        }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchScreen | PointerDevice.Stylus
                            onTapped: root.confirmPendingGame()
                        }
                    }
                }
            }
        }
    }
}
