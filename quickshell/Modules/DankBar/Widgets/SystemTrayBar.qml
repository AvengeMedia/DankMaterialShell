import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property bool isVertical: axis?.isVertical ?? false
    property var axis: null
    property var parentWindow: null
    property var parentScreen: null
    property real widgetThickness: 30
    property real barThickness: 48
    property bool isAtBottom: false
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 2 : Theme.spacingS
    readonly property var hiddenTrayIds: {
        const envValue = Quickshell.env("DMS_HIDE_TRAYIDS") || ""
        return envValue ? envValue.split(",").map(id => id.trim().toLowerCase()) : []
    }
    readonly property var allTrayItems: {
        if (!hiddenTrayIds.length) {
            return SystemTray.items.values
        }
        return SystemTray.items.values.filter(item => {
            const itemId = item?.id || ""
            return !hiddenTrayIds.includes(itemId.toLowerCase())
        })
    }
    readonly property var mainBarItems: allTrayItems.filter(item => !SessionData.isHiddenTrayId(item?.id || ""))
    readonly property var hiddenBarItems: allTrayItems.filter(item => SessionData.isHiddenTrayId(item?.id || ""))
    readonly property bool hasHiddenItems: allTrayItems.length > mainBarItems.length
    readonly property int calculatedSize: {
        if (allTrayItems.length === 0) return 0
        const itemCount = mainBarItems.length + (hasHiddenItems ? 1 : 0)
        return itemCount * 24 + horizontalPadding * 2
    }
    readonly property real visualWidth: isVertical ? widgetThickness : calculatedSize
    readonly property real visualHeight: isVertical ? calculatedSize : widgetThickness

    width: isVertical ? barThickness : visualWidth
    height: isVertical ? visualHeight : barThickness
    visible: allTrayItems.length > 0

    property bool menuOpen: false
    property bool overflowWasOpenBeforeTrayMenu: false

    Rectangle {
        id: visualBackground
        width: root.visualWidth
        height: root.visualHeight
        anchors.centerIn: parent
        radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
        color: {
            if (allTrayItems.length === 0) {
                return "transparent";
            }

            if (SettingsData.dankBarNoBackground) {
                return "transparent";
            }

            const baseColor = Theme.widgetBaseBackgroundColor;
            return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
        }
    }

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
                model: root.mainBarItems

                delegate: Item {
                    id: delegateRoot
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
                    height: root.barThickness

                    Rectangle {
                        id: visualContent
                        width: 24
                        height: 24
                        anchors.centerIn: parent
                        radius: Theme.cornerRadius
                        color: trayItemArea.containsMouse ? Theme.primaryHover : "transparent"

                        IconImage {
                            id: iconImg
                            anchors.centerIn: parent
                            width: Theme.barIconSize(root.barThickness)
                            height: Theme.barIconSize(root.barThickness)
                            source: delegateRoot.iconSource
                            asynchronous: true
                            smooth: true
                            mipmap: true
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !iconImg.visible
                            text: {
                                const itemId = trayItem?.id || ""
                                if (!itemId) {
                                    return "?"
                                }
                                return itemId.charAt(0).toUpperCase()
                            }
                            font.pixelSize: 10
                            color: Theme.surfaceText
                        }
                    }

                    MouseArea {
                        id: trayItemArea

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            if (!delegateRoot.trayItem) return

                            if (mouse.button === Qt.LeftButton && !delegateRoot.trayItem.onlyMenu) {
                                delegateRoot.trayItem.activate()
                                return
                            }

                            if (!delegateRoot.trayItem.hasMenu) return

                            root.overflowWasOpenBeforeTrayMenu = root.menuOpen
                            root.showForTrayItem(delegateRoot.trayItem, visualContent, parentScreen, root.isAtBottom, root.isVertical, root.axis)
                        }
                    }
                }
            }

            Item {
                width: 24
                height: root.barThickness
                visible: root.hasHiddenItems

                Rectangle {
                    id: caretButton
                    width: 24
                    height: 24
                    anchors.centerIn: parent
                    radius: Theme.cornerRadius
                    color: caretArea.containsMouse ? Theme.primaryHover : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: root.menuOpen ? "expand_less" : "expand_more"
                        size: Theme.barIconSize(root.barThickness)
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: caretArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.menuOpen = !root.menuOpen
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
                model: root.mainBarItems

                delegate: Item {
                    id: delegateRoot
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

                    width: root.barThickness
                    height: 24

                    Rectangle {
                        id: visualContent
                        width: 24
                        height: 24
                        anchors.centerIn: parent
                        radius: Theme.cornerRadius
                        color: trayItemArea.containsMouse ? Theme.primaryHover : "transparent"

                        IconImage {
                            id: iconImg
                            anchors.centerIn: parent
                            width: Theme.barIconSize(root.barThickness)
                            height: Theme.barIconSize(root.barThickness)
                            source: delegateRoot.iconSource
                            asynchronous: true
                            smooth: true
                            mipmap: true
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !iconImg.visible
                            text: {
                                const itemId = trayItem?.id || ""
                                if (!itemId) {
                                    return "?"
                                }
                                return itemId.charAt(0).toUpperCase()
                            }
                            font.pixelSize: 10
                            color: Theme.surfaceText
                        }
                    }

                    MouseArea {
                        id: trayItemArea

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            if (!delegateRoot.trayItem) return

                            if (mouse.button === Qt.LeftButton && !delegateRoot.trayItem.onlyMenu) {
                                delegateRoot.trayItem.activate()
                                return
                            }

                            if (!delegateRoot.trayItem.hasMenu) return

                            root.overflowWasOpenBeforeTrayMenu = root.menuOpen
                            root.showForTrayItem(delegateRoot.trayItem, visualContent, parentScreen, root.isAtBottom, root.isVertical, root.axis)
                        }
                    }
                }
            }

            Item {
                width: root.barThickness
                height: 24
                visible: root.hasHiddenItems

                Rectangle {
                    id: caretButtonVert
                    width: 24
                    height: 24
                    anchors.centerIn: parent
                    radius: Theme.cornerRadius
                    color: caretAreaVert.containsMouse ? Theme.primaryHover : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: {
                            const edge = root.axis?.edge
                            if (edge === "left") {
                                return root.menuOpen ? "chevron_left" : "chevron_right"
                            } else {
                                return root.menuOpen ? "chevron_right" : "chevron_left"
                            }
                        }
                        size: Theme.barIconSize(root.barThickness)
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: caretAreaVert
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.menuOpen = !root.menuOpen
                    }
                }
            }
        }
    }

    PanelWindow {
        id: overflowMenu
        visible: root.menuOpen
        screen: root.parentScreen
        WlrLayershell.layer: WlrLayershell.Top
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "dms:tray-overflow-menu"
        color: "transparent"

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        readonly property real dpr: (typeof CompositorService !== "undefined" && CompositorService.getScreenScale)
            ? CompositorService.getScreenScale(overflowMenu.screen)
            : (screen?.devicePixelRatio || 1)
        property point anchorPos: Qt.point(screen.width / 2, screen.height / 2)

        onVisibleChanged: {
            if (visible) {
                updatePosition()
                Qt.callLater(() => overflowFocusScope.forceActiveFocus())
            }
        }

        FocusScope {
            id: overflowFocusScope
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: {
                root.menuOpen = false
            }
        }

        function updatePosition() {
            if (!root.parentWindow) {
                anchorPos = Qt.point(screen.width / 2, screen.height / 2)
                return
            }

            const globalPos = root.mapToGlobal(0, 0)
            const screenX = screen.x || 0
            const screenY = screen.y || 0
            const relativeX = globalPos.x - screenX
            const relativeY = globalPos.y - screenY

            const widgetThickness = Math.max(20, 26 + SettingsData.dankBarInnerPadding * 0.6)
            const effectiveBarThickness = Math.max(widgetThickness + SettingsData.dankBarInnerPadding + 4, Theme.barHeight - 4 - (8 - SettingsData.dankBarInnerPadding))

            if (root.isVertical) {
                const edge = root.axis?.edge
                let targetX = edge === "left"
                    ? effectiveBarThickness + SettingsData.dankBarSpacing + Theme.popupDistance
                    : screen.width - (effectiveBarThickness + SettingsData.dankBarSpacing + Theme.popupDistance)
                anchorPos = Qt.point(targetX, relativeY + root.height / 2)
            } else {
                let targetY = root.isAtBottom
                    ? screen.height - (effectiveBarThickness + SettingsData.dankBarSpacing + SettingsData.dankBarBottomGap + Theme.popupDistance)
                    : effectiveBarThickness + SettingsData.dankBarSpacing + SettingsData.dankBarBottomGap + Theme.popupDistance
                anchorPos = Qt.point(relativeX + root.width / 2, targetY)
            }
        }

        Item {
            id: menuContainer

            readonly property real rawWidth: {
                const itemCount = root.hiddenBarItems.length
                const cols = Math.min(5, itemCount)
                const itemSize = 28
                const spacing = 2
                return cols * itemSize + (cols - 1) * spacing + Theme.spacingS * 2
            }
            readonly property real rawHeight: {
                const itemCount = root.hiddenBarItems.length
                const cols = Math.min(5, itemCount)
                const rows = Math.ceil(itemCount / cols)
                const itemSize = 28
                const spacing = 2
                return rows * itemSize + (rows - 1) * spacing + Theme.spacingS * 2
            }

            readonly property real alignedWidth: Theme.px(rawWidth, overflowMenu.dpr)
            readonly property real alignedHeight: Theme.px(rawHeight, overflowMenu.dpr)

            width: alignedWidth
            height: alignedHeight

            x: Theme.snap((() => {
                if (root.isVertical) {
                    const edge = root.axis?.edge
                    if (edge === "left") {
                        const targetX = overflowMenu.anchorPos.x
                        return Math.min(overflowMenu.screen.width - alignedWidth - 10, targetX)
                    } else {
                        const targetX = overflowMenu.anchorPos.x - alignedWidth
                        return Math.max(10, targetX)
                    }
                } else {
                    const left = 10
                    const right = overflowMenu.width - alignedWidth - 10
                    const want = overflowMenu.anchorPos.x - alignedWidth / 2
                    return Math.max(left, Math.min(right, want))
                }
            })(), overflowMenu.dpr)

            y: Theme.snap((() => {
                if (root.isVertical) {
                    const top = 10
                    const bottom = overflowMenu.height - alignedHeight - 10
                    const want = overflowMenu.anchorPos.y - alignedHeight / 2
                    return Math.max(top, Math.min(bottom, want))
                } else {
                    if (root.isAtBottom) {
                        const targetY = overflowMenu.anchorPos.y - alignedHeight
                        return Math.max(10, targetY)
                    } else {
                        const targetY = overflowMenu.anchorPos.y
                        return Math.min(overflowMenu.screen.height - alignedHeight - 10, targetY)
                    }
                }
            })(), overflowMenu.dpr)

            property real shadowBlurPx: 10
            property real shadowSpreadPx: 0
            property real shadowBaseAlpha: 0.60
            readonly property real popupSurfaceAlpha: Theme.popupTransparency
            readonly property real effectiveShadowAlpha: Math.max(0, Math.min(1, shadowBaseAlpha * popupSurfaceAlpha))

            opacity: root.menuOpen ? 1 : 0
            scale: root.menuOpen ? 1 : 0.85

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

            Item {
                id: bgShadowLayer
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true
                layer.textureSize: Qt.size(Math.round(width * overflowMenu.dpr * 2), Math.round(height * overflowMenu.dpr * 2))
                layer.textureMirroring: ShaderEffectSource.MirrorVertically
                layer.samples: 4

                layer.effect: MultiEffect {
                    autoPaddingEnabled: true
                    shadowEnabled: true
                    blurEnabled: false
                    maskEnabled: false
                    property int blurMax: 64
                    shadowBlur: Math.max(0, Math.min(1, menuContainer.shadowBlurPx / blurMax))
                    shadowScale: 1 + (2 * menuContainer.shadowSpreadPx) / Math.max(1, Math.min(bgShadowLayer.width, bgShadowLayer.height))
                    shadowColor: {
                        const baseColor = Theme.isLightMode ? Qt.rgba(0, 0, 0, 1) : Theme.surfaceContainerHighest
                        return Theme.withAlpha(baseColor, menuContainer.effectiveShadowAlpha)
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
                    radius: Theme.cornerRadius
                    antialiasing: true
                    smooth: true
                }
            }

            Grid {
                id: menuGrid
                anchors.centerIn: parent
                columns: Math.min(5, root.hiddenBarItems.length)
                spacing: 2
                rowSpacing: 2

                Repeater {
                    model: root.hiddenBarItems

                    delegate: Rectangle {
                        property var trayItem: modelData
                        property string iconSource: {
                            let icon = trayItem?.icon
                            if (typeof icon === 'string' || icon instanceof String) {
                                if (icon === "") return ""
                                if (icon.includes("?path=")) {
                                    const split = icon.split("?path=")
                                    if (split.length !== 2) return icon
                                    const name = split[0]
                                    const path = split[1]
                                    let fileName = name.substring(name.lastIndexOf("/") + 1)
                                    if (fileName.startsWith("dropboxstatus")) {
                                        fileName = `hicolor/16x16/status/${fileName}`
                                    }
                                    return `file://${path}/${fileName}`
                                }
                                if (icon.startsWith("/") && !icon.startsWith("file://")) {
                                    return `file://${icon}`
                                }
                                return icon
                            }
                            return ""
                        }

                        width: 28
                        height: 28
                        radius: Theme.cornerRadius
                        color: itemArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.surfaceContainer, 0)

                        IconImage {
                            id: menuIconImg
                            anchors.centerIn: parent
                            width: Theme.barIconSize(root.barThickness)
                            height: Theme.barIconSize(root.barThickness)
                            source: parent.iconSource
                            asynchronous: true
                            smooth: true
                            mipmap: true
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !menuIconImg.visible
                            text: {
                                const itemId = trayItem?.id || ""
                                if (!itemId) return "?"
                                return itemId.charAt(0).toUpperCase()
                            }
                            font.pixelSize: 10
                            color: Theme.surfaceText
                        }

                        MouseArea {
                            id: itemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                if (!trayItem) return

                                if (mouse.button === Qt.LeftButton && !trayItem.onlyMenu) {
                                    trayItem.activate()
                                    root.menuOpen = false
                                    return
                                }

                                if (!trayItem.hasMenu) return

                                root.overflowWasOpenBeforeTrayMenu = true
                                root.menuOpen = false
                                root.showForTrayItem(trayItem, parent, parentScreen, root.isAtBottom, root.isVertical, root.axis)
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: root.menuOpen = false
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
                if (root.overflowWasOpenBeforeTrayMenu) {
                    root.menuOpen = true
                    Qt.callLater(() => {
                        if (overflowMenu.visible && overflowFocusScope) {
                            overflowFocusScope.forceActiveFocus()
                        }
                    })
                }
                root.overflowWasOpenBeforeTrayMenu = false
            }

            function closeWithAction() {
                root.overflowWasOpenBeforeTrayMenu = false
                close()
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

                WlrLayershell.namespace: "dms:tray-menu-window"

                id: menuWindow
                visible: menuRoot.showMenu && (menuRoot.trayItem?.hasMenu ?? false)
                WlrLayershell.layer: WlrLayershell.Top
                WlrLayershell.exclusiveZone: -1
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
                color: "transparent"

                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }

                readonly property real dpr: (typeof CompositorService !== "undefined" && CompositorService.getScreenScale)
                    ? CompositorService.getScreenScale(menuWindow.screen)
                    : (screen?.devicePixelRatio || 1)
                property point anchorPos: Qt.point(screen.width / 2, screen.height / 2)

                onVisibleChanged: {
                    if (visible) {
                        updatePosition()
                        Qt.callLater(() => menuFocusScope.forceActiveFocus())
                    }
                }

                FocusScope {
                    id: menuFocusScope
                    anchors.fill: parent
                    focus: true

                    Keys.onEscapePressed: {
                        if (entryStack.count > 0) {
                            menuRoot.goBack()
                        } else {
                            menuRoot.close()
                        }
                    }
                }

                function updatePosition() {
                    if (!root.parentWindow) {
                        anchorPos = Qt.point(screen.width / 2, screen.height / 2)
                        return
                    }

                    const globalPos = root.mapToGlobal(0, 0)
                    const screenX = screen.x || 0
                    const screenY = screen.y || 0
                    const relativeX = globalPos.x - screenX
                    const relativeY = globalPos.y - screenY

                    const widgetThickness = Math.max(20, 26 + SettingsData.dankBarInnerPadding * 0.6)
                    const effectiveBarThickness = Math.max(widgetThickness + SettingsData.dankBarInnerPadding + 4, Theme.barHeight - 4 - (8 - SettingsData.dankBarInnerPadding))

                    if (root.isVertical) {
                        const edge = root.axis?.edge
                        let targetX = edge === "left"
                            ? effectiveBarThickness + SettingsData.dankBarSpacing + Theme.popupDistance
                            : screen.width - (effectiveBarThickness + SettingsData.dankBarSpacing + Theme.popupDistance)
                        anchorPos = Qt.point(targetX, relativeY + root.height / 2)
                    } else {
                        let targetY = root.isAtBottom
                            ? screen.height - (effectiveBarThickness + SettingsData.dankBarSpacing + SettingsData.dankBarBottomGap + Theme.popupDistance)
                            : effectiveBarThickness + SettingsData.dankBarSpacing + SettingsData.dankBarBottomGap + Theme.popupDistance
                        anchorPos = Qt.point(relativeX + root.width / 2, targetY)
                    }
                }

                Item {
                    id: menuContainer

                    readonly property real rawWidth: Math.min(500, Math.max(250, menuColumn.implicitWidth + Theme.spacingS * 2))
                    readonly property real rawHeight: Math.max(40, menuColumn.implicitHeight + Theme.spacingS * 2)

                    readonly property real alignedWidth: Theme.px(rawWidth, menuWindow.dpr)
                    readonly property real alignedHeight: Theme.px(rawHeight, menuWindow.dpr)

                    width: alignedWidth
                    height: alignedHeight

                    x: Theme.snap((() => {
                        if (menuRoot.isVertical) {
                            const edge = menuRoot.axis?.edge
                            if (edge === "left") {
                                const targetX = menuWindow.anchorPos.x
                                return Math.min(menuWindow.screen.width - alignedWidth - 10, targetX)
                            } else {
                                const targetX = menuWindow.anchorPos.x - alignedWidth
                                return Math.max(10, targetX)
                            }
                        } else {
                            const left = 10
                            const right = menuWindow.width - alignedWidth - 10
                            const want = menuWindow.anchorPos.x - alignedWidth / 2
                            return Math.max(left, Math.min(right, want))
                        }
                    })(), menuWindow.dpr)

                    y: Theme.snap((() => {
                        if (menuRoot.isVertical) {
                            const top = 10
                            const bottom = menuWindow.height - alignedHeight - 10
                            const want = menuWindow.anchorPos.y - alignedHeight / 2
                            return Math.max(top, Math.min(bottom, want))
                        } else {
                            if (menuRoot.isAtBottom) {
                                const targetY = menuWindow.anchorPos.y - alignedHeight
                                return Math.max(10, targetY)
                            } else {
                                const targetY = menuWindow.anchorPos.y
                                return Math.min(menuWindow.screen.height - alignedHeight - 10, targetY)
                            }
                        }
                    })(), menuWindow.dpr)

                    property real shadowBlurPx: 10
                    property real shadowSpreadPx: 0
                    property real shadowBaseAlpha: 0.60
                    readonly property real popupSurfaceAlpha: Theme.popupTransparency
                    readonly property real effectiveShadowAlpha: Math.max(0, Math.min(1, shadowBaseAlpha * popupSurfaceAlpha))

                    opacity: menuRoot.showMenu ? 1 : 0
                    scale: menuRoot.showMenu ? 1 : 0.85

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

                    Item {
                        id: menuBgShadowLayer
                        anchors.fill: parent
                        layer.enabled: true
                        layer.smooth: true
                        layer.textureSize: Qt.size(Math.round(width * menuWindow.dpr), Math.round(height * menuWindow.dpr))
                        layer.textureMirroring: ShaderEffectSource.MirrorVertically

                        layer.effect: MultiEffect {
                            autoPaddingEnabled: true
                            shadowEnabled: true
                            blurEnabled: false
                            maskEnabled: false
                            property int blurMax: 64
                            shadowBlur: Math.max(0, Math.min(1, menuContainer.shadowBlurPx / blurMax))
                            shadowScale: 1 + (2 * menuContainer.shadowSpreadPx) / Math.max(1, Math.min(menuBgShadowLayer.width, menuBgShadowLayer.height))
                            shadowColor: {
                                const baseColor = Theme.isLightMode ? Qt.rgba(0, 0, 0, 1) : Theme.surfaceContainerHighest
                                return Theme.withAlpha(baseColor, menuContainer.effectiveShadowAlpha)
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
                            radius: Theme.cornerRadius
                            antialiasing: true
                        }
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
                            visible: entryStack.count === 0
                            width: parent.width
                            height: 28
                            radius: 0
                            color: visibilityToggleArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.surfaceContainer, 0)

                            StyledText {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                text: menuRoot.trayItem?.id || "Unknown"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceTextMedium
                                elide: Text.ElideMiddle
                                width: parent.width - Theme.spacingS * 2 - 24
                            }

                            DankIcon {
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                name: SessionData.isHiddenTrayId(menuRoot.trayItem?.id || "") ? "visibility" : "visibility_off"
                                size: 16
                                color: Theme.surfaceText
                            }

                            MouseArea {
                                id: visibilityToggleArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const itemId = menuRoot.trayItem?.id || ""
                                    if (!itemId) return

                                    if (SessionData.isHiddenTrayId(itemId)) {
                                        SessionData.showTrayId(itemId)
                                    } else {
                                        SessionData.hideTrayId(itemId)
                                    }
                                    menuRoot.closeWithAction()
                                }
                            }
                        }

                        Rectangle {
                            visible: entryStack.count === 0
                            width: parent.width
                            height: 1
                            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                        }

                        Rectangle {
                            visible: entryStack.count > 0
                            width: parent.width
                            height: 28
                            radius: 0
                            color: backArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.surfaceContainer, 0)

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
                                radius: 0
                                color: {
                                    if (menuEntry?.isSeparator) {
                                        return Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                    }
                                    return itemArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.surfaceContainer, 0)
                                }

                                MouseArea {
                                    id: itemArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !menuEntry?.isSeparator && (menuEntry?.enabled !== false)
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        if (!menuEntry || menuEntry.isSeparator) return

                                        if (menuEntry.hasChildren) {
                                            menuRoot.showSubMenu(menuEntry)
                                            return
                                        }

                                        if (typeof menuEntry.activate === "function") {
                                            menuEntry.activate()
                                        } else if (typeof menuEntry.triggered === "function") {
                                            menuEntry.triggered()
                                        }
                                        Qt.createQmlObject('import QtQuick; Timer { interval: 80; running: true; repeat: false; onTriggered: menuRoot.closeWithAction() }', menuRoot)
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

    Connections {
        target: currentTrayMenu
        enabled: currentTrayMenu !== null
        function onShowMenuChanged() {
            if (parentWindow && typeof parentWindow.systemTrayMenuOpen !== "undefined") {
                parentWindow.systemTrayMenuOpen = currentTrayMenu.showMenu
            }
        }
    }

    function showForTrayItem(item, anchor, screen, atBottom, vertical, axisObj) {
        if (parentWindow && typeof parentWindow.systemTrayMenuOpen !== "undefined") {
            parentWindow.systemTrayMenuOpen = true
        }

        if (currentTrayMenu) {
            currentTrayMenu.destroy()
        }
        currentTrayMenu = trayMenuComponent.createObject(null)
        if (currentTrayMenu) {
            currentTrayMenu.showForTrayItem(item, anchor, screen, atBottom, vertical ?? false, axisObj)
        }
    }

}
