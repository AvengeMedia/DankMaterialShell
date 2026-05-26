pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    required property var modal
    property var keyController: null

    property var entry: null
    property string editorText: ""

    function decodeEntryData(data) {
        if (!data) {
            return "";
        }
        if (typeof data !== "string") {
            return String(data);
        }

        const sanitized = data.replace(/\s+/g, "");
        if (sanitized.length === 0) {
            return "";
        }

        try {
            const decoded = Qt.atob(sanitized);
            if (!decoded) {
                return data;
            }

            let binary = "";
            if (typeof decoded === "string") {
                // Pre-6.11 Qt.atob returns a binary string directly
                binary = decoded;
            } else {
                // Qt 6.11+ Qt.atob returns an ArrayBuffer — convert to avoid O(n²) concat/stack limits
                const bytes = new Uint8Array(decoded);
                const chunkSize = 8192;
                const chunks = [];
                for (let i = 0; i < bytes.length; i += chunkSize) {
                    chunks.push(String.fromCharCode.apply(null, bytes.subarray(i, i + chunkSize)));
                }
                binary = chunks.join("");
            }

            if (!binary) {
                return data;
            }
            try {
                return decodeURIComponent(escape(binary));
            } catch (e) {
                return binary;
            }
        } catch (e) {
            return data;
        }
    }

    function setEntry(newEntry) {
        entry = newEntry;
        editorText = newEntry?.text ?? newEntry?.preview ?? "";
        if (editField) {
            editField.text = editorText;
        }
        Qt.callLater(function () {
            if (editField) {
                editField.forceActiveFocus();
                editField.cursorPosition = editField.text.length;
            }
        });

        if (!newEntry || newEntry.isImage) {
            return;
        }

        const requestedId = newEntry.id;
        DMSService.sendRequest("clipboard.getEntry", {
            "id": requestedId
        }, function (response) {
            if (response.error) {
                return;
            }
            if (!root.entry || root.entry.id !== requestedId) {
                return;
            }
            const result = response.result;
            let fullText = "";
            if (result?.data) {
                fullText = root.decodeEntryData(result.data);
            } else {
                fullText = result?.preview ?? "";
            }

            if (!fullText || fullText.length === 0) {
                return;
            }
            root.editorText = fullText;
            if (editField) {
                if (fullText.length > 50000) {
                    Qt.callLater(function () {
                        if (editField) {
                            editField.text = fullText;
                            editField.cursorPosition = fullText.length;
                        }
                    });
                } else {
                    editField.text = fullText;
                    editField.cursorPosition = fullText.length;
                }
            }
        });
    }

    function saveEntry(action) {
        const saveAction = action ?? "history";
        DMSService.sendRequest("clipboard.copy", {
            "text": root.editorText
        }, function (response) {
            if (response.error) {
                ToastService.showError(I18n.tr("Failed to update clipboard"));
                return;
            }
            if (saveAction === "history") {
                modal.mode = "history";
                Qt.callLater(function () {
                    ClipboardService.reset();
                    ClipboardService.refresh();
                    if (keyController) {
                        keyController.reset();
                    }
                });
                return;
            }
            if (saveAction === "close") {
                modal.hide();
                return;
            }
            if (saveAction === "paste") {
                ClipboardService.pasteClipboard(modal.hide);
            }
        });
    }

    function positionSaveMenu() {
        saveMenu.width = Math.max(saveMenuColumn.implicitWidth + saveMenu.padding * 2, saveButton.width);
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

    function toggleSaveMenu() {
        if (saveMenu.visible) {
            saveMenu.close();
            return;
        }
        saveMenu.open();
        positionSaveMenu();
        Qt.callLater(positionSaveMenu);
    }

    Shortcut {
        sequences: ["Escape"]
        enabled: modal.mode === "editor"
        onActivated: modal.mode = "history"
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingM

        Item {
            id: editorHeader
            width: parent.width
            height: ClipboardConstants.headerHeight

            DankActionButton {
                iconName: "arrow_back"
                iconSize: Theme.iconSize - 4
                iconColor: Theme.surfaceText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                onClicked: modal.mode = "history"
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
                onClicked: modal.mode = "history"
            }
        }

        StyledRect {
            id: editFieldContainer
            width: parent.width
            height: Math.max(Theme.fontSizeMedium * 8, parent.height - editorHeader.height - editorActions.height - Theme.spacingM * 2)
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

            DankFlickable {
                id: editScroll
                anchors.left: editIcon.right
                anchors.leftMargin: Theme.spacingS
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.rightMargin: Theme.spacingM
                anchors.topMargin: Theme.spacingS
                anchors.bottomMargin: Theme.spacingS
                clip: true
                contentWidth: width
                contentHeight: editField.height

                TextEdit {
                    id: editField
                    width: editScroll.width
                    height: Math.max(editScroll.height, contentHeight)
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    onTextChanged: root.editorText = text
                    Keys.onPressed: function (event) {
                        const hasCtrl = (event.modifiers & Qt.ControlModifier) !== 0;
                        const hasShift = (event.modifiers & Qt.ShiftModifier) !== 0;

                        if (hasCtrl && event.key === Qt.Key_S) {
                            root.saveEntry(hasShift ? "close" : "history");
                            event.accepted = true;
                            return;
                        }
                        if (hasCtrl && hasShift && event.key === Qt.Key_V) {
                            root.saveEntry("paste");
                            event.accepted = true;
                            return;
                        }
                    }
                }
            }

            StyledText {
                text: I18n.tr("Edit clipboard text")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.outlineButton
                anchors.left: editScroll.left
                anchors.right: editScroll.right
                anchors.top: editScroll.top
                anchors.bottom: editScroll.bottom
                visible: editField.text.length === 0 && !editField.activeFocus
                wrapMode: Text.WordWrap
            }
        }

        Row {
            id: editorActions
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
                onClicked: modal.mode = "history"
            }

            Item {
                id: saveButton

                readonly property int buttonHeight: cancelButton.buttonHeight
                readonly property int arrowWidth: Theme.iconSizeLarge

                width: cancelButton.width
                height: buttonHeight

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
                    height: parent.height - cancelButton.horizontalPadding
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
                    z: 1
                    anchors.fill: saveMainArea
                    stateColor: Theme.onPrimary
                    onClicked: root.saveEntry("history")
                }

                StateLayer {
                    z: 1
                    anchors.fill: saveArrowArea
                    stateColor: Theme.onPrimary
                    onClicked: root.toggleSaveMenu()
                }
            }
        }

        Popup {
            id: saveMenu
            parent: Overlay.overlay
            padding: Theme.spacingM
            modal: true
            dim: false
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
                    implicitWidth: saveMenuRow.implicitWidth + Theme.spacingS * 2
                    implicitHeight: saveMenuRow.implicitHeight + Theme.spacingS * 2
                    radius: Theme.cornerRadius
                    color: saveMenuSaveArea.containsMouse ? Theme.surfaceVariant : "transparent"

                    Row {
                        id: saveMenuRow
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "save"
                            size: Theme.iconSizeSmall
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: I18n.tr("Save")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                        }
                    }

                    MouseArea {
                        id: saveMenuSaveArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            saveMenu.close();
                            root.saveEntry("history");
                        }
                    }
                }

                StyledRect {
                    implicitWidth: saveMenuCloseRow.implicitWidth + Theme.spacingS * 2
                    implicitHeight: saveMenuCloseRow.implicitHeight + Theme.spacingS * 2
                    radius: Theme.cornerRadius
                    color: saveMenuCloseArea.containsMouse ? Theme.surfaceVariant : "transparent"

                    Row {
                        id: saveMenuCloseRow
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "close"
                            size: Theme.iconSizeSmall
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: I18n.tr("Save and close")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                        }
                    }

                    MouseArea {
                        id: saveMenuCloseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            saveMenu.close();
                            root.saveEntry("close");
                        }
                    }
                }

                StyledRect {
                    implicitWidth: saveMenuPasteRow.implicitWidth + Theme.spacingS * 2
                    implicitHeight: saveMenuPasteRow.implicitHeight + Theme.spacingS * 2
                    radius: Theme.cornerRadius
                    color: saveMenuPasteArea.containsMouse ? Theme.surfaceVariant : "transparent"
                    opacity: modal.wtypeAvailable ? 1 : 0.5

                    Row {
                        id: saveMenuPasteRow
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "content_paste"
                            size: Theme.iconSizeSmall
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: I18n.tr("Save and paste")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                        }
                    }

                    MouseArea {
                        id: saveMenuPasteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: modal.wtypeAvailable
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            saveMenu.close();
                            root.saveEntry("paste");
                        }
                    }
                }
            }
        }
    }
}
