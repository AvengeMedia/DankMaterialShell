import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

FloatingWindow {
    id: root

    property bool disablePopupTransparency: true

    function show() {
        if (contentLoader.item)
            contentLoader.item.reset();
        visible = true;
        Qt.callLater(focusContent);
    }

    function hide() {
        visible = false;
    }

    function focusContent() {
        if (contentLoader.item)
            contentLoader.item.focusPasswordField();
    }

    objectName: "polkitAuthModal"
    title: I18n.tr("Authentication")
    minimumSize: Qt.size(460, 220)
    maximumSize: Qt.size(460, 220)
    color: Theme.surfaceContainer
    visible: false

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(focusContent);
            return;
        }
        if (contentLoader.item)
            contentLoader.item.reset();
    }

    Connections {
        target: PolkitService.agent
        enabled: PolkitService.polkitAvailable

        function onIsActiveChanged() {
            if (!(PolkitService.agent?.isActive ?? false))
                root.hide();
        }
    }

    Loader {
        id: contentLoader
        anchors.fill: parent
        active: root.visible
        sourceComponent: PolkitAuthContent {
            windowControls: windowControls
            onCloseRequested: root.hide()
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: root
    }
}
