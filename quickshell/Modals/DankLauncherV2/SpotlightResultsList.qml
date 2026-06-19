pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var controller: null
    property bool hasQuery: false
    property var rows: []
    readonly property real bottomInset: Theme.spacingS

    signal itemRightClicked(int index, var item, real mouseX, real mouseY)

    function resetScroll() {
        mainListView.contentY = mainListView.originY;
    }

    function ensureVisible(flatIndex) {
        if (!controller || flatIndex < 0)
            return;
        for (let i = 0; i < rows.length; i++) {
            if ((rows[i]?.flatIndex ?? -1) === flatIndex) {
                mainListView.positionViewAtIndex(i, ListView.Contain);
                return;
            }
        }
    }

    function getSelectedItemPosition() {
        const fallback = mapToItem(null, width / 2, Math.min(height / 2, 56));
        if (!controller || controller.selectedFlatIndex < 0)
            return fallback;
        for (let i = 0; i < rows.length; i++) {
            if ((rows[i]?.flatIndex ?? -1) === controller.selectedFlatIndex) {
                const rowY = i * mainListView.rowHeight - mainListView.contentY + mainListView.originY;
                return mapToItem(null, width / 2, Math.max(28, Math.min(height - 28, rowY + mainListView.rowHeight / 2)));
            }
        }
        return fallback;
    }

    Connections {
        target: root.controller
        function onSelectedFlatIndexChanged() {
            if (root.controller?.keyboardNavigationActive)
                Qt.callLater(() => root.ensureVisible(root.controller.selectedFlatIndex));
        }
    }

    DankListView {
        id: mainListView
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.bottomInset
        clip: true
        visible: root.rows.length > 0

        readonly property int rowHeight: 64

        model: ScriptModel {
            values: root.rows
            objectProp: "_rowId"
        }

        delegate: Item {
            id: delegateRoot
            required property var modelData
            required property int index

            width: mainListView.width
            height: mainListView.rowHeight

            SpotlightResultRow {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                anchors.topMargin: 3
                anchors.bottomMargin: 3
                item: delegateRoot.modelData?.item ?? null
                sectionTitle: delegateRoot.modelData?.sectionTitle ?? ""
                sectionIcon: delegateRoot.modelData?.sectionIcon ?? ""
                flatIndex: delegateRoot.modelData?.flatIndex ?? -1
                controller: root.controller
                isSelected: (delegateRoot.modelData?.flatIndex ?? -1) === root.controller?.selectedFlatIndex

                onClicked: {
                    if (root.controller && delegateRoot.modelData?.item)
                        root.controller.executeItem(delegateRoot.modelData.item);
                }

                onRightClicked: (mouseX, mouseY) => {
                    root.itemRightClicked(delegateRoot.modelData?.flatIndex ?? -1, delegateRoot.modelData?.item ?? null, mouseX, mouseY);
                }
            }
        }
    }

    Item {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.bottomInset
        visible: root.hasQuery && root.rows.length === 0

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingM

            Rectangle {
                width: 40
                height: 40
                radius: Theme.cornerRadius
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.surfaceContainerHigh

                DankIcon {
                    anchors.centerIn: parent
                    name: root.controller?.isSearching || root.controller?.isFileSearching ? "search" : statusIcon()
                    size: 22
                    color: Theme.surfaceVariantText

                    function statusIcon() {
                        const mode = root.controller?.searchMode ?? "all";
                        if (mode === "files")
                            return "folder_open";
                        if (mode === "plugins")
                            return "extension";
                        if (mode === "apps")
                            return "apps";
                        return "search_off";
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(420, root.width - 88)
                spacing: 2

                StyledText {
                    width: parent.width
                    text: statusTitle()
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    elide: Text.ElideRight

                    function statusTitle() {
                        if (root.controller?.isSearching || root.controller?.isFileSearching)
                            return I18n.tr("Searching");
                        if ((root.controller?.searchMode ?? "") === "files" && !DSearchService.dsearchAvailable)
                            return I18n.tr("File search unavailable");
                        if ((root.controller?.searchMode ?? "") === "files" && (root.controller?.searchQuery?.length ?? 0) < 2)
                            return I18n.tr("Keep typing");
                        return I18n.tr("No results");
                    }
                }

                StyledText {
                    width: parent.width
                    text: statusSubtitle()
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight

                    function statusSubtitle() {
                        if ((root.controller?.searchMode ?? "") === "files" && !DSearchService.dsearchAvailable)
                            return I18n.tr("Install dsearch to search files.");
                        if ((root.controller?.searchMode ?? "") === "files" && (root.controller?.searchQuery?.length ?? 0) < 2)
                            return I18n.tr("Type at least 2 characters to search files.");
                        return I18n.tr("Try a different search or switch filters.");
                    }
                }
            }
        }
    }
}
