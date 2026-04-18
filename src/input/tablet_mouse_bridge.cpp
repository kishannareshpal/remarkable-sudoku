#include "input/tablet_mouse_bridge.h"

#include <QDebug>
#include <QEvent>
#include <QPointingDevice>
#include <QTabletEvent>
#include <QWindow>

TabletMouseBridge::TabletMouseBridge(QObject *parent)
    : QObject(parent)
{
}

void TabletMouseBridge::setTargetWindow(QWindow *window)
{
    targetWindow_ = window;
}

bool TabletMouseBridge::eventFilter(QObject *watched, QEvent *event)
{
    if (targetWindow_ == nullptr) {
        return QObject::eventFilter(watched, event);
    }

    if (event->type() != QEvent::TabletPress
        && event->type() != QEvent::TabletMove
        && event->type() != QEvent::TabletRelease) {
        return QObject::eventFilter(watched, event);
    }

    auto *tabletEvent = static_cast<QTabletEvent *>(event);
    const auto pointerType = tabletEvent->pointingDevice()->pointerType();
    if (pointerType != QPointingDevice::PointerType::Pen
        && pointerType != QPointingDevice::PointerType::Eraser) {
        return QObject::eventFilter(watched, event);
    }

    const qreal rawX = tabletEvent->position().x();
    const qreal rawY = tabletEvent->position().y();
    const qreal windowWidth = targetWindow_->width();
    const qreal windowHeight = targetWindow_->height();
    const QPointF transformedPosition(
        (rawY / windowHeight) * windowWidth,
        (1.0 - (rawX / windowWidth)) * windowHeight);

    if (qEnvironmentVariableIsSet("RM_INPUT_DEBUG")) {
        qInfo().nospace()
            << "tablet event type=" << event->type()
            << " target=" << watched->metaObject()->className()
            << " pos=" << tabletEvent->position()
            << " transformed=" << transformedPosition
            << " global=" << tabletEvent->globalPosition()
            << " pressure=" << tabletEvent->pressure();
    }

    switch (event->type()) {
    case QEvent::TabletPress:
        if (qEnvironmentVariableIsSet("RM_INPUT_DEBUG")) {
            qInfo().nospace()
                << "emitting penPressed pos=" << transformedPosition;
        }

        emit penPressed(transformedPosition);
        break;
    case QEvent::TabletMove:
        if (qEnvironmentVariableIsSet("RM_INPUT_DEBUG")) {
            qInfo().nospace()
                << "emitting penMoved pos=" << transformedPosition;
        }

        emit penMoved(transformedPosition);
        break;
    case QEvent::TabletRelease:
        if (qEnvironmentVariableIsSet("RM_INPUT_DEBUG")) {
            qInfo().nospace()
                << "emitting penReleased pos=" << transformedPosition;
        }

        emit penReleased(transformedPosition);
        break;
    default:
        return QObject::eventFilter(watched, event);
    }

    event->accept();
    return true;
}
