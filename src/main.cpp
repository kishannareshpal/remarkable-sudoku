#include "input/tablet_mouse_bridge.h"

#include <QCoreApplication>
#include <QFile>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>

namespace
{
void enableTabletPlugin()
{
    if (!QFile::exists(QStringLiteral("/dev/input/event1"))) {
        return;
    }

    const QByteArray tabletPluginSpec = "evdevtablet:/dev/input/event1";
    QByteArray genericPlugins = qgetenv("QT_QPA_GENERIC_PLUGINS");
    if (genericPlugins.contains("evdevtablet")) {
        return;
    }

    if (!genericPlugins.isEmpty()) {
        genericPlugins.append(',');
    }

    genericPlugins.append(tabletPluginSpec);
    qputenv("QT_QPA_GENERIC_PLUGINS", genericPlugins);
}
}

int main(int argc, char *argv[])
{
    enableTabletPlugin();

    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    TabletMouseBridge tabletMouseBridge;
    engine.rootContext()->setContextProperty("tabletInputBridge", &tabletMouseBridge);
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("RemarkableSudoku", "Main");

    for (QObject *rootObject : engine.rootObjects()) {
        if (auto *window = qobject_cast<QQuickWindow *>(rootObject)) {
            tabletMouseBridge.setTargetWindow(window);
            break;
        }
    }
    app.installEventFilter(&tabletMouseBridge);

    return app.exec();
}
