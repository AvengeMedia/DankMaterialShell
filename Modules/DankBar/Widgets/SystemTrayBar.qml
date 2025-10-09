import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property var parentWindow: null
    property var parentScreen: null
    property real widgetThickness: 30
    property bool isAtBottom: false
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 2 : Theme.spacingS
    readonly property int calculatedSize: SystemTray.items.values.length > 0 ? SystemTray.items.values.length * 24 + horizontalPadding * 2 : 0

    width: isVertical ? widgetThickness : calculatedSize
    height: isVertical ? calculatedSize : widgetThickness
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SystemTray.items.values.length === 0) {
            return "transparent";
        }

        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }
    visible: SystemTray.items.values.length > 0

    Loader {
        id: layoutLoader
        anchors.centerIn: parent
        sourceComponent: root.isVertical ? columnComp : rowComp
    }

    Component {
        id: rowComp
        Row {
            spacing: 0

            Repeater {
                model: SystemTray.items.values

                delegate: Item {
                property var trayItem: modelData
                property string iconSource: {
                    let icon = trayItem && trayItem.icon;
                    if (typeof icon === 'string' || icon instanceof String) {
                        if (icon === "") {
                            return "";
                        }
                        if (icon.includes("?path=")) {
                            const split = icon.split("?path=");
                            if (split.length !== 2) {
                                return icon;
                            }

                            const name = split[0];
                            const path = split[1];
                            let fileName = name.substring(name.lastIndexOf("/") + 1);
                            if (fileName.startsWith("dropboxstatus")) {
                                fileName = `hicolor/16x16/status/${fileName}`;
                            }
                            return `file://${path}/${fileName}`;
                        }
                        if (icon.startsWith("/") && !icon.startsWith("file://")) {
                            return `file://${icon}`;
                        }
                        return icon;
                    }
                    return "";
                }

                width: 24
                height: 24

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.cornerRadius
                    color: trayItemArea.containsMouse ? Theme.primaryHover : "transparent"


                }

                IconImage {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: parent.iconSource
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }

                MouseArea {
                    id: trayItemArea

                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        if (!trayItem) {
                            return;
                        }

                        if (mouse.button === Qt.LeftButton && !trayItem.onlyMenu) {
                            trayItem.activate();
                            return ;
                        }
                        if (trayItem.hasMenu) {
                            root.showForTrayItem(trayItem, parent, parentScreen, root.isAtBottom, root.isVertical, root.axis);
                        }
                    }
                }

            }

        }
        }
    }

    Component {
        id: columnComp
        Column {
            spacing: 0

            Repeater {
                model: SystemTray.items.values

                delegate: Item {
                property var trayItem: modelData
                property string iconSource: {
                    let icon = trayItem && trayItem.icon;
                    if (typeof icon === 'string' || icon instanceof String) {
                        if (icon === "") {
                            return "";
                        }
                        if (icon.includes("?path=")) {
                            const split = icon.split("?path=");
                            if (split.length !== 2) {
                                return icon;
                            }

                            const name = split[0];
                            const path = split[1];
                            const fileName = name.substring(name.lastIndexOf("/") + 1);
                            return `file://${path}/${fileName}`;
                        }
                        if (icon.startsWith("/") && !icon.startsWith("file://")) {
                            return `file://${icon}`;
                        }
                        return icon;
                    }
                    return "";
                }

                width: 24
                height: 24

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.cornerRadius
                    color: trayItemArea.containsMouse ? Theme.primaryHover : "transparent"
                }

                IconImage {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: parent.iconSource
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }

                MouseArea {
                    id: trayItemArea

                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        if (!trayItem) {
                            return;
                        }

                        if (mouse.button === Qt.LeftButton && !trayItem.onlyMenu) {
                            trayItem.activate();
                            return ;
                        }
                        if (trayItem.hasMenu) {
                            root.showForTrayItem(trayItem, parent, parentScreen, root.isAtBottom, root.isVertical, root.axis);
                        }
                    }
                }

            }

        }
        }
    }

    Component {
        id: trayMenuComponent

        Rectangle {
            id: menuRoot

            property var trayItem: null
            property var anchorItem: null
            property var parentScreen: null
            property bool isAtBottom: false
            property bool isVertical: false
            property var axis: null
            property bool showMenu: false
            property var menuHandle: null

            ListModel { id: entryStack }
            function topEntry() {
                return entryStack.count ? entryStack.get(entryStack.count - 1).handle : null
            }

            function showForTrayItem(item, anchor, screen, atBottom, vertical, axisObj) {
                trayItem = item
                anchorItem = anchor
                parentScreen = screen
                isAtBottom = atBottom
                isVertical = vertical
                axis = axisObj
                menuHandle = item?.menu

                if (parentScreen) {
                    for (var i = 0; i < Quickshell.screens.length; i++) {
                        const s = Quickshell.screens[i]
                        if (s === parentScreen) {
                            menuWindow.screen = s
                            break
                        }
                    }
                }

                showMenu = true
            }

            function close() {
                showMenu = false
            }

            function showSubMenu(entry) {
                if (!entry || !entry.hasChildren) return;

                entryStack.append({ handle: entry });

                const h = entry.menu || entry;
                if (h && typeof h.updateLayout === "function") h.updateLayout();

                submenuHydrator.menu = h;
                submenuHydrator.open();
                Qt.callLater(() => submenuHydrator.close());
            }

            function goBack() {
                if (!entryStack.count) return;
                entryStack.remove(entryStack.count - 1);
            }

            width: 0
            height: 0
            color: "transparent"

            PanelWindow {
                id: menuWindow
                visible: menuRoot.showMenu && (menuRoot.trayItem?.hasMenu ?? false)
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

                property point anchorPos: Qt.point(screen.width / 2, screen.height / 2)

                onVisibleChanged: {
                    if (visible) {
                        updatePosition()
                    }
                }

                function updatePosition() {
                    if (!menuRoot.anchorItem || !menuRoot.trayItem) {
                        anchorPos = Qt.point(screen.width / 2, screen.height / 2)
                        return
                    }

                    const globalPos = menuRoot.anchorItem.mapToGlobal(0, 0)
                    const screenX = screen.x || 0
                    const screenY = screen.y || 0
                    const relativeX = globalPos.x - screenX
                    const relativeY = globalPos.y - screenY

                    const widgetThickness = Math.max(20, 26 + SettingsData.dankBarInnerPadding * 0.6)
                    const effectiveBarThickness = Math.max(widgetThickness + SettingsData.dankBarInnerPadding + 4, Theme.barHeight - 4 - (8 - SettingsData.dankBarInnerPadding))

                    if (menuRoot.isVertical) {
                        const edge = menuRoot.axis?.edge
                        let targetX
                        if (edge === "left") {
                            targetX = effectiveBarThickness + SettingsData.dankBarSpacing + Theme.popupDistance
                        } else {
                            const popupX = effectiveBarThickness + SettingsData.dankBarSpacing + Theme.popupDistance
                            targetX = screen.width - popupX
                        }
                        anchorPos = Qt.point(targetX, relativeY + menuRoot.anchorItem.height / 2)
                    } else {
                        let targetY
                        if (menuRoot.isAtBottom) {
                            const popupY = effectiveBarThickness + SettingsData.dankBarSpacing + SettingsData.dankBarBottomGap + Theme.popupDistance
                            targetY = screen.height - popupY
                        } else {
                            targetY = effectiveBarThickness + SettingsData.dankBarSpacing + SettingsData.dankBarBottomGap + Theme.popupDistance
                        }
                        anchorPos = Qt.point(relativeX + menuRoot.anchorItem.width / 2, targetY)
                    }
                }

                Rectangle {
                    id: menuContainer

                    width: Math.min(500, Math.max(250, menuColumn.implicitWidth + Theme.spacingS * 2))
                    height: Math.max(40, menuColumn.implicitHeight + Theme.spacingS * 2)

                    x: {
                        if (menuRoot.isVertical) {
                            const edge = menuRoot.axis?.edge
                            if (edge === "left") {
                                const targetX = menuWindow.anchorPos.x
                                return Math.min(menuWindow.screen.width - width - 10, targetX)
                            } else {
                                const targetX = menuWindow.anchorPos.x - width
                                return Math.max(10, targetX)
                            }
                        } else {
                            const left = 10
                            const right = menuWindow.width - width - 10
                            const want = menuWindow.anchorPos.x - width / 2
                            return Math.max(left, Math.min(right, want))
                        }
                    }

                    y: {
                        if (menuRoot.isVertical) {
                            const top = 10
                            const bottom = menuWindow.height - height - 10
                            const want = menuWindow.anchorPos.y - height / 2
                            return Math.max(top, Math.min(bottom, want))
                        } else {
                            if (menuRoot.isAtBottom) {
                                const targetY = menuWindow.anchorPos.y - height
                                return Math.max(10, targetY)
                            } else {
                                const targetY = menuWindow.anchorPos.y
                                return Math.min(menuWindow.screen.height - height - 10, targetY)
                            }
                        }
                    }

                    color: Theme.popupBackground()
                    radius: Theme.cornerRadius
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                    border.width: 1

                    opacity: menuRoot.showMenu ? 1 : 0
                    scale: menuRoot.showMenu ? 1 : 0.85

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 4
                        anchors.leftMargin: 2
                        anchors.rightMargin: -2
                        anchors.bottomMargin: -4
                        radius: parent.radius
                        color: Qt.rgba(0, 0, 0, 0.15)
                        z: parent.z - 1
                    }

                    QsMenuAnchor {
                        id: submenuHydrator
                        anchor.window: menuWindow
                    }

                    QsMenuOpener {
                        id: rootOpener
                        menu: menuRoot.menuHandle
                    }

                    QsMenuOpener {
                        id: subOpener
                        menu: {
                            const e = menuRoot.topEntry();
                            return e ? (e.menu || e) : null;
                        }
                    }


                    Column {
                        id: menuColumn

                        width: parent.width - Theme.spacingS * 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: Theme.spacingS
                        spacing: 1

                        Rectangle {
                            visible: entryStack.count > 0
                            width: parent.width
                            height: 28
                            radius: Theme.cornerRadius
                            color: backArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: "arrow_back"
                                    size: 16
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: I18n.tr("Back")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: backArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: menuRoot.goBack()
                            }
                        }

                        Rectangle {
                            visible: entryStack.count > 0
                            width: parent.width
                            height: 1
                            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                        }

                        Repeater {
                            model: entryStack.count
                                   ? (subOpener.children ? subOpener.children
                                                         : (menuRoot.topEntry()?.children || []))
                                   : rootOpener.children

                            Rectangle {
                                property var menuEntry: modelData

                                width: menuColumn.width
                                height: menuEntry?.isSeparator ? 1 : 28
                                radius: menuEntry?.isSeparator ? 0 : Theme.cornerRadius
                                color: {
                                    if (menuEntry?.isSeparator) {
                                        return Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                    }
                                    return itemArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                                }

                                MouseArea {
                                    id: itemArea
                                    anchors.fill: parent
                                    enabled: !menuEntry?.isSeparator && (menuEntry?.enabled !== false)
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        if (!menuEntry || menuEntry.isSeparator) return;

                                        if (menuEntry.hasChildren) {
                                            menuRoot.showSubMenu(menuEntry);
                                        } else {
                                            if (typeof menuEntry.activate === "function") {
                                                menuEntry.activate();
                                            } else if (typeof menuEntry.triggered === "function") {
                                                menuEntry.triggered();
                                            }
                                            Qt.createQmlObject('import QtQuick; Timer { interval: 80; running: true; repeat: false; onTriggered: menuRoot.close() }', menuRoot);
                                        }
                                    }
                                }

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingS
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.spacingS
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingXS
                                    visible: !menuEntry?.isSeparator

                                    Rectangle {
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: menuEntry?.buttonType !== undefined && menuEntry.buttonType !== 0
                                        radius: menuEntry?.buttonType === 2 ? 8 : 2
                                        border.width: 1
                                        border.color: Theme.outline
                                        color: "transparent"

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: parent.width - 6
                                            height: parent.height - 6
                                            radius: parent.radius - 3
                                            color: Theme.primary
                                            visible: menuEntry?.checkState === 2
                                        }

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "check"
                                            size: 10
                                            color: Theme.primaryText
                                            visible: menuEntry?.buttonType === 1 && menuEntry?.checkState === 2
                                        }
                                    }

                                    Item {
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: menuEntry?.icon && menuEntry.icon !== ""

                                        Image {
                                            anchors.fill: parent
                                            source: menuEntry?.icon || ""
                                            sourceSize.width: 16
                                            sourceSize.height: 16
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                        }
                                    }

                                    StyledText {
                                        text: menuEntry?.text || ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: (menuEntry?.enabled !== false) ? Theme.surfaceText : Theme.surfaceTextMedium
                                        elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.max(150, parent.width - 64)
                                        wrapMode: Text.NoWrap
                                    }

                                    Item {
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "chevron_right"
                                            size: 14
                                            color: Theme.surfaceText
                                            visible: menuEntry?.hasChildren ?? false
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: menuRoot.close()
                }
            }
        }
    }

    property var currentTrayMenu: null

    function showForTrayItem(item, anchor, screen, atBottom, vertical, axisObj) {
        if (currentTrayMenu) {
            currentTrayMenu.destroy()
        }
        currentTrayMenu = trayMenuComponent.createObject(null)
        if (currentTrayMenu) {
            currentTrayMenu.showForTrayItem(item, anchor, screen, atBottom, vertical ?? false, axisObj)
        }
    }

}
