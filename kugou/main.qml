import QtQuick 2.15
import "qrc:/qml/commons"

Rectangle {
    id: root
    width: 320
    height: 170
    color: "#f5f5f5"

    signal backButtonClicked()

    // ---------- 配置 ----------
    readonly property string apiBase: "http://127.0.0.1:3000"
    property string guestCookie: ""
    property string token: ""
    property string userId: ""
    property string dfid: ""
    property bool hasCookie: false
    property var songModel: ListModel {}
    property var detailSong: null
    property bool isSearching: false
    property bool isDownloading: false
    property string downloadDir: "/userdisk/Music/酷狗概念版"
    property string cookieJsonPath: downloadDir + "/cookie.json"
    property string historyJsonPath: downloadDir + "/history.json"
    property bool inputPageShowing: false
    property var searchHistory: []
    property int currentTotal: 0
    property string statusMessage: ""

    property var songCache: ({})
    readonly property string backendLogFile: "/tmp/kugou_api_startup.log"

    property var commandQueue: []
    property var currentCallback: null
    property bool cmdExecuting: false

    // ---------- 命令执行 ----------
    function runCommand(cmd, callback) {
        commandQueue.push({ cmd: cmd, cb: callback });
        if (!cmdExecuting) executeNext();
    }

    function executeNext() {
        if (commandQueue.length === 0) {
            cmdExecuting = false;
            return;
        }
        cmdExecuting = true;
        var item = commandQueue.shift();
        currentCallback = item.cb;

        if (typeof shell === 'undefined' || !shell) {
            console.error("[Shell Error] 全局 shell 对象不可用，命令:", item.cmd);
            if (currentCallback) currentCallback();
            currentCallback = null;
            executeNext();
            return;
        }

        console.log("[Shell Exec] ", item.cmd);
        shell.execAsync(item.cmd, function(result) {
            console.log("[Shell Result] ", JSON.stringify(result));
            if (result.error) console.warn("[Shell Warn] 命令出错:", result.error);
            if (currentCallback) {
                currentCallback();
                currentCallback = null;
            }
            executeNext();
        });
    }

    function sendCommand(cmd) {
        if (typeof shell !== 'undefined' && shell) {
            console.log("[Shell Send] ", cmd);
            shell.execAsync(cmd, function(result) {
                console.log("[Shell Send Result] ", JSON.stringify(result));
                if (result.error) console.warn("[Shell Send Warn] 出错:", result.error);
            });
        } else {
            console.warn("[Shell Error] 不可用，无法执行:", cmd);
        }
    }

    // ---------- 通用 JSON 文件读取 ----------
    function readJsonFile(filePath, callback) {
        console.log("[JsonFile] 读取文件: " + filePath);
        var cmd = "cat \"" + filePath + "\"";
        if (typeof shell !== 'undefined' && shell) {
            shell.execAsync(cmd, function(result) {
                if (result.exitCode === 0 && result.stdout) {
                    try {
                        var data = JSON.parse(result.stdout.trim());
                        callback(data);
                    } catch(e) {
                        console.warn("[JsonFile] 解析失败: " + filePath);
                        callback(null);
                    }
                } else {
                    console.warn("[JsonFile] 文件不存在或为空: " + filePath);
                    callback(null);
                }
            });
        } else {
            console.error("[JsonFile] shell不可用");
            callback(null);
        }
    }

    function readCookieJson(callback) {
        readJsonFile(cookieJsonPath, function(data) {
            if (data) {
                guestCookie = data.cookie || "";
                token = data.token || "";
                userId = data.userId || "";
                dfid = data.dfid || "";
                hasCookie = !!guestCookie;
                console.log("[CookieJson] 读取成功");
            } else {
                console.warn("[CookieJson] 使用空凭证");
            }
            if (callback) callback();
        });
    }

    function readHistoryJson(callback) {
        readJsonFile(historyJsonPath, function(data) {
            if (data && Array.isArray(data)) {
                searchHistory = data;
                console.log("[HistoryJson] 读取成功");
            } else {
                console.warn("[HistoryJson] 使用空历史");
                searchHistory = [];
            }
            if (callback) callback();
        });
    }

    function saveCookieJson() {
        var obj = { token: token, userId: userId, dfid: dfid, cookie: guestCookie };
        var jsonStr = JSON.stringify(obj);
        var cmd = "cat > \"" + cookieJsonPath + "\" << 'EOF'\n" + jsonStr + "\nEOF";
        console.log("[CookieJson] 保存凭证");
        runCommand(cmd);
    }

    function saveHistoryJson() {
        var jsonStr = JSON.stringify(searchHistory);
        var cmd = "cat > \"" + historyJsonPath + "\" << 'EOF'\n" + jsonStr + "\nEOF";
        console.log("[HistoryJson] 保存历史记录");
        runCommand(cmd);
    }

    function addHistory(keyword) {
        if (!keyword.trim()) return;
        var arr = searchHistory;
        arr = arr.filter(function(item) { return item !== keyword; });
        arr.unshift(keyword);
        if (arr.length > 10) arr = arr.slice(0, 10);
        searchHistory = arr;
        saveHistoryJson();
    }

    function removeHistory(keyword) {
        var arr = searchHistory;
        arr = arr.filter(function(item) { return item !== keyword; });
        searchHistory = arr;
        saveHistoryJson();
    }

    // ---------- 标题栏、错误弹窗 ----------
    StatusBar {
        id: statusBar
        anchors.top: parent.top
        statusText: root.statusMessage
    }

    ErrorDialog {
        id: errorDialog
        anchors.centerIn: parent
    }

    function showError(msg) {
        console.error("[Error] ", msg);
        errorDialog.errorText = msg;
        errorDialog.visible = true;
    }

    // 公共按钮样式
    Component {
        id: buttonStyle
        Rectangle {
            width: 45
            height: 28
            radius: 4
            color: btnMouse.pressed ? "#cccccc" : "#ffffff"
            border.color: "#aaaaaa"
            border.width: 1
            property alias text: btnText.text
            signal clicked()
            MouseArea {
                id: btnMouse
                anchors.fill: parent
                onClicked: parent.clicked()
            }
            Text {
                id: btnText
                anchors.centerIn: parent
                color: "#333"
                font.family: "Microsoft YaHei"
                font.pixelSize: 16
            }
        }
    }

    // ---------- 状态页 ----------
    state: "list"
    states: [
        State { name: "login" },
        State { name: "list" },
        State { name: "detail" },
        State { name: "mypage" },
        State { name: "settings" }
    ]

    Loader {
        id: loginLoader
        anchors.fill: parent
        visible: root.state === "login"
        source: "LoginPage.qml"
        onLoaded: {
            loginLoader.item.apiBase = root.apiBase;
            loginLoader.item.loginSuccess.connect(function(cookie, tkn, uid) {
                root.guestCookie = cookie;
                root.token = tkn;
                root.userId = uid;
                root.hasCookie = true;
                saveCookieJson();
                registerDev(function() {
                    root.state = "list";
                });
            });
        }
    }

    Loader {
        id: myPageLoader
        anchors.fill: parent
        visible: root.state === "mypage"
        source: "MyPage.qml"
    }

    Loader {
        id: settingsLoader
        anchors.fill: parent
        visible: root.state === "settings"
        source: "Settings.qml"
    }

    // ---------- 列表页 ----------
    Item {
        id: listPage
        anchors.top: statusBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.state === "list"

        Rectangle {
            id: searchArea
            height: 40
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            color: "#eeeeee"

            Row {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                Loader {
                    sourceComponent: buttonStyle
                    anchors.verticalCenter: parent.verticalCenter
                    onLoaded: {
                        item.text = "关闭";
                        item.clicked.connect(function() { root.backButtonClicked(); });
                    }
                }

                Rectangle {
                    width: parent.width - 3 * 45 - 3 * 4
                    height: 28
                    radius: 4
                    color: "#ffffff"
                    border.color: "#cccccc"
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        verticalAlignment: TextInput.AlignVCenter
                        color: "#333"
                        font.family: "Monospace"
                        font.pixelSize: 14
                        focus: true
                        onAccepted: searchButton.item.clicked()
                        MouseArea {
                            anchors.fill: parent
                            onClicked: requestKeyboard()
                        }
                    }
                    TextInput {
                        id: hiddenSearchInput
                        visible: false
                        onTextChanged: searchInput.text = text
                    }
                }

                Loader {
                    id: searchButton
                    sourceComponent: buttonStyle
                    anchors.verticalCenter: parent.verticalCenter
                    onLoaded: {
                        item.text = "搜索";
                        item.clicked.connect(function() {
                            var keyword = searchInput.text.trim();
                            if (keyword !== "" && !isSearching)
                                searchSongs(keyword);
                        });
                    }
                }

                Loader {
                    id: myButton
                    sourceComponent: buttonStyle
                    anchors.verticalCenter: parent.verticalCenter
                    onLoaded: {
                        item.text = "我的";
                        item.clicked.connect(function() {
                            root.state = "mypage";
                        });
                    }
                }
            }
        }

        Item {
            anchors.top: parent.top
            anchors.bottom: searchArea.top
            anchors.left: parent.left
            anchors.right: parent.right
            clip: true

            ListView {
                id: historyView
                anchors.fill: parent
                anchors.margins: 4
                model: searchHistory
                visible: songModel.count === 0 && !isSearching
                delegate: Rectangle {
                    width: historyView.width
                    height: 30
                    color: "#f0f0f0"
                    border.color: "#e0e0e0"
                    border.width: 1
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        color: "#333"
                        font.pixelSize: 15
                        font.family: "Microsoft YaHei"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            searchInput.text = modelData;
                            searchSongs(modelData);
                        }
                        onPressAndHold: {
                            root.removeHistory(modelData);
                        }
                    }
                }
            }

            ListView {
                id: listView
                anchors.fill: parent
                anchors.margins: 4
                model: songModel
                delegate: songDelegate
                spacing: 2
                visible: songModel.count > 0 || isSearching
                onCountChanged: {
                    if (count > 0) positionViewAtIndex(0, ListView.Beginning);
                }
            }

            Text {
                anchors.centerIn: parent
                text: {
                    if (isSearching) return "搜索中...";
                    if (songModel.count === 0 && searchHistory.length === 0) return "请输入关键词搜索";
                    return "";
                }
                color: "#999"
                font.pixelSize: 14
                font.family: "Microsoft YaHei"
                visible: !isSearching && songModel.count === 0 && searchHistory.length === 0
            }
        }

        Component {
            id: songDelegate
            Rectangle {
                width: listView.width
                height: 44
                color: index % 2 === 0 ? "#ffffff" : "#f0f0f0"
                radius: 2
                border.color: "#e0e0e0"
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 6

                    Column {
                        width: parent.width - 40 - 6
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            text: name
                            color: vip ? "#cc7b00" : "#333"
                            font.pixelSize: 14
                            font.family: "Microsoft YaHei"
                            elide: Text.ElideRight
                        }

                        Item {
                            width: parent.width
                            height: artistLabel.height
                            Text {
                                id: artistLabel
                                text: artists
                                color: "#666"
                                font.pixelSize: 12
                                font.family: "Microsoft YaHei"
                                elide: Text.ElideRight
                                anchors.left: parent.left
                                anchors.right: durationLabel.left
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                id: durationLabel
                                text: formatDuration(duration)
                                color: "#666"
                                font.pixelSize: 12
                                font.family: "Microsoft YaHei"
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Image {
                        width: 40
                        height: 40
                        anchors.verticalCenter: parent.verticalCenter
                        source: picUrl || ""
                        fillMode: Image.PreserveAspectCrop
                        clip: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: fetchSongDetail(model.id)
                }
            }
        }
    }

    // ---------- 详情页 ----------
    DetailPage {
        id: detailPage
        anchors.top: statusBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.state === "detail"
        detailSong: root.detailSong
    }

    // ---------- 键盘 ----------
    function requestKeyboard() {
        var component = qmlCreateComponent("YInputPage");
        if (component.status === Component.Ready) {
            var incubator = component.incubateObject(id_page_pop_helper.containerItem);
            if (incubator.status !== Component.Ready) {
                incubator.onStatusChanged = function(status) {
                    if (status === Component.Ready)
                        id_page_pop_helper.inputPageCreated(incubator.object);
                };
            } else {
                id_page_pop_helper.inputPageCreated(incubator.object);
            }
        } else if (component.status === Component.Error) {
            console.error("[Keyboard] 加载YInputPage失败:", component.errorString());
            showError("无法打开键盘");
        } else {
            component.statusChanged.connect(function() {
                if (component.status === Component.Ready) {
                    var incubator = component.incubateObject(id_page_pop_helper.containerItem);
                    if (incubator.status !== Component.Ready) {
                        incubator.onStatusChanged = function(status) {
                            if (status === Component.Ready)
                                id_page_pop_helper.inputPageCreated(incubator.object);
                        };
                    } else {
                        id_page_pop_helper.inputPageCreated(incubator.object);
                    }
                } else if (component.status === Component.Error) {
                    console.error("[Keyboard] 加载YInputPage失败:", component.errorString());
                    showError("无法打开键盘");
                }
            });
        }
    }

    YPagePopHelper {
        id: id_page_pop_helper
        z: 99
        function inputPageCreated(keyboardPage) {
            keyboardPage.backButtonClicked.connect(function() {
                inputPageShowing = false;
                keyboardPage.todoDestroy();
                keyboardPage = null;
            });

            keyboardPage.inputFinished.connect(function(content) {
                hiddenSearchInput.text = content.trim();
                inputPageShowing = false;
                keyboardPage.todoDestroy();
            });

            keyboardPage.enterText(searchInput.text);
            keyboardPage.show();
            inputPageShowing = true;
        }
        isShowing: inputPageShowing
        objectName: "from_NeteasePlugin.qml"
    }

    // ---------- 工具函数 ----------
    function formatDuration(ms) {
        if (!ms) return "";
        var totalSec = Math.floor(ms / 1000);
        var min = Math.floor(totalSec / 60);
        var sec = totalSec % 60;
        return min + ":" + (sec < 10 ? "0" + sec : sec);
    }

    function safeFileName(name) {
        return name.replace(/[<>:"/\\|?*]/g, '_');
    }

    function buildCookieParam() {
        var parts = [];
        if (token) parts.push("token=" + token);
        if (userId) parts.push("userid=" + userId);
        if (dfid) parts.push("dfid=" + dfid);
        return parts.join(";");
    }

    // ---------- API 请求 ----------
    function apiRequest(endpoint, params, callback, addCookie = true) {
        var url = apiBase + endpoint + "?";
        for (var key in params) {
            if (params[key] !== undefined)
                url += encodeURIComponent(key) + "=" + encodeURIComponent(params[key]) + "&";
        }
        if (addCookie && hasCookie) {
            url += "cookie=" + encodeURIComponent(buildCookieParam());
        }

        console.log("[API Request] " + endpoint);
        console.log("[API Request URL] " + url);

        var xhr = new XMLHttpRequest();
        xhr.open("GET", url);

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var status = xhr.status;
                console.log("[API Response] Status: " + status);
                console.log("[API Response] Body: " + xhr.responseText);

                if (status === 200) {
                    try {
                        var resp = JSON.parse(xhr.responseText);
                        var isError = false;
                        var errMsg = "";
                        var apiCode = 0;
                        if (resp.hasOwnProperty("error_code") && resp.error_code !== undefined) {
                            apiCode = resp.error_code;
                            if (resp.error_code !== 0) {
                                isError = true;
                                errMsg = "错误码:" + resp.error_code;
                                if (resp.error_msg) errMsg += " " + resp.error_msg;
                                else if (resp.message) errMsg += " " + resp.message;
                            }
                        } else if (resp.hasOwnProperty("code") && resp.code !== undefined) {
                            apiCode = resp.code;
                            if (resp.code !== 200) {
                                isError = true;
                                errMsg = "code:" + resp.code;
                                if (resp.message) errMsg += " " + resp.message;
                            }
                        }
                        if (isError) {
                            console.warn("[API] 业务错误: " + errMsg);
                            callback({ error: errMsg, statusCode: status, apiCode: apiCode });
                        } else {
                            callback(resp);
                        }
                    } catch (e) {
                        console.error("[API] JSON解析失败: " + e.message);
                        callback({ error: "解析响应失败: " + e.message, statusCode: status });
                    }
                } else {
                    console.warn("[API] HTTP错误: " + status + " " + xhr.statusText);
                    callback({ error: "HTTP " + status + " (" + xhr.statusText + ")", statusCode: status });
                }
            }
        };
        xhr.send();
    }

    // ---------- 设备注册 ----------
    function registerDev(callback) {
        if (dfid) {
            console.log("[RegisterDev] dfid 已存在，跳过注册");
            if (callback) callback();
            return;
        }
        console.log("[RegisterDev] 请求设备注册...");
        apiRequest("/register/dev", {}, function(resp) {
            if (!resp.error && resp.data && resp.data.dfid) {
                dfid = resp.data.dfid;
                saveCookieJson();
                console.log("[RegisterDev] 成功, dfid: " + dfid);
            } else {
                console.warn("[RegisterDev] 失败或无dfid: " + (resp.error || JSON.stringify(resp)));
            }
            if (callback) callback();
        }, false);
    }

    // ---------- 登录刷新 ----------
    function refreshLogin(callback) {
        if (!token || !userId) {
            console.log("[RefreshLogin] 无token/userId，无法刷新");
            if (callback) callback(false);
            return;
        }
        console.log("[RefreshLogin] 尝试刷新登录, userid: " + userId);
        apiRequest("/login/token", { token: token, userid: userId }, function(resp) {
            if (!resp.error && resp.data) {
                if (resp.data.cookie) guestCookie = resp.data.cookie;
                if (resp.data.token) token = resp.data.token;
                saveCookieJson();
                console.log("[RefreshLogin] 刷新成功");
                claimDailyVip();
                if (callback) callback(true);
            } else {
                console.warn("[RefreshLogin] 刷新失败: " + (resp.error || JSON.stringify(resp)));
                if (callback) callback(false);
            }
        }, false);
    }

    function claimDailyVip() {
        var today = new Date().toISOString().slice(0, 10);
        console.log("[VIP] 尝试领取每日VIP，日期:", today);
        apiRequest("/youth/day/vip", { receive_day: today }, function(resp) {
            if (resp.error) {
                if (resp.apiCode !== 131001) {
                    console.warn("[VIP] 领取失败: " + resp.error);
                } else {
                    console.log("[VIP] 今日已领取");
                }
            } else {
                console.log("[VIP] 领取成功");
            }
            upgradeVip();
        });
    }

    function upgradeVip() {
        console.log("[VIP] 尝试升级概念版VIP");
        apiRequest("/youth/day/vip/upgrade", {}, function(resp) {
            if (!resp.error) {
                console.log("[VIP] 升级成功");
            } else {
                console.warn("[VIP] 升级失败: " + resp.error);
            }
        });
    }

    // ---------- 搜索 ----------
    function searchSongs(keyword) {
        if (isSearching) return;
        isSearching = true;
        currentTotal = 0;
        songModel.clear();
        updateStatusMessage();

        apiRequest("/search", {
            keywords: keyword,
            page: 0,
            pagesize: 50
        }, function(resp) {
            if (resp.error) {
                var errMsg = "搜索失败: " + resp.error;
                console.warn("[Search] " + errMsg);
                showError(errMsg);
                if (resp.apiCode === 152) {
                    console.log("[Search] 错误码152，需要登录");
                    root.state = "login";
                }
                isSearching = false;
                updateStatusMessage();
                return;
            }
            var lists = resp.data && resp.data.lists || [];
            for (var i = 0; i < lists.length; i++) {
                var item = lists[i];
                var payType = item.PayType || 0;
                var picUrl = item.Image ? item.Image.replace("{size}", "150") : "";
                var durationMs = item.Duration ? item.Duration * 1000 : 0;
                var songName = item.OriSongName || item.FileName || "";
                var artistLine = item.SingerName || "";
                if (item.AlbumName) {
                    artistLine += " - " + item.AlbumName;
                }
                songModel.append({
                    id: item.FileHash || "",
                    name: songName,
                    artists: artistLine,
                    duration: durationMs,
                    vip: payType !== 0,
                    picUrl: picUrl,
                    payType: payType
                });
            }
            isSearching = false;
            currentTotal = songModel.count;
            updateStatusMessage();
            if (currentTotal > 0) addHistory(keyword);
        });
    }

    // ---------- 获取歌曲详情 ----------
    function fetchSongDetail(hash) {
        if (songCache[hash]) {
            applyDetail(songCache[hash]);
            return;
        }
        apiRequest("/privilege/lite", { hash: hash }, function(resp) {
            if (resp.error || !resp.data || resp.data.length === 0) {
                showError("获取歌曲详情失败");
                return;
            }
            var data = resp.data;
            songCache[hash] = data;
            applyDetail(data);
        });
    }

    function applyDetail(dataArr) {
        var lowHash = "";
        var lowLevel = 999;
        for (var i = 0; i < dataArr.length; i++) {
            var item = dataArr[i];
            if (item.level > 0 && item.level < lowLevel) {
                lowLevel = item.level;
                lowHash = item.hash;
            }
        }
        if (!lowHash) lowHash = dataArr[0].hash;

        var first = dataArr[0];
        var picUrl = first.info && first.info.image ? first.info.image.replace("{size}", "200") : "";
        root.detailSong = {
            id: first.hash,
            name: first.name || "",
            artist: first.singername || "",
            album: first.albumname || "",
            duration: first.info ? first.info.duration : 0,
            picUrl: picUrl,
            payType: first.pay_type || 0,
            lowHash: lowHash
        };
        root.state = "detail";
    }

    // ---------- 下载 ----------
    function startDownload(type) {
        if (!detailSong) return;
        if (isDownloading) {
            showTemporaryMessage("已有下载任务进行中");
            return;
        }

        isDownloading = true;
        statusMessage = "准备下载...";
        sendCommand("\x03");

        var timer = Qt.createQmlObject('import QtQuick 2.15; Timer {}', root);
        timer.interval = 100;
        timer.repeat = false;
        timer.triggered.connect(function() {
            var song = detailSong;
            var songName = safeFileName(song.name);
            var artist = safeFileName(song.artist);
            var baseName = songName + " - " + artist;
            var folder = downloadDir + "/" + baseName;

            runCommand("mkdir -p \"" + folder + "\"", function() {
                var tasks = [];
                if (type === "all" || type === "audio") tasks.push({ type: "audio", file: baseName + ".mp3", desc: "音频" });
                if (type === "all" || type === "lyric") tasks.push({ type: "lyric", file: baseName + ".lrc", desc: "歌词" });
                if (type === "all") tasks.push({ type: "cover", file: baseName + ".jpg", desc: "封面" });

                var completed = [];
                var index = 0;
                function nextTask() {
                    if (index >= tasks.length) {
                        isDownloading = false;
                        if (completed.length > 0) {
                            showTemporaryMessage(completed.join(" ") + " 下载完成");
                        } else {
                            showTemporaryMessage("下载失败");
                        }
                        timer.destroy();
                        return;
                    }
                    var task = tasks[index++];
                    statusMessage = "正在下载" + task.desc + "...";
                    var taskCallback = function(success) {
                        if (success) completed.push(task.desc);
                        nextTask();
                    };
                    if (task.type === "audio") downloadAudio(song, folder + "/" + task.file, taskCallback);
                    else if (task.type === "lyric") downloadLyric(song, folder + "/" + task.file, taskCallback);
                    else if (task.type === "cover") downloadCover(song, folder + "/" + task.file, taskCallback);
                }
                nextTask();
            });
        });
        timer.start();
    }

    function downloadAudio(song, filePath, callback) {
        var hash = song.lowHash || song.id;
        apiRequest("/song/url", { hash: hash }, function(resp) {
            if (resp.error || !resp.url || resp.url.length === 0) {
                if (resp.backupUrl && resp.backupUrl.length > 0) {
                    doCurlDownload(resp.backupUrl[0], filePath, function() { callback(true); });
                } else {
                    showError("获取音频链接失败，可能为付费歌曲");
                    callback(false);
                }
            } else {
                doCurlDownload(resp.url[0], filePath, function() { callback(true); });
            }
        });
    }

    function downloadLyric(song, filePath, callback) {
        apiRequest("/search/lyric", { hash: song.id }, function(resp) {
            if (resp.error || !resp.candidates || resp.candidates.length === 0) {
                showError("未找到歌词");
                callback(false);
                return;
            }
            var candidate = resp.candidates[0];
            apiRequest("/lyric", { id: candidate.id, accesskey: candidate.accesskey, fmt: "lrc", decode: "true" }, function(lyricResp) {
                if (lyricResp.error || !lyricResp.decodeContent) {
                    showError("获取歌词内容失败");
                    callback(false);
                    return;
                }
                var cmd = "cat > \"" + filePath + "\" << 'EOF'\n" + lyricResp.decodeContent + "\nEOF";
                runCommand(cmd, function() { callback(true); });
            });
        });
    }

    function downloadCover(song, filePath, callback) {
        var picUrl = song.picUrl;
        if (!picUrl) {
            console.warn("[Download] 无封面");
            callback(false);
            return;
        }
        doCurlDownload(picUrl.replace("{size}", "250"), filePath, function() { callback(true); });
    }

    function doCurlDownload(url, filePath, callback) {
        var cmd = "curl -L -o \"" + filePath + "\" \"" + url + "\"";
        runCommand(cmd, callback);
    }

    // ---------- 状态消息 ----------
    function updateStatusMessage() {
        if (isSearching) statusMessage = "搜索中...";
        else if (isDownloading) statusMessage = "下载中...";
        else if (currentTotal > 0) statusMessage = "共 " + currentTotal + " 首";
        else if (!backendReady && !isSearching && !isDownloading) {
            return;
        } else statusMessage = "";
    }

    function showTemporaryMessage(msg) {
        statusMessage = msg;
        statusTimer.restart();
    }

    Timer {
        id: statusTimer
        interval: 2000
        onTriggered: updateStatusMessage()
    }

    // ---------- 后端服务管理 ----------
    property int backendRetryCount: 0
    property int backendMaxRetry: 5
    property bool backendReady: false

    function checkBackend(callback) {
        console.log("[Backend] 检测后端服务...");
        var xhr = new XMLHttpRequest();
        xhr.open("GET", apiBase + "/");
        xhr.timeout = 2000;
        xhr.onload = function() {
            console.log("[Backend] 服务已响应, status: " + xhr.status);
            callback(true);
        };
        xhr.onerror = function() {
            console.log("[Backend] 无法连接");
            callback(false);
        };
        xhr.ontimeout = function() {
            console.log("[Backend] 连接超时");
            callback(false);
        };
        xhr.send();
    }

    function startBackend() {
        statusMessage = "后端未启动，正在启动...";
        // 用 node 的绝对路径启动，避免依赖 PATH（插件 shell 的 PATH 通常不含 /usr/bin）
        // 先 chmod 补执行位（解压/adb push 常丢失 x 位），再用绝对路径调用
        var nodeBin = "/userdisk/PenMods/plugins/kugou/node/bin/node";
        var cmd = "chmod +x " + nodeBin + " && cd /userdisk/PenMods/plugins/kugou/KuGouMusicApi && " + nodeBin + " app.js > " + backendLogFile + " 2>&1 &";
        console.log("[Backend] 启动命令: " + cmd);
        if (typeof shell !== 'undefined' && shell) {
            shell.execAsync(cmd, function(result) {
                console.log("[Backend] 启动命令执行结果: " + JSON.stringify(result));
                if (result.error) {
                    console.error("[Backend] 启动失败: " + result.error);
                    showError("后端服务启动失败: " + result.error);
                } else {
                    var readTimer = Qt.createQmlObject('import QtQuick 2.15; Timer { interval: 2000; repeat: false; onTriggered: root.readBackendLog(); }', root);
                    readTimer.start();
                }
            });
        } else {
            showError("Shell 不可用，无法启动后端");
        }
    }

    function readBackendLog() {
        if (typeof shell !== 'undefined' && shell) {
            var readCmd = "cat " + backendLogFile;
            console.log("[Backend] 读取启动日志...");
            shell.execAsync(readCmd, function(readResult) {
                console.log("[Backend] 启动日志 stdout: " + (readResult.stdout || "（无输出）"));
                if (readResult.stderr) {
                    console.warn("[Backend] 启动日志 stderr: " + readResult.stderr);
                }
            });
        }
    }

    function retryCheckBackend() {
        if (backendRetryCount >= backendMaxRetry) {
            statusMessage = "后端服务启动失败，请检查环境";
            backendReady = false;
            continueInitAfterBackend();
            return;
        }
        backendRetryCount++;
        statusMessage = "正在检测后端服务 (第" + backendRetryCount + "/" + backendMaxRetry + "次)...";
        console.log("[Backend] 第" + backendRetryCount + "次重试检测...");
        checkBackend(function(ok) {
            if (ok) {
                backendReady = true;
                statusMessage = "后端服务已启动";
                console.log("[Backend] 服务就绪");
                continueInitAfterBackend();
            } else {
                retryTimer.start();
            }
        });
    }

    Timer {
        id: retryTimer
        interval: 2000
        repeat: false
        onTriggered: retryCheckBackend()
    }

    function continueInitAfterBackend() {
        console.log("[Init] 继续初始化流程");
        if (typeof shell !== 'undefined' && shell) {
            runCommand("mkdir -p \"" + downloadDir + "\"", function(){});
        }
        readHistoryJson(function() {
            if (hasCookie) {
                console.log("[Init] 已有凭证，尝试刷新登录");
                refreshLogin(function(success) {
                    // 避免覆盖用户已手动切换的状态
                    if (root.state === "list" || root.state === "") {
                        root.state = "list";
                    }
                    updateStatusMessage();
                });
            } else {
                console.log("[Init] 无凭证，直接进入列表页");
                if (root.state === "list" || root.state === "") {
                    root.state = "list";
                }
                updateStatusMessage();
            }
        });
    }

    // ---------- 初始化 ----------
    function initApp() {
        statusMessage = "正在初始化...";
        if (typeof shell !== 'undefined' && shell) {
            runCommand("mkdir -p \"" + downloadDir + "\"", function(){});
        }
        readCookieJson(function() {
            readHistoryJson(function() {
                checkBackend(function(running) {
                    if (running) {
                        backendReady = true;
                        statusMessage = "后端服务已启动";
                        continueInitAfterBackend();
                    } else {
                        console.log("[Init] 后端未运行，尝试启动");
                        startBackend();
                        backendRetryCount = 0;
                        retryTimer.interval = 4000;
                        retryTimer.start();
                    }
                });
            });
        });
    }

    Component.onCompleted: {
        console.log("========== 酷狗概念版插件启动 ==========");
        initApp();
    }
}