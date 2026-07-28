import QtQuick 2.12
import QtQuick.Layouts 1.12
import "qrc:/qml/commons"

Rectangle {
    id: root
    width: 320
    height: 170
    color: "#0B1120"
    radius: 8
    clip: true

    signal backButtonClicked()

    property var controller: (typeof shellPluginController !== "undefined") ? shellPluginController : null
    readonly property string fontFamily: (typeof qmlGlobal !== "undefined" && qmlGlobal.fontFamilyZhCn) ? qmlGlobal.fontFamilyZhCn : "Microsoft YaHei"
    readonly property color panel: "#101827"
    readonly property color panelRaised: "#172235"
    readonly property color borderColor: "#273551"
    readonly property color textPrimary: "#F3F7FF"
    readonly property color textSecondary: "#90A0C1"
    readonly property color accent: "#6F8BFF"

    function setInputShowing(showing) {
        if (typeof qmlGlobal !== "undefined") qmlGlobal.inputPageShowing = showing
    }

    function showKeyboard() {
        var component = qmlCreateComponent("YInputPage")
        if (Component.Ready === component.status) {
            var incubator = component.incubateObject(id_page_pop_helper.containerItem)
            function initPage(keyboardPage) {
                keyboardPage.backButtonClicked.connect(function() {
                    setInputShowing(false)
                    keyboardPage.todoDestroy()
                })
                keyboardPage.inputFinished.connect(function(content) {
                    var text = content || ""
                    if (controller && text.length > 0) controller.sendCommand(text)
                    setInputShowing(false)
                    keyboardPage.todoDestroy()
                })
                keyboardPage.placeHolderText = "请输入 shell 命令"
                keyboardPage.enterText(controller ? (controller.lastCommand || "") : "")
                keyboardPage.show()
                setInputShowing(true)
            }
            if (incubator.status !== Component.Ready)
                incubator.onStatusChanged = function(status) { if (status === Component.Ready) initPage(incubator.object) }
            else initPage(incubator.object)
        }
    }

    Component.onCompleted: {
        if (controller) controller.startShell()
    }

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        Rectangle {
            width: parent.width
            height: parent.height - 34
            radius: 6
            color: root.panel
            border.color: root.borderColor
            border.width: 1
            clip: true

            Flickable {
                id: outputFlick
                anchors.fill: parent
                anchors.margins: 6
                contentWidth: width
                contentHeight: outputText.height
                clip: true

                onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

                Text {
                    id: outputText
                    width: outputFlick.width
                    text: controller ? controller.outputText : "shellPluginController 未加载"
                    color: root.textPrimary
                    font.pixelSize: 11
                    font.family: "monospace"
                    wrapMode: Text.WrapAnywhere
                }
            }
        }

        Row {
            width: parent.width
            height: 28
            spacing: 6

            Rectangle {
                width: 86
                height: 28
                radius: 7
                color: inputMouse.pressed ? "#88A0FF" : root.accent
                Text { anchors.centerIn: parent; text: "输入"; color: "white"; font.pixelSize: 11; font.family: root.fontFamily }
                MouseArea {
                    id: inputMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: showKeyboard()
                }
            }

            Rectangle {
                width: 58
                height: 24
                radius: 6
                color: restartMouse.pressed ? "#21314C" : root.panelRaised
                border.color: root.borderColor
                Text { anchors.centerIn: parent; text: "重启"; color: root.textPrimary; font.pixelSize: 10; font.family: root.fontFamily }
                MouseArea { id: restartMouse; anchors.fill: parent; onClicked: if (controller) controller.restartShell() }
            }

            Rectangle {
                width: 58
                height: 24
                radius: 6
                color: clearMouse.pressed ? "#21314C" : root.panelRaised
                border.color: root.borderColor
                Text { anchors.centerIn: parent; text: "清空"; color: root.textPrimary; font.pixelSize: 10; font.family: root.fontFamily }
                MouseArea { id: clearMouse; anchors.fill: parent; onClicked: if (controller) controller.clearOutput() }
            }

            Rectangle {
                width: 58
                height: 24
                radius: 6
                color: closeMouse.pressed ? "#21314C" : root.panelRaised
                border.color: root.borderColor
                Text { anchors.centerIn: parent; text: "关闭"; color: root.textPrimary; font.pixelSize: 10; font.family: root.fontFamily }
                MouseArea { id: closeMouse; anchors.fill: parent; onClicked: root.backButtonClicked() }
            }
        }
    }

    YPagePopHelper {
        id: id_page_pop_helper
        z: 1000
        anchors.fill: parent
        isShowing: (typeof qmlGlobal !== "undefined") ? qmlGlobal.inputPageShowing : false
        objectName: "from_shell_plugin.qml"
    }
}
