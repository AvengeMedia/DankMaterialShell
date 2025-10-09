import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    property string pickerTitle: "Choose Color"
    property color selectedColor: Theme.primary
    property bool shouldBeVisible: false
    property var onColorSelectedCallback: null

    signal colorSelected(color selectedColor)

    property color currentColor: Theme.primary
    property real hue: 0
    property real saturation: 1
    property real value: 1
    property real alpha: 1
    property real gradientX: 0
    property real gradientY: 0

    function open() {
        currentColor = selectedColor
        updateFromColor(currentColor)
        shouldBeVisible = true
        Qt.callLater(() => colorContent.forceActiveFocus())
    }

    function close() {
        shouldBeVisible = false
        onColorSelectedCallback = null
    }

    function show() {
        open()
    }

    function hide() {
        close()
    }

    onColorSelected: (color) => {
        if (onColorSelectedCallback) {
            onColorSelectedCallback(color)
        }
    }

    function copyColorToClipboard(colorValue) {
        Quickshell.execDetached(["sh", "-c", `echo "${colorValue}" | wl-copy`])
        ToastService.showInfo(`Color ${colorValue} copied`)
        SessionData.addRecentColor(currentColor)
    }

    function updateFromColor(color) {
        hue = color.hsvHue
        saturation = color.hsvSaturation
        value = color.hsvValue
        alpha = color.a
        gradientX = saturation
        gradientY = 1 - value
    }

    function updateColor() {
        currentColor = Qt.hsva(hue, saturation, value, alpha)
    }

    function updateColorFromGradient(x, y) {
        saturation = Math.max(0, Math.min(1, x))
        value = Math.max(0, Math.min(1, 1 - y))
        updateColor()
    }

    function pickColorFromScreen() {
        close()
        hyprpickerProcess.running = true
    }

    Process {
        id: hyprpickerProcess
        running: false
        command: ["hyprpicker", "--format=hex"]

        stdout: SplitParser {
            onRead: data => {
                const colorStr = data.trim()
                if (colorStr.length >= 7 && colorStr.startsWith('#')) {
                    root.currentColor = colorStr
                    root.updateFromColor(root.currentColor)
                    hexInput.text = root.currentColor.toString()
                    copyColorToClipboard(colorStr)
                    root.open()
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("hyprpicker exited with code:", exitCode)
            }
            root.open()
        }
    }

    readonly property var standardColors: [
        "#f44336", "#e91e63", "#9c27b0", "#673ab7", "#3f51b5", "#2196f3", "#03a9f4", "#00bcd4",
        "#009688", "#4caf50", "#8bc34a", "#cddc39", "#ffeb3b", "#ffc107", "#ff9800", "#ff5722",
        "#d32f2f", "#c2185b", "#7b1fa2", "#512da8", "#303f9f", "#1976d2", "#0288d1", "#0097a7",
        "#00796b", "#388e3c", "#689f38", "#afb42b", "#fbc02d", "#ffa000", "#f57c00", "#e64a19",
        "#c62828", "#ad1457", "#6a1b9a", "#4527a0", "#283593", "#1565c0", "#0277bd", "#00838f",
        "#00695c", "#2e7d32", "#558b2f", "#9e9d24", "#f9a825", "#ff8f00", "#ef6c00", "#d84315",
        "#ffffff", "#9e9e9e", "#212121"
    ]

    visible: shouldBeVisible

    WlrLayershell.namespace: "quickshell:color-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()

        Rectangle {
            color: "#80000000"
            anchors.fill: parent
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 680
        height: 680
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        border.color: Theme.outlineMedium
        border.width: 1

        MouseArea {
            anchors.fill: parent
            onClicked: {} // Prevent clicks from propagating to background
        }

        FocusScope {
            id: colorContent

            anchors.fill: parent
            focus: root.shouldBeVisible

            Keys.onEscapePressed: event => {
                root.close()
                event.accepted = true
            }

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    Column {
                        width: parent.width - 90
                        spacing: Theme.spacingXS

                        StyledText {
                            text: root.pickerTitle
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: I18n.tr("Select a color from the palette or use custom sliders")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceTextMedium
                        }
                    }

                    DankActionButton {
                        iconName: "colorize"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: () => {
                            pickColorFromScreen()
                        }
                    }

                    DankActionButton {
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: () => {
                            root.close()
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    Rectangle {
                        id: gradientPicker
                        width: parent.width - 70
                        height: 280
                        radius: Theme.cornerRadius
                        border.color: Theme.outlineStrong
                        border.width: 1
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.hsva(root.hue, 1, 1, 1)

                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "#ffffff" }
                                    GradientStop { position: 1.0; color: "transparent" }
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    orientation: Gradient.Vertical
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: "#000000" }
                                }
                            }
                        }

                        Rectangle {
                            id: pickerCircle
                            width: 16
                            height: 16
                            radius: 8
                            border.color: "white"
                            border.width: 2
                            color: "transparent"
                            x: root.gradientX * parent.width - width / 2
                            y: root.gradientY * parent.height - height / 2

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - 4
                                height: parent.height - 4
                                radius: width / 2
                                border.color: "black"
                                border.width: 1
                                color: "transparent"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.CrossCursor
                            onPressed: mouse => {
                                const x = Math.max(0, Math.min(1, mouse.x / width))
                                const y = Math.max(0, Math.min(1, mouse.y / height))
                                root.gradientX = x
                                root.gradientY = y
                                root.updateColorFromGradient(x, y)
                            }
                            onPositionChanged: mouse => {
                                if (pressed) {
                                    const x = Math.max(0, Math.min(1, mouse.x / width))
                                    const y = Math.max(0, Math.min(1, mouse.y / height))
                                    root.gradientX = x
                                    root.gradientY = y
                                    root.updateColorFromGradient(x, y)
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: hueSlider
                        width: 50
                        height: 280
                        radius: Theme.cornerRadius
                        border.color: Theme.outlineStrong
                        border.width: 1

                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.00; color: "#ff0000" }
                            GradientStop { position: 0.17; color: "#ffff00" }
                            GradientStop { position: 0.33; color: "#00ff00" }
                            GradientStop { position: 0.50; color: "#00ffff" }
                            GradientStop { position: 0.67; color: "#0000ff" }
                            GradientStop { position: 0.83; color: "#ff00ff" }
                            GradientStop { position: 1.00; color: "#ff0000" }
                        }

                        Rectangle {
                            id: hueIndicator
                            width: parent.width
                            height: 4
                            color: "white"
                            border.color: "black"
                            border.width: 1
                            y: root.hue * parent.height - height / 2
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.SizeVerCursor
                            onPressed: mouse => {
                                const h = Math.max(0, Math.min(1, mouse.y / height))
                                root.hue = h
                                root.updateColor()
                            }
                            onPositionChanged: mouse => {
                                if (pressed) {
                                    const h = Math.max(0, Math.min(1, mouse.y / height))
                                    root.hue = h
                                    root.updateColor()
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: I18n.tr("Material Colors")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }

                    GridView {
                        width: parent.width
                        height: 140
                        cellWidth: 38
                        cellHeight: 38
                        clip: true
                        interactive: false
                        model: root.standardColors

                        delegate: Rectangle {
                            width: 36
                            height: 36
                            color: modelData
                            radius: 4
                            border.color: Theme.outlineStrong
                            border.width: 1

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: () => {
                                    root.currentColor = modelData
                                    root.updateFromColor(root.currentColor)
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        Column {
                            width: 210
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Recent Colors")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingXS

                                Repeater {
                                    model: 5

                                    Rectangle {
                                        width: 36
                                        height: 36
                                        radius: 4
                                        border.color: Theme.outlineStrong
                                        border.width: 1

                                        color: {
                                            if (index < SessionData.recentColors.length) {
                                                return SessionData.recentColors[index]
                                            }
                                            return Theme.surfaceContainerHigh
                                        }

                                        opacity: index < SessionData.recentColors.length ? 1.0 : 0.3

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: index < SessionData.recentColors.length ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            enabled: index < SessionData.recentColors.length
                                            onClicked: () => {
                                                if (index < SessionData.recentColors.length) {
                                                    root.currentColor = SessionData.recentColors[index]
                                                    root.updateFromColor(root.currentColor)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width - 330
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Opacity")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            DankSlider {
                                width: parent.width
                                value: Math.round(root.alpha * 100)
                                minimum: 0
                                maximum: 100
                                showValue: false
                                onSliderValueChanged: (newValue) => {
                                    root.alpha = newValue / 100
                                    root.updateColor()
                                }
                            }
                        }

                        Rectangle {
                            width: 100
                            height: 50
                            radius: Theme.cornerRadius
                            color: root.currentColor
                            border.color: Theme.outlineStrong
                            border.width: 2
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: I18n.tr("Hex:")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceTextMedium
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DankTextField {
                        id: hexInput
                        width: 120
                        height: 38
                        text: root.currentColor.toString()
                        font.pixelSize: Theme.fontSizeMedium
                        textColor: {
                            if (text.length === 0) return Theme.surfaceText
                            const hexPattern = /^#?[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/
                            return hexPattern.test(text) ? Theme.surfaceText : Theme.error
                        }
                        placeholderText: "#000000"
                        backgroundColor: Theme.surfaceHover
                        borderWidth: 1
                        focusedBorderWidth: 2
                        topPadding: Theme.spacingS
                        bottomPadding: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        onAccepted: () => {
                            const hexPattern = /^#?[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/
                            if (!hexPattern.test(text)) return
                            const color = Qt.color(text)
                            if (color) {
                                root.currentColor = color
                                root.updateFromColor(color)
                            }
                        }
                    }

                    DankButton {
                        width: 80
                        buttonHeight: 36
                        text: I18n.tr("Apply")
                        backgroundColor: Theme.primary
                        textColor: Theme.background
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            const hexPattern = /^#?[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/
                            if (!hexPattern.test(hexInput.text)) return
                            const color = Qt.color(hexInput.text)
                            if (color) {
                                root.currentColor = color
                                root.updateFromColor(color)
                                root.selectedColor = root.currentColor
                                colorSelected(root.currentColor)
                                SessionData.addRecentColor(root.currentColor)
                                root.close()
                            }
                        }
                    }

                    Item {
                        width: parent.width - 460
                        height: 1
                    }

                    DankButton {
                        width: 70
                        buttonHeight: 36
                        text: I18n.tr("Cancel")
                        backgroundColor: "transparent"
                        textColor: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.close()
                        
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.cornerRadius
                            color: "transparent"
                            border.color: Theme.surfaceVariantAlpha
                            border.width: 1
                            z: -1
                        }
                    }

                    DankButton {
                        width: 70
                        buttonHeight: 36
                        text: I18n.tr("Copy")
                        backgroundColor: Theme.primary
                        textColor: Theme.background
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            const colorString = root.currentColor.toString()
                            copyColorToClipboard(colorString)
                        }
                    }
                }
            }
        }
    }
}
