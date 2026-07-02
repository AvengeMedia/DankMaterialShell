import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

FloatingWindow {
    id: root

    property bool disablePopupTransparency: true
    property string searchQuery: ""
    property var filteredApps: []
    property int selectedIndex: -1
    property bool keyboardNavigationActive: false
    property var appsModel: []
    property var parentModal: null
    parentWindow: parentModal

    signal appSelected(string appId)

    objectName: "appBrowserPopup"
    title: I18n.tr("Select Application")
    minimumSize: Qt.size(400, 350)
    implicitWidth: 500
    implicitHeight: 550
    color: "transparent"
    visible: false

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
        color: Theme.withAlpha(Theme.surfaceContainer, 0.95)
        border.color: Theme.outlineMedium
        border.width: Theme.layerOutlineWidth
    }

    FocusScope {
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
                    root.selectApp();
                } else if (root.filteredApps.length > 0) {
                    root.selectAppByIndex(0);
                }
                event.accepted = true;
                return;
            }
        }

        Column {
            anchors.fill: parent
            spacing: 0

            Item {
                width: parent.width
                height: 48

                MouseArea {
                    anchors.fill: parent
                    onPressed: windowControls.tryStartMove()
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
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
                        text: I18n.tr("Select Application")
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
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: root.hide()
                    }
                }
            }

            Item {
                width: parent.width
                height: parent.height - 48

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    DankTextField {
                        id: searchField
                        width: parent.width
                        height: 48
                        cornerRadius: Theme.cornerRadius
                        backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, 0.8)
                        normalBorderColor: Theme.outlineMedium
                        focusedBorderColor: Theme.primary
                        leftIconName: "search"
                        leftIconSize: Theme.iconSize
                        leftIconColor: Theme.surfaceVariantText
                        leftIconFocusedColor: Theme.primary
                        showClearButton: true
                        textColor: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        placeholderText: I18n.tr("Search applications...")
                        text: root.searchQuery
                        onTextEdited: {
                            root.searchQuery = text;
                            root.updateFilteredApps();
                        }
                    }

                    DankListView {
                        id: appList
                        width: parent.width
                        height: parent.height - searchField.height - Theme.spacingM
                        spacing: Theme.spacingS
                        model: root.filteredApps
                        clip: true

                        delegate: Rectangle {
                            width: appList.width
                            height: 60
                            radius: Theme.cornerRadius
                            required property int index
                            required property var modelData

                            readonly property bool isSelected: root.keyboardNavigationActive && index === root.selectedIndex

                            color: isSelected ? Theme.withAlpha(Theme.primary, 0.16) : appArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.08) : Theme.withAlpha(Theme.surfaceVariant, 0.3)
                            border.color: isSelected ? Theme.primary : Theme.outlineMedium
                            border.width: isSelected ? 2 : Theme.layerOutlineWidth

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM

                                Image {
                                    width: 28
                                    height: 28
                                    source: Paths.resolveIconUrl(modelData.icon || "application-x-executable")
                                    sourceSize.width: 28
                                    sourceSize.height: 28
                                    fillMode: Image.PreserveAspectFit
                                    anchors.verticalCenter: parent.verticalCenter
                                    onStatusChanged: {
                                        if (status === Image.Error)
                                            source = "image://icon/application-x-executable";
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingXXS
                                    width: parent.width - 28 - Theme.spacingM * 3 - 24

                                    StyledText {
                                        text: modelData.name || modelData.id || ""
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }

                                    StyledText {
                                        text: modelData.comment || modelData.genericName || ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.outline
                                        elide: Text.ElideRight
                                        width: parent.width
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
                                id: appArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const appId = modelData.id || modelData.execString || "";
                                    root.appSelected(appId);
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

        FloatingWindowControls {
            id: windowControls
            targetWindow: root
        }
    }

    function updateFilteredApps() {
        const allApps = root.appsModel || [];
        var filtered = [];
        if (!searchQuery || searchQuery.length === 0) {
            filtered = allApps.slice();
        } else {
            var query = searchQuery.toLowerCase();
            for (var i = 0; i < allApps.length; i++) {
                var app = allApps[i];
                var name = (app.name || "").toLowerCase();
                var id = (app.id || "").toLowerCase();
                var comment = (app.comment || app.genericName || "").toLowerCase();
                if (name.indexOf(query) !== -1 || id.indexOf(query) !== -1 || comment.indexOf(query) !== -1)
                    filtered.push(app);
            }
        }
        filteredApps = filtered;
        selectedIndex = -1;
        keyboardNavigationActive = false;
    }

    function selectNext() {
        if (filteredApps.length === 0)
            return;
        keyboardNavigationActive = true;
        selectedIndex = Math.min(selectedIndex + 1, filteredApps.length - 1);
    }

    function selectPrevious() {
        if (filteredApps.length === 0)
            return;
        keyboardNavigationActive = true;
        selectedIndex = Math.max(selectedIndex - 1, -1);
        if (selectedIndex === -1)
            keyboardNavigationActive = false;
    }

    function selectApp() {
        if (selectedIndex < 0 || selectedIndex >= filteredApps.length)
            return;
        selectAppByIndex(selectedIndex);
    }

    function selectAppByIndex(idx) {
        const app = filteredApps[idx];
        if (!app)
            return;
        root.appSelected(app.id || app.execString || "");
        hide();
    }

    function show() {
        updateFilteredApps();
        visible = true;
        Qt.callLater(() => searchField.forceActiveFocus());
    }

    function hide() {
        visible = false;
        searchQuery = "";
        filteredApps = [];
        selectedIndex = -1;
        keyboardNavigationActive = false;
    }

    onVisibleChanged: {
        if (!visible) {
            searchQuery = "";
            filteredApps = [];
            selectedIndex = -1;
            keyboardNavigationActive = false;
        }
    }
}
