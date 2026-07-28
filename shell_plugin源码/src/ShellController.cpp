#include "ShellController.h"

#include <QDir>
#include <QFileInfo>
#include <QProcessEnvironment>
#include <QRegularExpression>

ShellController* ShellController::instance() {
    static ShellController controller;
    return &controller;
}

ShellController::ShellController(QObject* parent) : QObject(parent) {}

ShellController::~ShellController() {
    stopShell();
}

void ShellController::createProcess() {
    if (m_process) return;

    m_process = new QProcess(this);
    m_process->setProcessChannelMode(QProcess::MergedChannels);

    connect(m_process, &QProcess::started, this, [this]() {
        setRunning(true);
    });

    connect(m_process, &QProcess::readyRead, this, [this]() {
        QString text = QString::fromLocal8Bit(m_process->readAll());
        text.remove(QRegularExpression(QStringLiteral("^bash: cannot set terminal process group.*\\n"), QRegularExpression::MultilineOption));
        text.remove(QStringLiteral("bash: no job control in this shell\n"));
        appendOutput(text);
    });

    connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this,
            [this](int exitCode, QProcess::ExitStatus exitStatus) {
                if (m_process) {
                    const QByteArray rest = m_process->readAll();
                    if (!rest.isEmpty()) appendOutput(QString::fromLocal8Bit(rest));
                }
                setRunning(false);
                appendOutput(QString("[shell exited: %1%2]\n")
                                 .arg(exitStatus == QProcess::CrashExit ? "crash, code " : "code ")
                                 .arg(exitCode));
            });

    connect(m_process, QOverload<QProcess::ProcessError>::of(&QProcess::errorOccurred), this,
            [this](QProcess::ProcessError) {
                appendOutput(QString("[shell error: %1]\n").arg(m_process ? m_process->errorString() : QStringLiteral("unknown")));
            });
}

void ShellController::startShell() {
    createProcess();
    if (m_process->state() != QProcess::NotRunning) return;

    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    if (!env.contains("TERM")) env.insert("TERM", "xterm");
    if (!env.contains("HOME")) env.insert("HOME", "/userdisk");
    env.insert("PS1", "\\u@\\h $(pwd) # ");
    m_process->setProcessEnvironment(env);

    if (QDir("/userdisk").exists()) {
        m_process->setWorkingDirectory("/userdisk");
    }

    QString shellPath = QStringLiteral("/bin/bash");
    if (!QFileInfo::exists(shellPath)) shellPath = QStringLiteral("/usr/bin/bash");
    if (!QFileInfo::exists(shellPath)) {
        appendOutput("[bash not found]\n");
        return;
    }

    m_process->start(shellPath, QStringList() << "--noprofile" << "--norc" << "-i");
}

void ShellController::sendCommand(const QString& command) {
    if (command.isEmpty()) return;
    startShell();
    if (!m_process || m_process->state() == QProcess::NotRunning) {
        appendOutput("[shell is not running]\n");
        return;
    }

    setLastCommand(command);
    QString shellCommand = command;
    shellCommand.replace(QRegularExpression(QStringLiteral("(\\bexec\\s+(?:/bin/)?bash)(?=\\s*(?:[\\\"';&|)]|$))")), QStringLiteral("\\1 -i"));
    m_process->write(shellCommand.toLocal8Bit());
    m_process->write("\n");
}

void ShellController::clearOutput() {
    if (m_outputText.isEmpty()) return;
    m_outputText.clear();
    emit outputTextChanged();
}

void ShellController::restartShell() {
    stopShell();
    appendOutput("[shell restarting]\n");
    startShell();
}

void ShellController::stopShell() {
    if (!m_process) return;

    if (m_process->state() != QProcess::NotRunning) {
        m_process->write("exit\n");
        m_process->closeWriteChannel();
        if (!m_process->waitForFinished(1000)) {
            m_process->terminate();
            if (!m_process->waitForFinished(1000)) {
                m_process->kill();
                m_process->waitForFinished(1000);
            }
        }
    }

    m_process->deleteLater();
    m_process = nullptr;
    setRunning(false);
}

void ShellController::appendOutput(const QString& text) {
    if (text.isEmpty()) return;
    m_outputText += text;
    constexpr int maxLength = 30000;
    if (m_outputText.length() > maxLength) {
        m_outputText = m_outputText.right(maxLength);
    }
    emit outputTextChanged();
}

void ShellController::setRunning(bool running) {
    if (m_running == running) return;
    m_running = running;
    emit runningChanged();
}

void ShellController::setLastCommand(const QString& command) {
    if (m_lastCommand == command) return;
    m_lastCommand = command;
    emit lastCommandChanged();
}
