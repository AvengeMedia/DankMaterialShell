import "../Common/fzf.js" as Fzf
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.Common
import qs.Widgets

Item {
    id: root

    property string text: ""
    property string description: ""
    property string currentValue: ""
    property var options: []
    property var optionIcons: []
    property bool enableFuzzySearch: false
    property int popupWidthOffset: 0
    property int maxPopupHeight: 400
    property bool openUpwards: false
    property int popupWidth: 0
    property bool alignPopupRight: false
    property int dropdownWidth: 200
    property bool compactMode: text === "" && description === ""

    signal valueChanged(string value)

    width: compactMode ? dropdownWidth : parent.width
    implicitHeight: compactMode ? 40 : Math.max(60, labelColumn.implicitHeight + Theme.spacingM)

    Component.onDestruction: {
        const popup = dropdownMenu
        if (popup && popup.visible) {
            popup.close()
        }
    }

    Column {
        id: labelColumn

        anchors.left: parent.left
        anchors.right: dropdown.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: Theme.spacingL
        spacing: Theme.spacingXS
        visible: !root.compactMode

        StyledText {
            text: root.text
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
            font.weight: Font.Medium
        }

        StyledText {
            text: root.description
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            visible: description.length > 0
            wrapMode: Text.WordWrap
            width: parent.width
        }
    }

    Rectangle {
        id: dropdown

        width: root.compactMode ? parent.width : (root.popupWidth === -1 ? undefined : (root.popupWidth > 0 ? root.popupWidth : root.dropdownWidth))
        height: 40
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        radius: Theme.cornerRadius
        color: dropdownArea.containsMouse || dropdownMenu.visible ? Theme.surfaceContainerHigh : Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
        border.color: dropdownMenu.visible ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
        border.width: dropdownMenu.visible ? 2 : 1

        MouseArea {
            id: dropdownArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (dropdownMenu.visible) {
                    dropdownMenu.close()
                    return
                }

                dropdownMenu.searchQuery = ""
                dropdownMenu.updateFilteredOptions()

                dropdownMenu.open()

                const pos = dropdown.mapToItem(Overlay.overlay, 0, 0)
                const popupWidth = dropdownMenu.width
                const popupHeight = dropdownMenu.height
                const overlayHeight = Overlay.overlay.height

                if (root.openUpwards || pos.y + dropdown.height + popupHeight + 4 > overlayHeight) {
                    if (root.alignPopupRight) {
                        dropdownMenu.x = pos.x + dropdown.width - popupWidth
                    } else {
                        dropdownMenu.x = pos.x - (root.popupWidthOffset / 2)
                    }
                    dropdownMenu.y = pos.y - popupHeight - 4
                } else {
                    if (root.alignPopupRight) {
                        dropdownMenu.x = pos.x + dropdown.width - popupWidth
                    } else {
                        dropdownMenu.x = pos.x - (root.popupWidthOffset / 2)
                    }
                    dropdownMenu.y = pos.y + dropdown.height + 4
                }

                if (root.enableFuzzySearch && searchField.visible) {
                    searchField.forceActiveFocus()
                }
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
                name: {
                    const currentIndex = root.options.indexOf(root.currentValue)
                    return currentIndex >= 0 && root.optionIcons.length > currentIndex ? root.optionIcons[currentIndex] : ""
                }
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
        property var filteredOptions: []
        property int selectedIndex: -1
        property var fzfFinder: new Fzf.Finder(root.options, {
            "selector": option => option,
            "limit": 50,
            "casing": "case-insensitive"
        })

        function updateFilteredOptions() {
            if (!root.enableFuzzySearch || searchQuery.length === 0) {
                filteredOptions = root.options
                selectedIndex = -1
                return
            }

            const results = fzfFinder.find(searchQuery)
            filteredOptions = results.map(result => result.item)
            selectedIndex = -1
        }

        function selectNext() {
            if (filteredOptions.length === 0) {
                return
            }
            selectedIndex = (selectedIndex + 1) % filteredOptions.length
            listView.positionViewAtIndex(selectedIndex, ListView.Contain)
        }

        function selectPrevious() {
            if (filteredOptions.length === 0) {
                return
            }
            selectedIndex = selectedIndex <= 0 ? filteredOptions.length - 1 : selectedIndex - 1
            listView.positionViewAtIndex(selectedIndex, ListView.Contain)
        }

        function selectCurrent() {
            if (selectedIndex < 0 || selectedIndex >= filteredOptions.length) {
                return
            }
            root.currentValue = filteredOptions[selectedIndex]
            root.valueChanged(filteredOptions[selectedIndex])
            close()
        }

        parent: Overlay.overlay
        width: root.popupWidth === -1 ? undefined : (root.popupWidth > 0 ? root.popupWidth : (dropdown.width + root.popupWidthOffset))
        height: Math.min(root.maxPopupHeight, (root.enableFuzzySearch ? 54 : 0) + Math.min(filteredOptions.length, 10) * 36 + 16)
        padding: 0
        modal: true
        dim: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: "transparent"
        }

        contentItem: Rectangle {
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
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                    DankTextField {
                        id: searchField

                        anchors.fill: parent
                        anchors.margins: 1
                        placeholderText: I18n.tr("Search...")
                        text: dropdownMenu.searchQuery
                        topPadding: Theme.spacingS
                        bottomPadding: Theme.spacingS
                        onTextChanged: {
                            dropdownMenu.searchQuery = text
                            dropdownMenu.updateFilteredOptions()
                        }
                        Keys.onDownPressed: dropdownMenu.selectNext()
                        Keys.onUpPressed: dropdownMenu.selectPrevious()
                        Keys.onReturnPressed: dropdownMenu.selectCurrent()
                        Keys.onEnterPressed: dropdownMenu.selectCurrent()
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_N && event.modifiers & Qt.ControlModifier) {
                                dropdownMenu.selectNext()
                                event.accepted = true
                            } else if (event.key === Qt.Key_P && event.modifiers & Qt.ControlModifier) {
                                dropdownMenu.selectPrevious()
                                event.accepted = true
                            } else if (event.key === Qt.Key_J && event.modifiers & Qt.ControlModifier) {
                                dropdownMenu.selectNext()
                                event.accepted = true
                            } else if (event.key === Qt.Key_K && event.modifiers & Qt.ControlModifier) {
                                dropdownMenu.selectPrevious()
                                event.accepted = true
                            }
                        }
                    }
                }

                Item {
                    width: 1
                    height: Theme.spacingXS
                    visible: root.enableFuzzySearch
                }

                DankListView {
                    id: listView

                    width: parent.width
                    height: parent.height - (root.enableFuzzySearch ? searchContainer.height + Theme.spacingXS : 0)
                    clip: true
                    model: dropdownMenu.filteredOptions
                    spacing: 2

                    interactive: true
                    flickDeceleration: 1500
                    maximumFlickVelocity: 2000
                    boundsBehavior: Flickable.DragAndOvershootBounds
                    boundsMovement: Flickable.FollowBoundsBehavior
                    pressDelay: 0
                    flickableDirection: Flickable.VerticalFlick

                    delegate: Rectangle {
                        property bool isSelected: dropdownMenu.selectedIndex === index
                        property bool isCurrentValue: root.currentValue === modelData
                        property int optionIndex: root.options.indexOf(modelData)

                        width: ListView.view.width
                        height: 32
                        radius: Theme.cornerRadius
                        color: isSelected ? Theme.primaryHover : optionArea.containsMouse ? Theme.primaryHoverLight : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: optionIndex >= 0 && root.optionIcons.length > optionIndex ? root.optionIcons[optionIndex] : ""
                                size: 18
                                color: isCurrentValue ? Theme.primary : Theme.surfaceText
                                visible: name !== ""
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData
                                font.pixelSize: Theme.fontSizeMedium
                                color: isCurrentValue ? Theme.primary : Theme.surfaceText
                                font.weight: isCurrentValue ? Font.Medium : Font.Normal
                                width: root.popupWidth > 0 ? undefined : (parent.parent.width - parent.x - Theme.spacingS)
                                elide: root.popupWidth > 0 ? Text.ElideNone : Text.ElideRight
                                wrapMode: Text.NoWrap
                            }
                        }

                        MouseArea {
                            id: optionArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.currentValue = modelData
                                root.valueChanged(modelData)
                                dropdownMenu.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
