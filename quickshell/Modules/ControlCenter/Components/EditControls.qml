pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Modules.ControlCenter
import qs.Modules.ControlCenter.Widgets
import qs.Widgets

Row {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var availableWidgets: []
    property var popupScreen: null
    property real popoutX: 0
    property real popoutY: 0
    property real popoutWidth: 0
    property real popoutHeight: 0

    signal addWidget(string widgetId)
    signal resetToDefault
    signal clearAll

    readonly property real buttonWidth: (width - spacing * 2) / 3

    height: Theme.buttonHeightS
    spacing: Theme.spacingS

    function openWidgetLibrary() {
        libraryLoader.active = true;
        const window = libraryLoader.item;
        if (!window)
            return;
        if (popupScreen)
            window.screen = popupScreen;
        window.visible = true;
    }

    function closeWidgetLibrary() {
        if (!libraryLoader.item)
            return;
        libraryLoader.item.visible = false;
    }

    onAddWidget: closeWidgetLibrary()
    onVisibleChanged: {
        if (visible)
            return;
        closeWidgetLibrary();
        libraryLoader.active = false;
    }

    LazyLoader {
        id: libraryLoader

        active: false

        PanelWindow {
            id: addWidgetWindow

            screen: root.popupScreen
            visible: false
            color: "transparent"

            WlrLayershell.namespace: "dms:control-center-widget-library"
            WlrLayershell.layer: WlrLayershell.Overlay
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.keyboardFocus: PopoutManager.screenshotActive ? WlrKeyboardFocus.None : (visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None)

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            WindowBlur {
                targetWindow: addWidgetWindow
                blurX: widgetLibraryPanel.x
                blurY: widgetLibraryPanel.y
                blurWidth: addWidgetWindow.visible ? widgetLibraryPanel.width : 0
                blurHeight: addWidgetWindow.visible ? widgetLibraryPanel.height : 0
                blurRadius: Theme.windowRadius
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: root.closeWidgetLibrary()
            }

            CcWidgetLibrary {
                id: widgetLibraryPanel

                width: Math.min(implicitWidth, addWidgetWindow.width - Theme.spacingL * 2)
                height: Math.min(implicitHeight, addWidgetWindow.height - Theme.spacingL * 2)
                x: Math.round(Math.max(Theme.spacingL, Math.min(addWidgetWindow.width - width - Theme.spacingL, root.popoutWidth > 0 ? root.popoutX + (root.popoutWidth - width) / 2 : (addWidgetWindow.width - width) / 2)))
                y: Math.round(Math.max(Theme.spacingL, Math.min(addWidgetWindow.height - height - Theme.spacingL, root.popoutHeight > 0 ? root.popoutY + (root.popoutHeight - height) / 2 : (addWidgetWindow.height - height) / 2)))
                widgets: root.availableWidgets
                onChosen: widgetId => root.addWidget(widgetId)
                onDismissed: root.closeWidgetLibrary()
            }

            onVisibleChanged: {
                if (visible)
                    widgetLibraryPanel.reset();
            }
        }
    }

    DankButton {
        width: root.buttonWidth
        buttonHeight: Theme.buttonHeightS
        iconName: "add"
        text: I18n.tr("Add widget")
        backgroundColor: Theme.secondaryContainer
        textColor: Theme.onSecondaryContainer
        onClicked: root.openWidgetLibrary()
    }

    DankButton {
        width: root.buttonWidth
        buttonHeight: Theme.buttonHeightS
        iconName: "settings_backup_restore"
        text: I18n.tr("Defaults", "noun, control center edit button restoring the default layout")
        backgroundColor: Theme.chipSurface
        textColor: Theme.surfaceText
        onClicked: root.resetToDefault()
    }

    DankButton {
        width: root.buttonWidth
        buttonHeight: Theme.buttonHeightS
        iconName: "clear_all"
        text: I18n.tr("Reset")
        backgroundColor: Theme.errorHover
        textColor: Theme.error
        onClicked: root.clearAll()
    }
}
