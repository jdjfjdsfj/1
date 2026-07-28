#pragma once

#include <QObject>
#include <QProcess>
#include <QString>

class ShellController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString outputText READ outputText NOTIFY outputTextChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(QString lastCommand READ lastCommand NOTIFY lastCommandChanged)

public:
    static ShellController* instance();
    ~ShellController() override;

    QString outputText() const { return m_outputText; }
    bool running() const { return m_running; }
    QString lastCommand() const { return m_lastCommand; }

    Q_INVOKABLE void startShell();
    Q_INVOKABLE void sendCommand(const QString& command);
    Q_INVOKABLE void clearOutput();
    Q_INVOKABLE void restartShell();
    Q_INVOKABLE void stopShell();

signals:
    void outputTextChanged();
    void runningChanged();
    void lastCommandChanged();

private:
    explicit ShellController(QObject* parent = nullptr);

    void createProcess();
    void appendOutput(const QString& text);
    void setRunning(bool running);
    void setLastCommand(const QString& command);

    QProcess* m_process = nullptr;
    QString m_outputText;
    bool m_running = false;
    QString m_lastCommand;
};
