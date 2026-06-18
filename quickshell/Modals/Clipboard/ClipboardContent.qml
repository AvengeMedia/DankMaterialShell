import QtQuick
import Quickshell
import qs.Common
import qs.Widgets

Item {
    id: clipboardContent

    required property var modal

    property alias searchField: searchField
    property alias clipboardListView: clipboardListView

    readonly property var filterOptions: [I18n.tr("All"), I18n.tr("Text"), I18n.tr("Long Text"), I18n.tr("Image")]
    readonly property var filterValues: ["all", "text", "long_text", "image"]

    function closeFilterMenu() {
        filterMenuLoader.active = false;
        filterMenuLoader.active = true;
    }

    function showContextMenu(entry, sceneX, sceneY) {
        const localPos = mapFromItem(null, sceneX, sceneY);
        contextMenu.show(localPos.x, localPos.y, entry);
    }

    function contextEntryAtScreen(screenX, screenY) {
        const host = modal.surfaceHost ?? null;
        const hostX = host?.alignedX;
        const hostY = host?.renderedAlignedY ?? host?.alignedY;

        if (!isNaN(hostX) && !isNaN(hostY))
            return contextEntryAtLocal(screenX - hostX, screenY - hostY);

        const screenRef = host?.effectiveScreen ?? host?.screen ?? modal.Window?.window?.screen ?? null;
        const globalOrigin = mapToGlobal(0, 0);
        const screenOriginX = screenRef?.x || 0;
        const screenOriginY = screenRef?.y || 0;
        return contextEntryAtLocal(screenOriginX + screenX - globalOrigin.x, screenOriginY + screenY - globalOrigin.y);
    }

    function contextEntryAtLocal(localX, localY) {
        const listView = modal.activeTab === "saved" ? savedListView : clipboardListView;
        const entries = modal.activeTab === "saved" ? modal.pinnedEntries : modal.unpinnedEntries;

        if (!listView.visible || !entries)
            return null;

        const listPos = mapToItem(listView, localX, localY);
        if (listPos.x < 0 || listPos.x > listView.width || listPos.y < 0 || listPos.y > listView.height)
            return null;

        const index = listView.indexAt(listPos.x + listView.contentX, listPos.y + listView.contentY);
        if (index < 0 || index >= entries.length)
            return null;

        return {
            entry: entries[index],
            x: localX,
            y: localY
        };
    }

    function closeContextMenu() {
        contextMenu.hide();
    }

    anchors.fill: parent

    ClipboardContextMenu {
        id: contextMenu
        modal: clipboardContent.modal
        parentHandler: clipboardContent
    }

    Column {
        id: headerColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingM
        focus: false

        ClipboardHeader {
            id: header
            width: parent.width
            recentsCount: modal.unpinnedEntries.length
            savedCount: modal.pinnedEntries.length
            showKeyboardHints: modal.showKeyboardHints
            activeTab: modal.activeTab
            pinnedCount: modal.pinnedCount
            onKeyboardHintsToggled: modal.showKeyboardHints = !modal.showKeyboardHints
            onTabChanged: tabName => modal.activeTab = tabName
            onClearAllClicked: modal.confirmClearAll()
            onCloseClicked: modal.hide()
        }

        Item {
            id: searchRow
            width: parent.width
            implicitHeight: searchField.height

            DankTextField {
                id: searchField

                width: parent.width
                rightAccessoryWidth: filterButton.width + Theme.spacingS
                placeholderText: ""
                leftIconName: "search"
                showClearButton: true
                focus: true
                ignoreTabKeys: true
                keyForwardTargets: [modal.modalFocusScope]

                onTextChanged: {
                    modal.searchText = text;
                    modal.updateFilteredModel();
                }

                Keys.onEscapePressed: function (event) {
                    modal.hide();
                    event.accepted = true;
                }

                Component.onCompleted: {
                    Qt.callLater(function () {
                        forceActiveFocus();
                    });
                }
            }

            DankActionButton {
                id: filterButton

                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                iconName: "filter_list"
                iconColor: modal.activeFilter !== "all" ? Theme.primary : Theme.surfaceText
                backgroundColor: modal.activeFilter !== "all" ? Theme.primarySelected : "transparent"
                tooltipText: I18n.tr("Filter by type", "Clipboard history type filter button tooltip")
                onClicked: filterMenuLoader.item?.openDropdownMenu()
            }

            Loader {
                id: filterMenuLoader

                active: true
                sourceComponent: filterMenuComponent
            }

            Component {
                id: filterMenuComponent

                DankDropdown {
                    showTrigger: false
                    popupAnchorItem: filterButton
                    popupWidth: 180
                    alignPopupRight: true
                    options: clipboardContent.filterOptions
                    currentValue: {
                        const idx = clipboardContent.filterValues.indexOf(clipboardContent.modal.activeFilter);
                        return idx >= 0 ? clipboardContent.filterOptions[idx] : clipboardContent.filterOptions[0];
                    }

                    onValueChanged: value => {
                        const idx = clipboardContent.filterOptions.indexOf(value);
                        if (idx >= 0) {
                            clipboardContent.modal.activeFilter = clipboardContent.filterValues[idx];
                        }
                    }
                }
            }
        }
    }

    Item {
        id: listContainer
        anchors.top: headerColumn.bottom
        anchors.topMargin: Theme.spacingM
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        anchors.bottomMargin: (modal.showKeyboardHints ? (ClipboardConstants.keyboardHintsHeight + Theme.spacingM * 2) : 0) + Theme.spacingXS
        clip: true

        DankListView {
            id: clipboardListView
            anchors.fill: parent
            model: ScriptModel {
                values: clipboardContent.modal.unpinnedEntries
                objectProp: "id"
            }
            visible: modal.activeTab === "recents"

            currentIndex: clipboardContent.modal ? clipboardContent.modal.selectedIndex : 0
            spacing: Theme.spacingXS
            interactive: true
            flickDeceleration: 1500
            maximumFlickVelocity: 2000
            boundsBehavior: Flickable.DragAndOvershootBounds
            boundsMovement: Flickable.FollowBoundsBehavior
            pressDelay: 0
            flickableDirection: Flickable.VerticalFlick

            states: [
                State {
                    name: "snap"
                    when: Theme.snapListModelChanges
                    PropertyChanges {
                        target: clipboardListView
                        add: null
                        remove: null
                        displaced: null
                        move: null
                    }
                }
            ]

            function ensureVisible(index) {
                if (index < 0 || index >= count) {
                    return;
                }
                positionViewAtIndex(index, ListView.Contain);
            }

            onCurrentIndexChanged: {
                if (clipboardContent.modal?.keyboardNavigationActive && currentIndex >= 0) {
                    ensureVisible(currentIndex);
                }
            }

            StyledText {
                text: clipboardContent.modal.clipboardAvailable ? I18n.tr("No recent clipboard entries found") : I18n.tr("Connecting to clipboard service...")
                anchors.centerIn: parent
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                visible: clipboardContent.modal.unpinnedEntries.length === 0
            }

            delegate: ClipboardEntry {
                required property int index
                required property var modelData

                width: clipboardListView.width
                height: ClipboardConstants.itemHeight
                entry: modelData
                entryIndex: index + 1
                itemIndex: index
                isSelected: clipboardContent.modal?.keyboardNavigationActive && index === clipboardContent.modal.selectedIndex
                modal: clipboardContent.modal
                listView: clipboardListView
                onCopyRequested: clipboardContent.modal.copyEntry(modelData)
                onDeleteRequested: clipboardContent.modal.deleteEntry(modelData)
                onPinRequested: targetEntry => clipboardContent.modal.pinEntry(targetEntry)
                onUnpinRequested: targetEntry => clipboardContent.modal.unpinEntry(targetEntry)
                onEditRequested: clipboardContent.modal.editEntry(modelData)
                onContextMenuRequested: (mouseX, mouseY) => clipboardContent.showContextMenu(modelData, mouseX, mouseY)
            }
        }

        DankListView {
            id: savedListView
            anchors.fill: parent
            model: ScriptModel {
                values: clipboardContent.modal.pinnedEntries
                objectProp: "id"
            }
            visible: modal.activeTab === "saved"

            currentIndex: clipboardContent.modal ? clipboardContent.modal.selectedIndex : 0
            spacing: Theme.spacingXS
            interactive: true
            flickDeceleration: 1500
            maximumFlickVelocity: 2000
            boundsBehavior: Flickable.DragAndOvershootBounds
            boundsMovement: Flickable.FollowBoundsBehavior
            pressDelay: 0
            flickableDirection: Flickable.VerticalFlick

            states: [
                State {
                    name: "snap"
                    when: Theme.snapListModelChanges
                    PropertyChanges {
                        target: savedListView
                        add: null
                        remove: null
                        displaced: null
                        move: null
                    }
                }
            ]

            function ensureVisible(index) {
                if (index < 0 || index >= count) {
                    return;
                }
                positionViewAtIndex(index, ListView.Contain);
            }

            onCurrentIndexChanged: {
                if (clipboardContent.modal?.keyboardNavigationActive && currentIndex >= 0) {
                    ensureVisible(currentIndex);
                }
            }

            StyledText {
                text: clipboardContent.modal.clipboardAvailable ? I18n.tr("No saved clipboard entries") : I18n.tr("Connecting to clipboard service...")
                anchors.centerIn: parent
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                visible: clipboardContent.modal.pinnedEntries.length === 0
            }

            delegate: ClipboardEntry {
                required property int index
                required property var modelData

                width: savedListView.width
                height: ClipboardConstants.itemHeight
                entry: modelData
                entryIndex: index + 1
                itemIndex: index
                isSelected: clipboardContent.modal?.keyboardNavigationActive && index === clipboardContent.modal.selectedIndex
                modal: clipboardContent.modal
                listView: savedListView
                onCopyRequested: clipboardContent.modal.copyEntry(modelData)
                onDeleteRequested: clipboardContent.modal.deletePinnedEntry(modelData)
                onPinRequested: targetEntry => clipboardContent.modal.pinEntry(targetEntry)
                onUnpinRequested: targetEntry => clipboardContent.modal.unpinEntry(targetEntry)
                onEditRequested: clipboardContent.modal.editEntry(modelData)
                onContextMenuRequested: (mouseX, mouseY) => clipboardContent.showContextMenu(modelData, mouseX, mouseY)
            }
        }

        Rectangle {
            id: bottomFade
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 24
            z: 100
            visible: {
                const listView = modal.activeTab === "recents" ? clipboardListView : savedListView;
                if (listView.contentHeight <= listView.height)
                    return false;
                const atBottom = listView.contentY >= listView.contentHeight - listView.height - 5;
                return !atBottom;
            }
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: "transparent"
                }
                GradientStop {
                    position: 1.0
                    color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
                }
            }
        }
    }

    Loader {
        id: keyboardHintsLoader
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        anchors.bottomMargin: active ? Theme.spacingM : 0
        active: modal.showKeyboardHints
        height: active ? ClipboardConstants.keyboardHintsHeight : 0

        Behavior on height {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        sourceComponent: ClipboardKeyboardHints {
            wtypeAvailable: modal.wtypeAvailable
            enterToPaste: SettingsData.clipboardEnterToPaste
        }
    }
}
