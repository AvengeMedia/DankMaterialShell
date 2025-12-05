import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: resultsContainer

    property var appLauncher: null

    signal itemRightClicked(int index, var modelData, real mouseX, real mouseY)

    function resetScroll() {
        resultsList.contentY = 0;
        if (gridLoader.item) {
            gridLoader.item.contentY = 0;
        }
    }

    function getSelectedItemPosition() {
        if (!appLauncher)
            return {
                x: 0,
                y: 0
            };

        const selectedIndex = appLauncher.selectedIndex;
        if (appLauncher.viewMode === "list") {
            const itemY = selectedIndex * (resultsList.itemHeight + resultsList.itemSpacing) - resultsList.contentY;
            return {
                x: resultsList.width / 2,
                y: itemY + resultsList.itemHeight / 2
            };
        } else if (gridLoader.item) {
            const grid = gridLoader.item;
            const row = Math.floor(selectedIndex / grid.actualColumns);
            const col = selectedIndex % grid.actualColumns;
            const itemX = col * grid.cellWidth + grid.leftMargin + grid.cellWidth / 2;
            const itemY = row * grid.cellHeight - grid.contentY + grid.cellHeight / 2;
            return {
                x: itemX,
                y: itemY
            };
        }
        return {
            x: 0,
            y: 0
        };
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
                return;
            const itemY = index * (itemHeight + itemSpacing);
            const itemBottom = itemY + itemHeight;
            if (itemY < contentY)
                contentY = itemY;
            else if (itemBottom > contentY + height)
                contentY = itemBottom - height;
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
                ensureVisible(currentIndex);
        }
        onItemClicked: (index, modelData) => {
            if (appLauncher)
                appLauncher.launchApp(modelData);
        }
        onItemRightClicked: (index, modelData, mouseX, mouseY) => {
            resultsContainer.itemRightClicked(index, modelData, mouseX, mouseY);
        }
        onKeyboardNavigationReset: () => {
            if (appLauncher)
                appLauncher.keyboardNavigationActive = false;
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
                resultsList.itemRightClicked(idx, modelData, mouseX, mouseY);
            }
            onKeyboardNavigationReset: resultsList.keyboardNavigationReset
        }
    }

    Loader {
        id: gridLoader

        property real _lastWidth: 0

        anchors.fill: parent
        anchors.margins: Theme.spacingS
        visible: appLauncher && appLauncher.viewMode === "grid"
        active: appLauncher && appLauncher.viewMode === "grid"
        asynchronous: false

        onLoaded: {
            if (item) {
                item.appLauncher = Qt.binding(() => resultsContainer.appLauncher);
            }
        }

        onWidthChanged: {
            if (visible && Math.abs(width - _lastWidth) > 1) {
                _lastWidth = width;
                active = false;
                Qt.callLater(() => {
                    active = true;
                });
            }
        }
        sourceComponent: Component {
            DankGridView {
                id: resultsGrid

                property var appLauncher: null

                property int currentIndex: appLauncher ? appLauncher.selectedIndex : -1
                property int columns: appLauncher ? appLauncher.gridColumns : 4
                property bool adaptiveColumns: false
                property int minCellWidth: 120
                property int maxCellWidth: 160
                property real iconSizeRatio: 0.55
                property int maxIconSize: 48
                property int minIconSize: 32
                property bool hoverUpdatesSelection: false
                property bool keyboardNavigationActive: appLauncher ? appLauncher.keyboardNavigationActive : false
                property real baseCellWidth: adaptiveColumns ? Math.max(minCellWidth, Math.min(maxCellWidth, width / columns)) : width / columns
                property real baseCellHeight: baseCellWidth + 20
                property int actualColumns: adaptiveColumns ? Math.floor(width / cellWidth) : columns
                property int remainingSpace: width - (actualColumns * cellWidth)

                signal keyboardNavigationReset
                signal itemClicked(int index, var modelData)
                signal itemRightClicked(int index, var modelData, real mouseX, real mouseY)

                function ensureVisible(index) {
                    if (index < 0 || index >= count)
                        return;
                    const itemY = Math.floor(index / actualColumns) * cellHeight;
                    const itemBottom = itemY + cellHeight;
                    if (itemY < contentY)
                        contentY = itemY;
                    else if (itemBottom > contentY + height)
                        contentY = itemBottom - height;
                }

                anchors.fill: parent
                model: appLauncher ? appLauncher.model : null
                clip: true
                cellWidth: baseCellWidth
                cellHeight: baseCellHeight
                focus: true
                interactive: true
                cacheBuffer: Math.max(0, Math.min(height * 2, 1000))
                reuseItems: true
                onCurrentIndexChanged: {
                    if (keyboardNavigationActive)
                        ensureVisible(currentIndex);
                }
                onItemClicked: (index, modelData) => {
                    if (appLauncher)
                        appLauncher.launchApp(modelData);
                }
                onItemRightClicked: (index, modelData, mouseX, mouseY) => {
                    resultsContainer.itemRightClicked(index, modelData, mouseX, mouseY);
                }
                onKeyboardNavigationReset: () => {
                    if (appLauncher)
                        appLauncher.keyboardNavigationActive = false;
                }

                delegate: AppLauncherGridDelegate {
                    gridView: resultsGrid
                    cellWidth: resultsGrid.cellWidth
                    cellHeight: resultsGrid.cellHeight
                    minIconSize: resultsGrid.minIconSize
                    maxIconSize: resultsGrid.maxIconSize
                    iconSizeRatio: resultsGrid.iconSizeRatio
                    hoverUpdatesSelection: resultsGrid.hoverUpdatesSelection
                    keyboardNavigationActive: resultsGrid.keyboardNavigationActive
                    currentIndex: resultsGrid.currentIndex
                    onItemClicked: (idx, modelData) => resultsGrid.itemClicked(idx, modelData)
                    onItemRightClicked: (idx, modelData, mouseX, mouseY) => {
                        resultsGrid.itemRightClicked(idx, modelData, mouseX, mouseY);
                    }
                    onKeyboardNavigationReset: resultsGrid.keyboardNavigationReset
                }
            }
        }
    }
}
