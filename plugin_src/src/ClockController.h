#pragma once
#include <QObject>
#include <QTime>

class ClockController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString currentTime READ currentTime NOTIFY timeChanged)
public:
    QString currentTime() { return QTime::currentTime().toString("hh:mm:ss"); }
signals:
    void timeChanged();
};
