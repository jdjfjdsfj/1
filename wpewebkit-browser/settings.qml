import QtQuick 2.15

Rectangle {
    id: settingsRoot
    width: 320
    height: 170
    color: "#F5F5F5"

    signal backRequested()
    signal resetZoomRequested()
    signal editSearchTemplate()
    signal resetSettingsRequested()

    property int zoomPercent: 100
    property string searchTemplate: ""
    property bool showTemplateWarning: false

    // 防止事件穿透
    MouseArea { anchors.fill: parent }

    TitleBar {
        id: titleBar
        width: parent.width
        height: 20
        title: "设置"
    }

    // 可滚动内容区
    Flickable {
        x: 0
        y: 20
        width: parent.width
        height: parent.height - 50
        contentWidth: width
        contentHeight: columnContent.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: columnContent
            width: parent.width
            spacing: 0

            // 重置缩放
            Rectangle {
                width: parent.width
                height: 30
                color: rza.pressed ? "#E0E0E0" : "transparent"
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "重置网页缩放"
                        font.pixelSize: 13
                        color: "#000000"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        text: "当前: " + zoomPercent + "%"
                        font.pixelSize: 13
                        color: "#000000"
                    }
                }
                MouseArea {
                    id: rza
                    anchors.fill: parent
                    onClicked: settingsRoot.resetZoomRequested()
                }
            }

            // 搜索引擎模板
            Rectangle {
                width: parent.width
                height: 30
                color: sa.pressed ? "#E0E0E0" : "transparent"
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "搜索引擎"
                        font.pixelSize: 13
                        color: "#000000"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        width: 220
                        text: searchTemplate
                        font.pixelSize: 13
                        color: "#000000"
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignRight
                    }
                }
                MouseArea {
                    id: sa
                    anchors.fill: parent
                    onClicked: settingsRoot.editSearchTemplate()
                }
            }

            // 说明文本
            Text {
                width: parent.width - 16
                x: 8
                text: "WPE WebKit 完整渲染引擎\n支持 HTML/CSS/JavaScript/图片/视频"
                font.pixelSize: 10
                color: "#999999"
                wrapMode: Text.WordWrap
                topPadding: 6
                bottomPadding: 6
            }
        }
    }

    // 底部栏（返回 + 重置）
    Rectangle {
        x: 0
        y: parent.height - 30
        width: parent.width
        height: 30
        color: "#EEEEEE"
        border.color: "#CCCCCC"
        border.width: 0.5

        Row {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            spacing: 4

            Rectangle {
                width: 154
                height: 26
                anchors.verticalCenter: parent.verticalCenter
                radius: 3
                color: ba.pressed ? "#D0D0D0" : "#E0E0E0"
                border.color: "#B0B0B0"
                border.width: 0.5

                Text {
                    anchors.centerIn: parent
                    text: "返回"
                    font.pixelSize: 14
                    color: "#000000"
                }
                MouseArea {
                    id: ba
                    anchors.fill: parent
                    onClicked: settingsRoot.backRequested()
                }
            }

            Rectangle {
                width: 154
                height: 26
                anchors.verticalCenter: parent.verticalCenter
                radius: 3
                color: ra.pressed ? "#D0D0D0" : "#E0E0E0"
                border.color: "#B0B0B0"
                border.width: 0.5

                Text {
                    anchors.centerIn: parent
                    text: "重置"
                    font.pixelSize: 14
                    color: "#FF0000"
                }
                MouseArea {
                    id: ra
                    anchors.fill: parent
                    onClicked: settingsRoot.resetSettingsRequested()
                }
            }
        }
    }

    // 警告弹窗（搜索引擎模板不含%1时显示）
    MouseArea {
        visible: showTemplateWarning
        anchors.fill: parent
        z: 109
        onClicked: {}
    }

    Rectangle {
        visible: showTemplateWarning
        x: (parent.width - 240) / 2
        y: (parent.height - 100) / 2
        z: 110
        width: 240
        height: 100
        color: "#FFFFFF"
        border.color: "#AAAAAA"
        border.width: 1
        radius: 6

        Column {
            anchors.centerIn: parent
            spacing: 8
            Text {
                text: "需包含至少一个关键词占位符%1"
                font.pixelSize: 13
                color: "#000000"
                horizontalAlignment: Text.AlignHCenter
                width: 220
                wrapMode: Text.Wrap
            }
            Text {
                text: "（点击关闭）"
                font.pixelSize: 12
                color: "#888888"
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: showTemplateWarning = false
        }
    }
}
