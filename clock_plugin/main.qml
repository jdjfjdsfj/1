import QtQuick 2.12
import QtQuick.Controls 1.4
import QtQuick.Layouts 1.15
import QtQuick.Controls.Styles 1.4
import MyPlugins.Clock 1.0
import "qrc:/qml/commons"

Rectangle {
    id: root
    width: 320
    height: 170
    color: "#222222"

    signal backButtonClicked()

    property int currentTab: 0 // 0:时钟 1:计时器 2:秒表 3:倒数日

    // 计时器状态
    property int timerSetSeconds: 60
    property int timerRemaining: 60
    property bool timerRunning: false

    // 秒表状态
    property int stopwatchElapsed: 0 // 毫秒
    property bool stopwatchRunning: false
    property var stopwatchLaps: []

    // 倒数日数据
    property var countdownList: [
        { name: "新年", date: "2027-01-01" }
    ]

    // ===== 键盘输入相关 =====
    property string activeInputField: "" // "cdName" | "cdDate"

    ClockController {
        id: controller
    }

    Timer {
        interval: 1000
        running: currentTab === 0
        repeat: true
        onTriggered: controller.timeChanged()
    }

    // 计时器倒计时
    Timer {
        id: timerTicker
        interval: 1000
        running: timerRunning && currentTab === 1
        repeat: true
        onTriggered: {
            if (timerRemaining > 0) {
                timerRemaining--;
            } else {
                timerRunning = false;
            }
        }
    }

    // 秒表计时
    Timer {
        id: stopwatchTicker
        interval: 10
        running: stopwatchRunning && currentTab === 2
        repeat: true
        onTriggered: stopwatchElapsed += 10
    }

    function pad(n) {
        return n < 10 ? "0" + n : n;
    }

    function formatTimer(sec) {
        var m = Math.floor(sec / 60);
        var s = sec % 60;
        return pad(m) + ":" + pad(s);
    }

    function formatStopwatch(ms) {
        var m = Math.floor(ms / 60000);
        var s = Math.floor((ms % 60000) / 1000);
        var ms2 = Math.floor((ms % 1000) / 10);
        return pad(m) + ":" + pad(s) + "." + pad(ms2);
    }

    function getDaysLeft(dateStr) {
        var today = new Date();
        today.setHours(0, 0, 0, 0);
        var target = new Date(dateStr);
        target.setHours(0, 0, 0, 0);
        var diff = target - today;
        return Math.ceil(diff / (1000 * 60 * 60 * 24));
    }

    // ===== 键盘调用函数 =====
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

    function handleInputSubmit(text) {
        if (activeInputField === "cdName") {
            cdNameInput.text = text
        } else if (activeInputField === "cdDate") {
            cdDateInput.text = text
        }
        activeInputField = ""
    }

    // ========== 标题栏 ==========
    Item {
        id: titleBar
        width: parent.width
        height: 28
        anchors.top: parent.top

        Rectangle {
            id: backBtn
            width: 44
            height: 20
            radius: 4
            color: backArea.pressed ? "#555555" : "#333333"
            border.color: "#666666"
            border.width: 1
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: "返回"
                color: "white"
                font.family: "Microsoft YaHei"
                font.pixelSize: 11
                anchors.centerIn: parent
            }

            MouseArea {
                id: backArea
                anchors.fill: parent
                onClicked: root.backButtonClicked()
            }
        }

        Text {
            text: {
                if (currentTab === 0) return "时钟";
                if (currentTab === 1) return "计时器";
                if (currentTab === 2) return "秒表";
                return "倒数日";
            }
            color: "#AAAAAA"
            font.family: "Microsoft YaHei"
            font.pixelSize: 14
            anchors.centerIn: parent
        }
    }

    // ========== Tab栏 ==========
    Row {
        id: tabBar
        anchors.top: titleBar.bottom
        width: parent.width
        height: 22

        Repeater {
            model: ["时钟", "计时", "秒表", "倒数"]
            delegate: Rectangle {
                width: tabBar.width / 4
                height: tabBar.height
                color: currentTab === index ? "#444444" : "#333333"
                border.color: "#555555"
                border.width: 0.5

                Text {
                    text: modelData
                    color: currentTab === index ? "white" : "#888888"
                    font.family: "Microsoft YaHei"
                    font.pixelSize: 10
                    anchors.centerIn: parent
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: currentTab = index
                }
            }
        }
    }

    // ========== 内容区 ==========
    Item {
        anchors.top: tabBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        // ---- 时钟页面 ----
        Item {
            visible: currentTab === 0
            anchors.fill: parent

            Text {
                anchors.centerIn: parent
                text: controller.currentTime
                color: "white"
                font.family: "Microsoft YaHei"
                font.pixelSize: 38
                font.bold: true
            }
        }

        // ---- 计时器页面 ----
        Item {
            visible: currentTab === 1
            anchors.fill: parent

            Column {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: formatTimer(timerRunning ? timerRemaining : timerSetSeconds)
                    color: timerRunning && timerRemaining <= 10 ? "#ff6b6b" : "white"
                    font.family: "Microsoft YaHei"
                    font.pixelSize: 36
                    font.bold: true
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4

                    Button {
                        width: 36
                        height: 22
                        text: "-1分"
                        onClicked: {
                            if (!timerRunning) {
                                timerSetSeconds = Math.max(0, timerSetSeconds - 60);
                                timerRemaining = timerSetSeconds;
                            }
                        }
                        style: ButtonStyle {
                            label: Label {
                                text: control.text
                                color: "white"
                                font.family: "Microsoft YaHei"
                                font.pixelSize: 9
                                anchors.centerIn: parent
                            }
                            background: Rectangle {
                                color: control.pressed ? "#555555" : "#444444"
                                radius: 3
                            }
                        }
                    }

                    Button {
                        width: 36
                        height: 22
                        text: "-10秒"
                        onClicked: {
                            if (!timerRunning) {
                                timerSetSeconds = Math.max(0, timerSetSeconds - 10);
                                timerRemaining = timerSetSeconds;
                            }
                        }
                        style: ButtonStyle {
                            label: Label {
                                text: control.text
                                color: "white"
                                font.family: "Microsoft YaHei"
                                font.pixelSize: 9
                                anchors.centerIn: parent
                            }
                            background: Rectangle {
                                color: control.pressed ? "#555555" : "#444444"
                                radius: 3
                            }
                        }
                    }

                    Button {
                        width: 50
                        height: 22
                        text: timerRunning ? "暂停" : "开始"
                        onClicked: {
                            if (timerRunning) {
                                timerRunning = false;
                            } else {
                                if (timerRemaining === 0) timerRemaining = timerSetSeconds;
                                if (timerRemaining > 0) timerRunning = true;
                            }
                        }
                        style: ButtonStyle {
                            label: Label {
                                text: control.text
                                color: "white"
                                font.family: "Microsoft YaHei"
                                font.pixelSize: 10
                                anchors.centerIn: parent
                            }
                            background: Rectangle {
                                color: control.pressed ? "#2e7d32" : "#4caf50"
                                radius: 3
                            }
                        }
                    }

                    Button {
                        width: 36
                        height: 22
                        text: "+10秒"
                        onClicked: {
                            if (!timerRunning) {
                                timerSetSeconds += 10;
                                timerRemaining = timerSetSeconds;
                            }
                        }
                        style: ButtonStyle {
                            label: Label {
                                text: control.text
                                color: "white"
                                font.family: "Microsoft YaHei"
                                font.pixelSize: 9
                                anchors.centerIn: parent
                            }
                            background: Rectangle {
                                color: control.pressed ? "#555555" : "#444444"
                                radius: 3
                            }
                        }
                    }

                    Button {
                        width: 36
                        height: 22
                        text: "+1分"
                        onClicked: {
                            if (!timerRunning) {
                                timerSetSeconds += 60;
                                timerRemaining = timerSetSeconds;
                            }
                        }
                        style: ButtonStyle {
                            label: Label {
                                text: control.text
                                color: "white"
                                font.family: "Microsoft YaHei"
                                font.pixelSize: 9
                                anchors.centerIn: parent
                            }
                            background: Rectangle {
                                color: control.pressed ? "#555555" : "#444444"
                                radius: 3
                            }
                        }
                    }
                }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 60
                    height: 22
                    text: "复位"
                    onClicked: {
                        timerRunning = false;
                        timerRemaining = timerSetSeconds;
                    }
                    style: ButtonStyle {
                        label: Label {
                            text: control.text
                            color: "white"
                            font.family: "Microsoft YaHei"
                            font.pixelSize: 10
                            anchors.centerIn: parent
                        }
                        background: Rectangle {
                            color: control.pressed ? "#c62828" : "#e53935"
                            radius: 3
                        }
                    }
                }
            }
        }

        // ---- 秒表页面 ----
        Item {
            visible: currentTab === 2
            anchors.fill: parent

            Column {
                anchors.fill: parent
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: formatStopwatch(stopwatchElapsed)
                    color: "white"
                    font.family: "Microsoft YaHei"
                    font.pixelSize: 32
                    font.bold: true
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6

                    Button {
                        width: 50
                        height: 22
                        text: stopwatchRunning ? "暂停" : "开始"
                        onClicked: stopwatchRunning = !stopwatchRunning
                        style: ButtonStyle {
                            label: Label {
                                text: control.text
                                color: "white"
                                font.family: "Microsoft YaHei"
                                font.pixelSize: 10
                                anchors.centerIn: parent
                            }
                            background: Rectangle {
                                color: control.pressed ? "#2e7d32" : "#4caf50"
                                radius: 3
                            }
                        }
                    }

                    Button {
                        width: 50
                        height: 22
                        text: "复位"
                        onClicked: {
                            stopwatchRunning = false;
                            stopwatchElapsed = 0;
                            stopwatchLaps = [];
                        }
                        style: ButtonStyle {
                            label: Label {
                                text: control.text
                                color: "white"
                                font.family: "Microsoft YaHei"
                                font.pixelSize: 10
                                anchors.centerIn: parent
                            }
                            background: Rectangle {
                                color: control.pressed ? "#c62828" : "#e53935"
                                radius: 3
                            }
                        }
                    }

                    Button {
                        width: 50
                        height: 22
                        text: "计圈"
                        onClicked: {
                            stopwatchLaps = [formatStopwatch(stopwatchElapsed)].concat(stopwatchLaps);
                            if (stopwatchLaps.length > 5) {
                                var tmp = stopwatchLaps.slice();
                                tmp.pop();
                                stopwatchLaps = tmp;
                            }
                        }
                        style: ButtonStyle {
                            label: Label {
                                text: control.text
                                color: "white"
                                font.family: "Microsoft YaHei"
                                font.pixelSize: 10
                                anchors.centerIn: parent
                            }
                            background: Rectangle {
                                color: control.pressed ? "#555555" : "#444444"
                                radius: 3
                            }
                        }
                    }
                }

                ListView {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.8
                    height: parent.height - 70
                    clip: true
                    model: stopwatchLaps
                    delegate: Text {
                        width: parent.width
                        text: "计圈 " + (stopwatchLaps.length - index) + ":  " + modelData
                        color: "#cccccc"
                        font.family: "Microsoft YaHei"
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        // ---- 倒数日页面 ----
        Item {
            visible: currentTab === 3
            anchors.fill: parent

            Column {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 2

                Row {
                    width: parent.width
                    height: 24
                    spacing: 4

                    TextField {
                        id: cdNameInput
                        width: parent.width * 0.3
                        height: parent.height
                        placeholderText: "名称"
                        font.family: "Microsoft YaHei"
                        font.pixelSize: 10
                        activeFocusOnPress: false
                        style: TextFieldStyle {
                            textColor: "white"
                            background: Rectangle {
                                color: "#444444"
                                radius: 3
                                border.color: "#666666"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                activeInputField = "cdName"
                                requestKeyboard(cdNameInput.text)
                            }
                        }
                    }

                    TextField {
                        id: cdDateInput
                        width: parent.width * 0.35
                        height: parent.height
                        placeholderText: "2026-05-01"
                        font.family: "Microsoft YaHei"
                        font.pixelSize: 10
                        activeFocusOnPress: false
                        style: TextFieldStyle {
                            textColor: "white"
                            background: Rectangle {
                                color: "#444444"
                                radius: 3
                                border.color: "#666666"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                activeInputField = "cdDate"
                                requestKeyboard(cdDateInput.text)
                            }
                        }
                    }

                    Button {
                        width: parent.width * 0.3
                        height: parent.height
                        text: "添加"
                        onClicked: {
                            if (cdNameInput.text !== "" && cdDateInput.text !== "") {
                                var newList = countdownList.slice();
                                newList.push({ name: cdNameInput.text, date: cdDateInput.text });
                                countdownList = newList;
                                cdNameInput.text = "";
                                cdDateInput.text = "";
                            }
                        }
                        style: ButtonStyle {
                            label: Label {
                                text: control.text
                                color: "white"
                                font.family: "Microsoft YaHei"
                                font.pixelSize: 10
                                anchors.centerIn: parent
                            }
                            background: Rectangle {
                                color: control.pressed ? "#2e7d32" : "#4caf50"
                                radius: 3
                            }
                        }
                    }
                }

                ListView {
                    width: parent.width
                    height: parent.height - 26
                    clip: true
                    model: countdownList
                    delegate: Rectangle {
                        width: parent.width
                        height: 26
                        color: index % 2 === 0 ? "#333333" : "#2a2a2a"
                        radius: 3

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            text: modelData.name
                            color: "white"
                            font.family: "Microsoft YaHei"
                            font.pixelSize: 11
                        }

                        Rectangle {
                            id: deleteBtn
                            width: 24
                            height: 18
                            radius: 3
                            color: deleteArea.pressed ? "#c62828" : "#e53935"
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 6

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: "white"
                                font.family: "Microsoft YaHei"
                                font.pixelSize: 14
                                font.bold: true
                            }

                            MouseArea {
                                id: deleteArea
                                anchors.fill: parent
                                onClicked: {
                                    var newList = [];
                                    for (var i = 0; i < countdownList.length; i++) {
                                        if (i !== index) newList.push(countdownList[i]);
                                    }
                                    countdownList = newList;
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: deleteBtn.left
                            anchors.rightMargin: 8
                            text: {
                                var days = getDaysLeft(modelData.date);
                                if (days < 0) return "已过期 " + Math.abs(days) + " 天";
                                if (days === 0) return "就在今天";
                                return "还剩 " + days + " 天";
                            }
                            color: {
                                var days = getDaysLeft(modelData.date);
                                if (days < 0) return "#888888";
                                if (days <= 3) return "#ff6b6b";
                                if (days <= 7) return "#ffa726";
                                return "#66bb6a";
                            }
                            font.family: "Microsoft YaHei"
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }
            }
        }
    }

    // ===== 键盘弹出辅助组件 =====
    YPagePopHelper {
        id: pagePopHelper
        z: 99
        property var containerItem: this

        function inputPageCreated(keyboardPage, initialText) {
            keyboardPage.backButtonClicked.connect(function() {
                qmlGlobal.inputPageShowing = false
                keyboardPage.todoDestroy()
                keyboardPage = null
            })
            keyboardPage.inputFinished.connect(function(content) {
                qmlGlobal.inputPageShowing = false
                keyboardPage.todoDestroy()
                if (content) handleInputSubmit(content)
            })
            keyboardPage.enterText(initialText)
            keyboardPage.show()
            qmlGlobal.inputPageShowing = true
        }

        isShowing: qmlGlobal.inputPageShowing
        objectName: "from_ClockPlugin"
    }
}
