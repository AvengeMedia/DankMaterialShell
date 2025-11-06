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

        delegate: AppLauncherListDelegate {
            listView: resultsList
            itemHeight: resultsList.itemHeight
            iconSize: resultsList.iconSize
            showDescription: resultsList.showDescription
            hoverUpdatesSelection: resultsList.hoverUpdatesSelection
            keyboardNavigationActive: resultsList.keyboardNavigationActive
            isCurrentItem: ListView.isCurrentItem
            iconMaterialSizeAdjustment: 0
            iconUnicodeScale: 0.8
            onItemClicked: (idx, modelData) => resultsList.itemClicked(idx, modelData)
            onItemRightClicked: (idx, modelData, mouseX, mouseY) => {
                const modalPos = resultsContainer.parent.mapFromItem(null, mouseX, mouseY)
                resultsList.itemRightClicked(idx, modelData, modalPos.x, modalPos.y)
            }
            onKeyboardNavigationReset: resultsList.keyboardNavigationReset
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

        delegate: AppLauncherGridDelegate {
            gridView: resultsGrid
            cellWidth: resultsGrid.cellWidth
            cellHeight: resultsGrid.cellHeight
            cellPadding: resultsGrid.cellPadding
            minIconSize: resultsGrid.minIconSize
            maxIconSize: resultsGrid.maxIconSize
            iconSizeRatio: resultsGrid.iconSizeRatio
            hoverUpdatesSelection: resultsGrid.hoverUpdatesSelection
            keyboardNavigationActive: resultsGrid.keyboardNavigationActive
            currentIndex: resultsGrid.currentIndex
            onItemClicked: (idx, modelData) => resultsGrid.itemClicked(idx, modelData)
            onItemRightClicked: (idx, modelData, mouseX, mouseY) => {
                const modalPos = resultsContainer.parent.mapFromItem(null, mouseX, mouseY)
                resultsGrid.itemRightClicked(idx, modelData, modalPos.x, modalPos.y)
            }
            onKeyboardNavigationReset: resultsGrid.keyboardNavigationReset
        }
    }
}
