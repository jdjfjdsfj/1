import QtQuick 2.15

Rectangle {
    id: errorDialog
    width: 260
    height: 120
    color: "#ffffff"
    border.color: "#cccccc"
    border.width: 2
    radius: 8
    visible: false
    z: 10   // 从 100 改为 10，低于键盘（z=99）

    property alias errorText: errorMessage.text
    signal closed()

    Text {
        id: errorTitle
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        text: "错误"
        font.bold: true
        color: "#d32f2f"
        font.pixelSize: 14
        font.family: "Microsoft YaHei"
    }

    Text {
        id: errorMessage
        anchors.top: errorTitle.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        wrapMode: Text.WordWrap
        color: "#333"
        font.pixelSize: 12
        font.family: "Microsoft YaHei"
        horizontalAlignment: Text.AlignHCenter
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: 60
        height: 26
        radius: 4
        color: okBtnArea.pressed ? "#cccccc" : "#f0f0f0"
        border.color: "#aaaaaa"
        border.width: 1
        Text {
            anchors.centerIn: parent
            text: "确定"
            color: "#333"
            font.pixelSize: 13
            font.family: "Microsoft YaHei"
        }
        MouseArea {
            id: okBtnArea
            anchors.fill: parent
            onClicked: {
                errorDialog.visible = false;
                errorDialog.closed();
            }
        }
    }
}