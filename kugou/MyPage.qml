import QtQuick 2.15
import "qrc:/qml/commons"

Item {
    id: myPageRoot
    property string statusText: ""
    property var userInfo: null
    property var playlists: []
    property var vipRecords: []

    StatusBar {
        id: statusBar
        anchors.top: parent.top
        statusText: myPageRoot.statusText
    }

    // 底部按钮行
    Row {
        id: bottomRow
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 36
        anchors.margins: 4
        spacing: 4

        Rectangle {
            width: (parent.width - 8) / 3
            height: 28; radius: 4
            color: backBtn.pressed ? "#cccccc" : "#ffffff"
            border.color: "#aaaaaa"; border.width: 1
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.centerIn: parent; text: "返回"; color: "#333"
                font.family: "Microsoft YaHei"; font.pixelSize: 16
            }
            MouseArea {
                id: backBtn; anchors.fill: parent
                onClicked: root.state = "list"
            }
        }

        Rectangle {
            width: (parent.width - 8) / 3
            height: 28; radius: 4
            color: loginLogoutBtn.pressed ? "#cccccc" : "#ffffff"
            border.color: "#aaaaaa"; border.width: 1
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.centerIn: parent
                text: root.hasCookie ? "退出登录" : "登录"
                color: "#333"
                font.family: "Microsoft YaHei"; font.pixelSize: 16
            }
            MouseArea {
                id: loginLogoutBtn; anchors.fill: parent
                onClicked: {
                    if (root.hasCookie) {
                        root.guestCookie = "";
                        root.token = "";
                        root.userId = "";
                        root.dfid = "";
                        root.hasCookie = false;
                        root.saveCookieJson();
                        root.state = "list";
                    } else {
                        root.state = "login";
                    }
                }
            }
        }

        Rectangle {
            width: (parent.width - 8) / 3
            height: 28; radius: 4
            color: settingsBtn.pressed ? "#cccccc" : "#ffffff"
            border.color: "#aaaaaa"; border.width: 1
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.centerIn: parent; text: "设置"; color: "#333"
                font.family: "Microsoft YaHei"; font.pixelSize: 16
            }
            MouseArea {
                id: settingsBtn; anchors.fill: parent
                onClicked: root.state = "settings"
            }
        }
    }

    // 内容区域
    Item {
        id: contentArea
        anchors.top: statusBar.bottom
        anchors.bottom: bottomRow.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 6

        // 未登录提示
        Column {
            anchors.centerIn: parent
            spacing: 10
            visible: !root.hasCookie
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "您尚未登录"
                color: "#666"
                font.pixelSize: 16
                font.family: "Microsoft YaHei"
            }
        }

        // 已登录界面
        Item {
            anchors.fill: parent
            visible: root.hasCookie

            // 左侧区域（1/2宽度）
            Item {
                id: leftColumn
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width / 2

                Flickable {
                    anchors.fill: parent
                    contentHeight: leftContent.height
                    clip: true

                    Column {
                        id: leftContent
                        width: parent.width
                        spacing: 6

                        // 头像 + 右侧两行信息（昵称 + 位置+生日）
                        Row {
                            spacing: 5
                            Image {
                                width: 50; height: 50
                                source: userInfo ? (userInfo.pic || "") : ""
                                fillMode: Image.PreserveAspectCrop
                                clip: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                Text {
                                    text: userInfo ? (userInfo.nickname || "未知昵称") : ""
                                    color: "#333"
                                    font.pixelSize: 14
                                    font.bold: true
                                    font.family: "Microsoft YaHei"
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: {
                                        if (!userInfo) return "";
                                        var province = userInfo.province || "";
                                        var city = userInfo.city || "";
                                        var birthday = userInfo.birthday || "";
                                        var line1 = province + " " + city;
                                        var line2 = birthday;
                                        if (line1.trim() && line2) return line1.trim() + "\n" + line2;
                                        return line1.trim() || line2;
                                    }
                                    color: "#666"
                                    font.pixelSize: 12
                                    font.family: "Microsoft YaHei"
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        // 简介
                        Text {
                            width: parent.width
                            text: userInfo ? (userInfo.descri || "") : ""
                            color: "#666"
                            font.pixelSize: 12
                            font.family: "Microsoft YaHei"
                            wrapMode: Text.WordWrap
                            visible: text !== ""
                        }

                        // VIP 领取状态列表
                        Text {
                            width: parent.width
                            text: "VIP领取状态"
                            color: "#333"
                            font.pixelSize: 14
                            font.bold: true
                            font.family: "Microsoft YaHei"
                        }

                        Repeater {
                            model: vipRecords
                            delegate: Rectangle {
                                width: parent.width
                                height: 24
                                color: "transparent"

                                Text {
                                    id: dateLabel
                                    text: modelData.day
                                    color: "#333"
                                    font.pixelSize: 14
                                    font.family: "Microsoft YaHei"
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    id: statusLabel
                                    text: modelData.statusText
                                    color: modelData.statusText === "SVIP" || modelData.statusText === "TVIP" ? "#cc7b00" : "#666"
                                    font.pixelSize: 14
                                    font.family: "Microsoft YaHei"
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (modelData.clickable) {
                                            if (modelData.action === "claim") {
                                                claimVip(modelData.day);
                                            } else if (modelData.action === "upgrade") {
                                                upgradeSvip();
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: vipRecords.length === 0
                            text: "暂无数据"
                            color: "#999"
                            font.pixelSize: 12
                            font.family: "Microsoft YaHei"
                        }
                    }
                }
            }

            // 右侧歌单区域（1/2宽度）
            Flickable {
                id: playlistFlick
                anchors.left: leftColumn.right
                anchors.leftMargin: 6
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                contentHeight: playlistColumn.height + 8
                clip: true

                Column {
                    id: playlistColumn
                    width: parent.width
                    spacing: 6

                    Text {
                        width: parent.width
                        text: "歌单"
                        color: "#333"
                        font.pixelSize: 14
                        font.bold: true
                        font.family: "Microsoft YaHei"
                    }

                    Repeater {
                        model: playlists
                        delegate: Rectangle {
                            width: parent.width
                            height: 50
                            color: "#f9f9f9"
                            radius: 4
                            border.color: "#e0e0e0"
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 6

                                Rectangle {
                                    width: 40; height: 40
                                    radius: 4
                                    color: modelData.pic ? "transparent" : "#dddddd"
                                    anchors.verticalCenter: parent.verticalCenter
                                    Image {
                                        anchors.fill: parent
                                        source: modelData.pic || ""
                                        visible: modelData.pic !== ""
                                        fillMode: Image.PreserveAspectCrop
                                        clip: true
                                    }
                                }

                                Column {
                                    width: parent.width - 46
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: modelData.name || "未命名歌单"
                                        color: "#333"
                                        font.pixelSize: 14
                                        font.family: "Microsoft YaHei"
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: (modelData.m_count !== undefined ? modelData.m_count : 0) + "首"
                                        color: "#999"
                                        font.pixelSize: 12
                                        font.family: "Microsoft YaHei"
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: playlists.length === 0
                        text: "暂无歌单"
                        color: "#999"
                        font.pixelSize: 12
                        font.family: "Microsoft YaHei"
                    }
                }
            }
        }
    }

    // ---------- VIP 领取/升级逻辑 ----------
    function claimVip(dateStr) {
        statusText = "领取VIP中...";
        var xhr = new XMLHttpRequest();
        var url = root.apiBase + "/youth/day/vip?receive_day=" + dateStr + "&cookie=" + encodeURIComponent(root.buildCookieParam()) + "&_t=" + Date.now();
        xhr.open("GET", url);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var resp = JSON.parse(xhr.responseText);
                        if (resp.status === 1 && resp.error_code === 0) {
                            statusText = "领取成功";
                            refreshVipRecords();
                        } else {
                            statusText = "领取失败";
                        }
                    } catch(e) {
                        statusText = "数据错误";
                    }
                } else {
                    statusText = "网络错误";
                }
            }
        };
        xhr.send();
    }

    function upgradeSvip() {
        statusText = "升级VIP中...";
        var xhr = new XMLHttpRequest();
        var url = root.apiBase + "/youth/day/vip/upgrade?cookie=" + encodeURIComponent(root.buildCookieParam()) + "&_t=" + Date.now();
        xhr.open("GET", url);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var resp = JSON.parse(xhr.responseText);
                        if (resp.status === 1 && resp.error_code === 0) {
                            statusText = "升级成功";
                            refreshVipRecords();
                        } else {
                            statusText = "升级失败";
                        }
                    } catch(e) {
                        statusText = "数据错误";
                    }
                } else {
                    statusText = "网络错误";
                }
            }
        };
        xhr.send();
    }

    function refreshVipRecords() {
        var xhr = new XMLHttpRequest();
        var url = root.apiBase + "/youth/month/vip/record?cookie=" + encodeURIComponent(root.buildCookieParam()) + "&_t=" + Date.now();
        xhr.open("GET", url);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var resp = JSON.parse(xhr.responseText);
                        if (resp.status === 1 && resp.error_code === 0 && resp.data && resp.data.list) {
                            buildVipList(resp.data.list);
                        } else {
                            statusText = "获取VIP状态失败";
                        }
                    } catch(e) {
                        statusText = "数据解析错误";
                    }
                } else {
                    statusText = "网络错误";
                }
            }
        };
        xhr.send();
    }

    function buildVipList(apiList) {
        var today = new Date();
        var records = [];
        for (var i = 0; i < 10; i++) {
            var date = new Date(today);
            date.setDate(today.getDate() + i);
            var year = date.getFullYear();
            var month = ("0" + (date.getMonth() + 1)).slice(-2);
            var day = ("0" + date.getDate()).slice(-2);
            var dateStr = year + "-" + month + "-" + day;

            var found = null;
            for (var j = 0; j < apiList.length; j++) {
                if (apiList[j].day === dateStr) {
                    found = apiList[j];
                    break;
                }
            }
            var statusText = "";
            var clickable = false;
            var action = "";
            if (found && found.receive_vip === 1) {
                statusText = found.vip_type.toUpperCase();
                if (i === 0 && found.vip_type === "tvip") {
                    clickable = true;
                    action = "upgrade";
                }
            } else {
                statusText = "未领取";
                clickable = true;
                action = "claim";
            }
            records.push({ day: dateStr, statusText: statusText, clickable: clickable, action: action });
        }
        vipRecords = records;
    }

    // ---------- 请求用户信息和歌单 ----------
    function fetchUserInfo() {
        if (!root.hasCookie) return;
        // 用户详情
        var xhrDetail = new XMLHttpRequest();
        var urlDetail = root.apiBase + "/user/detail?cookie=" + encodeURIComponent(root.buildCookieParam()) + "&_t=" + Date.now();
        xhrDetail.open("GET", urlDetail);
        xhrDetail.onreadystatechange = function() {
            if (xhrDetail.readyState === XMLHttpRequest.DONE) {
                if (xhrDetail.status === 200) {
                    try {
                        var resp = JSON.parse(xhrDetail.responseText);
                        if (resp.status === 1 && resp.error_code === 0 && resp.data) {
                            userInfo = resp.data;
                        } else {
                            statusText = "获取信息失败";
                        }
                    } catch(e) {
                        statusText = "数据解析错误";
                    }
                } else {
                    statusText = "网络错误";
                }
            }
        };
        xhrDetail.send();

        // 歌单
        var xhrPlaylist = new XMLHttpRequest();
        var urlPlaylist = root.apiBase + "/user/playlist?cookie=" + encodeURIComponent(root.buildCookieParam()) + "&_t=" + Date.now();
        xhrPlaylist.open("GET", urlPlaylist);
        xhrPlaylist.onreadystatechange = function() {
            if (xhrPlaylist.readyState === XMLHttpRequest.DONE) {
                if (xhrPlaylist.status === 200) {
                    try {
                        var resp = JSON.parse(xhrPlaylist.responseText);
                        if (resp.status === 1 && resp.error_code === 0 && resp.data && resp.data.info) {
                            playlists = resp.data.info;
                        }
                    } catch(e) {
                        console.warn("[Playlist] 解析失败");
                    }
                }
            }
        };
        xhrPlaylist.send();

        // VIP 记录
        refreshVipRecords();
    }

    onVisibleChanged: {
        if (visible) fetchUserInfo();
    }

    Component.onCompleted: {
        if (visible) fetchUserInfo();
    }

    Connections {
        target: root
        onHasCookieChanged: {
            if (root.hasCookie) fetchUserInfo();
            else {
                userInfo = null;
                playlists = [];
                vipRecords = [];
                statusText = "";
            }
        }
    }
}