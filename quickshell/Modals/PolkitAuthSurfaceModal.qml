import QtQuick
import Quickshell.Wayland
import qs.Common
import qs.Modals.Common
import qs.Services

DankModal {
    id: root

    property var parentPopout: null

    layerNamespace: "dms:polkit-auth-surface"
    modalWidth: 460
    modalHeight: 220
    backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    closeOnEscapeKey: true
    closeOnBackgroundClick: false
    allowStacking: true
    keepPopoutsOpen: true

    onOpened: {
        if (parentPopout)
            parentPopout.customKeyboardFocus = WlrKeyboardFocus.None;
        Qt.callLater(() => {
            if (contentLoader.item) {
                contentLoader.item.reset();
                contentLoader.item.focusPasswordField();
            }
        });
    }

    onDialogClosed: {
        if (parentPopout)
            parentPopout.customKeyboardFocus = null;
    }

    Connections {
        target: PolkitService.agent
        enabled: PolkitService.polkitAvailable

        function onIsActiveChanged() {
            if (!(PolkitService.agent?.isActive ?? false))
                root.close();
        }
    }

    content: PolkitAuthContent {
        focus: true
        onCloseRequested: root.close()
    }
}
