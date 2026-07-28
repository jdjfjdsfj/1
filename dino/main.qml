import QtQuick 2.15
import QtQuick.LocalStorage 2.15

Rectangle {
    id: gameWindow
    focus: true
    width: 320
    height: 170
    color: isNight ? "#1a1a2e" : "#f7f7f7"

    // PenMods 退出信号
    signal backButtonClicked()

    // ==================== 返回按钮 ====================
    Rectangle {
        x: 2; y: 2
        z: 10  // 确保在所有元素之上
        width: 24; height: 18
        color: "transparent"
        Text {
            anchors.centerIn: parent
            text: "←"
            font.pixelSize: 14; font.bold: true
            color: textColor
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            onClicked: {
                gameRunning = false
                gameOver = true
                gameWindow.backButtonClicked()
            }
        }
    }

    // ==================== 游戏状态 ====================
    property bool gameRunning: false
    property bool gameOver: false
    property int score: 0
    property int highScore: 0
    property real gameSpeed: 2.4
    property real baseSpeed: 2.4
    property int frameCount: 0

    // 昼夜切换：每 700 分切换一次
    property bool isNight: Math.floor(score / 700) % 2 === 1

    // 物理参数
    property real gravity: 0.32
    property real jumpVelocity: -5.6
    property real dinoYVelocity: 0
    property real groundY: 120
    property real dinoBaseY: groundY - 19

    property real groundOffset: 0.0

    // 所有障碍物共享冷却（仙人掌+翼龙不会同时出现）
    property int obstacleSpawnTimer: 0
    property int minObstacleGap: 80

    // 颜色随昼夜
    property string lineColor: isNight ? "#888888" : "#535353"
    property string textColor: isNight ? "#cccccc" : "#535353"
    property string subColor:  isNight ? "#666666" : "#b0b0b0"
    property string dinoColor: isNight ? "#aaaaaa" : "#535353"

    // ==================== 背景装饰：白天云朵 ====================
    Repeater {
        id: cloudRepeater
        model: 3
        Item {
            x: initX + cloudOffset
            y: 12 + index * 14
            width: 24; height: 9
            property real initX: 60 + index * 90
            property real cloudOffset: 0
            visible: !isNight

            Rectangle { color: "#e8e8e8"; radius: 4; anchors.fill: parent }
            Rectangle { x: 4; y: -4; width: 16; height: 7; color: "#e8e8e8"; radius: 4 }
            Rectangle { x: -4; y: -1; width: 10; height: 6; color: "#e8e8e8"; radius: 3 }
        }
    }

    // ==================== 背景装饰：夜晚月亮 ====================
    Item {
        id: moonContainer
        visible: isNight
        x: 240; y: 14
        width: 16; height: 16
        Canvas {
            id: moonCanvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.fillStyle = "#ffd700"
                ctx.beginPath()
                ctx.arc(8, 8, 7, 0, Math.PI * 2)
                ctx.fill()
                ctx.fillStyle = "#1a1a2e"
                ctx.beginPath()
                ctx.arc(11, 6, 5, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }

    // 昼夜切换时重绘月亮 + 恐龙/翼龙颜色刷新
    onIsNightChanged: {
        if (isNight) moonCanvas.requestPaint()
    }
    onDinoColorChanged: {
        dino.requestPaint()
        if (pterodactyl.visible) pteraCanvas.requestPaint()
    }

    // ==================== 背景装饰：夜晚星星 ====================
    Repeater {
        model: 8
        Rectangle {
            visible: isNight
            x: 15 + index * 35 + ((index * 17) % 40)
            y: 8 + (index * 11) % 30
            width: 2; height: 2
            color: "#ffffff"
            radius: 1
            // 闪烁
            opacity: 0.5 + 0.5 * Math.sin(frameCount * 0.02 + index)
        }
    }

    // ==================== 地面 ====================
    Rectangle {
        x: 0; y: groundY
        width: parent.width; height: 1
        color: lineColor
    }

    Repeater {
        model: 15
        Rectangle {
            x: index * 22 + (gameWindow.groundOffset % 22)
            y: gameWindow.groundY + 3
            width: 2; height: 1
            color: subColor
            radius: 1
        }
    }

    // ==================== 恐龙 Canvas 18×19 ====================
    Canvas {
        id: dino
        x: 32
        width: 18; height: 19
        property int legPhase: 0

        Component.onCompleted: y = dinoBaseY

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            drawDino(ctx, gameWindow.gameOver)
        }

        function drawDino(ctx, isDead) {
            var dc = gameWindow.dinoColor
            ctx.fillStyle = dc
            ctx.strokeStyle = dc
            ctx.lineWidth = 1

            ctx.beginPath()
            ctx.moveTo(3, 2);  ctx.lineTo(2, 7);  ctx.lineTo(1, 12)
            ctx.lineTo(2, 17); ctx.lineTo(3, 19); ctx.lineTo(15, 19)
            ctx.lineTo(17, 17); ctx.lineTo(18, 11)
            ctx.lineTo(17, 6); ctx.lineTo(14, 2)
            ctx.closePath()
            ctx.fill()

            ctx.fillStyle = "#ffffff"
            ctx.beginPath()
            ctx.arc(13, 6, 2, 0, Math.PI * 2)
            ctx.fill()

            ctx.fillStyle = dc
            ctx.beginPath()
            ctx.arc(isDead ? 13 : 14, 6, 1, 0, Math.PI * 2)
            ctx.fill()

            ctx.strokeStyle = dc
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.moveTo(6, 8)
            ctx.lineTo(isDead ? 2 : 1, 9)
            ctx.stroke()

            ctx.fillStyle = dc
            for (var i = 0; i < 3; i++) {
                ctx.beginPath()
                var sx = 6 + i * 2
                ctx.moveTo(sx - 1, 2); ctx.lineTo(sx - 2, 0); ctx.lineTo(sx + 1, 2)
                ctx.fill()
            }

            ctx.fillStyle = dc
            if (!isDead) {
                if (legPhase === 0) {
                    ctx.fillRect(9, 17, 2, 3); ctx.fillRect(11, 18, 2, 2)
                    ctx.fillRect(5, 17, 2, 3); ctx.fillRect(4, 18, 2, 2)
                } else {
                    ctx.fillRect(8, 17, 2, 3); ctx.fillRect(7, 18, 2, 2)
                    ctx.fillRect(6, 17, 2, 3); ctx.fillRect(7, 18, 2, 2)
                }
            } else {
                ctx.fillRect(10, 15, 2, 4)
                ctx.fillRect(5, 15, 2, 4)
            }
        }
    }

    // ==================== 仙人掌 ====================
    Item {
        id: cactus1
        x: -50; y: groundY - 18
        width: 9; height: 18
        visible: false
        Rectangle { x: 3; y: 0; width: 3; height: 18; color: dinoColor }
        Rectangle { x: 0; y: 5; width: 3; height: 2; color: dinoColor }
        Rectangle { x: 0; y: 3; width: 1; height: 3; color: dinoColor }
        Rectangle { x: 6; y: 3; width: 3; height: 2; color: dinoColor }
        Rectangle { x: 8; y: 1; width: 1; height: 3; color: dinoColor }
    }

    Item {
        id: cactus2
        x: -50; y: groundY - 14
        width: 7; height: 14
        visible: false
        Rectangle { x: 2; y: 0; width: 3; height: 14; color: dinoColor }
        Rectangle { x: 0; y: 4; width: 2; height: 1; color: dinoColor }
        Rectangle { x: 5; y: 2; width: 2; height: 1; color: dinoColor }
    }

    // ==================== 无齿翼龙 ====================
    Item {
        id: pterodactyl
        x: -50
        width: 22; height: 16
        visible: false
        property int wingPhase: 0
        property int flyHeight: 0  // 0=低飞需跳, 1=高飞可过

        Component.onCompleted: y = groundY - 40

        Canvas {
            id: pteraCanvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                drawPtera(ctx, pterodactyl.wingPhase)
            }

            function drawPtera(ctx, wing) {
                var dc = gameWindow.dinoColor
                ctx.fillStyle = dc
                ctx.strokeStyle = dc
                ctx.lineWidth = 1

                // 身体
                ctx.beginPath()
                ctx.ellipse(8, 6, 8, 5)
                ctx.fill()

                // 头部/喙
                ctx.beginPath()
                ctx.moveTo(16, 6)
                ctx.lineTo(22, 4)
                ctx.lineTo(18, 8)
                ctx.closePath()
                ctx.fill()

                // 翅膀
                if (wing === 0) {
                    ctx.beginPath()
                    ctx.moveTo(10, 7)
                    ctx.lineTo(14, 0)
                    ctx.lineTo(6, 2)
                    ctx.closePath()
                    ctx.fill()
                } else {
                    ctx.beginPath()
                    ctx.moveTo(10, 7)
                    ctx.lineTo(14, 15)
                    ctx.lineTo(6, 14)
                    ctx.closePath()
                    ctx.fill()
                }

                // 尾巴
                ctx.beginPath()
                ctx.moveTo(0, 8)
                ctx.lineTo(-4, 6)
                ctx.lineTo(0, 7)
                ctx.closePath()
                ctx.fill()
            }
        }
    }

    // ==================== 分数显示 ====================
    // 常驻最高分 + 当前分
    Text {
        id: hiDisplay
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 12; anchors.topMargin: 4
        text: "HI " + String(highScore).padStart(5, '0')
        font.pixelSize: 10; font.bold: true
        color: textColor
        font.family: "Courier New"
    }
    Text {
        id: scoreDisplay
        anchors.right: parent.right
        anchors.top: hiDisplay.bottom
        anchors.rightMargin: 12; anchors.topMargin: 0
        text: String(score).padStart(5, '0')
        font.pixelSize: 10; font.bold: true
        color: textColor
        font.family: "Courier New"
    }

    // ==================== 提示文字 ====================
    Text {
        id: gameOverText
        anchors.horizontalCenter: parent.horizontalCenter
        y: 50
        text: "G A M E   O V E R"
        font.pixelSize: 11; font.bold: true
        color: textColor
        font.family: "Courier New"
        visible: false
    }
    Text {
        id: nightIndicator
        anchors.horizontalCenter: parent.horizontalCenter
        y: 68
        text: isNight ? "✦ 夜晚 ✦" : ""
        font.pixelSize: 8
        color: "#ffd700"
        font.family: "Courier New"
        visible: gameOver && isNight
    }
    Text {
        id: restartText
        anchors.horizontalCenter: parent.horizontalCenter
        y: 82
        text: "点按 / 空格 / ↑ 重新开始"
        font.pixelSize: 8; color: subColor
        visible: false
    }
    Text {
        id: startHint
        anchors.horizontalCenter: parent.horizontalCenter
        y: 60
        text: "点按 / 空格 / ↑ 开始游戏"
        font.pixelSize: 9; color: subColor
    }

    // ==================== 主循环 ====================
    Timer {
        id: gameLoop
        interval: 16
        running: gameRunning && !gameOver
        repeat: true

        onTriggered: {
            frameCount++
            groundOffset = (groundOffset + gameSpeed) % 22

            dinoYVelocity += gravity
            dino.y += dinoYVelocity
            if (dino.y >= dinoBaseY) {
                dino.y = dinoBaseY
                dinoYVelocity = 0
            }

            if (obstacleSpawnTimer > 0) obstacleSpawnTimer--

            updateCacti()
            updatePterodactyl()
            updateClouds()
            checkCollision()

            if (frameCount % 10 === 0) {
                score += 1
                if (score > highScore) {
                    highScore = score
                }
            }
            gameSpeed = baseSpeed + score * 0.0016
        }
    }

    // ==================== 仙人掌逻辑 ====================
    function updateCacti() {
        if (cactus1.visible) cactus1.x -= gameSpeed
        if (cactus2.visible) cactus2.x -= gameSpeed
        if (cactus1.x < -30) cactus1.visible = false
        if (cactus2.x < -30) cactus2.visible = false

        if (obstacleSpawnTimer > 0) return  // 共享冷却中，不生成

        if (Math.random() < 0.015) {
            var c = !cactus1.visible ? cactus1 :
                    (!cactus2.visible ? cactus2 : null)
            if (c) {
                c.x = gameWindow.width + Math.random() * 50
                c.visible = true
                obstacleSpawnTimer = minObstacleGap + Math.floor(Math.random() * 40)
            }
        }
    }

    // ==================== 翼龙逻辑（500分后启用） ====================
    function updatePterodactyl() {
        if (score < 500) return

        if (pterodactyl.visible) {
            pterodactyl.x -= gameSpeed  // 和仙人掌相同速度
            if (pterodactyl.x < -50) {
                pterodactyl.visible = false
            }
        }

        if (obstacleSpawnTimer > 0) return  // 共享冷却中，不生成

        if (!pterodactyl.visible && Math.random() < 0.006) {
            pterodactyl.flyHeight = Math.random() < 0.5 ? 0 : 1
            if (pterodactyl.flyHeight === 0) {
                pterodactyl.y = groundY - 28  // 低飞：需要跳跃
            } else {
                pterodactyl.y = groundY - 50  // 高飞：可直接走过
            }
            pterodactyl.x = gameWindow.width + Math.random() * 40
            pterodactyl.visible = true
            pteraCanvas.requestPaint()
            obstacleSpawnTimer = minObstacleGap + Math.floor(Math.random() * 40)
        }
    }

    function updateClouds() {
        if (isNight) return  // 夜晚跳过
        for (var i = 0; i < cloudRepeater.count; i++) {
            var cloud = cloudRepeater.itemAt(i)
            if (cloud) {
                cloud.cloudOffset -= 0.4
                if (cloud.cloudOffset < -gameWindow.width - 40)
                    cloud.cloudOffset = gameWindow.width + Math.random() * 60
            }
        }
    }

    // ==================== 碰撞检测 ====================
    function checkCollision() {
        var dr = Qt.rect(dino.x + 3, dino.y + 2, dino.width - 6, dino.height - 4)

        // 仙人掌碰撞
        var cacti = [cactus1, cactus2]
        for (var i = 0; i < cacti.length; i++) {
            var c = cacti[i]
            if (c.visible && rectsOverlap(dr, Qt.rect(c.x + 1, c.y + 1, c.width - 2, c.height - 2))) {
                endGame(); return
            }
        }

        // 翼龙碰撞
        if (pterodactyl.visible) {
            var pr = Qt.rect(pterodactyl.x + 2, pterodactyl.y + 2,
                             pterodactyl.width - 6, pterodactyl.height - 5)
            if (rectsOverlap(dr, pr)) {
                endGame(); return
            }
        }
    }

    function rectsOverlap(r1, r2) {
        return !(r2.x > r1.x + r1.width ||
                 r2.x + r2.width < r1.x ||
                 r2.y > r1.y + r1.height ||
                 r2.y + r2.height < r1.y)
    }

    // ==================== 游戏控制 ====================
    function startGame() {
        score = 0; gameSpeed = baseSpeed
        dino.y = dinoBaseY; dinoYVelocity = 0
        cactus1.visible = false; cactus1.x = -50
        cactus2.visible = false; cactus2.x = -50
        pterodactyl.visible = false; pterodactyl.x = -50
        obstacleSpawnTimer = 0
        gameOver = false; gameRunning = true
        gameOverText.visible = false; restartText.visible = false
        startHint.visible = false
        dino.legPhase = 0; dino.requestPaint()
        frameCount = 0
    }

    function jump() {
        if (!gameRunning && !gameOver) {
            startGame(); dinoYVelocity = jumpVelocity
        } else if (gameRunning && !gameOver && dino.y >= dinoBaseY) {
            dinoYVelocity = jumpVelocity
        } else if (gameOver) {
            startGame()
        }
    }

    function endGame() {
        gameOver = true; gameRunning = false
        if (score > highScore) {
            highScore = score
            saveHighScore()
        }
        gameOverText.visible = true; restartText.visible = true
        dino.requestPaint()
    }

    // ==================== 持久化 ====================
    function loadHighScore() {
        try {
            var db = LocalStorage.openDatabaseSync("DinoGameDB", "1.0", "Dino High Scores", 100000)
            db.transaction(function(tx) {
                tx.executeSql('CREATE TABLE IF NOT EXISTS hiscore (k TEXT PRIMARY KEY, v INTEGER)')
                var rs = tx.executeSql('SELECT v FROM hiscore WHERE k = "hi"')
                if (rs.rows.length > 0) {
                    highScore = rs.rows.item(0).v
                }
            })
        } catch(e) {
            // 无法访问存储时静默回退到内存
        }
    }

    function saveHighScore() {
        try {
            var db = LocalStorage.openDatabaseSync("DinoGameDB", "1.0", "Dino High Scores", 100000)
            db.transaction(function(tx) {
                tx.executeSql('CREATE TABLE IF NOT EXISTS hiscore (k TEXT PRIMARY KEY, v INTEGER)')
                tx.executeSql('INSERT OR REPLACE INTO hiscore (k, v) VALUES ("hi", ?)', [highScore])
            })
        } catch(e) {
            // 无法访问存储时静默回退到内存
        }
    }

    // ==================== 输入 ====================
    MouseArea {
        anchors.fill: parent
        enabled: gameWindow.enabled
        onClicked: jump()
    }
    Keys.onSpacePressed: jump()
    Keys.onUpPressed:    jump()
    Keys.onPressed: {
        if (event.key === Qt.Key_W && !event.isAutoRepeat) jump()
    }

    // ==================== 动画定时器 ====================
    Timer {
        id: legTimer
        interval: 100
        running: gameRunning && !gameOver
        repeat: true
        onTriggered: {
            dino.legPhase = 1 - dino.legPhase
            dino.requestPaint()
        }
    }

    // 翼龙翅膀动画
    Timer {
        id: wingTimer
        interval: 200
        running: gameRunning && !gameOver && pterodactyl.visible
        repeat: true
        onTriggered: {
            pterodactyl.wingPhase = 1 - pterodactyl.wingPhase
            pteraCanvas.requestPaint()
        }
    }

    Component.onCompleted: {
        loadHighScore()
        forceActiveFocus()
    }
}
