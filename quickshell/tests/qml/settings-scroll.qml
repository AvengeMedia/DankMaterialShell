import QtQuick
import QtQuick.Controls
import QtTest
import Quickshell
import qs.Common
import qs.Services
import qs.Modals.Settings
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property var content: null
    property Item parentPage: null
    property Item childPage: null

    QtObject {
        id: modal
        property bool shouldBeVisible: true
        property bool isCompactMode: false
        property bool menuVisible: true
        property bool canGoBack: true
        property var pageHistory: []
    }

    Component {
        id: contentComponent
        SettingsContent {
            width: 900
            height: 500
            parentModal: modal
        }
    }

    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 900
        implicitHeight: 500
    }

    TestCase {
        id: tester
        when: false

        function check(condition, message) {
            if (!condition)
                throw new Error(message);
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

        function scrollable() {
            return find(root.content.currentPageItem, item => item.contentY !== undefined && item.contentItem !== undefined);
        }

        function settle() {
            wait(0);
            const scene = window.contentItem.Window.window;
            check(!isPolishScheduled(scene) || waitForPolish(scene, 5000), "settings layout settled");
            wait(0);
        }

        function open(page) {
            root.content.currentPage = page;
            settle();
            check(scrollable() !== null, page + " has a scrollable page");
        }

        function expectPosition(y, label) {
            try {
                tryVerify(() => Math.abs(scrollable().contentY - y) < 1, 1000);
            } catch (error) {
                throw new Error(label + ": expected " + y + ", got " + scrollable().contentY);
            }
        }

        function run() {
            try {
                tryVerify(() => CompositorService.compositor !== "unknown", 5000);
                root.content = contentComponent.createObject(window.contentItem);
                open("theme_surfaces");
                SettingsData.animationDuration = 0;
                const position = Math.min(700, scrollable().contentHeight - scrollable().height);
                check(position > 0, "interface style scrolls");
                scrollable().contentY = position;
                root.parentPage = root.content.currentPageItem;
                modal.pageHistory = ["theme_surfaces"];
                open("surface_shadows");
                root.childPage = root.content.currentPageItem;
                modal.pageHistory = [];
                open("theme_surfaces");
                check(root.content.currentPageItem === root.parentPage, "Back reuses the parent page");
                expectPosition(position, "Back preserves the scroll position");
                tryCompare(root, "childPage", null);

                SettingsData.animationDuration = 250;
                open("notifications");
                check(!root.content.currentPageItem.parent.StackView.view.busy, "category switches have no page transition");
                tryCompare(root, "parentPage", null);
                root.parentPage = root.content.currentPageItem;
                modal.shouldBeVisible = false;
                tryCompare(root, "parentPage", null);
                modal.shouldBeVisible = true;
                settle();

                SettingsData.barConfigs = [
                    {
                        id: "default",
                        leftWidgets: ["clock"],
                        centerWidgets: [],
                        rightWidgets: []
                    }
                ];
                root.content.currentPage = "dankbar_widgets";
                tryVerify(() => root.content.currentPageItem?.reorderGroup !== undefined, 1000);
                settle();
                const widgetRow = find(root.content.currentPageItem, item => item.modelData?.id === "clock");
                check(widgetRow && widgetRow.visible && widgetRow.height > 0, "bar widgets renders the configured clock row");
                console.log("FIXTURE_PASS settings page retention and cleanup");
            } catch (error) {
                console.error("FIXTURE_FAIL " + error.message);
            }
            Qt.quit();
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        SettingsData.animationDuration = 250;
        Qt.callLater(tester.run);
    }
}
