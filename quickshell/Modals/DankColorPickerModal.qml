import QtQuick
import Quickshell.Io
import qs.Common
import qs.Modals.Common
import qs.Modules.ColorPicker

DankModal {
    id: root

    layerNamespace: "dms:color-picker"

    property string pickerTitle: I18n.tr("Choose Color")
    property color selectedColor: SessionData.recentColors.length > 0 ? SessionData.recentColors[0] : Theme.primary
    property var onColorSelectedCallback: null

    signal colorSelected(color selectedColor)

    function show() {
        open();
        contentLoader?.item?.setColor(selectedColor);
    }

    function hide() {
        onColorSelectedCallback = null;
        close();
    }

    function hideInstant() {
        instantClose();
    }

    function toggle() {
        shouldBeVisible ? hide() : show();
    }

    function toggleInstant() {
        shouldBeVisible ? hideInstant() : show();
    }

    onSelectedColorChanged: contentLoader?.item?.setColor(selectedColor)

    onColorSelected: color => {
        if (onColorSelectedCallback)
            onColorSelectedCallback(color);
    }

    modalWidth: 680
    modalHeight: contentLoader?.item ? contentLoader.item.implicitHeight : 680
    backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
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

        function openColor(color: string): string {
            root.selectedColor = Qt.color(color);
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

    content: Component {
        ColorPickerContent {
            anchors.fill: parent
            pickerTitle: root.pickerTitle
            initialColor: root.selectedColor
            showSaveButton: root.onColorSelectedCallback !== null && root.onColorSelectedCallback !== undefined
            onColorSelected: color => root.colorSelected(color)
            onCloseRequested: root.hide()
            onHideRequested: root.hideInstant()
            onShowRequested: root.open()
        }
    }
}
