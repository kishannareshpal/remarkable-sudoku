#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>

namespace
{
void expect(bool condition, const std::string &message)
{
    if (!condition) {
        std::cerr << "FAILED: " << message << '\n';
        std::exit(1);
    }
}

std::string readFile(const std::filesystem::path &path)
{
    std::ifstream input(path);
    expect(input.is_open(), "expected to open " + path.string());

    std::ostringstream buffer;
    buffer << input.rdbuf();
    return buffer.str();
}
}

int main()
{
    const std::filesystem::path sourceRoot = REMARKABLE_SUDOKU_SOURCE_DIR;
    const std::string sudokuAppView = readFile(sourceRoot / "src/qml/SudokuAppView.qml");
    const std::string sudokuMenuView = readFile(sourceRoot / "src/qml/SudokuMenuView.qml");
    const std::string sudokuView = readFile(sourceRoot / "src/qml/SudokuView.qml");
    const std::string appsDrawer = readFile(sourceRoot / "xovi/qml/AppsDrawer.qml");
    const std::string inkDebugAppView = readFile(sourceRoot / "xovi/qml/InkDebugAppView.qml");
    const std::string installXoviLauncher = readFile(sourceRoot / "scripts/install-xovi-launcher.sh");
    const std::string mirrorScript = readFile(sourceRoot / "scripts/mirror-rm2.py");
    const std::string provisionSudokuDocument = readFile(sourceRoot / "scripts/provision-sudoku-document.sh");
    const std::string readme = readFile(sourceRoot / "README.md");
    const std::string runScript = readFile(sourceRoot / "run");
    const std::string sudokuPageHost = readFile(sourceRoot / "xovi/qml/SudokuPageHost.qml");
    const std::string sidebarPatch = readFile(sourceRoot / "xovi/remarkable-sudoku-sidebar/sidebar.qmd");
    const std::string inspectorHeader = readFile(sourceRoot / "src/debug/qml_object_inspector.h");
    const std::string touchInjector = readFile(sourceRoot / "src/tools/remarkable_touch_injector.cpp");

    expect(sudokuAppView.find("sudokuView.handleScenePress(scenePosition)") != std::string::npos,
           "SudokuAppView should forward scene presses into SudokuView");
    expect(sudokuAppView.find("signal requestInkDebug()") != std::string::npos,
           "SudokuAppView should expose a requestInkDebug signal for the dedicated host");
    expect(sudokuAppView.find("onRequestInkDebug: root.requestInkDebug()") != std::string::npos,
           "SudokuAppView should forward SudokuMenuView debug requests to the host");
    expect(sudokuAppView.find("property bool documentOverlayMode: false") != std::string::npos,
           "SudokuAppView should expose a documentOverlayMode switch for live DocumentView hosting");
    expect(sudokuAppView.find("property bool boardInteractionEnabled: true") != std::string::npos,
           "SudokuAppView should expose a boardInteractionEnabled switch for live ink mode");
    expect(sudokuAppView.find("documentOverlayMode: root.documentOverlayMode") != std::string::npos,
           "SudokuAppView should forward documentOverlayMode into SudokuView");
    expect(sudokuAppView.find("boardInteractionEnabled: root.boardInteractionEnabled") != std::string::npos,
           "SudokuAppView should forward boardInteractionEnabled into SudokuView");
    expect(sudokuAppView.find("onBoardInteractionEnabledChanged: root.boardInteractionEnabled = boardInteractionEnabled") != std::string::npos,
           "SudokuAppView should mirror boardInteractionEnabled changes back from SudokuView");
    expect(sudokuMenuView.find("signal requestInkDebug()") != std::string::npos,
           "SudokuMenuView should expose a requestInkDebug signal");
    expect(sudokuMenuView.find("text: \"Ink Debug\"") != std::string::npos,
           "SudokuMenuView should expose an Ink Debug action in the menu");
    expect(sudokuView.find("function handleScenePress(scenePosition)") != std::string::npos,
           "SudokuView should define handleScenePress for pen-driven button presses");
    expect(sudokuView.find("property bool documentOverlayMode: false") != std::string::npos,
           "SudokuView should support a documentOverlayMode for stock-scene hosting");
    expect(sudokuView.find("property bool boardInteractionEnabled: true") != std::string::npos,
           "SudokuView should expose a boardInteractionEnabled toggle");
    expect(sudokuView.find("readonly property bool documentInkMode: root.documentOverlayMode && !root.boardInteractionEnabled") != std::string::npos,
           "SudokuView should expose a documentInkMode for pen pass-through");
    expect(sudokuView.find("readonly property bool fullUiVisible: !root.documentInkMode") != std::string::npos,
           "SudokuView should collapse the full Sudoku chrome while the document is in ink mode");
    expect(sudokuView.find("readonly property int uiInputDevices: root.documentOverlayMode") != std::string::npos,
           "SudokuView should drop stylus capture when hosted above a live DocumentView");
    expect(sudokuView.find("text: root.boardInteractionEnabled ? \"Board\" : \"Ink\"") != std::string::npos,
           "SudokuView should show a live board-vs-ink mode toggle");
    expect(sudokuView.find("id: compactInteractionModeButton") != std::string::npos,
           "SudokuView should keep a compact button available while the full chrome is hidden");
    expect(sudokuView.find("id: pauseButton") != std::string::npos,
           "SudokuView should keep a dedicated pause button in the header");
    expect(sudokuView.find("visible: !game.solved") != std::string::npos,
           "SudokuView should hide gameplay-only controls when the puzzle is solved");
    expect(appsDrawer.find("title: qsTr(\"Ink Debug\")") != std::string::npos,
           "AppsDrawer should expose an Ink Debug entry");
    expect(appsDrawer.find("action: \"ink-debug\"") != std::string::npos,
           "AppsDrawer should route the Ink Debug entry with a stable action id");
    expect(appsDrawer.find("InkDebugAppView") != std::string::npos,
           "AppsDrawer should embed InkDebugAppView alongside Sudoku");
    expect(inkDebugAppView.find("Qt.createQmlObject") != std::string::npos,
           "InkDebugAppView should build pen-input probes dynamically");
    expect(inkDebugAppView.find("QmlObjectInspector") != std::string::npos,
           "InkDebugAppView should inspect live Qt objects for pen-input discovery");
    expect(installXoviLauncher.find("RM2_SUDOKU_DOCUMENT_ID") != std::string::npos,
           "install-xovi-launcher should configure a fixed backing notebook id");
    expect(installXoviLauncher.find("provision-sudoku-document.sh") != std::string::npos,
           "install-xovi-launcher should provision the backing Sudoku notebook before restart");
    expect(mirrorScript.find("class MirrorController") != std::string::npos,
           "mirror-rm2 should expose a dedicated host mirror controller");
    expect(mirrorScript.find("GOMARKABLESTREAM_RELEASE_API") != std::string::npos,
           "mirror-rm2 should resolve the latest goMarkableStream release from GitHub");
    expect(mirrorScript.find("gomarkablestream-RM2-lite") != std::string::npos,
           "mirror-rm2 should target the RM2 lite goMarkableStream asset");
    expect(mirrorScript.find("QWebEngineView") != std::string::npos,
           "mirror-rm2 should embed the goMarkableStream browser client in a local Qt web view");
    expect(mirrorScript.find("window.codexRestartStream") != std::string::npos,
           "mirror-rm2 should refresh the goMarkableStream worker when mirrored touch input starts");
    expect(provisionSudokuDocument.find("RM2_XOCHITL_DATA_DIR") != std::string::npos,
           "provision-sudoku-document should target xochitl storage");
    expect(provisionSudokuDocument.find("reMarkable .lines file, version=5") != std::string::npos,
           "provision-sudoku-document should seed a valid blank lines file");
    expect(provisionSudokuDocument.find("test -s '${remote_xochitl_dir}/${sudoku_document_id}/${sudoku_page_id}.rm'") != std::string::npos,
           "provision-sudoku-document should only reuse notebooks with a non-empty page file");
    expect(provisionSudokuDocument.find(".metadata") != std::string::npos,
           "provision-sudoku-document should create notebook metadata");
    expect(provisionSudokuDocument.find(".content") != std::string::npos,
           "provision-sudoku-document should create notebook content");
    expect(sudokuPageHost.find("SudokuAppView") != std::string::npos,
           "SudokuPageHost should embed SudokuAppView as the dedicated full-screen host");
    expect(sudokuPageHost.find("InkDebugAppView") != std::string::npos,
           "SudokuPageHost should keep InkDebugAppView reachable from the dedicated host");
    expect(sudokuPageHost.find("function showSudoku()") != std::string::npos,
           "SudokuPageHost should expose a stable entry point for the Sudoku page");
    expect(sudokuPageHost.find("onRequestInkDebug: root.showInkDebug()") != std::string::npos,
           "SudokuPageHost should switch panels when SudokuAppView requests Ink Debug");
    expect(sudokuPageHost.find("function tryActivateLiveDocumentSudoku(expectedDocumentId)") != std::string::npos,
           "SudokuPageHost should attempt to activate Sudoku inside a live DocumentView before falling back");
    expect(sudokuPageHost.find("applicationObjectWithProperty(") != std::string::npos
            && sudokuPageHost.find("\"remarkableSudokuActive\"") != std::string::npos,
           "SudokuPageHost should find live overlays by the injected DocumentView property");
    expect(sudokuPageHost.find("if (targetDocumentId && liveDocumentId && liveDocumentId !== targetDocumentId)") != std::string::npos,
           "SudokuPageHost should only reject a live DocumentView when its document id is known and wrong");
    expect(sudokuPageHost.find("inspector.writeProperty(") != std::string::npos,
           "SudokuPageHost should use QmlObjectInspector writeProperty to activate the live DocumentView");
    expect(inspectorHeader.find("Q_INVOKABLE bool writeProperty(") != std::string::npos,
           "QmlObjectInspector should expose a writeProperty helper for live-object integration");
    expect(inspectorHeader.find("Q_INVOKABLE QObject *applicationObjectWithProperty(") != std::string::npos,
           "QmlObjectInspector should expose property-based application object lookup");
    expect(touchInjector.find("/dev/uinput") != std::string::npos,
           "remarkable_touch_injector should create a virtual touch device");
    expect(touchInjector.find("ABS_MT_POSITION_X") != std::string::npos
            && touchInjector.find("ABS_MT_TRACKING_ID") != std::string::npos,
           "remarkable_touch_injector should emit multitouch events");
    expect(runScript.find("./run mirror [local-injector-path]") != std::string::npos,
           "run should document the mirror command");
    expect(runScript.find("mirror)") != std::string::npos,
           "run should dispatch the mirror command");
    expect(readme.find("./run mirror") != std::string::npos,
           "README should document the mirror workflow");
    expect(sidebarPatch.find("qrc:/remarkable-sudoku/qml/SudokuPageHost.qml") != std::string::npos,
           "Sidebar patch should load the dedicated SudokuPageHost instead of the floating drawer");
    expect(sidebarPatch.find("property string remarkableSudokuDocumentId: \"__SUDOKU_DOCUMENT_ID__\"") != std::string::npos,
           "Navigator patch should carry the fixed backing notebook id");
    expect(sidebarPatch.find("function openRemarkableSudokuDocument()") != std::string::npos,
           "Navigator patch should expose a guarded document opener");
    expect(sidebarPatch.find("documentView.item.openDocument(") != std::string::npos,
           "Navigator patch should try the live documentView item opener first");
    expect(sidebarPatch.find("function activateRemarkableSudokuDocument()") != std::string::npos,
           "Navigator patch should expose a reusable live-document activation helper");
    expect(sidebarPatch.find("id: remarkableSudokuActivationProbe") != std::string::npos,
           "Navigator patch should poll until the live document view is ready");
    expect(sidebarPatch.find("function onDocumentLoaded()") != std::string::npos,
           "Navigator patch should react when the real Sudoku notebook finishes loading");
    expect(sidebarPatch.find("AFFECT /qml/device/view/documentview/DocumentView.qml") != std::string::npos,
           "Sidebar patch should extend DocumentView for live Sudoku activation");
    expect(sidebarPatch.find("property string remarkableSudokuDocumentId: \"__SUDOKU_DOCUMENT_ID__\"") != std::string::npos,
           "DocumentView patch should know the fixed Sudoku notebook id");
    expect(sidebarPatch.find("readonly property bool remarkableSudokuDocumentMatches: !!root.document") != std::string::npos,
           "DocumentView patch should auto-detect when the Sudoku notebook is open");
    expect(sidebarPatch.find("property bool remarkableSudokuActive: root.remarkableSudokuDocumentMatches") != std::string::npos,
           "DocumentView patch should add an activation flag for the live Sudoku overlay");
    expect(sidebarPatch.find("property bool remarkableSudokuBoardInteractionEnabled: true") != std::string::npos,
           "DocumentView patch should track whether the live Sudoku overlay is visible above the page");
    expect(sidebarPatch.find("property string remarkableSudokuPanel: \"sudoku\"") != std::string::npos,
           "DocumentView patch should keep the active live panel state");
    expect(sidebarPatch.find("source: \"qrc:/remarkable-sudoku/qml/SudokuAppView.qml\"") != std::string::npos,
           "DocumentView patch should load the shared SudokuAppView from the resource bundle");
    expect(sidebarPatch.find("active: root.remarkableSudokuDocumentMatches") != std::string::npos,
           "DocumentView patch should keep the live Sudoku loader mounted for the backing notebook");
    expect(sidebarPatch.find("visible: active && root.remarkableSudokuBoardInteractionEnabled") != std::string::npos,
           "DocumentView patch should hide the full live Sudoku overlay while the document is in ink mode");
    expect(sidebarPatch.find("item.documentOverlayMode = true;") != std::string::npos,
           "DocumentView patch should enable overlay mode on the live Sudoku page");
    expect(sidebarPatch.find("item.boardInteractionEnabled = root.remarkableSudokuBoardInteractionEnabled;") != std::string::npos,
           "DocumentView patch should seed the live Sudoku loader with the current board interaction mode");
    expect(sidebarPatch.find("function onBoardInteractionEnabledChanged()") != std::string::npos,
           "DocumentView patch should observe live board mode changes from SudokuAppView");
    expect(sidebarPatch.find("id: remarkableSudokuDocumentModeButton") != std::string::npos,
           "DocumentView patch should expose a compact board button while the main overlay is hidden");
    expect(sidebarPatch.find("source: \"qrc:/remarkable-sudoku/qml/InkDebugAppView.qml\"") != std::string::npos,
           "DocumentView patch should keep InkDebugAppView reachable from the live DocumentView overlay");
    expect(sidebarPatch.find("property alias sudokuPageView: _sudokuPageView") != std::string::npos,
           "Sidebar patch should name the injected loader after the dedicated Sudoku page host");
    expect(sidebarPatch.find("title: qsTr(\"Sudoku\")") != std::string::npos,
           "Sidebar patch should label the entry as Sudoku");
    expect(sidebarPatch.find("function hasRemarkableSudokuDocumentOpen()") != std::string::npos,
           "Navigator patch should expose a guarded document-open helper for the sidebar");
}
