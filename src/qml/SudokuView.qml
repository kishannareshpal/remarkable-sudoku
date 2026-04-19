import QtQuick

Item {
    id: root

    required property var game
    property var sessionController: null
    property Item sceneRoot: root
    property color backgroundColor: "#f7f5ef"
    property bool documentOverlayMode: false
    property bool boardInteractionEnabled: true
    property bool showingElapsedPopup: false
    property string elapsedPopupLabel: "Played for: 0s"

    signal requestClose()

    readonly property real pageMargin: Math.round(Math.min(width, height) * 0.04)
    readonly property real sectionGap: Math.max(12, Math.round(pageMargin * 0.8))
    readonly property real numberPadGap: Math.max(6, Math.round(pageMargin * 0.18))
    readonly property bool documentInkMode: root.documentOverlayMode && !root.boardInteractionEnabled
    readonly property bool fullUiVisible: !root.documentInkMode
    readonly property int controlInputDevices: root.documentOverlayMode
        ? PointerDevice.Mouse | PointerDevice.TouchScreen
        : PointerDevice.Mouse | PointerDevice.TouchScreen | PointerDevice.Stylus
    readonly property int uiInputDevices: root.documentOverlayMode
        ? (root.boardInteractionEnabled
            ? PointerDevice.Mouse | PointerDevice.TouchScreen | PointerDevice.Stylus
            : PointerDevice.Mouse | PointerDevice.TouchScreen)
        : PointerDevice.Mouse | PointerDevice.TouchScreen | PointerDevice.Stylus
    readonly property color boardFillColor: root.documentOverlayMode ? "transparent" : "#fcfbf8"
    readonly property color givenCellFillColor: root.documentOverlayMode ? "transparent" : "#ece5d4"
    readonly property color editableCellFillColor: root.documentOverlayMode ? "transparent" : "#fcfbf8"

    function currentDifficultyLabel() {
        if (!root.sessionController || !root.sessionController.activeDifficultyLabel) {
            return ""
        }

        return root.sessionController.activeDifficultyLabel
    }

    function itemContainsScenePoint(item, scenePosition) {
        const itemPoint = item.mapFromItem(root.sceneRoot, scenePosition.x, scenePosition.y)
        return itemPoint.x >= 0 && itemPoint.x < item.width && itemPoint.y >= 0 && itemPoint.y < item.height
    }

    function boardCellIndexAtScenePosition(scenePosition) {
        const boardPoint = board.mapFromItem(root.sceneRoot, scenePosition.x, scenePosition.y)
        if (boardPoint.x < 0 || boardPoint.x >= board.width || boardPoint.y < 0 || boardPoint.y >= board.height) {
            return -1
        }

        const column = Math.floor(boardPoint.x / board.cellSize)
        const row = Math.floor(boardPoint.y / board.cellSize)
        return (row * 9) + column
    }

    function handleSceneDrag(scenePosition) {
        if (root.documentInkMode || game.paused || game.solved) {
            return
        }

        const cellIndex = root.boardCellIndexAtScenePosition(scenePosition)
        if (cellIndex !== -1) {
            game.selectCell(cellIndex)
        }
    }

    function refreshElapsedPopupLabel() {
        const playedText = root.sessionController && root.sessionController.resumePlayedText
            ? root.sessionController.resumePlayedText
            : "0s"
        root.elapsedPopupLabel = "Played for: " + playedText
    }

    function toggleElapsedPopup() {
        if (!root.showingElapsedPopup) {
            root.refreshElapsedPopupLabel()
        }

        root.showingElapsedPopup = !root.showingElapsedPopup
    }

    function closeElapsedPopup() {
        root.showingElapsedPopup = false
    }

    function handleScenePress(scenePosition) {
        if (root.documentInkMode) {
            return
        }

        if (root.itemContainsScenePoint(backButton, scenePosition)) {
            root.closeElapsedPopup()
            root.requestClose()
            return
        }

        if (game.solved) {
            if (root.itemContainsScenePoint(solvedPrimaryButton, scenePosition)) {
                root.closeElapsedPopup()
                root.requestClose()
            }
            return
        }

        if (root.itemContainsScenePoint(pauseButton, scenePosition)) {
            root.closeElapsedPopup()
            game.togglePaused()
            return
        }

        if (root.itemContainsScenePoint(elapsedButton, scenePosition)) {
            root.toggleElapsedPopup()
            return
        }

        if (root.showingElapsedPopup && root.itemContainsScenePoint(elapsedPopup, scenePosition)) {
            return
        }

        if (root.showingElapsedPopup) {
            root.closeElapsedPopup()
        }

        if (game.paused) {
            if (root.itemContainsScenePoint(pausedOverlay, scenePosition)
                || root.itemContainsScenePoint(pausedPanel, scenePosition)) {
                game.togglePaused()
            }
            return
        }

        if (root.itemContainsScenePoint(notesToggleButton, scenePosition)) {
            game.toggleNotesMode()
            return
        }

        if (root.itemContainsScenePoint(hintButton, scenePosition)) {
            game.applyHint()
            return
        }

        const boardCellIndex = root.boardCellIndexAtScenePosition(scenePosition)
        if (boardCellIndex !== -1) {
            game.selectCell(boardCellIndex)
            return
        }

        const padPoint = numberPad.mapFromItem(root.sceneRoot, scenePosition.x, scenePosition.y)
        if (padPoint.x >= 0 && padPoint.x < numberPad.width && padPoint.y >= 0 && padPoint.y < numberPad.height) {
            const slotWidth = numberPad.buttonWidth + root.numberPadGap
            const digitIndex = Math.floor(padPoint.x / slotWidth)
            const digitOffset = padPoint.x - (digitIndex * slotWidth)
            if (digitIndex >= 0 && digitIndex < 9 && digitOffset <= numberPad.buttonWidth) {
                game.enterDigit(digitIndex + 1)
                return
            }
        }

        if (root.itemContainsScenePoint(clearButton, scenePosition)) {
            game.clearSelectedCell()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: root.pageMargin

        readonly property real titleFontSize: Math.max(28, Math.round(Math.min(width, height) * 0.045))
        readonly property real subtitleFontSize: Math.max(18, Math.round(titleFontSize * 0.52))
        readonly property real controlHeight: Math.max(44, Math.round(Math.min(width * 0.09, height * 0.075)))
        readonly property real footerHeight: (controlHeight * 2) + root.sectionGap
        readonly property real boardAvailableHeight: Math.max(0, footerArea.y - headerRow.height - (root.sectionGap * 2))
        readonly property real boardSize: Math.max(0, Math.min(width, boardAvailableHeight))

        Item {
            id: headerRow
            width: parent.width
            height: Math.max(backButton.height, titleColumn.implicitHeight, headerControls.height)
            visible: root.fullUiVisible

            Rectangle {
                id: backButton
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: content.controlHeight
                height: width
                color: "#f0ede4"
                border.color: "#111111"
                border.width: 0

                Image {
                    id: backIcon
                    anchors.centerIn: parent
                    width: Math.round(parent.width * 0.42)
                    height: width
                    fillMode: Image.PreserveAspectFit
                    source: "qrc:/ark/icons/arrow_left"
                }

                Item {
                    anchors.centerIn: parent
                    width: Math.round(parent.width * 0.42)
                    height: width
                    visible: backIcon.status !== Image.Ready

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(parent.width * 0.9)
                        height: 3
                        color: "#111111"
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -Math.round(parent.height * 0.2)
                        width: Math.round(parent.width * 0.52)
                        height: 3
                        color: "#111111"
                        rotation: -45
                        transformOrigin: Item.Left
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: Math.round(parent.height * 0.2)
                        width: Math.round(parent.width * 0.52)
                        height: 3
                        color: "#111111"
                        rotation: 45
                        transformOrigin: Item.Left
                    }
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    acceptedDevices: root.controlInputDevices
                    onTapped: {
                        root.closeElapsedPopup()
                        root.requestClose()
                    }
                }
            }

            Column {
                id: titleColumn
                anchors.left: backButton.right
                anchors.leftMargin: root.sectionGap
                anchors.right: headerControls.left
                anchors.rightMargin: root.sectionGap
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.max(4, Math.round(root.sectionGap * 0.2))

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    color: "#111111"
                    font.bold: true
                    font.pixelSize: content.titleFontSize
                    text: "Sudoku"
                }

                Item {
                    width: parent.width
                    height: subtitleRow.height

                    Row {
                        id: subtitleRow
                        anchors.centerIn: parent
                        spacing: Math.max(8, Math.round(root.sectionGap * 0.35))

                        Text {
                            id: difficultyText
                            color: "#444444"
                            font.pixelSize: content.subtitleFontSize
                            font.bold: true
                            text: root.currentDifficultyLabel()
                            visible: text.length > 0
                        }

                        Rectangle {
                            width: 2
                            height: Math.max(20, Math.round(pointsText.height * 0.72))
                            anchors.verticalCenter: pointsText.verticalCenter
                            color: "#666666"
                            visible: difficultyText.visible
                        }

                        Text {
                            id: pointsText
                            color: "#444444"
                            font.pixelSize: content.subtitleFontSize
                            font.bold: true
                            text: game.score + " Points"
                        }

                        Rectangle {
                            width: 2
                            height: Math.max(20, Math.round(pointsText.height * 0.72))
                            anchors.verticalCenter: pointsText.verticalCenter
                            color: "#666666"
                        }

                        Item {
                            id: elapsedButton
                            width: Math.max(20, Math.round(content.subtitleFontSize * 1.05))
                            height: width

                            Canvas {
                                id: elapsedClockIcon
                                anchors.fill: parent

                                onPaint: {
                                    const context = getContext("2d")
                                    context.clearRect(0, 0, width, height)
                                    context.strokeStyle = "#444444"
                                    context.lineWidth = Math.max(2, width * 0.1)
                                    context.beginPath()
                                    context.arc(width * 0.5, height * 0.5, width * 0.34, 0, Math.PI * 2)
                                    context.stroke()
                                    context.beginPath()
                                    context.moveTo(width * 0.5, height * 0.5)
                                    context.lineTo(width * 0.5, height * 0.28)
                                    context.moveTo(width * 0.5, height * 0.5)
                                    context.lineTo(width * 0.67, height * 0.58)
                                    context.stroke()
                                }
                            }

                            TapHandler {
                                acceptedButtons: Qt.LeftButton
                                acceptedDevices: root.controlInputDevices
                                onTapped: root.toggleElapsedPopup()
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: elapsedPopup
                readonly property real popupPadding: Math.max(12, Math.round(root.sectionGap * 0.5))
                x: {
                    const point = elapsedButton.mapToItem(content, elapsedButton.width / 2, 0)
                    return Math.max(0, Math.min(content.width - width, point.x - (width / 2)))
                }
                y: {
                    const point = elapsedButton.mapToItem(content, elapsedButton.width / 2, 0)
                    const popupGap = Math.max(10, Math.round(root.sectionGap * 0.45))
                    return Math.max(0, point.y - height - popupGap)
                }
                visible: root.showingElapsedPopup
                width: Math.max(176, elapsedPopupText.implicitWidth + (popupPadding * 2))
                height: Math.max(60, elapsedPopupText.implicitHeight + (popupPadding * 2))
                color: "#f0ede4"
                border.color: "#111111"
                border.width: 2
                z: 5

                Text {
                    id: elapsedPopupText
                    anchors.centerIn: parent
                    width: parent.width - (elapsedPopup.popupPadding * 2)
                    color: "#111111"
                    font.bold: true
                    font.pixelSize: Math.max(18, Math.round(content.subtitleFontSize * 0.92))
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.NoWrap
                    text: root.elapsedPopupLabel
                }
            }

            Row {
                id: headerControls
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.max(8, Math.round(root.sectionGap * 0.35))
                height: content.controlHeight

                Rectangle {
                    id: interactionModeButton
                    visible: root.documentOverlayMode
                    width: Math.max(Math.round(content.controlHeight * 1.7),
                                    interactionModeLabel.implicitWidth + Math.round(content.controlHeight * 0.7))
                    height: content.controlHeight
                    color: root.documentInkMode ? "#111111" : "#f0ede4"
                    border.color: "#111111"
                    border.width: 2

                    Text {
                        id: interactionModeLabel
                        anchors.centerIn: parent
                        color: root.documentInkMode ? "#fcfbf8" : "#111111"
                        font.bold: true
                        font.pixelSize: Math.max(15, Math.round(parent.height * 0.28))
                        text: root.boardInteractionEnabled ? "Board" : "Ink"
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        acceptedDevices: root.controlInputDevices
                        onTapped: {
                            root.closeElapsedPopup()
                            root.boardInteractionEnabled = !root.boardInteractionEnabled
                        }
                    }
                }

                Rectangle {
                    id: pauseButton
                    width: backButton.width
                    height: backButton.height
                    visible: !game.solved
                    color: game.paused ? "#e3ddd0" : "#f0ede4"
                    border.color: "#111111"
                    border.width: 0

                    Item {
                        id: pauseIcon
                        anchors.centerIn: parent
                        width: Math.round(parent.width * 0.42)
                        height: width
                        readonly property real barWidth: Math.max(4, Math.round(width * 0.24))
                        readonly property real barGap: Math.max(4, Math.round(width * 0.14))
                        readonly property real barStartX: Math.round((width - ((barWidth * 2) + barGap)) / 2)

                        Rectangle {
                            x: pauseIcon.barStartX
                            anchors.verticalCenter: parent.verticalCenter
                            width: pauseIcon.barWidth
                            height: parent.height
                            color: "#111111"
                            visible: !game.paused
                        }

                        Rectangle {
                            x: pauseIcon.barStartX + pauseIcon.barWidth + pauseIcon.barGap
                            anchors.verticalCenter: parent.verticalCenter
                            width: pauseIcon.barWidth
                            height: parent.height
                            color: "#111111"
                            visible: !game.paused
                        }

                        Canvas {
                            id: resumeIcon
                            anchors.fill: parent
                            visible: game.paused
                            onVisibleChanged: requestPaint()

                            onPaint: {
                                const context = getContext("2d")
                                context.clearRect(0, 0, width, height)
                                context.fillStyle = "#111111"
                                context.beginPath()
                                context.moveTo(width * 0.18, height * 0.12)
                                context.lineTo(width * 0.82, height * 0.5)
                                context.lineTo(width * 0.18, height * 0.88)
                                context.closePath()
                                context.fill()
                            }
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        acceptedDevices: root.controlInputDevices
                        onTapped: {
                            root.closeElapsedPopup()
                            game.togglePaused()
                        }
                    }
                }
            }
        }

        Item {
            id: board
            width: content.boardSize
            height: width
            anchors.top: headerRow.bottom
            anchors.topMargin: root.sectionGap
            anchors.horizontalCenter: parent.horizontalCenter

            readonly property real cellSize: width / 9
            readonly property real subgridLineThickness: 4
            readonly property real boardBorderThickness: 6

            Rectangle {
                anchors.fill: parent
                color: root.boardFillColor
                border.color: "#111111"
                border.width: board.boardBorderThickness
            }

            Repeater {
                model: game

                delegate: Rectangle {
                    id: cell

                    required property int index
                    required property int value
                    required property bool given
                    required property bool editable
                    required property bool correct
                    required property bool selected
                    required property int notes
                    readonly property bool matchingSelectedDigit: game.selectedDigit > 0 && value === game.selectedDigit
                    readonly property bool peerCell: game.selectedCellIndex >= 0 && game.isPeerCell(index)

                    x: (index % 9) * board.cellSize
                    y: Math.floor(index / 9) * board.cellSize
                    width: board.cellSize
                    height: board.cellSize
                    z: selected ? 2 : 0
                    color: given ? root.givenCellFillColor : root.editableCellFillColor
                    border.color: selected ? "#111111" : "#666666"
                    border.width: selected ? 6 : 1

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.round(board.cellSize * 0.62)
                        height: Math.max(2, Math.round(board.cellSize * 0.05))
                        color: "#3a3a3a"
                        rotation: -45
                        visible: value !== 0 && !correct
                    }

                    Grid {
                        id: notesGrid
                        anchors.fill: parent
                        anchors.margins: Math.round(board.cellSize * 0.12)
                        columns: 3
                        visible: !game.paused && value === 0 && notes !== 0

                        readonly property real noteCellWidth: width / 3
                        readonly property real noteCellHeight: height / 3

                        Repeater {
                            model: 9

                            delegate: Item {
                                required property int index
                                readonly property int noteDigit: index + 1
                                readonly property bool noteVisible: (notes & (1 << index)) !== 0
                                readonly property bool highlighted: noteVisible
                                    && game.selectedDigit === noteDigit

                                width: notesGrid.noteCellWidth
                                height: notesGrid.noteCellHeight

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: Math.max(1, Math.round(board.cellSize * 0.025))
                                    color: parent.highlighted ? "#111111" : "transparent"
                                    visible: parent.noteVisible
                                }

                                Text {
                                    anchors.fill: parent
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    color: parent.highlighted ? "#fcfbf8" : "#111111"
                                    font.bold: true
                                    font.pixelSize: Math.round(board.cellSize * 0.17)
                                    text: parent.noteVisible ? parent.noteDigit : ""
                                }
                            }
                        }
                    }

                    Text {
                        id: valueText
                        anchors.centerIn: parent
                        color: "#111111"
                        font.bold: given
                        font.pixelSize: Math.round(board.cellSize * 0.42)
                        text: value === 0 ? "" : value
                        visible: !game.paused && value !== 0
                    }

                    Rectangle {
                        width: Math.max(Math.round(board.cellSize * 0.26), Math.round(valueText.contentWidth * 0.9))
                        height: Math.max(4, Math.round(board.cellSize * 0.06))
                        anchors.horizontalCenter: valueText.horizontalCenter
                        y: valueText.y + valueText.height - Math.round(height * 0.15)
                        color: "#111111"
                        visible: !game.paused && value !== 0 && cell.matchingSelectedDigit
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        acceptedDevices: root.uiInputDevices
                        enabled: !root.documentInkMode
                        onTapped: {
                            root.closeElapsedPopup()
                            game.selectCell(index)
                        }
                    }
                }
            }

            Repeater {
                model: [0, 3, 6, 9]

                delegate: Rectangle {
                    required property int modelData

                    x: modelData === 9 ? board.width - width : Math.round(modelData * board.cellSize - (width / 2))
                    y: 0
                    width: modelData === 0 || modelData === 9
                        ? board.boardBorderThickness
                        : board.subgridLineThickness
                    height: board.height
                    color: "#111111"
                }
            }

            Repeater {
                model: [0, 3, 6, 9]

                delegate: Rectangle {
                    required property int modelData

                    x: 0
                    y: modelData === 9 ? board.height - height : Math.round(modelData * board.cellSize - (height / 2))
                    width: board.width
                    height: modelData === 0 || modelData === 9
                        ? board.boardBorderThickness
                        : board.subgridLineThickness
                    color: "#111111"
                }
            }

            Rectangle {
                id: pausedOverlay
                anchors.fill: parent
                visible: root.fullUiVisible && game.paused
                color: root.backgroundColor
                z: 5

                Rectangle {
                    id: pausedPanel
                    anchors.centerIn: parent
                    width: Math.round(board.width * 0.42)
                    height: Math.round(board.cellSize * 1.55)
                    color: "#f0ede4"
                    border.color: "#111111"
                    border.width: 2

                    Column {
                        anchors.centerIn: parent
                        spacing: Math.max(6, Math.round(board.cellSize * 0.08))

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: "#111111"
                            font.bold: true
                            font.pixelSize: Math.round(board.cellSize * 0.54)
                            text: "Paused"
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: "#444444"
                            font.pixelSize: Math.round(board.cellSize * 0.2)
                            text: "Tap to resume"
                        }
                    }
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    acceptedDevices: root.uiInputDevices
                    enabled: !root.documentInkMode
                    onTapped: {
                        root.closeElapsedPopup()
                        game.togglePaused()
                    }
                }
            }

            MultiPointTouchArea {
                anchors.fill: parent
                enabled: !root.documentInkMode
                mouseEnabled: false
                z: 4

                touchPoints: [
                    TouchPoint { id: boardTouchPoint }
                ]

                onPressed: root.handleSceneDrag(Qt.point(boardTouchPoint.sceneX, boardTouchPoint.sceneY))
                onUpdated: root.handleSceneDrag(Qt.point(boardTouchPoint.sceneX, boardTouchPoint.sceneY))
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                enabled: !root.documentInkMode
                z: 4

                function scenePosition() {
                    return board.mapToItem(root.sceneRoot, mouseX, mouseY)
                }

                onPressed: root.handleSceneDrag(scenePosition())
                onPositionChanged: {
                    if (pressed) {
                        root.handleSceneDrag(scenePosition())
                    }
                }
            }
        }

        Item {
            id: footerArea
            width: board.width
            height: content.footerHeight
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.fullUiVisible

            Item {
                id: numberPad
                width: parent.width
                height: content.controlHeight
                anchors.top: parent.top
                visible: root.fullUiVisible && !game.solved

                readonly property real buttonWidth: (width - (root.numberPadGap * 8)) / 9

                Row {
                    anchors.fill: parent
                    spacing: root.numberPadGap

                    Repeater {
                        model: [1, 2, 3, 4, 5, 6, 7, 8, 9]

                        delegate: Rectangle {
                            required property int modelData

                            width: numberPad.buttonWidth
                            height: numberPad.height
                            color: game.paused ? "#f0ede4" : "#fcfbf8"
                            border.color: "#111111"
                            border.width: 2

                            Text {
                                anchors.centerIn: parent
                                color: game.paused ? "#666666" : "#111111"
                                font.bold: true
                                font.pixelSize: Math.round(parent.height * 0.38)
                                text: modelData
                            }

                            TapHandler {
                                acceptedButtons: Qt.LeftButton
                                acceptedDevices: root.uiInputDevices
                                enabled: !root.documentInkMode
                                onTapped: {
                                    root.closeElapsedPopup()
                                    game.enterDigit(modelData)
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: actionRow
                width: parent.width
                height: content.controlHeight
                anchors.bottom: parent.bottom
                visible: root.fullUiVisible && !game.solved

                readonly property real buttonGap: root.numberPadGap
                readonly property real utilityButtonWidth: Math.max(118, Math.round(width * 0.19))
                readonly property real modeToggleWidth: width - (utilityButtonWidth * 2) - (buttonGap * 2)

                Rectangle {
                    id: notesToggleButton
                    anchors.left: parent.left
                    width: actionRow.modeToggleWidth
                    height: parent.height
                    color: game.notesMode ? "#111111" : "#f0ede4"
                    border.color: "#111111"
                    border.width: 2

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Math.max(16, Math.round(parent.height * 0.26))
                        anchors.verticalCenter: parent.verticalCenter
                        color: game.notesMode ? "#fcfbf8" : "#111111"
                        font.bold: true
                        font.pixelSize: Math.round(parent.height * 0.24)
                        text: "Notes mode"
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: Math.max(14, Math.round(parent.height * 0.22))
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(42, Math.round(parent.height * 0.62))
                        height: Math.max(24, Math.round(parent.height * 0.44))
                        radius: height / 2
                        color: game.notesMode ? "#fcfbf8" : "transparent"
                        border.color: game.notesMode ? "#fcfbf8" : "#111111"
                        border.width: 2

                        Text {
                            anchors.centerIn: parent
                            color: game.notesMode ? "#111111" : "#666666"
                            font.bold: true
                            font.pixelSize: Math.max(14, Math.round(parent.height * 0.46))
                            text: game.notesMode ? "On" : "Off"
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        acceptedDevices: root.uiInputDevices
                        enabled: !root.documentInkMode
                        onTapped: {
                            root.closeElapsedPopup()
                            game.toggleNotesMode()
                        }
                    }
                }

                Rectangle {
                    id: hintButton
                    anchors.left: notesToggleButton.right
                    anchors.leftMargin: actionRow.buttonGap
                    width: actionRow.utilityButtonWidth
                    height: parent.height
                    color: game.paused ? "#e3ddd0" : "#f0ede4"
                    border.color: "#111111"
                    border.width: 2

                    Row {
                        anchors.centerIn: parent
                        spacing: Math.max(10, Math.round(parent.height * 0.16))

                        Item {
                            width: Math.round(hintButton.height * 0.3)
                            height: width

                            Canvas {
                                anchors.fill: parent

                                onPaint: {
                                    const context = getContext("2d")
                                    context.clearRect(0, 0, width, height)
                                    context.fillStyle = "#111111"
                                    context.beginPath()
                                    context.arc(width * 0.5, height * 0.36, width * 0.28, 0, Math.PI * 2)
                                    context.fill()
                                    context.fillRect(width * 0.38, height * 0.56, width * 0.24, height * 0.18)
                                    context.fillRect(width * 0.42, height * 0.78, width * 0.16, height * 0.08)
                                }
                            }
                        }

                        Text {
                            color: "#111111"
                            font.bold: true
                            font.pixelSize: Math.round(hintButton.height * 0.28)
                            text: "Hint"
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        acceptedDevices: root.uiInputDevices
                        enabled: !root.documentInkMode
                        onTapped: {
                            root.closeElapsedPopup()
                            game.applyHint()
                        }
                    }
                }

                Rectangle {
                    id: clearButton
                    anchors.left: hintButton.right
                    anchors.leftMargin: actionRow.buttonGap
                    width: actionRow.utilityButtonWidth
                    height: parent.height
                    color: game.paused ? "#e3ddd0" : "#f0ede4"
                    border.color: "#111111"
                    border.width: 2

                    Row {
                        anchors.centerIn: parent
                        spacing: Math.max(10, Math.round(parent.height * 0.18))

                        Image {
                            id: clearIcon
                            width: Math.round(clearButton.height * 0.38)
                            height: width
                            fillMode: Image.PreserveAspectFit
                            source: "qrc:/ark/icons/eraser"
                        }

                        Text {
                            color: "#111111"
                            font.bold: true
                            font.pixelSize: Math.round(clearButton.height * 0.28)
                            text: "Clear"
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        acceptedDevices: root.uiInputDevices
                        enabled: !root.documentInkMode
                        onTapped: {
                            root.closeElapsedPopup()
                            game.clearSelectedCell()
                        }
                    }
                }
            }

            Item {
                id: solvedFooter
                anchors.fill: parent
                visible: root.fullUiVisible && game.solved

                readonly property real metricGap: Math.max(12, Math.round(root.sectionGap * 0.6))
                readonly property string playedText: root.sessionController && root.sessionController.resumePlayedText
                    ? root.sessionController.resumePlayedText
                    : "0s"

                Row {
                    id: solvedSummaryRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: content.controlHeight
                    spacing: solvedFooter.metricGap

                    Column {
                        width: Math.max(180, Math.round(parent.width * 0.36))
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Math.max(2, Math.round(root.sectionGap * 0.14))

                        Text {
                            width: parent.width
                            color: "#111111"
                            font.bold: true
                            font.pixelSize: Math.max(20, Math.round(content.subtitleFontSize * 1.08))
                            text: "Puzzle complete"
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            color: "#666666"
                            font.bold: true
                            font.pixelSize: Math.max(14, Math.round(content.subtitleFontSize * 0.72))
                            text: "Score locked in"
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        width: 2
                        height: Math.round(parent.height * 0.72)
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#111111"
                    }

                    Column {
                        width: Math.max(72, Math.round(parent.width * 0.12))
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Math.max(2, Math.round(root.sectionGap * 0.12))

                        Text {
                            width: parent.width
                            color: "#666666"
                            font.bold: true
                            font.pixelSize: Math.max(12, Math.round(content.subtitleFontSize * 0.64))
                            text: "Points"
                        }

                        Text {
                            width: parent.width
                            color: "#111111"
                            font.bold: true
                            font.pixelSize: Math.max(24, Math.round(content.subtitleFontSize * 1.16))
                            text: game.score
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        width: 2
                        height: Math.round(parent.height * 0.72)
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#111111"
                    }

                    Column {
                        width: parent.width - x
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Math.max(2, Math.round(root.sectionGap * 0.12))

                        Text {
                            width: parent.width
                            color: "#666666"
                            font.bold: true
                            font.pixelSize: Math.max(12, Math.round(content.subtitleFontSize * 0.64))
                            text: "Played for"
                        }

                        Text {
                            width: parent.width
                            color: "#111111"
                            font.bold: true
                            font.pixelSize: Math.max(20, Math.round(content.subtitleFontSize * 0.96))
                            text: solvedFooter.playedText
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    id: solvedPrimaryButton
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: content.controlHeight
                    color: "#111111"
                    border.color: "#111111"
                    border.width: 2

                    Text {
                        anchors.centerIn: parent
                        color: "#fcfbf8"
                        font.bold: true
                        font.pixelSize: Math.max(18, Math.round(content.subtitleFontSize * 0.96))
                        text: "Back to menu"
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        acceptedDevices: root.uiInputDevices
                        onTapped: {
                            root.closeElapsedPopup()
                            root.requestClose()
                        }
                    }
                }
            }
        }

        Rectangle {
            id: compactInteractionModeButton
            anchors.top: parent.top
            anchors.right: parent.right
            width: Math.max(Math.round(content.controlHeight * 1.7),
                            compactInteractionModeLabel.implicitWidth + Math.round(content.controlHeight * 0.7))
            height: content.controlHeight
            visible: root.documentInkMode
            color: "#111111"
            border.color: "#111111"
            border.width: 2
            z: 6

            Text {
                id: compactInteractionModeLabel
                anchors.centerIn: parent
                color: "#fcfbf8"
                font.bold: true
                font.pixelSize: Math.max(15, Math.round(parent.height * 0.28))
                text: "Board"
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton
                acceptedDevices: root.controlInputDevices
                onTapped: root.boardInteractionEnabled = true
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        acceptedDevices: root.controlInputDevices
        enabled: root.showingElapsedPopup

        onTapped: function(point) {
            const scenePosition = root.mapToItem(root.sceneRoot, point.position.x, point.position.y)
            if (root.itemContainsScenePoint(elapsedPopup, scenePosition)
                || root.itemContainsScenePoint(elapsedButton, scenePosition)) {
                return
            }

            root.closeElapsedPopup()
        }
    }

    Connections {
        target: root.game

        function onSolvedChanged() {
            if (root.game.solved) {
                root.closeElapsedPopup()
            }
        }
    }

    Connections {
        target: root.sessionController

        function onSessionChanged() {
            if (root.showingElapsedPopup) {
                root.refreshElapsedPopupLabel()
            }
        }
    }
}
