import QtQuick
import QtTest
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Modals.Settings
import qs.DankCommon.Common as DC
import qs.Modules.Settings.Widgets
import qs.Widgets

ShellRoot {
    id: root

    property bool failed: false
    property int sidebarRequests: 0
    property string sidebarRequestedPage: ""

    function find(item, predicate) {
        if (!item)
            return null;
        if (predicate(item))
            return item;
        for (const child of item.children ?? []) {
            const found = find(child, predicate);
            if (found)
                return found;
        }
        return null;
    }

    function inside(ancestor, item) {
        for (let p = item; p; p = p.parent) {
            if (p === ancestor)
                return true;
        }
        return false;
    }

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    function waitFor(condition, label) {
        try {
            input.tryVerify(condition, 20000);
        } catch (error) {
            throw new Error("timed out: " + label);
        }
    }

    QtObject {
        id: modal
        property bool shouldBeVisible: true
        property bool isCompactMode: false
        property bool menuVisible: true
        property bool canGoBack: false
        readonly property bool searchFocused: sidebar.searchFocused
        readonly property string focusPane: navigation.activePane
        readonly property Item modalFocusScope: navigation
        property var pageHistory: []
        property int backs: 0
        property int searches: 0
        property int pageFocuses: 0
        function goBack() {
            backs++;
        }
        function focusSearch() {
            searches++;
            navigation.focusSearch();
        }
        function focusSidebar() {
            searches++;
            navigation.focusSidebar();
        }
        function focusCurrentPage() {
            pageFocuses++;
            navigation.focusContent();
        }
        function toggleMenu() {
        }
    }

    PanelWindow {
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        implicitWidth: 900
        implicitHeight: 700

        TestCase {
            id: input
            name: "settings-keyboard"
            when: false
        }

        SettingsPaneNavigation {
            id: navigation
            anchors.fill: parent
            sidebar: sidebar
            content: content
            parentModal: modal

            SettingsSidebar {
                id: sidebar
                width: 300
                height: parent.height
                parentModal: modal
                onPageRequested: pageId => {
                    root.sidebarRequests++;
                    root.sidebarRequestedPage = pageId;
                }
            }

            SettingsContent {
                id: content
                anchors.left: sidebar.right
                anchors.right: parent.right
                height: parent.height
                parentModal: modal
            }
        }
    }

    function run() {
        waitFor(() => CompositorService.compositor !== "unknown", "compositor detected");
        waitFor(() => content.Window.active, "settings window takes keyboard focus");
        SettingsData.animationDuration = 0;
        content.currentPage = "notifications";
        waitFor(() => find(content.currentPageItem, item => item.upDownKeysStep !== undefined && item.visible) !== null, "notifications page loads");
        const page = content.currentPageItem;
        const focused = () => content.Window.activeFocusItem;

        page.forceActiveFocus();
        const before = focused();
        input.keyClick(Qt.Key_Down);
        const first = focused();
        check(first !== before && inside(page, first), "Down moves focus to a control on the page");
        input.keyClick(Qt.Key_Down);
        const second = focused();
        check(second !== first && inside(page, second), "Down moves to the next control");
        input.keyClick(Qt.Key_Up);
        check(focused() === first, "Up returns to the previous control");

        const slider = find(page, item => item.upDownKeysStep === false && item.visible && item.enabled);
        slider.forceActiveFocus(Qt.TabFocusReason);
        const value = slider.value;
        input.keyClick(Qt.Key_Down);
        check(slider.value === value && !inside(slider, focused()), "Down leaves a settings slider without stepping it");

        const dropdown = find(page, item => item.downKeyOpens === false && item.visible && item.enabled);
        dropdown.forceActiveFocus(Qt.TabFocusReason);
        input.keyClick(Qt.Key_Down);
        check(!dropdown.menuOpen && !inside(dropdown, focused()), "Down leaves a settings dropdown without opening it");

        page.forceActiveFocus();
        input.keyClick(Qt.Key_Escape);
        check(modal.searches === 1 && modal.backs === 0, "Escape on a top-level page returns to the sidebar");
        modal.canGoBack = true;
        page.forceActiveFocus();
        input.keyClick(Qt.Key_Escape);
        input.keyClick(Qt.Key_Left, Qt.AltModifier);
        check(modal.backs === 2, "Escape and Alt+Left go back from a sub-page");

        SettingsData.desktopWidgetInstances = [
            {
                id: "a",
                widgetType: "desktopClock",
                name: "A",
                enabled: true
            },
            {
                id: "b",
                widgetType: "desktopClock",
                name: "B",
                enabled: true
            }
        ];
        content.currentPage = "desktop_widgets";
        const isHandle = item => item.upDownKeysMove === false && item.visible && item.enabled;
        waitFor(() => find(content.currentPageItem, isHandle) !== null, "desktop widgets page shows reorder handles");
        const handle = find(content.currentPageItem, isHandle);
        handle.forceActiveFocus(Qt.TabFocusReason);
        input.keyClick(Qt.Key_Down);
        check(SettingsData.desktopWidgetInstances[0].id === "a" && !handle.activeFocus, "Down leaves a reorder handle without moving its item");

        const deleteButton = find(content.currentPageItem, item => item.confirming !== undefined && item.visible);
        deleteButton.forceActiveFocus(Qt.TabFocusReason);
        input.keyClick(Qt.Key_Space);
        check(deleteButton.confirming && SettingsData.desktopWidgetInstances.length === 2, "first Space only arms the delete button");
        input.keyClick(Qt.Key_Tab);
        check(!deleteButton.confirming, "leaving an armed delete button disarms it");
        deleteButton.forceActiveFocus(Qt.TabFocusReason);
        input.keyClick(Qt.Key_Space);
        input.keyClick(Qt.Key_Space);
        check(SettingsData.desktopWidgetInstances.length === 1, "second Space deletes exactly once");

        SettingsData.desktopWidgetGroups = [
            {
                id: "g",
                name: "Group"
            }
        ];
        const isRename = item => item.iconName === "edit" && item.tooltipText === "Rename" && item.visible;
        waitFor(() => find(content.currentPageItem, isRename) !== null, "desktop widgets page shows the group rename button");
        const renameButton = find(content.currentPageItem, isRename);
        renameButton.forceActiveFocus(Qt.TabFocusReason);
        renameButton.clicked();
        waitFor(() => focused() !== renameButton && focused()?.cursorPosition !== undefined, "rename dialog focuses its field");
        const dialogField = focused();
        let renameDialog = dialogField;
        while (renameDialog && renameDialog.Accessible.role !== Accessible.Dialog)
            renameDialog = renameDialog.parent;
        input.keyClick(Qt.Key_Tab, Qt.ControlModifier);
        check(inside(renameDialog, focused()), "pane shortcut stays inside the rename dialog");
        input.keyClick(Qt.Key_F, Qt.ControlModifier);
        check(inside(renameDialog, focused()), "Search shortcut does not leave the rename dialog");
        dialogField.forceActiveFocus();
        input.keyClick(Qt.Key_Escape);
        check(focused() === renameButton, "closing the rename dialog returns focus to the rename button");

        SettingsData.barConfigs = [
            {
                id: "bar",
                enabled: true,
                visible: true,
                position: 0,
                leftWidgets: ["launcherButton", "workspaceSwitcher", "focusedWindow", "clock"],
                centerWidgets: [],
                rightWidgets: []
            }
        ];
        SettingsUiState.selectedBarId = "bar";
        content.currentPage = "dankbar_widgets";
        const isThirdRow = item => item.reorderList !== undefined && item.modelData?.id === "focusedWindow";
        waitFor(() => find(content.currentPageItem, isThirdRow) !== null, "bar widgets page lists the rows");
        const widgetsTab = find(content.currentPageItem, item => item.focusedWidgetRow !== undefined);
        find(content.currentPageItem, isThirdRow).forceActiveFocus(Qt.TabFocusReason);
        input.keyClick(Qt.Key_Down);
        check(widgetsTab.highlightedSection === "left" && widgetsTab.highlightedId === "clock", "Down from a Tab-focused widget row moves the cursor to the next row");

        sidebar.focusSearch();
        waitFor(() => focused()?.cursorPosition !== undefined && inside(sidebar, focused()), "sidebar search takes focus");
        input.keyClick(Qt.Key_Tab);
        const afterTab = focused();
        check(inside(sidebar, afterTab) && afterTab.tooltipText === "Users & accounts" && modal.pageFocuses === 0, "Tab from the sidebar search reaches the avatar button");

        const sidebarScroll = find(sidebar, item => item.contentY !== undefined && typeof item.flick === "function");
        const categoryIds = sidebar.navigableIds();
        const originalSidebarHeight = sidebar.height;
        const originalFocusRings = SettingsData.focusRingEnabled;
        sidebar.height = 400;
        sidebar.currentPage = categoryIds[0];
        sidebar.activeCategoryId = categoryIds[0];

        function checkCategory(id) {
            input.wait(0);
            const row = focused();
            check(inside(sidebar, row) && row.modelData?.id === id, "Tab focuses sidebar category " + id);
            const top = row.mapToItem(sidebarScroll.contentItem, 0, 0).y;
            check(top >= sidebarScroll.contentY && top + row.height <= sidebarScroll.contentY + sidebarScroll.height, "focused sidebar category stays in view: " + id);
            return row;
        }

        // Rings off is the harder case: focus must still read through the row tint alone
        SettingsData.focusRingEnabled = false;
        sidebar.focusSearch();
        input.keyClick(Qt.Key_Tab);
        const profile = focused();
        check(profile === afterTab && find(profile, item => item.stateOpacity !== undefined).stateOpacity > 0, "avatar button shows keyboard focus");
        input.keyClick(Qt.Key_Tab);
        const firstRow = checkCategory(categoryIds[0]);
        const ring = find(firstRow, item => item.pointerFocused !== undefined);
        check(ring.visible, "sidebar category shows focus with rings off");
        for (const id of categoryIds.slice(1)) {
            input.keyClick(Qt.Key_Tab);
            checkCategory(id);
        }
        check(sidebar.currentPage === categoryIds[0] && root.sidebarRequests === 0, "Tab preserves the selected page");
        input.keyClick(Qt.Key_Tab);
        check(inside(content, focused()), "Tab leaves the sidebar for page controls");
        input.keyClick(Qt.Key_Backtab, Qt.ShiftModifier);
        checkCategory(categoryIds[categoryIds.length - 1]);
        for (let i = categoryIds.length - 2; i >= 0; i--) {
            input.keyClick(Qt.Key_Backtab, Qt.ShiftModifier);
            checkCategory(categoryIds[i]);
        }
        input.keyClick(Qt.Key_Backtab, Qt.ShiftModifier);
        check(focused() === profile && sidebarScroll.contentY === 0, "Shift+Tab returns to the avatar button");
        input.keyClick(Qt.Key_Backtab, Qt.ShiftModifier);
        check(focused()?.cursorPosition !== undefined && inside(sidebar, focused()), "Shift+Tab returns to search");

        input.keyClick(Qt.Key_Tab);
        input.keyClick(Qt.Key_Tab);
        input.keyClick(Qt.Key_Return);
        check(root.sidebarRequests === 1 && root.sidebarRequestedPage === categoryIds[0], "Enter opens the Tab-focused category exactly once");
        waitFor(() => inside(content.currentPageItem, focused()), "category Enter actually enters the page");
        sidebar.focusSearch();
        focused().text = "bar";
        waitFor(() => SettingsSearchService.results.length > 1, "sidebar search finds several results");
        const resultRequests = root.sidebarRequests;
        input.keyClick(Qt.Key_Tab, Qt.ControlModifier);
        waitFor(() => inside(content.currentPageItem, focused()), "Ctrl+Tab leaves a populated Search without selecting a result");
        check(root.sidebarRequests === resultRequests, "pane switching does not activate Search results");
        input.keyClick(Qt.Key_Backtab, Qt.ControlModifier | Qt.ShiftModifier);
        check(sidebar.searchFocused && sidebar.searchActive, "pane switching restores the populated Search");
        input.keyClick(Qt.Key_Tab);
        check(sidebar.searchSelectedIndex === 1 && focused()?.cursorPosition !== undefined, "Tab in a populated search advances its result cursor");
        input.keyClick(Qt.Key_Escape);
        check(!sidebar.searchActive, "Escape clears search before normal Tab navigation resumes");
        input.keyClick(Qt.Key_Down);
        check(sidebar.keyboardHighlightId === categoryIds[1] && focused()?.cursorPosition !== undefined, "Down in empty search browses categories without moving focus");
        input.keyClick(Qt.Key_Tab);
        check(sidebar.keyboardHighlightId === categoryIds[2] && focused()?.cursorPosition !== undefined, "Tab advances an existing sidebar row cursor");
        input.keyClick(Qt.Key_Escape);
        input.keyClick(Qt.Key_Tab);
        check(focused() === afterTab, "clearing the sidebar cursor restores the normal Tab chain");
        sidebar.height = originalSidebarHeight;
        SettingsData.focusRingEnabled = originalFocusRings;

        sidebar.focusSearch();
        waitFor(() => focused()?.cursorPosition !== undefined && inside(sidebar, focused()), "sidebar search takes focus again");
        input.keyClick(Qt.Key_Return);
        waitFor(() => inside(content.currentPageItem, focused()), "empty Search Enter actually focuses the page");
        check(modal.pageFocuses === 2, "Enter in the empty sidebar search requests page focus once");

        checkPaneNavigation(categoryIds, afterTab, focused);
    }

    function checkPaneNavigation(categoryIds, profile, focused) {
        sidebar.focusSearch();
        input.keyClick(Qt.Key_Tab);
        input.keyClick(Qt.Key_Down);
        check(focused()?.modelData?.id === categoryIds[0], "Down after Tab moves from profile to the first category");
        input.keyClick(Qt.Key_Down);
        const category = focused();
        check(category.modelData?.id === categoryIds[1], "Down moves category focus without opening it");
        const requestsBefore = sidebarRequests;
        input.keyClick(Qt.Key_Up);
        check(focused()?.modelData?.id === categoryIds[0] && sidebarRequests === requestsBefore, "Up changes focus without activating a page");
        input.keyClick(Qt.Key_Down);
        input.keyClick(Qt.Key_Tab, Qt.ControlModifier);
        waitFor(() => inside(content.currentPageItem, focused()), "Ctrl+Tab transfers actual sidebar focus into content");
        const pageControl = focused();
        input.keyClick(Qt.Key_Backtab, Qt.ControlModifier | Qt.ShiftModifier);
        check(focused() === category, "Ctrl+Shift+Tab restores the sidebar row");
        input.keyClick(Qt.Key_Tab, Qt.ControlModifier);
        waitFor(() => focused() === pageControl, "Ctrl+Tab restores the content control");
        input.waitForPolish(content.Window.window);
        input.mouseClick(category, category.width / 2, category.height / 2);
        input.wait(0);
        check(focused() === category && sidebarRequests === requestsBefore + 1, "sidebar click activates once and retains actual sidebar focus");
        input.keyClick(Qt.Key_Up);
        check(focused()?.modelData?.id === categoryIds[0], "sidebar arrows work after a mouse click");
        input.mouseClick(content, content.width - 2, 2);
        waitFor(() => inside(content, focused()) && !inside(content.currentPageItem, focused()), "content background click parks keyboard focus without highlighting a control");
        input.keyClick(Qt.Key_Tab, Qt.ControlModifier);
        check(inside(sidebar, focused()), "keyboard pane transfer works after a content background click");

        content.currentPage = "notifications";
        waitFor(() => find(content.currentPageItem, item => item.upDownKeysStep === false) !== null, "content loads the pointer test page");
        waitFor(() => content.currentPageSettled, "pointer test page is presented");
        const slider = find(content.currentPageItem, item => item.upDownKeysStep === false && item.visible && item.enabled);
        input.waitForPolish(content.Window.window);
        content._reveal(slider);
        input.waitForPolish(content.Window.window);
        input.waitForRendering(slider);
        sidebar.focusSearch();
        input.mouseClick(slider, slider.width / 2, slider.height / 2);
        input.wait(0);
        check(inside(slider, focused()), "content click preserves clicked slider focus");
        const sliderValue = slider.value;
        input.keyClick(Qt.Key_Down);
        check(!inside(slider, focused()) && slider.value === sliderValue, "content arrows work after clicking a slider");
        input.keyClick(Qt.Key_F, Qt.ControlModifier);
        check(sidebar.searchFocused, "Ctrl+F restores actual Search focus");
        const pageScroll = find(content.currentPageItem, item => item.contentY !== undefined && typeof item.flick === "function");
        pageScroll.contentY = Math.max(0, pageScroll.contentHeight - pageScroll.height);
        const pointerScroll = pageScroll.contentY;
        input.mouseClick(content, content.width - 2, 2);
        waitFor(() => inside(content, focused()) && !inside(content.currentPageItem, focused()), "background click parks focus after scrolling");
        check(Math.abs(pageScroll.contentY - pointerScroll) < 1, "background click does not jump the page");
        input.keyClick(Qt.Key_Down);
        check(inside(content.currentPageItem, focused()) && pageScroll.contentY < pointerScroll, "the next arrow resumes at the remembered control and reveals it");
        checkPointerControls(focused);
        checkKeyCapture(focused);
        modal.focusCurrentPage();
        modal.focusSearch();
        input.wait(0);
        check(sidebar.searchFocused, "a later sidebar interaction cancels deferred content focus");
    }

    function checkKeyCapture(focused) {
        content.currentPage = "lock_screen";
        waitFor(() => content.currentPageSettled && find(content.currentPageItem, item => item.capturing !== undefined) !== null, "security key capture loads");
        const capture = find(content.currentPageItem, item => item.capturing !== undefined);
        capture.forceActiveFocus(Qt.TabFocusReason);
        input.keyClick(Qt.Key_Return);
        check(capture.capturing, "Enter starts security key capture");
        const backs = modal.backs;
        for (const key of [Qt.Key_Up, Qt.Key_Down, Qt.Key_Backspace])
            input.keyClick(key);
        check(focused() === capture && capture.capturing && modal.backs === backs, "capture owns arrows and Backspace");
        input.keyClick(Qt.Key_Tab);
        input.keyClick(Qt.Key_Backtab, Qt.ShiftModifier);
        check(focused() === capture && capture.capturing, "capture consumes forward and reverse Tab traversal");
        content._focusPage();
        input.wait(0);
        check(focused() === capture && capture.capturing, "deferred page focus preserves key capture");
        input.keyClick(Qt.Key_Tab, Qt.ControlModifier);
        check(focused() === capture && !sidebar.searchFocused, "capture owns the pane shortcut");
        capture.startCapture();
        input.keyClick(Qt.Key_Escape);
        check(!capture.capturing && focused() === capture && modal.backs === backs, "Escape ends capture before page navigation");
        modal.focusSearch();
    }

    Component {
        id: pointerControls
        Column {
            objectName: "pointer-controls"
            width: 400
            z: 100
            property int toggles: 0
            property int choices: 0
            DankTextField {
                objectName: "pointer-text"
                width: parent.width
                text: "abcd"
            }
            SettingsToggleRow {
                objectName: "pointer-toggle"
                width: parent.width
                text: "Fixture"
                onToggled: value => {
                    checked = value;
                    parent.toggles++;
                }
            }
            SettingsSwatchGrid {
                objectName: "pointer-swatches"
                width: parent.width
                compact: true
                options: [{value: "a", label: "A", primary: Theme.primary, secondary: Theme.secondary, tertiary: Theme.tertiary}, {value: "b", label: "B", primary: Theme.primary, secondary: Theme.secondary, tertiary: Theme.tertiary}]
                onSelected: value => {
                    currentValue = value;
                    parent.choices++;
                }
            }
        }
    }

    function checkPointerControls(focused) {
        const panel = pointerControls.createObject(content.currentPageItem);
        input.waitForPolish(content.Window.window);
        input.waitForRendering(panel);
        const field = find(panel, item => item.objectName === "pointer-text");
        modal.focusSearch();
        input.mouseClick(field, field.width / 2, field.height / 2);
        input.wait(0);
        check(inside(field, focused()), "clicking a content text field preserves actual field focus");
        const editor = focused();
        editor.cursorPosition = editor.text.length;
        const backs = modal.backs;
        input.keyClick(Qt.Key_Left);
        check(editor.cursorPosition === 3, "text field keeps horizontal caret navigation");
        input.keyClick(Qt.Key_Backspace);
        check(editor.text === "abd" && modal.backs === backs, "Backspace edits content text without navigating back");
        const toggle = find(panel, item => item.objectName === "pointer-toggle");
        input.mouseClick(toggle, toggle.width / 2, toggle.height / 2);
        input.wait(0);
        check(focused() === toggle && panel.toggles === 1, "mouse toggle activates once and retains control focus");
        input.keyClick(Qt.Key_Space);
        check(panel.toggles === 2 && !toggle.checked, "Space toggles the clicked control once");
        const rowTint = find(toggle, item => item.parent === toggle && item.color?.toString() === toggle.contentColor.toString());
        check(rowTint.opacity === 0, "a mouse-focused row stays untinted");
        const rings = SettingsData.focusRingEnabled;
        SettingsData.focusRingEnabled = false;
        modal.focusSearch();
        toggle.forceActiveFocus(Qt.TabFocusReason);
        check(rowTint.visible && rowTint.opacity === Theme.stateLayerFocus, "a keyboard-focused row tints with rings off");
        SettingsData.focusRingEnabled = rings;
        const tile = find(panel, item => item.modelData?.value === "b");
        input.mouseClick(tile, tile.width / 2, tile.height / 2);
        input.wait(0);
        check(focused() === tile && panel.choices === 1, "swatch click focuses and applies the actual tile once");
        const tileRing = find(tile, item => item.pointerFocused !== undefined);
        const tileTint = find(tile, item => item.stateOpacity !== undefined);
        check(!tileRing.visible, "a mouse-focused swatch draws no focus ring");
        input.keyClick(Qt.Key_Return);
        check(panel.choices === 2, "Enter acts on the mouse-focused swatch");
        // Focus must actually move: forceActiveFocus keeps the old reason on an already focused item
        toggle.forceActiveFocus(Qt.TabFocusReason);
        tile.forceActiveFocus(Qt.TabFocusReason);
        check(tileRing.visible && tileTint.stateOpacity === Theme.stateLayerFocus, "a keyboard-focused swatch draws its focus ring and tint");
        panel.destroy();
        modal.focusSearch();
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            try {
                root.run();
            } catch (error) {
                root.check(false, error.message);
            }
            console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
            Qt.quit();
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }
}
