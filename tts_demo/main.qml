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

    // ===== 输入文本 =====
    property string inputText: "Hello world"

    // ===== 键盘输入相关 =====
    property string activeInputField: ""

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
            text: "TTS 测试"
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

        Column {
            id: contentColumn
            width: parent.width
            spacing: 4

            // ---- 输入框 ----
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
                    font.family: "Microsoft YaHei"
                    font.pixelSize: 12
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

            // ---- 测试按钮网格 ----
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 4
                rowSpacing: 4

                Repeater {
                    model: [
                        { text: "🔊 英文", color: "#1a237e", border: "#3949ab", action: "speakEnglish" },
                        { text: "🔊 中文", color: "#1b5e20", border: "#388e3c", action: "speakChinese" },
                        { text: "🔊 speak(en)", color: "#4a148c", border: "#7b1fa2", action: "speakEn" },
                        { text: "🔊 speak(zh)", color: "#bf360c", border: "#e64a19", action: "speakZh" },
                        { text: "🔊 音标", color: "#3e2723", border: "#6d4c41", action: "phonetic" },
                        { text: "🔊 清空", color: "#37474f", border: "#78909c", action: "clear" }
                    ]

                    delegate: Rectangle {
                        width: (parent.width - 4) / 2
                        height: 28
                        radius: 4
                        color: modelData.color
                        border.color: modelData.border
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData.text
                            color: "white"
                            font.family: "Microsoft YaHei"
                            font.pixelSize: 11
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (modelData.action === "speakEnglish")
                                    tts.speakEnglish(inputText)
                                else if (modelData.action === "speakChinese")
                                    tts.speakChinese(inputText)
                                else if (modelData.action === "speakEn")
                                    tts.speak(inputText, "en")
                                else if (modelData.action === "speakZh")
                                    tts.speak(inputText, "zh-CHS")
                                else if (modelData.action === "phonetic")
                                    tts.speak("pronunciation", "en", "/prəˌnʌnsiˈeɪʃən/")
                                else if (modelData.action === "clear")
                                    statusText.text = "⏸ 等待操作..."
                            }
                        }
                    }
                }
            }

            // ---- 状态指示器 ----
            Rectangle {
                width: parent.width
                height: 22
                color: "#263238"
                radius: 4
                border.color: "#546e7a"
                border.width: 1

                Connections {
                    target: tts
                    onSpeakFinished: statusText.text = "✅ 播放结束"
                }

                Text {
                    id: statusText
                    anchors.centerIn: parent
                    text: "⏸ 等待操作..."
                    color: "#80cbc4"
                    font.family: "Microsoft YaHei"
                    font.pixelSize: 10
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: statusText.text = "⏸ 等待操作..."
                }
            }
        }
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
        objectName: "from_TtsTestPlugin"
    }
}