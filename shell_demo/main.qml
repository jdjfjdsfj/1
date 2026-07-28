import QtQuick 2.12
import QtQuick.Controls 1.4
import QtQuick.Layouts 1.15
import QtQuick.Controls.Styles 1.4
import "qrc:/qml/commons"

Rectangle {
    id: root
    width: 320
    height: 170
    color: "#222222"

    signal backButtonClicked()

    // ===== 状态 & 输入 =====
    property string inputText: "echo Hello World"
    property string activeInputField: ""
    property string lastResult: ""

    // ===== 预设命令列表 =====
    property var presetCommands: [
        { label: "echo Hello", cmd: "echo Hello World" },
        { label: "cat /proc/cpuinfo", cmd: "cat /proc/cpuinfo" },
        { label: "uname -a", cmd: "uname -a" },
        { label: "ls /tmp", cmd: "ls /tmp" },
        { label: "pwd; id", cmd: "pwd && id" },
        { label: "sleep 3", cmd: "sleep 3 && echo done", async: true },
        { label: "错误命令", cmd: "nonexistent_command_xyz" },
        { label: "ping 127.0.0.1", cmd: "ping -c 4 127.0.0.1", async: true }
    ]

    // ========== 标题栏 ==========
    Item {
        id: titleBar
        width: parent.width
        height: 28
        anchors.top: parent.top

        Rectangle {
            id: backBtn
            width: 44
            height: 20
            radius: 4
            color: backArea.pressed ? "#555555" : "#333333"
            border.color: "#666666"
            border.width: 1
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: "返回"
                color: "white"
                font.family: "Microsoft YaHei"
                font.pixelSize: 11
                anchors.centerIn: parent
            }

            MouseArea {
                id: backArea
                anchors.fill: parent
                onClicked: root.backButtonClicked()
            }
        }

        Text {
            text: "Shell 测试"
            color: "#AAAAAA"
            font.family: "Microsoft YaHei"
            font.pixelSize: 14
            anchors.centerIn: parent
        }
    }

    // ========== 可滚动的内容区 ==========
    Flickable {
        anchors.top: titleBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 4
        contentHeight: contentColumn.height + 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentColumn
            width: parent.width
            spacing: 4

            // ---- 命令输入框 ----
            Rectangle {
                width: parent.width
                height: 28
                color: "#333333"
                radius: 4
                border.color: "#666666"
                border.width: 1

                Text {
                    id: inputDisplay
                    anchors.fill: parent
                    anchors.margins: 4
                    text: inputText
                    color: "white"
                    font.family: "monospace"
                    font.pixelSize: 11
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        activeInputField = "input"
                        requestKeyboard(inputText)
                    }
                }
            }

            // ---- 执行按钮行 ----
            Row {
                width: parent.width
                spacing: 4

                Rectangle {
                    width: (parent.width - 4) / 3
                    height: 28
                    radius: 4
                    color: "#1b5e20"
                    border.color: "#388e3c"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "▶ 同步"
                        color: "white"
                        font.family: "Microsoft YaHei"
                        font.pixelSize: 11
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: doExec()
                    }
                }

                Rectangle {
                    width: (parent.width - 4) / 3
                    height: 28
                    radius: 4
                    color: "#1a237e"
                    border.color: "#3949ab"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "▶ 异步"
                        color: "white"
                        font.family: "Microsoft YaHei"
                        font.pixelSize: 11
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: doExecAsync()
                    }
                }

                Rectangle {
                    width: (parent.width - 4) / 3
                    height: 28
                    radius: 4
                    color: "#bf360c"
                    border.color: "#e64a19"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "✕ 终止"
                        color: "white"
                        font.family: "Microsoft YaHei"
                        font.pixelSize: 11
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: doKill()
                    }
                }
            }

            // ---- 预设命令面板 ----
            Flow {
                width: parent.width
                spacing: 3

                Repeater {
                    model: presetCommands

                    delegate: Rectangle {
                        width: cmdLabel.implicitWidth + 12
                        height: 22
                        radius: 3
                        color: "#37474f"
                        border.color: "#78909c"
                        border.width: 1

                        Text {
                            id: cmdLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            color: "white"
                            font.family: "Microsoft YaHei"
                            font.pixelSize: 10
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                inputText = modelData.cmd
                                if (modelData.async)
                                    doExecAsync()
                                else
                                    doExec()
                            }
                        }
                    }
                }
            }

            // ---- 结果输出区域 ----
            Rectangle {
                width: parent.width
                height: 42
                color: "#1a1a2e"
                radius: 4
                border.color: "#4a4a6a"
                border.width: 1
                clip: true

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 3
                    contentHeight: resultText.height
                    clip: true

                    Text {
                        id: resultText
                        width: parent.width
                        text: lastResult === "" ? "⏸ 等待执行..." : lastResult
                        color: "#80cbc4"
                        font.family: "monospace"
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // ---- 底部状态栏 ----
            Rectangle {
                width: parent.width
                height: 20
                color: "#263238"
                radius: 4
                border.color: "#546e7a"
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 6

                    Text {
                        id: statusIcon
                        text: "⏸"
                        color: "#80cbc4"
                        font.pixelSize: 10
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: statusLabel
                        text: "就绪 (超时: " + shell.getTimeout() + "ms)"
                        color: "#80cbc4"
                        font.family: "Microsoft YaHei"
                        font.pixelSize: 10
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // 点击状态栏可清空输出
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        lastResult = ""
                        statusIcon.text = "⏸"
                        statusLabel.text = "已清空"
                    }
                }
            }

            // ---- 信号监听 ----
            Connections {
                target: shell

                onStarted: function(command) {
                    statusIcon.text = "▶"
                    statusLabel.text = "执行中: " + command
                }

                onFinished: function(command, exitCode) {
                    statusIcon.text = exitCode === 0 ? "✓" : "✗"
                    statusLabel.text = "完成 (exit: " + exitCode + ")"
                }

                onStdoutReady: function(data) {
                    // 追加实时输出（限制长度防止溢出）
                    if (lastResult.length > 2000)
                        lastResult = lastResult.substring(lastResult.length - 1000)
                    lastResult += data
                }

                onStderrReady: function(data) {
                    lastResult += "[stderr] " + data
                }

                onErrorOccurred: function(command, errorMessage) {
                    lastResult += "❌ 错误: " + errorMessage + "\n"
                    statusIcon.text = "✗"
                    statusLabel.text = "出错: " + errorMessage
                }
            }
        }
    }

    // ========== 核心函数 ==========

    function doExec() {
        if (inputText.trim() === "") return

        statusIcon.text = "⏳"
        statusLabel.text = "同步执行中..."
        lastResult = ""

        // exec() - 仅获取 stdout
        var output = shell.exec(inputText)
        // execWithResult() - 获取完整结果
        var full = shell.execWithResult(inputText)

        lastResult = "=== exec() stdout ===\n" + output + "\n\n"
            + "=== execWithResult() ===\n"
            + "exitCode: " + full.exitCode + "\n"
            + "timedOut: " + full.timedOut + "\n"
            + "stderr: " + full.stderr + "\n"
            + (full.error !== undefined ? "error: " + full.error + "\n" : "")

        statusIcon.text = full.exitCode === 0 ? "✓" : "✗"
        statusLabel.text = "完成 (exit: " + full.exitCode + ")"
    }

    function doExecAsync() {
        if (inputText.trim() === "") return

        lastResult = ""
        lastResult += "▶ 异步执行: " + inputText + "\n"

        shell.execAsync(inputText, function(result) {
            lastResult += "\n=== 回调结果 ===\n"
            lastResult += "exitCode: " + result.exitCode + "\n"
            lastResult += "timedOut: " + result.timedOut + "\n"
            if (result.stdout !== "") lastResult += "stdout: " + result.stdout + "\n"
            if (result.stderr !== "") lastResult += "stderr: " + result.stderr + "\n"
            if (result.error !== undefined) lastResult += "error: " + result.error + "\n"
        })
    }

    function doKill() {
        shell.kill()
        lastResult += "⛔ 已发送终止信号\n"
        statusIcon.text = "⛔"
        statusLabel.text = "已终止"
    }

    // ===== 键盘调用函数 =====
    function requestKeyboard(initialText) {
        var comp = qmlCreateComponent("YInputPage")
        if (comp.status === Component.Ready) {
            var incubator = comp.incubateObject(pagePopHelper.containerItem)
            if (incubator.status !== Component.Ready) {
                incubator.onStatusChanged = function(status) {
                    if (status === Component.Ready)
                        pagePopHelper.inputPageCreated(incubator.object, initialText)
                }
            } else {
                pagePopHelper.inputPageCreated(incubator.object, initialText)
            }
        }
    }

    function handleInputSubmit(text) {
        if (activeInputField === "input") {
            inputText = text
        }
        activeInputField = ""
    }

    // ===== 键盘弹出辅助组件 =====
    YPagePopHelper {
        id: pagePopHelper
        z: 99
        property var containerItem: this

        function inputPageCreated(keyboardPage, initialText) {
            keyboardPage.backButtonClicked.connect(function() {
                qmlGlobal.inputPageShowing = false
                keyboardPage.todoDestroy()
                keyboardPage = null
            })
            keyboardPage.inputFinished.connect(function(content) {
                qmlGlobal.inputPageShowing = false
                keyboardPage.todoDestroy()
                if (content) handleInputSubmit(content)
            })
            keyboardPage.enterText(initialText)
            keyboardPage.show()
            qmlGlobal.inputPageShowing = true
        }

        isShowing: qmlGlobal.inputPageShowing
        objectName: "from_ShellTestPlugin"
    }
}