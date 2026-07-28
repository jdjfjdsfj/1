import QtQuick 2.15
import "qrc:/qml/commons"

Rectangle {
    id: root
    width: 320
    height: 170
    color: "#0B0F17"

    signal backButtonClicked()

    property string appFontFamily: "Microsoft YaHei"

    // 计算器状态
    property string currentInput: "0"
    property string previousValue: ""
    property string currentOperator: ""
    property bool waitingForOperand: false
    property string expression: ""
    property string errorMessage: ""

    // 按键反馈
    property var pressedKeys: ({})

    function clearAll() {
        currentInput = "0"
        previousValue = ""
        currentOperator = ""
        waitingForOperand = false
        expression = ""
        errorMessage = ""
    }

    function clearEntry() {
        currentInput = "0"
        errorMessage = ""
    }

    function backspace() {
        if (errorMessage !== "") {
            clearAll()
            return
        }
        if (waitingForOperand) return
        if (currentInput.length === 1) {
            currentInput = "0"
        } else {
            currentInput = currentInput.slice(0, -1)
        }
    }

    function inputDigit(digit) {
        if (errorMessage !== "") {
            clearAll()
        }
        if (waitingForOperand) {
            currentInput = digit
            waitingForOperand = false
        } else {
            if (currentInput === "0") {
                currentInput = digit
            } else if (currentInput.length < 12) {
                currentInput += digit
            }
        }
    }

    function inputDecimal() {
        if (errorMessage !== "") {
            clearAll()
        }
        if (waitingForOperand) {
            currentInput = "0."
            waitingForOperand = false
            return
        }
        if (currentInput.indexOf(".") === -1 && currentInput.length < 12) {
            currentInput += "."
        }
    }

    function calculate() {
        var prev = parseFloat(previousValue)
        var curr = parseFloat(currentInput)
        var result = 0

        switch (currentOperator) {
            case "+":
                result = prev + curr
                break
            case "−":
                result = prev - curr
                break
            case "×":
                result = prev * curr
                break
            case "÷":
                if (curr === 0) {
                    errorMessage = "不能除以零"
                    currentInput = "Error"
                    waitingForOperand = true
                    return
                }
                result = prev / curr
                break
            default:
                return
        }

        // 处理精度问题
        var resultStr = parseFloat(result.toPrecision(12)).toString()
        if (resultStr.length > 12) {
            resultStr = result.toExponential(6)
        }

        currentInput = resultStr
        previousValue = ""
        currentOperator = ""
        waitingForOperand = true
    }

    function performOperation(op) {
        if (errorMessage !== "") {
            clearAll()
            return
        }

        var inputValue = parseFloat(currentInput)

        if (previousValue === "") {
            previousValue = currentInput
        } else if (currentOperator !== "" && !waitingForOperand) {
            calculate()
            previousValue = currentInput
        } else {
            previousValue = currentInput
        }

        currentOperator = op
        waitingForOperand = true
        expression = previousValue + " " + op
    }

    function handleKeyPress(key) {
        pressedKeys[key] = true
        keyPressTimer.restart()

        if (key >= "0" && key <= "9") {
            inputDigit(key)
        } else if (key === ".") {
            inputDecimal()
        } else if (key === "C") {
            clearAll()
        } else if (key === "CE") {
            clearEntry()
        } else if (key === "⌫") {
            backspace()
        } else if (key === "+") {
            performOperation("+")
        } else if (key === "−") {
            performOperation("−")
        } else if (key === "×") {
            performOperation("×")
        } else if (key === "÷") {
            performOperation("÷")
        } else if (key === "=") {
            if (currentOperator !== "" && !waitingForOperand) {
                expression = previousValue + " " + currentOperator + " " + currentInput + " ="
                calculate()
            }
        } else if (key === "±") {
            if (currentInput !== "0" && errorMessage === "") {
                if (currentInput.charAt(0) === "-") {
                    currentInput = currentInput.slice(1)
                } else {
                    currentInput = "-" + currentInput
                }
            }
        } else if (key === "%") {
            if (errorMessage === "") {
                var val = parseFloat(currentInput)
                currentInput = (val / 100).toString()
            }
        }
    }

    Timer {
        id: keyPressTimer
        interval: 120
        repeat: false
        onTriggered: pressedKeys = ({})
    }

    // ========== 标题栏 ==========
    Rectangle {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 22
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
            width: 44
            height: 16
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            scale: backArea.pressed ? 0.95 : 1.0
            Behavior on scale { NumberAnimation { duration: 60 } }

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: backArea.pressed ? "#1F2937" : "#111827"
                border.width: 1
                border.color: "#243041"
            }

            Text {
                anchors.centerIn: parent
                text: "← 返回"
                font.pixelSize: 9
                color: "#E5E7EB"
                font.family: root.appFontFamily
            }

            MouseArea {
                id: backArea
                anchors.fill: parent
                anchors.margins: -6
                onClicked: root.backButtonClicked()
            }
        }

        Text {
            anchors.centerIn: parent
            text: "计算器"
            font.pixelSize: 11
            font.bold: true
            color: "#E5E7EB"
            font.family: root.appFontFamily
        }
    }

    // ========== 显示区域 ==========
    Rectangle {
        id: displayArea
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 42
        color: "#0B0F17"

        Column {
            anchors.fill: parent
            anchors.margins: 3
            anchors.rightMargin: 8
            spacing: 2

            Text {
                anchors.right: parent.right
                text: expression
                font.pixelSize: 9
                color: "#94A3B8"
                font.family: root.appFontFamily
                elide: Text.ElideLeft
                width: parent.width
                horizontalAlignment: Text.AlignRight
            }

            Text {
                anchors.right: parent.right
                text: errorMessage !== "" ? errorMessage : currentInput
                font.pixelSize: errorMessage !== "" ? 11 : 18
                font.bold: true
                color: errorMessage !== "" ? "#FCA5A5" : "#E5E7EB"
                font.family: root.appFontFamily
                elide: Text.ElideLeft
                width: parent.width
                horizontalAlignment: Text.AlignRight
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: "#1F2937"
        }
    }

    // ========== 按钮区域 ==========
    Flickable {
        id: buttonFlickable
        anchors.top: displayArea.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 3
        clip: true
        contentHeight: buttonColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2000

        property real btnHeight: 50
        property real btnWidth: (width - colSpacing * 3) / 4
        property real rowSpacing: 4
        property real colSpacing: 4

        Column {
            id: buttonColumn
            width: parent.width
            spacing: buttonFlickable.rowSpacing

            // 第1行
            Row {
                id: row1
                spacing: buttonFlickable.colSpacing
                width: parent.width
                height: buttonFlickable.btnHeight

                CalcButton { text: "C"; width: buttonFlickable.btnWidth; height: row1.height; bgColor: "#7f1d1d"; bgPressed: "#991b1b"; onClicked: handleKeyPress("C") }
                CalcButton { text: "删除"; width: buttonFlickable.btnWidth; height: row1.height; bgColor: "#374151"; bgPressed: "#4b5563"; onClicked: handleKeyPress("⌫") }
                CalcButton { text: "÷"; width: buttonFlickable.btnWidth; height: row1.height; bgColor: "#1e3a5f"; bgPressed: "#2563eb"; isOperator: currentOperator === "÷"; onClicked: handleKeyPress("÷") }
                CalcButton { text: "×"; width: buttonFlickable.btnWidth; height: row1.height; bgColor: "#1e3a5f"; bgPressed: "#2563eb"; isOperator: currentOperator === "×"; onClicked: handleKeyPress("×") }
            }

            // 第2行
            Row {
                id: row2
                spacing: buttonFlickable.colSpacing
                width: parent.width
                height: buttonFlickable.btnHeight

                CalcButton { text: "7"; width: buttonFlickable.btnWidth; height: row2.height; onClicked: handleKeyPress("7") }
                CalcButton { text: "8"; width: buttonFlickable.btnWidth; height: row2.height; onClicked: handleKeyPress("8") }
                CalcButton { text: "9"; width: buttonFlickable.btnWidth; height: row2.height; onClicked: handleKeyPress("9") }
                CalcButton { text: "−"; width: buttonFlickable.btnWidth; height: row2.height; bgColor: "#1e3a5f"; bgPressed: "#2563eb"; isOperator: currentOperator === "−"; onClicked: handleKeyPress("−") }
            }

            // 第3行
            Row {
                id: row3
                spacing: buttonFlickable.colSpacing
                width: parent.width
                height: buttonFlickable.btnHeight

                CalcButton { text: "4"; width: buttonFlickable.btnWidth; height: row3.height; onClicked: handleKeyPress("4") }
                CalcButton { text: "5"; width: buttonFlickable.btnWidth; height: row3.height; onClicked: handleKeyPress("5") }
                CalcButton { text: "6"; width: buttonFlickable.btnWidth; height: row3.height; onClicked: handleKeyPress("6") }
                CalcButton { text: "+"; width: buttonFlickable.btnWidth; height: row3.height; bgColor: "#1e3a5f"; bgPressed: "#2563eb"; isOperator: currentOperator === "+"; onClicked: handleKeyPress("+") }
            }

            // 第4-5行（合并，= 竖条）
            Row {
                spacing: buttonFlickable.colSpacing
                width: parent.width
                height: buttonFlickable.btnHeight * 2 + buttonFlickable.rowSpacing

                Column {
                    spacing: buttonFlickable.rowSpacing
                    width: buttonFlickable.btnWidth * 3 + buttonFlickable.colSpacing * 2
                    height: parent.height

                    // 子行4: 1 2 3
                    Row {
                        spacing: buttonFlickable.colSpacing
                        width: parent.width
                        height: buttonFlickable.btnHeight

                        CalcButton { text: "1"; width: buttonFlickable.btnWidth; height: buttonFlickable.btnHeight; onClicked: handleKeyPress("1") }
                        CalcButton { text: "2"; width: buttonFlickable.btnWidth; height: buttonFlickable.btnHeight; onClicked: handleKeyPress("2") }
                        CalcButton { text: "3"; width: buttonFlickable.btnWidth; height: buttonFlickable.btnHeight; onClicked: handleKeyPress("3") }
                    }

                    // 子行5: 0(wide) .
                    Row {
                        spacing: buttonFlickable.colSpacing
                        width: parent.width
                        height: buttonFlickable.btnHeight

                        CalcButton {
                            text: "0"
                            width: buttonFlickable.btnWidth * 2 + buttonFlickable.colSpacing
                            height: buttonFlickable.btnHeight
                            onClicked: handleKeyPress("0")
                        }
                        CalcButton { text: "."; width: buttonFlickable.btnWidth; height: buttonFlickable.btnHeight; onClicked: handleKeyPress(".") }
                    }
                }

                // 竖条 =
                CalcButton {
                    text: "="
                    width: buttonFlickable.btnWidth
                    height: parent.height
                    bgColor: "#065f46"
                    bgPressed: "#10b981"
                    onClicked: handleKeyPress("=")
                }
            }
        }

        // 底部渐隐提示
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 18
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: "#0B0F17" }
            }

            Text {
                anchors.centerIn: parent
                text: "▼"
                font.pixelSize: 10
                color: "#6B7280"
            }
        }
    }

    // ========== 按钮组件 ==========
    component CalcButton: Rectangle {
        id: calcBtn
        property string text: ""
        property color bgColor: "#1f2937"
        property color bgPressed: "#374151"
        property bool isOperator: false
        signal clicked()

        radius: 6
        color: {
            if (isOperator) return "#1e40af"
            if (mouseArea.pressed || root.pressedKeys[text]) return bgPressed
            return bgColor
        }
        border.width: isOperator ? 1 : 0
        border.color: "#3b82f6"

        scale: mouseArea.pressed ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: 60 } }

        Text {
            anchors.centerIn: parent
            text: calcBtn.text
            font.pixelSize: parent.height * 0.45
            font.bold: true
            color: {
                if (calcBtn.text === "C") return "#fca5a5"
                if (calcBtn.text === "=") return "#6ee7b7"
                if (["÷", "×", "−", "+"].indexOf(calcBtn.text) !== -1) return "#93c5fd"
                return "#E5E7EB"
            }
            font.family: root.appFontFamily
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            onClicked: calcBtn.clicked()
        }
    }
}
