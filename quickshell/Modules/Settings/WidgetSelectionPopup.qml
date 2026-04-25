import QtQuick
import Quickshell
import qs.Common
import qs.Widgets

FloatingWindow {
    id: root

    property bool disablePopupTransparency: true
    property var allWidgets: []
    property string targetSection: ""
    property string searchQuery: ""
    property var filteredWidgets: []
    property int selectedIndex: -1
    property bool keyboardNavigationActive: false
    property var parentModal: null
    readonly property bool blurActive: Theme.blurForegroundLayers || Theme.transparentBlurLayers
    readonly property real surfaceAlpha: blurActive ? Math.min(Theme.popupTransparency, Theme.transparentBlurLayers ? 0.36 : 0.78) : 1.0
    readonly property real fieldAlpha: blurActive ? Math.min(Theme.popupTransparency, Theme.transparentBlurLayers ? 0.18 : 0.62) : 1.0
    readonly property real rowAlpha: blurActive ? Math.min(Theme.popupTransparency, Theme.transparentBlurLayers ? 0.12 : 0.52) : 0.30

    signal widgetSelected(string widgetId, string targetSection)

    function updateFilteredWidgets() {
        if (!searchQuery || searchQuery.length === 0) {
            filteredWidgets = allWidgets.slice();
            return;
        }

        var filtered = [];
        var query = searchQuery.toLowerCase();

        for (var i = 0; i < allWidgets.length; i++) {
            var widget = allWidgets[i];
            var text = widget.text ? widget.text.toLowerCase() : "";
            var description = widget.description ? widget.description.toLowerCase() : "";
            var id = widget.id ? widget.id.toLowerCase() : "";

            if (text.indexOf(query) !== -1 || description.indexOf(query) !== -1 || id.indexOf(query) !== -1)
                filtered.push(widget);
        }

        filteredWidgets = filtered;
        selectedIndex = -1;
        keyboardNavigationActive = false;
    }

    onAllWidgetsChanged: {
        updateFilteredWidgets();
    }

    function selectNext() {
        if (filteredWidgets.length === 0)
            return;
        keyboardNavigationActive = true;
        selectedIndex = Math.min(selectedIndex + 1, filteredWidgets.length - 1);
    }

    function selectPrevious() {
        if (filteredWidgets.length === 0)
            return;
        keyboardNavigationActive = true;
        selectedIndex = Math.max(selectedIndex - 1, -1);
        if (selectedIndex === -1)
            keyboardNavigationActive = false;
    }

    function selectWidget() {
        if (selectedIndex < 0 || selectedIndex >= filteredWidgets.length)
            return;
        var widget = filteredWidgets[selectedIndex];
        root.widgetSelected(widget.id, root.targetSection);
        root.hide();
    }

    function show() {
        if (parentModal)
            parentModal.shouldHaveFocus = false;
        visible = true;
        Qt.callLater(() => {
            searchField.forceActiveFocus();
        });
    }

    function hide() {
        visible = false;
        if (!parentModal)
            return;
        parentModal.shouldHaveFocus = Qt.binding(() => parentModal.shouldBeVisible);
        Qt.callLater(() => {
            if (parentModal && parentModal.modalFocusScope)
                parentModal.modalFocusScope.forceActiveFocus();
        });
    }

    objectName: "widgetSelectionPopup"
    title: I18n.tr("Add Widget")
    minimumSize: Qt.size(400, 350)
    implicitWidth: 500
    implicitHeight: 550
    color: blurActive ? "transparent" : Theme.surfaceContainer
    visible: false

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(() => {
                searchField.forceActiveFocus();
            });
            return;
        }
        allWidgets = [];
        targetSection = "";
        searchQuery = "";
        filteredWidgets = [];
        selectedIndex = -1;
        keyboardNavigationActive = false;
        if (!parentModal)
            return;
        parentModal.shouldHaveFocus = Qt.binding(() => parentModal.shouldBeVisible);
        Qt.callLater(() => {
            if (parentModal && parentModal.modalFocusScope)
                parentModal.modalFocusScope.forceActiveFocus();
        });
    }

    WindowBlur {
        targetWindow: root
        blurX: 0
        blurY: 0
        blurWidth: root.visible ? root.width : 0
        blurHeight: root.visible ? root.height : 0
        blurRadius: Theme.cornerRadius
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainer, root.surfaceAlpha)
        border.color: root.blurActive ? Theme.outlineMedium : "transparent"
        border.width: root.blurActive ? Theme.layerOutlineWidth : 0
        antialiasing: true
    }

    FocusScope {
        id: widgetKeyHandler

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                root.hide();
                event.accepted = true;
                return;
            case Qt.Key_Down:
                root.selectNext();
                event.accepted = true;
                return;
            case Qt.Key_Up:
                root.selectPrevious();
                event.accepted = true;
                return;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (root.keyboardNavigationActive) {
                    root.selectWidget();
                } else if (root.filteredWidgets.length > 0) {
                    var firstWidget = root.filteredWidgets[0];
                    root.widgetSelected(firstWidget.id, root.targetSection);
                    root.hide();
                }
                event.accepted = true;
                return;
            }
            if (event.modifiers & Qt.ControlModifier) {
                switch (event.key) {
                case Qt.Key_N:
                case Qt.Key_J:
                    root.selectNext();
                    event.accepted = true;
                    return;
                case Qt.Key_P:
                case Qt.Key_K:
                    root.selectPrevious();
                    event.accepted = true;
                    return;
                }
            }
        }

        Column {
            anchors.fill: parent
            spacing: 0

            Item {
                id: titleBar
                width: parent.width
                height: 48

                MouseArea {
                    anchors.fill: parent
                    onPressed: windowControls.tryStartMove()
                    onDoubleClicked: windowControls.tryToggleMaximize()
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, root.blurActive ? 0.20 : 0.50)
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingL
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "add_circle"
                        size: Theme.iconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: I18n.tr("Add Widget to %1 Section").arg(root.targetSection)
                        font.pixelSize: Theme.fontSizeXLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    DankActionButton {
                        visible: windowControls.supported
                        circular: false
                        iconName: root.maximized ? "fullscreen_exit" : "fullscreen"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: windowControls.tryToggleMaximize()
                    }

                    DankActionButton {
                        circular: false
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: root.hide()
                    }
                }
            }

            Item {
                width: parent.width
                height: parent.height - titleBar.height

                Column {
                    id: contentColumn
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    StyledText {
                        text: I18n.tr("Select a widget to add. You can add multiple instances of the same widget if needed.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.outline
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }

                    DankTextField {
                        id: searchField
                        width: parent.width
                        height: 48
                        cornerRadius: Theme.cornerRadius
                        backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, root.fieldAlpha)
                        normalBorderColor: Theme.outlineMedium
                        focusedBorderColor: Theme.primary
                        leftIconName: "search"
                        leftIconSize: Theme.iconSize
                        leftIconColor: Theme.surfaceVariantText
                        leftIconFocusedColor: Theme.primary
                        showClearButton: true
                        textColor: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        placeholderText: I18n.tr("Search widgets...")
                        text: root.searchQuery
                        focus: true
                        ignoreLeftRightKeys: true
                        keyForwardTargets: [widgetKeyHandler]
                        onTextEdited: {
                            root.searchQuery = text;
                            updateFilteredWidgets();
                        }
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                root.hide();
                                event.accepted = true;
                                return;
                            }
                            if (event.key === Qt.Key_Down || event.key === Qt.Key_Up || ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && text.length === 0))
                                event.accepted = false;
                        }
                    }

                    DankListView {
                        id: widgetList

                        width: parent.width
                        height: parent.height - y
                        spacing: Theme.spacingS
                        model: root.filteredWidgets
                        clip: true

                        delegate: Rectangle {
                            width: widgetList.width
                            height: 60
                            radius: Theme.cornerRadius
                            property bool isSelected: root.keyboardNavigationActive && index === root.selectedIndex
                            color: isSelected ? Theme.withAlpha(Theme.primary, root.blurActive ? 0.22 : 0.16) : widgetArea.containsMouse ? Theme.withAlpha(Theme.primary, root.blurActive ? 0.14 : 0.08) : Theme.withAlpha(Theme.surfaceVariant, root.rowAlpha)
                            border.color: isSelected ? Theme.primary : Theme.outlineMedium
                            border.width: isSelected ? 2 : Theme.layerOutlineWidth
                            antialiasing: true

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM

                                DankIcon {
                                    name: modelData.icon
                                    size: Theme.iconSize
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    width: parent.width - Theme.iconSize - Theme.spacingM * 3

                                    StyledText {
                                        text: modelData.text
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }

                                    StyledText {
                                        text: modelData.description
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.outline
                                        elide: Text.ElideRight
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                DankIcon {
                                    name: "add"
                                    size: Theme.iconSize - 4
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: widgetArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.widgetSelected(modelData.id, root.targetSection);
                                    root.hide();
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: root
    }
}
