import QtQuick 2.15
import QtQuick.LocalStorage 2.0
import WPEWebKit 1.0
import "qrc:/qml/commons"

Rectangle {
    id: root
    width: 320
    height: 170
    color: "#F5F5F5"

    signal backButtonClicked()

    // ---- 基本状态 ----
    property string currentInput: ""
    property bool menuVisible: false
    property bool keyboardPending: false

    // ---- 历史列表（QML 侧跟踪已访问 URL 用于展示） ----
    property var historyList: []
    property var db: null

    // ---- 书签 ----
    property var defaultPresets: [
        { name: "一言", url: "https://v1.hitokoto.cn/?c=a&encode=text" },
        { name: "必应", url: "https://cn.bing.com" },
        { name: "哔哩哔哩", url: "https://www.bilibili.com" }
    ]
    property var presets: defaultPresets

    // ---- URL格式化 ----
    function formatUrl(input) {
        var t = input.trim()
        if (t === "") return ""
        if (/^[a-zA-Z][a-zA-Z0-9+\-.]*:\/\//.test(t)) return t
        if (/^\/\//.test(t)) return "https:" + t
        if (t.indexOf('.') > 0 && t.indexOf(' ') === -1) return "https://" + t
        return "https://cn.bing.com/search?q=" + encodeURIComponent(t)
    }

    // ---- 持久化（书签） ----
    function initDatabase() {
        try {
            db = LocalStorage.openDatabaseSync("WPEBrowser", "1.0", "wpe浏览器状态", 100000)
            db.transaction(function(tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS state(key TEXT PRIMARY KEY, value TEXT)")
            })
            loadState()
        } catch(e) {
            db = null
        }
    }

    function saveState() {
        if (!db) return
        db.transaction(function(tx) {
            tx.executeSql("INSERT OR REPLACE INTO state(key,value) VALUES('presets',?)",
                          [JSON.stringify(presets)])
        })
    }

    function loadState() {
        if (!db) return
        db.readTransaction(function(tx) {
            var rs = tx.executeSql("SELECT value FROM state WHERE key='presets'")
            if (rs.rows.length > 0) presets = JSON.parse(rs.rows.item(0).value)
        })
    }

    // ---- URL变更时追踪历史（通过 Connections 监听 WPEWebView 信号） ----

    // ---- 导航操作 ----
    function goHome() {
        webView.stop()
        webView.loadUrl("about:blank")
    }
    function requestExit() {
        saveState()
        backButtonClicked()
    }
    function clearHistory() {
        historyList = []
    }

    // ---- 键盘 ----
    function _createKeyboard(initialText, callback) {
        if (qmlGlobal.inputPageShowing || keyboardPending) return
        keyboardPending = true
        var comp = qmlCreateComponent("YInputPage")
        if (comp.status === Component.Ready) {
            var incubator = comp.incubateObject(pagePopHelper.containerItem)
            if (incubator.status !== Component.Ready) {
                incubator.onStatusChanged = function(s) {
                    if (s === Component.Ready) _setupKeyboard(incubator.object, initialText, callback)
                }
            } else {
                _setupKeyboard(incubator.object, initialText, callback)
            }
        } else {
            keyboardPending = false
        }
    }

    function _setupKeyboard(kp, text, cb) {
        kp.backButtonClicked.connect(function() {
            qmlGlobal.inputPageShowing = false
            kp.todoDestroy()
            keyboardPending = false
        })
        kp.inputFinished.connect(function(c) {
            qmlGlobal.inputPageShowing = false
            kp.todoDestroy()
            if (c && cb) cb(c)
            keyboardPending = false
        })
        kp.enterText(text)
        kp.show()
        qmlGlobal.inputPageShowing = true
    }

    function handleUrlSubmit(text) {
        var f = formatUrl(text)
        if (f) webView.loadUrl(f)
    }

    // ---- 书签管理 ----
    function editPreset(index) {
        if (index < 0 || index >= presets.length) return
        var p = presets[index]
        _createKeyboard(p.name + "," + p.url, function(ns) {
            if (!ns) return
            var s = ns.replace(/[\r\n]/g, "").trim()
            if (s === "") {
                presets.splice(index, 1)
                presets = presets
                saveState()
                return
            }
            var ci = s.indexOf(",")
            var nm, ur
            if (ci === -1) { nm = s; ur = s }
            else { nm = s.substring(0, ci).trim(); ur = s.substring(ci + 1).trim() }
            if (nm === "" || ur === "") {
                presets.splice(index, 1)
            } else {
                presets[index].name = nm
                presets[index].url = ur
            }
            presets = presets
            saveState()
        })
    }

    function addPreset() {
        if (presets.length >= 20) return
        presets.push({ name: "书签", url: "https://" })
        presets = presets
        saveState()
    }

    // ---- 历史/设置页面 ----
    function showHistoryPage() { menuVisible = false; historyLoader.show() }
    function closeHistory() { historyLoader.hide() }
    function showSettingsPage() { menuVisible = false; settingsLoader.show() }
    function closeSettings() { settingsLoader.hide() }

    // ---- 缩放 ----
    function zoomIn() { webView.zoomFactor = Math.min(3.0, webView.zoomFactor + 0.25) }
    function zoomOut() { webView.zoomFactor = Math.max(0.5, webView.zoomFactor - 0.25) }

    // ============================================================
    // UI 布局
    // ============================================================

    TitleBar {
        id: titleBar
        width: parent.width
        height: 20
        title: webView.url ? webView.title : "主页"
    }

    Column {
        anchors.top: titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        // ---- 内容区域：WPE WebView ----
        Item {
            width: parent.width
            height: parent.height - 30
            clip: true

            WPEWebView {
                id: webView
                anchors.fill: parent
            }

            // 主页书签列表（URL为空或about:blank时显示）
            Item {
                id: homePresets
                anchors.fill: parent
                visible: !webView.url || webView.url === "about:blank" || webView.url === ""
                z: 1

                ListView {
                    anchors.fill: parent
                    model: presets
                    delegate: Rectangle {
                        width: parent.width
                        height: 30
                        color: ma.pressed ? "#E0E0E0" : "transparent"
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 5
                            anchors.rightMargin: 5
                            Text {
                                anchors.centerIn: parent
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.url
                                font.pixelSize: 16
                                color: "#000000"
                                visible: modelData.name === modelData.url
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 90
                                text: modelData.name.substring(0, 5)
                                font.pixelSize: 16
                                color: "#000000"
                                visible: modelData.name !== modelData.url
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                width: parent.width - 90
                                text: modelData.url
                                font.pixelSize: 16
                                color: "#000000"
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignRight
                                visible: modelData.name !== modelData.url
                            }
                        }
                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            onClicked: webView.loadUrl(modelData.url)
                            onPressAndHold: editPreset(index)
                        }
                    }
                    footer: Item {
                        width: parent.width
                        height: presets.length < 20 ? 30 : 0
                        visible: presets.length < 20
                        Rectangle {
                            anchors.fill: parent
                            color: pa.pressed ? "#E0E0E0" : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "添加书签"
                                font.pixelSize: 16
                                color: "#000000"
                            }
                            MouseArea {
                                id: pa
                                anchors.fill: parent
                                onClicked: addPreset()
                            }
                        }
                    }
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                }
            }
        }

        // ---- 底部栏（URL输入 + 菜单） ----
        Rectangle {
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
                    width: parent.width - 53
                    height: 26
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 3
                    color: "#FFFFFF"
                    border.color: "#CCCCCC"
                    border.width: 0.5

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        verticalAlignment: Text.AlignVCenter
                        text: webView.url || "输入网址或搜索词"
                        font.pixelSize: 12
                        color: webView.url ? "#000000" : "#AAAAAA"
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: _createKeyboard(webView.url, function(c) { handleUrlSubmit(c) })
                    }
                }

                Rectangle {
                    width: 45
                    height: 26
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 3
                    color: mba.pressed ? "#D0D0D0" : "#E0E0E0"
                    border.color: "#B0B0B0"
                    border.width: 0.5

                    Text {
                        anchors.centerIn: parent
                        text: "菜单"
                        font.pixelSize: 13
                        color: "#000000"
                    }
                    MouseArea {
                        id: mba
                        anchors.fill: parent
                        onClicked: menuVisible = !menuVisible
                    }
                }
            }
        }
    }

    // ---- 加载提示 ----
    Rectangle {
        visible: webView.loading
        x: (root.width - 135) / 2
        y: 20
        z: 10
        width: 135
        height: 30
        radius: 6
        color: "#FFFFFF"
        border.color: "#DDDDDD"
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "加载中… " + webView.loadProgress + "%"
            font.pixelSize: 13
            color: "#000000"
        }
        MouseArea {
            anchors.fill: parent
            onClicked: webView.stop()
        }
    }

    // ---- 菜单 ----
    Rectangle {
        visible: menuVisible
        x: parent.width - 116 - 6
        y: parent.height - 30 - 96 - 2
        width: 116
        height: 96
        radius: 4
        color: "#FFFFFF"
        border.color: "#AAAAAA"
        border.width: 1
        z: 98

        Grid {
            anchors.fill: parent
            anchors.margins: 3
            columns: 2
            rows: 4
            spacing: 0

            MenuItem { text: "返回"; onTriggered: { webView.goBack(); menuVisible = false } }
            MenuItem { text: "前进"; onTriggered: { webView.goForward(); menuVisible = false } }
            MenuItem { text: "刷新"; onTriggered: { webView.reload(); menuVisible = false } }
            MenuItem { text: "主页"; onTriggered: { goHome(); menuVisible = false } }
            MenuItem { text: "放大"; onTriggered: { zoomIn(); menuVisible = false } }
            MenuItem { text: "缩小"; onTriggered: { zoomOut(); menuVisible = false } }
            MenuItem { text: "历史"; onTriggered: showHistoryPage() }
            MenuItem { text: "退出"; onTriggered: { requestExit(); menuVisible = false } }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -10
            z: -1
            onClicked: menuVisible = false
        }
    }

    MouseArea {
        visible: menuVisible
        anchors.fill: parent
        z: 90
        onClicked: menuVisible = false
    }

    component MenuItem: Rectangle {
        width: parent.width / 2
        height: parent.height / 4
        radius: 2
        color: ma2.pressed ? "#E0E0E0" : "transparent"
        property alias text: label.text
        signal triggered()

        Text {
            id: label
            anchors.centerIn: parent
            font.pixelSize: 14
            color: "#000000"
        }
        MouseArea {
            id: ma2
            anchors.fill: parent
            onClicked: parent.triggered()
        }
    }

    // ---- 历史页面 ----
    Loader {
        id: historyLoader
        anchors.fill: parent
        z: 95
        active: false
        source: "history.qml"

        onLoaded: {
            item.historyModel = Qt.binding(function() { return historyList })
            item.urlClicked.connect(function(url) {
                webView.loadUrl(url)
                closeHistory()
            })
            item.clearHistoryRequested.connect(function() {
                clearHistory()
            })
            item.backRequested.connect(closeHistory)
        }
        function show() { active = true }
        function hide() { active = false }
    }

    // ---- 设置页面 ----
    Loader {
        id: settingsLoader
        anchors.fill: parent
        z: 95
        active: false
        source: "settings.qml"

        onLoaded: {
            item.zoomPercent = Qt.binding(function() { return Math.round(webView.zoomFactor * 100) })
            item.searchTemplate = "https://cn.bing.com/search?q=%1"

            item.resetZoomRequested.connect(function() { webView.zoomFactor = 1.0 })
            item.editSearchTemplate.connect(function() {
                _createKeyboard("https://cn.bing.com/search?q=%1", function() {})
            })

            item.resetSettingsRequested.connect(function() {
                webView.zoomFactor = 1.0
                presets = defaultPresets
                saveState()
            })
            item.backRequested.connect(closeSettings)
        }
        function show() { active = true }
        function hide() { active = false }
    }

    // ---- 键盘辅助 ----
    YPagePopHelper {
        id: pagePopHelper
        z: 99
        property var containerItem: this
        isShowing: qmlGlobal.inputPageShowing
        objectName: "from_WPEBrowser"
    }

    // ---- WebView 事件监听（URL变更时追踪历史） ----
    Connections {
        target: webView
        function onUrlChanged() {
            var u = webView.url
            if (u && u !== "" && u !== "about:blank") {
                if (historyList.length === 0 || historyList[historyList.length - 1] !== u) {
                    if (historyList.length >= 50) historyList.shift()
                    historyList.push(u)
                }
            }
        }
    }

    // ---- 生命周期 ----
    Component.onCompleted: {
        initDatabase()
        // 启动时加载必应首页
        webView.loadUrl("https://cn.bing.com")
    }
    Component.onDestruction: {
        saveState()
    }
}
