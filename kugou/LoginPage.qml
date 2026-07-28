import QtQuick 2.15
import "qrc:/qml/commons"

Rectangle {
    id: loginPage
    width: 320
    height: 170
    color: "#f5f5f5"

    property string apiBase: ""
    property string statusText: ""
    signal loginSuccess(string cookie, string token, string userId)

    property bool sendingCode: false
    property bool loggingIn: false
    property bool inputPageShowing: false
    property string currentField: ""

    // 标题栏
    StatusBar {
        id: statusBar
        anchors.top: parent.top
        statusText: loginPage.statusText
    }

    // 主要内容区域
    Column {
        anchors.centerIn: parent
        spacing: 8

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "酷狗音乐登录"
            font.family: "Microsoft YaHei"
            font.pixelSize: 16
            color: "#333"
        }

        // 手机号行
        Row {
            spacing: 4
            Text {
                text: "手机号:"
                font.family: "Microsoft YaHei"
                font.pixelSize: 16
                color: "#333"
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                width: 180
                height: 28
                color: "white"
                border.color: "#cccccc"
                border.width: 1
                radius: 4
                Text {
                    id: mobileDisplay
                    anchors.fill: parent
                    anchors.margins: 4
                    verticalAlignment: Text.AlignVCenter
                    font.family: "Microsoft YaHei"
                    font.pixelSize: 16
                    color: "#333"
                    elide: Text.ElideRight
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: requestKeyboard("mobile")
                }
            }
        }

        // 验证码行
        Row {
            spacing: 4
            Text {
                text: "验证码:"
                font.family: "Microsoft YaHei"
                font.pixelSize: 16
                color: "#333"
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                width: 116
                height: 28
                color: "white"
                border.color: "#cccccc"
                border.width: 1
                radius: 4
                Text {
                    id: codeDisplay
                    anchors.fill: parent
                    anchors.margins: 4
                    verticalAlignment: Text.AlignVCenter
                    font.family: "Microsoft YaHei"
                    font.pixelSize: 16
                    color: "#333"
                    elide: Text.ElideRight
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: requestKeyboard("code")
                }
            }
            Rectangle {
                width: 60
                height: 28
                radius: 4
                color: sendBtn.pressed ? "#cccccc" : "#ffffff"
                border.color: "#aaaaaa"
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "发送"
                    font.family: "Microsoft YaHei"
                    font.pixelSize: 16
                    color: "#333"
                }
                MouseArea {
                    id: sendBtn
                    anchors.fill: parent
                    onClicked: sendCode()
                }
            }
        }

        // 返回和登录按钮并排
        Row {
            spacing: 4
            anchors.horizontalCenter: parent.horizontalCenter
            Rectangle {
                width: 45
                height: 28
                radius: 4
                color: backBtnArea.pressed ? "#cccccc" : "#ffffff"
                border.color: "#aaaaaa"
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "返回"
                    font.family: "Microsoft YaHei"
                    font.pixelSize: 16
                    color: "#333"
                }
                MouseArea {
                    id: backBtnArea
                    anchors.fill: parent
                    onClicked: root.state = "list"
                }
            }
            Rectangle {
                width: 45
                height: 28
                radius: 4
                color: loginBtn.pressed ? "#cccccc" : "#ffffff"
                border.color: "#aaaaaa"
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "登录"
                    font.family: "Microsoft YaHei"
                    font.pixelSize: 16
                    color: "#333"
                }
                MouseArea {
                    id: loginBtn
                    anchors.fill: parent
                    onClicked: login()
                }
            }
        }
    }

    // 隐藏输入框
    TextInput {
        id: hiddenMobileInput
        visible: false
        inputMethodHints: Qt.ImhDigitsOnly
        onTextChanged: mobileDisplay.text = text
    }
    TextInput {
        id: hiddenCodeInput
        visible: false
        inputMethodHints: Qt.ImhDigitsOnly
        onTextChanged: codeDisplay.text = text
    }

    function sendCode() {
        if (sendingCode) return;
        var phone = hiddenMobileInput.text.trim();
        if (!phone) {
            statusText = "请输入手机号";
            return;
        }
        if (phone.length !== 11) {
            statusText = "请输入11位手机号";
            return;
        }
        sendingCode = true;
        statusText = "发送中...";
        var xhr = new XMLHttpRequest();
        // timestamp 用于绕过后端 2 分钟缓存，避免重发被缓存拦截
        var url = apiBase + "/captcha/sent?mobile=" + encodeURIComponent(phone) + "&timestamp=" + Date.now();
        xhr.open("GET", url);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                sendingCode = false;
                // 网络层失败：后端服务未启动或不可达（statusText 会是空串，原代码显示"发送失败:"无法排查）
                if (xhr.status === 0) {
                    statusText = "发送失败: 无法连接后端服务，请确认服务已启动";
                    return;
                }
                var resp;
                try {
                    resp = JSON.parse(xhr.responseText);
                } catch(e) {
                    statusText = "发送失败: 响应解析失败 (HTTP " + xhr.status + ")";
                    return;
                }
                // 酷狗成功标志为 status===1（与后端 util/request.js:210 及 module/login_cellphone.js:56 一致）
                // 不要额外要求 error_code===0：该字段在登录类接口可能不存在，会被误判为失败
                if (xhr.status === 200 && resp.status === 1) {
                    statusText = "验证码已发送";
                    return;
                }
                // 失败：优先展示服务端返回的信息，便于定位
                var msg = resp.err_msg || resp.message || resp.msg || "";
                if (!msg && resp.error_code) msg = "错误码: " + resp.error_code;
                if (!msg) msg = "HTTP " + xhr.status;
                statusText = "发送失败: " + msg;
            }
        };
        xhr.send();
    }

    function login() {
        if (loggingIn) return;
        var phone = hiddenMobileInput.text.trim();
        var smsCode = hiddenCodeInput.text.trim();
        if (!phone || !smsCode) {
            statusText = "请输入手机号和验证码";
            return;
        }
        loggingIn = true;
        statusText = "登录中...";
        var xhr = new XMLHttpRequest();
        var url = apiBase + "/login/cellphone?mobile=" + encodeURIComponent(phone) + "&code=" + encodeURIComponent(smsCode) + "&timestamp=" + Date.now();
        xhr.open("GET", url);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                loggingIn = false;
                if (xhr.status === 0) {
                    statusText = "登录失败: 无法连接后端服务，请确认服务已启动";
                    return;
                }
                var resp;
                try {
                    resp = JSON.parse(xhr.responseText);
                } catch(e) {
                    statusText = "登录失败: 响应解析失败 (HTTP " + xhr.status + ")";
                    return;
                }
                // 酷狗成功标志为 status===1（error_code 字段可能不存在，不应作为判定条件）
                if (xhr.status === 200 && resp.status === 1) {
                    // 凭证优先取 Set-Cookie 头；module/login_cellphone.js 会把 token/userid 写入 cookie
                    var cookie = xhr.getResponseHeader("Set-Cookie") || "";
                    if (!cookie && resp.cookie) cookie = resp.cookie;
                    if (!cookie) {
                        // 回退：拼接 token/userid 作为凭证字符串
                        var parts = [];
                        if (resp.data && resp.data.token) parts.push("token=" + resp.data.token);
                        if (resp.data && resp.data.userid) parts.push("userid=" + resp.data.userid);
                        cookie = parts.join(";");
                    }
                    var tkn = (resp.data && resp.data.token) ? resp.data.token : "";
                    var uid = (resp.data && resp.data.userid) ? resp.data.userid.toString() : "";
                    if (cookie) {
                        statusText = "登录成功";
                        loginSuccess(cookie, tkn, uid);
                    } else {
                        statusText = "登录失败：无法获取凭证";
                    }
                } else {
                    var msg = resp.err_msg || resp.message || resp.msg || "";
                    if (!msg && resp.error_code) msg = "错误码: " + resp.error_code;
                    if (!msg) msg = "HTTP " + xhr.status;
                    statusText = "登录失败: " + msg;
                }
            }
        };
        xhr.send();
    }

    // 键盘复用主界面逻辑
    function requestKeyboard(field) {
        currentField = field;
        var component = qmlCreateComponent("YInputPage");
        if (component.status === Component.Ready) {
            var incubator = component.incubateObject(id_pop_helper.containerItem);
            if (incubator.status !== Component.Ready) {
                incubator.onStatusChanged = function(status) {
                    if (status === Component.Ready)
                        id_pop_helper.inputPageCreated(incubator.object);
                };
            } else {
                id_pop_helper.inputPageCreated(incubator.object);
            }
        } else if (component.status === Component.Error) {
            console.error("[Keyboard] 加载YInputPage失败:", component.errorString());
            statusText = "无法打开键盘";
        } else {
            component.statusChanged.connect(function() {
                if (component.status === Component.Ready) {
                    var incubator = component.incubateObject(id_pop_helper.containerItem);
                    if (incubator.status !== Component.Ready) {
                        incubator.onStatusChanged = function(status) {
                            if (status === Component.Ready)
                                id_pop_helper.inputPageCreated(incubator.object);
                        };
                    } else {
                        id_pop_helper.inputPageCreated(incubator.object);
                    }
                } else if (component.status === Component.Error) {
                    console.error("[Keyboard] 加载YInputPage失败:", component.errorString());
                    statusText = "无法打开键盘";
                }
            });
        }
    }

    YPagePopHelper {
        id: id_pop_helper
        z: 99
        function inputPageCreated(keyboardPage) {
            keyboardPage.backButtonClicked.connect(function() {
                inputPageShowing = false;
                keyboardPage.todoDestroy();
                keyboardPage = null;
            });

            keyboardPage.inputFinished.connect(function(content) {
                var text = content.trim();
                if (currentField === "mobile") {
                    hiddenMobileInput.text = text;
                } else if (currentField === "code") {
                    hiddenCodeInput.text = text;
                }
                inputPageShowing = false;
                keyboardPage.todoDestroy();
            });

            if (currentField === "mobile") {
                keyboardPage.enterText(hiddenMobileInput.text);
            } else if (currentField === "code") {
                keyboardPage.enterText(hiddenCodeInput.text);
            }
            keyboardPage.show();
            inputPageShowing = true;
        }
        isShowing: inputPageShowing
        objectName: "from_LoginPage"
    }
}