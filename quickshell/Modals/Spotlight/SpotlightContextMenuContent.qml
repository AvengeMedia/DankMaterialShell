import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var currentApp: null
    property var appLauncher: null
    property int selectedMenuIndex: 0
    property bool keyboardNavigation: false

    signal hideRequested()

    readonly property var desktopEntry: (currentApp && !currentApp.isPlugin && appLauncher && appLauncher._uniqueApps && currentApp.appIndex >= 0 && currentApp.appIndex < appLauncher._uniqueApps.length) ? appLauncher._uniqueApps[currentApp.appIndex] : null

    readonly property var menuItems: {
        const items = [];
        const appId = desktopEntry ? (desktopEntry.id || desktopEntry.execString || "") : "";
        const isPinned = SessionData.isPinnedApp(appId);

        items.push({
            type: "item",
            icon: isPinned ? "keep_off" : "push_pin",
            text: isPinned ? I18n.tr("Unpin from Dock") : I18n.tr("Pin to Dock"),
            action: togglePin
        });

        if (desktopEntry && desktopEntry.actions) {
            items.push({
                type: "separator"
            });
            for (let i = 0; i < desktopEntry.actions.length; i++) {
                const act = desktopEntry.actions[i];
                items.push({
                    type: "item",
                    text: act.name || "",
                    action: () => launchAction(act)
                });
            }
        }

        items.push({
            type: "separator",
            hidden: !desktopEntry || !desktopEntry.actions || desktopEntry.actions.length === 0
        });
        items.push({
            type: "item",
            icon: "launch",
            text: I18n.tr("Launch"),
            action: launchCurrentApp
        });

        if (SessionService.nvidiaCommand) {
            items.push({
                type: "separator"
            });
            items.push({
                type: "item",
                icon: "memory",
                text: I18n.tr("Launch on dGPU"),
                action: launchWithNvidia
            });
        }

        return items;
    }

    readonly property int visibleItemCount: {
        let count = 0;
        for (let i = 0; i < menuItems.length; i++) {
            if (menuItems[i].type === "item" && !menuItems[i].hidden) {
                count++;
            }
        }
        return count;
    }

    function selectNext() {
        if (visibleItemCount > 0) {
            selectedMenuIndex = (selectedMenuIndex + 1) % visibleItemCount;
        }
    }

    function selectPrevious() {
        if (visibleItemCount > 0) {
            selectedMenuIndex = (selectedMenuIndex - 1 + visibleItemCount) % visibleItemCount;
        }
    }

    function togglePin() {
        if (!desktopEntry)
            return;
        const appId = desktopEntry.id || desktopEntry.execString || "";
        if (SessionData.isPinnedApp(appId))
            SessionData.removePinnedApp(appId);
        else
            SessionData.addPinnedApp(appId);
        hideRequested();
    }

    function launchCurrentApp() {
        if (currentApp && appLauncher)
            appLauncher.launchApp(currentApp);
        hideRequested();
    }

    function launchWithNvidia() {
        if (desktopEntry) {
            SessionService.launchDesktopEntry(desktopEntry, true);
            if (appLauncher && currentApp) {
                appLauncher.appLaunched(currentApp);
            }
        }
        hideRequested();
    }

    function launchAction(action) {
        if (desktopEntry) {
            SessionService.launchDesktopAction(desktopEntry, action);
            if (appLauncher && currentApp) {
                appLauncher.appLaunched(currentApp);
            }
        }
        hideRequested();
    }

    function activateSelected() {
        let itemIndex = 0;
        for (let i = 0; i < menuItems.length; i++) {
            if (menuItems[i].type === "item" && !menuItems[i].hidden) {
                if (itemIndex === selectedMenuIndex) {
                    menuItems[i].action();
                    return;
                }
                itemIndex++;
            }
        }
    }

    property alias keyboardHandler: keyboardHandler

    implicitWidth: Math.max(180, menuColumn.implicitWidth + Theme.spacingS * 2)
    implicitHeight: menuColumn.implicitHeight + Theme.spacingS * 2
    
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        id: menuContainer
        anchors.fill: parent
        color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
        radius: Theme.cornerRadius
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1

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

        Item {
            id: keyboardHandler
            anchors.fill: parent
            focus: keyboardNavigation

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Down) {
                    selectNext();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    selectPrevious();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    activateSelected();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    hideRequested();
                    event.accepted = true;
                }
            }

            Column {
                id: menuColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: 1

                Repeater {
                    model: menuItems

                    Item {
                        width: parent.width
                        height: modelData.type === "separator" ? 5 : 32
                        visible: !modelData.hidden

                        property int itemIndex: {
                            let count = 0;
                            for (let i = 0; i < index; i++) {
                                if (menuItems[i].type === "item" && !menuItems[i].hidden) {
                                    count++;
                                }
                            }
                            return count;
                        }

                        Rectangle {
                            visible: modelData.type === "separator"
                            width: parent.width - Theme.spacingS * 2
                            height: parent.height
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: "transparent"

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: 1
                                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                            }
                        }

                        Rectangle {
                            visible: modelData.type === "item"
                            width: parent.width
                            height: parent.height
                            radius: Theme.cornerRadius
                            color: {
                                if (keyboardNavigation && selectedMenuIndex === itemIndex) {
                                    return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2);
                                }
                                return mouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent";
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingS
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingS

                                Item {
                                    width: Theme.iconSize - 2
                                    height: Theme.iconSize - 2
                                    anchors.verticalCenter: parent.verticalCenter

                                    DankIcon {
                                        visible: modelData.icon !== undefined && modelData.icon !== ""
                                        name: modelData.icon || ""
                                        size: Theme.iconSize - 2
                                        color: Theme.surfaceText
                                        opacity: 0.7
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                StyledText {
                                    text: modelData.text || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    font.weight: Font.Normal
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    width: parent.width - (Theme.iconSize - 2) - Theme.spacingS
                                }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: {
                                    keyboardNavigation = false;
                                    selectedMenuIndex = itemIndex;
                                }
                                onClicked: modelData.action()
                            }
                        }
                    }
                }
            }
        }
    }
}
