import QtQuick 2.15

Item {
    id: detailPage
    property var detailSong: null

    function formatDuration(ms) {
        if (!ms) return "未知";
        var sec = Math.floor(ms / 1000);
        return Math.floor(sec / 60) + ":" + (sec % 60).toString().padStart(2, '0');
    }

    Row {
        id: infoRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 6
        height: 110
        spacing: 10

        Image {
            id: coverImage
            width: 100
            height: 100
            source: {
                var s = detailPage.detailSong;
                if (s && s.picUrl) return s.picUrl;
                return "";
            }
            fillMode: Image.PreserveAspectFit
        }

        Flickable {
            width: parent.width - coverImage.width - parent.spacing
            height: parent.height
            contentHeight: infoColumn.height
            clip: true
            Column {
                id: infoColumn
                width: parent.width
                spacing: 4

                Text {
                    width: parent.width
                    text: (detailPage.detailSong ? detailPage.detailSong.name : "") +
                          (detailPage.detailSong && detailPage.detailSong.payType !== 0 ? " (VIP)" : "")
                    color: "#333"
                    font.pixelSize: 14
                    font.bold: true
                    font.family: "Microsoft YaHei"
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: {
                        var s = detailPage.detailSong;
                        if (!s) return "";
                        var lines = [];
                        lines.push("艺术家: " + (s.artist || ""));
                        lines.push("专辑: " + (s.album || ""));
                        lines.push("时长: " + formatDuration(s.duration));
                        lines.push("ID: " + (s.id || ""));
                        return lines.join("\n");
                    }
                    color: "#666"
                    font.pixelSize: 12
                    font.family: "Microsoft YaHei"
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    Row {
        id: bottomRow
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: 5
        anchors.right: parent.right
        anchors.rightMargin: 5
        height: 36
        spacing: 4

        Repeater {
            model: ["返回", "全部", "音频", "歌词"]
            delegate: Rectangle {
                width: (bottomRow.width - 12) / 4
                height: 28
                radius: 4
                color: mouseArea.pressed ? "#cccccc" : "#ffffff"
                border.color: "#aaaaaa"
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: modelData
                    color: "#333"
                    font.family: "Microsoft YaHei"
                    font.pixelSize: 13
                }
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    onClicked: {
                        if (index === 0) {
                            root.state = "list";
                        } else if (index === 1) {
                            root.startDownload("all");
                        } else if (index === 2) {
                            root.startDownload("audio");
                        } else if (index === 3) {
                            root.startDownload("lyric");
                        }
                    }
                }
            }
        }
    }
}