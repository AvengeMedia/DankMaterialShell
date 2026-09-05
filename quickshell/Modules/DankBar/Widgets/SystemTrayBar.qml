import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    enableBackgroundHover: false
    enableCursor: false

    property var parentWindow: null
    property var widgetData: null
    property string section: "right"
    property bool isAtBottom: false
    property bool isAutoHideBar: false
    property bool useOverflowPopup: !widgetData?.trayUseInlineExpansion
    property bool useSingleLineOverflowPopup: widgetData?.trayPopupSingleLine ?? SettingsData.trayPopupSingleLine
    property bool useAutomaticOverflow: widgetData?.trayAutoOverflow ?? SettingsData.trayAutoOverflow
    property int configuredMaxVisibleItems: widgetData?.trayMaxVisibleItems ?? SettingsData.trayMaxVisibleItems
    property real configuredIconSpacing: Math.max(0, widgetData?.trayIconSpacing ?? SettingsData.trayIconSpacing)
    property real sectionAvailablePrimarySize: 0
    readonly property var hiddenTrayIds: {
        const envValue = Quickshell.env("DMS_HIDE_TRAYIDS") || "";
        return envValue ? envValue.split(",").map(id => id.trim().toLowerCase()) : [];
    }
    readonly property var allTrayItems: {
        if (!hiddenTrayIds.length) {
            return SystemTray.items.values;
        }
        return SystemTray.items.values.filter(item => {
            const itemId = item?.id || "";
            return !hiddenTrayIds.includes(itemId.toLowerCase());
        });
    }
    function getTrayItemKey(item) {
        const id = item?.id || "";
        const tooltipTitle = item?.tooltipTitle || "";
        if (!tooltipTitle || tooltipTitle === id) {
            return id;
        }
        return `${id}::${tooltipTitle}`;
    }

    function trayIconSourceFor(trayItem) {
        let icon = trayItem && trayItem.icon;
        if (typeof icon === 'string' || icon instanceof String) {
            if (icon === "")
                return "";
            if (icon.includes("?path=")) {
                const split = icon.split("?path=");
                if (split.length !== 2)
                    return icon;
                const name = split[0];
                const path = split[1];
                let fileName = name.substring(name.lastIndexOf("/") + 1);
                if (fileName.startsWith("dropboxstatus")) {
                    fileName = `hicolor/16x16/status/${fileName}`;
                }
                return `file://${path}/${fileName}`;
            }
            if (icon.startsWith("/") && !icon.startsWith("file://"))
                return `file://${icon}`;
            return icon;
        }
        return "";
    }

    function activateInlineTrayItem(trayItem, anchorItem) {
        if (!trayItem)
            return;
        if (!trayItem.onlyMenu) {
            trayItem.activate();
            return;
        }
        if (!trayItem.hasMenu)
            return;
        root.showForTrayItem(trayItem, anchorItem, parentScreen, root.isAtBottom, root.isVerticalOrientation, root.axis);
    }

    Connections {
        target: TrayMenuManager

        function onOpenTrayMenuRequested() {
            const request = TrayMenuManager.claimMenuRequest(root.parentScreen?.name);
            if (!request)
                return;

            const item = TrayMenuManager.findTrayItem(request.itemId);
            if (!item || !item.hasMenu)
                return;

            root.showForTrayItem(item, root, parentScreen, root.isAtBottom, root.isVerticalOrientation, root.axis);
        }
    }

    function openInlineTrayContextMenu(trayItem, areaItem, mouse, anchorItem) {
        if (!trayItem) {
            return;
        }
        if (!trayItem.hasMenu) {
            const gp = areaItem.mapToGlobal(mouse.x, mouse.y);
            root.callContextMenuFallback(trayItem.id, Math.round(gp.x), Math.round(gp.y));
            return;
        }
        root.showForTrayItem(trayItem, anchorItem, parentScreen, root.isAtBottom, root.isVerticalOrientation, root.axis);
    }

    function toggleIconName() {
        const edge = root.axis?.edge;
        if (root.useOverflowPopup) {
            switch (edge) {
            case "left":
                return root.menuOpen ? "keyboard_arrow_left" : "keyboard_arrow_right";
            case "right":
                return root.menuOpen ? "keyboard_arrow_right" : "keyboard_arrow_left";
            case "bottom":
                return root.menuOpen ? "keyboard_arrow_down" : "keyboard_arrow_up";
            case "top":
                return root.menuOpen ? "keyboard_arrow_up" : "keyboard_arrow_down";
            }
        }

        if (edge === "left" || edge === "right") {
            return root.menuOpen == (root.section !== "right") ? "keyboard_arrow_up" : "keyboard_arrow_down";
        }

        return root.menuOpen != (root.section === "right") ? "keyboard_arrow_left" : "keyboard_arrow_right";
    }

    // ! TODO - replace with either native dbus client (like plugins use) or just a DMS cli or something
    function callContextMenuFallback(trayItemId, globalX, globalY) {
        const script = ['ITEMS=$(dbus-send --session --print-reply --dest=org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.freedesktop.DBus.Properties.Get string:org.kde.StatusNotifierWatcher string:RegisteredStatusNotifierItems 2>/dev/null)', 'while IFS= read -r line; do', '  line="${line#*\\\"}"', '  line="${line%\\\"*}"', '  [ -z "$line" ] && continue', '  BUS="${line%%/*}"', '  OBJ="/${line#*/}"', '  ID=$(dbus-send --session --print-reply --dest="$BUS" "$OBJ" org.freedesktop.DBus.Properties.Get string:org.kde.StatusNotifierItem string:Id 2>/dev/null | grep -oP "(?<=\\\")(.*?)(?=\\\")" | tail -1)', '  if [ "$ID" = "$1" ]; then', '    dbus-send --session --type=method_call --dest="$BUS" "$OBJ" org.kde.StatusNotifierItem.ContextMenu int32:"$2" int32:"$3"', '    exit 0', '  fi', 'done <<< "$ITEMS"',].join("\n");
        Quickshell.execDetached(["bash", "-c", script, "_", trayItemId, String(globalX), String(globalY)]);
    }

    property int _trayOrderTrigger: 0

    Connections {
        target: SessionData
        function onTrayItemOrderChanged() {
            root._trayOrderTrigger++;
        }
    }

    function sortByPreferredOrder(items, trigger) {
        void trigger;
        const savedOrder = SessionData.trayItemOrder || [];
        const orderMap = new Map();
        savedOrder.forEach((key, idx) => orderMap.set(key, idx));

        return [...items].sort((a, b) => {
            const keyA = getTrayItemKey(a);
            const keyB = getTrayItemKey(b);
            const orderA = orderMap.has(keyA) ? orderMap.get(keyA) : 10000 + items.indexOf(a);
            const orderB = orderMap.has(keyB) ? orderMap.get(keyB) : 10000 + items.indexOf(b);
            return orderA - orderB;
        });
    }

    readonly property var allSortedTrayItems: sortByPreferredOrder(allTrayItems, _trayOrderTrigger)
    readonly property var allSortedTrayItemKeys: allSortedTrayItems.map(item => getTrayItemKey(item))
    readonly property var visibleSortedTrayItems: allSortedTrayItems.filter(item => !SessionData.isHiddenTrayId(root.getTrayItemKey(item)))
    readonly property int automaticVisibleItemLimit: {
        if (!root.useAutomaticOverflow)
            return root.visibleSortedTrayItems.length;

        const explicitLimit = Number(root.configuredMaxVisibleItems || 0);
        if (explicitLimit > 0)
            return Math.max(1, Math.min(root.visibleSortedTrayItems.length, explicitLimit));

        const scale = (typeof CompositorService !== "undefined" && CompositorService.getScreenScale) ? Math.max(1, CompositorService.getScreenScale(root.parentScreen)) : 1;
        const sectionPrimary = root.sectionAvailablePrimarySize > 0 ? root.sectionAvailablePrimarySize : (root.isVerticalOrientation ? (root.parentScreen?.height || 0) : (root.parentScreen?.width || 0));
        const logicalPrimary = sectionPrimary > 0 ? (sectionPrimary / scale) : 640;
        const maxTrayShare = root.isVerticalOrientation ? 0.55 : 0.50;
        const itemSize = Math.max(1, root.trayItemSize + root.configuredIconSpacing);
        const slots = Math.floor((logicalPrimary * maxTrayShare) / itemSize);
        return Math.max(2, Math.min(10, Math.min(root.visibleSortedTrayItems.length, slots)));
    }
    readonly property var mainBarItemsRaw: visibleSortedTrayItems.slice(0, automaticVisibleItemLimit)
    readonly property var mainBarItems: mainBarItemsRaw.map((item, idx) => ({
                key: getTrayItemKey(item),
                item: item
            }))
    readonly property var autoOverflowBarItems: visibleSortedTrayItems.slice(automaticVisibleItemLimit)
    readonly property var manualHiddenBarItems: allSortedTrayItems.filter(item => SessionData.isHiddenTrayId(root.getTrayItemKey(item)))
    readonly property var hiddenBarItemKeys: manualHiddenBarItems.concat(autoOverflowBarItems).map(item => root.getTrayItemKey(item))
    readonly property var hiddenBarItems: allSortedTrayItems.filter(item => hiddenBarItemKeys.indexOf(root.getTrayItemKey(item)) !== -1)
    readonly property string trayIconTintMode: {
        const configuredMode = SettingsData.systemTrayIconTintMode || "none";
        switch (configuredMode) {
        case "monochrome":
        case "primary":
        case "secondary":
            return configuredMode;
        default:
            return "none";
        }
    }
    readonly property bool trayIconTintEnabled: trayIconTintMode !== "none"
    readonly property real trayIconTintSaturationAmount: {
        const raw = SettingsData.systemTrayIconTintSaturation;
        const value = (raw === undefined || raw === null) ? 50 : raw;
        return Math.max(0, Math.min(100, value)) / 100;
    }
    readonly property real trayIconTintStrengthAmount: {
        const raw = SettingsData.systemTrayIconTintStrength;
        const value = (raw === undefined || raw === null) ? 135 : raw;
        return Math.max(0, Math.min(200, value)) / 100;
    }
    readonly property real trayIconSaturation: {
        switch (trayIconTintMode) {
        case "monochrome":
            return -1;
        case "primary":
        case "secondary":
            return -root.trayIconTintSaturationAmount;
        default:
            return 0;
        }
    }
    readonly property real trayIconColorization: {
        switch (trayIconTintMode) {
        case "primary":
        case "secondary":
            return root.trayIconTintStrengthAmount;
        default:
            return 0;
        }
    }
    readonly property color trayIconTintColor: {
        switch (trayIconTintMode) {
        case "primary":
            return Theme.primary;
        case "secondary":
            return Theme.secondary;
        default:
            return Theme.surfaceText;
        }
    }

    readonly property bool reverseInlineHorizontal: !useOverflowPopup && !isVerticalOrientation && section === "right"
    readonly property bool reverseInlineVertical: !useOverflowPopup && isVerticalOrientation && section === "right"
    readonly property var displayedMainBarItems: reverseInlineHorizontal ? [...mainBarItems].reverse() : mainBarItems
    readonly property var displayedInlineExpandedItems: (reverseInlineHorizontal ? [...hiddenBarItems].reverse() : hiddenBarItems).map(item => ({
                key: getTrayItemKey(item),
                item: item
            }))

    function moveTrayItemInFullOrder(visibleFromIndex, visibleToIndex) {
        if (visibleFromIndex === visibleToIndex || visibleFromIndex < 0 || visibleToIndex < 0)
            return;

        const fromKey = mainBarItems[visibleFromIndex]?.key ?? null;
        const toKey = mainBarItems[visibleToIndex]?.key ?? null;
        moveTrayItemKeyInFullOrder(fromKey, toKey);
    }

    function moveTrayItemKeyInFullOrder(fromKey, toKey) {
        if (!fromKey || !toKey)
            return;

        const fullOrder = [...allSortedTrayItemKeys];
        const fullFromIndex = fullOrder.indexOf(fromKey);
        const fullToIndex = fullOrder.indexOf(toKey);
        if (fullFromIndex < 0 || fullToIndex < 0)
            return;

        const movedKey = fullOrder.splice(fullFromIndex, 1)[0];
        fullOrder.splice(fullToIndex, 0, movedKey);
        SessionData.setTrayItemOrder(fullOrder);
    }

    function promoteTrayItemToBar(item) {
        const itemKey = getTrayItemKey(item);
        if (!itemKey)
            return;
        if (SessionData.isHiddenTrayId(itemKey)) {
            SessionData.showTrayId(itemKey);
            return;
        }

        const fullOrder = [...allSortedTrayItemKeys];
        const fromIndex = fullOrder.indexOf(itemKey);
        if (fromIndex < 0)
            return;
        const movedKey = fullOrder.splice(fromIndex, 1)[0];
        const targetIndex = Math.max(0, Math.min(root.automaticVisibleItemLimit - 1, fullOrder.length));
        fullOrder.splice(targetIndex, 0, movedKey);
        SessionData.setTrayItemOrder(fullOrder);
    }

    function isManualHiddenTrayItem(item) {
        return SessionData.isHiddenTrayId(getTrayItemKey(item));
    }

    function isAutoOverflowTrayItem(item) {
        const key = getTrayItemKey(item);
        return key && !isManualHiddenTrayItem(item) && root.autoOverflowBarItems.some(overflowItem => getTrayItemKey(overflowItem) === key);
    }

    function dragShiftOffset(index, draggedIndex, dropTargetIndex, shiftAmount) {
        if (draggedIndex < 0 || index === draggedIndex || dropTargetIndex < 0)
            return 0;
        if (draggedIndex < dropTargetIndex && index > draggedIndex && index <= dropTargetIndex)
            return -shiftAmount;
        if (draggedIndex > dropTargetIndex && index >= dropTargetIndex && index < draggedIndex)
            return shiftAmount;
        return 0;
    }

    function beginMainDrag(visualIndex, reversed) {
        root.draggedIndex = reversed ? (root.mainBarItems.length - 1 - visualIndex) : visualIndex;
        root.dropTargetIndex = root.draggedIndex;
    }

    function updateMainDrag(axisOffset, visualIndex, reversed) {
        const itemSize = root.trayItemSize + root.configuredIconSpacing;
        const slotOffset = Math.round(axisOffset / itemSize);
        const visualTargetIndex = Math.max(0, Math.min(root.mainBarItems.length - 1, visualIndex + slotOffset));
        const newTargetIndex = reversed ? (root.mainBarItems.length - 1 - visualTargetIndex) : visualTargetIndex;
        if (newTargetIndex !== root.dropTargetIndex)
            root.dropTargetIndex = newTargetIndex;
    }

    function finishMainDrag() {
        const didReorder = root.dropTargetIndex >= 0 && root.dropTargetIndex !== root.draggedIndex;
        if (didReorder) {
            root.suppressShiftAnimation = true;
            root.moveTrayItemInFullOrder(root.draggedIndex, root.dropTargetIndex);
            Qt.callLater(() => root.suppressShiftAnimation = false);
        }
        root.draggedIndex = -1;
        root.dropTargetIndex = -1;
        return didReorder;
    }

    function beginPopupDrag(index) {
        root.popupDraggedIndex = index;
        root.popupDropTargetIndex = index;
    }

    function updatePopupDrag(axisOffset, index) {
        const itemSize = root.trayItemSize + 6;
        const slotOffset = Math.round(axisOffset / itemSize);
        const newTargetIndex = Math.max(0, Math.min(root.hiddenBarItems.length - 1, index + slotOffset));
        if (newTargetIndex !== root.popupDropTargetIndex)
            root.popupDropTargetIndex = newTargetIndex;
    }

    function finishPopupDrag() {
        const didReorder = root.popupDropTargetIndex >= 0 && root.popupDropTargetIndex !== root.popupDraggedIndex;
        if (didReorder) {
            const fromItem = root.hiddenBarItems[root.popupDraggedIndex];
            const toItem = root.hiddenBarItems[root.popupDropTargetIndex];
            root.suppressShiftAnimation = true;
            root.moveTrayItemKeyInFullOrder(root.getTrayItemKey(fromItem), root.getTrayItemKey(toItem));
            Qt.callLater(() => root.suppressShiftAnimation = false);
        }
        root.popupDraggedIndex = -1;
        root.popupDropTargetIndex = -1;
        return didReorder;
    }

    property int draggedIndex: -1
    property int dropTargetIndex: -1
    property int popupDraggedIndex: -1
    property int popupDropTargetIndex: -1
    property bool suppressShiftAnimation: false
    readonly property bool hasHiddenItems: hiddenBarItems.length > 0
    readonly property bool inlineExpanded: hasHiddenItems && !useOverflowPopup && menuOpen
    visible: allTrayItems.length > 0
    opacity: allTrayItems.length > 0 ? 1 : 0

    states: [
        State {
            name: "hidden_horizontal"
            when: allTrayItems.length === 0 && !isVerticalOrientation
            PropertyChanges {
                target: root
                width: 0
            }
        },
        State {
            name: "hidden_vertical"
            when: allTrayItems.length === 0 && isVerticalOrientation
            PropertyChanges {
                target: root
                height: 0
            }
        }
    ]

    transitions: [
        Transition {
            NumberAnimation {
                properties: "width,height"
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }
    ]

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    readonly property real trayItemSize: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale) + 6

    readonly property real minTooltipY: {
        if (!parentScreen || !isVerticalOrientation) {
            return 0;
        }

        if (isAutoHideBar) {
            return 0;
        }

        if (parentScreen.y > 0) {
            const estimatedTopBarHeight = barThickness + barSpacing;
            return estimatedTopBarHeight;
        }

        return 0;
    }

    readonly property string autoBarShadowDirection: {
        const edge = root.axis?.edge;
        switch (edge) {
        case "top":
            return "top";
        case "bottom":
            return "bottom";
        case "left":
            return "left";
        case "right":
            return "right";
        default:
            return "bottom";
        }
    }
    readonly property string effectiveShadowDirection: Theme.elevationLightDirection === "autoBar" ? autoBarShadowDirection : Theme.elevationLightDirection

    property bool menuOpen: false

    function _openOverflowAt(triggerItem) {
        if (!triggerItem || !root.parentScreen)
            return;
        const barPosition = root.axis?.edge === "left" ? 2 : (root.axis?.edge === "right" ? 3 : (root.axis?.edge === "top" ? 0 : 1));
        const triggerPos = triggerItem.mapToItem(null, 0, root.isVerticalOrientation ? (triggerItem.height / 2 + root.minTooltipY) : 0);
        const pos = SettingsData.getPopupTriggerPosition(triggerPos, root.parentScreen, root.barThickness, triggerItem.width, root.barSpacing, barPosition, root.barConfig);
        overflowPopout.setTriggerPosition(pos.x, pos.y, pos.width, root.section, root.parentScreen, barPosition, root.barThickness, root.barSpacing, root.barConfig);
        root.menuOpen = true;
        PopoutManager.requestPopout(overflowPopout, undefined, "tray-overflow-" + root.section);
    }

    readonly property real overflowRawWidth: {
        const itemCount = root.hiddenBarItems.length;
        if (itemCount === 0)
            return 0;
        const popupUsesVerticalLine = root.useSingleLineOverflowPopup && root.isVerticalOrientation;
        const popupPadding = Theme.spacingS + (popupUsesVerticalLine ? 3 : 0);
        if (popupUsesVerticalLine)
            return root.trayItemSize + 4 + popupPadding * 2;
        const cols = root.useSingleLineOverflowPopup ? itemCount : Math.min(5, itemCount);
        const itemSize = root.trayItemSize + 4;
        const spacing = 2;
        const desiredWidth = cols * itemSize + (cols - 1) * spacing + popupPadding * 2;
        if (!root.useSingleLineOverflowPopup)
            return desiredWidth;
        const maxWidth = Math.max(itemSize + popupPadding * 2, (root.parentScreen?.width || 1920) - 20);
        return Math.min(desiredWidth, maxWidth);
    }

    readonly property real overflowRawHeight: {
        const itemCount = root.hiddenBarItems.length;
        if (itemCount === 0)
            return 0;
        const popupUsesVerticalLine = root.useSingleLineOverflowPopup && root.isVerticalOrientation;
        const popupPadding = Theme.spacingS + (popupUsesVerticalLine ? 3 : 0);
        const itemSize = root.trayItemSize + 4;
        const spacing = 2;
        if (popupUsesVerticalLine) {
            const desiredHeight = itemCount * itemSize + (itemCount - 1) * spacing + popupPadding * 2;
            const maxHeight = Math.max(itemSize + popupPadding * 2, (root.parentScreen?.height || 1080) - 20);
            return Math.min(desiredHeight, maxHeight);
        }
        const cols = root.useSingleLineOverflowPopup ? itemCount : Math.min(5, itemCount);
        const rows = Math.ceil(itemCount / cols);
        return rows * itemSize + (rows - 1) * spacing + popupPadding * 2;
    }

    DankPopout {
        id: overflowPopout
        layerNamespace: "dms:tray-overflow"
        screen: root.parentScreen
        popupWidth: root.overflowRawWidth
        popupHeight: root.overflowRawHeight
        content: overflowContentComponent
    }

    DankPopout {
        id: trayMenuPopout
        layerNamespace: "dms:tray-menu"
        screen: root.parentScreen
        popupWidth: trayMenuState.computedWidth
        popupHeight: trayMenuState.computedHeight
        content: trayMenuContentComponent
        contentHandlesKeys: true
        property alias openedByHover: trayMenuState.openedByHover
        onOpened: {
            contentLoader.item?.entryStack?.clear();
            contentLoader.item?.forceActiveFocus();
        }
    }

    Connections {
        target: overflowPopout
        function onBackgroundClicked() { root.menuOpen = false; }
        function onPopoutClosed() { root.menuOpen = false; }
    }

    function _unregisterMenuIfMatches(targetMenu) {
        if (!root.parentScreen || !targetMenu)
            return;
        const currentRegistered = TrayMenuManager.activeTrayMenus[root.parentScreen.name];
        if (currentRegistered === targetMenu) {
            TrayMenuManager.unregisterMenu(root.parentScreen.name);
        }
    }

    onMenuOpenChanged: {
        if (!root.useOverflowPopup || !root.parentScreen)
            return;
        if (root.menuOpen) {
            trayMenuState.close();
            TrayMenuManager.registerMenu(root.parentScreen.name, overflowPopout);
        } else {
            root._unregisterMenuIfMatches(overflowPopout);
            overflowPopout.close();
        }
    }

    content: Component {
        Item {
            implicitWidth: layoutLoader.item ? layoutLoader.item.implicitWidth : 0
            implicitHeight: layoutLoader.item ? layoutLoader.item.implicitHeight : 0

            Loader {
                id: layoutLoader
                anchors.centerIn: parent
                sourceComponent: root.isVerticalOrientation ? columnComp : rowComp
            }
        }
    }

    Component {
        id: rowComp
        Row {
            spacing: root.configuredIconSpacing
            layoutDirection: root.reverseInlineHorizontal ? Qt.RightToLeft : Qt.LeftToRight

            Repeater {
                model: ScriptModel {
                    values: root.displayedMainBarItems
                    objectProp: "key"
                }

                delegate: Item {
                    id: delegateRoot
                    property var trayItem: modelData.item
                    property string itemKey: modelData.key
                    property string iconSource: root.trayIconSourceFor(trayItem)

                    width: root.trayItemSize
                    height: root.barThickness
                    z: dragHandler.dragging ? 100 : 0

                    property real shiftOffset: root.dragShiftOffset(index, root.draggedIndex, root.dropTargetIndex, root.trayItemSize + root.configuredIconSpacing)

                    transform: Translate {
                        x: delegateRoot.shiftOffset
                        Behavior on x {
                            enabled: !root.suppressShiftAnimation
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Item {
                        id: dragHandler
                        anchors.fill: parent
                        property bool dragging: false
                        property point dragStartPos: Qt.point(0, 0)
                        property real dragAxisOffset: 0
                        property bool longPressing: false

                        Timer {
                            id: longPressTimer
                            interval: 400
                            repeat: false
                            onTriggered: dragHandler.longPressing = true
                        }
                    }

                    Rectangle {
                        id: visualContent
                        width: root.trayItemSize
                        height: root.trayItemSize
                        anchors.centerIn: parent
                        radius: Theme.cornerRadius
                        color: trayItemArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : Theme.withAlpha(BlurService.hoverColor(Theme.widgetBaseHoverColor), 0)
                        border.width: dragHandler.dragging ? 2 : 0
                        border.color: Theme.primary
                        opacity: dragHandler.dragging ? 0.8 : 1.0

                        transform: Translate {
                            x: dragHandler.dragging ? dragHandler.dragAxisOffset : 0
                        }

                        IconImage {
                            id: iconImg
                            anchors.centerIn: parent
                            width: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                            height: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                            source: delegateRoot.iconSource
                            asynchronous: true
                            smooth: true
                            mipmap: true
                            visible: status === Image.Ready
                            layer.enabled: root.trayIconTintEnabled
                            layer.effect: MultiEffect {
                                saturation: root.trayIconSaturation
                                colorization: root.trayIconColorization
                                colorizationColor: root.trayIconTintColor
                            }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            visible: !iconImg.visible
                            text: {
                                const itemId = trayItem?.id || "";
                                if (!itemId)
                                    return "?";
                                return itemId.charAt(0).toUpperCase();
                            }
                            font.pixelSize: 10
                            color: Theme.widgetTextColor
                        }

                        DankRipple {
                            id: itemRipple
                            cornerRadius: Theme.cornerRadius
                        }
                    }

                    MouseArea {
                        id: trayItemArea
                        y: root.isVerticalOrientation ? 0 : -root.topMargin
                        x: root.isVerticalOrientation ? -root.leftMargin : 0
                        width: parent.width + (root.isVerticalOrientation ? root.leftMargin + root.rightMargin : 0)
                        height: parent.height + (root.isVerticalOrientation ? 0 : root.topMargin + root.bottomMargin)
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: dragHandler.longPressing ? Qt.DragMoveCursor : Qt.PointingHandCursor

                        onPressed: mouse => {
                            const pos = mapToItem(visualContent, mouse.x, mouse.y);
                            itemRipple.trigger(pos.x, pos.y);
                            if (mouse.button === Qt.LeftButton) {
                                dragHandler.dragStartPos = Qt.point(mouse.x, mouse.y);
                                longPressTimer.start();
                            }
                        }

                        onReleased: mouse => {
                            longPressTimer.stop();
                            const wasDragging = dragHandler.dragging;
                            if (wasDragging)
                                root.finishMainDrag();

                            dragHandler.longPressing = false;
                            dragHandler.dragging = false;
                            dragHandler.dragAxisOffset = 0;

                            if (wasDragging || mouse.button !== Qt.LeftButton)
                                return;

                            if (!delegateRoot.trayItem)
                                return;
                            if (!delegateRoot.trayItem.onlyMenu) {
                                delegateRoot.trayItem.activate();
                                return;
                            }
                            if (!delegateRoot.trayItem.hasMenu)
                                return;
                            if (root.useOverflowPopup)
                                root.menuOpen = false;
                            root.showForTrayItem(delegateRoot.trayItem, visualContent, parentScreen, root.isAtBottom, root.isVerticalOrientation, root.axis);
                        }

                        onPositionChanged: mouse => {
                            if (dragHandler.longPressing && !dragHandler.dragging) {
                                const distance = Math.abs(mouse.x - dragHandler.dragStartPos.x);
                                if (distance > 5) {
                                    dragHandler.dragging = true;
                                    root.beginMainDrag(index, root.reverseInlineHorizontal);
                                }
                            }
                            if (!dragHandler.dragging)
                                return;

                            const axisOffset = mouse.x - dragHandler.dragStartPos.x;
                            dragHandler.dragAxisOffset = axisOffset;
                            root.updateMainDrag(axisOffset, index, root.reverseInlineHorizontal);
                        }

                        onClicked: mouse => {
                            if (dragHandler.dragging)
                                return;
                            if (mouse.button !== Qt.RightButton)
                                return;
                            if (!delegateRoot.trayItem?.hasMenu) {
                                const gp = trayItemArea.mapToGlobal(mouse.x, mouse.y);
                                root.callContextMenuFallback(delegateRoot.trayItem.id, Math.round(gp.x), Math.round(gp.y));
                                return;
                            }
                            if (root.useOverflowPopup)
                                root.menuOpen = false;
                            root.showForTrayItem(delegateRoot.trayItem, visualContent, parentScreen, root.isAtBottom, root.isVerticalOrientation, root.axis);
                        }
                    }
                }
            }

            Item {
                width: root.trayItemSize
                height: root.barThickness
                visible: root.hasHiddenItems

                Rectangle {
                    id: caretButton
                    width: root.trayItemSize
                    height: root.trayItemSize
                    anchors.centerIn: parent
                    radius: Theme.cornerRadius
                    color: caretArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : Theme.withAlpha(BlurService.hoverColor(Theme.widgetBaseHoverColor), 0)

                    DankIcon {
                        anchors.centerIn: parent
                        name: root.toggleIconName()
                        size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                        color: Theme.widgetTextColor
                    }

                    DankRipple {
                        id: caretRipple
                        cornerRadius: Theme.cornerRadius
                    }

                    MouseArea {
                        id: caretArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => {
                            caretRipple.trigger(mouse.x, mouse.y);
                        }
                        onClicked: {
                            if (root.useOverflowPopup) {
                                if (!root.menuOpen) {
                                    root._openOverflowAt(caretButton);
                                } else {
                                    root.menuOpen = false;
                                }
                            } else {
                                root.menuOpen = !root.menuOpen;
                            }
                        }
                    }
                }
            }

            Repeater {
                model: ScriptModel {
                    values: root.displayedInlineExpandedItems
                    objectProp: "key"
                }

                delegate: inlineExpandedTrayItemDelegate
            }
        }
    }

    Component {
        id: inlineExpandedTrayItemDelegate

        Item {
            property var trayItem: modelData.item
            property string itemKey: modelData.key
            property string iconSource: root.trayIconSourceFor(trayItem)

            width: root.isVerticalOrientation ? root.barThickness : (root.inlineExpanded ? root.trayItemSize : 0)
            height: root.isVerticalOrientation ? (root.inlineExpanded ? root.trayItemSize : 0) : root.barThickness
            visible: width > 0 && height > 0

            Behavior on width {
                enabled: !root.isVerticalOrientation
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on height {
                enabled: root.isVerticalOrientation
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Rectangle {
                id: inlineVisualContent
                width: root.trayItemSize
                height: root.trayItemSize
                x: root.isVerticalOrientation ? Math.round((parent.width - width) / 2) : (root.reverseInlineHorizontal ? parent.width - width : 0)
                y: root.isVerticalOrientation ? (root.reverseInlineVertical ? parent.height - height : 0) : Math.round((parent.height - height) / 2)
                radius: Theme.cornerRadius
                color: inlineTrayItemArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : Theme.withAlpha(BlurService.hoverColor(Theme.widgetBaseHoverColor), 0)
                opacity: root.inlineExpanded ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                IconImage {
                    id: inlineIconImg
                    anchors.centerIn: parent
                    width: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    height: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    source: iconSource
                    asynchronous: true
                    smooth: true
                    mipmap: true
                    visible: status === Image.Ready
                    layer.enabled: root.trayIconTintEnabled
                    layer.effect: MultiEffect {
                        saturation: root.trayIconSaturation
                        colorization: root.trayIconColorization
                        colorizationColor: root.trayIconTintColor
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: !inlineIconImg.visible
                    text: {
                        const itemId = trayItem?.id || "";
                        if (!itemId)
                            return "?";
                        return itemId.charAt(0).toUpperCase();
                    }
                    font.pixelSize: 10
                    color: Theme.widgetTextColor
                }

                DankRipple {
                    id: inlineItemRipple
                    cornerRadius: Theme.cornerRadius
                }
            }

            MouseArea {
                id: inlineTrayItemArea
                y: root.isVerticalOrientation ? 0 : -root.topMargin
                x: root.isVerticalOrientation ? -root.leftMargin : 0
                width: parent.width + (root.isVerticalOrientation ? root.leftMargin + root.rightMargin : 0)
                height: parent.height + (root.isVerticalOrientation ? 0 : root.topMargin + root.bottomMargin)
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                enabled: root.inlineExpanded

                onPressed: mouse => {
                    const pos = mapToItem(inlineVisualContent, mouse.x, mouse.y);
                    inlineItemRipple.trigger(pos.x, pos.y);
                }

                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) {
                        root.activateInlineTrayItem(trayItem, inlineVisualContent);
                        return;
                    }
                    if (mouse.button !== Qt.RightButton)
                        return;
                    root.openInlineTrayContextMenu(trayItem, inlineTrayItemArea, mouse, inlineVisualContent);
                }
            }
        }
    }

    Component {
        id: verticalMainTrayItemDelegate

        Item {
            property var trayItem: modelData.item
            property string itemKey: modelData.key
            property string iconSource: root.trayIconSourceFor(trayItem)

            width: root.barThickness
            height: root.trayItemSize
            z: dragHandler.dragging ? 100 : 0

            property real shiftOffset: root.dragShiftOffset(index, root.draggedIndex, root.dropTargetIndex, root.trayItemSize + root.configuredIconSpacing)

            transform: Translate {
                y: shiftOffset
                Behavior on y {
                    enabled: !root.suppressShiftAnimation
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Item {
                id: dragHandler
                anchors.fill: parent
                property bool dragging: false
                property point dragStartPos: Qt.point(0, 0)
                property real dragAxisOffset: 0
                property bool longPressing: false

                Timer {
                    id: longPressTimer
                    interval: 400
                    repeat: false
                    onTriggered: dragHandler.longPressing = true
                }
            }

            Rectangle {
                id: visualContent
                width: root.trayItemSize
                height: root.trayItemSize
                anchors.centerIn: parent
                radius: Theme.cornerRadius
                color: trayItemArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : Theme.withAlpha(BlurService.hoverColor(Theme.widgetBaseHoverColor), 0)
                border.width: dragHandler.dragging ? 2 : 0
                border.color: Theme.primary
                opacity: dragHandler.dragging ? 0.8 : 1.0

                transform: Translate {
                    y: dragHandler.dragging ? dragHandler.dragAxisOffset : 0
                }

                IconImage {
                    id: iconImg
                    anchors.centerIn: parent
                    width: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    height: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    source: iconSource
                    asynchronous: true
                    smooth: true
                    mipmap: true
                    visible: status === Image.Ready
                    layer.enabled: root.trayIconTintEnabled
                    layer.effect: MultiEffect {
                        saturation: root.trayIconSaturation
                        colorization: root.trayIconColorization
                        colorizationColor: root.trayIconTintColor
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: !iconImg.visible
                    text: {
                        const itemId = trayItem?.id || "";
                        if (!itemId)
                            return "?";
                        return itemId.charAt(0).toUpperCase();
                    }
                    font.pixelSize: 10
                    color: Theme.widgetTextColor
                }

                DankRipple {
                    id: itemRipple
                    cornerRadius: Theme.cornerRadius
                }
            }

            MouseArea {
                id: trayItemArea
                y: root.isVerticalOrientation ? 0 : -root.topMargin
                x: root.isVerticalOrientation ? -root.leftMargin : 0
                width: parent.width + (root.isVerticalOrientation ? root.leftMargin + root.rightMargin : 0)
                height: parent.height + (root.isVerticalOrientation ? 0 : root.topMargin + root.bottomMargin)
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: dragHandler.longPressing ? Qt.DragMoveCursor : Qt.PointingHandCursor

                onPressed: mouse => {
                    const pos = mapToItem(visualContent, mouse.x, mouse.y);
                    itemRipple.trigger(pos.x, pos.y);
                    if (mouse.button === Qt.LeftButton) {
                        dragHandler.dragStartPos = Qt.point(mouse.x, mouse.y);
                        longPressTimer.start();
                    }
                }

                onReleased: mouse => {
                    longPressTimer.stop();
                    const wasDragging = dragHandler.dragging;
                    if (wasDragging)
                        root.finishMainDrag();

                    dragHandler.longPressing = false;
                    dragHandler.dragging = false;
                    dragHandler.dragAxisOffset = 0;

                    if (wasDragging || mouse.button !== Qt.LeftButton)
                        return;

                    if (!trayItem)
                        return;
                    if (!trayItem.onlyMenu) {
                        trayItem.activate();
                        return;
                    }
                    if (!trayItem.hasMenu)
                        return;
                    if (root.useOverflowPopup)
                        root.menuOpen = false;
                    root.showForTrayItem(trayItem, visualContent, parentScreen, root.isAtBottom, root.isVerticalOrientation, root.axis);
                }

                onPositionChanged: mouse => {
                    if (dragHandler.longPressing && !dragHandler.dragging) {
                        const distance = Math.abs(mouse.y - dragHandler.dragStartPos.y);
                        if (distance > 5) {
                            dragHandler.dragging = true;
                            root.beginMainDrag(index, false);
                        }
                    }
                    if (!dragHandler.dragging)
                        return;

                    const axisOffset = mouse.y - dragHandler.dragStartPos.y;
                    dragHandler.dragAxisOffset = axisOffset;
                    root.updateMainDrag(axisOffset, index, false);
                }

                onClicked: mouse => {
                    if (dragHandler.dragging)
                        return;
                    if (mouse.button !== Qt.RightButton)
                        return;
                    root.openInlineTrayContextMenu(trayItem, trayItemArea, mouse, visualContent);
                }
            }
        }
    }

    Component {
        id: columnComp
        Column {
            spacing: root.configuredIconSpacing

            // Column lacks layoutDirection, so we use four repeaters with mutually exclusive models to control whether main items or expanded items appear above/ below the toggle button.
            // When reverseInlineVertical is true the first and third repeaters are empty and the second and fourth are active, and vice-versa.
            // Because items are swapped between repeaters rather than reversed within a single list, vertical drag-and-drop indices don't need remapping (unlike the horizontal RightToLeft case).
            Repeater {
                model: ScriptModel {
                    values: root.reverseInlineVertical ? [] : root.displayedMainBarItems
                    objectProp: "key"
                }
                delegate: verticalMainTrayItemDelegate
            }

            Repeater {
                model: ScriptModel {
                    values: root.reverseInlineVertical ? root.displayedInlineExpandedItems : []
                    objectProp: "key"
                }
                delegate: inlineExpandedTrayItemDelegate
            }

            Item {
                width: root.barThickness
                height: root.trayItemSize
                visible: root.hasHiddenItems

                Rectangle {
                    id: caretButtonVert
                    width: root.trayItemSize
                    height: root.trayItemSize
                    anchors.centerIn: parent
                    radius: Theme.cornerRadius
                    color: caretAreaVert.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : Theme.withAlpha(BlurService.hoverColor(Theme.widgetBaseHoverColor), 0)

                    DankIcon {
                        anchors.centerIn: parent
                        name: root.toggleIconName()
                        size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                        color: Theme.widgetTextColor
                    }

                    DankRipple {
                        id: caretRippleVert
                        cornerRadius: Theme.cornerRadius
                    }

                    MouseArea {
                        id: caretAreaVert
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => {
                            caretRippleVert.trigger(mouse.x, mouse.y);
                        }
                        onClicked: {
                            if (root.useOverflowPopup) {
                                if (!root.menuOpen) {
                                    root._openOverflowAt(caretButtonVert);
                                } else {
                                    root.menuOpen = false;
                                }
                            } else {
                                root.menuOpen = !root.menuOpen;
                            }
                        }
                    }
                }
            }

            Repeater {
                model: ScriptModel {
                    values: root.reverseInlineVertical ? [] : root.displayedInlineExpandedItems
                    objectProp: "key"
                }
                delegate: inlineExpandedTrayItemDelegate
            }

            Repeater {
                model: ScriptModel {
                    values: root.reverseInlineVertical ? root.displayedMainBarItems : []
                    objectProp: "key"
                }
                delegate: verticalMainTrayItemDelegate
            }
        }
    }

    // Overflow grid content rendered inside DankPopout
    Component {
        id: overflowContentComponent

        Item {
            id: overflowContent
            objectName: "overflowMenuContainer"

            readonly property bool popupUsesVerticalLine: root.useSingleLineOverflowPopup && root.isVerticalOrientation
            readonly property real popupPadding: Theme.spacingS + (popupUsesVerticalLine ? 3 : 0)

            implicitWidth: root.overflowRawWidth
            implicitHeight: root.overflowRawHeight

            Flickable {
                anchors.centerIn: parent
                width: parent.width - overflowContent.popupPadding * 2
                height: parent.height - overflowContent.popupPadding * 2
                contentWidth: menuGrid.implicitWidth
                contentHeight: menuGrid.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                interactive: root.useSingleLineOverflowPopup && (overflowContent.popupUsesVerticalLine ? contentHeight > height : contentWidth > width)

                Grid {
                    id: menuGrid
                    anchors.verticalCenter: overflowContent.popupUsesVerticalLine ? undefined : parent.verticalCenter
                    anchors.horizontalCenter: overflowContent.popupUsesVerticalLine ? parent.horizontalCenter : undefined
                    columns: overflowContent.popupUsesVerticalLine ? 1 : (root.useSingleLineOverflowPopup ? root.hiddenBarItems.length : Math.min(5, root.hiddenBarItems.length))
                    spacing: Theme.spacingXXS
                    rowSpacing: 2

                    Repeater {
                        model: root.hiddenBarItems

                        delegate: Rectangle {
                            id: overflowItemRoot
                            property var trayItem: modelData
                            property string itemKey: root.getTrayItemKey(trayItem)
                            property string iconSource: root.trayIconSourceFor(trayItem)

                            width: root.trayItemSize + 4
                            height: root.trayItemSize + 4
                            z: popupDragHandler.dragging ? 100 : 0
                            radius: Theme.cornerRadius
                            color: itemArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : Theme.withAlpha(Theme.surfaceContainer, 0)
                            border.width: popupDragHandler.dragging ? 2 : 0
                            border.color: Theme.primary
                            opacity: popupDragHandler.dragging ? 0.8 : 1.0

                            property real shiftOffset: root.dragShiftOffset(index, root.popupDraggedIndex, root.popupDropTargetIndex, root.trayItemSize + 6)

                            transform: Translate {
                                x: !overflowContent.popupUsesVerticalLine ? overflowItemRoot.shiftOffset + (popupDragHandler.dragging ? popupDragHandler.dragAxisOffset : 0) : 0
                                y: overflowContent.popupUsesVerticalLine ? overflowItemRoot.shiftOffset + (popupDragHandler.dragging ? popupDragHandler.dragAxisOffset : 0) : 0
                                Behavior on x {
                                    enabled: !root.suppressShiftAnimation && !overflowContent.popupUsesVerticalLine
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on y {
                                    enabled: !root.suppressShiftAnimation && overflowContent.popupUsesVerticalLine
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            Item {
                                id: popupDragHandler
                                anchors.fill: parent
                                property bool dragging: false
                                property point dragStartPos: Qt.point(0, 0)
                                property real dragAxisOffset: 0
                                property bool longPressing: false

                                Timer {
                                    id: popupLongPressTimer
                                    interval: 400
                                    repeat: false
                                    onTriggered: popupDragHandler.longPressing = true
                                }
                            }

                            IconImage {
                                id: menuIconImg
                                anchors.centerIn: parent
                                width: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                                height: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                                source: parent.iconSource
                                asynchronous: true
                                smooth: true
                                mipmap: true
                                visible: status === Image.Ready
                                layer.enabled: root.trayIconTintEnabled
                                layer.effect: MultiEffect {
                                    saturation: root.trayIconSaturation
                                    colorization: root.trayIconColorization
                                    colorizationColor: root.trayIconTintColor
                                }
                            }

                            StyledText {
                                anchors.centerIn: parent
                                visible: !menuIconImg.visible
                                text: {
                                    const itemId = trayItem?.id || "";
                                    if (!itemId)
                                        return "?";
                                    return itemId.charAt(0).toUpperCase();
                                }
                                font.pixelSize: 10
                                color: Theme.widgetTextColor
                            }

                            MouseArea {
                                id: itemArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: popupDragHandler.longPressing ? Qt.DragMoveCursor : Qt.PointingHandCursor
                                onPressed: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        popupDragHandler.dragStartPos = Qt.point(mouse.x, mouse.y);
                                        popupLongPressTimer.start();
                                    }
                                }
                                onReleased: mouse => {
                                    popupLongPressTimer.stop();
                                    const wasDragging = popupDragHandler.dragging;
                                    if (wasDragging)
                                        root.finishPopupDrag();

                                    popupDragHandler.longPressing = false;
                                    popupDragHandler.dragging = false;
                                    popupDragHandler.dragAxisOffset = 0;
                                }
                                onPositionChanged: mouse => {
                                    const axisDelta = overflowContent.popupUsesVerticalLine ? (mouse.y - popupDragHandler.dragStartPos.y) : (mouse.x - popupDragHandler.dragStartPos.x);
                                    if (popupDragHandler.longPressing && !popupDragHandler.dragging && Math.abs(axisDelta) > 5) {
                                        popupDragHandler.dragging = true;
                                        root.beginPopupDrag(index);
                                    }
                                    if (!popupDragHandler.dragging)
                                        return;

                                    popupDragHandler.dragAxisOffset = axisDelta;
                                    root.updatePopupDrag(axisDelta, index);
                                }
                                onClicked: mouse => {
                                    if (popupDragHandler.dragging)
                                        return;
                                    if (!trayItem)
                                        return;
                                    if (mouse.button === Qt.LeftButton && !trayItem.onlyMenu) {
                                        trayItem.activate();
                                        root.menuOpen = false;
                                        return;
                                    }
                                    const localPos = itemArea.mapToGlobal(mouse.x, mouse.y);
                                    const isStandalone = !overflowPopout.useConnectedBackend;
                                    const popX = isStandalone ? overflowPopout.alignedX : 0;
                                    const popY = isStandalone ? overflowPopout.alignedY : 0;
                                    const gx = localPos.x + popX;
                                    const gy = localPos.y + popY;
                                    if (!trayItem.hasMenu) {
                                        root.callContextMenuFallback(trayItem.id, Math.round(gx), Math.round(gy));
                                        return;
                                    }
                                    root.showForTrayItemAtGlobalPoint(trayItem, gx, gy, itemArea.width, parentScreen, root.isAtBottom, root.isVerticalOrientation, root.axis);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    QtObject {
        id: trayMenuState
        property var trayItem: null
        property bool showMenu: false
        property var menuHandle: null
        property bool openedByHover: false
        property real computedWidth: 280
        property real computedHeight: 200

        function close() {
            showMenu = false;
            root._unregisterMenuIfMatches(trayMenuPopout);
            trayMenuPopout.close();
        }
    }

    Binding { target: trayMenuPopout; property: "popupWidth";  value: trayMenuState.computedWidth }
    Binding { target: trayMenuPopout; property: "popupHeight"; value: trayMenuState.computedHeight }

    Connections {
        target: trayMenuPopout
        function onBackgroundClicked() { trayMenuState.close(); }
        function onPopoutClosed() {
            trayMenuState.showMenu = false;
            root._unregisterMenuIfMatches(trayMenuPopout);
        }
    }

    Timer {
        id: pendingActionCloseTimer
        interval: 80
        repeat: false
        onTriggered: trayMenuState.close()
    }

    Component {
        id: trayMenuContentComponent

        Item {
            id: trayMenuContentRoot
            focus: true
            property alias entryStack: entryStack

            readonly property real _rawW: Math.min(500, Math.max(250, menuColumn.implicitWidth + Theme.spacingS * 2))
            readonly property real _rawH: Math.min(
                Math.max(40, menuColumn.implicitHeight + Theme.spacingS * 2),
                Math.max(40, (root.parentScreen?.height || 1080) - 20)
            )

            implicitWidth: _rawW
            implicitHeight: _rawH

            onImplicitWidthChanged:  trayMenuState.computedWidth  = implicitWidth
            onImplicitHeightChanged: trayMenuState.computedHeight = implicitHeight
            Component.onCompleted: {
                trayMenuState.computedWidth  = implicitWidth;
                trayMenuState.computedHeight = implicitHeight;
                forceActiveFocus();
            }

            ListModel { id: entryStack }
            function topEntry() { return entryStack.count ? entryStack.get(entryStack.count - 1).handle : null; }

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

            QsMenuAnchor {
                id: submenuHydrator
                anchor.window: trayMenuPopout.contentWindow
            }

            QsMenuOpener {
                id: rootOpener
                menu: trayMenuState.menuHandle
            }

            QsMenuOpener {
                id: subOpener
                menu: {
                    const e = topEntry();
                    return e ? (e.menu || e) : null;
                }
            }

            Keys.onEscapePressed: {
                if (entryStack.count > 0) goBack();
                else trayMenuState.close();
            }

            DankFlickable {
                id: menuFlickable
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                contentWidth: width
                contentHeight: menuColumn.implicitHeight
                clip: true
                interactive: contentHeight > height

                Column {
                    id: menuColumn
                    width: menuFlickable.width
                    spacing: 1

                    Rectangle {
                        visible: entryStack.count === 0
                        width: parent.width
                        height: 28
                        radius: Theme.cornerRadius
                        color: visibilityToggleArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : Theme.withAlpha(Theme.surfaceContainer, 0)

                        StyledText {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                const itemTitle = trayMenuState.trayItem?.tooltipTitle || trayMenuState.trayItem?.id || I18n.tr("Unknown");
                                if (root.isAutoOverflowTrayItem(trayMenuState.trayItem))
                                    return itemTitle + " · " + I18n.tr("Keep in Bar");
                                return itemTitle;
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                            elide: Text.ElideMiddle
                            width: parent.width - Theme.spacingS * 2 - (Theme.iconSizeSmall + Theme.spacingS)
                        }

                        DankIcon {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            name: {
                                if (root.isAutoOverflowTrayItem(trayMenuState.trayItem))
                                    return "push_pin";
                                return root.isManualHiddenTrayItem(trayMenuState.trayItem) ? "visibility" : "visibility_off";
                            }
                            size: Theme.iconSizeSmall
                            color: Theme.widgetTextColor
                        }

                        MouseArea {
                            id: visibilityToggleArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const itemKey = root.getTrayItemKey(trayMenuState.trayItem);
                                if (!itemKey) return;
                                if (root.isAutoOverflowTrayItem(trayMenuState.trayItem)) {
                                    root.promoteTrayItemToBar(trayMenuState.trayItem);
                                } else if (root.isManualHiddenTrayItem(trayMenuState.trayItem)) {
                                    SessionData.showTrayId(itemKey);
                                } else {
                                    SessionData.hideTrayId(itemKey);
                                }
                                trayMenuState.close();
                            }
                        }
                    }

                    Rectangle {
                        visible: entryStack.count === 0
                        width: parent.width
                        height: 1
                        color: Theme.outlineHeavy
                    }

                    Rectangle {
                        visible: entryStack.count > 0
                        width: parent.width
                        height: 28
                        radius: Theme.cornerRadius
                        color: backArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : Theme.withAlpha(Theme.surfaceContainer, 0)

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            DankIcon {
                                name: "arrow_back"
                                size: Theme.iconSizeSmall
                                color: Theme.widgetTextColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: I18n.tr("Back")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.widgetTextColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: backArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: goBack()
                        }
                    }

                    Rectangle {
                        visible: entryStack.count > 0
                        width: parent.width
                        height: 1
                        color: Theme.outlineHeavy
                    }

                    Repeater {
                        model: entryStack.count ? (subOpener.children ? subOpener.children : (topEntry()?.children || [])) : rootOpener.children

                        Rectangle {
                            property var menuEntry: modelData

                            width: menuColumn.width
                            height: menuEntry?.isSeparator ? 1 : 28
                            radius: menuEntry?.isSeparator ? 0 : Theme.cornerRadius
                            color: {
                                if (menuEntry?.isSeparator) return Theme.outlineHeavy;
                                return entryItemArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : Theme.withAlpha(Theme.surfaceContainer, 0);
                            }

                            MouseArea {
                                id: entryItemArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !menuEntry?.isSeparator && (menuEntry?.enabled !== false)
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    if (!menuEntry || menuEntry.isSeparator) return;
                                    if (menuEntry.hasChildren) {
                                        showSubMenu(menuEntry);
                                        return;
                                    }
                                    if (typeof menuEntry.activate === "function") {
                                        menuEntry.activate();
                                    } else if (typeof menuEntry.triggered === "function") {
                                        menuEntry.triggered();
                                    }
                                    pendingActionCloseTimer.restart();
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
                                    width: Theme.iconSizeSmall
                                    height: Theme.iconSizeSmall
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: menuEntry?.buttonType !== undefined && menuEntry.buttonType !== 0
                                    radius: menuEntry?.buttonType === 2 ? width / 2 : 2
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
                                        size: Theme.iconSizeSmall - 6
                                        color: Theme.primaryText
                                        visible: menuEntry?.buttonType === 1 && menuEntry?.checkState === 2
                                    }
                                }

                                Item {
                                    width: Theme.iconSizeSmall
                                    height: Theme.iconSizeSmall
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: (menuEntry?.icon ?? "") !== ""

                                    Image {
                                        anchors.fill: parent
                                        source: menuEntry?.icon || ""
                                        sourceSize.width: Theme.iconSizeSmall
                                        sourceSize.height: Theme.iconSizeSmall
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
                                    width: Theme.iconSizeSmall
                                    height: Theme.iconSizeSmall
                                    anchors.verticalCenter: parent.verticalCenter

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "chevron_right"
                                        size: Theme.iconSizeSmall - 2
                                        color: Theme.widgetTextColor
                                        visible: menuEntry?.hasChildren ?? false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function showForTrayItemAtGlobalPoint(item, gx, gy, triggerWidth, screen, atBottom, vertical, axisObj, byHover) {
        if (!screen)
            return;

        trayMenuState.close();

        const barPosition = (axisObj?.edge === "left") ? 2 : ((axisObj?.edge === "right") ? 3 : ((axisObj?.edge === "top") ? 0 : 1));
        const localPos = Qt.point(gx - (screen.x || 0), gy - (screen.y || 0));
        const tw = triggerWidth || root.width;
        const pos = SettingsData.getPopupTriggerPosition(localPos, screen, root.barThickness, tw, root.barSpacing, barPosition, root.barConfig);

        trayMenuPopout.setTriggerPosition(pos.x, pos.y, pos.width, root.section, screen, barPosition, root.barThickness, root.barSpacing, root.barConfig);

        trayMenuState.trayItem = item;
        trayMenuState.menuHandle = item?.menu ?? null;
        trayMenuState.openedByHover = byHover === true;

        PopoutManager.closeAllPopouts();
        ModalManager.closeAllModalsExcept(null);
        if (root.useOverflowPopup)
            root.menuOpen = false;

        if (screen)
            TrayMenuManager.registerMenu(screen.name, trayMenuPopout);

        trayMenuState.showMenu = true;
        PopoutManager.requestPopout(trayMenuPopout, undefined, "tray-menu-" + (item?.id ?? ""));
    }

    function showForTrayItem(item, anchor, screen, atBottom, vertical, axisObj, byHover) {
        if (!screen)
            return;

        const anchorY = (vertical && anchor) ? (anchor.height / 2 + root.minTooltipY) : 0;
        const globalPos = anchor ? anchor.mapToGlobal(0, anchorY) : Qt.point(0, 0);
        const triggerWidth = anchor ? anchor.width : root.width;
        showForTrayItemAtGlobalPoint(item, globalPos.x, globalPos.y, triggerWidth, screen, atBottom, vertical, axisObj, byHover);
    }

    function _trayLayoutRoot() {
        const contentChildren = root.visualContent?.children;
        if (!contentChildren || contentChildren.length === 0)
            return null;
        const contentRoot = contentChildren[0];
        return contentRoot?.layoutLoader?.item || null;
    }

    function _trayHitAtGlobalPoint(gx, gy) {
        if (!root.visible || root.width <= 0 || root.height <= 0)
            return null;
        const local = root.mapFromItem(null, gx, gy);
        if (local.x < 0 || local.y < 0 || local.x > root.width || local.y > root.height)
            return null;
        const layout = _trayLayoutRoot();
        if (!layout)
            return null;
        const layoutLocal = layout.mapFromItem(null, gx, gy);
        const children = layout.children || [];
        for (let i = 0; i < children.length; i++) {
            const child = children[i];
            if (!child.visible || child.width <= 0 || child.height <= 0)
                continue;
            if (layoutLocal.x < child.x || layoutLocal.x >= child.x + child.width)
                continue;
            if (layoutLocal.y < child.y || layoutLocal.y >= child.y + child.height)
                continue;
            if (child.trayItem)
                return child;
        }
        return null;
    }

    function hoverTriggerAtGlobalPoint(gx, gy) {
        const hit = _trayHitAtGlobalPoint(gx, gy);
        if (!hit?.trayItem?.hasMenu)
            return "";
        return "tray-" + (hit.trayItem.id || hit.itemKey || "");
    }

    function openHoverAtGlobalPoint(gx, gy) {
        const hit = _trayHitAtGlobalPoint(gx, gy);
        if (!hit?.trayItem?.hasMenu)
            return false;
        const anchor = hit.children?.length > 0 ? hit.children[0] : hit;
        showForTrayItem(hit.trayItem, anchor, parentScreen, isAtBottom, isVerticalOrientation, axis, true);
        return true;
    }
}
