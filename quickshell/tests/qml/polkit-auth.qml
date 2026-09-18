import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Services
import qs.Modals
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property int cancellations: 0
    property bool queueNext: false

    component Flow: QtObject {
        property bool isCompleted: false
        property bool isResponseRequired: true
        property bool responseVisible: false
        property string message: "Authentication is needed to run /usr/bin/echo as the super user."
        property string inputPrompt: "Password:"
        property string supplementaryMessage: ""
        property bool supplementaryIsError: false
        signal authenticationSucceeded
        signal authenticationFailed
        signal authenticationRequestCancelled
        function submit(value) {
            isResponseRequired = false;
        }
        function cancelAuthenticationRequest() {
            root.cancellations++;
            isCompleted = true;
            if (!root.queueNext)
                return;
            root.queueNext = false;
            modal.show();
            modal.currentFlow = nextFlow;
        }
    }

    Flow {
        id: flow
    }
    Flow {
        id: nextFlow
    }
    PolkitAuthModal {
        id: modal
    }
    PolkitAuthSurfaceModal {
        id: surface
    }
    TestCase {
        id: input
        when: false
        name: "polkit"
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }

    function find(item, predicate) {
        if (predicate(item))
            return item;
        for (const child of item.children ?? []) {
            const found = find(child, predicate);
            if (found)
                return found;
        }
        return null;
    }

    function check(value, message) {
        if (!value)
            throw new Error(message);
    }

    function openModal() {
        flow.isCompleted = false;
        flow.isResponseRequired = true;
        modal.show();
        modal.currentFlow = flow;
        input.wait(50);
        return find(modal.contentItem, item => typeof item.submitAuth === "function");
    }

    Timer {
        interval: 500
        running: true
        onTriggered: {
            try {
                openModal();
                modal.closed();
                root.check(root.cancellations === 1 && !modal.visible, "native close cancels the request");
                modal.closed();
                root.check(root.cancellations === 1, "duplicate close does not cancel twice");

                let content = root.openModal();
                root.find(content, item => item.text === "Cancel" && typeof item.click === "function").click();
                root.check(root.cancellations === 2 && !modal.visible, "Cancel button cancels");

                content = root.openModal();
                root.find(content, item => item.Accessible.name === "Close" && typeof item.click === "function").click();
                root.check(root.cancellations === 3 && !modal.visible, "header close cancels");

                content = root.openModal();
                content.submitAuth();
                root.check(content.isLoading, "submission pending");
                content.forceActiveFocus();
                input.keyClick(Qt.Key_Escape);
                root.check(root.cancellations === 4 && !modal.visible, "Escape cancels during submission");

                content = root.openModal();
                content.submitAuth();
                modal.closed();
                root.check(root.cancellations === 5 && !modal.visible, "native close cancels during submission");

                root.openModal();
                root.queueNext = true;
                modal.closed();
                root.check(root.cancellations === 6 && modal.visible && modal.currentFlow === nextFlow, "queued request stays open");
                modal.hide();

                root.openModal();
                flow.isCompleted = true;
                modal.closed();
                root.check(root.cancellations === 6, "completed request is not cancelled");

                content = root.openModal();
                flow.isCompleted = true;
                flow.authenticationSucceeded();
                root.check(root.cancellations === 6 && !modal.visible, "success closes without cancellation");

                flow.isCompleted = false;
                surface.open();
                input.wait(100);
                surface.currentFlow = flow;
                input.wait(20);
                content = surface.contentLoader.item;
                content.forceActiveFocus();
                input.keyClick(Qt.Key_Escape);
                root.check(root.cancellations === 7 && !surface.shouldBeVisible, "surface Escape cancels");

                console.log("FIXTURE_PASS polkit close, buttons, Escape, pending submit, queued and completed requests");
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
            }
            Qt.quit();
        }
    }
}
