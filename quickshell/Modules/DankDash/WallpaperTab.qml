import Qt.labs.folderlistmodel
import QtCore
import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Modals.FileBrowser
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    implicitWidth: SettingsData.showWeekNumber ? 736 : 700
    implicitHeight: 410

    property string wallpaperDir: ""
    property int currentPage: 0
    property int itemsPerPage: 16
    property int totalPages: Math.max(1, Math.ceil(wallpaperFolderModel.count / itemsPerPage))
    property bool active: false
    property Item focusTarget: wallpaperGrid
    property Item tabBarItem: null
    property int gridIndex: 0
    property Item keyForwardTarget: null
    property var parentPopout: null
    property int lastPage: 0
    property bool enableAnimation: false
    property string homeDir: StandardPaths.writableLocation(StandardPaths.HomeLocation)
    property string selectedFileName: ""
    property var targetScreen: null
    property string targetScreenName: targetScreen ? targetScreen.name : ""
    // Shared with the wallpaper FileBrowser via CacheData.fileBrowserSettings["wallpaper"]
    property string sortBy: "name"
    property bool sortAscending: true
    // Forces the page grid to rebuild when the folder model reorders in place.
    property int gridRevision: 0

    signal requestTabChange(int newIndex)

    function refreshAfterSort() {
        // Defer until FolderListModel finishes reordering.
        Qt.callLater(() => {
            gridRevision++;
            if (visible && active) {
                setInitialSelection();
            }
            updateSelectedFileName();
        });
    }

    onSortByChanged: refreshAfterSort()
    onSortAscendingChanged: refreshAfterSort()

    function loadSort() {
        const s = CacheData.fileBrowserSettings["wallpaper"];
        if (s) {
            sortBy = s.sortBy || "name";
            sortAscending = s.sortAscending !== undefined ? s.sortAscending : true;
        }
    }

    function persistSort() {
        let settings = CacheData.fileBrowserSettings;
        if (!settings["wallpaper"])
            settings["wallpaper"] = {};
        settings["wallpaper"].sortBy = sortBy;
        settings["wallpaper"].sortAscending = sortAscending;
        CacheData.fileBrowserSettings = settings;
        CacheData.saveCache();
    }

    function getCurrentWallpaper() {
        if (SessionData.perMonitorWallpaper && targetScreenName) {
            return SessionData.getMonitorWallpaper(targetScreenName);
        }
        return SessionData.wallpaperPath;
    }

    function setCurrentWallpaper(path) {
        if (SessionData.perMonitorWallpaper && targetScreenName) {
            SessionData.setMonitorWallpaper(targetScreenName, path);
        } else {
            SessionData.setWallpaper(path);
        }
    }

    onCurrentPageChanged: {
        if (currentPage !== lastPage) {
            enableAnimation = false;
            lastPage = currentPage;
        }
        updateSelectedFileName();
    }

    onGridIndexChanged: {
        updateSelectedFileName();
    }

    onVisibleChanged: {
        if (visible && active) {
            setInitialSelection();
        }
    }

    Component.onCompleted: {
        loadSort();
        loadWallpaperDirectory();
    }

    Connections {
        target: CacheData
        function onFileBrowserSettingsChanged() {
            loadSort();
        }
    }

    onActiveChanged: {
        if (active && visible) {
            setInitialSelection();
        }
    }

    function goToNextCell(visibleCount) {
        if (gridIndex + 1 < visibleCount) {
            gridIndex++;
        } else if (currentPage < totalPages - 1) {
            gridIndex = 0;
            currentPage++;
        } else if (totalPages > 1) {
            gridIndex = 0;
            currentPage = 0;
        }
    }

    function goToPrevCell() {
        if (gridIndex > 0) {
            gridIndex--;
        } else if (currentPage > 0) {
            currentPage--;
            const prevPageCount = Math.min(itemsPerPage, wallpaperFolderModel.count - currentPage * itemsPerPage);
            gridIndex = prevPageCount - 1;
        } else if (totalPages > 1) {
            currentPage = totalPages - 1;
            const lastPageCount = Math.min(itemsPerPage, wallpaperFolderModel.count - currentPage * itemsPerPage);
            gridIndex = lastPageCount - 1;
        }
    }

    function closeOverlays() {
        if (sortMenu.visible || pageJumpPopup.visible) {
            sortMenu.visible = false;
            pageJumpPopup.visible = false;
            return true;
        }
        return false;
    }

    function handleKeyEvent(event) {
        if (event.key === Qt.Key_Escape) {
            return closeOverlays();
        }
        const columns = 4;
        const currentCol = gridIndex % columns;
        const visibleCount = Math.min(itemsPerPage, wallpaperFolderModel.count - currentPage * itemsPerPage);

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (gridIndex >= 0 && gridIndex < visibleCount) {
                const absoluteIndex = currentPage * itemsPerPage + gridIndex;
                if (absoluteIndex < wallpaperFolderModel.count) {
                    const filePath = wallpaperFolderModel.get(absoluteIndex, "filePath");
                    if (filePath) {
                        setCurrentWallpaper(filePath.toString().replace(/^file:\/\//, ''));
                    }
                }
            }
            return true;
        }

        if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
            if (I18n.isRtl) {
                goToPrevCell();
            } else {
                goToNextCell(visibleCount);
            }
            return true;
        }

        if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
            if (I18n.isRtl) {
                goToNextCell(visibleCount);
            } else {
                goToPrevCell();
            }
            return true;
        }

        if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            if (gridIndex + columns < visibleCount) {
                gridIndex += columns;
            } else if (currentPage < totalPages - 1) {
                gridIndex = currentCol;
                currentPage++;
            } else if (totalPages > 1) {
                gridIndex = currentCol;
                currentPage = 0;
            }
            return true;
        }

        if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            if (gridIndex >= columns) {
                gridIndex -= columns;
            } else if (currentPage > 0) {
                currentPage--;
                const prevPageCount = Math.min(itemsPerPage, wallpaperFolderModel.count - currentPage * itemsPerPage);
                const prevPageRows = Math.ceil(prevPageCount / columns);
                gridIndex = (prevPageRows - 1) * columns + currentCol;
                gridIndex = Math.min(gridIndex, prevPageCount - 1);
            } else if (totalPages > 1) {
                currentPage = totalPages - 1;
                const lastPageCount = Math.min(itemsPerPage, wallpaperFolderModel.count - currentPage * itemsPerPage);
                const lastPageRows = Math.ceil(lastPageCount / columns);
                gridIndex = (lastPageRows - 1) * columns + currentCol;
                gridIndex = Math.min(gridIndex, lastPageCount - 1);
            }
            return true;
        }

        if (event.key === Qt.Key_PageUp && totalPages > 1) {
            gridIndex = 0;
            currentPage = (currentPage - 1 + totalPages) % totalPages;
            return true;
        }

        if (event.key === Qt.Key_PageDown && totalPages > 1) {
            gridIndex = 0;
            currentPage = (currentPage + 1) % totalPages;
            return true;
        }

        if (event.key === Qt.Key_Home && event.modifiers & Qt.ControlModifier) {
            gridIndex = 0;
            currentPage = 0;
            return true;
        }

        if (event.key === Qt.Key_End && event.modifiers & Qt.ControlModifier) {
            currentPage = totalPages - 1;
            const lastPageCount = Math.min(itemsPerPage, wallpaperFolderModel.count - currentPage * itemsPerPage);
            gridIndex = Math.max(0, lastPageCount - 1);
            return true;
        }

        return false;
    }

    function setInitialSelection() {
        const currentWallpaper = getCurrentWallpaper();
        if (!currentWallpaper || wallpaperFolderModel.count === 0) {
            gridIndex = 0;
            updateSelectedFileName();
            Qt.callLater(() => {
                enableAnimation = true;
            });
            return;
        }

        for (var i = 0; i < wallpaperFolderModel.count; i++) {
            const filePath = wallpaperFolderModel.get(i, "filePath");
            if (filePath && filePath.toString().replace(/^file:\/\//, '') === currentWallpaper) {
                const targetPage = Math.floor(i / itemsPerPage);
                const targetIndex = i % itemsPerPage;
                currentPage = targetPage;
                gridIndex = targetIndex;
                updateSelectedFileName();
                Qt.callLater(() => {
                    enableAnimation = true;
                });
                return;
            }
        }
        gridIndex = 0;
        updateSelectedFileName();
        Qt.callLater(() => {
            enableAnimation = true;
        });
    }

    function loadWallpaperDirectory() {
        const currentWallpaper = getCurrentWallpaper();

        if (!currentWallpaper || currentWallpaper.startsWith("#")) {
            if (CacheData.wallpaperLastPath && CacheData.wallpaperLastPath !== "") {
                wallpaperDir = CacheData.wallpaperLastPath;
            } else {
                wallpaperDir = "";
            }
            return;
        }

        wallpaperDir = currentWallpaper.substring(0, currentWallpaper.lastIndexOf('/'));
    }

    function updateSelectedFileName() {
        if (wallpaperFolderModel.count === 0) {
            selectedFileName = "";
            return;
        }

        const absoluteIndex = currentPage * itemsPerPage + gridIndex;
        if (absoluteIndex < wallpaperFolderModel.count) {
            const filePath = wallpaperFolderModel.get(absoluteIndex, "filePath");
            if (filePath) {
                const pathStr = filePath.toString().replace(/^file:\/\//, '');
                selectedFileName = pathStr.substring(pathStr.lastIndexOf('/') + 1);
                return;
            }
        }
        selectedFileName = "";
    }

    Connections {
        target: SessionData
        function onWallpaperPathChanged() {
            loadWallpaperDirectory();
            if (visible && active) {
                setInitialSelection();
            }
        }
        function onMonitorWallpapersChanged() {
            loadWallpaperDirectory();
            if (visible && active) {
                setInitialSelection();
            }
        }
        function onPerMonitorWallpaperChanged() {
            loadWallpaperDirectory();
            if (visible && active) {
                setInitialSelection();
            }
        }
    }

    onTargetScreenNameChanged: {
        loadWallpaperDirectory();
        if (visible && active) {
            setInitialSelection();
        }
    }

    function collectWallpaperPaths() {
        const paths = [];
        for (var i = 0; i < wallpaperFolderModel.count; i++) {
            const filePath = wallpaperFolderModel.get(i, "filePath");
            if (filePath) {
                paths.push(filePath.toString().replace(/^file:\/\//, ''));
            }
        }
        return paths;
    }

    Connections {
        target: wallpaperFolderModel
        function onCountChanged() {
            if (wallpaperFolderModel.status === FolderListModel.Ready) {
                if (visible && active) {
                    setInitialSelection();
                }
                updateSelectedFileName();
                thumbnailPreloader.paths = collectWallpaperPaths();
            }
        }
        function onStatusChanged() {
            if (wallpaperFolderModel.status === FolderListModel.Ready && wallpaperFolderModel.count > 0) {
                if (visible && active) {
                    setInitialSelection();
                }
                updateSelectedFileName();
                thumbnailPreloader.paths = collectWallpaperPaths();
            }
        }
    }

    WallpaperThumbnailPreloader {
        id: thumbnailPreloader
        cacheSize: 256
    }

    FolderListModel {
        id: wallpaperFolderModel

        showDirsFirst: false
        showDotAndDotDot: false
        showHidden: false
        caseSensitive: false
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp", "*.jxl", "*.avif", "*.heif", "*.exr"]
        showFiles: true
        showDirs: false
        sortField: {
            switch (root.sortBy) {
            case "size":
                return FolderListModel.Size;
            case "modified":
                return FolderListModel.Time;
            case "type":
                return FolderListModel.Type;
            default:
                return FolderListModel.Name;
            }
        }
        sortReversed: !root.sortAscending
        folder: wallpaperDir ? "file://" + wallpaperDir.split('/').map(s => encodeURIComponent(s)).join('/') : ""
    }

    FileBrowserSurfaceModal {
        id: wallpaperBrowser

        browserTitle: I18n.tr("Select Wallpaper Directory", "wallpaper directory file browser title")
        browserIcon: "folder_open"
        browserType: "wallpaper"
        showHiddenFiles: false
        fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp", "*.jxl", "*.avif", "*.heif", "*.exr"]
        parentPopout: root.parentPopout

        onFileSelected: path => {
            const cleanPath = path.replace(/^file:\/\//, '');
            setCurrentWallpaper(cleanPath);

            const dirPath = cleanPath.substring(0, cleanPath.lastIndexOf('/'));
            if (dirPath) {
                wallpaperDir = dirPath;
                CacheData.wallpaperLastPath = dirPath;
                CacheData.saveCache();
            }
            close();
        }
    }

    Column {
        id: contentColumn
        anchors.fill: parent
        spacing: 0

        Item {
            width: parent.width
            height: parent.height - 50

            GridView {
                id: wallpaperGrid
                anchors.centerIn: parent
                width: parent.width - Theme.spacingS
                height: parent.height - Theme.spacingS
                cellWidth: width / 4
                cellHeight: height / 4
                clip: true
                enabled: root.active
                interactive: root.active
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: false
                activeFocusOnTab: false
                highlightFollowsCurrentItem: true
                highlightMoveDuration: enableAnimation ? Theme.shortDuration : 0
                focus: false

                highlight: Item {
                    z: 1000
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingXS
                        color: "transparent"
                        border.width: 3
                        border.color: Theme.primary
                        radius: Theme.cornerRadius
                    }
                }

                model: {
                    root.gridRevision; // re-evaluate when sort order changes in place
                    const startIndex = currentPage * itemsPerPage;
                    const endIndex = Math.min(startIndex + itemsPerPage, wallpaperFolderModel.count);
                    const items = [];
                    for (var i = startIndex; i < endIndex; i++) {
                        const filePath = wallpaperFolderModel.get(i, "filePath");
                        if (filePath) {
                            items.push(filePath.toString().replace(/^file:\/\//, ''));
                        }
                    }
                    return items;
                }

                onModelChanged: {
                    const clampedIndex = model.length > 0 ? Math.min(Math.max(0, gridIndex), model.length - 1) : 0;
                    if (gridIndex !== clampedIndex) {
                        gridIndex = clampedIndex;
                    }
                }

                onCountChanged: {
                    if (count > 0) {
                        const clampedIndex = Math.min(gridIndex, count - 1);
                        currentIndex = clampedIndex;
                        positionViewAtIndex(clampedIndex, GridView.Contain);
                    }
                    Qt.callLater(() => {
                        enableAnimation = true;
                    });
                }

                Connections {
                    target: root
                    function onGridIndexChanged() {
                        if (wallpaperGrid.count > 0) {
                            wallpaperGrid.currentIndex = gridIndex;
                            if (!enableAnimation) {
                                wallpaperGrid.positionViewAtIndex(gridIndex, GridView.Contain);
                            }
                        }
                    }
                }

                delegate: Item {
                    width: wallpaperGrid.cellWidth
                    height: wallpaperGrid.cellHeight

                    property string wallpaperPath: modelData || ""
                    property bool isSelected: getCurrentWallpaper() === modelData

                    Rectangle {
                        id: wallpaperCard
                        anchors.fill: parent
                        anchors.margins: Theme.spacingXS
                        color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                        radius: Theme.cornerRadius
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            color: isSelected ? Theme.primaryPressed : Theme.withAlpha(Theme.primaryPressed, 0)
                            radius: parent.radius

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }

                        Rectangle {
                            id: maskRect
                            width: thumbnailImage.width
                            height: thumbnailImage.height
                            radius: Theme.cornerRadius
                            visible: false
                            layer.enabled: true
                        }

                        CachingImage {
                            id: thumbnailImage
                            anchors.fill: parent
                            imagePath: modelData || ""
                            maxCacheSize: 256

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1.0
                                maskSource: maskRect
                            }
                        }

                        StateLayer {
                            anchors.fill: parent
                            cornerRadius: parent.radius
                            stateColor: Theme.primary
                        }

                        MouseArea {
                            id: wallpaperMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                gridIndex = index;
                                if (modelData) {
                                    setCurrentWallpaper(modelData);
                                }
                            }
                        }
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: wallpaperFolderModel.count === 0
                text: I18n.tr("No wallpapers found\n\nClick the folder icon below to browse")
                font.pixelSize: 14
                color: Theme.outline
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Column {
            width: parent.width
            height: 50

            Row {
                width: parent.width
                height: 32
                spacing: Theme.spacingS

                Item {
                    width: (parent.width - controlsRow.width - sortButton.width - browseButton.width - Theme.spacingS * 3) / 2
                    height: parent.height
                }

                Row {
                    id: controlsRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    DankActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "skip_previous"
                        iconSize: 20
                        buttonSize: 32
                        enabled: totalPages > 1
                        opacity: enabled ? 1.0 : 0.3
                        tooltipText: I18n.tr("Previous page")
                        tooltipSide: "top"
                        onClicked: {
                            if (totalPages > 1) {
                                currentPage = (currentPage - 1 + totalPages) % totalPages;
                            }
                        }
                    }

                    StyledText {
                        id: pageIndicator
                        anchors.verticalCenter: parent.verticalCenter
                        text: wallpaperFolderModel.count > 0 ? (wallpaperFolderModel.count === 1 ? I18n.tr("%1 wallpaper  •  %2 / %3").arg(wallpaperFolderModel.count).arg(currentPage + 1).arg(totalPages) : I18n.tr("%1 wallpapers  •  %2 / %3").arg(wallpaperFolderModel.count).arg(currentPage + 1).arg(totalPages)) : I18n.tr("No wallpapers")
                        font.pixelSize: 14
                        color: pageIndicatorMouseArea.containsMouse && pageIndicatorMouseArea.enabled ? Theme.primary : Theme.surfaceText
                        opacity: 0.7

                        MouseArea {
                            id: pageIndicatorMouseArea
                            anchors.fill: parent
                            enabled: totalPages > 1
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                sortMenu.visible = false;
                                pageJumpPopup.visible = !pageJumpPopup.visible;
                            }
                            onEntered: if (enabled)
                                pageJumpTooltip.show(I18n.tr("Jump to page"), pageIndicator, 0, 0, "top")
                            onExited: pageJumpTooltip.hide()
                        }

                        DankTooltipV2 {
                            id: pageJumpTooltip
                        }
                    }

                    DankActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "skip_next"
                        iconSize: 20
                        buttonSize: 32
                        enabled: totalPages > 1
                        opacity: enabled ? 1.0 : 0.3
                        tooltipText: I18n.tr("Next page")
                        tooltipSide: "top"
                        onClicked: {
                            if (totalPages > 1) {
                                currentPage = (currentPage + 1) % totalPages;
                            }
                        }
                    }
                }

                DankActionButton {
                    id: sortButton
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "sort"
                    iconSize: 20
                    buttonSize: 32
                    opacity: 0.7
                    enabled: wallpaperFolderModel.count > 0
                    tooltipText: I18n.tr("Sort wallpapers")
                    tooltipSide: "top"
                    onClicked: {
                        pageJumpPopup.visible = false;
                        sortMenu.visible = !sortMenu.visible;
                    }
                }

                DankActionButton {
                    id: browseButton
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "folder_open"
                    iconSize: 20
                    buttonSize: 32
                    opacity: 0.7
                    tooltipText: I18n.tr("Choose wallpaper folder")
                    tooltipSide: "top"
                    onClicked: wallpaperBrowser.open()
                }
            }

            StyledText {
                width: parent.width
                height: 18
                text: selectedFileName
                font.pixelSize: 12
                color: Theme.surfaceText
                opacity: 0.5
                visible: selectedFileName !== ""
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    function jumpToPage(value) {
        const n = parseInt(value);
        if (!isNaN(n)) {
            currentPage = Math.max(0, Math.min(totalPages - 1, n - 1));
        }
        pageJumpPopup.visible = false;
    }

    // Click anywhere outside an open overlay to dismiss it.
    MouseArea {
        anchors.fill: parent
        z: 99
        visible: sortMenu.visible || pageJumpPopup.visible
        enabled: visible
        onClicked: closeOverlays()
    }

    BackdropBlur {
        visible: sortMenu.visible
        z: 100
        width: sortMenu.width
        height: sortMenu.height
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Theme.spacingM
        anchors.bottomMargin: 56
        radius: Theme.cornerRadius
        sourceItem: contentColumn
    }

    FileBrowserSortMenu {
        id: sortMenu
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Theme.spacingM
        anchors.bottomMargin: 56
        z: 101
        surfaceColor: Theme.readableSurface
        sortBy: root.sortBy
        sortAscending: root.sortAscending
        onSortBySelected: value => {
            root.sortBy = value;
            root.persistSort();
        }
        onSortOrderSelected: ascending => {
            root.sortAscending = ascending;
            root.persistSort();
        }
    }

    BackdropBlur {
        visible: pageJumpPopup.visible
        z: 100
        width: pageJumpPopup.width
        height: pageJumpPopup.height
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 56
        radius: Theme.cornerRadius
        sourceItem: contentColumn
    }

    StyledRect {
        id: pageJumpPopup
        width: 180
        height: jumpColumn.height + Theme.spacingM * 2
        color: Theme.readableSurface
        radius: Theme.cornerRadius
        border.color: Theme.outlineMedium
        border.width: 1
        visible: false
        z: 101
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 56

        onVisibleChanged: {
            if (visible) {
                pageJumpField.text = (root.currentPage + 1).toString();
                pageJumpField.forceActiveFocus();
                pageJumpField.selectAll();
            }
        }

        Column {
            id: jumpColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingXS

            StyledText {
                text: I18n.tr("Jump to page (1 - %1)").arg(root.totalPages)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
                font.weight: Font.Medium
            }

            DankTextField {
                id: pageJumpField
                width: parent.width
                placeholderText: "1 - " + root.totalPages
                maximumLength: 6
                topPadding: Theme.spacingS
                bottomPadding: Theme.spacingS
                validator: IntValidator {
                    bottom: 1
                    top: root.totalPages
                }
                onAccepted: root.jumpToPage(text)
            }
        }
    }
}
