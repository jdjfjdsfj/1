import QtQuick 2.15

Rectangle {
    id: statusBar
    width: parent.width
    height: 20
    color: "#dddddd"
    property string statusText: ""

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: "酷狗音乐"
        color: "#333"
        font.pixelSize: 12
        font.family: "Microsoft YaHei"
    }

    Text {
        id: statusMsg
        anchors.centerIn: parent
        color: "#666"
        font.pixelSize: 12
        font.family: "Microsoft YaHei"
        text: statusText
    }

    Text {
        id: timeText
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatTime(new Date(), "hh:mm:ss")
        color: "#666"
        font.pixelSize: 12
        font.family: "Microsoft YaHei"
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: timeText.text = Qt.formatTime(new Date(), "hh:mm:ss")
    }
}