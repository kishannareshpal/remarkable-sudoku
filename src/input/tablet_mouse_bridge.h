#pragma once

#include <QObject>
#include <QPointF>

class QWindow;

class TabletMouseBridge : public QObject
{
    Q_OBJECT

public:
    explicit TabletMouseBridge(QObject *parent = nullptr);

    void setTargetWindow(QWindow *window);

    bool eventFilter(QObject *watched, QEvent *event) override;

signals:
    void penPressed(const QPointF &scenePosition);
    void penMoved(const QPointF &scenePosition);
    void penReleased(const QPointF &scenePosition);

private:
    QWindow *targetWindow_ = nullptr;
};
