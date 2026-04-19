import QtQuick
Item {
    id: root

    signal requestClose()

    property string currentApp: "menu"
    readonly property var appEntries: [
        {
            title: qsTr("Sudoku"),
            action: "sudoku"
        },
        {
            title: qsTr("Ink Debug"),
            action: "ink-debug"
        }
    ]
    readonly property bool showingMenu: root.currentApp === "menu"
    readonly property bool showingSudoku: root.currentApp === "sudoku"
    readonly property bool showingInkDebug: root.currentApp === "ink-debug"
    readonly property real panelLeft: 412
    readonly property real bottomInset: 14
    readonly property real panelWidth: 412
    readonly property real panelBorderWidth: 2
    readonly property real menuItemHeight: 118
    readonly property real menuHeight: root.panelBorderWidth * 2 + root.appEntries.length * root.menuItemHeight
    property real touchStartX: 0
    property real touchStartY: 0
    property bool touchDragged: false
    readonly property real dragThreshold: 12

    function containsPoint(item, x, y) {
        const localPoint = item.mapFromItem(root, x, y)
        return localPoint.x >= 0 && localPoint.x < item.width
            && localPoint.y >= 0 && localPoint.y < item.height
    }

    function handleTouchPressed(x, y) {
        root.touchStartX = x
        root.touchStartY = y
        root.touchDragged = false

        if (root.showingSudoku) {
            sudokuHost.handleSceneDrag(Qt.point(x, y))
        }
    }

    function handleTouchMoved(x, y) {
        if (Math.abs(x - root.touchStartX) > root.dragThreshold || Math.abs(y - root.touchStartY) > root.dragThreshold) {
            root.touchDragged = true
        }

        if (root.showingSudoku) {
            sudokuHost.handleSceneDrag(Qt.point(x, y))
        }
    }

    function handleTouchTap(x, y) {
        if (root.showingSudoku) {
            if (root.touchDragged) {
                sudokuHost.handleSceneDrag(Qt.point(x, y))
            } else {
                sudokuHost.handleScenePress(Qt.point(x, y))
            }
            return
        }

        const entryIndex = root.entryIndexAt(x, y)
        if (entryIndex !== -1) {
            root.openEntry(entryIndex)
            return
        }

        if (!root.containsPoint(drawerPanel, x, y)) {
            root.closeDrawer()
        }
    }

    function entryIndexAt(x, y) {
        const localPoint = drawerPanel.mapFromItem(root, x, y)
        if (localPoint.x < 0 || localPoint.x >= drawerPanel.width) {
            return -1
        }

        const listY = localPoint.y - root.panelBorderWidth
        if (listY < 0 || listY >= root.appEntries.length * root.menuItemHeight) {
            return -1
        }

        return Math.floor(listY / root.menuItemHeight)
    }

    function showAppList() {
        root.currentApp = "menu"
    }

    function showSudoku() {
        sudokuHost.openMenu()
        root.currentApp = "sudoku"
    }

    function showInkDebug() {
        root.currentApp = "ink-debug"
    }

    function closeDrawer() {
        root.showAppList()
        root.requestClose()
    }

    function openEntry(index) {
        if (index < 0 || index >= root.appEntries.length) {
            return
        }

        const entry = root.appEntries[index]
        if (entry.action === "sudoku") {
            root.showSudoku()
            return
        }

        if (entry.action === "ink-debug") {
            root.showInkDebug()
        }
    }

    MultiPointTouchArea {
        anchors.fill: parent
        mouseEnabled: false
        z: 2
        enabled: root.showingSudoku
        visible: enabled

        touchPoints: [
            TouchPoint { id: primaryTouchPoint }
        ]

        onPressed: root.handleTouchPressed(primaryTouchPoint.x, primaryTouchPoint.y)
        onUpdated: root.handleTouchMoved(primaryTouchPoint.x, primaryTouchPoint.y)
        onReleased: root.handleTouchTap(primaryTouchPoint.x, primaryTouchPoint.y)
    }

    Item {
        anchors.fill: parent
        z: 0
        visible: root.showingMenu

        TapHandler {
            acceptedButtons: Qt.LeftButton
            acceptedDevices: PointerDevice.Mouse | PointerDevice.Stylus
            enabled: root.showingMenu

            onTapped: {
                if (root.showingMenu) {
                    root.closeDrawer()
                }
            }
        }
    }

    Rectangle {
        id: drawerPanel
        z: 1
        x: root.panelLeft
        y: parent.height - height - root.bottomInset
        width: root.panelWidth
        height: root.menuHeight
        visible: root.showingMenu
        color: "white"
        border.color: "black"
        border.width: root.panelBorderWidth

        Column {
            anchors.fill: parent
            anchors.margins: root.panelBorderWidth
            spacing: 0

            Repeater {
                model: root.appEntries.length

                delegate: Rectangle {
                    required property int index

                    width: drawerPanel.width - root.panelBorderWidth * 2
                    height: root.menuItemHeight
                    color: "white"

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 28
                        text: root.appEntries[index].title
                        color: "black"
                        font.pixelSize: 32
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 2
                        color: "black"
                        visible: index < root.appEntries.length - 1
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.Stylus
                        onTapped: root.openEntry(index)
                    }
                }
            }
        }
    }

    SudokuAppView {
        id: sudokuHost
        z: 1
        anchors.fill: parent
        visible: root.showingSudoku
        sceneRoot: root
        onRequestClose: root.closeDrawer()
    }

    InkDebugAppView {
        id: inkDebugHost
        z: 1
        anchors.fill: parent
        visible: root.showingInkDebug
        onRequestClose: root.closeDrawer()
    }
}
