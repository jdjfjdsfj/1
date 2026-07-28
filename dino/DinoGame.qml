import QtQuick 2.15

Rectangle {
    id: gameWindow
    width: 800
    height: 400
    color: "#f7f7f7"

    // ==================== 游戏状态 ====================
    property bool gameRunning: false
    property bool gameOver: false
    property int score: 0
    property int highScore: 0
    property real gameSpeed: 6.0
    property real baseSpeed: 6.0
    property real speedIncrement: 0.001
    property int frameCount: 0

    // 物理参数
    property real gravity: 0.8
    property real jumpVelocity: -14.0
    property real dinoYVelocity: 0
    property real groundY: 300
    property real dinoBaseY: groundY - dino.height

    // ==================== 背景地面 ====================
    Rectangle {
        anchors.fill: parent
        color: "#f7f7f7"
    }

    // 地面线
    Rectangle {
        x: 0
        y: groundY
        width: parent.width
        height: 2
        color: "#535353"
    }

    // 地面小石子（滚动效果）
    Repeater {
        model: 20
        Rectangle {
            x: index * 45 + (groundOffset % 45)
            y: groundY + 6 + (index % 3) * 4
            width: 3 + (index % 3)
            height: 2
            color: "#b0b0b0"
            radius: 1
        }
    }
    property int groundOffset: 0

    // ==================== 云朵 ====================
    Repeater {
        id: cloudRepeater
        model: 3
        Item {
            id: cloudItem
            x: initX + cloudOffset
            y: 40 + index * 35
            width: 62
            height: 22

            property real initX: 200 + index * 240
            property real cloudOffset: 0

            Rectangle { color: "#e8e8e8"; radius: 10; anchors.fill: parent }
            Rectangle { x: 10; y: -10; width: 42; height: 18; color: "#e8e8e8"; radius: 9 }
            Rectangle { x: -10; y: -3; width: 26; height: 15; color: "#e8e8e8"; radius: 8 }
        }
    }

    // ==================== 恐龙 ====================
    Canvas {
        id: dino
        x: 80
        y: dinoBaseY
        width: 44
        height: 48
        property int legPhase: 0

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            drawDino(ctx, gameOver)
        }

        function drawDino(ctx, isDead) {
            ctx.fillStyle = "#535353"
            ctx.strokeStyle = "#535353"
            ctx.lineWidth = 2

            // 身体轮廓
            ctx.beginPath()
            ctx.moveTo(8, 4)
            ctx.lineTo(4, 18)
            ctx.lineTo(2, 30)
            ctx.lineTo(4, 42)
            ctx.lineTo(8, 47)
            ctx.lineTo(38, 47)
            ctx.lineTo(42, 42)
            ctx.lineTo(44, 28)
            ctx.lineTo(42, 14)
            ctx.lineTo(36, 4)
            ctx.closePath()
            ctx.fill()

            // 眼睛白色部分
            ctx.fillStyle = "#ffffff"
            ctx.beginPath()
            ctx.arc(33, 14, 5.5, 0, Math.PI * 2)
            ctx.fill()

            // 眼珠
            ctx.fillStyle = "#535353"
            ctx.beginPath()
            ctx.arc(isDead ? 34 : 35, 14, 2.5, 0, Math.PI * 2)
            ctx.fill()

            // 嘴巴线条
            ctx.strokeStyle = "#535353"
            ctx.lineWidth = 1.5
            ctx.beginPath()
            ctx.moveTo(14, 20)
            ctx.lineTo(isDead ? 6 : 2, 23)
            ctx.stroke()

            // 背部棘刺
            ctx.fillStyle = "#535353"
            for (var i = 0; i < 4; i++) {
                ctx.beginPath()
                var sx = 14 + i * 5
                ctx.moveTo(sx - 2, 4)
                ctx.lineTo(sx - 5, -1)
                ctx.lineTo(sx + 1, 4)
                ctx.fill()
            }

            // 腿
            ctx.fillStyle = "#535353"
            if (!isDead) {
                if (legPhase === 0) {
                    // 前腿向前
                    ctx.fillRect(24, 43, 5, 7)
                    ctx.fillRect(28, 46, 5, 4)
                    // 后腿向后
                    ctx.fillRect(14, 43, 5, 7)
                    ctx.fillRect(12, 46, 5, 4)
                } else {
                    // 前腿向后
                    ctx.fillRect(22, 43, 5, 7)
                    ctx.fillRect(20, 46, 5, 4)
                    // 后腿向前
                    ctx.fillRect(16, 43, 5, 7)
                    ctx.fillRect(18, 46, 5, 4)
                }
            } else {
                // 死亡姿势
                ctx.fillRect(26, 37, 6, 10)
                ctx.fillRect(14, 37, 6, 10)
            }
        }
    }

    // ==================== 障碍物（仙人掌） ====================
    Item {
        id: cactus1
        x: gameWindow.width
        y: groundY - 44
        width: 22
        height: 44
        visible: false

        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.fillStyle = "#535353"
                var w = parent.width, h = parent.height
                // 主干
                ctx.fillRect(w * 0.32, 0, w * 0.36, h)
                // 左臂
                ctx.fillRect(0, h * 0.30, w * 0.36, h * 0.11)
                ctx.fillRect(w * 0.05, h * 0.14, w * 0.10, h * 0.28)
                // 右臂
                ctx.fillRect(w * 0.66, h * 0.20, w * 0.34, h * 0.11)
                ctx.fillRect(w * 0.82, h * 0.07, w * 0.10, h * 0.25)
            }
        }
    }

    Item {
        id: cactus2
        x: gameWindow.width + 200
        y: groundY - 34
        width: 16
        height: 34
        visible: false

        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.fillStyle = "#535353"
                var w = parent.width, h = parent.height
                // 主干
                ctx.fillRect(w * 0.31, 0, w * 0.38, h)
                // 左臂
                ctx.fillRect(0, h * 0.33, w * 0.36, h * 0.10)
                // 右臂
                ctx.fillRect(w * 0.66, h * 0.22, w * 0.34, h * 0.10)
            }
        }
    }

    // ==================== 分数显示 ====================
    Text {
        id: scoreDisplay
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 20
        anchors.topMargin: 20
        text: "00000"
        font.pixelSize: 22
        font.bold: true
        color: "#535353"
        font.family: "Courier New"
    }

    Text {
        id: hiText
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 90
        anchors.topMargin: 22
        text: "HI 00000"
        font.pixelSize: 18
        color: "#757575"
        font.family: "Courier New"
        visible: gameOver
    }

    // ==================== 提示文字 ====================
    Text {
        id: gameOverText
        anchors.horizontalCenter: parent.horizontalCenter
        y: 160
        text: "G A M E   O V E R"
        font.pixelSize: 24
        font.bold: true
        color: "#535353"
        font.family: "Courier New"
        visible: false
    }

    Text {
        id: restartText
        anchors.horizontalCenter: parent.horizontalCenter
        y: 195
        text: "按 空格键 / ↑ / 点击屏幕 重新开始"
        font.pixelSize: 13
        color: "#888888"
        visible: false
    }

    Text {
        id: startHint
        anchors.horizontalCenter: parent.horizontalCenter
        y: 160
        text: "按 空格键 / ↑ / 点击屏幕 开始游戏"
        font.pixelSize: 15
        color: "#888888"
        visible: !gameRunning && !gameOver
    }

    // ==================== 游戏主循环 ====================
    Timer {
        id: gameLoop
        interval: 16  // ~60 FPS
        running: gameRunning && !gameOver
        repeat: true

        onTriggered: {
            frameCount++

            // 地面滚动
            groundOffset = (groundOffset + gameSpeed) % 45

            // 恐龙物理
            dinoYVelocity += gravity
            dino.y += dinoYVelocity
            if (dino.y >= dinoBaseY) {
                dino.y = dinoBaseY
                dinoYVelocity = 0
            }

            // 仙人掌移动 & 生成
            updateCactus(cactus1)
            updateCactus(cactus2)

            // 云朵移动
            updateClouds()

            // 碰撞检测
            checkCollision()

            // 计分
            if (frameCount % 10 === 0) {
                score += 1
                scoreDisplay.text = String(score).padStart(5, '0')
            }

            // 加速
            gameSpeed = baseSpeed + score * 0.004
        }
    }

    function updateCactus(cactus) {
        if (cactus.visible) {
            cactus.x -= gameSpeed
            if (cactus.x < -60) {
                cactus.visible = false
            }
        } else {
            if (Math.random() < 0.012) {
                cactus.x = gameWindow.width + Math.random() * 200
                cactus.visible = true
            }
        }
    }

    function updateClouds() {
        for (var i = 0; i < cloudRepeater.count; i++) {
            var cloud = cloudRepeater.itemAt(i)
            if (cloud) {
                cloud.cloudOffset -= 1.0
                if (cloud.cloudOffset < -gameWindow.width - 100) {
                    cloud.cloudOffset = gameWindow.width + Math.random() * 150
                }
            }
        }
    }

    function checkCollision() {
        // 恐龙的碰撞框（略微缩小，更宽容）
        var dr = Qt.rect(dino.x + 8, dino.y + 6, dino.width - 16, dino.height - 12)

        var cacti = [cactus1, cactus2]
        for (var i = 0; i < cacti.length; i++) {
            var c = cacti[i]
            if (c.visible) {
                var cr = Qt.rect(c.x + 4, c.y + 2, c.width - 8, c.height - 4)
                if (!(cr.x > dr.x + dr.width ||
                      cr.x + cr.width < dr.x ||
                      cr.y > dr.y + dr.height ||
                      cr.y + cr.height < dr.y)) {
                    endGame()
                    return
                }
            }
        }
    }

    // ==================== 游戏控制函数 ====================
    function startGame() {
        score = 0
        gameSpeed = baseSpeed
        dino.y = dinoBaseY
        dinoYVelocity = 0
        cactus1.visible = false
        cactus2.visible = false
        cactus1.x = gameWindow.width
        cactus2.x = gameWindow.width + 200
        gameOver = false
        gameRunning = true
        gameOverText.visible = false
        restartText.visible = false
        startHint.visible = false
        hiText.visible = false
        scoreDisplay.text = "00000"
        dino.legPhase = 0
        dino.requestPaint()
        frameCount = 0
    }

    function jump() {
        if (!gameRunning && !gameOver) {
            startGame()
            dinoYVelocity = jumpVelocity
        } else if (gameRunning && !gameOver && dino.y >= dinoBaseY) {
            dinoYVelocity = jumpVelocity
        } else if (gameOver) {
            startGame()
        }
    }

    function endGame() {
        gameOver = true
        gameRunning = false
        if (score > highScore) {
            highScore = score
        }
        hiText.text = "HI " + String(highScore).padStart(5, '0')
        hiText.visible = true
        gameOverText.visible = true
        restartText.visible = true
        dino.requestPaint()
    }

    // ==================== 输入 ====================
    MouseArea {
        anchors.fill: parent
        onClicked: jump()
    }

    // 键盘输入
    Keys.onSpacePressed: { jump(); event.accepted = true }
    Keys.onUpPressed:    { jump(); event.accepted = true }
    Keys.onPressed: {
        if (event.key === Qt.Key_W && !event.isAutoRepeat) { jump(); event.accepted = true }
    }

    // 尝试获取键盘焦点
    Component.onCompleted: forceActiveFocus()

    // ==================== 腿部动画定时器 ====================
    Timer {
        interval: 100
        running: gameRunning && !gameOver
        repeat: true
        onTriggered: {
            dino.legPhase = 1 - dino.legPhase
            dino.requestPaint()
        }
    }
}
