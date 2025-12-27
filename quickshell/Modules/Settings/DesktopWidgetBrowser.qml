pragma ComponentBehavior

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

FloatingWindow {
    id: root

    property string searchQuery: ""
    property var filteredWidgets: []
    property int selectedIndex: -1
    property bool keyboardNavigationActive: false
    property var parentModal: null

    signal widgetAdded(string widgetType)

    function updateFilteredWidgets() {
        const allWidgets = DesktopWidgetRegistry.registeredWidgetsList || [];
        if (!searchQuery || searchQuery.length === 0) {
            filteredWidgets = allWidgets.slice();
            return;
        }

        var filtered = [];
        var query = searchQuery.toLowerCase();

        for (var i = 0; i < allWidgets.length; i++) {
            var widget = allWidgets[i];
            var name = widget.name ? widget.name.toLowerCase() : "";
            var description = widget.description ? widget.description.toLowerCase() : "";
            var id = widget.id ? widget.id.toLowerCase() : "";

            if (name.indexOf(query) !== -1 || description.indexOf(query) !== -1 || id.indexOf(query) !== -1)
                filtered.push(widget);
        }

        filteredWidgets = filtered;
        selectedIndex = -1;
        keyboardNavigationActive = false;
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
        addWidget(widget);
    }

    function addWidget(widget) {
        const widgetType = widget.id;
        const defaultConfig = DesktopWidgetRegistry.getDefaultConfig(widgetType);
        const name = widget.name || widgetType;
        SettingsData.createDesktopWidgetInstance(widgetType, name, defaultConfig);
        root.widgetAdded(widgetType);
        root.hide();
    }

    function show() {
        updateFilteredWidgets();
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

    objectName: "desktopWidgetBrowser"
    title: I18n.tr("Add Desktop Widget")
    minimumSize: Qt.size(400, 350)
    implicitWidth: 500
    implicitHeight: 550
    color: Theme.surfaceContainer
    visible: false

    onVisibleChanged: {
        if (visible) {
            updateFilteredWidgets();
            Qt.callLater(() => {
                searchField.forceActiveFocus();
            });
            return;
        }
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

    Connections {
        target: DesktopWidgetRegistry
        function onRegistryChanged() {
            if (root.visible)
                root.updateFilteredWidgets();
        }
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
                    root.addWidget(root.filteredWidgets[0]);
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
                    color: Theme.withAlpha(Theme.surfaceContainer, 0.5)
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
                        text: I18n.tr("Add Desktop Widget")
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
                        text: I18n.tr("Select a widget to add to your desktop. Each widget is a separate instance with its own settings.")
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
                        backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
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
                            root.updateFilteredWidgets();
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
                            id: delegateRoot

                            required property var modelData
                            required property int index

                            width: widgetList.width
                            height: 72
                            radius: Theme.cornerRadius
                            property bool isSelected: root.keyboardNavigationActive && index === root.selectedIndex
                            color: isSelected ? Theme.primarySelected : widgetArea.containsMouse ? Theme.primaryHover : Theme.withAlpha(Theme.surfaceVariant, 0.3)
                            border.color: isSelected ? Theme.primary : Theme.withAlpha(Theme.outline, 0.2)
                            border.width: isSelected ? 2 : 1

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM

                                Rectangle {
                                    width: 44
                                    height: 44
                                    radius: Theme.cornerRadius
                                    color: Theme.primarySelected
                                    anchors.verticalCenter: parent.verticalCenter

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: delegateRoot.modelData.icon || "widgets"
                                        size: Theme.iconSize
                                        color: Theme.primary
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    width: parent.width - 44 - Theme.iconSize - Theme.spacingM * 3

                                    Row {
                                        spacing: Theme.spacingS

                                        StyledText {
                                            text: delegateRoot.modelData.name || delegateRoot.modelData.id
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Medium
                                            color: Theme.surfaceText
                                        }

                                        Rectangle {
                                            visible: delegateRoot.modelData.type === "plugin"
                                            width: pluginLabel.implicitWidth + Theme.spacingXS * 2
                                            height: 18
                                            radius: 9
                                            color: Theme.withAlpha(Theme.secondary, 0.15)
                                            anchors.verticalCenter: parent.verticalCenter

                                            StyledText {
                                                id: pluginLabel
                                                anchors.centerIn: parent
                                                text: I18n.tr("Plugin")
                                                font.pixelSize: Theme.fontSizeSmall - 2
                                                color: Theme.secondary
                                            }
                                        }
                                    }

                                    StyledText {
                                        text: delegateRoot.modelData.description || ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.outline
                                        elide: Text.ElideRight
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        visible: text !== ""
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
                                onClicked: root.addWidget(delegateRoot.modelData)
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }

                        footer: Item {
                            width: widgetList.width
                            height: emptyText.visible ? 60 : 0

                            StyledText {
                                id: emptyText
                                visible: root.filteredWidgets.length === 0
                                text: root.searchQuery.length > 0 ? I18n.tr("No widgets match your search") : I18n.tr("No widgets available")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                anchors.centerIn: parent
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
