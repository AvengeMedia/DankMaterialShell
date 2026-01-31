import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankModal {
    id: root

    layerNamespace: "dms:color-picker"

    HyprlandFocusGrab {
        windows: [root.contentWindow]
        active: root.useHyprlandFocusGrab && root.shouldHaveFocus
    }

    property string pickerTitle: I18n.tr("Choose Color")
    property color selectedColor: SessionData.recentColors.length > 0 ? SessionData.recentColors[0] : Theme.primary
    property var onColorSelectedCallback: null

    signal colorSelected(color selectedColor)

    property color currentColor: Theme.primary
    property real hue: 0
    property real saturation: 1
    property real value: 1
    property real alpha: 1
    property real gradientX: 0
    property real gradientY: 0

    readonly property var standardColors: ["#f44336", "#e91e63", "#9c27b0", "#673ab7", "#3f51b5", "#2196f3", "#03a9f4", "#00bcd4", "#009688", "#4caf50", "#8bc34a", "#cddc39", "#ffeb3b", "#ffc107", "#ff9800", "#ff5722", "#d32f2f", "#c2185b", "#7b1fa2", "#512da8", "#303f9f", "#1976d2", "#0288d1", "#0097a7", "#00796b", "#388e3c", "#689f38", "#afb42b", "#fbc02d", "#ffa000", "#f57c00", "#e64a19", "#c62828", "#ad1457", "#6a1b9a", "#4527a0", "#283593", "#1565c0", "#0277bd", "#00838f", "#00695c", "#2e7d32", "#558b2f", "#9e9d24", "#f9a825", "#ff8f00", "#ef6c00", "#d84315", "#ffffff", "#9e9e9e", "#212121"]

    function show() {
        currentColor = selectedColor;
        updateFromColor(currentColor);
        open();
    }

    function hide() {
        onColorSelectedCallback = null;
        close();
    }

    function hideInstant() {
        instantClose();
    }

    function toggle() {
        if (shouldBeVisible) {
          hide();
        } else {
          show();
        }
    }

    function toggleInstant() {
        if (shouldBeVisible) {
          hideInstant();
        } else {
          show();
        }
    }

    onColorSelected: color => {
        if (onColorSelectedCallback) {
            onColorSelectedCallback(color);
        }
    }

    function copyColorToClipboard(colorValue) {
        Quickshell.execDetached(["dms", "cl", "copy", colorValue]);
        ToastService.showInfo(`Color ${colorValue} copied`);
        SessionData.addRecentColor(currentColor);
    }

    function updateFromColor(color) {
        hue = color.hsvHue;
        saturation = color.hsvSaturation;
        value = color.hsvValue;
        alpha = color.a;
        gradientX = saturation;
        gradientY = 1 - value;
    }

    function updateColor() {
        currentColor = Qt.hsva(hue, saturation, value, alpha);
    }

    function updateColorFromGradient(x, y) {
        saturation = Math.max(0, Math.min(1, x));
        value = Math.max(0, Math.min(1, 1 - y));
        updateColor();
        selectedColor = currentColor;
    }

    function applyPickedColor(colorStr) {
        if (colorStr.length < 7 || !colorStr.startsWith('#'))
            return;
        const pickedColor = Qt.color(colorStr);
        root.selectedColor = pickedColor;
        root.currentColor = pickedColor;
        root.updateFromColor(pickedColor);
        copyColorToClipboard(colorStr);
        root.show();
    }

    function pickColorFromScreen() {
        hideInstant();
        Proc.runCommand("dms-color-pick", ["dms", "color", "pick", "--json"], (output, exitCode) => {
            if (exitCode !== 0) {
                console.warn("dms color pick exited with code:", exitCode);
                root.show();
                return;
            }
            try {
                const result = JSON.parse(output);
                if (result.hex) {
                    applyPickedColor(result.hex);
                } else {
                    console.warn("Failed to parse dms color pick output: missing hex");
                    root.show();
                }
            } catch (e) {
                console.warn("Failed to parse dms color pick JSON:", e);
                root.show();
            }
        }, 0, Proc.noTimeout);
    }

    modalWidth: 680
    modalHeight: contentLoader.item ? contentLoader.item.implicitHeight + Theme.spacingM * 2 : 680
    backgroundColor: Theme.surfaceContainer
    cornerRadius: Theme.cornerRadius
    borderColor: Theme.outlineMedium
    borderWidth: 1
    keepContentLoaded: true
    allowStacking: true

    onBackgroundClicked: hide()

    IpcHandler {
      function open(): string {
        root.show();
        return "COLOR_PICKER_MODAL_OPEN_SUCCESS";
      }

      function close(): string {
        root.hide();
        return "COLOR_PICKER_MODAL_CLOSE_SUCCESS";
      }

      function closeInstant(): string {
        root.hideInstant();
        return "COLOR_PICKER_MODAL_CLOSE_INSTANT_SUCCESS";
      }

      function toggle(): string {
        root.toggle();
        return "COLOR_PICKER_MODAL_TOGGLE_SUCCESS";
      }

      function toggleInstant(): string {
        root.toggleInstant();
        return "COLOR_PICKER_MODAL_TOGGLE_INSTANT_SUCCESS";
      }

      target: "color-picker"
    }

    content: Component {
        FocusScope {
            id: colorContent

            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true

            property alias hexInput: hexInput

            anchors.fill: parent
            implicitHeight: mainColumn.implicitHeight
            focus: true

            Keys.onEscapePressed: event => {
                root.hide();
                event.accepted = true;
            }

            Column {
                id: mainColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
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
                            anchors.left: parent.left
                        }

                        StyledText {
                            text: I18n.tr("Select a color from the palette or use custom sliders")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceTextMedium
                            anchors.left: parent.left
                        }
                    }

                    DankActionButton {
                        iconName: "colorize"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: () => {
                            root.pickColorFromScreen();
                        }
                    }

                    DankActionButton {
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: () => {
                            root.hide();
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
                                    GradientStop {
                                        position: 0.0
                                        color: "#ffffff"
                                    }
                                    GradientStop {
                                        position: 1.0
                                        color: "transparent"
                                    }
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    orientation: Gradient.Vertical
                                    GradientStop {
                                        position: 0.0
                                        color: "transparent"
                                    }
                                    GradientStop {
                                        position: 1.0
                                        color: "#000000"
                                    }
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
                                const x = Math.max(0, Math.min(1, mouse.x / width));
                                const y = Math.max(0, Math.min(1, mouse.y / height));
                                root.gradientX = x;
                                root.gradientY = y;
                                root.updateColorFromGradient(x, y);
                            }
                            onPositionChanged: mouse => {
                                if (pressed) {
                                    const x = Math.max(0, Math.min(1, mouse.x / width));
                                    const y = Math.max(0, Math.min(1, mouse.y / height));
                                    root.gradientX = x;
                                    root.gradientY = y;
                                    root.updateColorFromGradient(x, y);
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
                            GradientStop {
                                position: 0.00
                                color: "#ff0000"
                            }
                            GradientStop {
                                position: 0.17
                                color: "#ffff00"
                            }
                            GradientStop {
                                position: 0.33
                                color: "#00ff00"
                            }
                            GradientStop {
                                position: 0.50
                                color: "#00ffff"
                            }
                            GradientStop {
                                position: 0.67
                                color: "#0000ff"
                            }
                            GradientStop {
                                position: 0.83
                                color: "#ff00ff"
                            }
                            GradientStop {
                                position: 1.00
                                color: "#ff0000"
                            }
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
                                const h = Math.max(0, Math.min(1, mouse.y / height));
                                root.hue = h;
                                root.updateColor();
                                root.selectedColor = root.currentColor;
                            }
                            onPositionChanged: mouse => {
                                if (pressed) {
                                    const h = Math.max(0, Math.min(1, mouse.y / height));
                                    root.hue = h;
                                    root.updateColor();
                                    root.selectedColor = root.currentColor;
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
                        anchors.left: parent.left
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
                                    const pickedColor = Qt.color(modelData);
                                    root.selectedColor = pickedColor;
                                    root.currentColor = pickedColor;
                                    root.updateFromColor(pickedColor);
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
                                anchors.left: parent.left
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
                                                return SessionData.recentColors[index];
                                            }
                                            return Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency);
                                        }

                                        opacity: index < SessionData.recentColors.length ? 1.0 : 0.3

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: index < SessionData.recentColors.length ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            enabled: index < SessionData.recentColors.length
                                            onClicked: () => {
                                                if (index < SessionData.recentColors.length) {
                                                    const pickedColor = SessionData.recentColors[index];
                                                    root.selectedColor = pickedColor;
                                                    root.currentColor = pickedColor;
                                                    root.updateFromColor(pickedColor);
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
                                anchors.left: parent.left
                            }

                            DankSlider {
                                width: parent.width
                                value: Math.round(root.alpha * 100)
                                minimum: 0
                                maximum: 100
                                showValue: false
                                onSliderValueChanged: newValue => {
                                    root.alpha = newValue / 100;
                                    root.updateColor();
                                    root.selectedColor = root.currentColor;
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

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: (parent.width - Theme.spacingM * 2) / 3
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Hex")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceTextMedium
                                font.weight: Font.Medium
                                anchors.left: parent.left
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingXS

                                DankTextField {
                                    id: hexInput
                                    width: parent.width - 36
                                    height: 36
                                    text: root.currentColor.toString()
                                    font.pixelSize: Theme.fontSizeMedium
                                    textColor: {
                                        if (text.length === 0)
                                            return Theme.surfaceText;
                                        const hexPattern = /^#?[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/;
                                        return hexPattern.test(text) ? Theme.surfaceText : Theme.error;
                                    }
                                    placeholderText: "#000000"
                                    backgroundColor: Theme.surfaceHover
                                    borderWidth: 1
                                    focusedBorderWidth: 2
                                    topPadding: Theme.spacingS
                                    bottomPadding: Theme.spacingS
                                    onAccepted: () => {
                                        const hexPattern = /^#?[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/;
                                        if (!hexPattern.test(text))
                                            return;
                                        const color = Qt.color(text);
                                        if (color) {
                                            root.selectedColor = color;
                                            root.currentColor = color;
                                            root.updateFromColor(color);
                                        }
                                    }
                                }

                                DankActionButton {
                                    iconName: "content_copy"
                                    iconSize: Theme.iconSize - 6
                                    iconColor: Theme.surfaceText
                                    buttonSize: 36
                                    anchors.verticalCenter: parent.verticalCenter
                                    onClicked: () => {
                                        root.copyColorToClipboard(hexInput.text);
                                    }
                                }
                            }
                        }

                        Column {
                            width: (parent.width - Theme.spacingM * 2) / 3
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("RGB")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceTextMedium
                                font.weight: Font.Medium
                                anchors.left: parent.left
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingXS

                                Rectangle {
                                    width: parent.width - 36
                                    height: 36
                                    radius: Theme.cornerRadius
                                    color: Theme.surfaceHover
                                    border.color: Theme.outline
                                    border.width: 1

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: {
                                            const r = Math.round(root.currentColor.r * 255);
                                            const g = Math.round(root.currentColor.g * 255);
                                            const b = Math.round(root.currentColor.b * 255);
                                            if (root.alpha < 1) {
                                                const a = Math.round(root.alpha * 255);
                                                return `${r}, ${g}, ${b}, ${a}`;
                                            }
                                            return `${r}, ${g}, ${b}`;
                                        }
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                    }
                                }

                                DankActionButton {
                                    iconName: "content_copy"
                                    iconSize: Theme.iconSize - 6
                                    iconColor: Theme.surfaceText
                                    buttonSize: 36
                                    anchors.verticalCenter: parent.verticalCenter
                                    onClicked: () => {
                                        const r = Math.round(root.currentColor.r * 255);
                                        const g = Math.round(root.currentColor.g * 255);
                                        const b = Math.round(root.currentColor.b * 255);
                                        let rgbString;
                                        if (root.alpha < 1) {
                                            const a = Math.round(root.alpha * 255);
                                            rgbString = `rgba(${r}, ${g}, ${b}, ${a})`;
                                        } else {
                                            rgbString = `rgb(${r}, ${g}, ${b})`;
                                        }
                                        Quickshell.execDetached(["dms", "cl", "copy", rgbString]);
                                        ToastService.showInfo(`${rgbString} copied`);
                                    }
                                }
                            }
                        }

                        Column {
                            width: (parent.width - Theme.spacingM * 2) / 3
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("HSV")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceTextMedium
                                font.weight: Font.Medium
                                anchors.left: parent.left
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingXS

                                Rectangle {
                                    width: parent.width - 36
                                    height: 36
                                    radius: Theme.cornerRadius
                                    color: Theme.surfaceHover
                                    border.color: Theme.outline
                                    border.width: 1

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: {
                                            const h = Math.round(root.hue * 360);
                                            const s = Math.round(root.saturation * 100);
                                            const v = Math.round(root.value * 100);
                                            if (root.alpha < 1) {
                                                const a = Math.round(root.alpha * 100);
                                                return `${h}°, ${s}%, ${v}%, ${a}%`;
                                            }
                                            return `${h}°, ${s}%, ${v}%`;
                                        }
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                    }
                                }

                                DankActionButton {
                                    iconName: "content_copy"
                                    iconSize: Theme.iconSize - 6
                                    iconColor: Theme.surfaceText
                                    buttonSize: 36
                                    anchors.verticalCenter: parent.verticalCenter
                                    onClicked: () => {
                                        const h = Math.round(root.hue * 360);
                                        const s = Math.round(root.saturation * 100);
                                        const v = Math.round(root.value * 100);
                                        let hsvString;
                                        if (root.alpha < 1) {
                                            const a = Math.round(root.alpha * 100);
                                            hsvString = `${h}, ${s}, ${v}, ${a}`;
                                        } else {
                                            hsvString = `${h}, ${s}, ${v}`;
                                        }
                                        Quickshell.execDetached(["dms", "cl", "copy", hsvString]);
                                        ToastService.showInfo(`HSV ${hsvString} copied`);
                                    }
                                }
                            }
                        }
                    }

                    DankButton {
                        visible: root.onColorSelectedCallback !== null && root.onColorSelectedCallback !== undefined
                        width: 70
                        buttonHeight: 36
                        text: I18n.tr("Save")
                        backgroundColor: Theme.primary
                        textColor: Theme.background
                        anchors.right: parent.right
                        onClicked: {
                            SessionData.addRecentColor(root.currentColor);
                            root.colorSelected(root.currentColor);
                            root.hide();
                        }
                    }
                }
            }
        }
    }
}
