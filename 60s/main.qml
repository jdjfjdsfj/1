import QtQuick 2.15
import "qrc:/qml/commons"

Rectangle {
    id: root
    width: 320
    height: 170
    color: "#0B0F17"
    property string appFontFamily: "Microsoft YaHei"
    // ===== 可自定义服务器/请求行为 =====
    property string apiBaseUrl: "https://60s.viki.moe"   // 用户可改
    property string apiPrefix: "/v2"                             // 可改
    property bool enableCacheBuster: true                        // 强制每次重新请求
    property string cacheBusterKey: "_t"                         // 时间戳参数名，用于防止qt缓存
    property int maxContentLength: 1000000                        // 最大内容长度限制
    // ===== 状态 =====
    property string currentPage: "home"   // home / content
    property string currentTitle: ""
    property string currentContent: ""
    property bool isLoading: false
    property string errorMessage: ""
    property var httpRequest: null
    property int currentRequestId: 0
    property bool showHomeList: false
    property bool errorPopupVisible: false
    property string errorPopupText: ""
    // ===== 图片查看 =====
    property var contentSegments: []
    property bool imagePreviewVisible: false
    property string previewImageUrl: ""
    property int imageSaveCounter: 0

    // ===== 通用输入回调状态 =====
    property var inputPending: ({ active: false, action: "", baseUrl: "", item: null, done: null, fail: null })

    function showErrorPopup(msg) {
        errorPopupText = msg || "请求失败"
        errorPopupVisible = true
    }

    // ============================================================
    // 全功能菜单（42个端点）
    // ============================================================
    property var menuItems: [
        // ── 周期资讯 ──
        { name: "60秒看世界", endpoint: "60s", icon: "📰", accent: "#4DA3FF" },
        { name: "AI 新闻", endpoint: "ai-news", icon: "🤖", accent: "#A78BFA" },
        { name: "IT 科技", endpoint: "it-news", icon: "💻", accent: "#34D399" },
        { name: "必应壁纸", endpoint: "bing", icon: "🖼", accent: "#60A5FA" },
        { name: "历史上的今天", endpoint: "today-in-history", icon: "📅", accent: "#10B981" },
        { name: "摸鱼日报", endpoint: "moyu", icon: "🐟", accent: "#38BDF8" },

        // ── 实用功能 ──
        { name: "黄金价格", endpoint: "gold-price", icon: "🎖", accent: "#FBBF24" },
        { name: "汽油价格", endpoint: "fuel-price", icon: "⛽", accent: "#F59E0B", action: "getFuelPrice" },
        { name: "汇率", endpoint: "exchange-rate", icon: "💱", accent: "#F472B6", action: "getRate" },
        { name: "实时天气", endpoint: "weather", icon: "🌡", accent: "#38BDF8", action: "getWeatherRealTime" },
        { name: "天气预报", endpoint: "weather/forecast", icon: "🌤", accent: "#38BDF8", action: "getWeather" },
        { name: "歌词搜索", endpoint: "lyric", icon: "🎵", accent: "#EC4899", action: "getLyric" },
        { name: "在线翻译", endpoint: "fanyi", icon: "🌐", accent: "#8B5CF6", action: "getFanyi" },
        { name: "生成二维码", endpoint: "qrcode", icon: "🔲", accent: "#6B7280", action: "getQrcode" },
        { name: "Whois查询", endpoint: "whois", icon: "🔍", accent: "#6366F1", action: "getWhois" },
        { name: "公网IP", endpoint: "ip", icon: "🌐", accent: "#3B82F6", action: "getIp" },
        { name: "哈希计算", endpoint: "hash", icon: "#️⃣", accent: "#9CA3AF", action: "getHash" },
        { name: "密码生成", endpoint: "password", icon: "🔐", accent: "#10B981", action: "getPassword" },
        { name: "链接OG", endpoint: "og", icon: "🔗", accent: "#3B82F6", action: "getOg" },
        { name: "百度百科", endpoint: "baike", icon: "📚", accent: "#3B82F6", action: "getBaike" },
        { name: "农历信息", endpoint: "lunar", icon: "🌙", accent: "#F59E0B" },

        // ── 热门榜单 ──
        { name: "微博热搜", endpoint: "weibo", icon: "📣", accent: "#EF4444" },
        { name: "知乎", endpoint: "zhihu", icon: "🧠", accent: "#3B82F6" },
        { name: "百度热搜", endpoint: "baidu/hot", icon: "🔎", accent: "#2563EB" },
        { name: "百度贴吧", endpoint: "baidu/tieba", icon: "💬", accent: "#3B82F6" },
        { name: "抖音热搜", endpoint: "douyin", icon: "🎵", accent: "#111827" },
        { name: "小红书", endpoint: "rednote", icon: "📕", accent: "#EF4444" },
        { name: "B站热搜", endpoint: "bili", icon: "📺", accent: "#FB7299", action: "getBili" },
        { name: "夸克热点", endpoint: "quark", icon: "🔥", accent: "#3B82F6" },
        { name: "头条热搜", endpoint: "toutiao", icon: "📰", accent: "#EF4444" },
        { name: "懂车帝", endpoint: "dongchedi", icon: "🚗", accent: "#3B82F6", action: "getDongchedi" },
        { name: "网易云榜单", endpoint: "ncm-rank/list", icon: "🎧", accent: "#C20C0C", action: "getNcmRank" },
        { name: "HackerNews", endpoint: "hacker-news/top", icon: "💻", accent: "#FF6600", action: "getHackerNews" },
        { name: "猫眼票房", endpoint: "maoyan/realtime/movie", icon: "🎬", accent: "#EF4444", action: "getMaoyan" },

        // ── 消遣娱乐 ──
        { name: "今日运势", endpoint: "luck", icon: "🍀", accent: "#22C55E" },
        { name: "答案之书", endpoint: "answer", icon: "📜", accent: "#F97316" },
        { name: "随机一言", endpoint: "hitokoto", icon: "💬", accent: "#60A5FA" },
        { name: "搞笑段子", endpoint: "duanzi", icon: "😂", accent: "#FBBF24" },
        { name: "发病文学", endpoint: "fabing", icon: "🤪", accent: "#A78BFA" },
        { name: "KFC文案", endpoint: "kfc", icon: "🍗", accent: "#EF4444" },
        { name: "冷笑话", endpoint: "dad-joke", icon: "❄", accent: "#60A5FA" },
        { name: "Epic免费游戏", endpoint: "epic", icon: "🎮", accent: "#8A2BE2" }
    ]

    signal backToHome()
    signal backButtonClicked()

    function buildUrlWithParams(endpoint) {
        var url = buildBaseUrl(endpoint)
        var qs = []
        qs.push("encoding=markdown")
        if (enableCacheBuster)
            qs.push(cacheBusterKey + "=" + Date.now())
        if (qs.length > 0)
            url += "?" + qs.join("&")
        return url
    }

    function buildBaseUrl(endpoint) {
        return apiBaseUrl + apiPrefix + "/" + endpoint
    }

    function fetchContent(endpoint) {
        if (httpRequest) {
            httpRequest.abort()
            httpRequest = null
        }

        isLoading = true
        errorMessage = ""
        currentContent = ""

        var selectedItem = null
        for (var i = 0; i < menuItems.length; i++) {
            if (menuItems[i].endpoint === endpoint) {
                selectedItem = menuItems[i]
                currentTitle = menuItems[i].name
                break
            }
        }

        runCustomActionOrDefaultFetch(selectedItem, endpoint)
    }

    function defaultFetch(url) {
        if (httpRequest && httpRequest.readyState === XMLHttpRequest.LOADING) {
            httpRequest.abort()
            httpRequest = null
        }

        var reqId = ++currentRequestId
        httpRequest = new XMLHttpRequest()

        httpRequest.onreadystatechange = function() {
            if (reqId !== currentRequestId) return
            if (httpRequest.readyState === XMLHttpRequest.DONE) {
                isLoading = false
                if (httpRequest.status === 200) {
                    var text = httpRequest.responseText || ""
                    if (text.length > maxContentLength) {
                        errorMessage = "内容过大，无法显示"
                    } else {
                        currentContent = text
                        currentPage = "content"
                    }
                } else {
                    errorMessage = "加载失败: HTTP " + httpRequest.status
                }
                httpRequest = null
            }
        }

        httpRequest.onerror = function() {
            if (reqId !== currentRequestId) return
            isLoading = false
            errorMessage = "网络错误，请检查连接"
            httpRequest = null
        }

        httpRequest.open("GET", url)
        httpRequest.send()
    }

    function runCustomActionOrDefaultFetch(selectedItem, endpoint) {
        var baseUrl = buildBaseUrl(endpoint)
        var url = buildUrlWithParams(endpoint)

        if (!selectedItem || selectedItem.action === undefined || selectedItem.action === null) {
            defaultFetch(url)
            return
        }

        var fn = null
        if (typeof selectedItem.action === "function") {
            fn = selectedItem.action
        } else if (typeof selectedItem.action === "string" && selectedItem.action !== "") {
            if (typeof root[selectedItem.action] === "function")
                fn = root[selectedItem.action]
        }

        if (!fn) {
            isLoading = false
            errorMessage = "action 无效：必须是函数或 root 上的函数名字符串"
            return
        }

        var finished = false
        function done(md) {
            if (finished) return
            finished = true
            isLoading = false

            if (typeof md !== "string") {
                errorMessage = "action 必须返回/回调 Markdown 字符串"
                return
            }
            if (md.length > maxContentLength) {
                errorMessage = "内容过大，无法显示"
                return
            }

            currentContent = md
            currentPage = "content"
        }

        function fail(msg) {
            if (finished) return
            finished = true
            isLoading = false
            errorMessage = msg || "加载失败"
            root.showErrorPopup(msg)
        }

        try {
            var ret = fn(baseUrl, selectedItem, done, fail)
            if (typeof ret === "string") {
                done(ret)
            }
        } catch (e) {
            fail("action 执行异常: " + e)
        }
    }

    function goHome() {
        if (httpRequest) {
            httpRequest.abort()
            httpRequest = null
        }
        currentPage = "home"
        currentTitle = ""
        currentContent = ""
        isLoading = false
        errorMessage = ""
    }

    function handleBack() {
        if (imagePreviewVisible) {
            imagePreviewVisible = false
            previewImageUrl = ""
            return
        }
        if (currentPage === "content") goHome()
        else backButtonClicked()
    }

    // ===== 内容图片：分段解析 / 系统查看器 =====
    onCurrentContentChanged: {
        contentSegments = parseSegments(currentContent)
        prepareDataImageSegments()
    }

    // 把 markdown 切成 文字段 + 图片段，图片段可点击放大
    function parseSegments(md) {
        var segs = []
        var re = /!\[([^\]]*)\]\(([^)]+)\)/g
        var last = 0
        var m
        while ((m = re.exec(md)) !== null) {
            if (m.index > last)
                segs.push({ type: "text", text: md.substring(last, m.index) })
            segs.push({ type: "image", url: (m[2] || "").trim(), alt: m[1] || "" })
            last = re.lastIndex
        }
        if (last < md.length)
            segs.push({ type: "text", text: md.substring(last) })
        return segs
    }

    // data: 图片（如二维码）QML Image 无法直接加载，先解码成 /tmp 本地文件
    function prepareDataImageSegments() {
        if (typeof shell === "undefined" || !shell) return
        for (var i = 0; i < contentSegments.length; i++) {
            if (contentSegments[i].type !== "image") continue
            if (contentSegments[i].url.indexOf("data:") !== 0) continue
            ;(function(idx) {
                var seg = contentSegments[idx]
                var comma = seg.url.indexOf(",")
                if (comma < 0) return
                var b64 = seg.url.substring(comma + 1)
                var path = "/tmp/60s_images/img_" + Date.now() + "_" + idx + ".png"
                shell.execAsync("mkdir -p /tmp/60s_images && echo '" + b64 + "' | base64 -d > " + path + " && test -s " + path, function(result) {
                    if (result && result.exitCode === 0) {
                        contentSegments[idx].url = path
                        contentSegments = contentSegments.slice()
                    }
                })
            })(i)
        }
    }

    function imageExtFromUrl(url) {
        var path = url.split("?")[0].toLowerCase()
        var exts = [".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"]
        for (var i = 0; i < exts.length; i++) {
            if (path.length >= exts[i].length && path.substr(path.length - exts[i].length) === exts[i])
                return exts[i] === ".jpeg" ? ".jpg" : exts[i]
        }
        return ".jpg"
    }

    function openViewerOrPreview(localPath) {
        // 先记录路径，系统查看器组件不可用时 show() 里会回退到应用内预览
        previewImageUrl = "file://" + localPath
        if (typeof imageViewer !== "undefined" && imageViewer) {
            imageViewer.open(localPath)
            id_pop_container.show("qrc:/qml/audiopages/FileManagerImageViewer.qml")
        } else {
            imagePreviewVisible = true
        }
    }

    function showImagePreview(src) {
        previewImageUrl = src
        imagePreviewVisible = true
    }

    // 点击图片：系统 FileManagerImageViewer 只能打开本地文件，
    // 远程图先用宿主注入的 shell 下载到 /tmp，再交给系统查看器；
    // 宿主未注入 imageViewer / shell 时回退到应用内全屏预览。
    function openImageWithSystemViewer(url) {
        if (!url) return
        if (url.indexOf("file://") === 0) { openViewerOrPreview(url.substring(7)); return }
        if (url.charAt(0) === "/") { openViewerOrPreview(url); return }

        if (typeof shell === "undefined" || !shell) { showImagePreview(url); return }

        if (url.indexOf("data:") === 0) {
            var comma = url.indexOf(",")
            if (comma < 0) { showErrorPopup("图片数据无效"); return }
            var b64 = url.substring(comma + 1)
            var dpath = "/tmp/60s_images/img_" + Date.now() + "_" + (++root.imageSaveCounter) + ".png"
            shell.execAsync("mkdir -p /tmp/60s_images && echo '" + b64 + "' | base64 -d > " + dpath + " && test -s " + dpath, function(result) {
                if (result && result.exitCode === 0) openViewerOrPreview(dpath)
                else showErrorPopup("图片解码失败")
            })
            return
        }

        var u = url
        if (u.indexOf("//") === 0) u = "https:" + u
        var path = "/tmp/60s_images/img_" + Date.now() + "_" + (++root.imageSaveCounter) + imageExtFromUrl(u)
        shell.execAsync("mkdir -p /tmp/60s_images && curl -sL --max-time 20 -o " + path + " '" + u + "' && test -s " + path, function(result) {
            if (result && result.exitCode === 0) openViewerOrPreview(path)
            else showImagePreview(u)
        })
    }

    // ===== 通用输入请求 =====
    function requestInput(action, baseUrl, item, done, fail, initialText) {
        root.inputPending = {
            active: true,
            action: action,
            baseUrl: baseUrl,
            item: item,
            done: done,
            fail: fail
        }
        requestKeyboard(initialText || "")
    }

    function onInputFinished(content) {
        if (!root.inputPending.active) return

        var action = root.inputPending.action
        var baseUrl = root.inputPending.baseUrl
        var item = root.inputPending.item
        var done = root.inputPending.done
        var fail = root.inputPending.fail

        root.inputPending = ({ active: false, action: "", baseUrl: "", item: null, done: null, fail: null })

        var keyword = (content || "").trim()
        if (keyword === "") {
            if (fail) fail("请输入内容")
            return
        }

        if (action === "baike") {
            doBaikeFetch(baseUrl, item, done, fail, keyword)
        } else if (action === "lyric") {
            doLyricFetch(baseUrl, item, done, fail, keyword)
        } else if (action === "fanyi") {
            doFanyiFetch(baseUrl, item, done, fail, keyword)
        } else if (action === "whois") {
            doWhoisFetch(baseUrl, item, done, fail, keyword)
        } else if (action === "qrcode") {
            doQrcodeFetch(baseUrl, item, done, fail, keyword)
        } else if (action === "hash") {
            doHashFetch(baseUrl, item, done, fail, keyword)
        } else if (action === "og") {
            doOgFetch(baseUrl, item, done, fail, keyword)
        } else if (action === "fuel") {
            doFuelFetch(baseUrl, item, done, fail, keyword)
        }
    }

    // ===== 顶栏 =====
    Rectangle {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 26
        color: "#0F172A"

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: "#1F2937"
        }

        Item {
            id: backBtn
            width: 54
            height: 18
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter

            property bool pressed: false
            scale: pressed ? 0.96 : 1.0
            opacity: pressed ? 0.88 : 1.0
            Behavior on scale { NumberAnimation { duration: 80 } }
            Behavior on opacity { NumberAnimation { duration: 80 } }

            Rectangle {
                anchors.fill: parent
                radius: 9
                color: backArea.pressed ? "#1F2937" : "#111827"
                border.width: 1
                border.color: "#243041"
            }

            Text {
                anchors.centerIn: parent
                text: "← 返回"
                font.pixelSize: 10
                color: "#E5E7EB"
                font.family: root.appFontFamily
            }

            MouseArea {
                id: backArea
                anchors.fill: parent
                anchors.margins: -8
                onPressed: backBtn.pressed = true
                onReleased: backBtn.pressed = false
                onCanceled: backBtn.pressed = false
                onClicked: handleBack()
            }
        }

        Text {
            anchors.centerIn: parent
            text: (currentPage === "home") ? "资讯速览" : currentTitle
            font.pixelSize: 11
            font.bold: true
            color: "#E5E7EB"
            font.family: root.appFontFamily
            elide: Text.ElideRight
            width: parent.width - 130
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            width: 7
            height: 7
            radius: 4
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            color: isLoading ? "#60A5FA" : "#334155"
            opacity: 0.95
        }
    }

    // ===== Home 页 =====
    Item {
        id: homePage
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        visible: currentPage === "home"

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#0B0F17" }
                GradientStop { position: 1.0; color: "#0B1220" }
            }
        }

        Flickable {
            id: cardFlick
            anchors.fill: parent
            anchors.margins: 10
            contentWidth: cardRow.width
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Row {
                id: cardRow
                spacing: 10
                height: parent.height
                visible: root.showHomeList
                opacity: root.showHomeList ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }

                Repeater {
                    id: cardRepeater
                    model: menuItems

                    Rectangle {
                        id: card
                        width: 132
                        height: parent.height
                        radius: 14
                        color: "#0F172A"
                        border.width: 1
                        border.color: "#1F2A3A"

                        Rectangle {
                            id: accentBar
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.leftMargin: 12
                            anchors.topMargin: 10
                            width: 52
                            height: 6
                            radius: 3
                            color: modelData.accent
                            opacity: 0.95
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 12
                            anchors.topMargin: 24
                            spacing: 6

                            Text {
                                text: modelData.icon
                                font.pixelSize: 24
                                color: "#FFFFFF"
                                font.family: root.appFontFamily
                            }

                            Text {
                                text: modelData.name
                                font.pixelSize: 12
                                font.bold: true
                                color: "#E5E7EB"
                                font.family: root.appFontFamily
                                wrapMode: Text.WordWrap
                            }

                            Item { height: 1; width: 1 }

                            Item {
                                id: openBtn
                                width: 44
                                height: 22
                                anchors.left: parent.left
                                anchors.topMargin: -4
                                property bool pressed: false
                                scale: pressed ? 0.96 : 1.0
                                opacity: pressed ? 0.88 : 1.0
                                Behavior on scale { NumberAnimation { duration: 80 } }
                                Behavior on opacity { NumberAnimation { duration: 80 } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: openArea.pressed ? "#1F2937" : "#111827"
                                    border.width: 1
                                    border.color: "#243041"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "打开"
                                    font.pixelSize: 11
                                    font.family: root.appFontFamily
                                    color: "#E5E7EB"
                                }

                                MouseArea {
                                    id: openArea
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    onPressed: openBtn.pressed = true
                                    onReleased: openBtn.pressed = false
                                    onCanceled: openBtn.pressed = false
                                    onClicked: fetchContent(modelData.endpoint)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ===== Content 页 =====
    Item {
        id: contentPage
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        visible: currentPage === "content"

        Rectangle {
            anchors.fill: parent
            color: "#0B0F17"
        }

        Text {
            id: errorText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 4
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            text: errorMessage
            visible: !isLoading && errorMessage !== ""
            font.pixelSize: 10
            color: "#FCA5A5"
            font.family: root.appFontFamily
            elide: Text.ElideRight
        }

        Flickable {
            id: contentFlickable
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: errorText.visible ? errorText.bottom : parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 10
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: contentColumn.height + 12

            Column {
                id: contentColumn
                width: parent.width
                y: 2
                spacing: 6

                Repeater {
                    model: isLoading ? [] : root.contentSegments

                    delegate: Column {
                        width: contentColumn.width
                        spacing: 2

                        Text {
                            visible: modelData.type === "text"
                            width: parent.width

                            textFormat: Text.MarkdownText
                            text: visible ? modelData.text : ""
                            wrapMode: Text.WordWrap

                            font.pixelSize: 13
                            color: "#E5E7EB"
                            font.family: root.appFontFamily

                            onLinkActivated: function(link) {
                                Qt.openUrlExternally(link)
                            }
                        }

                        Image {
                            visible: modelData.type === "image"
                            width: parent.width
                            height: {
                                if (!visible) return 0
                                if (status === Image.Ready && sourceSize.width > 0)
                                    return Math.min(sourceSize.height * (width / sourceSize.width), 400)
                                return 60
                            }
                            source: visible ? modelData.url : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true

                            Text {
                                anchors.centerIn: parent
                                visible: parent.status === Image.Loading
                                text: "图片加载中…"
                                font.pixelSize: 10
                                color: "#94A3B8"
                                font.family: root.appFontFamily
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: parent.status === Image.Error
                                text: "⚠ 图片加载失败"
                                font.pixelSize: 10
                                color: "#FCA5A5"
                                font.family: root.appFontFamily
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.openImageWithSystemViewer(modelData.url)
                            }
                        }

                        Text {
                            visible: modelData.type === "image"
                            text: "🔍 点击查看大图"
                            font.pixelSize: 9
                            color: "#60A5FA"
                            font.family: root.appFontFamily
                        }
                    }
                }
            }
        }
    }

    // ===== Loading 覆盖层 =====
    Rectangle {
        id: loadingOverlay
        anchors.fill: parent
        visible: isLoading
        color: Qt.rgba(0, 0, 0, 0.38)

        opacity: isLoading ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        Item {
            id: loadingPopup
            width: 130
            height: 54
            anchors.centerIn: parent

            scale: isLoading ? 1.0 : 0.92
            opacity: isLoading ? 1.0 : 0.0
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Rectangle {
                anchors.fill: parent
                radius: 14
                color: "#0F172A"
                border.width: 1
                border.color: "#223046"
            }

            Rectangle {
                anchors.fill: parent
                radius: 14
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)
            }

            Row {
                anchors.centerIn: parent
                spacing: 10

                Item {
                    width: 18
                    height: 18

                    Canvas {
                        id: spinner
                        anchors.fill: parent
                        antialiasing: true

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            var r = Math.min(width, height) / 2 - 2
                            var cx = width / 2
                            var cy = height / 2

                            ctx.beginPath()
                            ctx.strokeStyle = "#60A5FA"
                            ctx.lineWidth = 2
                            ctx.lineCap = "round"
                            ctx.arc(cx, cy, r, 0, Math.PI * 1.4, false)
                            ctx.stroke()
                        }

                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 700
                            loops: Animation.Infinite
                            running: isLoading
                        }
                    }

                    Connections {
                        target: root
                        function onIsLoadingChanged() {
                            if (isLoading) spinner.requestPaint()
                        }
                    }
                }

                Column {
                    spacing: 5
                    Text {
                        text: "加载中…"
                        font.pixelSize: 11
                        font.family: root.appFontFamily
                        color: "#E5E7EB"
                    }
                    Text {
                        text: "点按取消"
                        anchors.left: parent.left
                        anchors.leftMargin: -10
                        font.pixelSize: 9
                        font.family: root.appFontFamily
                        color: "#94A3B8"
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (httpRequest) httpRequest.abort()
                    httpRequest = null
                    isLoading = false
                    errorMessage = "已取消"
                }
                onPressed: loadingPopup.scale = 0.98
                onReleased: loadingPopup.scale = 1.0
                onCanceled: loadingPopup.scale = 1.0
            }
        }
    }

    // ===== 错误弹窗 =====
    Rectangle {
        id: errorPopup
        anchors.fill: parent
        visible: root.errorPopupVisible
        color: Qt.rgba(0, 0, 0, 0.45)
        z: 999

        MouseArea {
            anchors.fill: parent
            onClicked: root.errorPopupVisible = false
        }

        Item {
            width: 240
            height: 110
            anchors.centerIn: parent

            Rectangle {
                anchors.fill: parent
                radius: 14
                color: "#0F172A"
                border.width: 1
                border.color: "#223046"
            }

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Text {
                    text: "请求失败"
                    font.pixelSize: 12
                    font.bold: true
                    color: "#FCA5A5"
                    font.family: root.appFontFamily
                    elide: Text.ElideRight
                }

                Text {
                    text: root.errorPopupText
                    font.pixelSize: 11
                    color: "#E5E7EB"
                    font.family: root.appFontFamily
                    wrapMode: Text.WordWrap
                }

                Item { height: 1; width: 1 }

                Item {
                    id: okBtn
                    width: 60
                    height: 24
                    anchors.right: parent.right
                    property bool pressed: false
                    scale: pressed ? 0.96 : 1.0
                    opacity: pressed ? 0.88 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }
                    Behavior on opacity { NumberAnimation { duration: 80 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: okArea.pressed ? "#1F2937" : "#111827"
                        border.width: 1
                        border.color: "#243041"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "知道了"
                        font.pixelSize: 11
                        color: "#E5E7EB"
                        font.family: root.appFontFamily
                    }

                    MouseArea {
                        id: okArea
                        anchors.fill: parent
                        anchors.margins: -6
                        onPressed: okBtn.pressed = true
                        onReleased: okBtn.pressed = false
                        onCanceled: okBtn.pressed = false
                        onClicked: root.errorPopupVisible = false
                    }
                }
            }
        }
    }

    // ===== 兜底全屏图片预览（宿主未注入 imageViewer 时使用） =====
    Rectangle {
        id: imagePreviewOverlay
        anchors.fill: parent
        visible: root.imagePreviewVisible
        color: Qt.rgba(0, 0, 0, 0.9)
        z: 2000

        Image {
            anchors.fill: parent
            anchors.margins: 4
            source: root.previewImageUrl
            fillMode: Image.PreserveAspectFit
            asynchronous: true

            Text {
                anchors.centerIn: parent
                visible: parent.status === Image.Error
                text: "⚠ 图片加载失败"
                font.pixelSize: 11
                color: "#FCA5A5"
                font.family: root.appFontFamily
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            text: "点击任意处关闭"
            font.pixelSize: 9
            color: "#94A3B8"
            font.family: root.appFontFamily
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.imagePreviewVisible = false
                root.previewImageUrl = ""
            }
        }
    }

    // ===== 系统图片查看器弹出容器（参考 bili_plugin CommentsPage） =====
    Item {
        id: id_pop_container
        anchors.fill: parent
        z: 3000
        visible: popItemObject !== null
        property var popItemObject: null
        signal closeSameItem(string popStackId)

        function updateStackInfo() {
            if (id_pop_container.children.length > 1) {
                popItemObject = id_pop_container.children[id_pop_container.children.length - 2]
            } else {
                popItemObject = null
            }
        }

        function show(componentPath) {
            function initObj(obj) {
                if (!obj) return
                Object.defineProperty(obj, "popStackId", {
                    enumerable: false,
                    configurable: false,
                    writable: false,
                    value: componentPath
                })
                popItemObject = obj
                if (obj.backButtonClicked) {
                    obj.backButtonClicked.connect(function() {
                        closeSameItem(obj.popStackId)
                        updateStackInfo()
                        obj.destroy(1)
                    })
                }
                id_pop_container.closeSameItem.connect(function(popStackId) {
                    if (popStackId === obj.popStackId) obj.destroy(1)
                })
                if (obj.show) obj.show()
            }

            closeSameItem(componentPath)
            var comp = Qt.createComponent(componentPath)
            if (comp.status === Component.Ready) {
                var incubator = comp.incubateObject(id_pop_container)
                if (incubator.status !== Component.Ready) {
                    incubator.onStatusChanged = function(s) {
                        if (s === Component.Ready) initObj(incubator.object)
                    }
                } else {
                    initObj(incubator.object)
                }
            } else {
                console.error("Image viewer component error: " + comp.errorString())
                // 系统组件不可用时回退应用内预览
                if (root.previewImageUrl !== "")
                    root.imagePreviewVisible = true
            }
        }
    }

    Timer {
        interval: 300
        running: true
        repeat: false
        onTriggered: root.showHomeList = true
    }

    YPagePopHelper {
        id: pagePopHelper
        z: 9999
        property var containerItem: this

        function inputPageCreated(keyboardPage, initialText) {
            keyboardPage.backButtonClicked.connect(function() {
                qmlGlobal.inputPageShowing = false
                keyboardPage.todoDestroy()
                keyboardPage = null

                if (root.inputPending.active && root.inputPending.fail) {
                    var f = root.inputPending.fail
                    root.inputPending = ({ active: false, action: "", baseUrl: "", item: null, done: null, fail: null })
                    f("已取消输入")
                }
            })

            keyboardPage.inputFinished.connect(function(content) {
                qmlGlobal.inputPageShowing = false
                keyboardPage.todoDestroy()
                keyboardPage = null

                root.onInputFinished(content)
            })

            keyboardPage.enterText(initialText || "")
            keyboardPage.show()
            qmlGlobal.inputPageShowing = true
        }

        isShowing: qmlGlobal.inputPageShowing
        objectName: "from_NewsApp"
    }

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

    // ========= 用户自定义函数（全功能解锁） ==========

    // ── 1. 汇率 ──
    function getRate(baseUrl, item, done, fail) {
        var url = baseUrl + "?encoding=json"
        if (root.enableCacheBuster)
            url += "&" + root.cacheBusterKey + "=" + Date.now()

        var x = new XMLHttpRequest()
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status !== 200) {
                fail("自定义请求失败: HTTP " + x.status)
                return
            }
            var jsonData = null
            try {
                jsonData = JSON.parse(x.responseText || "{}")
            } catch (e) {
                fail("JSON 解析失败: " + e)
                return
            }
            var updatedDate = jsonData && jsonData.data ? jsonData.data.updated : ""
            var rates = (jsonData && jsonData.data && jsonData.data.rates) ? jsonData.data.rates : []
            var targetCurrencies = ["GBP", "JPY", "HKD", "USD", "EUR"]
            var targetRates = rates.filter(function(rate) {
                return targetCurrencies.indexOf(rate.currency) !== -1
            })
            var outputText = "日期：" + updatedDate + "\n\n"
            var cnyRate = rates.find(function(rate) { return rate.currency === "CNY" })
            if (cnyRate) {
                targetRates.forEach(function(rate) {
                    outputText += "- CNY -> " + rate.currency + "：**" + rate.rate + "**\n"
                })
            } else {
                outputText = "错误：未找到 CNY 汇率"
            }
            var md = "# " + (item.name || "汇率") + "\n\n" + outputText
            done(md)
        }
        x.onerror = function() { fail("自定义请求网络错误") }
        x.open("GET", url)
        x.send()
    }

    // ── 2. 天气预报 ──
    function getWeather(baseUrl, item, done, fail) {
        var city = encodeURIComponent("北京")
        var url = baseUrl + "?query=" + city + "&day=3&encoding=markdown"
        if (root.enableCacheBuster) {
            url += "&" + root.cacheBusterKey + "=" + Date.now()
        }
        var x = new XMLHttpRequest()
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status === 200) done(x.responseText || "")
            else fail("HTTP " + x.status)
        }
        x.onerror = function() { fail("网络错误") }
        x.open("GET", url)
        x.send()
    }

    // ── 3. 实时天气 ──
    function getWeatherRealTime(baseUrl, item, done, fail) {
        var city = encodeURIComponent("北京")
        var url = baseUrl + "?query=" + city + "&encoding=markdown"
        if (root.enableCacheBuster) {
            url += "&" + root.cacheBusterKey + "=" + Date.now()
        }
        var x = new XMLHttpRequest()
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status === 200) done(x.responseText || "")
            else fail("HTTP " + x.status)
        }
        x.onerror = function() { fail("网络错误") }
        x.open("GET", url)
        x.send()
    }

    // ── 4. 百度百科 ──
    function getBaike(baseUrl, item, done, fail) {
        root.inputPending = ({
            active: true,
            action: "baike",
            baseUrl: baseUrl,
            item: item,
            done: done,
            fail: fail
        })
        requestKeyboard("")
    }
    function doBaikeFetch(baseUrl, item, done, fail, keyword) {
        var encoded = encodeURIComponent(keyword)
        var url = baseUrl + "?word=" + encoded + "&encoding=markdown"
        if (root.enableCacheBuster)
            url += "&" + root.cacheBusterKey + "=" + Date.now()
        var x = new XMLHttpRequest()
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status === 200) {
                var text = x.responseText || ""
                if (text.length > root.maxContentLength) {
                    fail("内容过大，无法显示")
                    return
                }
                var md = "# " + (item && item.name ? item.name : "百度百科") + "\n\n" + text
                done(md)
            } else {
                fail("HTTP " + x.status)
            }
        }
        x.onerror = function() { fail("网络错误") }
        x.open("GET", url)
        x.send()
    }

    // ── 5. 汽油价格 ──
    function getFuelPrice(baseUrl, item, done, fail) {
        requestInput("fuel", baseUrl, item, done, fail, "")
    }
    function doFuelFetch(baseUrl, item, done, fail, keyword) {
        var url = baseUrl + "?encoding=json"
        if (keyword) url += "&region=" + encodeURIComponent(keyword)
        if (root.enableCacheBuster)
            url += "&" + root.cacheBusterKey + "=" + Date.now()
        var x = new XMLHttpRequest()
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status !== 200) { fail("HTTP " + x.status); return }
            var json = JSON.parse(x.responseText || "{}")
            var data = json.data || {}
            var region = data.region || "未知地区"
            var items = data.items || []
            var trend = data.trend || {}
            var updated = data.updated || ""
            var md = "# " + (item.name || "汽油价格") + "\n\n"
            md += "**地区：** " + region + "\n"
            md += "**更新时间：** " + updated + "\n\n"
            if (trend.description) md += "> 📢 " + trend.description + "\n\n"
            items.forEach(function(it) {
                md += "- **" + it.name + "**：" + it.price_desc + "\n"
            })
            done(md)
        }
        x.onerror = function() { fail("网络错误") }
        x.open("GET", url)
        x.send()
    }

    // ── 6. 歌词搜索 ──
    function getLyric(baseUrl, item, done, fail) {
        requestInput("lyric", baseUrl, item, done, fail, "")
    }
    function doLyricFetch(baseUrl, item, done, fail, keyword) {
        var url = baseUrl + "?query=" + encodeURIComponent(keyword) + "&encoding=json"
        if (root.enableCacheBuster)
            url += "&" + root.cacheBusterKey + "=" + Date.now()
        var x = new XMLHttpRequest()
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status !== 200) { fail("HTTP " + x.status); return }
            var json = JSON.parse(x.responseText || "{}")
            var data = json.data || {}
            var title = data.title || "未知"
            var artists = data.artists || []
            var album = data.album || ""
            var formatted = data.formatted || ""
            var md = "# " + title + "\n\n"
            md += "**歌手：** " + artists.join(", ") + "\n"
            md += "**专辑：** " + album + "\n\n"
            md += "---\n\n"
            md += formatted
            done(md)
        }
        x.onerror = function() { fail("网络错误") }
        x.open("GET", url)
        x.send()
    }

    // ── 7. 在线翻译 ──
    function getFanyi(baseUrl, item, done, fail) {
        requestInput("fanyi", baseUrl, item, done, fail, "")
    }
    function doFanyiFetch(baseUrl, item, done, fail, keyword) {
        var url = baseUrl + "?text=" + encodeURIComponent(keyword) + "&from=auto&to=auto&encoding=json"
        if (root.enableCacheBuster)
            url += "&" + root.cacheBusterKey + "=" + Date.now()
        var x = new XMLHttpRequest()
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status !== 200) { fail("HTTP " + x.status); return }
            var json = JSON.parse(x.responseText || "{}")
            var data = json.data || {}
            var source = data.source || {}
            var target = data.target || {}
            var md = "# 在线翻译\n\n"
            md += "**原文（" + (source.type_desc || source.type || "auto") + "）：**\n"
            md += source.text + "\n\n"
            if (source.pronounce) md += "*读音：" + source.pronounce + "*\n\n"
            md += "---\n\n"
            md += "**译文（" + (target.type_desc || target.type || "auto") + "）：**\n"
            md += target.text + "\n\n"
            if (target.pronounce) md += "*读音：" + target.pronounce + "*\n\n"
            done(md)
        }
        x.onerror = function() { fail("网络错误") }
        x.open("GET", url)
        x.send()
    }

    // ── 8. 生成二维码 ──
    function getQrcode(baseUrl, item, done, fail) {
        requestInput("qrcode", baseUrl, item, done, fail, "")
    }
    function doQrcodeFetch(baseUrl, item, done, fail, keyword) {
        var url = baseUrl + "?text=" + encodeURIComponent(keyword) + "&size=256&encoding=json"
        if (root.enableCacheBuster)
            url += "&" + root.cacheBusterKey + "=" + Date.now()
        var x = new XMLHttpRequest()
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status !== 200) { fail("HTTP " + x.status); return }
            var json = JSON.parse(x.responseText || "{}")
            var data = json.data || {}
            var dataUri = data.data_uri || ""
            var text = data.text || ""
            var md = "# 二维码\n\n"
            md += "**内容：** " + text + "\n\n"
            if (dataUri) md += "![二维码](" + dataUri + ")\n\n"
            done(md)
        }
        x.onerror = function() { fail("网络错误") }
        x.open("GET", url)
        x.send()
    }

    // ── 9. Whois 查询 ──
    function getWhois(baseUrl, item, done, fail) {
        requestInput("whois", baseUrl, item, done, fail, "")
    }
    function doWhoisFetch(baseUrl, item, done, fail, keyword) {
        var url = baseUrl + "?domain=" + encodeURIComponent(keyword) + "&encoding=json"
        if (root.enableCacheBuster)
            url += "&" + root.cacheBusterKey + "=" + Date.now()
        var x = new XMLHttpRequest()
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status !== 200) { fail("HTTP " + x.status); return }
            var json = JSON.parse(x.responseText || "{}")
            var data = json.data || {}
            var md = "# Whois 查询\n\n"
            md += "**域名：** " + (data.domain || keyword) + "\n"
            md += "**注册商：** " + (data.registrar || "-") + "\n"
            md += "**创建时间：** " + (data.created || "-") + "\n"
            md += "**过期时间：** " + (data.expires || "-") + "\n"
            md += "**更新时间：** " + (data.updated || "-") + "\n"
            md += "**DNSSEC：** " + (data.dnssec || "-") + "\n\n"
            var ns = data.nameservers || []
            if (ns.length > 0) {
                md += "**NS 服务器：**\n"
                ns.forEach(function(n) { md += "- " + n + "\n" })
                md += "\n"
            }
            var reg = data.registrant || {}
            if (reg.name || reg.organization) {
                md += "**注册人信息：**\n"
                if (reg.name) md += "- 名称：" + reg.name + "\n"
                if (reg.organization) md += "- 组织：" + reg.organization + "\n"
                if (reg.country) md += "- 国家：" + reg.country + "\n"
                md += "\n"
            }
            var status = data.status || []
            if (status.length > 0) {
                md += "**状态：**\n"
                status.forEach(function(s) { md += "- " + s + "\n" })
            }
            done(md)
        }
        x.onerror = function() { fail("网络错误") }
        x.open("GET", url)
        x.send()
    }

    // ── 10. 公网 IP ──
    function getIp(baseUrl, item, done, fail) {
        var url = baseUrl + "?encoding=json"
        if (root.enableCacheBuster)
            url += "&" + root.cacheBusterKey + "=" + Date.now()
        var x = new XMLHttpRequest()
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status !== 200) { fail("HTTP " + x.status); return }
            var json = JSON.parse(x.responseText || "{}")
            var data = json.data || {}
            var md = "# 公网 IP 地址\n\n"
            var keys = Object.keys(data)
            keys.forEach(function(k) {
                md += "- **" + k + "**：" + data[k] + "\n"
            })
            done(md)
        }
        x.onerror = function() { fail("网络错误") }
        x.open("GET", url)
        x.send()
    }

    // ── 11. 哈希计算 ──
    function getHash(baseUrl, item, done, fail) {
        requestInput("hash", baseUrl, item, done, fail, "")
    }
    function doHashFetch(baseUrl, item, done, fail, keyword) {
        var url = baseUrl + "?content=" + encodeURIComponent(keyword) + "&encoding=json"
        if (root.enableCacheBuster)
            url += "&" + root.cacheBusterKey + "=" + Date.now()
        var x = new XMLHttpRequest()
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status !== 200) { fail("HTTP " + x.status); return }
            var json = JSON.parse(x.responseText || "{}")
            var data = json.data || {}
            var md = "# 哈希计算\n\n"
            md += "**原文：** " + (data.source || keyword) + "\n\n"
            md += "**MD5：**\n```\n" + (data.md5 || "-") + "\n```\n\n"
            var sha = data.sha || {}
            md += "**SHA1：**\n```\n" + (sha.sha1 || "-") + "\n```\n\n"
            md += "**SHA256：**\n```\n" + (sha.sha256 || "-") + "\n```\n\n"
            md += "**SHA512：**\n```\n" + (sha.sha512 || "-") + "\n```\n\n"
            var b64 = data.base64 || {}
            md += "**Base64 编码：**\n```\n" + (b64.encoded || "-") + "\n```\n\n"
            var urlenc = data.url || {}
            md += "**URL 编码：**\n```\n" + (urlenc.encoded || "-") + "\n```\n\n"
            done(md)
        }
        x.onerror = function() { fail("网络错误") }
        x.open("GET", url)
        x.send()
    }

    // ── 12. 密码生成 ──
    function getPassword(baseUrl, item, done, fail) {
        var url = baseUrl + "?length=16&numbers=true&lowercase=true&uppercase=true&symbols=true&encoding=json"
        if (root.enableCacheBuster)
            url += "&" + root.cacheBusterKey + "=" + Date.now()
        var x = new XMLHttpRequest()
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status !== 200) { fail("HTTP " + x.status); return }
            var json = JSON.parse(x.responseText || "{}")
            var data = json.data || {}
            var md = "# 密码生成器\n\n"
            md += "**密码：**\n```\n" + (data.password || "-") + "\n```\n\n"
            md += "**长度：** " + (data.length || "-") + "\n"
            var info = data.generation_info || {}
            md += "**强度：** " + (info.strength || "-") + "\n"
            md += "**熵：** " + (info.entropy || "-") + "\n"
            md += "**破解时间：** " + (info.time_to_crack || "-") + "\n\n"
            var cfg = data.config || {}
            md += "**配置：**\n"
            md += "- 数字：" + (cfg.include_numbers ? "✅" : "❌") + "\n"
            md += "- 小写：" + (cfg.include_lowercase ? "✅" : "❌") + "\n"
            md += "- 大写：" + (cfg.include_uppercase ? "✅" : "❌") + "\n"
            md += "- 符号：" + (cfg.include_symbols ? "✅" : "❌") + "\n"
            done(md)
        }
        x.onerror = function() { fail("网络错误") }
        x.open("GET", url)
        x.send()
    }

    // ── 14. HackerNews ──
    function getHackerNews(baseUrl, item, done, fail) {
        var url = baseUrl + "?encoding=json"
        if (root.enableCacheBuster)
            url += "&" + root.cacheBusterKey + "=" + Date.now()
        var x = new XMLHttpRequest()
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status !== 200) { fail("HTTP " + x.status); return }
            var json = JSON.parse(x.responseText || "{}")
            var data = json.data || []
            var md = "# Hacker News 热帖\n\n"
            data.forEach(function(post, idx) {
                md += (idx + 1) + ". [**" + post.title + "**](" + post.link + ")\n"
                md += "   👤 " + (post.author || "-") + "  |  ⭐ " + (post.score || 0) + "  |  🕐 " + (post.created || "-") + "\n\n"
            })
            done(md)
        }
        x.onerror = function() { fail("网络错误") }
        x.open("GET", url)
        x.send()
    }

    // ── 15. 猫眼实时票房 ──
    function getMaoyan(baseUrl, item, done, fail) {
        var url = baseUrl + "?encoding=json"
        if (root.enableCacheBuster)
            url += "&" + root.cacheBusterKey + "=" + Date.now()
        var x = new XMLHttpRequest()
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status !== 200) { fail("HTTP " + x.status); return }
            var json = JSON.parse(x.responseText || "{}")
            var data = json.data || {}
            var list = data.list || []
            var md = "# " + (data.title || "猫眼实时票房") + "\n\n"
            md += "**大盘：** " + (data.box_office || "-") + (data.box_office_unit || "") + "\n"
            md += "**场次：** " + (data.show_count_desc || "-") + "  |  **人次：** " + (data.view_count_desc || "-") + "\n"
            md += "**更新时间：** " + (data.updated || "-") + "\n\n"
            md += "| 排名 | 影片 | 上映信息 | 实时票房 | 占比 | 累计票房 |\n"
            md += "|:---|:---|:---|:---|:---|:---|\n"
            list.forEach(function(m, idx) {
                md += "| " + (idx + 1) + " | " + m.movie_name + " | " + m.release_info + " | " + m.box_office_desc + " | " + m.box_office_rate + " | " + m.sum_box_desc + " |\n"
            })
            done(md)
        }
        x.onerror = function() { fail("网络错误") }
        x.open("GET", url)
        x.send()
    }

    // ── 16. 网易云榜单列表 ──
    function getNcmRank(baseUrl, item, done, fail) {
        var url = baseUrl + "?encoding=json"
        if (root.enableCacheBuster)
            url += "&" + root.cacheBusterKey + "=" + Date.now()
        var x = new XMLHttpRequest()
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status !== 200) { fail("HTTP " + x.status); return }
            var json = JSON.parse(x.responseText || "{}")
            var data = json.data || []
            var md = "# 网易云音乐榜单\n\n"
            data.forEach(function(rank, idx) {
                md += (idx + 1) + ". **" + rank.name + "**\n"
                if (rank.description) md += "   > " + rank.description + "\n"
                md += "   🔄 " + (rank.update_frequency || "-") + "  |  🕐 " + (rank.updated || "-") + "\n"
                if (rank.cover) md += "   ![封面](" + rank.cover + ")\n"
                md += "\n"
            })
            done(md)
        }
        x.onerror = function() { fail("网络错误") }
        x.open("GET", url)
        x.send()
    }

    // ── 13. 链接 OG 信息 ──
    function getOg(baseUrl, item, done, fail) {
        requestInput("og", baseUrl, item, done, fail, "https://")
    }
    function doOgFetch(baseUrl, item, done, fail, keyword) {
        var url = baseUrl
        if (root.enableCacheBuster)
            url += "?" + root.cacheBusterKey + "=" + Date.now()
        var x = new XMLHttpRequest()
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status !== 200) { fail("HTTP " + x.status); return }
            var json = JSON.parse(x.responseText || "{}")
            var data = json.data || {}
            var md = "# 链接 OG 信息\n\n"
            md += "**URL：** " + (data.url || keyword) + "\n"
            md += "**标题：** " + (data.title || "-") + "\n"
            md += "**描述：** " + (data.description || "-") + "\n"
            md += "**图片：** " + (data.image || "-") + "\n"
            if (data.site_name) md += "**站点：** " + data.site_name + "\n"
            if (data.type) md += "**类型：** " + data.type + "\n"
            done(md)
        }
        x.onerror = function() { fail("网络错误") }
        x.open("POST", url)
        x.setRequestHeader("Content-Type", "application/json")
        x.send(JSON.stringify({url: keyword}))
    }

    // ── 17. B站热搜（主站故障时回退社区镜像） ──
    // 上游 /v2/bili 在官方实例上 500（B站已对爬虫返回 HTML），
    // 社区镜像 60s.7se.cn 的同名接口目前可用，失败时自动回退。
    function getBili(baseUrl, item, done, fail) {
        var mirrorUrl = "https://60s.7se.cn/v2/bili?encoding=json"
        var primaryUrl = baseUrl + "?encoding=json"
        if (root.enableCacheBuster) {
            primaryUrl += "&" + root.cacheBusterKey + "=" + Date.now()
            mirrorUrl += "&" + root.cacheBusterKey + "=" + Date.now()
        }

        function tryParse(text) {
            try {
                var json = JSON.parse(text || "{}")
                if (json.code === 200 && json.data && json.data.length > 0)
                    return json.data
            } catch (e) {}
            return null
        }

        function buildMd(list) {
            var md = "# " + (item.name || "B站热搜") + "\n\n"
            list.slice(0, 20).forEach(function(e, idx) {
                var link = e.link || ("https://search.bilibili.com/all?keyword=" + encodeURIComponent(e.title))
                md += (idx + 1) + ". [" + e.title + "](" + link + ")"
                if (e.heat_desc) md += " `" + e.heat_desc + "`"
                md += "\n"
            })
            return md
        }

        function request(url, onOk, onFail) {
            var x = new XMLHttpRequest()
            x.onreadystatechange = function() {
                if (x.readyState !== XMLHttpRequest.DONE) return
                if (x.status !== 200) { onFail(); return }
                var list = tryParse(x.responseText)
                if (list) onOk(list)
                else onFail()
            }
            x.onerror = function() { onFail() }
            x.open("GET", url)
            x.send()
        }

        request(primaryUrl, function(list) {
            done(buildMd(list))
        }, function() {
            request(mirrorUrl, function(list) {
                done(buildMd(list))
            }, function() {
                fail("B站热搜接口暂不可用")
            })
        })
    }

    // ── 18. 懂车帝热搜（60s 接口已空，直连懂车帝官方接口） ──
    // 上游 /v2/dongchedi 抓取的页面已失效，所有镜像均返回空数组；
    // 懂车帝官方搜索热榜接口实测可用，QML 的 XHR 无 CORS 限制，直接请求。
    function getDongchedi(baseUrl, item, done, fail) {
        var apiUrl = "https://www.dongchedi.com/motor/searchpage/launcher/main/v1/?aid=1839&app_name=auto_web_pc"
        if (root.enableCacheBuster)
            apiUrl += "&" + root.cacheBusterKey + "=" + Date.now()

        function buildMd(list) {
            var md = "# " + (item.name || "懂车帝热搜") + "\n\n"
            list.slice(0, 20).forEach(function(e, idx) {
                var link = "https://www.dongchedi.com/search?keyword=" + encodeURIComponent(e.title)
                md += (idx + 1) + ". [" + e.title + "](" + link + ")\n"
            })
            return md
        }

        function fallbackTo60s() {
            var url = baseUrl + "?encoding=json"
            if (root.enableCacheBuster)
                url += "&" + root.cacheBusterKey + "=" + Date.now()
            var x = new XMLHttpRequest()
            x.onreadystatechange = function() {
                if (x.readyState !== XMLHttpRequest.DONE) return
                if (x.status !== 200) { fail("懂车帝热搜暂无数据"); return }
                try {
                    var json = JSON.parse(x.responseText || "{}")
                    var list = json.data || []
                    if (list.length > 0) {
                        var md = "# " + (item.name || "懂车帝热搜") + "\n\n"
                        list.slice(0, 20).forEach(function(e, idx) {
                            md += (idx + 1) + ". [" + e.title + "](" + (e.url || "") + ")"
                            if (e.score_desc) md += " `" + e.score_desc + "`"
                            md += "\n"
                        })
                        done(md)
                    } else {
                        fail("懂车帝热搜暂无数据")
                    }
                } catch (e) {
                    fail("JSON 解析失败: " + e)
                }
            }
            x.onerror = function() { fail("网络错误") }
            x.open("GET", url)
            x.send()
        }

        var x = new XMLHttpRequest()
        x.onreadystatechange = function() {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status !== 200) { fallbackTo60s(); return }
            try {
                var json = JSON.parse(x.responseText || "{}")
                var boards = (json.data && json.data.rank_board) ? json.data.rank_board : []
                var tops = []
                for (var i = 0; i < boards.length; i++) {
                    if (boards[i].rank_name === "热搜榜" && boards[i].tops && boards[i].tops.length > 0) {
                        tops = boards[i].tops
                        break
                    }
                }
                if (tops.length === 0 && boards.length > 0 && boards[0].tops)
                    tops = boards[0].tops
                if (tops.length > 0) done(buildMd(tops))
                else fallbackTo60s()
            } catch (e) {
                fallbackTo60s()
            }
        }
        x.onerror = function() { fallbackTo60s() }
        x.open("GET", apiUrl)
        x.send()
    }
}
