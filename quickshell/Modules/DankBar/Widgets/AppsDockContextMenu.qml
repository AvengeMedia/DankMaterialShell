import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    WlrLayershell.namespace: "dms:dock-context-menu"

    property var appData: null
    property var anchorItem: null
    property int margin: 10
    property bool hidePin: false
    property var desktopEntry: null
    property bool isDmsWindow: appData?.appId === "org.quickshell"

    property bool isVertical: false
    property string edge: "top"
    property point anchorPos: Qt.point(0, 0)

    function showAt(x, y, vertical, barEdge, data, hidePinOption, entry, targetScreen) {
        if (targetScreen) {
            root.screen = targetScreen;
        }

        anchorPos = Qt.point(x, y);
        isVertical = vertical ?? false;
        edge = barEdge ?? "top";

        appData = data;
        hidePin = hidePinOption || false;
        desktopEntry = entry || null;

        visible = true;

        if (targetScreen) {
            TrayMenuManager.registerMenu(targetScreen.name, root);
        }
    }

    function close() {
        visible = false;

        if (root.screen) {
            TrayMenuManager.unregisterMenu(root.screen.name);
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
        if (root.screen) {
            TrayMenuManager.unregisterMenu(root.screen.name);
        }
    }

    Connections {
        target: PopoutManager
        function onPopoutOpening() {
            root.close();
        }
    }

    Rectangle {
        id: menuContainer

        x: {
            if (root.isVertical) {
                if (root.edge === "left") {
                    return Math.min(root.width - width - 10, root.anchorPos.x);
                } else {
                    return Math.max(10, root.anchorPos.x - width);
                }
            } else {
                const left = 10;
                const right = root.width - width - 10;
                const want = root.anchorPos.x - width / 2;
                return Math.max(left, Math.min(right, want));
            }
        }
        y: {
            if (root.isVertical) {
                const top = 10;
                const bottom = root.height - height - 10;
                const want = root.anchorPos.y - height / 2;
                return Math.max(top, Math.min(bottom, want));
            } else {
                if (root.edge === "top") {
                    return Math.min(root.height - height - 10, root.anchorPos.y);
                } else {
                    return Math.max(10, root.anchorPos.y - height);
                }
            }
        }

        width: Math.min(400, Math.max(180, menuColumn.implicitWidth + Theme.spacingS * 2))
        height: Math.max(60, menuColumn.implicitHeight + Theme.spacingS * 2)
        color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
        radius: Theme.cornerRadius
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1

        opacity: root.visible ? 1 : 0
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

            // Window list for grouped apps
            Repeater {
                model: {
                    if (!root.appData || root.appData.type !== "grouped")
                        return [];

                    const toplevels = [];
                    const allToplevels = ToplevelManager.toplevels.values;
                    for (let i = 0; i < allToplevels.length; i++) {
                        const toplevel = allToplevels[i];
                        if (toplevel.appId === root.appData.appId) {
                            toplevels.push(toplevel);
                        }
                    }
                    return toplevels;
                }

                Rectangle {
                    width: parent.width
                    height: 28
                    radius: Theme.cornerRadius
                    color: windowArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: closeButton.left
                        anchors.rightMargin: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        text: (modelData && modelData.title) ? modelData.title : I18n.tr("(Unnamed)")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        font.weight: Font.Normal
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }

                    Rectangle {
                        id: closeButton
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        radius: 10
                        color: closeMouseArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2) : "transparent"

                        DankIcon {
                            anchors.centerIn: parent
                            name: "close"
                            size: 12
                            color: closeMouseArea.containsMouse ? Theme.error : Theme.surfaceText
                        }

                        MouseArea {
                            id: closeMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData && modelData.close) {
                                    modelData.close();
                                }
                                root.close();
                            }
                        }
                    }

                    DankRipple {
                        id: windowRipple
                        rippleColor: Theme.surfaceText
                        cornerRadius: Theme.cornerRadius
                    }

                    MouseArea {
                        id: windowArea
                        anchors.fill: parent
                        anchors.rightMargin: 24
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => windowRipple.trigger(mouse.x, mouse.y)
                        onClicked: {
                            if (modelData && modelData.activate) {
                                modelData.activate();
                            }
                            root.close();
                        }
                    }
                }
            }

            Rectangle {
                visible: {
                    if (!root.appData)
                        return false;
                    if (root.appData.type !== "grouped")
                        return false;
                    return root.appData.windowCount > 0;
                }
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
            }

            Repeater {
                model: root.desktopEntry && root.desktopEntry.actions ? root.desktopEntry.actions : []

                Rectangle {
                    width: parent.width
                    height: 28
                    radius: Theme.cornerRadius
                    color: actionArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            visible: modelData.icon && modelData.icon !== ""

                            IconImage {
                                anchors.fill: parent
                                source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                                smooth: true
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name || ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }
                    }

                    DankRipple {
                        id: actionRipple
                        rippleColor: Theme.surfaceText
                        cornerRadius: Theme.cornerRadius
                    }

                    MouseArea {
                        id: actionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => actionRipple.trigger(mouse.x, mouse.y)
                        onClicked: {
                            if (modelData) {
                                SessionService.launchDesktopAction(root.desktopEntry, modelData);
                            }
                            root.close();
                        }
                    }
                }
            }

            Rectangle {
                visible: {
                    if (!root.desktopEntry?.actions || root.desktopEntry.actions.length === 0) {
                        return false;
                    }
                    return !root.hidePin || (!root.isDmsWindow && root.desktopEntry && SessionService.nvidiaCommand);
                }
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
            }

            Rectangle {
                visible: !root.hidePin
                width: parent.width
                height: 28
                radius: Theme.cornerRadius
                color: pinArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.appData && root.appData.isPinned ? I18n.tr("Unpin from Dock") : I18n.tr("Pin to Dock")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                DankRipple {
                    id: pinRipple
                    rippleColor: Theme.surfaceText
                    cornerRadius: Theme.cornerRadius
                }

                MouseArea {
                    id: pinArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => pinRipple.trigger(mouse.x, mouse.y)
                    onClicked: {
                        if (!root.appData) {
                            return;
                        }
                        if (root.appData.isPinned) {
                            SessionData.removeBarPinnedApp(root.appData.appId);
                        } else {
                            SessionData.addBarPinnedApp(root.appData.appId);
                        }
                        root.close();
                    }
                }
            }

            Rectangle {
                visible: {
                    const hasNvidia = !root.isDmsWindow && root.desktopEntry && SessionService.nvidiaCommand;
                    const hasWindow = root.appData && (root.appData.type === "window" || (root.appData.type === "grouped" && root.appData.windowCount > 0));
                    const hasPinOption = !root.hidePin;
                    const hasContentAbove = hasPinOption || hasNvidia;
                    return hasContentAbove && hasWindow;
                }
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
            }

            Rectangle {
                visible: !root.isDmsWindow && root.desktopEntry && SessionService.nvidiaCommand
                width: parent.width
                height: 28
                radius: Theme.cornerRadius
                color: nvidiaArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Launch on dGPU")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                DankRipple {
                    id: nvidiaRipple
                    rippleColor: Theme.surfaceText
                    cornerRadius: Theme.cornerRadius
                }

                MouseArea {
                    id: nvidiaArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => nvidiaRipple.trigger(mouse.x, mouse.y)
                    onClicked: {
                        if (root.desktopEntry) {
                            SessionService.launchDesktopEntry(root.desktopEntry, true);
                        }
                        root.close();
                    }
                }
            }

            Rectangle {
                visible: root.appData && (root.appData.type === "window" || (root.appData.type === "grouped" && root.appData.windowCount > 0))
                width: parent.width
                height: 28
                radius: Theme.cornerRadius
                color: closeArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) : "transparent"

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (root.appData && root.appData.type === "grouped") {
                            return I18n.tr("Close All Windows");
                        }
                        return I18n.tr("Close Window");
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: closeArea.containsMouse ? Theme.error : Theme.surfaceText
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                DankRipple {
                    id: closeRipple
                    rippleColor: Theme.error
                    cornerRadius: Theme.cornerRadius
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => closeRipple.trigger(mouse.x, mouse.y)
                    onClicked: {
                        if (root.appData?.type === "window") {
                            root.appData?.toplevel?.close();
                        } else if (root.appData?.type === "grouped") {
                            root.appData?.allWindows?.forEach(window => window.toplevel?.close());
                        }
                        root.close();
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.close()
    }
}
