import QtQuick 2.15
import "qrc:/qml/commons"

Item {
    id: settingsRoot

    StatusBar {
        id: titleBar
        anchors.top: parent.top
        statusText: "设置"
    }

    // 左下角返回按钮
    Rectangle {
        id: backButton
        width: 60
        height: 28
        radius: 4
        color: backMouse.pressed ? "#cccccc" : "#ffffff"
        border.color: "#aaaaaa"
        border.width: 1
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 8

        Text {
            anchors.centerIn: parent
            text: "返回"
            color: "#333"
            font.family: "Microsoft YaHei"
            font.pixelSize: 16
        }

        MouseArea {
            id: backMouse
            anchors.fill: parent
            onClicked: root.state = "list"
        }
    }

    // 未来可扩展其他设置项的区域（目前空白）
    Item {
        anchors.top: titleBar.bottom
        anchors.bottom: backButton.top
        anchors.left: parent.left
        anchors.right: parent.right
    }
}