import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Widgets

Rectangle {
    id: resultsContainer

    property var appLauncher: null
    property var contextMenu: null

    function resetScroll() {
        resultsList.contentY = 0
        resultsGrid.contentY = 0
    }

    width: parent.width
    height: parent.height - y
    radius: Theme.cornerRadius
    color: "transparent"
    clip: true

    DankListView {
        id: resultsList

        property int itemHeight: 60
        property int iconSize: 40
        property bool showDescription: true
        property int itemSpacing: Theme.spacingS
        property bool hoverUpdatesSelection: false
        property bool keyboardNavigationActive: appLauncher ? appLauncher.keyboardNavigationActive : false

        signal keyboardNavigationReset
        signal itemClicked(int index, var modelData)
        signal itemRightClicked(int index, var modelData, real mouseX, real mouseY)

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
        visible: appLauncher && appLauncher.viewMode === "list"
        model: appLauncher ? appLauncher.model : null
        currentIndex: appLauncher ? appLauncher.selectedIndex : -1
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
        onItemClicked: (index, modelData) => {
                           if (appLauncher)
                           appLauncher.launchApp(modelData)
                       }
        onItemRightClicked: (index, modelData, mouseX, mouseY) => {
                                if (contextMenu)
                                contextMenu.show(mouseX, mouseY, modelData)
                            }
        onKeyboardNavigationReset: () => {
                                       if (appLauncher)
                                       appLauncher.keyboardNavigationActive = false
                                   }

        delegate: Rectangle {
            width: ListView.view.width
            height: resultsList.itemHeight
            radius: Theme.cornerRadius
            color: ListView.isCurrentItem ? Theme.primaryPressed : listMouseArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceContainerHigh

            Row {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingL

                Item {
                    width: resultsList.iconSize
                    height: resultsList.iconSize
                    anchors.verticalCenter: parent.verticalCenter

                    IconImage {
                        id: listIconImg

                        anchors.fill: parent
                        source: Quickshell.iconPath(model.icon, true)
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: !listIconImg.visible
                        color: Theme.surfaceLight
                        radius: Theme.cornerRadius
                        border.width: 1
                        border.color: Theme.primarySelected

                        StyledText {
                            anchors.centerIn: parent
                            text: (model.name && model.name.length > 0) ? model.name.charAt(0).toUpperCase() : "A"
                            font.pixelSize: resultsList.iconSize * 0.4
                            color: Theme.primary
                            font.weight: Font.Bold
                        }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - resultsList.iconSize - Theme.spacingL
                    spacing: Theme.spacingXS

                    StyledText {
                        width: parent.width
                        text: model.name || ""
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        width: parent.width
                        text: model.comment || "Application"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        visible: resultsList.showDescription && model.comment && model.comment.length > 0
                    }
                }
            }

            MouseArea {
                id: listMouseArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                z: 10
                onEntered: () => {
                               if (resultsList.hoverUpdatesSelection && !resultsList.keyboardNavigationActive)
                               resultsList.currentIndex = index
                           }
                onPositionChanged: () => {
                                       resultsList.keyboardNavigationReset()
                                   }
                onClicked: mouse => {
                               if (mouse.button === Qt.LeftButton) {
                                   resultsList.itemClicked(index, model)
                               } else if (mouse.button === Qt.RightButton && !model.isPlugin) {
                                   const globalPos = mapToItem(null, mouse.x, mouse.y)
                                   const modalPos = resultsContainer.parent.mapFromItem(null, globalPos.x, globalPos.y)
                                   resultsList.itemRightClicked(index, model, modalPos.x, modalPos.y)
                               }
                           }
            }
        }
    }

    DankGridView {
        id: resultsGrid

        property int currentIndex: appLauncher ? appLauncher.selectedIndex : -1
        property int columns: 4
        property bool adaptiveColumns: false
        property int minCellWidth: 120
        property int maxCellWidth: 160
        property int cellPadding: 8
        property real iconSizeRatio: 0.55
        property int maxIconSize: 48
        property int minIconSize: 32
        property bool hoverUpdatesSelection: false
        property bool keyboardNavigationActive: appLauncher ? appLauncher.keyboardNavigationActive : false
        property int baseCellWidth: adaptiveColumns ? Math.max(minCellWidth, Math.min(maxCellWidth, width / columns)) : (width - Theme.spacingS * 2) / columns
        property int baseCellHeight: baseCellWidth + 20
        property int actualColumns: adaptiveColumns ? Math.floor(width / cellWidth) : columns
        property int remainingSpace: width - (actualColumns * cellWidth)

        signal keyboardNavigationReset
        signal itemClicked(int index, var modelData)
        signal itemRightClicked(int index, var modelData, real mouseX, real mouseY)

        function ensureVisible(index) {
            if (index < 0 || index >= count)
                return

            const itemY = Math.floor(index / actualColumns) * cellHeight
            const itemBottom = itemY + cellHeight
            if (itemY < contentY)
                contentY = itemY
            else if (itemBottom > contentY + height)
                contentY = itemBottom - height
        }

        anchors.fill: parent
        anchors.margins: Theme.spacingS
        visible: appLauncher && appLauncher.viewMode === "grid"
        model: appLauncher ? appLauncher.model : null
        clip: true
        cellWidth: baseCellWidth
        cellHeight: baseCellHeight
        leftMargin: Math.max(Theme.spacingS, remainingSpace / 2)
        rightMargin: leftMargin
        focus: true
        interactive: true
        cacheBuffer: Math.max(0, Math.min(height * 2, 1000))
        reuseItems: true
        onCurrentIndexChanged: {
            if (keyboardNavigationActive)
                ensureVisible(currentIndex)
        }
        onItemClicked: (index, modelData) => {
                           if (appLauncher)
                           appLauncher.launchApp(modelData)
                       }
        onItemRightClicked: (index, modelData, mouseX, mouseY) => {
                                if (contextMenu)
                                contextMenu.show(mouseX, mouseY, modelData)
                            }
        onKeyboardNavigationReset: () => {
                                       if (appLauncher)
                                       appLauncher.keyboardNavigationActive = false
                                   }

        delegate: Rectangle {
            width: resultsGrid.cellWidth - resultsGrid.cellPadding
            height: resultsGrid.cellHeight - resultsGrid.cellPadding
            radius: Theme.cornerRadius
            color: resultsGrid.currentIndex === index ? Theme.primaryPressed : gridMouseArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceContainerHigh

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingS

                Item {
                    property int iconSize: Math.min(resultsGrid.maxIconSize, Math.max(resultsGrid.minIconSize, resultsGrid.cellWidth * resultsGrid.iconSizeRatio))

                    width: iconSize
                    height: iconSize
                    anchors.horizontalCenter: parent.horizontalCenter

                    IconImage {
                        id: gridIconImg

                        anchors.fill: parent
                        source: Quickshell.iconPath(model.icon, true)
                        smooth: true
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: !gridIconImg.visible
                        color: Theme.surfaceLight
                        radius: Theme.cornerRadius
                        border.width: 1
                        border.color: Theme.primarySelected

                        StyledText {
                            anchors.centerIn: parent
                            text: (model.name && model.name.length > 0) ? model.name.charAt(0).toUpperCase() : "A"
                            font.pixelSize: Math.min(28, parent.width * 0.5)
                            color: Theme.primary
                            font.weight: Font.Bold
                        }
                    }
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: resultsGrid.cellWidth - 12
                    text: model.name || ""
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }
            }

            MouseArea {
                id: gridMouseArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                z: 10
                onEntered: () => {
                               if (resultsGrid.hoverUpdatesSelection && !resultsGrid.keyboardNavigationActive)
                               resultsGrid.currentIndex = index
                           }
                onPositionChanged: () => {
                                       resultsGrid.keyboardNavigationReset()
                                   }
                onClicked: mouse => {
                               if (mouse.button === Qt.LeftButton) {
                                   resultsGrid.itemClicked(index, model)
                               } else if (mouse.button === Qt.RightButton && !model.isPlugin) {
                                   const globalPos = mapToItem(null, mouse.x, mouse.y)
                                   const modalPos = resultsContainer.parent.mapFromItem(null, globalPos.x, globalPos.y)
                                   resultsGrid.itemRightClicked(index, model, modalPos.x, modalPos.y)
                               }
                           }
            }
        }
    }
}
