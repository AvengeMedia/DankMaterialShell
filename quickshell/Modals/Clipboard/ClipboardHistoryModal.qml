pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Hyprland
import qs.Common
import qs.Modals.Clipboard
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankModal {
    id: clipboardHistoryModal

    layerNamespace: "dms:clipboard"

    HyprlandFocusGrab {
        windows: [clipboardHistoryModal.contentWindow]
        active: clipboardHistoryModal.useHyprlandFocusGrab && clipboardHistoryModal.shouldHaveFocus
    }

    property string activeTab: "recents"
    onActiveTabChanged: {
        ClipboardService.selectedIndex = 0;
        ClipboardService.keyboardNavigationActive = false;
    }
    property var editClipboardModal: null
    property bool showKeyboardHints: false
    property Component clipboardContent
    property int activeImageLoads: 0
    readonly property int maxConcurrentLoads: 3

    readonly property bool clipboardAvailable: ClipboardService.clipboardAvailable
    readonly property bool wtypeAvailable: ClipboardService.wtypeAvailable
    readonly property int totalCount: ClipboardService.totalCount
    readonly property var clipboardEntries: ClipboardService.clipboardEntries
    readonly property var pinnedEntries: ClipboardService.pinnedEntries
    readonly property int pinnedCount: ClipboardService.pinnedCount
    readonly property var unpinnedEntries: ClipboardService.unpinnedEntries
    readonly property int selectedIndex: ClipboardService.selectedIndex
    readonly property bool keyboardNavigationActive: ClipboardService.keyboardNavigationActive
    property string searchText: ClipboardService.searchText
    onSearchTextChanged: ClipboardService.searchText = searchText

    Ref {
        service: ClipboardService
    }

    property string mode: "history"
    onModeChanged: {
        if (mode !== "history") {
            return;
        }
        Qt.callLater(function () {
            if (contentLoader.item?.searchField) {
                contentLoader.item.searchField.forceActiveFocus();
            }
        });
    }

    function updateFilteredModel() {
        ClipboardService.updateFilteredModel();
    }

    function pasteSelected() {
        ClipboardService.pasteSelected(instantClose);
    }

    function toggle() {
        if (shouldBeVisible) {
            hide();
        } else {
            show();
        }
    }

    function show() {
        if (!clipboardAvailable) {
            ToastService.showError(I18n.tr("Clipboard service not available"));
            return;
        }
        open();
        mode = "history";
        activeImageLoads = 0;
        shouldHaveFocus = true;
        ClipboardService.reset();
        ClipboardService.refresh();
        keyboardController.reset();

        Qt.callLater(function () {
            if (contentLoader.item?.searchField) {
                contentLoader.item.searchField.text = "";
                contentLoader.item.searchField.forceActiveFocus();
            }
        });
    }

    function hide() {
        close();
    }

    onDialogClosed: {
        activeImageLoads = 0;
        ClipboardService.reset();
        keyboardController.reset();
    }

    function refreshClipboard() {
        ClipboardService.refresh();
    }

    function copyEntry(entry) {
        ClipboardService.copyEntry(entry, hide);
    }

    function deleteEntry(entry) {
        ClipboardService.deleteEntry(entry);
    }

    function deletePinnedEntry(entry) {
        ClipboardService.deletePinnedEntry(entry, clearConfirmDialog);
    }

    function pinEntry(entry) {
        ClipboardService.pinEntry(entry);
    }

    function unpinEntry(entry) {
        ClipboardService.unpinEntry(entry);
    }

    function clearAll() {
        ClipboardService.clearAll();
    }

    function getEntryPreview(entry) {
        return ClipboardService.getEntryPreview(entry);
    }

    function getEntryType(entry) {
        return ClipboardService.getEntryType(entry);
    }

    function editEntry(entry) {
        if (!entry) {
            return;
        }
        if (entry.isImage) {
            return;
        }
        const editor = contentLoader.item?.editorView;
        if (!editor) {
            return;
        }
        editor.setEntry(entry);
        mode = "editor";
    }

    visible: false
    modalWidth: ClipboardConstants.modalWidth
    modalHeight: ClipboardConstants.modalHeight
    backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    cornerRadius: Theme.cornerRadius
    borderColor: Theme.outlineMedium
    borderWidth: 1
    enableShadow: true
    closeOnEscapeKey: mode !== "editor"
    onBackgroundClicked: hide()
    modalFocusScope.Keys.onPressed: function (event) {
        if (mode === "history" && (event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)) {
            activeTab = activeTab === "recents" ? "saved" : "recents";
            event.accepted = true;
            return;
        }
        if (mode === "history" && (event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
            const entries = activeTab === "saved" ? pinnedEntries : unpinnedEntries;
            if (entries && entries.length > 0) {
                const index = ClipboardService.selectedIndex >= 0 && ClipboardService.selectedIndex < entries.length ? ClipboardService.selectedIndex : 0;
                const entry = entries[index];
                if (activeTab === "saved") {
                    unpinEntry(entry);
                } else {
                    pinEntry(entry);
                }
            }
            event.accepted = true;
            return;
        }
        if (mode === "history" && (event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_E) {
            const entries = activeTab === "saved" ? pinnedEntries : unpinnedEntries;
            if (entries && entries.length > 0) {
                const index = ClipboardService.selectedIndex >= 0 && ClipboardService.selectedIndex < entries.length ? ClipboardService.selectedIndex : 0;
                editEntry(entries[index]);
            }
            event.accepted = true;
            return;
        }
        keyboardController.handleKey(event);
    }
    content: clipboardContent

    ClipboardKeyboardController {
        id: keyboardController
        modal: clipboardHistoryModal
    }

    ConfirmModal {
        id: clearConfirmDialog
        confirmButtonText: I18n.tr("Clear All")
        confirmButtonColor: Theme.primary
        onVisibleChanged: {
            if (visible) {
                clipboardHistoryModal.shouldHaveFocus = false;
                return;
            }
            Qt.callLater(function () {
                if (!clipboardHistoryModal.shouldBeVisible) {
                    return;
                }
                clipboardHistoryModal.shouldHaveFocus = true;
                clipboardHistoryModal.modalFocusScope.forceActiveFocus();
                if (clipboardHistoryModal.contentLoader.item?.searchField) {
                    clipboardHistoryModal.contentLoader.item.searchField.forceActiveFocus();
                }
            });
        }
    }

    property var confirmDialog: clearConfirmDialog

    clipboardContent: Component {
        Item {
            id: viewContainer

            property alias editorView: editorView
            property alias searchField: historyContent.searchField

            anchors.fill: parent

            Item {
                id: historyView

                anchors.fill: parent
                opacity: 1
                scale: 1
                visible: opacity > 0.01
                enabled: clipboardHistoryModal.mode === "history"

                ClipboardContent {
                    id: historyContent
                    anchors.fill: parent
                    modal: clipboardHistoryModal
                    clearConfirmDialog: clipboardHistoryModal.confirmDialog
                }
            }

            Item {
                id: editorView

                anchors.fill: parent
                opacity: 0
                scale: 0.98
                visible: opacity > 0.01
                enabled: clipboardHistoryModal.mode === "editor"
                focus: clipboardHistoryModal.mode === "editor"

                Shortcut {
                    sequences: ["Escape"]
                    enabled: clipboardHistoryModal.mode === "editor"
                    onActivated: clipboardHistoryModal.mode = "history"
                }

                property var entry: null
                property string editorText: ""

                function setEntry(newEntry) {
                    entry = newEntry;
                    editorText = newEntry?.text ?? newEntry?.preview ?? "";
                    if (editField) {
                        editField.text = editorText;
                    }
                    Qt.callLater(function () {
                        if (editField) {
                            editField.forceActiveFocus();
                        }
                    });
                }

                function saveEntry(action) {
                    const saveAction = action ?? "history";
                    DMSService.sendRequest("clipboard.copy", {
                        "text": editorView.editorText
                    }, function (response) {
                        if (response.error) {
                            ToastService.showError(I18n.tr("Failed to update clipboard"));
                            return;
                        }
                        if (saveAction === "history") {
                            clipboardHistoryModal.mode = "history";
                            clipboardHistoryModal.refreshClipboard();
                            return;
                        }
                        if (saveAction === "close") {
                            clipboardHistoryModal.hide();
                            return;
                        }
                        if (saveAction === "paste") {
                            ClipboardService.pasteClipboard(clipboardHistoryModal.hide);
                        }
                    });
                }

                function toggleSaveMenu() {
                    if (saveMenu.visible) {
                        saveMenu.close();
                        return;
                    }
                    saveMenu.open();
                    const pos = saveButton.mapToItem(Overlay.overlay, 0, 0);
                    const popupW = saveMenu.width;
                    const popupH = saveMenu.height;
                    const overlayW = Overlay.overlay.width;
                    const overlayH = Overlay.overlay.height;

                    let x = pos.x + (saveButton.width - popupW) / 2;
                    let y = pos.y + saveButton.height + 4;
                    if (y + popupH > overlayH) {
                        y = pos.y - popupH - 4;
                    }

                    x = Math.max(8, Math.min(x, overlayW - popupW - 8));
                    y = Math.max(8, y);

                    saveMenu.x = x;
                    saveMenu.y = y;
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingM

                    Item {
                        width: parent.width
                        height: ClipboardConstants.headerHeight

                        DankActionButton {
                            iconName: "arrow_back"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: clipboardHistoryModal.mode = "history"
                        }

                        StyledText {
                            text: I18n.tr("Edit Clipboard")
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.centerIn: parent
                        }

                        DankActionButton {
                            iconName: "close"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: clipboardHistoryModal.mode = "history"
                        }
                    }

                    StyledRect {
                        id: editFieldContainer
                        width: parent.width
                        height: Math.max(Theme.fontSizeMedium * 8, Theme.fontSizeMedium * 3)
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                        border.color: editField.activeFocus ? Theme.primary : Theme.outlineMedium
                        border.width: editField.activeFocus ? 2 : 1
                        clip: true

                        DankIcon {
                            id: editIcon
                            name: "edit"
                            size: Theme.iconSize
                            color: editField.activeFocus ? Theme.primary : Theme.surfaceVariantText
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.top: parent.top
                            anchors.topMargin: Theme.spacingM
                        }

                        TextEdit {
                            id: editField
                            anchors.left: editIcon.right
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: Theme.spacingM
                            anchors.topMargin: Theme.spacingS
                            anchors.bottomMargin: Theme.spacingS
                            text: editorView.editorText
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            Keys.forwardTo: [clipboardHistoryModal.modalFocusScope]
                            onTextChanged: editorView.editorText = text
                            Keys.onPressed: function (event) {
                                const hasCtrl = (event.modifiers & Qt.ControlModifier) !== 0;
                                const hasShift = (event.modifiers & Qt.ShiftModifier) !== 0;

                                if (hasCtrl && event.key === Qt.Key_S) {
                                    editorView.saveEntry(hasShift ? "close" : "history");
                                    event.accepted = true;
                                    return;
                                }
                                if (hasCtrl && hasShift && event.key === Qt.Key_V) {
                                    editorView.saveEntry("paste");
                                    event.accepted = true;
                                    return;
                                }
                            }
                        }

                        StyledText {
                            text: I18n.tr("Edit clipboard text")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.outlineButton
                            anchors.left: editField.left
                            anchors.right: editField.right
                            anchors.top: editField.top
                            anchors.bottom: editField.bottom
                            visible: editField.text.length === 0 && !editField.activeFocus
                            wrapMode: Text.WordWrap
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        Item {
                            id: buttonSpacer
                            width: Math.max(0, parent.width - cancelButton.width - saveButton.width - Theme.spacingS)
                            height: 1
                        }

                        DankButton {
                            id: cancelButton
                            text: I18n.tr("Cancel")
                            backgroundColor: Theme.surfaceContainerHigh
                            textColor: Theme.surfaceText
                            onClicked: clipboardHistoryModal.mode = "history"
                        }

                        Item {
                            id: saveButton
                            property int arrowWidth: 32
                            property int horizontalPadding: Theme.spacingL
                            width: cancelButton.width
                            height: 40

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.cornerRadius
                                color: Theme.primary
                            }

                            Item {
                                id: saveMainArea
                                anchors.left: parent.left
                                anchors.right: saveArrowArea.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                            }

                            StyledText {
                                id: saveLabel
                                text: I18n.tr("Save")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.onPrimary
                                anchors.centerIn: saveMainArea
                            }

                            Item {
                                id: saveArrowArea
                                width: saveButton.arrowWidth
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                            }

                            Rectangle {
                                width: 1
                                height: parent.height - Theme.spacingM
                                color: Theme.withAlpha(Theme.onPrimary, 0.2)
                                anchors.right: saveArrowArea.left
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            DankIcon {
                                name: saveMenu.visible ? "expand_less" : "expand_more"
                                size: Theme.iconSizeSmall
                                color: Theme.onPrimary
                                anchors.centerIn: saveArrowArea
                            }

                            StateLayer {
                                anchors.fill: saveMainArea
                                stateColor: Theme.onPrimary
                                onClicked: editorView.saveEntry("history")
                            }

                            StateLayer {
                                anchors.fill: saveArrowArea
                                stateColor: Theme.onPrimary
                                onClicked: editorView.toggleSaveMenu()
                            }
                        }
                    }

                    Popup {
                        id: saveMenu
                        parent: Overlay.overlay
                        width: 220
                        padding: Theme.spacingM
                        modal: false
                        focus: true
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                        background: StyledRect {
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainer
                            border.color: Theme.outlineMedium
                            border.width: 1
                        }

                        contentItem: Column {
                            id: saveMenuColumn
                            spacing: Theme.spacingXS

                            StyledRect {
                                width: saveMenu.width - saveMenu.padding * 2
                                height: 32
                                radius: Theme.cornerRadius
                                color: saveMenuSaveArea.containsMouse ? Theme.surfaceVariant : "transparent"

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingS
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: "save"
                                        size: Theme.iconSizeSmall
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: I18n.tr("Save")
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: saveMenuSaveArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        saveMenu.close();
                                        editorView.saveEntry("history");
                                    }
                                }
                            }

                            StyledRect {
                                width: saveMenu.width - saveMenu.padding * 2
                                height: 32
                                radius: Theme.cornerRadius
                                color: saveMenuCloseArea.containsMouse ? Theme.surfaceVariant : "transparent"

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingS
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: "close"
                                        size: Theme.iconSizeSmall
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: I18n.tr("Save and close")
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: saveMenuCloseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        saveMenu.close();
                                        editorView.saveEntry("close");
                                    }
                                }
                            }

                            StyledRect {
                                width: saveMenu.width - saveMenu.padding * 2
                                height: 32
                                radius: Theme.cornerRadius
                                color: saveMenuPasteArea.containsMouse ? Theme.surfaceVariant : "transparent"
                                opacity: clipboardHistoryModal.wtypeAvailable ? 1 : 0.5

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingS
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: "content_paste"
                                        size: Theme.iconSizeSmall
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: I18n.tr("Save and paste")
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: saveMenuPasteArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: clipboardHistoryModal.wtypeAvailable
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        saveMenu.close();
                                        editorView.saveEntry("paste");
                                    }
                                }
                            }
                        }
                    }
                }
            }

            states: [
                State {
                    name: "history"
                    when: clipboardHistoryModal.mode === "history"
                    PropertyChanges {
                        target: historyView
                        opacity: 1
                        scale: 1
                    }
                    PropertyChanges {
                        target: editorView
                        opacity: 0
                        scale: 0.98
                    }
                },
                State {
                    name: "editor"
                    when: clipboardHistoryModal.mode === "editor"
                    PropertyChanges {
                        target: historyView
                        opacity: 0
                        scale: 0.98
                    }
                    PropertyChanges {
                        target: editorView
                        opacity: 1
                        scale: 1
                    }
                }
            ]

            transitions: [
                Transition {
                    from: "history"
                    to: "editor"
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                        NumberAnimation {
                            property: "scale"
                            duration: Theme.shortDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }
                },
                Transition {
                    from: "editor"
                    to: "history"
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                        NumberAnimation {
                            property: "scale"
                            duration: Theme.shortDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }
                }
            ]
        }
    }
}
