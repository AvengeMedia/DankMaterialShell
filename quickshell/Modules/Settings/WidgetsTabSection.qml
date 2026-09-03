import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets
import qs.Services

Column {
    id: root
    readonly property var log: Log.scoped("WidgetsTabSection")

    property var items: []
    property var allWidgets: []
    property string title: ""
    property string titleIcon: "widgets"
    property string sectionId: ""

    DankTooltipV2 {
        id: sharedTooltip
    }

    Component.onDestruction: sharedTooltip.hide()

    signal itemEnabledChanged(string sectionId, string itemId, bool enabled)
    signal itemOrderChanged(string sectionId, var orderedIds)
    signal addWidget(string sectionId)
    signal removeWidget(string sectionId, int widgetIndex)
    signal spacerSizeChanged(string sectionId, int widgetIndex, int newSize)
    signal compactModeChanged(string widgetId, var value)
    signal widgetSizeChanged(string widgetId, var value)
    signal gpuSelectionChanged(string sectionId, int widgetIndex, int selectedIndex)
    signal diskMountSelectionChanged(string sectionId, int widgetIndex, string mountPath)
    signal controlCenterSettingChanged(string sectionId, int widgetIndex, string settingName, bool value)
    signal controlCenterGroupOrderChanged(string sectionId, int widgetIndex, var groupOrder)
    signal privacySettingChanged(string sectionId, int widgetIndex, string settingName, bool value)
    signal keyboardLayoutNameSettingChanged(string sectionId, int widgetIndex, string settingName, bool value)
    signal minimumWidthChanged(string sectionId, int widgetIndex, bool enabled)
    signal showSwapChanged(string sectionId, int widgetIndex, bool enabled)
    signal showInGbChanged(string sectionId, int widgetIndex, bool enabled)
    signal diskUsageModeChanged(string sectionId, int widgetIndex, int mode)
    signal overflowSettingChanged(string sectionId, int widgetIndex, string settingName, var value)
    signal hideWhenIdleChanged(string sectionId, int widgetIndex, bool enabled)

    // Cross-section drag coordination with WidgetsTab (positions are section-local)
    signal dragStarted(string sectionId, string id, int index, var widgetData, var localPos)
    signal dragMoved(string sectionId, var localPos)
    signal dragEnded(string sectionId)

    property string highlightedId: ""
    property string highlightedSection: ""

    // Absolute-Y spring drag state (mirrors DankDashTab); gapIndex is the phantom drop slot
    property var workingOrder: []
    property int draggingIndex: -1
    property string draggingId: ""
    property var dragStartOrder: []
    property int gapIndex: -1
    property bool crossSectionActive: false

    readonly property real rowHeight: 72
    readonly property real rowSpacing: Theme.spacingS

    property var rowHeights: []

    function rowHeightAt(i) {
        if (i < 0 || i >= rowHeights.length || rowHeights[i] === undefined)
            return rowHeight;
        return Math.max(rowHeight, rowHeights[i]);
    }

    function cumulativeHeightUpTo(pos) {
        var y = 0;
        var n = Math.min(pos, items.length);
        for (var i = 0; i < n; i++)
            y += rowHeightAt(i) + rowSpacing;
        return y;
    }

    readonly property real totalHeight: {
        const n = items.length;
        let base = cumulativeHeightUpTo(n);
        if (n > 0)
            base -= rowSpacing;
        if (gapIndex >= 0)
            base += (rowHeight + rowSpacing);
        return Math.max(0, base);
    }

    function resetWorkingOrder() {
        const arr = [];
        for (var i = 0; i < items.length; i++)
            arr.push(i);
        workingOrder = arr;
    }

    function slotYForIndex(i) {
        var pos = workingOrder.indexOf(i);
        if (pos < 0)
            pos = i;
        var y = cumulativeHeightUpTo(pos);
        if (gapIndex >= 0 && pos >= gapIndex)
            y += (rowHeight + rowSpacing);
        return y;
    }

    function slotIndexForY(localY) {
        var y = 0;
        for (var i = 0; i < items.length; i++) {
            var h = rowHeightAt(i) + rowSpacing;
            if (y + h / 2 > localY)
                return i;
            y += h;
        }
        return items.length;
    }

    function slotIndexForGlobalY(rootItem, gy) {
        var p = reorderArea.mapFromItem(rootItem, 0, gy);
        return slotIndexForY(p.y);
    }

    function beginDrag(i) {
        draggingIndex = i;
        draggingId = (items[i] && items[i].id) ? items[i].id : "";
        dragStartOrder = workingOrder.slice();
        crossSectionActive = false;
    }

    function updateDragTarget(centerY) {
        if (draggingIndex < 0)
            return;
        var pos = slotIndexForY(centerY);
        pos = Math.max(0, Math.min(pos, items.length - 1));
        var arr = workingOrder.slice();
        var d = arr.indexOf(draggingIndex);
        if (d < 0 || d === pos)
            return;
        arr.splice(d, 1);
        arr.splice(pos, 0, draggingIndex);
        workingOrder = arr;
    }

    function setCrossMode(active) {
        if (crossSectionActive === active)
            return;
        crossSectionActive = active;
        if (active)
            workingOrder = dragStartOrder.slice();
    }

    function openGapAt(idx) {
        gapIndex = Math.max(0, Math.min(idx, items.length));
    }

    function clearGap() {
        gapIndex = -1;
    }

    function commitDrag() {
        if (draggingIndex < 0)
            return;
        const changed = JSON.stringify(workingOrder) !== JSON.stringify(dragStartOrder);
        const orderedIds = workingOrder.map(i => items[i].id);
        draggingIndex = -1;
        draggingId = "";
        crossSectionActive = false;
        gapIndex = -1;
        if (changed)
            itemOrderChanged(sectionId, orderedIds);
    }

    function cancelDrag() {
        draggingIndex = -1;
        draggingId = "";
        crossSectionActive = false;
        gapIndex = -1;
        resetWorkingOrder();
    }

    function openWidgetMenu(menu, button, modelData, index) {
        menu.widgetData = modelData;
        menu.sectionId = root.sectionId;
        menu.widgetIndex = index;

        const qsWin = root.QsWindow?.window;
        const host = qsWin?.contentItem ?? root;
        const buttonPos = button.mapToItem(host, 0, 0);
        const popupWidth = menu.menuWidth;
        const popupHeight = menu.menuHeight;
        let xPos = buttonPos.x - popupWidth - Theme.spacingS;
        if (xPos < 0)
            xPos = buttonPos.x + button.width + Theme.spacingS;
        let yPos = buttonPos.y - popupHeight / 2 + button.height / 2;
        if (yPos < 0)
            yPos = Theme.spacingS;
        else if (yPos + popupHeight > host.height)
            yPos = host.height - popupHeight - Theme.spacingS;

        menu.menuX = xPos;
        menu.menuY = yPos;
        menu.open();
    }

    // Host-sized PopupWindow
    component WidgetSettingsMenu: Item {
        id: menuRoot

        property var widgetData: null
        property string sectionId: ""
        property int widgetIndex: -1
        readonly property var currentWidgetData: (widgetIndex >= 0 && widgetIndex < root.items.length) ? root.items[widgetIndex] : widgetData
        property real menuWidth: 200
        property real menuHeight: 80
        property real menuX: 0
        property real menuY: 0

        default property alias content: menuContent.data

        signal opened
        signal closed

        visible: false
        width: 0
        height: 0

        function open() {
            if (!positionInHost())
                return;
            popup.visible = true;
            opened();
        }

        function close() {
            if (popup.visible)
                popup.visible = false;
        }

        function positionInHost() {
            const qsWin = root.QsWindow?.window;
            if (!qsWin)
                return false;

            popup.anchor.window = qsWin;
            popup.anchor.rect.x = 0;
            popup.anchor.rect.y = 0;
            popup.anchor.edges = Edges.Top | Edges.Left;
            popup.anchor.gravity = Edges.Bottom | Edges.Right;
            popup.anchor.margins.top = 0;
            popup.anchor.margins.bottom = 0;
            popup.anchor.adjustment = PopupAdjustment.None;
            popup.width = qsWin.width;
            popup.height = qsWin.height;
            popup.menuX = Math.max(0, Math.min(qsWin.width - menuRoot.menuWidth, menuRoot.menuX));
            popup.menuY = Math.max(0, Math.min(qsWin.height - menuRoot.menuHeight, menuRoot.menuY));
            popup.anchor.updateAnchor();
            return true;
        }

        PopupWindow {
            id: popup

            property real menuX: 0
            property real menuY: 0

            color: "transparent"
            visible: false
            grabFocus: true

            onVisibleChanged: {
                if (!visible)
                    menuRoot.closed();
            }

            BackgroundEffect.blurRegion: visible ? menuBlurRegion : null

            Region {
                id: menuBlurRegion
                x: menuContainer.x
                y: menuContainer.y
                width: menuContainer.width
                height: menuContainer.height
                radius: Theme.cornerRadius
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                enabled: popup.visible
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: menuRoot.close()
            }

            FocusScope {
                anchors.fill: parent
                focus: popup.visible
                z: 0

                Keys.onEscapePressed: event => {
                    menuRoot.close();
                    event.accepted = true;
                }
            }

            Item {
                id: menuContainer

                x: popup.menuX
                y: popup.menuY
                width: menuRoot.menuWidth
                height: menuRoot.menuHeight
                z: 1

                Rectangle {
                    id: contentSurface

                    anchors.fill: parent
                    color: Theme.floatingWindowNestedSurface
                    radius: Theme.cornerRadius
                    border.color: Theme.outlineMedium
                    border.width: Theme.layerOutlineWidth
                    clip: true

                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        acceptedButtons: Qt.AllButtons
                        onPressed: mouse => mouse.accepted = true
                        onClicked: mouse => mouse.accepted = true
                    }

                    Item {
                        id: menuContent
                        anchors.fill: parent
                    }
                }
            }
        }
    }

    onItemsChanged: resetWorkingOrder()
    Component.onCompleted: resetWorkingOrder()

    width: parent.width
    height: implicitHeight
    spacing: Theme.spacingM

    Item {
        width: parent.width
        height: Math.max(headerRow.implicitHeight, centeringModeRow.implicitHeight)
        LayoutMirroring.enabled: I18n.isRtl
        LayoutMirroring.childrenInherit: true

        Row {
            id: headerRow
            spacing: Theme.spacingM
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            DankIcon {
                name: root.titleIcon
                size: Theme.iconSize
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.title
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            id: centeringModeRow
            spacing: Theme.spacingXS
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.sectionId === "center"

            DankActionButton {
                id: indexCenterButton
                buttonSize: 28
                iconName: "format_list_numbered"
                iconSize: 16
                iconColor: SettingsData.centeringMode === "index" ? Theme.primary : Theme.outline
                onClicked: {
                    SettingsData.set("centeringMode", "index");
                }
                onEntered: {
                    sharedTooltip.show(I18n.tr("Index Centering"), indexCenterButton, 0, 0, "bottom");
                }
                onExited: {
                    sharedTooltip.hide();
                }
            }

            DankActionButton {
                id: geometricCenterButton
                buttonSize: 28
                iconName: "center_focus_weak"
                iconSize: 16
                iconColor: SettingsData.centeringMode === "geometric" ? Theme.primary : Theme.outline
                onClicked: {
                    SettingsData.set("centeringMode", "geometric");
                }
                onEntered: {
                    sharedTooltip.show(I18n.tr("Geometric Centering"), geometricCenterButton, 0, 0, "bottom");
                }
                onExited: {
                    sharedTooltip.hide();
                }
            }
        }
    }

    Item {
        id: reorderArea

        width: parent.width
        height: root.totalHeight

        Behavior on height {
            NumberAnimation {
                duration: Theme.expressiveDurations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
            }
        }

        Repeater {
            model: root.items

            delegate: Item {
                id: delegateItem

                readonly property int rowIndex: index
                readonly property bool dragging: root.draggingIndex === rowIndex
                readonly property bool highlighted: root.highlightedId !== "" && root.highlightedId === modelData.id && root.highlightedSection === root.sectionId

                width: reorderArea.width
                height: Math.max(root.rowHeight, textColumn.implicitHeight + 28)
                z: dragging ? 100 : (highlighted ? 3 : 1)
                opacity: (dragging && root.crossSectionActive) ? 0 : 1

                onHeightChanged: {
                    var arr = root.rowHeights.slice();
                    while (arr.length <= rowIndex)
                        arr.push(root.rowHeight);
                    if (arr[rowIndex] !== height) {
                        arr[rowIndex] = height;
                        root.rowHeights = arr;
                    }
                }
                Component.onCompleted: {
                    var arr = root.rowHeights.slice();
                    while (arr.length <= rowIndex)
                        arr.push(root.rowHeight);
                    arr[rowIndex] = height;
                    root.rowHeights = arr;
                }

                Binding {
                    target: delegateItem
                    property: "y"
                    value: root.slotYForIndex(delegateItem.rowIndex)
                    when: !delegateItem.dragging
                    restoreMode: Binding.RestoreNone
                }

                onYChanged: {
                    if (!dragging)
                        return;
                    root.dragMoved(root.sectionId, delegateItem.mapToItem(root, delegateItem.width / 2, delegateItem.height / 2));
                    if (!root.crossSectionActive)
                        root.updateDragTarget(y + height / 2);
                }

                Behavior on y {
                    enabled: !delegateItem.dragging

                    NumberAnimation {
                        duration: Theme.expressiveDurations.expressiveDefaultSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
                    }
                }

                Rectangle {
                    id: itemBackground

                    anchors.fill: parent
                    scale: delegateItem.dragging ? 1.02 : 1.0
                    transformOrigin: Item.Center
                    radius: delegateItem.dragging ? Theme.cornerRadius + 6 : Theme.cornerRadius
                    color: itemColor.value
                    border.color: delegateItem.dragging ? Theme.primary : Theme.outlineHeavy
                    border.width: delegateItem.dragging ? 2 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on radius {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                    DankColorAnimation {
                        id: itemColor
                        to: delegateItem.dragging ? Theme.secondaryContainer : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.floatingWindowForegroundLayers ? Theme.floatingWindowForegroundTransparency * (modelData.enabled ? 0.7 : 0.4) : 0)
                        duration: Theme.shortDuration
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.primary
                        opacity: (dragArea.containsMouse && !delegateItem.dragging) ? 0.06 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.shortDuration
                            }
                        }
                    }

                    DankIcon {
                        id: dragHandle
                        name: "drag_indicator"
                        size: Theme.iconSize - 4
                        color: delegateItem.dragging ? Theme.primary : Theme.outline
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: modelData.enabled ? ((dragArea.containsMouse || delegateItem.dragging || delegateItem.highlighted) ? 1.0 : 0.45) : 0
                        visible: opacity > 0.01

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.shortDuration
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.shortDuration
                            }
                        }
                    }

                    DankIcon {
                        id: tabIcon
                        name: modelData.icon
                        size: Theme.iconSize
                        color: modelData.enabled ? Theme.primary : Theme.outline
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM * 2 + Theme.iconSize - 4
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.shortDuration
                            }
                        }
                    }

                    Column {
                        id: textColumn
                        anchors.left: tabIcon.right
                        anchors.leftMargin: Theme.spacingM
                        anchors.right: actionButtons.left
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXXS

                        StyledText {
                            text: modelData.text
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: modelData.enabled ? Theme.surfaceText : Theme.outline
                            elide: Text.ElideRight
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }

                        StyledText {
                            text: {
                                if (modelData.id === "gpuTemp") {
                                    var selectedIdx = modelData.selectedGpuIndex !== undefined ? modelData.selectedGpuIndex : 0;
                                    if (DgopService.availableGpus && DgopService.availableGpus.length > selectedIdx) {
                                        var gpu = DgopService.availableGpus[selectedIdx];
                                        return gpu.driver ? gpu.driver.toUpperCase() : "";
                                    }
                                    return I18n.tr("No GPU detected");
                                }
                                return modelData.description;
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: modelData.enabled ? Theme.outline : Theme.outlineVariant
                            elide: Text.ElideRight
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }
                    }

                    Row {
                        id: actionButtons

                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        DankActionButton {
                            id: gpuMenuButton
                            visible: modelData.id === "gpuTemp"
                            buttonSize: 32
                            iconName: "more_vert"
                            iconSize: 18
                            iconColor: Theme.outline
                            onEntered: {
                                sharedTooltip.show(I18n.tr("Options"), gpuMenuButton, 0, 0, "bottom");
                            }
                            onExited: {
                                sharedTooltip.hide();
                            }
                            onClicked: root.openWidgetMenu(gpuContextMenu, gpuMenuButton, modelData, index)
                        }

                        Item {
                            width: 120
                            height: 32
                            visible: modelData.id === "diskUsage"
                            DankDropdown {
                                id: diskMountDropdown
                                anchors.fill: parent
                                currentValue: {
                                    const mountPath = modelData.mountPath || "/";
                                    if (mountPath === "/") {
                                        return "root (/)";
                                    }
                                    return mountPath;
                                }
                                options: {
                                    if (!DgopService.diskMounts || DgopService.diskMounts.length === 0) {
                                        return ["root (/)"];
                                    }
                                    return DgopService.diskMounts.map(mount => {
                                        if (mount.mount === "/") {
                                            return "root (/)";
                                        }
                                        return mount.mount;
                                    });
                                }
                                onValueChanged: value => {
                                    const newPath = value === "root (/)" ? "/" : value;
                                    root.diskMountSelectionChanged(root.sectionId, index, newPath);
                                }
                            }
                        }

                        DankActionButton {
                            id: diskMenuButton
                            visible: modelData.id === "diskUsage"
                            buttonSize: 32
                            iconName: "more_vert"
                            iconSize: 18
                            iconColor: Theme.outline
                            onEntered: {
                                sharedTooltip.show(I18n.tr("Options"), diskMenuButton, 0, 0, "bottom");
                            }
                            onExited: {
                                sharedTooltip.hide();
                            }
                            onClicked: root.openWidgetMenu(diskUsageContextMenu, diskMenuButton, modelData, index)
                        }

                        Item {
                            width: 32
                            height: 32
                            visible: modelData.warning !== undefined && modelData.warning !== ""

                            DankIcon {
                                name: "warning"
                                size: 20
                                color: Theme.error
                                anchors.centerIn: parent
                                opacity: warningArea.containsMouse ? 1.0 : 0.8
                            }

                            MouseArea {
                                id: warningArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                            }

                            Rectangle {
                                id: warningTooltip

                                property string warningText: (modelData.warning !== undefined && modelData.warning !== "") ? modelData.warning : ""

                                width: Math.min(250, warningTooltipText.implicitWidth) + Theme.spacingM * 2
                                height: warningTooltipText.implicitHeight + Theme.spacingS * 2
                                radius: Theme.cornerRadius
                                color: Theme.floatingWindowNestedSurface
                                border.color: Theme.outlineMedium
                                border.width: Theme.layerOutlineWidth
                                visible: warningArea.containsMouse && warningText !== ""
                                opacity: visible ? 1 : 0
                                x: -width - Theme.spacingS
                                y: (parent.height - height) / 2
                                z: 100

                                StyledText {
                                    id: warningTooltipText
                                    anchors.centerIn: parent
                                    anchors.margins: Theme.spacingS
                                    text: warningTooltip.warningText
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    width: Math.min(250, implicitWidth)
                                    wrapMode: Text.WordWrap
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }
                            }
                        }

                        DankActionButton {
                            id: minimumWidthButton
                            buttonSize: 28
                            visible: modelData.id === "cpuUsage" || modelData.id === "memUsage" || modelData.id === "cpuTemp" || modelData.id === "gpuTemp" || modelData.id === "diskUsage"
                            iconName: "straighten"
                            iconSize: 16
                            iconColor: (modelData.minimumWidth !== undefined ? modelData.minimumWidth : true) ? Theme.primary : Theme.outline
                            onClicked: {
                                var currentEnabled = modelData.minimumWidth !== undefined ? modelData.minimumWidth : true;
                                root.minimumWidthChanged(root.sectionId, index, !currentEnabled);
                            }
                            onEntered: {
                                var currentEnabled = modelData.minimumWidth !== undefined ? modelData.minimumWidth : true;
                                const tooltipText = currentEnabled ? I18n.tr("Force Padding") : I18n.tr("Dynamic Width");
                                sharedTooltip.show(tooltipText, minimumWidthButton, 0, 0, "bottom");
                            }
                            onExited: {
                                sharedTooltip.hide();
                            }
                        }

                        DankActionButton {
                            id: hideWhenIdleButton
                            buttonSize: 28
                            visible: modelData.id === "systemUpdate"
                            iconName: "visibility_off"
                            iconSize: 16
                            iconColor: (modelData.hideWhenIdle === true) ? Theme.primary : Theme.outline
                            onClicked: {
                                root.hideWhenIdleChanged(root.sectionId, index, modelData.hideWhenIdle !== true);
                            }
                            onEntered: {
                                const tooltipText = modelData.hideWhenIdle === true ? I18n.tr("Hide when no updates: ON") : I18n.tr("Hide when no updates: OFF");
                                sharedTooltip.show(tooltipText, hideWhenIdleButton, 0, 0, "bottom");
                            }
                            onExited: {
                                sharedTooltip.hide();
                            }
                        }

                        DankActionButton {
                            id: memMenuButton
                            visible: modelData.id === "memUsage"
                            buttonSize: 32
                            iconName: "more_vert"
                            iconSize: 18
                            iconColor: Theme.outline
                            onEntered: {
                                sharedTooltip.show(I18n.tr("Options"), memMenuButton, 0, 0, "bottom");
                            }
                            onExited: {
                                sharedTooltip.hide();
                            }
                            onClicked: root.openWidgetMenu(memUsageContextMenu, memMenuButton, modelData, index)
                        }

                        DankActionButton {
                            id: focusedWindowMenuButton
                            buttonSize: 32
                            visible: modelData.id === "focusedWindow"
                            iconName: "more_vert"
                            iconSize: 18
                            iconColor: Theme.outline
                            onEntered: {
                                sharedTooltip.show(I18n.tr("Options"), focusedWindowMenuButton, 0, 0, "bottom");
                            }
                            onExited: {
                                sharedTooltip.hide();
                            }
                            onClicked: root.openWidgetMenu(focusedWindowContextMenu, focusedWindowMenuButton, modelData, index)
                        }

                        DankActionButton {
                            id: musicMenuButton
                            visible: modelData.id === "music"
                            buttonSize: 32
                            iconName: "more_vert"
                            iconSize: 18
                            iconColor: Theme.outline
                            onEntered: {
                                sharedTooltip.show(I18n.tr("Options"), musicMenuButton, 0, 0, "bottom");
                            }
                            onExited: {
                                sharedTooltip.hide();
                            }
                            onClicked: root.openWidgetMenu(musicContextMenu, musicMenuButton, modelData, index)
                        }

                        DankActionButton {
                            id: runningAppsMenuButton
                            visible: modelData.id === "runningApps"
                            buttonSize: 32
                            iconName: "more_vert"
                            iconSize: 18
                            iconColor: Theme.outline
                            onEntered: {
                                sharedTooltip.show(I18n.tr("Options"), runningAppsMenuButton, 0, 0, "bottom");
                            }
                            onExited: {
                                sharedTooltip.hide();
                            }
                            onClicked: root.openWidgetMenu(runningAppsContextMenu, runningAppsMenuButton, modelData, index)
                        }

                        DankActionButton {
                            id: batteryMenuButton
                            visible: modelData.id === "battery"
                            buttonSize: 32
                            iconName: "more_vert"
                            iconSize: 18
                            iconColor: Theme.outline
                            onEntered: {
                                sharedTooltip.show(I18n.tr("Options"), batteryMenuButton, 0, 0, "bottom");
                            }
                            onExited: {
                                sharedTooltip.hide();
                            }
                            onClicked: root.openWidgetMenu(batteryContextMenu, batteryMenuButton, modelData, index)
                        }

                        Row {
                            spacing: Theme.spacingXS
                            visible: modelData.id === "clock" || modelData.id === "keyboard_layout_name" || modelData.id === "appsDock" || modelData.id === "systemTray"

                            DankActionButton {
                                id: compactModeButton
                                buttonSize: 28
                                visible: modelData.id === "clock" || modelData.id === "keyboard_layout_name"
                                iconName: {
                                    const isCompact = (() => {
                                            switch (modelData.id) {
                                            case "clock":
                                                return modelData.clockCompactMode !== undefined ? modelData.clockCompactMode : SettingsData.clockCompactMode;
                                            case "keyboard_layout_name":
                                                return modelData.keyboardLayoutNameCompactMode !== undefined ? modelData.keyboardLayoutNameCompactMode : SettingsData.keyboardLayoutNameCompactMode;
                                            default:
                                                return false;
                                            }
                                        })();
                                    return isCompact ? "zoom_out" : "zoom_in";
                                }
                                iconSize: 16
                                iconColor: {
                                    const isCompact = (() => {
                                            switch (modelData.id) {
                                            case "clock":
                                                return modelData.clockCompactMode !== undefined ? modelData.clockCompactMode : SettingsData.clockCompactMode;
                                            case "keyboard_layout_name":
                                                return modelData.keyboardLayoutNameCompactMode !== undefined ? modelData.keyboardLayoutNameCompactMode : SettingsData.keyboardLayoutNameCompactMode;
                                            default:
                                                return false;
                                            }
                                        })();
                                    return isCompact ? Theme.primary : Theme.outline;
                                }
                                onClicked: {
                                    const currentValue = (() => {
                                            switch (modelData.id) {
                                            case "clock":
                                                return modelData.clockCompactMode !== undefined ? modelData.clockCompactMode : SettingsData.clockCompactMode;
                                            case "keyboard_layout_name":
                                                return modelData.keyboardLayoutNameCompactMode !== undefined ? modelData.keyboardLayoutNameCompactMode : SettingsData.keyboardLayoutNameCompactMode;
                                            default:
                                                return false;
                                            }
                                        })();
                                    root.compactModeChanged(modelData.id, !currentValue);
                                }
                                onEntered: {
                                    const isCompact = (() => {
                                            switch (modelData.id) {
                                            case "clock":
                                                return modelData.clockCompactMode !== undefined ? modelData.clockCompactMode : SettingsData.clockCompactMode;
                                            case "keyboard_layout_name":
                                                return modelData.keyboardLayoutNameCompactMode !== undefined ? modelData.keyboardLayoutNameCompactMode : SettingsData.keyboardLayoutNameCompactMode;
                                            default:
                                                return false;
                                            }
                                        })();
                                    const tooltipText = isCompact ? I18n.tr("Full Size") : I18n.tr("Compact");
                                    sharedTooltip.show(tooltipText, compactModeButton, 0, 0, "bottom");
                                }
                                onExited: {
                                    sharedTooltip.hide();
                                }
                            }

                            DankActionButton {
                                id: kbdLayoutCtxMenuButton
                                buttonSize: 32
                                visible: modelData.id === "keyboard_layout_name"
                                iconName: "more_vert"
                                iconSize: 18
                                iconColor: Theme.outline

                                onEntered: {
                                    sharedTooltip.show(I18n.tr("Options"), kbdLayoutCtxMenuButton, 0, 0, "bottom");
                                }
                                onExited: {
                                    sharedTooltip.hide();
                                }
                                onClicked: root.openWidgetMenu(kbdLayoutCtxMenu, kbdLayoutCtxMenuButton, modelData, index)
                            }

                            DankActionButton {
                                id: clockCtxMenuButton
                                buttonSize: 32
                                visible: modelData.id === "clock"
                                iconName: "more_vert"
                                iconSize: 18
                                iconColor: Theme.outline

                                onEntered: {
                                    sharedTooltip.show(I18n.tr("Options"), clockCtxMenuButton, 0, 0, "bottom");
                                }
                                onExited: {
                                    sharedTooltip.hide();
                                }
                                onClicked: root.openWidgetMenu(clockContextMenu, clockCtxMenuButton, modelData, index)
                            }

                            DankActionButton {
                                id: appsDockMenuButton
                                buttonSize: 32
                                visible: modelData.id === "appsDock"
                                iconName: "more_vert"
                                iconSize: 18
                                iconColor: Theme.outline
                                onEntered: {
                                    sharedTooltip.show(I18n.tr("Options"), appsDockMenuButton, 0, 0, "bottom");
                                }
                                onExited: {
                                    sharedTooltip.hide();
                                }
                                onClicked: root.openWidgetMenu(appsDockContextMenu, appsDockMenuButton, modelData, index)
                            }

                            DankActionButton {
                                id: trayMenuButton
                                buttonSize: 32
                                visible: modelData.id === "systemTray"
                                iconName: "more_vert"
                                iconSize: 18
                                iconColor: Theme.outline
                                onEntered: {
                                    sharedTooltip.show(I18n.tr("Options"), trayMenuButton, 0, 0, "bottom");
                                }
                                onExited: {
                                    sharedTooltip.hide();
                                }
                                onClicked: root.openWidgetMenu(trayContextMenu, trayMenuButton, modelData, index)
                            }

                            Rectangle {
                                id: compactModeTooltip
                                width: tooltipText.contentWidth + Theme.spacingM * 2
                                height: tooltipText.contentHeight + Theme.spacingS * 2
                                radius: Theme.cornerRadius
                                color: Theme.floatingWindowNestedSurface
                                border.color: Theme.outlineMedium
                                border.width: Theme.layerOutlineWidth
                                visible: false
                                opacity: visible ? 1 : 0
                                x: -width - Theme.spacingS
                                y: (parent.height - height) / 2
                                z: 100

                                StyledText {
                                    id: tooltipText
                                    anchors.centerIn: parent
                                    text: I18n.tr("Compact Mode")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }
                            }
                        }

                        DankActionButton {
                            id: ccMenuButton
                            visible: modelData.id === "controlCenterButton"
                            buttonSize: 32
                            iconName: "more_vert"
                            iconSize: 18
                            iconColor: Theme.outline
                            onEntered: {
                                sharedTooltip.show(I18n.tr("Options"), ccMenuButton, 0, 0, "bottom");
                            }
                            onExited: {
                                sharedTooltip.hide();
                            }
                            onClicked: {
                                controlCenterContextMenu.controlCenterGroups = controlCenterContextMenu.getOrderedControlCenterGroups();
                                root.openWidgetMenu(controlCenterContextMenu, ccMenuButton, modelData, index);
                            }
                        }

                        DankActionButton {
                            id: privacyMenuButton
                            visible: modelData.id === "privacyIndicator"
                            buttonSize: 32
                            iconName: "more_vert"
                            iconSize: 18
                            iconColor: Theme.outline
                            onEntered: {
                                sharedTooltip.show(I18n.tr("Options"), privacyMenuButton, 0, 0, "bottom");
                            }
                            onExited: {
                                sharedTooltip.hide();
                            }
                            onClicked: root.openWidgetMenu(privacyContextMenu, privacyMenuButton, modelData, index)
                        }

                        DankActionButton {
                            id: visibilityButton
                            visible: modelData.id !== "spacer"
                            buttonSize: 32
                            iconName: modelData.enabled ? "visibility" : "visibility_off"
                            iconSize: 18
                            iconColor: modelData.enabled ? Theme.primary : Theme.outline
                            onClicked: {
                                root.itemEnabledChanged(root.sectionId, modelData.id, !modelData.enabled);
                            }
                            onEntered: {
                                const tooltipText = modelData.enabled ? I18n.tr("Hide") : I18n.tr("Show");
                                sharedTooltip.show(tooltipText, visibilityButton, 0, 0, "bottom");
                            }
                            onExited: {
                                sharedTooltip.hide();
                            }
                        }

                        Row {
                            visible: modelData.id === "spacer"
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            DankActionButton {
                                buttonSize: 24
                                iconName: "remove"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var currentSize = modelData.size || 20;
                                    var newSize = Math.max(5, currentSize - 5);
                                    root.spacerSizeChanged(root.sectionId, index, newSize);
                                }
                            }

                            StyledText {
                                text: (modelData.size || 20).toString()
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            DankActionButton {
                                buttonSize: 24
                                iconName: "add"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var currentSize = modelData.size || 20;
                                    var newSize = Math.min(5000, currentSize + 5);
                                    root.spacerSizeChanged(root.sectionId, index, newSize);
                                }
                            }
                        }

                        DankActionButton {
                            id: removeWidgetButton
                            buttonSize: 32
                            iconName: "close"
                            iconSize: 18
                            iconColor: Theme.error
                            onClicked: {
                                sharedTooltip.hide();
                                root.removeWidget(root.sectionId, index);
                            }
                            onEntered: {
                                sharedTooltip.show(I18n.tr("Remove"), removeWidgetButton, 0, 0, "bottom");
                            }
                            onExited: {
                                sharedTooltip.hide();
                            }
                        }
                    }

                    MouseArea {
                        id: dragArea

                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.right: actionButtons.left
                        hoverEnabled: true
                        cursorShape: delegateItem.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: delegateItem
                        drag.axis: Drag.YAxis
                        drag.minimumY: -2000
                        drag.maximumY: 4000
                        drag.smoothed: false
                        preventStealing: true
                        onPressed: {
                            root.beginDrag(delegateItem.rowIndex);
                            root.dragStarted(root.sectionId, modelData.id, delegateItem.rowIndex, modelData, delegateItem.mapToItem(root, delegateItem.width / 2, delegateItem.height / 2));
                        }
                        onReleased: root.dragEnded(root.sectionId)
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    radius: Theme.cornerRadius + 2
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.primary
                    opacity: delegateItem.highlighted && !delegateItem.dragging ? 0.6 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.shortDuration
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        width: 200
        height: 40
        radius: Theme.cornerRadius
        color: addButtonArea.containsMouse ? Theme.primaryContainer : Theme.withAlpha(Theme.surfaceVariant, 0.3)
        border.color: Theme.outlineHeavy
        border.width: 0
        anchors.horizontalCenter: parent.horizontalCenter

        StyledText {
            text: I18n.tr("Add Widget")
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
            anchors.centerIn: parent
        }

        MouseArea {
            id: addButtonArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.addWidget(root.sectionId);
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }
    }

    WidgetSettingsMenu {
        id: clockContextMenu

        menuWidth: 190
        menuHeight: clockMenuColumn.implicitHeight + Theme.spacingS * 2

        Item {
            anchors.fill: parent
            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true

            Column {
                id: clockMenuColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingXXS

                Repeater {
                    model: [
                        {
                            icon: "schedule",
                            label: I18n.tr("Time First"),
                            value: "timeFirst"
                        },
                        {
                            icon: "calendar_month",
                            label: I18n.tr("Date First"),
                            value: "dateFirst"
                        }
                    ]

                    delegate: Rectangle {
                        required property var modelData

                        function isSelected() {
                            const currentOrder = clockContextMenu.currentWidgetData?.clockDateOrder ?? "timeFirst";
                            return currentOrder === modelData.value;
                        }

                        width: clockMenuColumn.width
                        height: Math.max(18, Theme.fontSizeSmall) + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: clockOrderArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: clockOrderCheck.left
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS
                            clip: true

                            DankIcon {
                                name: modelData.icon
                                size: 18
                                color: isSelected() ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: isSelected() ? Font.Medium : Font.Normal
                                color: isSelected() ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                width: parent.width - 18 - Theme.spacingS
                            }
                        }

                        DankIcon {
                            id: clockOrderCheck
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            name: "check"
                            size: 16
                            color: Theme.primary
                            visible: isSelected()
                        }

                        MouseArea {
                            id: clockOrderArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.overflowSettingChanged(clockContextMenu.sectionId, clockContextMenu.widgetIndex, "clockDateOrder", modelData.value);
                                clockContextMenu.close();
                            }
                        }
                    }
                }
            }
        }
    }

    WidgetSettingsMenu {
        id: memUsageContextMenu

        menuWidth: 200
        menuHeight: 80

        Item {
            anchors.fill: parent
            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true
            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingXXS

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: swapToggleArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: swapToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "swap_horiz"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Show Swap")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 16 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: swapToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: memUsageContextMenu.widgetData?.showSwap ?? false
                        onToggled: {
                            root.showSwapChanged(memUsageContextMenu.sectionId, memUsageContextMenu.widgetIndex, toggled);
                        }
                    }

                    MouseArea {
                        id: swapToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            swapToggle.checked = !swapToggle.checked;
                            root.showSwapChanged(memUsageContextMenu.sectionId, memUsageContextMenu.widgetIndex, swapToggle.checked);
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: gbToggleArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: gbToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "straighten"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Show in GB")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 16 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: gbToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: memUsageContextMenu.widgetData?.showInGb ?? false
                        onToggled: {
                            root.showInGbChanged(memUsageContextMenu.sectionId, memUsageContextMenu.widgetIndex, toggled);
                        }
                    }

                    MouseArea {
                        id: gbToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            gbToggle.checked = !gbToggle.checked;
                            root.showInGbChanged(memUsageContextMenu.sectionId, memUsageContextMenu.widgetIndex, gbToggle.checked);
                        }
                    }
                }
            }
        }
    }

    WidgetSettingsMenu {
        id: trayContextMenu

        menuWidth: 280
        menuHeight: contentColumn.implicitHeight + Theme.spacingS * 2

        Item {
            anchors.fill: parent
            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true
            Column {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingXXS

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: trayOverflowArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: trayOverflowToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "arrow_selector_tool"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Use Inline Expansion")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 16 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: trayOverflowToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: trayContextMenu.currentWidgetData?.trayUseInlineExpansion ?? false
                    }

                    MouseArea {
                        id: trayOverflowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const newValue = !(trayContextMenu.currentWidgetData?.trayUseInlineExpansion ?? false);
                            root.overflowSettingChanged(trayContextMenu.sectionId, trayContextMenu.widgetIndex, "trayUseInlineExpansion", newValue);
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: trayPopupLineArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)
                    opacity: (trayContextMenu.currentWidgetData?.trayUseInlineExpansion ?? false) ? 0.55 : 1

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: trayPopupLineToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "view_week"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Single-Line Popup")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 16 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: trayPopupLineToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: trayContextMenu.currentWidgetData?.trayPopupSingleLine ?? SettingsData.trayPopupSingleLine
                        enabled: !(trayContextMenu.currentWidgetData?.trayUseInlineExpansion ?? false)
                    }

                    MouseArea {
                        id: trayPopupLineArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: (trayContextMenu.currentWidgetData?.trayUseInlineExpansion ?? false) ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (trayContextMenu.currentWidgetData?.trayUseInlineExpansion ?? false)
                                return;
                            const newValue = !(trayContextMenu.currentWidgetData?.trayPopupSingleLine ?? SettingsData.trayPopupSingleLine);
                            root.overflowSettingChanged(trayContextMenu.sectionId, trayContextMenu.widgetIndex, "trayPopupSingleLine", newValue);
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: trayAutoOverflowArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: trayAutoOverflowToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "responsive_layout"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Auto Overflow")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 16 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: trayAutoOverflowToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: trayContextMenu.currentWidgetData?.trayAutoOverflow ?? SettingsData.trayAutoOverflow
                    }

                    MouseArea {
                        id: trayAutoOverflowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const newValue = !(trayContextMenu.currentWidgetData?.trayAutoOverflow ?? SettingsData.trayAutoOverflow);
                            root.overflowSettingChanged(trayContextMenu.sectionId, trayContextMenu.widgetIndex, "trayAutoOverflow", newValue);
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 36
                    radius: Theme.cornerRadius
                    color: trayMaxVisibleArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)
                    opacity: (trayContextMenu.currentWidgetData?.trayAutoOverflow ?? SettingsData.trayAutoOverflow) ? 1 : 0.55

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: trayMaxVisibleButtons.left
                        anchors.rightMargin: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "low_priority"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Max Visible")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            maximumLineCount: 1
                        }

                        StyledText {
                            text: {
                                const value = trayContextMenu.currentWidgetData?.trayMaxVisibleItems ?? SettingsData.trayMaxVisibleItems;
                                return value > 0 ? String(value) : I18n.tr("Auto");
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        id: trayMaxVisibleButtons
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXXS

                        DankActionButton {
                            buttonSize: 28
                            iconName: "remove"
                            iconSize: 16
                            iconColor: Theme.surfaceText
                            enabled: trayContextMenu.currentWidgetData?.trayAutoOverflow ?? SettingsData.trayAutoOverflow
                            onClicked: {
                                const current = trayContextMenu.currentWidgetData?.trayMaxVisibleItems ?? SettingsData.trayMaxVisibleItems;
                                root.overflowSettingChanged(trayContextMenu.sectionId, trayContextMenu.widgetIndex, "trayMaxVisibleItems", Math.max(0, current - 1));
                            }
                        }

                        DankActionButton {
                            buttonSize: 28
                            iconName: "add"
                            iconSize: 16
                            iconColor: Theme.surfaceText
                            enabled: trayContextMenu.currentWidgetData?.trayAutoOverflow ?? SettingsData.trayAutoOverflow
                            onClicked: {
                                const current = trayContextMenu.currentWidgetData?.trayMaxVisibleItems ?? SettingsData.trayMaxVisibleItems;
                                root.overflowSettingChanged(trayContextMenu.sectionId, trayContextMenu.widgetIndex, "trayMaxVisibleItems", Math.min(20, current + 1));
                            }
                        }
                    }

                    MouseArea {
                        id: trayMaxVisibleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 36
                    radius: Theme.cornerRadius
                    color: trayIconSpacingArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: trayIconSpacingButtons.left
                        anchors.rightMargin: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "open_in_full"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Icon Spacing")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            maximumLineCount: 1
                        }

                        StyledText {
                            text: {
                                const value = Math.max(0, trayContextMenu.currentWidgetData?.trayIconSpacing ?? SettingsData.trayIconSpacing);
                                return `${value}px`;
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        id: trayIconSpacingButtons
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXXS

                        DankActionButton {
                            buttonSize: 28
                            iconName: "remove"
                            iconSize: 16
                            iconColor: Theme.surfaceText
                            onClicked: {
                                const current = Math.max(0, trayContextMenu.currentWidgetData?.trayIconSpacing ?? SettingsData.trayIconSpacing);
                                root.overflowSettingChanged(trayContextMenu.sectionId, trayContextMenu.widgetIndex, "trayIconSpacing", Math.max(0, current - 1));
                            }
                        }

                        DankActionButton {
                            buttonSize: 28
                            iconName: "add"
                            iconSize: 16
                            iconColor: Theme.surfaceText
                            onClicked: {
                                const current = Math.max(0, trayContextMenu.currentWidgetData?.trayIconSpacing ?? SettingsData.trayIconSpacing);
                                root.overflowSettingChanged(trayContextMenu.sectionId, trayContextMenu.widgetIndex, "trayIconSpacing", Math.min(20, current + 1));
                            }
                        }
                    }

                    MouseArea {
                        id: trayIconSpacingArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
            }
        }
    }

    WidgetSettingsMenu {
        id: kbdLayoutCtxMenu

        menuWidth: 200
        menuHeight: kbdLayoutCtxMenuColumn.implicitHeight + Theme.spacingS * 2

        Item {
            anchors.fill: parent
            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true
            Column {
                id: kbdLayoutCtxMenuColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingXXS

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: kbdLayoutCtxMenuIconArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: kbdLayoutCtxMenuIconToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "visibility"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Show Icon")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 16 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: kbdLayoutCtxMenuIconToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: kbdLayoutCtxMenu.currentWidgetData?.keyboardLayoutNameShowIcon ?? SettingsData.keyboardLayoutNameShowIcon
                        onToggled: toggled => {
                            root.keyboardLayoutNameSettingChanged(kbdLayoutCtxMenu.sectionId, kbdLayoutCtxMenu.widgetIndex, "showIcon", toggled);
                        }
                    }

                    MouseArea {
                        id: kbdLayoutCtxMenuIconArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            kbdLayoutCtxMenuIconToggle.checked = !kbdLayoutCtxMenuIconToggle.checked;
                            root.keyboardLayoutNameSettingChanged(kbdLayoutCtxMenu.sectionId, kbdLayoutCtxMenu.widgetIndex, "showIcon", kbdLayoutCtxMenuIconToggle.checked);
                        }
                    }
                }
            }
        }
    }

    WidgetSettingsMenu {
        id: focusedWindowContextMenu

        menuWidth: 180
        menuHeight: focusedWindowMenuColumn.implicitHeight + Theme.spacingS * 2

        Item {
            anchors.fill: parent
            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true
            Column {
                id: focusedWindowMenuColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingXXS

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: fwCompactArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: fwCompactToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "zoom_in"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Compact")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 16 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: fwCompactToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: focusedWindowContextMenu.currentWidgetData?.focusedWindowCompactMode ?? SettingsData.focusedWindowCompactMode
                        onToggled: {
                            root.overflowSettingChanged(focusedWindowContextMenu.sectionId, focusedWindowContextMenu.widgetIndex, "focusedWindowCompactMode", toggled);
                        }
                    }

                    MouseArea {
                        id: fwCompactArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            fwCompactToggle.checked = !fwCompactToggle.checked;
                            root.overflowSettingChanged(focusedWindowContextMenu.sectionId, focusedWindowContextMenu.widgetIndex, "focusedWindowCompactMode", fwCompactToggle.checked);
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: fwShowIconArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: fwShowIconToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "visibility"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Show Icon")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 16 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: fwShowIconToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: focusedWindowContextMenu.currentWidgetData?.focusedWindowShowIcon ?? SettingsData.focusedWindowShowIcon
                        onToggled: {
                            root.overflowSettingChanged(focusedWindowContextMenu.sectionId, focusedWindowContextMenu.widgetIndex, "focusedWindowShowIcon", toggled);
                        }
                    }

                    MouseArea {
                        id: fwShowIconArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            fwShowIconToggle.checked = !fwShowIconToggle.checked;
                            root.overflowSettingChanged(focusedWindowContextMenu.sectionId, focusedWindowContextMenu.widgetIndex, "focusedWindowShowIcon", fwShowIconToggle.checked);
                        }
                    }
                }

                Repeater {
                    model: [
                        {
                            icon: "photo_size_select_small",
                            label: I18n.tr("Small"),
                            sizeValue: 0
                        },
                        {
                            icon: "photo_size_select_actual",
                            label: I18n.tr("Medium"),
                            sizeValue: 1
                        },
                        {
                            icon: "photo_size_select_large",
                            label: I18n.tr("Large"),
                            sizeValue: 2
                        },
                        {
                            icon: "fit_screen",
                            label: I18n.tr("Largest"),
                            sizeValue: 3
                        }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        function isSelected() {
                            var wd = focusedWindowContextMenu.widgetData;
                            var currentSize = wd?.focusedWindowSize ?? SettingsData.focusedWindowSize;
                            return currentSize === modelData.sizeValue;
                        }

                        width: focusedWindowMenuColumn.width
                        height: Math.max(18, Theme.fontSizeSmall) + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: focusedWindowOptionArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: fwSizeCheck.left
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS
                            clip: true

                            DankIcon {
                                name: modelData.icon
                                size: 18
                                color: isSelected() ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: isSelected() ? Font.Medium : Font.Normal
                                color: isSelected() ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                width: parent.width - 18 - Theme.spacingS
                            }
                        }

                        DankIcon {
                            id: fwSizeCheck
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            name: "check"
                            size: 16
                            color: Theme.primary
                            visible: isSelected()
                        }

                        MouseArea {
                            id: focusedWindowOptionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.widgetSizeChanged("focusedWindow", modelData.sizeValue);
                                focusedWindowContextMenu.close();
                            }
                        }
                    }
                }
            }
        }
    }

    WidgetSettingsMenu {
        id: diskUsageContextMenu

        menuWidth: 240
        menuHeight: diskMenuColumn.implicitHeight + Theme.spacingS * 2

        Item {
            anchors.fill: parent
            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true
            Column {
                id: diskMenuColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingXXS

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: "transparent"

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Disk Usage Display")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                }

                Repeater {
                    model: [
                        {
                            label: I18n.tr("Percentage"),
                            mode: 0,
                            icon: "percent"
                        },
                        {
                            label: I18n.tr("Total"),
                            mode: 1,
                            icon: "storage"
                        },
                        {
                            label: I18n.tr("Remaining"),
                            mode: 2,
                            icon: "hourglass_empty"
                        },
                        {
                            label: I18n.tr("Remaining / Total"),
                            mode: 3,
                            icon: "pie_chart"
                        }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: diskMenuColumn.width
                        height: 32
                        radius: Theme.cornerRadius
                        color: diskOptionArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                        function isSelected() {
                            return (diskUsageContextMenu.currentWidgetData?.diskUsageMode ?? 0) === modelData.mode;
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: diskModeCheck.left
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS
                            clip: true

                            DankIcon {
                                name: modelData.icon
                                size: 16
                                color: isSelected() ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                color: isSelected() ? Theme.primary : Theme.surfaceText
                                font.weight: isSelected() ? Font.Medium : Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                width: parent.width - 16 - Theme.spacingS
                            }
                        }

                        DankIcon {
                            id: diskModeCheck
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            name: "check"
                            size: 16
                            color: Theme.primary
                            visible: isSelected()
                        }

                        MouseArea {
                            id: diskOptionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.diskUsageModeChanged(diskUsageContextMenu.sectionId, diskUsageContextMenu.widgetIndex, modelData.mode);
                                diskUsageContextMenu.close();
                            }
                        }
                    }
                }
            }
        }
    }

    WidgetSettingsMenu {
        id: controlCenterContextMenu

        readonly property real minimumContentWidth: controlCenterContentMetrics.implicitWidth + Theme.spacingS * 2
        readonly property real controlCenterRowHeight: 32
        readonly property real controlCenterRowSpacing: 1
        readonly property real controlCenterGroupVerticalPadding: Theme.spacingXS * 2
        readonly property real controlCenterMenuSpacing: 2
        menuWidth: Math.max(220, minimumContentWidth)
        menuHeight: getControlCenterPopupHeight(controlCenterGroups)

        onClosed: {
            cancelControlCenterDrag();
        }

        readonly property var defaultControlCenterGroups: [
            {
                id: "network",
                rows: [
                    {
                        icon: "lan",
                        label: I18n.tr("Network"),
                        setting: "showNetworkIcon"
                    }
                ]
            },
            {
                id: "vpn",
                rows: [
                    {
                        icon: "vpn_lock",
                        label: I18n.tr("VPN"),
                        setting: "showVpnIcon"
                    }
                ]
            },
            {
                id: "bluetooth",
                rows: [
                    {
                        icon: "bluetooth",
                        label: I18n.tr("Bluetooth"),
                        setting: "showBluetoothIcon"
                    }
                ]
            },
            {
                id: "audio",
                rows: [
                    {
                        icon: "volume_up",
                        label: I18n.tr("Audio"),
                        setting: "showAudioIcon"
                    },
                    {
                        icon: "percent",
                        label: I18n.tr("Volume"),
                        setting: "showAudioPercent"
                    }
                ]
            },
            {
                id: "microphone",
                rows: [
                    {
                        icon: "mic",
                        label: I18n.tr("Microphone"),
                        setting: "showMicIcon"
                    },
                    {
                        icon: "percent",
                        label: I18n.tr("Microphone Volume"),
                        setting: "showMicPercent"
                    }
                ]
            },
            {
                id: "brightness",
                rows: [
                    {
                        icon: "brightness_high",
                        label: I18n.tr("Brightness"),
                        setting: "showBrightnessIcon"
                    },
                    {
                        icon: "percent",
                        label: I18n.tr("Brightness Value"),
                        setting: "showBrightnessPercent"
                    }
                ]
            },
            {
                id: "battery",
                rows: [
                    {
                        icon: "battery_full",
                        label: I18n.tr("Battery"),
                        setting: "showBatteryIcon"
                    }
                ]
            },
            {
                id: "printer",
                rows: [
                    {
                        icon: "print",
                        label: I18n.tr("Printer"),
                        setting: "showPrinterIcon"
                    }
                ]
            },
            {
                id: "screenSharing",
                rows: [
                    {
                        icon: "screen_record",
                        label: I18n.tr("Screen sharing"),
                        setting: "showScreenSharingIcon"
                    }
                ]
            },
            {
                id: "idleInhibitor",
                rows: [
                    {
                        icon: "motion_sensor_active",
                        label: I18n.tr("Idle Inhibitor"),
                        setting: "showIdleInhibitorIcon"
                    }
                ]
            },
            {
                id: "doNotDisturb",
                rows: [
                    {
                        icon: "do_not_disturb_on",
                        label: I18n.tr("Do Not Disturb"),
                        setting: "showDoNotDisturbIcon"
                    }
                ]
            }
        ]
        property var controlCenterGroups: defaultControlCenterGroups
        property int draggedControlCenterGroupIndex: -1
        property int controlCenterGroupDropIndex: -1

        function updateControlCenterGroupDropIndex(draggedIndex, localY) {
            const totalGroups = controlCenterGroups.length;
            let dropIndex = totalGroups;

            for (let i = 0; i < totalGroups; i++) {
                const delegate = groupRepeater.itemAt(i);
                if (!delegate)
                    continue;

                const midpoint = delegate.y + delegate.height / 2;
                if (localY < midpoint) {
                    dropIndex = i;
                    break;
                }
            }

            controlCenterGroupDropIndex = Math.max(0, Math.min(totalGroups, dropIndex));
            draggedControlCenterGroupIndex = draggedIndex;
        }

        function finishControlCenterDrag() {
            if (draggedControlCenterGroupIndex < 0) {
                controlCenterGroupDropIndex = -1;
                return;
            }

            const fromIndex = draggedControlCenterGroupIndex;
            let toIndex = controlCenterGroupDropIndex;

            draggedControlCenterGroupIndex = -1;
            controlCenterGroupDropIndex = -1;

            if (toIndex < 0 || toIndex > controlCenterGroups.length || toIndex === fromIndex || toIndex === fromIndex + 1)
                return;

            const groups = controlCenterGroups.slice();
            const moved = groups.splice(fromIndex, 1)[0];

            if (toIndex > fromIndex)
                toIndex -= 1;

            groups.splice(toIndex, 0, moved);
            controlCenterGroups = groups;
            const reorderedGroupIds = groups.map(group => group.id);
            root.controlCenterGroupOrderChanged(sectionId, widgetIndex, reorderedGroupIds);
        }

        function cancelControlCenterDrag() {
            draggedControlCenterGroupIndex = -1;
            controlCenterGroupDropIndex = -1;
        }

        function getControlCenterGroupHeight(group) {
            const rowCount = group?.rows?.length ?? 0;
            if (rowCount <= 0)
                return controlCenterGroupVerticalPadding;

            return rowCount * controlCenterRowHeight + Math.max(0, rowCount - 1) * controlCenterRowSpacing + controlCenterGroupVerticalPadding;
        }

        function getControlCenterPopupHeight(groups) {
            const orderedGroups = groups || [];
            let totalHeight = Theme.spacingS * 2;

            for (let i = 0; i < orderedGroups.length; i++) {
                totalHeight += getControlCenterGroupHeight(orderedGroups[i]);
                if (i < orderedGroups.length - 1)
                    totalHeight += controlCenterMenuSpacing;
            }

            return totalHeight;
        }

        function getOrderedControlCenterGroups() {
            const baseGroups = defaultControlCenterGroups.slice();
            const savedOrder = currentWidgetData?.controlCenterGroupOrder;
            if (!savedOrder || !savedOrder.length)
                return baseGroups;

            const groupMap = {};
            for (let i = 0; i < baseGroups.length; i++)
                groupMap[baseGroups[i].id] = baseGroups[i];

            const orderedGroups = [];
            for (let i = 0; i < savedOrder.length; i++) {
                const groupId = savedOrder[i];
                const group = groupMap[groupId];
                if (group) {
                    orderedGroups.push(group);
                    delete groupMap[groupId];
                }
            }

            for (let i = 0; i < baseGroups.length; i++) {
                const group = baseGroups[i];
                if (groupMap[group.id])
                    orderedGroups.push(group);
            }

            return orderedGroups;
        }

        Item {
            anchors.fill: parent
            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true

            Column {
                id: menuColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingXXS

                Item {
                    id: controlCenterContentMetrics
                    visible: false
                    implicitWidth: 16 + Theme.spacingS + 16 + Theme.spacingS + longestControlCenterLabelMetrics.advanceWidth + Theme.spacingM + 40 + Theme.spacingS * 2 + Theme.spacingM
                }

                TextMetrics {
                    id: longestControlCenterLabelMetrics
                    font.pixelSize: Theme.fontSizeSmall
                    text: {
                        const labels = [I18n.tr("Network"), I18n.tr("VPN"), I18n.tr("Bluetooth"), I18n.tr("Audio"), I18n.tr("Volume"), I18n.tr("Microphone"), I18n.tr("Microphone Volume"), I18n.tr("Brightness"), I18n.tr("Brightness Value"), I18n.tr("Battery"), I18n.tr("Printer"), I18n.tr("Screen sharing"), I18n.tr("Idle Inhibitor"), I18n.tr("Do Not Disturb")];
                        let longest = "";
                        for (let i = 0; i < labels.length; i++) {
                            if (labels[i].length > longest.length)
                                longest = labels[i];
                        }
                        return longest;
                    }
                }

                Repeater {
                    id: groupRepeater
                    model: controlCenterContextMenu.controlCenterGroups

                    delegate: Item {
                        id: delegateRoot

                        required property var modelData
                        required property int index

                        function getCheckedState(settingName) {
                            const wd = controlCenterContextMenu.currentWidgetData;
                            switch (settingName) {
                            case "showNetworkIcon":
                                return wd?.showNetworkIcon ?? SettingsData.controlCenterShowNetworkIcon;
                            case "showVpnIcon":
                                return wd?.showVpnIcon ?? SettingsData.controlCenterShowVpnIcon;
                            case "showBluetoothIcon":
                                return wd?.showBluetoothIcon ?? SettingsData.controlCenterShowBluetoothIcon;
                            case "showAudioIcon":
                                return wd?.showAudioIcon ?? SettingsData.controlCenterShowAudioIcon;
                            case "showAudioPercent":
                                return wd?.showAudioPercent ?? SettingsData.controlCenterShowAudioPercent;
                            case "showMicIcon":
                                return wd?.showMicIcon ?? SettingsData.controlCenterShowMicIcon;
                            case "showMicPercent":
                                return wd?.showMicPercent ?? SettingsData.controlCenterShowMicPercent;
                            case "showBrightnessIcon":
                                return wd?.showBrightnessIcon ?? SettingsData.controlCenterShowBrightnessIcon;
                            case "showBrightnessPercent":
                                return wd?.showBrightnessPercent ?? SettingsData.controlCenterShowBrightnessPercent;
                            case "showBatteryIcon":
                                return wd?.showBatteryIcon ?? SettingsData.controlCenterShowBatteryIcon;
                            case "showPrinterIcon":
                                return wd?.showPrinterIcon ?? SettingsData.controlCenterShowPrinterIcon;
                            case "showScreenSharingIcon":
                                return wd?.showScreenSharingIcon ?? SettingsData.controlCenterShowScreenSharingIcon;
                            case "showIdleInhibitorIcon":
                                return wd?.showIdleInhibitorIcon ?? SettingsData.controlCenterShowIdleInhibitorIcon;
                            case "showDoNotDisturbIcon":
                                return wd?.showDoNotDisturbIcon ?? SettingsData.controlCenterShowDoNotDisturbIcon;
                            default:
                                return false;
                            }
                        }

                        readonly property string rootSetting: modelData.rows[0]?.setting ?? ""
                        readonly property bool rootEnabled: rootSetting ? getCheckedState(rootSetting) : true
                        readonly property bool isDragged: controlCenterContextMenu.draggedControlCenterGroupIndex === index
                        readonly property bool showDropIndicatorAbove: controlCenterContextMenu.controlCenterGroupDropIndex === index
                        readonly property bool showDropIndicatorBelow: controlCenterContextMenu.controlCenterGroupDropIndex === controlCenterContextMenu.controlCenterGroups.length && index === controlCenterContextMenu.controlCenterGroups.length - 1

                        width: menuColumn.width
                        height: groupBackground.height

                        Rectangle {
                            id: groupBackground
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: groupContent.implicitHeight + Theme.spacingXS * 2
                            radius: Theme.cornerRadius
                            color: isDragged ? Theme.primaryPressed : (groupHoverArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0))
                            opacity: isDragged ? 0.75 : 1.0
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: -1
                            height: 2
                            radius: 1
                            color: Theme.primary
                            visible: showDropIndicatorAbove
                            z: 3
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: -1
                            height: 2
                            radius: 1
                            color: Theme.primary
                            visible: showDropIndicatorBelow
                            z: 3
                        }

                        Item {
                            id: groupContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: Theme.spacingXS
                            implicitHeight: groupColumn.implicitHeight

                            Column {
                                id: groupColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: 1

                                Repeater {
                                    id: groupColumnRepeater
                                    model: modelData.rows

                                    delegate: Rectangle {
                                        required property var modelData
                                        required property int index

                                        readonly property var rowData: modelData
                                        readonly property bool isFirstRow: index === 0
                                        readonly property bool rowEnabled: isFirstRow ? true : delegateRoot.rootEnabled
                                        readonly property bool computedCheckedState: rowEnabled ? getCheckedState(rowData.setting) : false
                                        readonly property bool rowHovered: rowEnabled && (toggleArea.containsMouse || (isFirstRow && groupDragHandleArea.containsMouse))

                                        width: groupColumn.width
                                        height: 32
                                        radius: Theme.cornerRadius
                                        opacity: rowEnabled ? 1.0 : 0.5
                                        color: rowHovered ? Theme.primaryHoverLight : Theme.withAlpha(Theme.primaryHoverLight, 0)

                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: Theme.spacingS
                                            anchors.right: toggle.left
                                            anchors.rightMargin: Theme.spacingM
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: Theme.spacingS
                                            clip: true

                                            Item {
                                                width: 16
                                                height: 16
                                                anchors.verticalCenter: parent.verticalCenter

                                                DankIcon {
                                                    anchors.centerIn: parent
                                                    name: "drag_indicator"
                                                    size: 16
                                                    color: groupDragHandleArea.pressed || isDragged ? Theme.primary : Theme.outline
                                                    visible: isFirstRow
                                                }

                                                MouseArea {
                                                    id: groupDragHandleArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    preventStealing: true
                                                    enabled: isFirstRow
                                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                                                    onPressed: mouse => {
                                                        mouse.accepted = true;
                                                        const point = mapToItem(menuColumn, mouse.x, mouse.y);
                                                        controlCenterContextMenu.updateControlCenterGroupDropIndex(delegateRoot.index, point.y);
                                                    }
                                                    onPositionChanged: mouse => {
                                                        if (!pressed)
                                                            return;
                                                        mouse.accepted = true;
                                                        const point = mapToItem(menuColumn, mouse.x, mouse.y);
                                                        controlCenterContextMenu.updateControlCenterGroupDropIndex(delegateRoot.index, point.y);
                                                    }
                                                    onReleased: mouse => {
                                                        mouse.accepted = true;
                                                        const point = mapToItem(menuColumn, mouse.x, mouse.y);
                                                        controlCenterContextMenu.updateControlCenterGroupDropIndex(delegateRoot.index, point.y);
                                                        controlCenterContextMenu.finishControlCenterDrag();
                                                    }
                                                    onCanceled: {
                                                        controlCenterContextMenu.cancelControlCenterDrag();
                                                    }
                                                }
                                            }

                                            DankIcon {
                                                name: rowData.icon
                                                size: 16
                                                color: Theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            StyledText {
                                                text: rowData.label
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceText
                                                font.weight: Font.Normal
                                                anchors.verticalCenter: parent.verticalCenter
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                                width: parent.width - 16 - Theme.spacingS - 16 - Theme.spacingS
                                            }
                                        }

                                        DankToggle {
                                            id: toggle
                                            anchors.right: parent.right
                                            anchors.rightMargin: Theme.spacingS
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 40
                                            height: 20
                                            enabled: rowEnabled
                                            checked: computedCheckedState

                                            onToggled: {
                                                if (!rowEnabled)
                                                    return;
                                                root.controlCenterSettingChanged(controlCenterContextMenu.sectionId, controlCenterContextMenu.widgetIndex, rowData.setting, toggled);
                                            }
                                        }

                                        MouseArea {
                                            id: toggleArea
                                            anchors.fill: parent
                                            anchors.leftMargin: 16 + Theme.spacingS * 2
                                            hoverEnabled: true
                                            cursorShape: rowEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            enabled: rowEnabled && controlCenterContextMenu.draggedControlCenterGroupIndex < 0
                                            onPressed: {
                                                if (!rowEnabled)
                                                    return;
                                                root.controlCenterSettingChanged(controlCenterContextMenu.sectionId, controlCenterContextMenu.widgetIndex, rowData.setting, !computedCheckedState);
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: groupHoverArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: false
                            }
                        }
                    }
                }
            }
        }
    }

    WidgetSettingsMenu {
        id: privacyContextMenu

        menuWidth: 240
        menuHeight: menuPrivacyColumn.implicitHeight + Theme.spacingS * 2

        onOpened: {
            log.debug("Privacy context menu opened");
        }

        onClosed: {
            log.debug("Privacy Center context menu closed");
        }

        Item {
            anchors.fill: parent
            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true

            Column {
                id: menuPrivacyColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingXXS

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Always on icons")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: micToggleArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: micToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "mic"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Microphone")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 16 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: micToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: SettingsData.privacyShowMicIcon
                        onToggled: toggled => {
                            root.privacySettingChanged(privacyContextMenu.sectionId, privacyContextMenu.widgetIndex, "showMicIcon", toggled);
                        }
                    }

                    MouseArea {
                        id: micToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            micToggle.checked = !micToggle.checked;
                            root.privacySettingChanged(privacyContextMenu.sectionId, privacyContextMenu.widgetIndex, "showMicIcon", micToggle.checked);
                        }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: cameraToggleArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: cameraToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "camera_video"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Camera")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 16 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: cameraToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: SettingsData.privacyShowCameraIcon
                        onToggled: toggled => {
                            root.privacySettingChanged(privacyContextMenu.sectionId, privacyContextMenu.widgetIndex, "showCameraIcon", toggled);
                        }
                    }

                    MouseArea {
                        id: cameraToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            cameraToggle.checked = !cameraToggle.checked;
                            root.privacySettingChanged(privacyContextMenu.sectionId, privacyContextMenu.widgetIndex, "showCameraIcon", cameraToggle.checked);
                        }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: screenshareToggleArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: screenshareToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "screen_share"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Screen sharing")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 16 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: screenshareToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: SettingsData.privacyShowScreenShareIcon
                        onToggled: toggled => {
                            root.privacySettingChanged(privacyContextMenu.sectionId, privacyContextMenu.widgetIndex, "showScreenSharingIcon", toggled);
                        }
                    }

                    MouseArea {
                        id: screenshareToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            screenshareToggle.checked = !screenshareToggle.checked;
                            root.privacySettingChanged(privacyContextMenu.sectionId, privacyContextMenu.widgetIndex, "showScreenSharingIcon", screenshareToggle.checked);
                        }
                    }
                }
            }
        }
    }

    WidgetSettingsMenu {
        id: gpuContextMenu

        menuWidth: 250
        menuHeight: gpuMenuColumn.implicitHeight + Theme.spacingS * 2

        Item {
            anchors.fill: parent
            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true
            Column {
                id: gpuMenuColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingXXS

                Repeater {
                    model: DgopService.availableGpus || []

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: gpuMenuColumn.width
                        height: 40
                        radius: Theme.cornerRadius
                        color: gpuOptionArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                        property bool isSelected: {
                            var selectedIdx = gpuContextMenu.widgetData ? (gpuContextMenu.widgetData.selectedGpuIndex !== undefined ? gpuContextMenu.widgetData.selectedGpuIndex : 0) : 0;
                            return index === selectedIdx;
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: checkIcon.left
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "memory"
                                size: 18
                                color: isSelected ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingXXS

                                StyledText {
                                    text: modelData.driver ? modelData.driver.toUpperCase() : ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: isSelected ? Theme.primary : Theme.surfaceText
                                }

                                StyledText {
                                    text: modelData.displayName || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    elide: Text.ElideRight
                                    width: 180
                                }
                            }
                        }

                        DankIcon {
                            id: checkIcon
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            name: "check"
                            size: 18
                            color: Theme.primary
                            visible: isSelected
                        }

                        MouseArea {
                            id: gpuOptionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.gpuSelectionChanged(gpuContextMenu.sectionId, gpuContextMenu.widgetIndex, index);
                                gpuContextMenu.close();
                            }
                        }
                    }
                }
            }
        }
    }

    WidgetSettingsMenu {
        id: batteryContextMenu

        menuWidth: 270
        menuHeight: batteryMenuColumn.implicitHeight + Theme.spacingS * 2

        Item {
            anchors.fill: parent
            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true
            Column {
                id: batteryMenuColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingXXS

                Rectangle {
                    width: parent.width
                    height: Math.max(18, Theme.fontSizeSmall) + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: batteryPercentArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: batteryPercentToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "percent"
                            size: 18
                            color: Theme.outline
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Show Percentage")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 18 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: batteryPercentToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: batteryContextMenu.currentWidgetData?.showBatteryPercent ?? SettingsData.showBatteryPercent
                        onToggled: {
                            root.overflowSettingChanged(batteryContextMenu.sectionId, batteryContextMenu.widgetIndex, "showBatteryPercent", toggled);
                        }
                    }

                    MouseArea {
                        id: batteryPercentArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            batteryPercentToggle.checked = !batteryPercentToggle.checked;
                            root.overflowSettingChanged(batteryContextMenu.sectionId, batteryContextMenu.widgetIndex, "showBatteryPercent", batteryPercentToggle.checked);
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Math.max(18, Theme.fontSizeSmall) + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: batteryPercentOnlyOnBatteryArea.containsMouse && batteryPercentToggle.checked ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)
                    opacity: batteryPercentToggle.checked ? 1.0 : 0.5

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS + 18
                        anchors.right: batteryPercentOnlyOnBatteryToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "battery_charging_full"
                            size: 18
                            color: Theme.outline
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Only on Battery")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 18 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: batteryPercentOnlyOnBatteryToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        enabled: batteryPercentToggle.checked
                        checked: batteryContextMenu.currentWidgetData?.showBatteryPercentOnlyOnBattery ?? SettingsData.showBatteryPercentOnlyOnBattery
                        onToggled: {
                            root.overflowSettingChanged(batteryContextMenu.sectionId, batteryContextMenu.widgetIndex, "showBatteryPercentOnlyOnBattery", toggled);
                        }
                    }

                    MouseArea {
                        id: batteryPercentOnlyOnBatteryArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: batteryPercentToggle.checked
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onPressed: {
                            batteryPercentOnlyOnBatteryToggle.checked = !batteryPercentOnlyOnBatteryToggle.checked;
                            root.overflowSettingChanged(batteryContextMenu.sectionId, batteryContextMenu.widgetIndex, "showBatteryPercentOnlyOnBattery", batteryPercentOnlyOnBatteryToggle.checked);
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Math.max(18, Theme.fontSizeSmall) + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: batteryTimeArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: batteryTimeToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "schedule"
                            size: 18
                            color: Theme.outline
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Show Remaining Time")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 18 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: batteryTimeToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: batteryContextMenu.currentWidgetData?.showBatteryTime ?? SettingsData.showBatteryTime
                        onToggled: {
                            root.overflowSettingChanged(batteryContextMenu.sectionId, batteryContextMenu.widgetIndex, "showBatteryTime", toggled);
                        }
                    }

                    MouseArea {
                        id: batteryTimeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            batteryTimeToggle.checked = !batteryTimeToggle.checked;
                            root.overflowSettingChanged(batteryContextMenu.sectionId, batteryContextMenu.widgetIndex, "showBatteryTime", batteryTimeToggle.checked);
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Math.max(18, Theme.fontSizeSmall) + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: batteryTimeOnlyOnBatteryArea.containsMouse && batteryTimeToggle.checked ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)
                    opacity: batteryTimeToggle.checked ? 1.0 : 0.5

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS + 18
                        anchors.right: batteryTimeOnlyOnBatteryToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "battery_charging_full"
                            size: 18
                            color: Theme.outline
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Only on Battery")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 18 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: batteryTimeOnlyOnBatteryToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        enabled: batteryTimeToggle.checked
                        checked: batteryContextMenu.currentWidgetData?.showBatteryTimeOnlyOnBattery ?? SettingsData.showBatteryTimeOnlyOnBattery
                        onToggled: {
                            root.overflowSettingChanged(batteryContextMenu.sectionId, batteryContextMenu.widgetIndex, "showBatteryTimeOnlyOnBattery", toggled);
                        }
                    }

                    MouseArea {
                        id: batteryTimeOnlyOnBatteryArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: batteryTimeToggle.checked
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onPressed: {
                            batteryTimeOnlyOnBatteryToggle.checked = !batteryTimeOnlyOnBatteryToggle.checked;
                            root.overflowSettingChanged(batteryContextMenu.sectionId, batteryContextMenu.widgetIndex, "showBatteryTimeOnlyOnBattery", batteryTimeOnlyOnBatteryToggle.checked);
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Math.max(18, Theme.fontSizeSmall) + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: batteryPowerChargingArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: batteryPowerChargingToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "bolt"
                            size: 18
                            color: Theme.outline
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Show Charge Rate", "Battery bar widget setting: show how many watts are going into the battery while charging")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 18 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: batteryPowerChargingToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: batteryContextMenu.currentWidgetData?.showBatteryPowerCharging ?? SettingsData.showBatteryPowerCharging
                        onToggled: {
                            root.overflowSettingChanged(batteryContextMenu.sectionId, batteryContextMenu.widgetIndex, "showBatteryPowerCharging", toggled);
                        }
                    }

                    MouseArea {
                        id: batteryPowerChargingArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            batteryPowerChargingToggle.checked = !batteryPowerChargingToggle.checked;
                            root.overflowSettingChanged(batteryContextMenu.sectionId, batteryContextMenu.widgetIndex, "showBatteryPowerCharging", batteryPowerChargingToggle.checked);
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Math.max(18, Theme.fontSizeSmall) + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: batteryPowerDischargingArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: batteryPowerDischargingToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "battery_5_bar"
                            size: 18
                            color: Theme.outline
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Show Discharge Rate", "Battery bar widget setting: show how many watts the system is drawing from the battery")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 18 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: batteryPowerDischargingToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: batteryContextMenu.currentWidgetData?.showBatteryPowerDischarging ?? SettingsData.showBatteryPowerDischarging
                        onToggled: {
                            root.overflowSettingChanged(batteryContextMenu.sectionId, batteryContextMenu.widgetIndex, "showBatteryPowerDischarging", toggled);
                        }
                    }

                    MouseArea {
                        id: batteryPowerDischargingArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            batteryPowerDischargingToggle.checked = !batteryPowerDischargingToggle.checked;
                            root.overflowSettingChanged(batteryContextMenu.sectionId, batteryContextMenu.widgetIndex, "showBatteryPowerDischarging", batteryPowerDischargingToggle.checked);
                        }
                    }
                }

                Column {
                    id: batteryStyleBlock

                    width: parent.width
                    leftPadding: Theme.spacingS
                    rightPadding: Theme.spacingS
                    topPadding: Theme.spacingXS
                    bottomPadding: Theme.spacingXS
                    spacing: Theme.spacingXS

                    Row {
                        width: batteryStyleBlock.width - Theme.spacingS * 2
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "battery_horiz_075"
                            size: 18
                            color: Theme.outline
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Battery Style")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 18 - Theme.spacingS
                        }
                    }

                    DankButtonGroup {
                        id: batteryStyleGroup

                        readonly property var values: ["icon", "solid", "outline", "ring"]

                        model: [I18n.tr("Icon", "battery widget: system battery glyph"), I18n.tr("Solid", "island settings: filled battery meter style"), I18n.tr("Outline", "island settings: outlined battery meter style"), I18n.tr("Circle", "island settings: circular battery meter style")]
                        buttonHeight: 24
                        minButtonWidth: 44
                        maximumWidth: batteryStyleBlock.width - Theme.spacingS * 2
                        buttonPadding: 6
                        checkIconSize: 10
                        textSize: 10
                        spacing: 2
                        currentIndex: Math.max(0, batteryStyleGroup.values.indexOf(batteryContextMenu.currentWidgetData?.batteryStyle ?? SettingsData.batteryStyle))
                        onSelectionChanged: (index, selected) => {
                            if (!selected)
                                return;
                            root.overflowSettingChanged(batteryContextMenu.sectionId, batteryContextMenu.widgetIndex, "batteryStyle", batteryStyleGroup.values[index] ?? "icon");
                        }
                    }
                }
            }
        }
    }

    WidgetSettingsMenu {
        id: musicContextMenu

        menuWidth: 180
        menuHeight: musicMenuColumn.implicitHeight + Theme.spacingS * 2

        Item {
            anchors.fill: parent
            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true
            Column {
                id: musicMenuColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingXXS

                Repeater {
                    model: [
                        {
                            icon: "photo_size_select_small",
                            label: I18n.tr("Small"),
                            sizeValue: 0
                        },
                        {
                            icon: "photo_size_select_actual",
                            label: I18n.tr("Medium"),
                            sizeValue: 1
                        },
                        {
                            icon: "photo_size_select_large",
                            label: I18n.tr("Large"),
                            sizeValue: 2
                        },
                        {
                            icon: "fit_screen",
                            label: I18n.tr("Largest"),
                            sizeValue: 3
                        }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        function isSelected() {
                            var wd = musicContextMenu.widgetData;
                            var currentSize = wd?.mediaSize ?? SettingsData.mediaSize;
                            return currentSize === modelData.sizeValue;
                        }

                        width: musicMenuColumn.width
                        height: Math.max(18, Theme.fontSizeSmall) + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: musicOptionArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: musicSizeCheck.left
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS
                            clip: true

                            DankIcon {
                                name: modelData.icon
                                size: 18
                                color: isSelected() ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: isSelected() ? Font.Medium : Font.Normal
                                color: isSelected() ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                width: parent.width - 18 - Theme.spacingS
                            }
                        }

                        DankIcon {
                            id: musicSizeCheck
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            name: "check"
                            size: 16
                            color: Theme.primary
                            visible: isSelected()
                        }

                        MouseArea {
                            id: musicOptionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.widgetSizeChanged("music", modelData.sizeValue);
                                musicContextMenu.close();
                            }
                        }
                    }
                }
            }
        }
    }

    WidgetSettingsMenu {
        id: runningAppsContextMenu

        menuWidth: 240
        menuHeight: runningAppsMenuColumn.implicitHeight + Theme.spacingS * 2

        Item {
            anchors.fill: parent
            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true
            Column {
                id: runningAppsMenuColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingXXS

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: "transparent"

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Running Apps Settings")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: raCompactArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: raCompactToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "zoom_in"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Compact Mode")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 16 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: raCompactToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: runningAppsContextMenu.currentWidgetData?.runningAppsCompactMode ?? SettingsData.runningAppsCompactMode
                        onToggled: {
                            root.overflowSettingChanged(runningAppsContextMenu.sectionId, runningAppsContextMenu.widgetIndex, "runningAppsCompactMode", toggled);
                        }
                    }

                    MouseArea {
                        id: raCompactArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            raCompactToggle.checked = !raCompactToggle.checked;
                            root.overflowSettingChanged(runningAppsContextMenu.sectionId, runningAppsContextMenu.widgetIndex, "runningAppsCompactMode", raCompactToggle.checked);
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: raGroupArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: raGroupToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "apps"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Group by App")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 16 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: raGroupToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: runningAppsContextMenu.currentWidgetData?.runningAppsGroupByApp ?? SettingsData.runningAppsGroupByApp
                        onToggled: {
                            root.overflowSettingChanged(runningAppsContextMenu.sectionId, runningAppsContextMenu.widgetIndex, "runningAppsGroupByApp", toggled);
                        }
                    }

                    MouseArea {
                        id: raGroupArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            raGroupToggle.checked = !raGroupToggle.checked;
                            root.overflowSettingChanged(runningAppsContextMenu.sectionId, runningAppsContextMenu.widgetIndex, "runningAppsGroupByApp", raGroupToggle.checked);
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: raWorkspaceArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: raWorkspaceToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "workspaces"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Current Workspace", "Running apps filter: only show apps from the active workspace")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 16 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: raWorkspaceToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: runningAppsContextMenu.currentWidgetData?.runningAppsCurrentWorkspace ?? SettingsData.runningAppsCurrentWorkspace
                        onToggled: {
                            root.overflowSettingChanged(runningAppsContextMenu.sectionId, runningAppsContextMenu.widgetIndex, "runningAppsCurrentWorkspace", toggled);
                        }
                    }

                    MouseArea {
                        id: raWorkspaceArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            raWorkspaceToggle.checked = !raWorkspaceToggle.checked;
                            root.overflowSettingChanged(runningAppsContextMenu.sectionId, runningAppsContextMenu.widgetIndex, "runningAppsCurrentWorkspace", raWorkspaceToggle.checked);
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: raDisplayArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.right: raDisplayToggle.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        clip: true

                        DankIcon {
                            name: "monitor"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Current Monitor", "Running apps filter: only show apps from the same monitor")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 16 - Theme.spacingS
                        }
                    }

                    DankToggle {
                        id: raDisplayToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: runningAppsContextMenu.currentWidgetData?.runningAppsCurrentMonitor ?? SettingsData.runningAppsCurrentMonitor
                        onToggled: {
                            root.overflowSettingChanged(runningAppsContextMenu.sectionId, runningAppsContextMenu.widgetIndex, "runningAppsCurrentMonitor", toggled);
                        }
                    }

                    MouseArea {
                        id: raDisplayArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            raDisplayToggle.checked = !raDisplayToggle.checked;
                            root.overflowSettingChanged(runningAppsContextMenu.sectionId, runningAppsContextMenu.widgetIndex, "runningAppsCurrentMonitor", raDisplayToggle.checked);
                        }
                    }
                }
            }
        }
    }

    WidgetSettingsMenu {
        id: appsDockContextMenu

        menuWidth: 320
        menuHeight: appsDockMenuColumn.implicitHeight + Theme.spacingS * 2

        Item {
            anchors.fill: parent
            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true
            Column {
                id: appsDockMenuColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingS

                StyledText {
                    text: I18n.tr("Apps Dock Settings")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    leftPadding: Theme.spacingS
                    rightPadding: Theme.spacingS
                    width: parent.width
                    horizontalAlignment: Text.AlignLeft
                }

                StyledText {
                    text: I18n.tr("Overflow")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    leftPadding: Theme.spacingS
                    rightPadding: Theme.spacingS
                    width: parent.width
                    horizontalAlignment: Text.AlignLeft
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Max Pinned Apps")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            width: 120
                            maximumLineCount: 1
                            horizontalAlignment: Text.AlignLeft
                        }

                        Row {
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            DankActionButton {
                                buttonSize: 24
                                iconName: "remove"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var current = appsDockContextMenu.currentWidgetData?.barMaxVisibleApps ?? SettingsData.barMaxVisibleApps;
                                    var newVal = Math.max(0, current - 1);
                                    root.overflowSettingChanged(appsDockContextMenu.sectionId, appsDockContextMenu.widgetIndex, "barMaxVisibleApps", newVal);
                                }
                            }

                            StyledText {
                                text: {
                                    var val = appsDockContextMenu.currentWidgetData?.barMaxVisibleApps ?? SettingsData.barMaxVisibleApps;
                                    return val === 0 ? I18n.tr("All") : val;
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignHCenter
                                width: 30
                            }

                            DankActionButton {
                                buttonSize: 24
                                iconName: "add"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var current = appsDockContextMenu.currentWidgetData?.barMaxVisibleApps ?? SettingsData.barMaxVisibleApps;
                                    var newVal = current + 1;
                                    root.overflowSettingChanged(appsDockContextMenu.sectionId, appsDockContextMenu.widgetIndex, "barMaxVisibleApps", newVal);
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Max Running Apps")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            width: 120
                            maximumLineCount: 1
                            horizontalAlignment: Text.AlignLeft
                        }

                        Row {
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            DankActionButton {
                                buttonSize: 24
                                iconName: "remove"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var current = appsDockContextMenu.currentWidgetData?.barMaxVisibleRunningApps ?? SettingsData.barMaxVisibleRunningApps;
                                    var newVal = Math.max(0, current - 1);
                                    root.overflowSettingChanged(appsDockContextMenu.sectionId, appsDockContextMenu.widgetIndex, "barMaxVisibleRunningApps", newVal);
                                }
                            }

                            StyledText {
                                text: {
                                    var val = appsDockContextMenu.currentWidgetData?.barMaxVisibleRunningApps ?? SettingsData.barMaxVisibleRunningApps;
                                    return val === 0 ? I18n.tr("All") : val;
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignHCenter
                                width: 30
                            }

                            DankActionButton {
                                buttonSize: 24
                                iconName: "add"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var current = appsDockContextMenu.currentWidgetData?.barMaxVisibleRunningApps ?? SettingsData.barMaxVisibleRunningApps;
                                    var newVal = current + 1;
                                    root.overflowSettingChanged(appsDockContextMenu.sectionId, appsDockContextMenu.widgetIndex, "barMaxVisibleRunningApps", newVal);
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.15
                    }

                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: Theme.cornerRadius
                        color: badgeToggleArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: badgeToggle.left
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS
                            clip: true

                            DankIcon {
                                name: "notifications"
                                size: 16
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: I18n.tr("Show Badge")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                width: parent.width - 16 - Theme.spacingS
                            }
                        }

                        DankToggle {
                            id: badgeToggle
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 20
                            checked: appsDockContextMenu.currentWidgetData?.barShowOverflowBadge ?? SettingsData.barShowOverflowBadge
                            onToggled: {
                                root.overflowSettingChanged(appsDockContextMenu.sectionId, appsDockContextMenu.widgetIndex, "barShowOverflowBadge", toggled);
                            }
                        }

                        MouseArea {
                            id: badgeToggleArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                badgeToggle.checked = !badgeToggle.checked;
                                root.overflowSettingChanged(appsDockContextMenu.sectionId, appsDockContextMenu.widgetIndex, "barShowOverflowBadge", badgeToggle.checked);
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.15
                    }

                    StyledText {
                        text: I18n.tr("Visual Effects")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        leftPadding: Theme.spacingS
                        rightPadding: Theme.spacingS
                        topPadding: Theme.spacingXS
                        width: parent.width
                        horizontalAlignment: Text.AlignLeft
                    }

                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: Theme.cornerRadius
                        color: hideIndicatorsArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: hideIndicatorsToggle.left
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS
                            clip: true

                            DankIcon {
                                name: "visibility_off"
                                size: 16
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: I18n.tr("Hide Indicators")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                width: parent.width - 16 - Theme.spacingS
                            }
                        }

                        DankToggle {
                            id: hideIndicatorsToggle
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 20
                            checked: SettingsData.appsDockHideIndicators
                            onToggled: {
                                SettingsData.set("appsDockHideIndicators", toggled);
                            }
                        }

                        MouseArea {
                            id: hideIndicatorsArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                hideIndicatorsToggle.checked = !hideIndicatorsToggle.checked;
                                SettingsData.set("appsDockHideIndicators", hideIndicatorsToggle.checked);
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: Theme.cornerRadius
                        color: colorizeActiveArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: colorizeActiveToggle.left
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS
                            clip: true

                            DankIcon {
                                name: "palette"
                                size: 16
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: I18n.tr("Colorize Active")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                width: parent.width - 16 - Theme.spacingS
                            }
                        }

                        DankToggle {
                            id: colorizeActiveToggle
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 20
                            checked: SettingsData.appsDockColorizeActive
                            onToggled: {
                                SettingsData.set("appsDockColorizeActive", toggled);
                            }
                        }

                        MouseArea {
                            id: colorizeActiveArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                colorizeActiveToggle.checked = !colorizeActiveToggle.checked;
                                SettingsData.set("appsDockColorizeActive", colorizeActiveToggle.checked);
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: SettingsData.appsDockColorizeActive
                        leftPadding: Theme.spacingL + Theme.spacingS

                        StyledText {
                            text: I18n.tr("Active Color")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            width: 90
                            maximumLineCount: 1
                            horizontalAlignment: Text.AlignLeft
                        }

                        DankButtonGroup {
                            anchors.verticalCenter: parent.verticalCenter
                            model: ["pri", "sec", "pc", "err", "ok"]
                            buttonHeight: 22
                            minButtonWidth: 32
                            buttonPadding: 4
                            checkIconSize: 10
                            textSize: 9
                            spacing: 1
                            currentIndex: {
                                switch (SettingsData.appsDockActiveColorMode) {
                                case "secondary":
                                    return 1;
                                case "primaryContainer":
                                    return 2;
                                case "error":
                                    return 3;
                                case "success":
                                    return 4;
                                default:
                                    return 0;
                                }
                            }
                            onSelectionChanged: (index, selected) => {
                                if (!selected)
                                    return;
                                const modes = ["primary", "secondary", "primaryContainer", "error", "success"];
                                SettingsData.set("appsDockActiveColorMode", modes[index]);
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: Theme.cornerRadius
                        color: enlargeOnHoverArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.primaryHover, 0)

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: enlargeOnHoverToggle.left
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS
                            clip: true

                            DankIcon {
                                name: "zoom_in"
                                size: 16
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: I18n.tr("Enlarge on Hover")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                width: parent.width - 16 - Theme.spacingS
                            }
                        }

                        DankToggle {
                            id: enlargeOnHoverToggle
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 20
                            checked: SettingsData.appsDockEnlargeOnHover
                            onToggled: {
                                SettingsData.set("appsDockEnlargeOnHover", toggled);
                            }
                        }

                        MouseArea {
                            id: enlargeOnHoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                enlargeOnHoverToggle.checked = !enlargeOnHoverToggle.checked;
                                SettingsData.set("appsDockEnlargeOnHover", enlargeOnHoverToggle.checked);
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: SettingsData.appsDockEnlargeOnHover

                        StyledText {
                            text: I18n.tr("Enlargement %")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            width: 120
                            maximumLineCount: 1
                            horizontalAlignment: Text.AlignLeft
                        }

                        Row {
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            DankActionButton {
                                buttonSize: 24
                                iconName: "remove"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var current = SettingsData.appsDockEnlargePercentage;
                                    var newVal = Math.max(100, current - 5);
                                    SettingsData.set("appsDockEnlargePercentage", newVal);
                                }
                            }

                            StyledText {
                                text: SettingsData.appsDockEnlargePercentage + "%"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignHCenter
                                width: 50
                            }

                            DankActionButton {
                                buttonSize: 24
                                iconName: "add"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var current = SettingsData.appsDockEnlargePercentage;
                                    var newVal = Math.min(150, current + 5);
                                    SettingsData.set("appsDockEnlargePercentage", newVal);
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Icon Size %")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            width: 120
                            maximumLineCount: 1
                            horizontalAlignment: Text.AlignLeft
                        }

                        Row {
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            DankActionButton {
                                buttonSize: 24
                                iconName: "remove"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var current = SettingsData.appsDockIconSizePercentage;
                                    var newVal = Math.max(50, current - 5);
                                    SettingsData.set("appsDockIconSizePercentage", newVal);
                                }
                            }

                            StyledText {
                                text: SettingsData.appsDockIconSizePercentage + "%"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignHCenter
                                width: 50
                            }

                            DankActionButton {
                                buttonSize: 24
                                iconName: "add"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var current = SettingsData.appsDockIconSizePercentage;
                                    var newVal = Math.min(200, current + 5);
                                    SettingsData.set("appsDockIconSizePercentage", newVal);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
