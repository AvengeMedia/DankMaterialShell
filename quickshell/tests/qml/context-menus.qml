import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Services
import qs.Modals.Clipboard
import qs.Modals.DankLauncherV2
import qs.Modules.Notifications
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property var calls: []

    Component {
        id: clipboardContent
        ClipboardContent {}
    }
    Component {
        id: launcherContent
        LauncherContent {}
    }
    Component {
        id: spotlightContent
        SpotlightLauncherContent {}
    }
    TestCase {
        id: input
        when: false
        name: "context-menus"
    }

    Item {
        id: fakeModal
        function copyEntry(entry) {
            root.calls.push("copy:" + entry.hash);
        }
        function pasteEntry(entry) {
            root.calls.push("paste:" + entry.hash);
        }
        function pinEntry(entry) {
            root.calls.push("pin:" + entry.hash);
        }
        function unpinEntry(entry) {
            root.calls.push("unpin:" + entry.hash);
        }
        function editEntry(entry) {
            root.calls.push("edit:" + entry.hash);
        }
        function deleteEntry(entry) {
            root.calls.push("delete:" + entry.hash);
        }
        function deletePinnedEntry(entry) {
            root.calls.push("deletePinned:" + entry.hash);
        }
    }

    QtObject {
        id: fakeController
        function itemExecuted() {
            root.calls.push("executed");
        }
        function performSearch() {
            root.calls.push("search");
        }
        function executeAction(item, action) {
            root.calls.push("launcherAction:" + action.name);
        }
    }

    Item {
        id: handler
        width: 400
        height: 300
        readonly property var parentModal: null
        function contextEntryAtScreen(x, y) {
            return x < 100 ? {
                entry: {
                    hash: "h2",
                    isImage: true
                },
                x: x,
                y: y
            } : null;
        }
    }

    ClipboardContextMenu {
        id: clipboardMenu
        modal: fakeModal
        parentHandler: handler
    }
    LauncherContextMenu {
        id: launcherMenu
        controller: fakeController
        parentHandler: handler
    }
    NotificationContextMenu {
        id: notificationMenu
        appName: "Mail"
        onDismissRequested: root.calls.push("dismiss")
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }

    function check(value, message) {
        if (!value)
            throw new Error(message);
    }

    function texts(menu) {
        return menu.menuItems.map(m => m.type === "separator" ? "|" : m.text).join(",");
    }

    function settle() {
        for (let i = 0; i < 20 && (clipboardMenu.renderActive || launcherMenu.renderActive || notificationMenu.renderActive); i++)
            input.wait(50);
    }

    Timer {
        interval: 500
        running: true
        onTriggered: {
            try {
                root.check(clipboardContent.status === Component.Ready, "ClipboardContent compiles: " + clipboardContent.errorString());
                root.check(launcherContent.status === Component.Ready, "LauncherContent compiles: " + launcherContent.errorString());
                root.check(spotlightContent.status === Component.Ready, "SpotlightLauncherContent compiles: " + spotlightContent.errorString());

                clipboardMenu.show(10, 10, {
                    hash: "h1",
                    isImage: false,
                    altMimeType: "text/plain"
                });
                input.wait(50);
                root.check(clipboardMenu.renderActive && clipboardMenu.openState && clipboardMenu.contextWindow.visible, "clipboard menu opens a window");
                root.check(root.texts(clipboardMenu) === "Copy,Copy Text,Pin,Edit,Delete,|,Paste", "clipboard items: " + root.texts(clipboardMenu));
                root.check(clipboardMenu.effectiveMenuHeight === clipboardMenu.naturalMenuHeight && clipboardMenu.naturalMenuHeight === 6 * Theme.menuItemHeight + Theme.spacingXS + Theme.dividerWidth + 6 * Theme.groupedListGap + Theme.spacingS * 2, "menu height sums items, separator and gaps");
                root.check(clipboardMenu.effectiveMenuWidth >= clipboardMenu.minMenuWidth, "menu width respects the minimum");
                clipboardMenu.activate(clipboardMenu.menuItems[0]);
                root.check(root.calls.join() === "copy:h1" && !clipboardMenu.openState, "copy action runs and closes");
                root.settle();
                root.check(!clipboardMenu.renderActive && !clipboardMenu.contextWindow.visible, "window hides after the fade");

                clipboardMenu.show(10, 10, {
                    hash: "h3",
                    isImage: true
                });
                root.check(root.texts(clipboardMenu) === "Copy,Pin,Delete,|,Paste", "image entry hides text-only actions: " + root.texts(clipboardMenu));
                clipboardMenu.backdropRightClicked(50, 50);
                root.check(clipboardMenu.openState && clipboardMenu.entry.hash === "h2", "right click on the backdrop retargets the hit entry");
                clipboardMenu.backdropRightClicked(200, 50);
                root.check(!clipboardMenu.openState, "right click on empty space closes");
                root.settle();

                root.calls = [];
                handler.enabled = true;
                launcherMenu.show(20, 20, {
                    type: "note",
                    data: {
                        id: "n"
                    },
                    actions: [
                        {
                            name: "Open",
                            icon: "open_in_new"
                        },
                        {
                            name: "Trash"
                        }
                    ]
                }, true);
                input.wait(50);
                root.check(!handler.enabled, "launcher disables the handler while open");
                root.check(root.texts(launcherMenu) === "Open,Trash", "generic item actions: " + root.texts(launcherMenu));
                root.check(launcherMenu.keyboardNavigation && launcherMenu.selectedMenuIndex === 0, "keyboard open selects the first item");
                launcherMenu.selectNext();
                launcherMenu.selectNext();
                root.check(launcherMenu.selectedMenuIndex === 0, "selection wraps");
                launcherMenu.selectPrevious();
                launcherMenu.activateSelected();
                root.check(root.calls.join() === "launcherAction:Trash" && !launcherMenu.openState, "activate runs the selected launcher action");
                root.settle();
                root.check(handler.enabled, "launcher re-enables the handler after the fade");

                launcherMenu.show(20, 20, {
                    type: "app",
                    isCore: false,
                    data: {
                        id: "app.desktop",
                        name: "App",
                        execString: "app"
                    },
                    actions: []
                }, false);
                root.check(launcherMenu.selectedMenuIndex === -1 && !launcherMenu.keyboardNavigation, "pointer open starts without a selection");
                root.check(root.texts(launcherMenu).endsWith(",Launch") && root.texts(launcherMenu).startsWith("Hide App,Edit App"), "regular app items: " + root.texts(launcherMenu));
                launcherMenu.hide();
                root.settle();

                root.calls = [];
                notificationMenu.showAt(30, 30, handler.Window?.window?.screen ?? null);
                root.check(notificationMenu.openState && notificationMenu.menuItems.length === 4 && notificationMenu.effectiveMenuWidth >= NotificationMetrics.menuWidth, "notification menu opens with four actions at the metrics width");
                root.check(notificationMenu.menuItems[1].text.indexOf("Mail") >= 0, "notification labels carry the app name");
                notificationMenu.activate(notificationMenu.menuItems[3]);
                root.check(root.calls.join() === "dismiss" && !notificationMenu.openState, "dismiss action signals and closes");
                root.settle();

                console.log("FIXTURE_PASS context menus: compile, clipboard model and actions, backdrop retarget, launcher keyboard navigation and handler gating, notification actions");
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
            }
            Qt.quit();
        }
    }
}
