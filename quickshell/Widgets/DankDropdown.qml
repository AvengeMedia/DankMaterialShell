import "../Common/fzf.js" as Fzf
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    function checkParentDisablesTransparency() {
        let p = parent;
        while (p) {
            if (p.disablePopupTransparency === true)
                return true;
            p = p.parent;
        }
        return false;
    }

    property string text: ""
    property string description: ""
    property string currentValue: ""
    property var options: []
    property var optionIcons: []
    property bool enableFuzzySearch: false
    property var optionIconMap: ({})

    function rebuildIconMap() {
        const map = {};
        for (let i = 0; i < options.length; i++) {
            if (optionIcons.length > i)
                map[options[i]] = optionIcons[i];
        }
        optionIconMap = map;
    }

    onOptionsChanged: rebuildIconMap()
    onOptionIconsChanged: rebuildIconMap()

    property int popupWidthOffset: 0
    property int maxPopupHeight: 400
    property bool openUpwards: false
    property int popupWidth: 0
    property bool alignPopupRight: false
    property int dropdownWidth: 200
    property bool compactMode: text === "" && description === ""
    property bool addHorizontalPadding: false
    property string emptyText: ""
    property bool usePopupTransparency: !checkParentDisablesTransparency()

    signal valueChanged(string value)

    function closeDropdownMenu() {
        dropdownMenu.close();
    }

    width: compactMode ? dropdownWidth : parent.width
    implicitHeight: compactMode ? 40 : Math.max(60, labelColumn.implicitHeight + Theme.spacingM)

    Component.onDestruction: {
        if (dropdownMenu.visible)
            dropdownMenu.close();
    }

    Column {
        id: labelColumn

        anchors.left: parent.left
        anchors.right: dropdown.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.addHorizontalPadding ? Theme.spacingM : 0
        anchors.rightMargin: Theme.spacingL
        spacing: Theme.spacingXS
        visible: !root.compactMode

        StyledText {
            text: root.text
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
            font.weight: Font.Medium
            width: parent.width
            horizontalAlignment: Text.AlignLeft
        }

        StyledText {
            text: root.description
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            visible: description.length > 0
            wrapMode: Text.WordWrap
            width: parent.width
            horizontalAlignment: Text.AlignLeft
        }
    }

    Rectangle {
        id: dropdown

        width: root.compactMode ? parent.width : (root.popupWidth === -1 ? undefined : (root.popupWidth > 0 ? root.popupWidth : root.dropdownWidth))
        height: 40
        anchors.right: parent.right
        anchors.rightMargin: root.addHorizontalPadding && !root.compactMode ? Theme.spacingM : 0
        anchors.verticalCenter: parent.verticalCenter
        radius: Theme.cornerRadius
        color: dropdownArea.containsMouse || dropdownMenu.visible ? Theme.surfaceContainerHigh : (root.usePopupTransparency ? Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency) : Theme.surfaceContainer)
        border.color: dropdownMenu.visible ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
        border.width: dropdownMenu.visible ? 2 : 1

        MouseArea {
            id: dropdownArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (dropdownMenu.visible) {
                    dropdownMenu.close();
                    return;
                }
                dropdownMenu.open();
                const pos = dropdown.mapToItem(Overlay.overlay, 0, 0);
                const popupW = dropdownMenu.width;
                const popupH = dropdownMenu.height;
                const overlayH = Overlay.overlay.height;
                const goUp = root.openUpwards || pos.y + dropdown.height + popupH + 4 > overlayH;
                dropdownMenu.x = root.alignPopupRight ? pos.x + dropdown.width - popupW : pos.x - (root.popupWidthOffset / 2);
                dropdownMenu.y = goUp ? pos.y - popupH - 4 : pos.y + dropdown.height + 4;
                if (root.enableFuzzySearch)
                    searchField.forceActiveFocus();
            }
        }

        Row {
            id: contentRow

            anchors.left: parent.left
            anchors.right: expandIcon.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingS
            spacing: Theme.spacingS

            DankIcon {
                name: root.optionIconMap[root.currentValue] ?? ""
                size: 18
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                visible: name !== ""
            }

            StyledText {
                text: root.currentValue
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                width: contentRow.width - (contentRow.children[0].visible ? contentRow.children[0].width + contentRow.spacing : 0)
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                horizontalAlignment: Text.AlignLeft
            }
        }

        DankIcon {
            id: expandIcon

            name: dropdownMenu.visible ? "expand_less" : "expand_more"
            size: 20
            color: Theme.surfaceText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: Theme.spacingS

            Behavior on rotation {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }
        }
    }

    Popup {
        id: dropdownMenu

        property string searchQuery: ""
        property var filteredOptions: {
            if (!root.enableFuzzySearch || searchQuery.length === 0)
                return root.options;
            if (!fzfFinder)
                return root.options;
            return fzfFinder.find(searchQuery).map(r => r.item);
        }
        property int selectedIndex: -1
        property var fzfFinder: null

        function initFinder() {
            fzfFinder = new Fzf.Finder(root.options, {
                "selector": option => option,
                "limit": 50,
                "casing": "case-insensitive"
            });
        }

        function selectNext() {
            if (filteredOptions.length === 0)
                return;
            selectedIndex = (selectedIndex + 1) % filteredOptions.length;
            listView.positionViewAtIndex(selectedIndex, ListView.Contain);
        }

        function selectPrevious() {
            if (filteredOptions.length === 0)
                return;
            selectedIndex = selectedIndex <= 0 ? filteredOptions.length - 1 : selectedIndex - 1;
            listView.positionViewAtIndex(selectedIndex, ListView.Contain);
        }

        function selectCurrent() {
            if (selectedIndex < 0 || selectedIndex >= filteredOptions.length)
                return;
            root.currentValue = filteredOptions[selectedIndex];
            root.valueChanged(filteredOptions[selectedIndex]);
            close();
        }

        onOpened: {
            fzfFinder = null;
            searchQuery = "";
            selectedIndex = -1;
        }

        parent: Overlay.overlay
        width: root.popupWidth === -1 ? undefined : (root.popupWidth > 0 ? root.popupWidth : (dropdown.width + root.popupWidthOffset))
        height: {
            let h = root.enableFuzzySearch ? 54 : 0;
            if (root.options.length === 0 && root.emptyText !== "")
                h += 32;
            else
                h += Math.min(filteredOptions.length, 10) * 36;
            return Math.min(root.maxPopupHeight, h + 16);
        }
        padding: 0
        modal: true
        dim: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: "transparent"
        }

        contentItem: Rectangle {
            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 1)
            border.color: Theme.primary
            border.width: 2
            radius: Theme.cornerRadius

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowBlur: 0.4
                shadowColor: Theme.shadowStrong
                shadowVerticalOffset: 4
            }

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingS

                Rectangle {
                    id: searchContainer

                    width: parent.width
                    height: 42
                    visible: root.enableFuzzySearch
                    radius: Theme.cornerRadius
                    color: root.usePopupTransparency ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : Theme.surfaceContainerHigh

                    DankTextField {
                        id: searchField

                        anchors.fill: parent
                        anchors.margins: 1
                        placeholderText: I18n.tr("Search...")
                        topPadding: Theme.spacingS
                        bottomPadding: Theme.spacingS
                        onTextChanged: searchDebounce.restart()
                        Keys.onDownPressed: dropdownMenu.selectNext()
                        Keys.onUpPressed: dropdownMenu.selectPrevious()
                        Keys.onReturnPressed: dropdownMenu.selectCurrent()
                        Keys.onEnterPressed: dropdownMenu.selectCurrent()
                        Keys.onPressed: event => {
                            if (!(event.modifiers & Qt.ControlModifier))
                                return;
                            switch (event.key) {
                            case Qt.Key_N:
                            case Qt.Key_J:
                                dropdownMenu.selectNext();
                                event.accepted = true;
                                break;
                            case Qt.Key_P:
                            case Qt.Key_K:
                                dropdownMenu.selectPrevious();
                                event.accepted = true;
                                break;
                            }
                        }

                        Timer {
                            id: searchDebounce
                            interval: 50
                            onTriggered: {
                                if (!dropdownMenu.fzfFinder)
                                    dropdownMenu.initFinder();
                                dropdownMenu.searchQuery = searchField.text;
                                dropdownMenu.selectedIndex = -1;
                            }
                        }
                    }
                }

                Item {
                    width: 1
                    height: Theme.spacingXS
                    visible: root.enableFuzzySearch
                }

                Item {
                    width: parent.width
                    height: 32
                    visible: root.options.length === 0 && root.emptyText !== ""

                    StyledText {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.spacingS
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.emptyText
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        horizontalAlignment: Text.AlignLeft
                    }
                }

                DankListView {
                    id: listView

                    width: parent.width
                    height: parent.height - (root.enableFuzzySearch ? searchContainer.height + Theme.spacingXS : 0) - (root.options.length === 0 && root.emptyText !== "" ? 32 : 0)
                    clip: true
                    visible: root.options.length > 0
                    model: ScriptModel {
                        values: dropdownMenu.filteredOptions
                    }
                    spacing: 2

                    interactive: true
                    flickDeceleration: 1500
                    maximumFlickVelocity: 2000
                    boundsBehavior: Flickable.DragAndOvershootBounds
                    boundsMovement: Flickable.FollowBoundsBehavior
                    pressDelay: 0
                    flickableDirection: Flickable.VerticalFlick

                    delegate: Rectangle {
                        id: delegateRoot

                        required property var modelData
                        required property int index
                        property bool isSelected: dropdownMenu.selectedIndex === index
                        property bool isCurrentValue: root.currentValue === modelData
                        property string iconName: root.optionIconMap[modelData] ?? ""

                        width: ListView.view.width
                        height: 32
                        radius: Theme.cornerRadius
                        color: isSelected ? Theme.primaryHover : optionArea.containsMouse ? Theme.primaryHoverLight : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: delegateRoot.iconName
                                size: 18
                                color: delegateRoot.isCurrentValue ? Theme.primary : Theme.surfaceText
                                visible: name !== ""
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: delegateRoot.modelData
                                font.pixelSize: Theme.fontSizeMedium
                                color: delegateRoot.isCurrentValue ? Theme.primary : Theme.surfaceText
                                font.weight: delegateRoot.isCurrentValue ? Font.Medium : Font.Normal
                                width: root.popupWidth > 0 ? undefined : (delegateRoot.width - parent.x - Theme.spacingS * 2)
                                elide: root.popupWidth > 0 ? Text.ElideNone : Text.ElideRight
                                wrapMode: Text.NoWrap
                                horizontalAlignment: Text.AlignLeft
                            }
                        }

                        MouseArea {
                            id: optionArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.currentValue = delegateRoot.modelData;
                                root.valueChanged(delegateRoot.modelData);
                                root.closeDropdownMenu();
                            }
                        }
                    }
                }
            }
        }
    }
}
