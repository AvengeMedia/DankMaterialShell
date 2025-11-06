import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: resultsContainer

    property var fileSearchController: null

    function resetScroll() {
        filesList.contentY = 0
    }

    color: "transparent"
    clip: true

    DankListView {
        id: filesList

        property int itemHeight: 60
        property int itemSpacing: Theme.spacingS
        property bool hoverUpdatesSelection: false
        property bool keyboardNavigationActive: fileSearchController ? fileSearchController.keyboardNavigationActive : false

        signal keyboardNavigationReset
        signal itemClicked(int index)
        signal itemRightClicked(int index)

        function ensureVisible(index) {
            if (index < 0 || index >= count)
                return

            const itemY = index * (itemHeight + itemSpacing)
            const itemBottom = itemY + itemHeight
            if (itemY < contentY)
                contentY = itemY
            else if (itemBottom > contentY + height)
                contentY = itemBottom - height
        }

        anchors.fill: parent
        anchors.margins: Theme.spacingS
        model: fileSearchController ? fileSearchController.model : null
        currentIndex: fileSearchController ? fileSearchController.selectedIndex : -1
        clip: true
        spacing: itemSpacing
        focus: true
        interactive: true
        cacheBuffer: Math.max(0, Math.min(height * 2, 1000))
        reuseItems: true

        onCurrentIndexChanged: {
            if (keyboardNavigationActive)
                ensureVisible(currentIndex)
        }

        onItemClicked: function (index) {
            if (fileSearchController) {
                const item = fileSearchController.model.get(index)
                fileSearchController.openFile(item.filePath)
            }
        }

        onItemRightClicked: function (index) {
            if (fileSearchController) {
                const item = fileSearchController.model.get(index)
                fileSearchController.openFolder(item.filePath)
            }
        }

        onKeyboardNavigationReset: {
            if (fileSearchController)
                fileSearchController.keyboardNavigationActive = false
        }

        delegate: Rectangle {
            required property int index
            required property string filePath
            required property string fileName
            required property string fileExtension
            required property string fileType
            required property string dirPath

            width: ListView.view.width
            height: filesList.itemHeight
            radius: Theme.cornerRadius
            color: ListView.isCurrentItem ? Theme.primaryPressed : fileMouseArea.containsMouse ? Theme.primaryHoverLight : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

            Row {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingL

                Item {
                    width: 40
                    height: 40
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        id: iconBackground
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.surfaceLight
                        visible: fileType !== "image"

                        DankNFIcon {
                            id: nerdIcon
                            anchors.centerIn: parent
                            name: {
                                const lowerName = fileName.toLowerCase()
                                if (lowerName.startsWith("dockerfile"))
                                    return "docker"
                                if (lowerName.startsWith("makefile"))
                                    return "makefile"
                                if (lowerName.startsWith("license"))
                                    return "license"
                                if (lowerName.startsWith("readme"))
                                    return "readme"
                                return fileExtension.toLowerCase()
                            }
                            size: Theme.fontSizeXLarge
                            color: Theme.surfaceText
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: fileExtension ? (fileExtension.length > 4 ? fileExtension.substring(0, 4) : fileExtension) : "?"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Bold
                            visible: !nerdIcon.visible
                        }
                    }

                    Loader {
                        anchors.fill: parent
                        active: fileType === "image"
                        sourceComponent: Image {
                            anchors.fill: parent
                            source: "file://" + filePath
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1.0
                                maskSource: ShaderEffectSource {
                                    sourceItem: Rectangle {
                                        width: 40
                                        height: 40
                                        radius: 20
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 40 - Theme.spacingL
                    spacing: Theme.spacingXS

                    StyledText {
                        width: parent.width
                        text: fileName || ""
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                    }

                    StyledText {
                        width: parent.width
                        text: dirPath || ""
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                    }
                }
            }

            MouseArea {
                id: fileMouseArea

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                z: 10
                onEntered: {
                    if (filesList.hoverUpdatesSelection && !filesList.keyboardNavigationActive)
                        filesList.currentIndex = index
                }
                onPositionChanged: {
                    filesList.keyboardNavigationReset()
                }
                onClicked: mouse => {
                               if (mouse.button === Qt.LeftButton) {
                                   filesList.itemClicked(index)
                               } else if (mouse.button === Qt.RightButton) {
                                   filesList.itemRightClicked(index)
                               }
                           }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: !fileSearchController || !fileSearchController.model || fileSearchController.model.count === 0

        StyledText {
            property string displayText: {
                if (!fileSearchController) {
                    return ""
                }
                if (!DSearchService.dsearchAvailable) {
                    return I18n.tr("DankSearch not available")
                }
                if (fileSearchController.isSearching) {
                    return I18n.tr("Searching...")
                }
                if (fileSearchController.searchQuery.length === 0) {
                    return I18n.tr("Enter a search query")
                }
                if (!fileSearchController.model || fileSearchController.model.count === 0) {
                    return I18n.tr("No files found")
                }
                return ""
            }

            text: displayText
            anchors.centerIn: parent
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceVariantText
            visible: displayText.length > 0
        }
    }
}
