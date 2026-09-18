import QtQuick
import Quickshell.Io
import qs.Common
import qs.Modules.ColorPicker
import qs.Widgets
import qs.DankCommon.Widgets as CommonWidgets

DankFloatingWindow {
    id: root

    property string pickerTitle: I18n.tr("Choose color", "color picker title")
    property color selectedColor: SessionData.recentColors.length > 0 ? SessionData.recentColors[0] : Theme.primary
    property var onColorSelectedCallback: null
    property alias shouldBeVisible: root.visible
    readonly property alias pickerContent: pickerContent

    signal colorSelected(color selectedColor)

    objectName: "colorPickerModal"
    title: pickerTitle
    implicitWidth: Theme.dialogMaxWidth
    implicitHeight: Math.min(pickerContent.implicitHeight, (screen?.height ?? 1080) - Theme.spacingXL * 2)
    minimumSize: Qt.size(Math.min(Theme.smallBreakpoint, screen?.width ?? Theme.smallBreakpoint), Math.min(Theme.fieldDefaultWidth * 2, screen?.height ?? Theme.fieldDefaultWidth * 2))
    visible: false
    contentVisible: !captureGuard.active

    function show() {
        captureGuard.cancel();
        pickerContent.cancelScreenPick();
        pickerContent.setColor(selectedColor);
        visible = true;
        focusTimer.restart();
    }

    function hide() {
        captureGuard.cancel();
        pickerContent.cancelScreenPick();
        visible = false;
        onColorSelectedCallback = null;
    }

    function open() {
        show();
    }

    function close() {
        hide();
    }

    function hideInstant() {
        hide();
    }

    function toggle() {
        visible ? hide() : show();
    }

    function toggleInstant() {
        toggle();
    }

    onSelectedColorChanged: pickerContent.setColor(selectedColor)
    onClosed: hide()
    onColorSelected: color => {
        if (typeof onColorSelectedCallback === "function")
            onColorSelectedCallback(color);
    }

    Timer {
        id: focusTimer
        interval: 0
        onTriggered: {
            if (root.visible)
                pickerContent.focusInitial();
        }
    }

    IpcHandler {
        function open(): string {
            root.show();
            return "COLOR_PICKER_MODAL_OPEN_SUCCESS";
        }

        function openColor(color: string): string {
            const text = color.trim();
            try {
                root.selectedColor = Qt.color(/^[0-9a-f]{6}([0-9a-f]{2})?$/i.test(text) ? "#" + text : text);
            } catch (error) {
                return "COLOR_PICKER_INVALID_COLOR";
            }
            return open();
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

    ColorPickerContent {
        id: pickerContent

        anchors.fill: parent
        windowControls: windowControls
        pickerTitle: root.pickerTitle
        initialColor: root.selectedColor
        showSaveButton: typeof root.onColorSelectedCallback === "function"
        onColorSelected: color => root.colorSelected(color)
        onCloseRequested: root.hide()
        onHideRequested: captureGuard.prepare()
        onShowRequested: {
            captureGuard.cancel();
            root.visible = true;
            focusTimer.restart();
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: root
    }

    CommonWidgets.WindowCaptureGuard {
        id: captureGuard

        targetWindow: root
        onReady: {
            root.visible = false;
            pickerContent.startScreenPick();
        }
    }
}
