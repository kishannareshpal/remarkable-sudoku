import QtQuick
import RemarkableSudoku 1.0

Item {
    id: root

    signal requestClose()

    readonly property color backgroundColor: "#f7f5ef"
    readonly property real controlBarHeight: 116
    readonly property real inspectorHeight: 320
    readonly property real probeListWidth: 304
    readonly property var defaultProbeTitles: [
        qsTr("Canvas Draw"),
        qsTr("impl / Active Stack"),
        qsTr("Live / DeviceSceneView"),
        qsTr("Live / Patched SceneView"),
        qsTr("Live / Patched StrokeHandler"),
        qsTr("Live / Patched Viewport"),
        qsTr("Live / Patched TileManager"),
        qsTr("Live / DocumentView"),
        qsTr("Live / Pen Surface"),
        qsTr("Live / Scene Handler"),
        qsTr("Live / ScreenDriver"),
        qsTr("Registry Scan")
    ]
    readonly property var candidateModules: [
        "xofm.libs.devicesceneview.impl",
        "xofm.libs.peninput",
        "xofm.libs.sceneview",
        "xofm.modules.peninput",
        "xofm.modules.sceneview",
        "xofm.modules.devicesceneview",
        "xofm.modules.devicesceneview.screendriver"
    ]
    readonly property var candidateTypes: [
        "DocumentView",
        "ScenePenInputHandler",
        "DeviceSceneViewBehavior",
        "DeviceSceneView",
        "DeviceSceneViewport",
        "ScreenDriver",
        "GestureInputHandler",
        "PenInput",
        "PenInputHandler",
        "PenInputLineHandler",
        "PenInputSurface",
        "PenInputSurfaceManager"
    ]
    readonly property var probeDefinitions: [
        {
            category: "probe",
            advanced: false,
            title: qsTr("Registry Scan"),
            detail: qsTr("Registered types from the private scene and pen modules"),
            source: [
                "import QtQuick",
                "QtObject {}"
            ].join("\n")
        },
        {
            category: "live",
            advanced: true,
            title: qsTr("Live / Matches"),
            detail: qsTr("Existing xochitl objects related to pen input and scene drawing"),
            liveMatchList: true
        },
        {
            category: "live",
            advanced: false,
            title: qsTr("Live / DeviceSceneView"),
            detail: qsTr("First live DeviceSceneView already running inside xochitl"),
            liveClassName: "DeviceSceneView"
        },
        {
            category: "live",
            advanced: false,
            title: qsTr("Live / Patched SceneView"),
            detail: qsTr("Patched stock DeviceSceneView from the live document page"),
            liveClassName: "RemarkableSudokuPatchedDeviceSceneView"
        },
        {
            category: "live",
            advanced: false,
            title: qsTr("Live / Patched StrokeHandler"),
            detail: qsTr("Patched live stock strokeHandler wired to the native ink scene"),
            liveClassName: "RemarkableSudokuStrokeHandler"
        },
        {
            category: "live",
            advanced: false,
            title: qsTr("Live / Patched Viewport"),
            detail: qsTr("Patched live viewport from the stock DeviceSceneView"),
            liveClassName: "RemarkableSudokuViewport"
        },
        {
            category: "live",
            advanced: false,
            title: qsTr("Live / Patched TileManager"),
            detail: qsTr("Patched live tile manager from the stock DeviceSceneView"),
            liveClassName: "RemarkableSudokuSceneTileManager"
        },
        {
            category: "live",
            advanced: false,
            title: qsTr("Live / DocumentView"),
            detail: qsTr("First live DocumentView already running inside xochitl"),
            liveClassName: "DocumentView"
        },
        {
            category: "live",
            advanced: false,
            title: qsTr("Live / ScreenDriver"),
            detail: qsTr("First live ScreenDriver already running inside xochitl"),
            liveClassName: "ScreenDriver"
        },
        {
            category: "live",
            advanced: false,
            title: qsTr("Live / Scene Handler"),
            detail: qsTr("First live ScenePenInputHandler already running inside xochitl"),
            liveClassName: "ScenePenInputHandler"
        },
        {
            category: "live",
            advanced: true,
            title: qsTr("Live / Behaviour"),
            detail: qsTr("First live DeviceSceneViewBehavior already running inside xochitl"),
            liveClassName: "DeviceSceneViewBehavior"
        },
        {
            category: "live",
            advanced: true,
            title: qsTr("Live / PenInput"),
            detail: qsTr("First live PenInput or closely matching pen object inside xochitl"),
            liveClassName: "PenInput"
        },
        {
            category: "live",
            advanced: false,
            title: qsTr("Live / Pen Surface"),
            detail: qsTr("First live PenInputSurface already running inside xochitl"),
            liveClassName: "PenInputSurface"
        },
        {
            category: "probe",
            advanced: true,
            title: qsTr("cpp / ScreenDriver"),
            detail: qsTr("Attempt ScreenDriver construction from C++"),
            constructModuleUri: "xofm.libs.devicesceneview.impl",
            constructTypeName: "ScreenDriver"
        },
        {
            category: "probe",
            advanced: true,
            title: qsTr("cpp / PenInput"),
            detail: qsTr("Attempt PenInput construction from C++"),
            constructModuleUri: "xofm.libs.peninput",
            constructTypeName: "PenInput"
        },
        {
            category: "draw",
            advanced: false,
            title: qsTr("Canvas Draw"),
            detail: qsTr("QtQuick fallback canvas for stylus and touch event testing"),
            source: [
                "import QtQuick",
                "Item {",
                "    id: drawRoot",
                "    anchors.fill: parent",
                "    property var strokeSegments: []",
                "    property real lastX: -1",
                "    property real lastY: -1",
                "    function appendPoint(x, y) {",
                "        if (drawRoot.lastX >= 0 && drawRoot.lastY >= 0) {",
                "            drawRoot.strokeSegments = drawRoot.strokeSegments.concat([{",
                "                x1: drawRoot.lastX,",
                "                y1: drawRoot.lastY,",
                "                x2: x,",
                "                y2: y",
                "            }])",
                "        }",
                "        drawRoot.lastX = x",
                "        drawRoot.lastY = y",
                "        drawCanvas.requestPaint()",
                "    }",
                "    function finishStroke() {",
                "        drawRoot.lastX = -1",
                "        drawRoot.lastY = -1",
                "    }",
                "    Rectangle {",
                "        anchors.fill: parent",
                "        color: '#f7f5ef'",
                "    }",
                "    Canvas {",
                "        id: drawCanvas",
                "        anchors.fill: parent",
                "        onPaint: {",
                "            const ctx = getContext('2d')",
                "            ctx.clearRect(0, 0, width, height)",
                "            ctx.fillStyle = '#f7f5ef'",
                "            ctx.fillRect(0, 0, width, height)",
                "            ctx.strokeStyle = 'black'",
                "            ctx.lineWidth = 3",
                "            ctx.lineCap = 'round'",
                "            ctx.lineJoin = 'round'",
                "            for (let index = 0; index < drawRoot.strokeSegments.length; ++index) {",
                "                const segment = drawRoot.strokeSegments[index]",
                "                ctx.beginPath()",
                "                ctx.moveTo(segment.x1, segment.y1)",
                "                ctx.lineTo(segment.x2, segment.y2)",
                "                ctx.stroke()",
                "            }",
                "        }",
                "    }",
                "    MouseArea {",
                "        anchors.fill: parent",
                "        hoverEnabled: true",
                "        onPressed: {",
                "            console.log('[InkDebug] Canvas press', mouse.x, mouse.y)",
                "            drawRoot.lastX = mouse.x",
                "            drawRoot.lastY = mouse.y",
                "        }",
                "        onPositionChanged: {",
                "            if (pressed) {",
                "                drawRoot.appendPoint(mouse.x, mouse.y)",
                "            }",
                "        }",
                "        onReleased: {",
                "            console.log('[InkDebug] Canvas release', mouse.x, mouse.y)",
                "            drawRoot.finishStroke()",
                "        }",
                "        onDoubleClicked: {",
                "            drawRoot.strokeSegments = []",
                "            drawCanvas.requestPaint()",
                "            console.log('[InkDebug] Canvas cleared')",
                "        }",
                "    }",
                "    MultiPointTouchArea {",
                "        anchors.fill: parent",
                "        mouseEnabled: false",
                "        touchPoints: [TouchPoint { id: primaryTouchPoint }]",
                "        onPressed: {",
                "            console.log('[InkDebug] Touch press', primaryTouchPoint.x, primaryTouchPoint.y)",
                "            drawRoot.lastX = primaryTouchPoint.x",
                "            drawRoot.lastY = primaryTouchPoint.y",
                "        }",
                "        onUpdated: drawRoot.appendPoint(primaryTouchPoint.x, primaryTouchPoint.y)",
                "        onReleased: drawRoot.finishStroke()",
                "    }",
                "}"
            ].join("\n")
        },
        {
            category: "probe",
            advanced: false,
            title: qsTr("impl / Scene Handler"),
            detail: qsTr("ScenePenInputHandler from xofm.libs.devicesceneview.impl 1.0"),
            moduleUri: "xofm.libs.devicesceneview.impl",
            typeName: "ScenePenInputHandler",
            source: [
                "import QtQuick",
                "import xofm.libs.devicesceneview.impl 1.0",
                "ScenePenInputHandler {}"
            ].join("\n")
        },
        {
            category: "probe",
            advanced: false,
            title: qsTr("impl / Behaviour"),
            detail: qsTr("DeviceSceneViewBehavior from xofm.libs.devicesceneview.impl 1.0"),
            moduleUri: "xofm.libs.devicesceneview.impl",
            typeName: "DeviceSceneViewBehavior",
            source: [
                "import QtQuick",
                "import xofm.libs.devicesceneview.impl 1.0",
                "DeviceSceneViewBehavior {}"
            ].join("\n")
        },
        {
            category: "probe",
            advanced: true,
            title: qsTr("impl / Pair"),
            detail: qsTr("Scene handler and behaviour created together"),
            source: [
                "import QtQuick",
                "import xofm.libs.devicesceneview.impl 1.0",
                "Item {",
                "    property alias handler: handler",
                "    property alias behavior: behavior",
                "    ScenePenInputHandler { id: handler }",
                "    DeviceSceneViewBehavior { id: behavior }",
                "}"
            ].join("\n")
        },
        {
            category: "probe",
            advanced: true,
            title: qsTr("impl / Stack"),
            detail: qsTr("Scene handler, behaviour, and ScreenDriver created together"),
            source: [
                "import QtQuick",
                "import xofm.libs.devicesceneview.impl 1.0",
                "Item {",
                "    property alias handler: handler",
                "    property alias behavior: behavior",
                "    property alias screenDriver: screenDriver",
                "    ScenePenInputHandler { id: handler }",
                "    DeviceSceneViewBehavior { id: behavior }",
                "    ScreenDriver {",
                "        id: screenDriver",
                "        visible: true",
                "        notePage: false",
                "        pendingTiles: false",
                "        penClose: false",
                "        gestureMode: false",
                "        selectionMode: false",
                "        textMode: false",
                "        snapMode: false",
                "        quickBrowseMode: false",
                "    }",
                "}"
            ].join("\n")
        },
        {
            category: "draw",
            advanced: false,
            title: qsTr("impl / Active Stack"),
            detail: qsTr("Full-screen stack with signal logging while drawing"),
            source: [
                "import QtQuick",
                "import xofm.libs.devicesceneview.impl 1.0",
                "Item {",
                "    id: stackRoot",
                "    anchors.fill: parent",
                "    property int strokeCount: 0",
                "    property int gestureCount: 0",
                "    property int fallbackPressCount: 0",
                "    property int fallbackTouchCount: 0",
                "    property string lastEvent: 'idle'",
                "    Rectangle {",
                "        anchors.fill: parent",
                "        color: '#f7f5ef'",
                "    }",
                "    Text {",
                "        anchors.left: parent.left",
                "        anchors.top: parent.top",
                "        anchors.margins: 24",
                "        width: parent.width - 48",
                "        color: 'black'",
                "        wrapMode: Text.Wrap",
                "        font.pixelSize: 28",
                "        z: 2",
                "        text: 'Active Stack\\nlast=' + stackRoot.lastEvent + '\\nstrokes=' + stackRoot.strokeCount + '\\ngestures=' + stackRoot.gestureCount + '\\nmouse=' + stackRoot.fallbackPressCount + '\\ntouch=' + stackRoot.fallbackTouchCount",
                "    }",
                "    Rectangle {",
                "        anchors.centerIn: parent",
                "        width: 420",
                "        height: 180",
                "        color: 'white'",
                "        border.color: 'black'",
                "        border.width: 3",
                "        radius: 18",
                "        z: 1",
                "        Text {",
                "            anchors.centerIn: parent",
                "            color: 'black'",
                "            font.pixelSize: 34",
                "            text: stackRoot.lastEvent",
                "        }",
                "    }",
                "    property alias handler: handler",
                "    property alias behavior: behavior",
                "    property alias screenDriver: screenDriver",
                "    ScenePenInputHandler {",
                "        id: handler",
                "    }",
                "    DeviceSceneViewBehavior {",
                "        id: behavior",
                "    }",
                "    ScreenDriver {",
                "        id: screenDriver",
                "        visible: true",
                "        notePage: false",
                "        pendingTiles: false",
                "        penClose: false",
                "        gestureMode: false",
                "        selectionMode: false",
                "        textMode: false",
                "        snapMode: false",
                "        quickBrowseMode: false",
                "    }",
                "    Component.onCompleted: {",
                "        stackRoot.lastEvent = 'ready'",
                "        handler.setShapeDetection(false)",
                "        console.log('[InkDebug] ActiveStack ready intermediate=', handler.queryIntermediateState())",
                "    }",
                "    MouseArea {",
                "        anchors.fill: parent",
                "        hoverEnabled: true",
                "        z: 3",
                "        onPressed: {",
                "            stackRoot.fallbackPressCount += 1",
                "            stackRoot.lastEvent = 'mousePress'",
                "            console.log('[InkDebug] ActiveStack mousePress', mouse.x, mouse.y, stackRoot.fallbackPressCount)",
                "        }",
                "        onReleased: {",
                "            stackRoot.lastEvent = 'mouseRelease'",
                "            console.log('[InkDebug] ActiveStack mouseRelease', mouse.x, mouse.y)",
                "        }",
                "        onPositionChanged: {",
                "            if (pressed) {",
                "                stackRoot.lastEvent = 'mouseMove'",
                "            }",
                "        }",
                "    }",
                "    MultiPointTouchArea {",
                "        anchors.fill: parent",
                "        z: 4",
                "        mouseEnabled: false",
                "        touchPoints: [TouchPoint { id: activeStackTouchPoint }]",
                "        onPressed: {",
                "            stackRoot.fallbackTouchCount += 1",
                "            stackRoot.lastEvent = 'touchPress'",
                "            console.log('[InkDebug] ActiveStack touchPress', activeStackTouchPoint.x, activeStackTouchPoint.y, stackRoot.fallbackTouchCount)",
                "        }",
                "        onUpdated: stackRoot.lastEvent = 'touchMove'",
                "        onReleased: {",
                "            stackRoot.lastEvent = 'touchRelease'",
                "            console.log('[InkDebug] ActiveStack touchRelease', activeStackTouchPoint.x, activeStackTouchPoint.y)",
                "        }",
                "    }",
                "    Connections {",
                "        target: handler",
                "        function onStrokeCompleted(line) {",
                "            stackRoot.strokeCount += 1",
                "            stackRoot.lastEvent = 'strokeCompleted'",
                "            console.log('[InkDebug] ActiveStack strokeCompleted', stackRoot.strokeCount)",
                "        }",
                "        function onPasteTriggered(position) {",
                "            stackRoot.lastEvent = 'pasteTriggered'",
                "            console.log('[InkDebug] ActiveStack pasteTriggered', position)",
                "        }",
                "        function onGesturesRejected() {",
                "            stackRoot.lastEvent = 'gesturesRejected'",
                "            console.log('[InkDebug] ActiveStack gesturesRejected')",
                "        }",
                "        function onGestureStarted(gestureType, metadata) {",
                "            stackRoot.gestureCount += 1",
                "            stackRoot.lastEvent = 'gestureStarted'",
                "            console.log('[InkDebug] ActiveStack gestureStarted', gestureType, metadata)",
                "        }",
                "        function onGestureMoved(position) {",
                "            stackRoot.lastEvent = 'gestureMoved'",
                "            console.log('[InkDebug] ActiveStack gestureMoved', position)",
                "        }",
                "        function onGestureEnded(position) {",
                "            stackRoot.lastEvent = 'gestureEnded'",
                "            console.log('[InkDebug] ActiveStack gestureEnded', position)",
                "        }",
                "    }",
                "    Connections {",
                "        target: screenDriver",
                "        function onPendingTilesChanged() {",
                "            console.log('[InkDebug] ActiveStack pendingTilesChanged', screenDriver.pendingTiles)",
                "        }",
                "        function onFinalizeNewPage() {",
                "            console.log('[InkDebug] ActiveStack finalizeNewPage')",
                "        }",
                "        function onNotifyDidQuickBrowse() {",
                "            console.log('[InkDebug] ActiveStack notifyDidQuickBrowse')",
                "        }",
                "    }",
                "}"
            ].join("\n")
        },
        {
            category: "draw",
            advanced: false,
            title: qsTr("peninput / Handler"),
            detail: qsTr("Standalone PenInputHandler from xofm.modules.peninput"),
            source: [
                "import QtQuick",
                "import xofm.modules.peninput",
                "PenInputHandler {}"
            ].join("\n")
        },
        {
            category: "draw",
            advanced: false,
            title: qsTr("peninput / Surface handler"),
            detail: qsTr("PenInputSurface wired with handler: ScenePenInputHandler"),
            source: [
                "import QtQuick",
                "import xofm.modules.peninput",
                "import xofm.libs.devicesceneview.impl 1.0",
                "Item {",
                "    id: surfaceRoot",
                "    anchors.fill: parent",
                "    property int strokeCount: 0",
                "    property int gestureCount: 0",
                "    property string lastEvent: 'idle'",
                "    Rectangle {",
                "        anchors.fill: parent",
                "        color: '#f7f5ef'",
                "    }",
                "    Text {",
                "        anchors.left: parent.left",
                "        anchors.top: parent.top",
                "        anchors.margins: 24",
                "        width: parent.width - 48",
                "        color: 'black'",
                "        wrapMode: Text.Wrap",
                "        font.pixelSize: 28",
                "        text: 'Surface handler\\nlast=' + surfaceRoot.lastEvent + '\\nstrokes=' + surfaceRoot.strokeCount + '\\ngestures=' + surfaceRoot.gestureCount",
                "    }",
                "    property alias surface: surface",
                "    property alias handler: sceneHandler",
                "    PenInputSurface {",
                "        id: surface",
                "        anchors.fill: parent",
                "        handler: sceneHandler",
                "    }",
                "    ScenePenInputHandler {",
                "        id: sceneHandler",
                "    }",
                "    Component.onCompleted: {",
                "        surfaceRoot.lastEvent = 'ready'",
                "        console.log('[InkDebug] SurfaceHandler ready')",
                "    }",
                "    Connections {",
                "        target: sceneHandler",
                "        function onStrokeCompleted(line) {",
                "            surfaceRoot.strokeCount += 1",
                "            surfaceRoot.lastEvent = 'strokeCompleted'",
                "            console.log('[InkDebug] SurfaceHandler strokeCompleted', surfaceRoot.strokeCount)",
                "        }",
                "        function onGestureStarted(gestureType, metadata) {",
                "            surfaceRoot.gestureCount += 1",
                "            surfaceRoot.lastEvent = 'gestureStarted'",
                "            console.log('[InkDebug] SurfaceHandler gestureStarted', gestureType, metadata)",
                "        }",
                "        function onGestureMoved(position) {",
                "            surfaceRoot.lastEvent = 'gestureMoved'",
                "            console.log('[InkDebug] SurfaceHandler gestureMoved', position)",
                "        }",
                "        function onGestureEnded(position) {",
                "            surfaceRoot.lastEvent = 'gestureEnded'",
                "            console.log('[InkDebug] SurfaceHandler gestureEnded', position)",
                "        }",
                "    }",
                "}"
            ].join("\n")
        },
        {
            category: "draw",
            advanced: false,
            title: qsTr("peninput / Surface penInputHandler"),
            detail: qsTr("PenInputSurface wired with penInputHandler: ScenePenInputHandler"),
            source: [
                "import QtQuick",
                "import xofm.modules.peninput",
                "import xofm.libs.devicesceneview.impl 1.0",
                "Item {",
                "    id: surfaceRoot",
                "    anchors.fill: parent",
                "    property int strokeCount: 0",
                "    property int gestureCount: 0",
                "    property string lastEvent: 'idle'",
                "    Rectangle {",
                "        anchors.fill: parent",
                "        color: '#f7f5ef'",
                "    }",
                "    Text {",
                "        anchors.left: parent.left",
                "        anchors.top: parent.top",
                "        anchors.margins: 24",
                "        width: parent.width - 48",
                "        color: 'black'",
                "        wrapMode: Text.Wrap",
                "        font.pixelSize: 28",
                "        text: 'Surface penInputHandler\\nlast=' + surfaceRoot.lastEvent + '\\nstrokes=' + surfaceRoot.strokeCount + '\\ngestures=' + surfaceRoot.gestureCount",
                "    }",
                "    property alias surface: surface",
                "    property alias handler: sceneHandler",
                "    PenInputSurface {",
                "        id: surface",
                "        anchors.fill: parent",
                "        penInputHandler: sceneHandler",
                "    }",
                "    ScenePenInputHandler {",
                "        id: sceneHandler",
                "    }",
                "    Component.onCompleted: {",
                "        surfaceRoot.lastEvent = 'ready'",
                "        console.log('[InkDebug] SurfacePenInputHandler ready')",
                "    }",
                "    Connections {",
                "        target: sceneHandler",
                "        function onStrokeCompleted(line) {",
                "            surfaceRoot.strokeCount += 1",
                "            surfaceRoot.lastEvent = 'strokeCompleted'",
                "            console.log('[InkDebug] SurfacePenInputHandler strokeCompleted', surfaceRoot.strokeCount)",
                "        }",
                "        function onGestureStarted(gestureType, metadata) {",
                "            surfaceRoot.gestureCount += 1",
                "            surfaceRoot.lastEvent = 'gestureStarted'",
                "            console.log('[InkDebug] SurfacePenInputHandler gestureStarted', gestureType, metadata)",
                "        }",
                "        function onGestureMoved(position) {",
                "            surfaceRoot.lastEvent = 'gestureMoved'",
                "            console.log('[InkDebug] SurfacePenInputHandler gestureMoved', position)",
                "        }",
                "        function onGestureEnded(position) {",
                "            surfaceRoot.lastEvent = 'gestureEnded'",
                "            console.log('[InkDebug] SurfacePenInputHandler gestureEnded', position)",
                "        }",
                "    }",
                "}"
            ].join("\n")
        },
        {
            category: "probe",
            advanced: false,
            title: qsTr("sceneview / Viewport"),
            detail: qsTr("DeviceSceneViewport from xofm.modules.sceneview"),
            source: [
                "import QtQuick",
                "import xofm.modules.sceneview",
                "DeviceSceneViewport {}"
            ].join("\n")
        },
        {
            category: "probe",
            advanced: true,
            title: qsTr("impl / ScreenDriver"),
            detail: qsTr("Bare ScreenDriver from xofm.libs.devicesceneview.impl 1.0"),
            moduleUri: "xofm.libs.devicesceneview.impl",
            typeName: "ScreenDriver",
            source: [
                "import QtQuick",
                "import xofm.libs.devicesceneview.impl 1.0",
                "ScreenDriver {}"
            ].join("\n")
        },
        {
            category: "probe",
            advanced: false,
            title: qsTr("impl / ScreenDriver stub"),
            detail: qsTr("ScreenDriver with guessed defaults for required properties"),
            moduleUri: "xofm.libs.devicesceneview.impl",
            typeName: "ScreenDriver",
            source: [
                "import QtQuick",
                "import xofm.libs.devicesceneview.impl 1.0",
                "ScreenDriver {",
                "    visible: true",
                "    notePage: false",
                "    pendingTiles: false",
                "    penClose: false",
                "    gestureMode: false",
                "    selectionMode: false",
                "    textMode: false",
                "    snapMode: false",
                "    quickBrowseMode: false",
                "}"
            ].join("\n")
        },
        {
            category: "probe",
            advanced: true,
            title: qsTr("peninput / PenInput"),
            detail: qsTr("PenInput from xofm.libs.peninput 1.0"),
            moduleUri: "xofm.libs.peninput",
            typeName: "PenInput",
            source: [
                "import QtQuick",
                "import xofm.libs.peninput 1.0",
                "PenInput {}"
            ].join("\n")
        }
    ]

    property int probeIndex: 0
    property var activeProbe: null
    property bool activeProbeOwned: false
    property string creationStatus: ""
    property string creationError: ""
    property string typeLookupText: ""
    property string typePropertiesText: ""
    property string inspectionText: ""

    function selectedProbe() {
        if (root.probeIndex < 0 || root.probeIndex >= root.probeDefinitions.length) {
            return null
        }

        return root.probeDefinitions[root.probeIndex]
    }

    function visibleProbeIndexes() {
        const visibleIndexes = []
        for (let titleIndex = 0; titleIndex < root.defaultProbeTitles.length; ++titleIndex) {
            const expectedTitle = root.defaultProbeTitles[titleIndex]

            for (let definitionIndex = 0; definitionIndex < root.probeDefinitions.length; ++definitionIndex) {
                const definition = root.probeDefinitions[definitionIndex]
                if (definition.title !== expectedTitle) {
                    continue
                }

                visibleIndexes.push(definitionIndex)
                break
            }
        }

        return visibleIndexes
    }

    function ensureVisibleProbeSelected() {
        const visibleIndexes = root.visibleProbeIndexes()
        if (visibleIndexes.length === 0) {
            root.destroyProbe()
            root.creationError = ""
            root.creationStatus = qsTr("No probes are available in this view")
            root.inspectionText = ""
            return
        }

        for (let index = 0; index < visibleIndexes.length; ++index) {
            if (visibleIndexes[index] === root.probeIndex) {
                return
            }
        }

        root.selectProbe(visibleIndexes[0])
    }

    function visibleProbeIndexAt(listIndex) {
        const visibleIndexes = root.visibleProbeIndexes()
        if (listIndex < 0 || listIndex >= visibleIndexes.length) {
            return -1
        }

        return visibleIndexes[listIndex]
    }

    function selectProbe(index) {
        if (index < 0 || index >= root.probeDefinitions.length) {
            return
        }

        root.probeIndex = index
        root.reloadProbe()
    }

    function logLines(prefix, lines) {
        for (let index = 0; index < lines.length; ++index) {
            console.log(prefix, lines[index])
        }
    }

    function numberedSourceLines(source) {
        const sourceLines = source.split("\n")
        const lines = []

        for (let index = 0; index < sourceLines.length; ++index) {
            lines.push((index + 1) + ": " + sourceLines[index])
        }

        return lines
    }

    function describeObject(label, object) {
        if (!object) {
            return []
        }

        const lines = [label + ": " + inspector.summary(object)]
        const objectPath = inspector.objectPathString(object)
        if (objectPath.length > 0) {
            lines.push("Path:")
            lines.push(objectPath)
        }

        const propertyLines = inspector.formattedProperties(object)
        const constructorLines = inspector.formattedConstructors(object)
        const methodLines = inspector.formattedMethods(object)

        if (propertyLines.length > 0) {
            lines.push("Properties:")
            lines.push(propertyLines.join("\n"))
        }

        if (constructorLines.length > 0) {
            lines.push("Constructors:")
            lines.push(constructorLines.join("\n"))
        }

        if (methodLines.length > 0) {
            lines.push("Methods:")
            lines.push(methodLines.join("\n"))
        }

        return lines
    }

    function describeObjectProperty(object, propertyName) {
        if (!inspector.hasProperty(object, propertyName)) {
            return []
        }

        const relatedObject = inspector.objectProperty(object, propertyName)
        if (relatedObject) {
            return root.describeObject(propertyName, relatedObject)
        }

        return [propertyName + ": " + inspector.propertyValue(object, propertyName)]
    }

    function refreshTypeLookup() {
        const sections = []
        const registeredLines = inspector.registeredTypeMatches(root.candidateModules, root.candidateTypes, 1, 0)
        const liveLines = inspector.applicationObjectMatches(root.candidateTypes, 24)

        if (registeredLines.length > 0) {
            sections.push(qsTr("Registered candidate types") + ":\n" + registeredLines.join("\n"))
        }

        if (liveLines.length > 0) {
            sections.push(qsTr("Live candidate objects") + ":\n" + liveLines.join("\n"))
        }

        if (sections.length > 0) {
            root.typeLookupText = sections.join("\n\n")
            return
        }

        root.typeLookupText = qsTr("No candidate types or live drawing objects were discovered.")
    }

    function refreshTypeProperties() {
        const definition = root.selectedProbe()
        if (!definition.moduleUri || !definition.typeName) {
            root.typePropertiesText = ""
            return
        }

        const lines = inspector.qmlTypeProperties(definition.moduleUri, 1, 0, definition.typeName)
        if (lines.length > 0) {
            root.typePropertiesText = qsTr("Type properties") + ":\n" + lines.join("\n")
            return
        }

        root.typePropertiesText = qsTr("Type properties were unavailable for %1.").arg(definition.typeName)
    }

    function refreshInspection() {
        if (!root.activeProbe) {
            root.inspectionText = ""
            return
        }

        const sections = []
        sections.push(root.describeObject(qsTr("Probe"), root.activeProbe).join("\n"))

        const relatedSections = []
        const relatedPropertyNames = [
            "parent",
            "parentItem",
            "view",
            "documentView",
            "handler",
            "behavior",
            "viewBehavior",
            "screenDriver",
            "driver",
            "penInputHandler",
            "manager",
            "surface",
            "surfaceManager",
            "viewport",
            "sceneController",
            "tileManager",
            "framebuffer",
            "page",
            "config"
        ]
        for (let index = 0; index < relatedPropertyNames.length; ++index) {
            const relatedLines = root.describeObjectProperty(root.activeProbe, relatedPropertyNames[index])
            if (relatedLines.length > 0) {
                relatedSections.push(relatedLines.join("\n"))
            }
        }

        if (relatedSections.length > 0) {
            sections.push(relatedSections.join("\n\n"))
        }

        const childLines = inspector.childSummaries(root.activeProbe)
        if (childLines.length > 0) {
            sections.push(qsTr("Children") + ":\n" + childLines.join("\n"))
        }

        root.inspectionText = sections.join("\n\n")
    }

    function logCurrentProbeState() {
        const definition = root.selectedProbe()
        if (!definition) {
            return
        }

        console.log("[InkDebug] Selected", definition.title)
        if (definition.moduleUri && definition.typeName) {
            console.log("[InkDebug] QmlType", definition.moduleUri, definition.typeName)
            root.logLines(
                "[InkDebug] TypeProperty",
                inspector.qmlTypeProperties(definition.moduleUri, 1, 0, definition.typeName))
        }

        root.logLines(
            "[InkDebug] TypeMatch",
            inspector.registeredTypeMatches(root.candidateModules, root.candidateTypes, 1, 0))
        root.logLines(
            "[InkDebug] LiveMatch",
            inspector.applicationObjectMatches(root.candidateTypes, 24))

        if (!root.activeProbe) {
            return
        }

        console.log("[InkDebug] ProbeObject", inspector.summary(root.activeProbe))
        console.log("[InkDebug] ProbePath", inspector.objectPathString(root.activeProbe))
        root.logLines("[InkDebug] Property", inspector.formattedProperties(root.activeProbe))
        root.logLines("[InkDebug] Constructor", inspector.formattedConstructors(root.activeProbe))
        root.logLines("[InkDebug] Method", inspector.formattedMethods(root.activeProbe))

        const relatedPropertyNames = [
            "parent",
            "parentItem",
            "view",
            "documentView",
            "handler",
            "behavior",
            "viewBehavior",
            "screenDriver",
            "driver",
            "penInputHandler",
            "manager",
            "surface",
            "surfaceManager",
            "viewport",
            "sceneController",
            "tileManager",
            "framebuffer",
            "page",
            "config"
        ]
        for (let index = 0; index < relatedPropertyNames.length; ++index) {
            const propertyName = relatedPropertyNames[index]
            if (!inspector.hasProperty(root.activeProbe, propertyName)) {
                continue
            }

            const relatedObject = inspector.objectProperty(root.activeProbe, propertyName)
            if (relatedObject) {
                console.log("[InkDebug] RelatedObject", propertyName, inspector.summary(relatedObject))
                console.log("[InkDebug] RelatedPath", propertyName, inspector.objectPathString(relatedObject))
                root.logLines(
                    "[InkDebug] RelatedProperty " + propertyName,
                    inspector.formattedProperties(relatedObject))
                root.logLines(
                    "[InkDebug] RelatedConstructor " + propertyName,
                    inspector.formattedConstructors(relatedObject))
                root.logLines(
                    "[InkDebug] RelatedMethod " + propertyName,
                    inspector.formattedMethods(relatedObject))
            } else {
                console.log(
                    "[InkDebug] RelatedValue",
                    propertyName,
                    inspector.propertyValue(root.activeProbe, propertyName))
            }
        }
    }

    function destroyProbe() {
        if (!root.activeProbe) {
            return
        }

        if (root.activeProbeOwned && root.activeProbe.destroy) {
            root.activeProbe.destroy()
        }

        root.activeProbe = null
        root.activeProbeOwned = false
    }

    function reloadProbe() {
        const definition = root.selectedProbe()
        if (!definition) {
            root.creationStatus = qsTr("No probe selected")
            root.creationError = ""
            root.inspectionText = ""
            return
        }

        root.destroyProbe()
        root.creationError = ""
        root.creationStatus = qsTr("Loading %1").arg(definition.title)
        root.inspectionText = ""
        root.refreshTypeLookup()
        root.refreshTypeProperties()

        if (definition.liveMatchList) {
            const liveLines = inspector.applicationObjectMatches(root.candidateTypes, 48)
            root.creationStatus = qsTr("Scanned live drawing objects")
            root.inspectionText = liveLines.length > 0
                ? qsTr("Live candidate objects") + ":\n" + liveLines.join("\n")
                : qsTr("No live drawing objects matched the current candidate list.")
            root.logCurrentProbeState()
            return
        }

        if (definition.liveClassName) {
            root.activeProbe = inspector.applicationObject(definition.liveClassName, 0)
            root.activeProbeOwned = false
            if (root.activeProbe) {
                root.creationStatus = qsTr("Attached to live %1").arg(definition.liveClassName)
                root.refreshInspection()
                console.log("[InkDebug] Attached", definition.title, inspector.summary(root.activeProbe))
            } else {
                root.creationStatus = qsTr("No live %1 found").arg(definition.liveClassName)
                root.inspectionText = qsTr("No live object matched %1.").arg(definition.liveClassName)
                console.log("[InkDebug] Missing", definition.title, definition.liveClassName)
            }
            root.logCurrentProbeState()
            return
        }

        if (definition.constructModuleUri && definition.constructTypeName) {
            const lines = inspector.constructedTypeProperties(
                definition.constructModuleUri,
                1,
                0,
                definition.constructTypeName)
            root.creationStatus = qsTr("C++ construction probe finished for %1").arg(definition.constructTypeName)
            root.inspectionText = lines.join("\n")
            root.logLines("[InkDebug] Constructed " + definition.title, lines)
            root.logCurrentProbeState()
            return
        }

        root.logLines("[InkDebug] Source " + definition.title, root.numberedSourceLines(definition.source))

        try {
            root.activeProbe = Qt.createQmlObject(definition.source, probeHost, definition.title + "Probe.qml")
            root.activeProbeOwned = true
            root.creationStatus = qsTr("Loaded %1").arg(definition.title)
            root.refreshInspection()
            console.log("[InkDebug] Loaded", definition.title, inspector.summary(root.activeProbe))
            root.logCurrentProbeState()
        } catch (error) {
            root.creationStatus = qsTr("Failed to load %1").arg(definition.title)
            root.creationError = String(error)
            console.log("[InkDebug] Failed", definition.title, root.creationError)
            root.logCurrentProbeState()
        }
    }

    component ControlButton : Rectangle {
        id: control

        required property string label
        signal tapped()

        radius: 18
        color: "white"
        border.color: "black"
        border.width: 2

        implicitWidth: 128
        implicitHeight: 68

        Text {
            anchors.centerIn: parent
            text: control.label
            color: "black"
            font.pixelSize: 26
        }

        TapHandler {
            onTapped: control.tapped()
        }
    }

    QmlObjectInspector {
        id: inspector
    }

    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
    }

    Rectangle {
        id: controlBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.controlBarHeight
        color: "white"
        border.color: "black"
        border.width: 2

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            ControlButton {
                label: qsTr("Back")
                onTapped: root.requestClose()
            }

            ControlButton {
                label: qsTr("Reload")
                onTapped: root.reloadProbe()
            }
        }

        Column {
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                text: root.selectedProbe() ? root.selectedProbe().title : ""
                color: "black"
                font.pixelSize: 34
                horizontalAlignment: Text.AlignRight
            }

            Text {
                text: root.selectedProbe() ? root.selectedProbe().detail : ""
                color: "black"
                font.pixelSize: 22
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    Rectangle {
        id: probeListPanel
        anchors.top: controlBar.bottom
        anchors.left: parent.left
        anchors.bottom: inspectorPanel.top
        width: root.probeListWidth
        color: "white"
        border.color: "black"
        border.width: 2

        Flickable {
            anchors.fill: parent
            anchors.margins: 14
            contentWidth: width
            contentHeight: probeListColumn.implicitHeight
            clip: true

            Column {
                id: probeListColumn
                width: parent.width
                spacing: 12

                Repeater {
                    model: root.visibleProbeIndexes().length

                    delegate: Rectangle {
                        readonly property int probeIndexValue: root.visibleProbeIndexAt(index)
                        readonly property bool selected: probeIndexValue === root.probeIndex

                        radius: 14
                        color: selected ? "#dfd9c8" : "white"
                        border.color: "black"
                        border.width: 2
                        width: probeListColumn.width
                        implicitHeight: titleText.implicitHeight + (detailText.visible ? detailText.implicitHeight + 20 : 28)

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 6

                            Text {
                                id: titleText
                                width: parent.width
                                text: probeIndexValue >= 0 ? root.probeDefinitions[probeIndexValue].title : ""
                                color: "black"
                                font.pixelSize: 24
                                wrapMode: Text.Wrap
                            }

                            Text {
                                id: detailText
                                width: parent.width
                                visible: parent.parent.selected
                                text: probeIndexValue >= 0 ? root.probeDefinitions[probeIndexValue].detail : ""
                                color: "black"
                                font.pixelSize: 18
                                wrapMode: Text.Wrap
                            }
                        }

                        TapHandler {
                            onTapped: {
                                if (parent.probeIndexValue >= 0) {
                                    root.selectProbe(parent.probeIndexValue)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: probeHost
        anchors.top: controlBar.bottom
        anchors.left: probeListPanel.right
        anchors.right: parent.right
        anchors.bottom: inspectorPanel.top
        clip: true

        Text {
            anchors.centerIn: parent
            visible: !root.activeProbe
            text: root.creationStatus
            color: "black"
            font.pixelSize: 34
        }
    }

    Rectangle {
        id: inspectorPanel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.inspectorHeight
        color: "white"
        border.color: "black"
        border.width: 2

        Flickable {
            anchors.fill: parent
            anchors.margins: 20
            contentWidth: width
            contentHeight: inspectionColumn.implicitHeight
            clip: true

            Column {
                id: inspectionColumn
                width: parent.width
                spacing: 14

                Text {
                    width: parent.width
                    visible: root.typeLookupText.length > 0
                    text: root.typeLookupText
                    color: "black"
                    font.pixelSize: 20
                    wrapMode: Text.WrapAnywhere
                }

                Text {
                    width: parent.width
                    visible: root.typePropertiesText.length > 0
                    text: root.typePropertiesText
                    color: "black"
                    font.pixelSize: 20
                    wrapMode: Text.WrapAnywhere
                }

                Text {
                    width: parent.width
                    text: root.creationStatus
                    color: "black"
                    font.pixelSize: 28
                    wrapMode: Text.Wrap
                }

                Text {
                    width: parent.width
                    visible: root.creationError.length > 0
                    text: root.creationError
                    color: "black"
                    font.pixelSize: 22
                    wrapMode: Text.WrapAnywhere
                }

                Text {
                    width: parent.width
                    visible: root.inspectionText.length > 0
                    text: root.inspectionText
                    color: "black"
                    font.pixelSize: 20
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            root.ensureVisibleProbeSelected()
            root.reloadProbe()
        } else {
            root.destroyProbe()
        }
    }

    Component.onCompleted: {
        if (visible) {
            root.ensureVisibleProbeSelected()
            root.reloadProbe()
        }
    }
}
