import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Services
import qs.Modals.Settings
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    SettingsModal {
        id: modal
    }

    TestCase {
        id: input
        name: "settings-panes"
        when: false
    }

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
        if (!condition)
            throw new Error(label);
    }

    function until(condition, label) {
        try {
            input.tryVerify(condition, 20000);
        } catch (error) {
            throw new Error(label);
        }
    }

    function run() {
        until(() => CompositorService.compositor !== "unknown", "compositor detected");
        SettingsData.animationDuration = 0;
        modal.show();
        const navigation = modal.modalFocusScope;
        const content = navigation.content;
        const focused = () => navigation.Window.activeFocusItem;
        until(() => modal.visible && navigation.Window.active && modal.searchFocused, "initial Settings load focuses Search");
        input.keyClick(Qt.Key_Tab);
        input.keyClick(Qt.Key_Down);
        const row = focused();
        check(inside(modal.sidebar, row) && row.modelData?.id, "initial Tab then Down focuses a category");
        input.mouseClick(row, row.width / 2, row.height / 2);
        until(() => content.currentPageSettled, "clicked category finishes loading");
        check(focused() === row, "cold mouse category load retains sidebar focus");
        input.keyClick(Qt.Key_Return);
        until(() => inside(content.currentPageItem, focused()), "Enter on the selected category enters content");

        const avatar = find(modal.sidebar, item => item.tooltipText === "Users & accounts");
        let profileRequests = 0;
        modal.sidebar.pageRequested.connect(() => profileRequests++);
        input.mouseClick(avatar, avatar.width / 2, avatar.height / 2);
        check(profileRequests === 1, "avatar click requests its page exactly once");
        modal.sidebar.focusSearch();
        input.keyClick(Qt.Key_Tab);
        check(focused() === avatar, "Tab from search reaches the avatar button");
        input.keyClick(Qt.Key_Return);
        check(profileRequests === 2, "Enter on the avatar requests its page");
        until(() => inside(content.currentPageItem, focused()), "Enter on the avatar enters its page");

        modal.setPage("personalization");
        modal.focusCurrentPage();
        until(() => content.currentPageSettled && content.currentPageItem?.hubId === "personalization", "personalization hub loads");
        const group = find(content.currentPageItem, item => item.arrowKeysSelect === false && item.model?.[0]?.icon === "light_mode");
        group.requestFocus(false);
        const mode = SessionData.isLightMode;
        input.keyClick(Qt.Key_Right);
        check(SessionData.isLightMode === mode && focused()?.selected === false, "Light/Dark arrows focus without applying a theme");
        input.keyClick(Qt.Key_Space);
        check(SessionData.isLightMode !== mode, "Space applies the focused Light/Dark mode");
        input.keyClick(Qt.Key_Tab, Qt.ControlModifier);
        check(inside(modal.sidebar, focused()), "Ctrl+Tab returns to sidebar");
        input.keyClick(Qt.Key_Tab, Qt.ControlModifier);
        until(() => inside(group, focused()), "Ctrl+Tab restores the focused Light/Dark choice");

        const opener = find(content.currentPageItem, item => item.settingKey === "themeNav" && item.clickable);
        opener.forceActiveFocus(Qt.TabFocusReason);
        content._reveal(opener);
        const scroll = find(content.currentPageItem, item => item.contentY !== undefined && typeof item.flick === "function");
        const position = scroll.contentY;
        input.keyClick(Qt.Key_Return);
        until(() => modal.currentPage === "theme" && content.currentPageSettled && inside(content.currentPageItem, focused()), "keyboard opens subpage and focuses a control");
        input.keyClick(Qt.Key_Left, Qt.AltModifier);
        until(() => modal.currentPage === "personalization" && focused() === opener, "Back restores the actual hub opener");
        check(Math.abs(scroll.contentY - position) < 1, "Back preserves hub scroll");

        // Parked keyboard focus sits on the content anchor, so no control is highlighted
        const parked = () => focused()?.parent === content;
        input.mouseClick(opener, opener.width / 2, opener.height / 2);
        until(() => modal.currentPage === "theme" && content.currentPageSettled && parked(), "mouse-opened subpage parks focus instead of highlighting a control");
        input.keyClick(Qt.Key_Down);
        check(inside(content.currentPageItem, focused()), "Down after a mouse-opened subpage enters it");
        input.mouseClick(content, content.width / 2, content.height / 2, Qt.BackButton);
        until(() => modal.currentPage === "personalization" && parked(), "mouse Back button returns a page and parks focus");
        input.keyClick(Qt.Key_Down);
        check(focused() === opener, "Down after mouse Back resumes at the hub opener");

        input.mouseClick(row, row.width / 2, row.height / 2);
        input.mouseClick(content, content.width / 2, Theme.spacingM);
        until(parked, "content background click parks keyboard focus without highlighting a control");
        input.keyClick(Qt.Key_Down);
        check(focused() === opener, "Down after a background click resumes at the last control");

        const hubPage = content.currentPageItem;
        modal.setPage("typography");
        modal.focusSearch();
        until(() => modal.currentPage === "typography" && content.currentPageItem !== hubPage && content.currentPageSettled, "typography page loads");
        const textRow = find(content.currentPageItem, item => item.clickable === false && item.hasBody === true);
        input.waitForPolish(navigation.Window.window);
        input.mouseClick(textRow, textRow.width / 2, textRow.height / 2);
        until(parked, "click on a page body row parks keyboard focus in content");

        SettingsData.barConfigs = [{
            id: "fixture", enabled: true, visible: true, position: 0,
            leftWidgets: ["clock"], centerWidgets: [], rightWidgets: []
        }];
        SettingsUiState.selectedBarId = "fixture";
        modal.focusSearch();
        focused().text = "clock";
        const widgetResult = () => find(modal.sidebar, item => item.modelData?.runtimeType === "barWidget" && item.modelData.runtimeId === "clock");
        until(() => widgetResult() !== null, "search finds the existing Clock widget");
        const result = widgetResult();
        modal.sidebar.ensureRowVisible(result);
        input.waitForPolish(navigation.Window.window);
        const previousPage = content.currentPageItem;
        input.mouseClick(result, result.width / 2, result.height / 2);
        until(() => modal.currentPage === "bar_widget" && content.currentPageItem !== previousPage && content.currentPageSettled, "mouse search result loads widget options");
        check(inside(modal.sidebar, focused()), "mouse search drilldown retains sidebar focus");
        input.keyClick(Qt.Key_Tab, Qt.ControlModifier);
        until(() => inside(content.currentPageItem, focused()), "pane shortcut enters searched widget options");
        modal.focusSearch();
        input.keyClick(Qt.Key_Escape);
        modal.setPage("personalization");
        modal.focusCurrentPage();
        until(() => content.currentPageItem?.hubId === "personalization" && content.currentPageSettled, "personalization returns after search drilldown");

        // The test compositor owns tiled window width; exercise the compact layout directly.
        modal.isCompactMode = true;
        modal.focusSearch();
        input.keyClick(Qt.Key_Tab, Qt.ControlModifier);
        until(() => !modal.menuVisible && inside(content.currentPageItem, focused()), "compact pane shortcut enters visible content");
        input.keyClick(Qt.Key_Tab, Qt.ControlModifier);
        check(modal.menuVisible && inside(modal.sidebar, focused()), "compact pane shortcut reveals the sidebar");
        input.keyClick(Qt.Key_Tab);
        input.keyClick(Qt.Key_Return);
        until(() => !modal.menuVisible && inside(content.currentPageItem, focused()), "compact sidebar activation enters content");
        modal.hide();
        until(() => !content.currentPageItem, "closing Settings releases its pages");
        modal.menuVisible = false;
        navigation.activePane = "content";
        modal.show();
        until(() => modal.visible && modal.menuVisible && modal.searchFocused, "compact reopening starts in visible Search");
        modal.hide();
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            try {
                root.run();
                console.log("FIXTURE_PASS");
            } catch (error) {
                console.log("FIXTURE_FAIL " + error.message);
            }
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
