pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property var menuItems: []
    property string layerNamespace: "dms:context-menu"
    property real menuMargin: Theme.spacingS
    property real minMenuWidth: Theme.fieldDefaultWidth
    property bool keyboardNavigable: false
    property var transientSurfaceTracker: null
    property var targetScreen: null
    property real anchorX: 0
    property real anchorY: 0
    property bool openState: false
    property bool renderActive: false
    property int selectedMenuIndex: -1
    property bool keyboardNavigation: false
    readonly property alias contextWindow: menuWindow
    readonly property bool blurActive: renderActive && openState && BlurService.enabled && Theme.connectedSurfaceBlurEnabled

    readonly property real maxMenuWidth: Math.max(0, (targetScreen?.width ?? Theme.launcherWidthMicro) - menuMargin * 2)
    readonly property real maxMenuHeight: Math.max(0, (targetScreen?.height ?? Theme.launcherHeightDefault) - menuMargin * 2)
    readonly property string longestMenuText: {
        let longest = "";
        for (const menuItem of menuItems) {
            const text = menuItem.text || "";
            if (text.length > longest.length)
                longest = text;
        }
        return longest;
    }
    readonly property real naturalMenuWidth: Math.max(minMenuWidth, menuTextMetrics.width + Theme.iconSize + Theme.spacingS * 5)
    readonly property real effectiveMenuWidth: Math.max(0, Math.min(maxMenuWidth, naturalMenuWidth))
    readonly property real naturalMenuHeight: menuItemsHeight() + Theme.spacingS * 2
    readonly property real effectiveMenuHeight: Math.min(maxMenuHeight, naturalMenuHeight)
    readonly property bool menuScrolls: naturalMenuHeight > effectiveMenuHeight + 0.5
    readonly property int visibleItemCount: menuItems.filter(menuItem => menuItem.type === "item").length

    signal backdropRightClicked(real x, real y)

    onRenderActiveChanged: transientSurfaceTracker?.setActive(root, renderActive, contextWindow)
    Component.onDestruction: transientSurfaceTracker?.unregister(root)

    Connections {
        target: root.transientSurfaceTracker
        ignoreUnknownSignals: true

        function onCloseRequested() {
            root.hide();
        }
    }

    StyledTextMetrics {
        id: menuTextMetrics
        text: root.longestMenuText
        font.pixelSize: Theme.fontSizeSmall
    }

    function menuItemsHeight() {
        let h = 0;
        for (const menuItem of menuItems)
            h += menuItem.type === "separator" ? Theme.spacingXS + Theme.dividerWidth : Theme.menuItemHeight;
        if (menuItems.length > 1)
            h += (menuItems.length - 1) * Theme.groupedListGap;
        return h;
    }

    function open(screen, x, y, fromKeyboard) {
        targetScreen = screen;
        anchorX = x;
        anchorY = y;
        selectedMenuIndex = fromKeyboard ? 0 : -1;
        keyboardNavigation = !!fromKeyboard;
        renderActive = true;
        openState = true;
        Qt.callLater(() => {
            menuFlickable.contentY = 0;
            if (keyboardNavigable)
                keyboardHandler.forceActiveFocus();
            ensureSelectedVisible();
        });
    }

    function openFromBar(anchor) {
        if (!anchor?.screen)
            return;
        targetScreen = anchor.screen;
        let x = anchor.x - effectiveMenuWidth / 2;
        let y = anchor.edge === "bottom" ? anchor.y - effectiveMenuHeight : anchor.y;
        if (anchor.isVertical) {
            x = anchor.edge === "left" ? anchor.x : anchor.x - effectiveMenuWidth;
            y = anchor.y - effectiveMenuHeight / 2;
        }
        open(anchor.screen, x, y, false);
    }

    function hide() {
        if (!renderActive)
            return;
        openState = false;
    }

    function activate(menuItem) {
        if (typeof menuItem?.action === "function")
            menuItem.action();
        hide();
    }

    function selectNext() {
        if (visibleItemCount === 0)
            return;
        keyboardNavigation = true;
        selectedMenuIndex = (selectedMenuIndex + 1) % visibleItemCount;
        ensureSelectedVisible();
    }

    function selectPrevious() {
        if (visibleItemCount === 0)
            return;
        keyboardNavigation = true;
        selectedMenuIndex = (selectedMenuIndex - 1 + visibleItemCount) % visibleItemCount;
        ensureSelectedVisible();
    }

    function selectedDelegateIndex() {
        let itemIndex = 0;
        for (let i = 0; i < menuItems.length; i++) {
            if (menuItems[i].type !== "item")
                continue;
            if (itemIndex === selectedMenuIndex)
                return i;
            itemIndex++;
        }
        return -1;
    }

    function ensureSelectedVisible() {
        Qt.callLater(() => {
            const delegate = menuRepeater.itemAt(selectedDelegateIndex());
            if (!delegate)
                return;
            const top = delegate.y;
            const bottom = top + delegate.height;
            const viewTop = menuFlickable.contentY;
            const viewBottom = viewTop + menuFlickable.height;
            if (top < viewTop) {
                menuFlickable.contentY = Math.max(0, top);
                return;
            }
            if (bottom > viewBottom)
                menuFlickable.contentY = Math.min(Math.max(0, menuFlickable.contentHeight - menuFlickable.height), bottom - menuFlickable.height);
        });
    }

    function activateSelected() {
        const index = selectedDelegateIndex();
        if (index >= 0)
            activate(menuItems[index]);
    }

    PanelWindow {
        id: menuWindow

        screen: root.targetScreen
        visible: root.renderActive
        color: "transparent"

        WlrLayershell.namespace: root.layerNamespace
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1

        WlrLayershell.keyboardFocus: {
            if (!root.keyboardNavigable || !root.renderActive)
                return WlrKeyboardFocus.None;
            if (PopoutManager.screenshotActive || CompositorService.useHyprlandFocusGrab)
                return WlrKeyboardFocus.None;
            return WlrKeyboardFocus.Exclusive;
        }

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        WindowBlur {
            targetWindow: menuWindow
            blurX: root.blurActive ? menuContainer.x : 0
            blurY: root.blurActive ? menuContainer.y : 0
            blurWidth: root.blurActive ? menuContainer.width : 0
            blurHeight: root.blurActive ? menuContainer.height : 0
            blurRadius: Theme.windowRadius
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            enabled: root.renderActive
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    root.backdropRightClicked(mouse.x, mouse.y);
                    return;
                }
                root.hide();
            }
        }

        Item {
            id: keyboardHandler
            anchors.fill: parent
            focus: root.keyboardNavigable && root.openState

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Down:
                    root.selectNext();
                    event.accepted = true;
                    return;
                case Qt.Key_Up:
                    root.selectPrevious();
                    event.accepted = true;
                    return;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    root.activateSelected();
                    event.accepted = true;
                    return;
                case Qt.Key_Escape:
                case Qt.Key_Left:
                    root.hide();
                    event.accepted = true;
                    return;
                }
            }

            Rectangle {
                id: menuContainer
                x: Math.max(root.menuMargin, Math.min(menuWindow.width - width - root.menuMargin, root.anchorX))
                y: Math.max(root.menuMargin, Math.min(menuWindow.height - height - root.menuMargin, root.anchorY))
                width: root.effectiveMenuWidth
                height: root.effectiveMenuHeight
                color: Theme.readableSurface
                radius: Theme.windowRadius
                border.color: BlurService.borderColor
                border.width: BlurService.borderWidth
                opacity: root.openState ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: SettingsData.reduceMotion ? 0 : Theme.shortDuration
                        easing.type: Theme.emphasizedEasing
                        onRunningChanged: {
                            if (!running && !root.openState)
                                root.renderActive = false;
                        }
                    }
                }

                ElevationShadow {
                    anchors.fill: parent
                    z: -1
                    level: Theme.elevationLevel2
                    targetRadius: parent.radius
                    targetColor: "transparent"
                    shadowEnabled: Theme.elevationEnabled
                }

                DankFlickable {
                    id: menuFlickable
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    clip: true
                    contentWidth: width
                    contentHeight: menuColumn.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: root.menuScrolls

                    Column {
                        id: menuColumn
                        width: menuFlickable.width
                        spacing: Theme.groupedListGap

                        Repeater {
                            id: menuRepeater
                            model: root.menuItems

                            Item {
                                id: menuItemDelegate
                                required property var modelData
                                required property int index

                                readonly property bool isSeparator: modelData.type === "separator"
                                readonly property int itemIndex: root.menuItems.slice(0, index).filter(menuItem => menuItem.type === "item").length

                                width: menuColumn.width
                                height: isSeparator ? Theme.spacingXS + Theme.dividerWidth : Theme.menuItemHeight

                                Rectangle {
                                    visible: menuItemDelegate.isSeparator
                                    width: parent.width - Theme.spacingS * 2
                                    height: Theme.outlineWidth
                                    anchors.centerIn: parent
                                    color: Theme.outlineHeavy
                                }

                                Rectangle {
                                    id: menuRow
                                    readonly property bool selected: root.keyboardNavigation && root.selectedMenuIndex === menuItemDelegate.itemIndex
                                    readonly property bool destructive: menuItemDelegate.modelData?.isDestructive ?? false
                                    readonly property color contentColor: {
                                        if (destructive)
                                            return Theme.error;
                                        return selected ? Theme.onSelectedContainer : Theme.onSurface;
                                    }
                                    visible: !menuItemDelegate.isSeparator
                                    anchors.fill: parent
                                    radius: Theme.cornerRadiusS
                                    color: {
                                        if (destructive)
                                            return selected ? Theme.errorSelected : itemMouseArea.containsMouse ? Theme.errorHover : "transparent";
                                        return selected ? Theme.selectedContainer : itemMouseArea.pressed ? Theme.withAlpha(Theme.onSurface, Theme.stateLayerPressed) : itemMouseArea.containsMouse ? Theme.withAlpha(Theme.onSurface, Theme.stateLayerHover) : "transparent";
                                    }

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.spacingS
                                        anchors.right: parent.right
                                        anchors.rightMargin: Theme.spacingS
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Theme.spacingS

                                        DankIcon {
                                            name: menuItemDelegate.modelData?.icon ?? ""
                                            size: Theme.iconSizeMedium
                                            color: menuRow.contentColor
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: menuItemDelegate.modelData.text || ""
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: menuRow.contentColor
                                            font.weight: Theme.fontWeight
                                            anchors.verticalCenter: parent.verticalCenter
                                            elide: Text.ElideRight
                                            width: parent.width - Theme.iconSizeMedium - Theme.spacingS
                                        }
                                    }

                                    DankRipple {
                                        id: menuItemRipple
                                        rippleColor: menuRow.contentColor
                                        cornerRadius: Theme.cornerRadiusM
                                    }

                                    MouseArea {
                                        id: itemMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: {
                                            root.keyboardNavigation = false;
                                            root.selectedMenuIndex = menuItemDelegate.itemIndex;
                                        }
                                        onPressed: mouse => menuItemRipple.trigger(mouse.x, mouse.y)
                                        onClicked: root.activate(menuItemDelegate.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
