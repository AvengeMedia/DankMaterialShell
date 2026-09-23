import QtQuick
import QtTest
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Modals.Clipboard
import qs.DankCommon.Common as DC

ShellRoot {
    id: root
    property bool failed: false

    function findItem(item, predicate) {
        if (predicate(item))
            return item;
        for (const child of item.children ?? []) {
            const found = findItem(child, predicate);
            if (found)
                return found;
        }
        return null;
    }

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    QtObject {
        id: testModal
        property string activeTab: "recents"
        property int pinnedCount: 1
        property bool showKeyboardHints: false
        property bool clearsFilteredOnly: false
        property string mode: "history"
        property bool contextMenuActive: false
        property var modalFocusScope: scope
        function openPreview() {
            mode = "preview";
        }
        function closePreview() {
            mode = "history";
        }
        function confirmClearAll() {
        }
    }

    ClipboardKeyboardController {
        id: controller
        modal: testModal
    }
    PanelWindow {
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        implicitWidth: 800
        implicitHeight: 600
        TestCase {
            id: input
            name: "clipboard-preview"
            when: false
        }
        FocusScope {
            id: scope
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => controller.handleKey(event)
            ClipboardActions {
                id: actions
                modal: testModal
            }
        }
        ClipboardHistoryContent {
            id: history
            anchors.fill: parent
            visible: false
        }
    }

    function waitFor(condition, label) {
        const deadline = Date.now() + 20000;
        while (!condition()) {
            if (Date.now() > deadline)
                throw new Error("timed out: " + label);
            input.wait(10);
        }
    }

    function settle(item) {
        input.wait(0);
        const surface = item.Window.window;
        check(!input.isPolishScheduled(surface) || input.waitForPolish(surface, 20000), "layout settles");
    }

    function run() {
        waitFor(() => scope.Window.active, "clipboard surface takes keyboard focus");
        settle(scope);
        ClipboardService.keyboardNavigationActive = true;
        const help = input.findChild(actions, "keyboardHints");
        input.mouseClick(help, help.width / 2, help.height / 2);
        root.check(testModal.showKeyboardHints, "mouse opens keyboard hints");
        root.check(help.activeFocus, "help button receives focus");
        input.keyClick(Qt.Key_Space, Qt.ControlModifier);
        root.check(testModal.mode === "preview", "Ctrl+Space opens preview after clicking help");
        input.keyClick(Qt.Key_Escape);
        root.check(testModal.mode === "history", "Escape closes preview");
        input.keyClick(Qt.Key_F10);
        root.check(!testModal.showKeyboardHints, "F10 closes keyboard hints");
        input.keyClick(Qt.Key_Space, Qt.ControlModifier);
        root.check(testModal.mode === "preview", "Ctrl+Space still works after hiding hints");
        scope.visible = false;
        history.visible = true;
        ClipboardService.unpinnedEntries = [
            {
                id: 1,
                preview: "Text",
                mimeType: "text/plain",
                isImage: false
            },
            {
                id: 2,
                preview: "Image",
                mimeType: "image/png",
                isImage: true
            }
        ];
        ClipboardService.selectedIndex = 0;
        const findPreview = () => root.findItem(history, item => item.objectName === "previewEntry" && item.visible);
        waitFor(() => findPreview() !== null, "image row exposes a mouse preview action");
        settle(history);
        const preview = findPreview();
        input.mouseClick(preview, preview.width / 2, preview.height / 2);
        root.check(history.mode === "preview", "mouse action opens preview");
        root.check(history.currentEntry?.id === 2, "mouse action selects its image rather than the previous selection");
        input.keyClick(Qt.Key_Escape);
        root.check(history.mode === "history", "Escape closes mouse-opened preview");
        input.keyClick(Qt.Key_Space, Qt.ControlModifier);
        root.check(history.mode === "preview", "keyboard reopens the mouse-selected image");
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
