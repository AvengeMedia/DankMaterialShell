pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets
import qs.Modules.DankDash.Overview
import "../../DankCommon/Common/FocusNavigation.js" as FocusNavigation

DankPopout {
    id: root

    layerNamespace: "dms:dash"
    fullHeightSurface: true
    contentHandlesKeys: true
    closesWithSource: false
    resizeCurve: Theme.expressiveCurves.standard
    resizeDuration: Theme.expressiveDurations.expressiveFastSpatial
    resizeMotion: true
    resizing: contentLoader.item?.panelResizing ?? false
    surfacePadding: PopoutMetrics.editOverflow * 2
    inputMargin: editGutter * 2
    hoverDismissSuspended: editMode
    onOpened: contentFocusTimer.restart()

    Timer {
        id: contentFocusTimer
        interval: 0
        onTriggered: {
            if (root.shouldBeVisible)
                root.contentLoader.item?.focusInitial();
        }
    }

    property bool dashVisible: false
    property var triggerScreen: null
    property string currentTabId: DashRegistry.defaultTabId
    property string detailTabId: ""
    property bool editMode: false
    property string overviewFocusId: CacheData.dashFocusCardId || "calendar"

    onEditModeChanged: {
        if (!editMode)
            contentLoader.item?.panelResizer.cancel();
        if (!shouldBeVisible)
            return;
        Qt.callLater(() => contentLoader.item?.focusInitial());
    }

    readonly property string activeTabId: detailTabId !== "" ? detailTabId : currentTabId
    readonly property var detailEntry: detailTabId !== "" ? DashRegistry.entry(detailTabId) : null
    readonly property var orderedTabIds: DashRegistry.visibleTabIds
    readonly property int currentTabIndex: orderedTabIds.indexOf(currentTabId)
    readonly property bool showTabs: orderedTabIds.length > 1 && currentTabIndex >= 0 && detailTabId === ""
    readonly property bool showBack: detailTabId !== "" && currentTabIndex >= 0
    readonly property int navigationEdge: {
        switch (SettingsData.dashTabPosition) {
        case "left":
            return SettingsData.Left;
        case "right":
            return SettingsData.Right;
        case "bottom":
            return SettingsData.Bottom;
        case "center":
            return SettingsData.Top;
        }
        switch (effectiveBarPosition % 4) {
        case SettingsData.Left:
            return SettingsData.Right;
        case SettingsData.Right:
            return SettingsData.Left;
        default:
            return effectiveBarPosition % 4;
        }
    }
    readonly property bool verticalNavigation: showTabs && (navigationEdge === SettingsData.Left || navigationEdge === SettingsData.Right)
    readonly property real navigationWidth: verticalNavigation ? Theme.navigationRailWidth + DashMetrics.contentGap : 0

    readonly property int columnCap: DashMetrics.columnCapFor(screen ? screen.width - navigationWidth : undefined, SettingsData.showWeekNumber)
    readonly property real editGutter: editMode ? PopoutMetrics.editOverflow : 0

    popupWidth: panelWidthFor(DashMetrics.panelColumnsFor(activeTabId))
    minimumSurfaceWidth: panelWidthFor(editMode ? columnCap : DashRegistry.widestPanelColumns)
    popupHeight: contentLoader.item?.implicitHeight ?? (DashMetrics.tabDefaultHeight + Theme.navigationHeight + DashMetrics.contentGap + DashMetrics.contentPadding * 2)
    triggerWidth: DashMetrics.triggerWidth
    screen: triggerScreen

    property bool __focusArmed: false

    function panelWidthFor(columns) {
        return DashMetrics.widthFor(SettingsData.showWeekNumber, screen ? screen.width - navigationWidth : undefined, columns) + navigationWidth;
    }

    function requestTab(tab) {
        const id = DashRegistry.resolveId(tab);
        if (DashRegistry.isSelectable(id)) {
            detailTabId = "";
            currentTabId = id;
            return;
        }
        if (DashRegistry.hasTab(id)) {
            detailTabId = id;
            return;
        }
        detailTabId = "";
        currentTabId = DashRegistry.defaultTabId;
    }

    function closeDetail() {
        if (!showBack) {
            dashVisible = false;
            return;
        }
        detailTabId = "";
    }

    function cycleTab(dir) {
        const ids = orderedTabIds;
        if (ids.length === 0)
            return;
        const pos = ids.indexOf(currentTabId);
        const next = pos < 0 ? (dir > 0 ? 0 : ids.length - 1) : (pos + dir + ids.length) % ids.length;
        detailTabId = "";
        currentTabId = ids[next];
    }

    function focusContent(backwards) {
        contentLoader.item?.focusNavigation(backwards);
    }

    onActiveTabIdChanged: {
        editMode = false;
        contentLoader.item?.dismissOptions();
        contentLoader.item?.resetScroll();
        if (shouldBeVisible && !contentLoader.item?.navigationFocused)
            contentLoader.item?.focusInitial();
    }

    readonly property string registryVisibleTabIds: DashRegistry.visibleTabIds.join("\n")
    readonly property string registryTabIds: DashRegistry.tabIds.join("\n")

    onRegistryVisibleTabIdsChanged: {
        if (!DashRegistry.isSelectable(currentTabId))
            currentTabId = DashRegistry.defaultTabId;
    }

    onRegistryTabIdsChanged: {
        if (detailTabId !== "" && !DashRegistry.hasTab(detailTabId))
            detailTabId = "";
    }

    function __tryFocusOnce() {
        if (!__focusArmed)
            return;
        const win = root.contentWindow;
        if (!win || !win.visible)
            return;
        const content = contentLoader.item;
        if (!content)
            return;
        if (win.requestActivate)
            win.requestActivate();
        content.focusInitial();
        if (content.activeFocus)
            __focusArmed = false;
    }

    onDashVisibleChanged: {
        if (dashVisible) {
            __focusArmed = true;
            presentWhenReady();
            return;
        }
        __focusArmed = false;
        contentLoader.item?.dismissOptions();
        if (openDeadline.running) {
            openDeadline.stop();
            clearPrimedContent();
        }
        close();
        if (CacheData.dashFocusCardId !== overviewFocusId)
            CacheData.set("dashFocusCardId", overviewFocusId);
    }

    onPopoutClosed: {
        editMode = false;
        detailTabId = "";
    }

    function presentWhenReady() {
        primeContent();
        openDeadline.restart();
        Qt.callLater(presentIfReady);
    }

    function presentIfReady() {
        if (!openDeadline.running || !contentLoader.item?.ready)
            return;
        presentNow();
    }

    function presentNow() {
        openDeadline.stop();
        if (!dashVisible || shouldBeVisible)
            return;
        open();
        __tryFocusOnce();
    }

    Timer {
        id: openDeadline
        interval: DashMetrics.openReadyDeadline
        onTriggered: root.presentNow()
    }

    Connections {
        target: root.contentLoader.item ?? null
        ignoreUnknownSignals: true

        function onReadyChanged() {
            Qt.callLater(root.presentIfReady);
        }
    }

    Connections {
        target: contentLoader

        function onLoaded() {
            if (root.__focusArmed)
                root.__tryFocusOnce();
        }
    }

    Connections {
        target: root.contentWindow ? root.contentWindow : null
        enabled: !!root.contentWindow

        function onVisibleChanged() {
            if (root.__focusArmed)
                root.__tryFocusOnce();
        }
    }

    onBackgroundClicked: dashVisible = false

    content: Component {
        FocusScope {
            id: mainContainer

            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true

            implicitWidth: root.popupWidth
            implicitHeight: horizontalChromeHeight + pages.implicitHeight + DashMetrics.contentPadding * 2
            readonly property real horizontalChromeHeight: root.verticalNavigation ? 0 : (root.showTabs ? tabBar.implicitHeight : Theme.minimumTouchTargetSize) + DashMetrics.contentGap
            readonly property bool ready: pages.ready
            readonly property bool navigationFocused: tabBar.activeFocus
            focus: true

            readonly property bool panelResizing: panelResizer.resizing
            readonly property bool cardResizing: pages.currentItem?.cardResizing ?? false
            property int cardResizeColumns: 0
            property int cardResizeRows: 0
            readonly property bool panelShifted: cardResizing && (panelColumns !== cardResizeColumns || panelRows !== cardResizeRows)
            onCardResizingChanged: {
                if (!cardResizing)
                    return;
                cardResizeColumns = panelColumns;
                cardResizeRows = panelRows;
            }
            readonly property int panelColumns: DashMetrics.panelColumnsFor(root.activeTabId)
            readonly property int contentRows: DashMetrics.rowsForHeight(pages.currentHostImplicitHeight)
            readonly property int panelRows: Math.max(DashMetrics.panelFloorRowsFor(root.activeTabId), contentRows)
            readonly property bool panelAtDefault: panelColumns === DashMetrics.defaultGridColumns && panelRows === DashMetrics.defaultPanelRows(root.activeTabId, contentRows)
            readonly property DankPanelResizer panelResizer: DankPanelResizer {
                popout: root
                stepWidth: DashMetrics.preferredColumnWidth + DashMetrics.gridGap
                widthFor: columns => root.panelWidthFor(columns)
                currentStep: () => mainContainer.panelColumns
                currentRows: () => mainContainer.panelRows
                minStep: Math.max(DashMetrics.minimumGridColumns, pages.currentItem?.usedColumns ?? 0)
                maxStep: root.columnCap
                rowUnit: DashMetrics.gridRowUnit + DashMetrics.gridGap
                minRows: mainContainer.contentRows
                maxRows: Math.min(pages.rowBudget, DashMetrics.maximumGridRows)
                onPreview: (columns, rows) => DashMetrics.panelPreview = {
                        "id": root.activeTabId,
                        "columns": columns,
                        "rows": rows
                    }
                onCommitted: (columns, rows, columnsChanged, rowsChanged) => {
                    const values = {};
                    if (columnsChanged)
                        values.panelColumns = columns;
                    if (rowsChanged)
                        values.panelRows = DashMetrics.panelRowsToStore(root.activeTabId, rows, mainContainer.contentRows);
                    DashRegistry.setOptions(root.activeTabId, values);
                    DashMetrics.panelPreview = null;
                }
                onCanceled: DashMetrics.panelPreview = null
            }

            function headerFocusTargets() {
                const targets = root.editMode ? pageActions.focusTargets : [backButton, tabBar, pageTitle.focusTarget];
                return targets.filter(item => item.visible && item.enabled);
            }

            function focusNavigation(backwards) {
                const targets = headerFocusTargets();
                const target = backwards ? targets[targets.length - 1] : targets[0];
                target?.forceActiveFocus(backwards ? Qt.BacktabFocusReason : Qt.TabFocusReason);
            }

            function focusInitial() {
                if (root.activeTabId === "") {
                    emptySettings.forceActiveFocus(Qt.OtherFocusReason);
                    return;
                }
                for (const target of [backButton, tabBar, pageTitle.focusTarget])
                    target.focus = false;
                pageActions.clearFocus();
                if (pages.currentHost)
                    pages.currentHost.focus = false;
                mainContainer.forceActiveFocus(Qt.OtherFocusReason);
                if (!root.editMode)
                    pages.currentItem?.restoreFocus?.();
            }

            function contentEntryFor(key) {
                switch (key) {
                case Qt.Key_Down:
                case Qt.Key_Right:
                    return "forwards";
                case Qt.Key_Up:
                case Qt.Key_Left:
                    return "backwards";
                }
                return "";
            }

            function enterContent(backwards) {
                const target = backwards ? (pages.currentItem?.previousFocusTarget ?? pages.focusTarget) : pages.focusTarget;
                FocusNavigation.focusItem(target, backwards);
            }

            function cycleRegion(backwards) {
                if (pages.currentHost?.activeFocus) {
                    if (pages.currentItem?.cycleFocus?.(backwards) === true)
                        return;
                    focusNavigation(backwards);
                    return;
                }
                const targets = headerFocusTargets();
                const inHeader = targets.some(FocusNavigation.containsFocus);
                if (inHeader && FocusNavigation.moveFocus(targets, backwards))
                    return;
                if (inHeader && pages.currentItem?.cycleFocus?.(backwards) === true)
                    return;
                enterContent(backwards);
            }

            function resetScroll() {
                pages.contentY = 0;
            }

            function revealFocusedItem() {
                const item = mainContainer.windowFocusItem;
                if (!item)
                    return;
                let ancestor = item;
                while (ancestor && ancestor !== pages.contentItem)
                    ancestor = ancestor.parent;
                if (!ancestor)
                    return;
                const point = item.mapToItem(pages.contentItem, 0, 0);
                let target = pages.contentY;
                if (point.y < target)
                    target = point.y;
                else if (point.y + item.height > target + pages.height)
                    target = Math.min(point.y, point.y + item.height - pages.height);
                pages.contentY = Math.max(0, Math.min(target, pages.contentHeight - pages.height));
            }

            readonly property Item windowFocusItem: Window.activeFocusItem
            onWindowFocusItemChanged: revealFocusedItem()

            function dismissOptions() {
                tabOptions.dismiss();
                pageActions.closeMenu();
            }

            Component.onCompleted: {
                if (root.shouldBeVisible)
                    focusInitial();
            }

            readonly property bool rootShouldBeVisible: root.shouldBeVisible

            onRootShouldBeVisibleChanged: {
                if (!rootShouldBeVisible)
                    return;
                focusInitial();
            }

            Keys.onPressed: function (event) {
                if (pageActions.menuOpen)
                    return;
                if (tabOptions.shown) {
                    if (event.key !== Qt.Key_Escape)
                        return;
                    tabOptions.dismiss();
                    event.accepted = true;
                    return;
                }

                const current = pages.currentItem;
                if (current && typeof current.handleKeyEvent === "function" && current.handleKeyEvent(event) === true) {
                    event.accepted = true;
                    return;
                }

                const entry = contentEntryFor(event.key);
                if (entry !== "" && !pages.currentHost?.activeFocus) {
                    enterContent(entry === "backwards");
                    event.accepted = true;
                    return;
                }

                if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                    if (root.editMode) {
                        mainContainer.focusNavigation(event.key === Qt.Key_Backtab || !!(event.modifiers & Qt.ShiftModifier));
                        event.accepted = true;
                        return;
                    }
                    if (current?.blocksTabNavigation)
                        return;
                    root.cycleTab(event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1);
                    event.accepted = true;
                    return;
                }
                if (event.key !== Qt.Key_Escape)
                    return;
                if (root.editMode) {
                    root.editMode = false;
                    event.accepted = true;
                    return;
                }
                if (root.detailTabId !== "") {
                    root.closeDetail();
                    event.accepted = true;
                    return;
                }
                root.dashVisible = false;
                event.accepted = true;
            }

            Shortcut {
                sequence: "Tab"
                enabled: root.shouldBeVisible && !tabOptions.shown && !pageActions.menuOpen && !root.editMode && !pages.currentItem?.blocksTabNavigation
                context: Qt.WindowShortcut
                onActivated: {
                    root.cycleTab(1);
                    mainContainer.focusInitial();
                }
            }

            Shortcut {
                sequence: "Shift+Tab"
                enabled: root.shouldBeVisible && !tabOptions.shown && !pageActions.menuOpen && !root.editMode && !pages.currentItem?.blocksTabNavigation
                context: Qt.WindowShortcut
                onActivated: {
                    root.cycleTab(-1);
                    mainContainer.focusInitial();
                }
            }

            Shortcut {
                sequence: "Ctrl+Tab"
                enabled: root.shouldBeVisible && !tabOptions.shown && !pageActions.menuOpen
                context: Qt.WindowShortcut
                onActivated: {
                    root.cycleTab(1);
                    mainContainer.focusInitial();
                }
            }

            Shortcut {
                sequence: "Ctrl+Shift+Tab"
                enabled: root.shouldBeVisible && !tabOptions.shown && !pageActions.menuOpen
                context: Qt.WindowShortcut
                onActivated: {
                    root.cycleTab(-1);
                    mainContainer.focusInitial();
                }
            }

            Shortcut {
                sequences: ["F2", "Ctrl+E"]
                enabled: root.shouldBeVisible && root.activeTabId !== "" && !root.editMode && !tabOptions.shown && !pageActions.menuOpen && !pages.currentItem?.blocksTabNavigation
                context: Qt.WindowShortcut
                onActivated: root.editMode = true
            }

            Shortcut {
                sequence: "F6"
                enabled: root.shouldBeVisible && !tabOptions.shown && !pageActions.menuOpen && !root.editMode && !pages.currentItem?.blocksTabNavigation
                context: Qt.WindowShortcut
                onActivated: mainContainer.cycleRegion(false)
            }

            Shortcut {
                sequence: "Shift+F6"
                enabled: root.shouldBeVisible && !tabOptions.shown && !pageActions.menuOpen && !root.editMode && !pages.currentItem?.blocksTabNavigation
                context: Qt.WindowShortcut
                onActivated: mainContainer.cycleRegion(true)
            }

            Shortcut {
                sequence: "Alt+Tab"
                enabled: root.shouldBeVisible && !tabOptions.shown && !pageActions.menuOpen && !root.editMode && !pages.currentItem?.blocksTabNavigation
                context: Qt.WindowShortcut
                onActivated: pages.currentItem?.cycleCardFocus?.(false)
            }

            Shortcut {
                sequence: "Alt+Shift+Tab"
                enabled: root.shouldBeVisible && !tabOptions.shown && !pageActions.menuOpen && !root.editMode && !pages.currentItem?.blocksTabNavigation
                context: Qt.WindowShortcut
                onActivated: pages.currentItem?.cycleCardFocus?.(true)
            }

            Shortcut {
                sequences: ["Alt+Left", "Alt+H"]
                enabled: root.shouldBeVisible && !tabOptions.shown && !pageActions.menuOpen && !root.editMode && !pages.currentItem?.blocksTabNavigation
                context: Qt.WindowShortcut
                onActivated: pages.currentItem?.moveCardFocus?.("left")
            }

            Shortcut {
                sequences: ["Alt+Right", "Alt+L"]
                enabled: root.shouldBeVisible && !tabOptions.shown && !pageActions.menuOpen && !root.editMode && !pages.currentItem?.blocksTabNavigation
                context: Qt.WindowShortcut
                onActivated: pages.currentItem?.moveCardFocus?.("right")
            }

            Shortcut {
                sequences: ["Alt+Up", "Alt+K"]
                enabled: root.shouldBeVisible && !tabOptions.shown && !pageActions.menuOpen && !root.editMode && !pages.currentItem?.blocksTabNavigation
                context: Qt.WindowShortcut
                onActivated: pages.currentItem?.moveCardFocus?.("up")
            }

            Shortcut {
                sequences: ["Alt+Down", "Alt+J"]
                enabled: root.shouldBeVisible && !tabOptions.shown && !pageActions.menuOpen && !root.editMode && !pages.currentItem?.blocksTabNavigation
                context: Qt.WindowShortcut
                onActivated: pages.currentItem?.moveCardFocus?.("down")
            }

            DashOptionsSheet {
                id: tabOptions
                onDismissed: mainContainer.focusInitial()
            }

            DankGridEditChrome {
                id: panelChrome

                anchors.fill: parent
                anchors.margins: -(contentInset + Theme.spacingS)
                z: 2
                visible: root.editMode
                edgeResize: mainContainer.panelResizing || mainContainer.panelResizer.sideMovable(-1, mainContainer.panelColumns)
                cornerResize: mainContainer.panelResizing || mainContainer.panelResizer.sideMovable(1, mainContainer.panelColumns)
                removable: false
                cornerRadius: Theme.windowRadius + Theme.spacingS
                handleOverhang: contentInset
                buttonSize: PopoutMetrics.chromeButtonSize
                iconSize: PopoutMetrics.chromeIconSize
                resizing: mainContainer.panelResizing || mainContainer.panelShifted
                atDefault: mainContainer.panelAtDefault
                sizeText: mainContainer.panelColumns + "×" + mainContainer.panelRows
                onResizeStarted: (px, py, signX) => mainContainer.panelResizer.begin(px, py, signX)
                onResizeMoved: (px, py) => mainContainer.panelResizer.move(px, py)
                onResizeEnded: mainContainer.panelResizer.end()
                onResizeCanceled: mainContainer.panelResizer.cancel()
            }

            Item {
                id: contentClip

                anchors.fill: parent
                clip: mainContainer.width < Theme.px(mainContainer.implicitWidth, root.dpr) || mainContainer.height < Theme.px(mainContainer.implicitHeight, root.dpr)

                Item {
                    id: contentColumn

                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.topMargin: DashMetrics.contentPadding
                    anchors.leftMargin: DashMetrics.contentPadding
                    anchors.bottomMargin: DashMetrics.contentPadding
                    width: root.popupWidth - DashMetrics.contentPadding * 2
                    LayoutMirroring.enabled: false
                    LayoutMirroring.childrenInherit: true

                    Item {
                        id: headerRow
                        enabled: !tabOptions.shown && !pageActions.menuOpen

                        x: root.verticalNavigation && root.navigationEdge === SettingsData.Right ? parent.width - width : 0
                        y: !root.verticalNavigation && root.navigationEdge === SettingsData.Bottom ? parent.height - height : 0
                        width: root.verticalNavigation ? Theme.navigationRailWidth : parent.width
                        height: root.verticalNavigation ? parent.height : mainContainer.horizontalChromeHeight - DashMetrics.contentGap

                        DankNavigationBar {
                            id: tabBar

                            width: parent.width
                            height: parent.height
                            editable: true
                            evenlySpaced: SettingsData.dashTabsEvenlySpaced
                            onEditRequested: root.editMode = true
                            visible: root.showTabs && !root.editMode
                            orientation: root.verticalNavigation ? Qt.Vertical : Qt.Horizontal
                            currentIndex: root.currentTabIndex
                            nextFocusTarget: pageActions.focusTargets[0] ?? pages.focusTarget
                            previousFocusTarget: pages.currentItem?.previousFocusTarget ?? pages.focusTarget
                            model: DashRegistry.tabBarModel
                            onActivated: index => {
                                const id = root.orderedTabIds[index];
                                if (id !== undefined)
                                    root.currentTabId = id;
                            }
                        }

                        DankActionButton {
                            id: backButton
                            x: I18n.isRtl ? parent.width - width : 0
                            anchors.verticalCenter: parent.verticalCenter
                            buttonSize: Theme.buttonHeightS
                            iconName: I18n.isRtl ? "arrow_forward" : "arrow_back"
                            tooltipText: I18n.tr("Back")
                            visible: root.showBack && !root.editMode
                            onClicked: root.closeDetail()
                        }

                        DashPageTitle {
                            id: pageTitle
                            readonly property real backWidth: root.showBack ? backButton.width + Theme.spacingS : 0
                            x: I18n.isRtl ? 0 : backWidth
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(0, parent.width - backWidth)
                            height: implicitHeight
                            entryId: root.activeTabId
                            visible: !root.showTabs && !root.editMode
                            onEditRequested: root.editMode = true
                        }

                        DashPageActions {
                            id: pageActions
                            x: root.verticalNavigation ? 0 : (parent.width - width) / 2
                            y: (parent.height - height) / 2
                            width: Math.min(parent.width, implicitWidth)
                            height: Math.min(parent.height, implicitHeight)
                            visible: root.editMode
                            vertical: root.verticalNavigation
                            overlayParent: mainContainer
                            entryId: root.activeTabId
                            tabItem: pages.currentItem
                            editMode: root.editMode
                            panelResizable: true
                            onOptionsRequested: tabOptions.presentFor(root.activeTabId)
                            onFinished: root.editMode = false
                        }
                    }

                    DankFlickable {
                        id: pages
                        enabled: !tabOptions.shown && !pageActions.menuOpen

                        property var currentHost: null
                        property real settledHeight: DashMetrics.tabDefaultHeight
                        readonly property var currentItem: root.activeTabId !== "" ? currentHost?.item ?? null : null
                        readonly property Item focusTarget: root.activeTabId === "" ? emptySettings : currentHost?.focusTarget ?? null
                        readonly property bool currentSettled: !!currentHost && (!!currentHost.item || currentHost.failed)
                        readonly property real currentHostImplicitHeight: currentHost?.implicitHeight ?? 0
                        readonly property real targetHeight: root.activeTabId === "" ? emptyContent.implicitHeight : currentSettled && currentHost.isCurrent ? DashMetrics.panelHeightFor(root.activeTabId, currentHostImplicitHeight) : -1
                        readonly property real bodyHeight: root.activeTabId === "" ? emptyContent.implicitHeight : Math.max(settledHeight, currentHostImplicitHeight)
                        readonly property bool ready: targetHeight >= 0 && settledHeight === targetHeight
                        readonly property real availableHeight: root.screen ? root.screen.height - mainContainer.horizontalChromeHeight - DashMetrics.contentPadding * 2 - Theme.barHeight - Theme.spacingL * 2 : contentHeight
                        readonly property int rowBudget: DashMetrics.rowCapFor(availableHeight)

                        x: (root.verticalNavigation && root.navigationEdge === SettingsData.Left ? root.navigationWidth : 0) - root.editGutter
                        y: (!root.verticalNavigation && root.navigationEdge !== SettingsData.Bottom ? mainContainer.horizontalChromeHeight : 0) - root.editGutter
                        width: parent.width - root.navigationWidth + root.editGutter * 2
                        height: Math.max(0, mainContainer.height - mainContainer.horizontalChromeHeight - DashMetrics.contentPadding * 2) + root.editGutter * 2
                        implicitHeight: Math.min(settledHeight, Math.max(DashMetrics.gridRowUnit, availableHeight))
                        contentWidth: width
                        contentHeight: bodyHeight + root.editGutter * 2
                        clip: contentHeight > height

                        function updateContentHeight() {
                            if (targetHeight < 0)
                                return;
                            settledHeight = targetHeight;
                        }

                        onTargetHeightChanged: Qt.callLater(updateContentHeight)

                        Column {
                            id: emptyContent
                            width: parent.width
                            spacing: Theme.spacingM
                            visible: root.activeTabId === ""

                            CcEmptyState {
                                iconName: "dashboard"
                                title: I18n.tr("No tabs enabled", "Dashboard empty state when all navigation tabs are hidden")
                            }

                            DankButton {
                                id: emptySettings
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: I18n.tr("Settings")
                                iconName: "settings"
                                onClicked: {
                                    root.dashVisible = false;
                                    root.instantClose();
                                    PopoutService.openSettingsWithTab("dank_dash");
                                }
                            }
                        }

                        Repeater {
                            model: ScriptModel {
                                values: DashRegistry.tabIds
                            }

                            DashTabHost {
                                id: host

                                required property string modelData

                                width: pages.width
                                height: pages.height + Math.max(0, pages.bodyHeight - pages.implicitHeight)
                                contentPadding: root.editGutter
                                entry: DashRegistry.entry(modelData)
                                dashHost: root
                                rowBudget: pages.rowBudget
                                keyForwardTarget: mainContainer
                                contentViewport: pages
                                isCurrent: root.activeTabId === modelData

                                onIsCurrentChanged: {
                                    if (isCurrent) {
                                        pages.currentHost = host;
                                        return;
                                    }
                                    if (pages.currentHost === host)
                                        pages.currentHost = null;
                                }

                                Component.onCompleted: {
                                    if (isCurrent)
                                        pages.currentHost = host;
                                }

                                Component.onDestruction: {
                                    if (pages.currentHost === host)
                                        pages.currentHost = null;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
