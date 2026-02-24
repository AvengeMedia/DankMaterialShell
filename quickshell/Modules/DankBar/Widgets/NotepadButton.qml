import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    readonly property string focusedScreenName: (CompositorService.isHyprland && typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor ? (Hyprland.focusedWorkspace.monitor.name || "") : CompositorService.isNiri && typeof NiriService !== "undefined" && NiriService.currentOutput ? NiriService.currentOutput : "")

    function resolveNotepadInstance() {
        if (typeof notepadSlideoutVariants === "undefined" || !notepadSlideoutVariants || !notepadSlideoutVariants.instances) {
            return null;
        }

        const targetScreen = focusedScreenName;
        if (targetScreen) {
            for (var i = 0; i < notepadSlideoutVariants.instances.length; i++) {
                var slideout = notepadSlideoutVariants.instances[i];
                if (slideout.modelData && slideout.modelData.name === targetScreen) {
                    return slideout;
                }
            }
        }

        return notepadSlideoutVariants.instances.length > 0 ? notepadSlideoutVariants.instances[0] : null;
    }

    readonly property var notepadInstance: resolveNotepadInstance()
    readonly property bool isActive: notepadInstance?.isVisible ?? false
    property bool isAutoHideBar: false

    readonly property real minTooltipY: {
        if (!parentScreen || !(axis?.isVertical ?? false)) {
            return 0;
        }

        if (isAutoHideBar) {
            return 0;
        }

        if (parentScreen.y > 0) {
            return barThickness + barSpacing;
        }

        return 0;
    }

    readonly property var savedTabEntries: {
        const result = [];
        const tabs = NotepadStorageService.tabs || [];
        for (let i = 0; i < tabs.length; i++) {
            const tab = tabs[i];
            if (tab && !tab.isTemporary) {
                result.push({
                    index: i,
                    tab: tab
                });
            }
        }
        return result.slice(0, 5);
    }

    function openTabByIndex(tabIndex) {
        if (tabIndex < 0)
            return;
        if (root.notepadInstance && typeof root.notepadInstance.show === "function") {
            root.notepadInstance.show();
        }
        Qt.callLater(() => {
            NotepadStorageService.switchToTab(tabIndex);
        });
    }

    function openNewNote() {
        if (root.notepadInstance && typeof root.notepadInstance.show === "function") {
            root.notepadInstance.show();
        }
        Qt.callLater(() => {
            NotepadStorageService.createNewTab();
        });
    }

    function openContextMenu() {
        const screen = root.parentScreen || Screen;
        const screenX = screen.x || 0;
        const screenY = screen.y || 0;
        const isVertical = root.axis?.isVertical ?? false;
        const edge = root.axis?.edge ?? "top";
        const gap = Math.max(Theme.spacingXS, root.barSpacing ?? Theme.spacingXS);

        const globalPos = root.mapToGlobal(root.width / 2, root.height / 2);
        const relativeX = globalPos.x - screenX;
        const relativeY = globalPos.y - screenY;

        let anchorX = relativeX;
        let anchorY = relativeY;

        if (isVertical) {
            anchorX = edge === "left" ? (root.barThickness + root.barSpacing + gap) : (screen.width - (root.barThickness + root.barSpacing + gap));
            anchorY = relativeY + root.minTooltipY;
        } else {
            anchorX = relativeX;
            anchorY = edge === "bottom" ? (screen.height - (root.barThickness + root.barSpacing + gap)) : (root.barThickness + root.barSpacing + gap);
        }

        contextMenuWindow.showAt(anchorX, anchorY, isVertical, edge, screen);
    }

    content: Component {
        Item {
            implicitWidth: notepadIcon.width
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2

            DankIcon {
                id: notepadIcon

                anchors.centerIn: parent
                name: "assignment"
                size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                color: root.isActive ? Theme.primary : Theme.surfaceText
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            root.triggerRipple(this, mouse.x, mouse.y);
        }
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton) {
                openContextMenu();
                return;
            }
            const inst = root.notepadInstance;
            if (inst) {
                inst.toggle();
            }
        }
    }

    PanelWindow {
        id: contextMenuWindow

        WlrLayershell.namespace: "dms:notepad-context-menu"

        property bool isVertical: false
        property string edge: "top"
        property point anchorPos: Qt.point(0, 0)

        function showAt(x, y, vertical, barEdge, targetScreen) {
            if (targetScreen) {
                contextMenuWindow.screen = targetScreen;
            }

            anchorPos = Qt.point(x, y);
            isVertical = vertical ?? false;
            edge = barEdge ?? "top";

            visible = true;

            if (contextMenuWindow.screen) {
                TrayMenuManager.registerMenu(contextMenuWindow.screen.name, contextMenuWindow);
            }
        }

        function closeMenu() {
            visible = false;

            if (contextMenuWindow.screen) {
                TrayMenuManager.unregisterMenu(contextMenuWindow.screen.name);
            }
        }

        screen: null
        visible: false
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        Component.onDestruction: {
            if (contextMenuWindow.screen) {
                TrayMenuManager.unregisterMenu(contextMenuWindow.screen.name);
            }
        }

        Connections {
            target: PopoutManager
            function onPopoutOpening() {
                contextMenuWindow.closeMenu();
            }
        }

        MouseArea {
            anchors.fill: parent
            z: 0
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: contextMenuWindow.closeMenu()
        }

        Rectangle {
            id: menuContainer
            z: 1

            x: {
                if (contextMenuWindow.isVertical) {
                    if (contextMenuWindow.edge === "left") {
                        return Math.min(contextMenuWindow.width - width - 10, contextMenuWindow.anchorPos.x);
                    }
                    return Math.max(10, contextMenuWindow.anchorPos.x - width);
                }
                const left = 10;
                const right = contextMenuWindow.width - width - 10;
                const want = contextMenuWindow.anchorPos.x - width / 2;
                return Math.max(left, Math.min(right, want));
            }
            y: {
                if (contextMenuWindow.isVertical) {
                    const top = 10;
                    const bottom = contextMenuWindow.height - height - 10;
                    const want = contextMenuWindow.anchorPos.y - height / 2;
                    return Math.max(top, Math.min(bottom, want));
                }
                if (contextMenuWindow.edge === "top") {
                    return Math.min(contextMenuWindow.height - height - 10, contextMenuWindow.anchorPos.y);
                }
                return Math.max(10, contextMenuWindow.anchorPos.y - height);
            }

            width: Math.min(260, Math.max(180, menuColumn.implicitWidth + Theme.spacingS * 2))
            height: Math.max(60, menuColumn.implicitHeight + Theme.spacingS * 2)
            color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            radius: Theme.cornerRadius
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: 1

            opacity: contextMenuWindow.visible ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.emphasizedEasing
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 4
                anchors.leftMargin: 2
                anchors.rightMargin: -2
                anchors.bottomMargin: -4
                radius: parent.radius
                color: Qt.rgba(0, 0, 0, 0.15)
                z: -1
            }

            Column {
                id: menuColumn
                width: parent.width - Theme.spacingS * 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingS
                spacing: 1

                Repeater {
                    model: root.savedTabEntries

                    Rectangle {
                        required property var modelData

                        width: parent.width
                        height: 30
                        radius: Theme.cornerRadius
                        color: tabArea.containsMouse ? Theme.widgetBaseHoverColor : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS
                            spacing: Theme.spacingS

                            DankIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "description"
                                size: 16
                                color: Theme.surfaceText
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.tab?.title || I18n.tr("Saved Note")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        MouseArea {
                            id: tabArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                contextMenuWindow.closeMenu();
                                root.openTabByIndex(modelData.index);
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 30
                    radius: Theme.cornerRadius
                    color: newNoteArea.containsMouse ? Theme.widgetBaseHoverColor : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingS
                        anchors.rightMargin: Theme.spacingS
                        spacing: Theme.spacingS

                        DankIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "add"
                            size: 16
                            color: Theme.surfaceText
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Open a new note")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }
                    }

                    MouseArea {
                        id: newNoteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            contextMenuWindow.closeMenu();
                            root.openNewNote();
                        }
                    }
                }
            }
        }
    }
}
