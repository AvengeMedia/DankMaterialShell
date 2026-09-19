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
    surfaceFillsScreen: editMode
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
    property string currentTabId: DashRegistry.fallbackId
    property string detailTabId: ""
    property bool editMode: false
    property string overviewFocusId: CacheData.dashFocusCardId || "calendar"

    onEditModeChanged: {
        if (!editMode)
            contentLoader.item?.panelResizer.cancel();
        if (!shouldBeVisible)
            return;
        Qt.callLater(() => {
            if (editMode) {
                contentLoader.item?.focusNavigation();
                return;
            }
            contentLoader.item?.focusInitial();
        });
    }

    readonly property string activeTabId: detailTabId !== "" ? detailTabId : currentTabId
    readonly property var detailEntry: detailTabId !== "" ? DashRegistry.entry(detailTabId) : null
    readonly property var orderedTabIds: DashRegistry.visibleTabIds
    readonly property int currentTabIndex: orderedTabIds.indexOf(currentTabId)
    readonly property bool showTabs: orderedTabIds.length > 0 && currentTabIndex >= 0

    readonly property int columnCap: DashMetrics.columnCapFor(screen?.width, SettingsData.showWeekNumber)
    readonly property real editGutter: editMode ? PopoutMetrics.editOverflow : 0

    popupWidth: DashMetrics.widthFor(SettingsData.showWeekNumber, screen?.width, DashMetrics.panelColumnsFor(activeTabId))
    minimumSurfaceWidth: DashMetrics.widthFor(SettingsData.showWeekNumber, screen?.width, DashRegistry.widestPanelColumns)
    popupHeight: contentLoader.item?.implicitHeight ?? (DashMetrics.tabMinHeight + DashMetrics.tabBarBlockHeight + DashMetrics.contentGap + DashMetrics.contentPadding * 2)
    triggerWidth: DashMetrics.triggerWidth
    screen: triggerScreen

    property bool __focusArmed: false

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
        currentTabId = DashRegistry.fallbackId;
    }

    function closeDetail() {
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
        contentLoader.item?.focusInitial();
    }

    onActiveTabIdChanged: {
        editMode = false;
        contentLoader.item?.dismissOptions();
        contentLoader.item?.resetScroll();
        if (shouldBeVisible)
            contentLoader.item?.focusInitial();
    }

    readonly property var registryVisibleTabIds: DashRegistry.visibleTabIds
    readonly property var registryTabIds: DashRegistry.tabIds

    onRegistryVisibleTabIdsChanged: {
        if (!DashRegistry.isSelectable(currentTabId))
            currentTabId = DashRegistry.fallbackId;
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
            implicitHeight: headerRow.height + DashMetrics.contentGap + pages.implicitHeight + DashMetrics.contentPadding * 2
            readonly property bool ready: pages.ready
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
            readonly property bool hasWidgets: headerMenu.hasWidgets
            readonly property int panelColumns: DashMetrics.panelColumnsFor(root.activeTabId)
            readonly property int contentRows: DashMetrics.rowsForHeight(pages.currentHostImplicitHeight)
            readonly property int panelRows: Math.max(DashMetrics.panelFloorRowsFor(root.activeTabId), contentRows)
            readonly property bool panelAtDefault: panelColumns === DashMetrics.defaultGridColumns && DashMetrics.panelFloorRowsFor(root.activeTabId) <= contentRows
            readonly property DankPanelResizer panelResizer: DankPanelResizer {
                popout: root
                stepWidth: DashMetrics.preferredColumnWidth + DashMetrics.gridGap
                widthFor: columns => DashMetrics.widthFor(SettingsData.showWeekNumber, root.screen?.width, columns)
                currentStep: () => mainContainer.panelColumns
                currentRows: () => mainContainer.panelRows
                minStep: DashMetrics.minimumGridColumns
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
                        values.panelRows = rows > mainContainer.contentRows ? rows : DashMetrics.minimumTabRows;
                    DashRegistry.setOptions(root.activeTabId, values);
                    DashMetrics.panelPreview = null;
                }
                onCanceled: DashMetrics.panelPreview = null
            }

            function headerFocusTargets() {
                const targets = root.editMode ? editControls.focusTargets : [root.detailTabId !== "" ? backButton : tabBar, menuButton];
                return targets.filter(item => item.visible && item.enabled);
            }

            function focusNavigation(backwards) {
                const targets = headerFocusTargets();
                const target = backwards ? targets[targets.length - 1] : targets[0];
                target?.forceActiveFocus(backwards ? Qt.BacktabFocusReason : Qt.TabFocusReason);
            }

            function focusInitial() {
                for (const target of headerFocusTargets())
                    target.focus = false;
                if (pages.currentHost)
                    pages.currentHost.focus = false;
                mainContainer.forceActiveFocus(Qt.OtherFocusReason);
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
                headerMenu.close();
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
                if (headerMenu.open)
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
                enabled: root.shouldBeVisible && !tabOptions.shown && !headerMenu.open && !root.editMode && !pages.currentItem?.blocksTabNavigation
                context: Qt.WindowShortcut
                onActivated: {
                    root.cycleTab(1);
                    mainContainer.focusInitial();
                }
            }

            Shortcut {
                sequence: "Shift+Tab"
                enabled: root.shouldBeVisible && !tabOptions.shown && !headerMenu.open && !root.editMode && !pages.currentItem?.blocksTabNavigation
                context: Qt.WindowShortcut
                onActivated: {
                    root.cycleTab(-1);
                    mainContainer.focusInitial();
                }
            }

            Shortcut {
                sequence: "Ctrl+Tab"
                enabled: root.shouldBeVisible && !tabOptions.shown && !headerMenu.open
                context: Qt.WindowShortcut
                onActivated: {
                    root.cycleTab(1);
                    mainContainer.focusInitial();
                }
            }

            Shortcut {
                sequence: "Ctrl+Shift+Tab"
                enabled: root.shouldBeVisible && !tabOptions.shown && !headerMenu.open
                context: Qt.WindowShortcut
                onActivated: {
                    root.cycleTab(-1);
                    mainContainer.focusInitial();
                }
            }

            Shortcut {
                sequence: "F6"
                enabled: root.shouldBeVisible && !tabOptions.shown && !headerMenu.open && !root.editMode && !pages.currentItem?.blocksTabNavigation
                context: Qt.WindowShortcut
                onActivated: mainContainer.cycleRegion(false)
            }

            Shortcut {
                sequence: "Shift+F6"
                enabled: root.shouldBeVisible && !tabOptions.shown && !headerMenu.open && !root.editMode && !pages.currentItem?.blocksTabNavigation
                context: Qt.WindowShortcut
                onActivated: mainContainer.cycleRegion(true)
            }

            Shortcut {
                sequence: "Alt+Tab"
                enabled: root.shouldBeVisible && !tabOptions.shown && !headerMenu.open && !root.editMode && !pages.currentItem?.blocksTabNavigation
                context: Qt.WindowShortcut
                onActivated: pages.currentItem?.cycleCardFocus?.(false)
            }

            Shortcut {
                sequence: "Alt+Shift+Tab"
                enabled: root.shouldBeVisible && !tabOptions.shown && !headerMenu.open && !root.editMode && !pages.currentItem?.blocksTabNavigation
                context: Qt.WindowShortcut
                onActivated: pages.currentItem?.cycleCardFocus?.(true)
            }

            Shortcut {
                sequences: ["Alt+Left", "Alt+H"]
                enabled: root.shouldBeVisible && !tabOptions.shown && !headerMenu.open && !root.editMode && !pages.currentItem?.blocksTabNavigation
                context: Qt.WindowShortcut
                onActivated: pages.currentItem?.moveCardFocus?.("left")
            }

            Shortcut {
                sequences: ["Alt+Right", "Alt+L"]
                enabled: root.shouldBeVisible && !tabOptions.shown && !headerMenu.open && !root.editMode && !pages.currentItem?.blocksTabNavigation
                context: Qt.WindowShortcut
                onActivated: pages.currentItem?.moveCardFocus?.("right")
            }

            Shortcut {
                sequences: ["Alt+Up", "Alt+K"]
                enabled: root.shouldBeVisible && !tabOptions.shown && !headerMenu.open && !root.editMode && !pages.currentItem?.blocksTabNavigation
                context: Qt.WindowShortcut
                onActivated: pages.currentItem?.moveCardFocus?.("up")
            }

            Shortcut {
                sequences: ["Alt+Down", "Alt+J"]
                enabled: root.shouldBeVisible && !tabOptions.shown && !headerMenu.open && !root.editMode && !pages.currentItem?.blocksTabNavigation
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
                edgeResize: true
                removable: false
                cornerRadius: Theme.windowRadius + Theme.spacingS
                handleOverhang: contentInset + Theme.spacingL
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

            DashPageMenu {
                id: headerMenu
                entryId: root.activeTabId
                tabItem: pages.currentItem
                editMode: root.editMode
                panelResizable: true
                onEditRequested: root.editMode = true
                onOptionsRequested: tabOptions.presentFor(root.activeTabId)
                onSettingsRequested: {
                    root.dashVisible = false;
                    root.instantClose();
                    PopoutService.openSettingsWithTab("dank_dash");
                }
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

                    Item {
                        id: headerRow

                        readonly property real stripCenter: (tabBar.y + tabBar.height - Theme.dividerWidth - DashMetrics.contentPadding) / 2

                        width: parent.width
                        height: root.showTabs ? Math.max(DashMetrics.tabBarBlockHeight, tabBar.y + tabBar.height) : 0
                        visible: root.showTabs

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: -DashMetrics.contentPadding
                            anchors.rightMargin: -DashMetrics.contentPadding
                            y: tabBar.y + tabBar.height - height
                            height: Theme.dividerWidth
                            color: Theme.outlineVariant
                            visible: tabBar.visible
                        }

                        DankTabBar {
                            id: tabBar

                            anchors.left: parent.left
                            anchors.right: menuButton.left
                            anchors.rightMargin: Theme.spacingS
                            y: -DashMetrics.tabBarLift
                            visible: !root.editMode && root.detailTabId === ""
                            tabHeight: DashMetrics.tabHeight
                            showDivider: false
                            currentIndex: root.currentTabIndex
                            spacing: Theme.spacingS
                            equalWidthTabs: true
                            enableArrowNavigation: false
                            cycleOnTab: true
                            nextFocusTarget: pages.focusTarget
                            previousFocusTarget: pages.currentItem?.previousFocusTarget ?? pages.focusTarget
                            model: DashRegistry.tabBarModel

                            onTabClicked: function (index) {
                                const id = root.orderedTabIds[index];
                                if (id !== undefined)
                                    root.currentTabId = id;
                            }
                        }

                        DashEditControls {
                            id: editControls
                            anchors.left: parent.left
                            anchors.right: parent.right
                            y: Math.round(headerRow.stripCenter - height / 2)
                            visible: root.editMode
                            canAdd: (pages.currentItem?.addable?.length ?? 0) > 0
                            hasWidgets: mainContainer.hasWidgets
                            title: mainContainer.hasWidgets ? I18n.tr("Widgets") : (DashRegistry.entry(root.activeTabId)?.text ?? "")
                            onAddRequested: anchor => pages.currentItem?.openAddMenu(anchor)
                            onMenuRequested: anchor => headerMenu.openAt(anchor)
                            onFinished: root.editMode = false
                        }

                        Item {
                            id: detailHeader

                            anchors.left: parent.left
                            anchors.right: parent.right
                            y: Math.round(headerRow.stripCenter - height / 2)
                            height: DashMetrics.headerActionSize
                            visible: root.detailTabId !== "" && !root.editMode

                            DankActionButton {
                                id: backButton
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                buttonSize: DashMetrics.headerActionSize
                                iconName: I18n.isRtl ? "arrow_forward" : "arrow_back"
                                Accessible.name: I18n.tr("Back")
                                KeyNavigation.tab: pages.focusTarget
                                KeyNavigation.backtab: pages.focusTarget
                                onClicked: root.closeDetail()
                            }

                            StyledText {
                                anchors.left: backButton.right
                                anchors.right: parent.right
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: DashMetrics.headerActionSize + Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.detailEntry?.text ?? ""
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Theme.fontWeightMedium
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                            }
                        }

                        DankActionButton {
                            id: menuButton

                            anchors.right: parent.right
                            y: Math.round(headerRow.stripCenter - height / 2)
                            buttonSize: DashMetrics.headerActionSize
                            iconName: "more_vert"
                            iconColor: headerMenu.open ? Theme.primary : Theme.onSurfaceVariant
                            backgroundColor: headerMenu.open ? Theme.withAlpha(Theme.primary, Theme.stateLayerFocus) : "transparent"
                            Accessible.name: I18n.tr("Options")
                            visible: !root.editMode
                            KeyNavigation.tab: pages.focusTarget
                            KeyNavigation.backtab: root.detailTabId !== "" ? backButton : tabBar
                            onClicked: headerMenu.openAt(menuButton)
                        }
                    }

                    DankFlickable {
                        id: pages

                        property var currentHost: null
                        property real settledHeight: DashMetrics.tabMinHeight
                        readonly property var currentItem: currentHost?.item ?? null
                        readonly property Item focusTarget: currentHost?.focusTarget ?? null
                        readonly property bool currentSettled: !!currentHost && (!!currentHost.item || currentHost.failed)
                        readonly property real currentHostImplicitHeight: currentHost?.implicitHeight ?? 0
                        readonly property real targetHeight: currentSettled && currentHost.isCurrent ? DashMetrics.panelHeightFor(root.activeTabId, currentHostImplicitHeight) : -1
                        readonly property real bodyHeight: Math.max(settledHeight, currentHostImplicitHeight)
                        readonly property bool ready: targetHeight >= 0 && settledHeight === targetHeight
                        readonly property real availableHeight: root.screen ? root.screen.height - headerRow.height - DashMetrics.contentGap - DashMetrics.contentPadding * 2 - Theme.barHeight - Theme.spacingL * 2 : contentHeight
                        readonly property int rowBudget: DashMetrics.rowCapFor(availableHeight)

                        x: -root.editGutter
                        y: (headerRow.visible ? headerRow.height + DashMetrics.contentGap : 0) - root.editGutter
                        width: parent.width + root.editGutter * 2
                        height: Math.max(0, mainContainer.height - headerRow.height - DashMetrics.contentGap - DashMetrics.contentPadding * 2) + root.editGutter * 2
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
                                    if (isCurrent)
                                        pages.currentHost = host;
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
