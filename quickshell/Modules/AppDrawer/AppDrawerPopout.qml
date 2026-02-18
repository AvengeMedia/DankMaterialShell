import QtQuick
import qs.Common
import qs.Modals.DankLauncherV2
import qs.Widgets

DankPopout {
    id: appDrawerPopout

    layerNamespace: "dms:app-launcher"

    property string _pendingMode: ""
    property string _pendingQuery: ""

    function show() {
        open();
    }

    function openWithMode(mode) {
        _pendingMode = mode || "";
        open();
    }

    function toggleWithMode(mode) {
        if (shouldBeVisible) {
            close();
            return;
        }
        openWithMode(mode);
    }

    function openWithQuery(query) {
        _pendingQuery = query || "";
        open();
    }

    function toggleWithQuery(query) {
        if (shouldBeVisible) {
            close();
            return;
        }
        openWithQuery(query);
    }

    popupWidth: 560
    popupHeight: 640
    triggerWidth: 40
    positioning: ""
    contentHandlesKeys: contentLoader.item?.launcherContent?.editMode ?? false

    onBackgroundClicked: {
        if (contentLoader.item?.launcherContent?.editMode) {
            contentLoader.item.launcherContent.closeEditMode();
            return;
        }
        close();
    }

    onOpened: {
        var lc = contentLoader.item?.launcherContent;
        if (!lc)
            return;

        const query = _pendingQuery;
        const mode = _pendingMode || "apps";
        _pendingMode = "";
        _pendingQuery = "";

        if (lc.searchField) {
            lc.searchField.text = query;
            lc.searchField.forceActiveFocus();
        }
        if (lc.controller) {
            lc.controller.searchMode = mode;
            lc.controller.pluginFilter = "";
            lc.controller.searchQuery = "";
            if (query) {
                lc.controller.setSearchQuery(query);
            } else {
                lc.controller.performSearch();
            }
        }
        lc.resetScroll?.();
        lc.actionPanel?.hide();
    }

    content: Component {
        Rectangle {
            id: contentContainer

            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true

            property alias launcherContent: launcherContent

            color: "transparent"

            QtObject {
                id: modalAdapter
                property bool spotlightOpen: appDrawerPopout.shouldBeVisible
                property bool isClosing: false

                function hide() {
                    appDrawerPopout.close();
                }
            }

            FocusScope {
                anchors.fill: parent
                focus: true

                LauncherContent {
                    id: launcherContent
                    anchors.fill: parent
                    parentModal: modalAdapter
                    viewModeContext: "appDrawer"
                }

                Keys.onEscapePressed: event => {
                    if (launcherContent.editMode) {
                        launcherContent.closeEditMode();
                        event.accepted = true;
                        return;
                    }
                    appDrawerPopout.close();
                    event.accepted = true;
                }
            }
        }
    }
}
