import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

Item {
    id: root

    implicitWidth: 700
    implicitHeight: 410

    property var wallpaperList: []
    property string wallpaperDir: ""
    property int currentPage: 0
    property int itemsPerPage: 16
    property int totalPages: Math.max(1, Math.ceil(wallpaperList.length / itemsPerPage))
    property bool active: false
    property Item focusTarget: wallpaperGrid
    property Item tabBarItem: null
    property int gridIndex: 0
    property Item keyForwardTarget: null
    property int lastPage: 0
    property bool enableAnimation: false

    signal requestTabChange(int newIndex)

    onCurrentPageChanged: {
        if (currentPage !== lastPage) {
            enableAnimation = false
            lastPage = currentPage
        }
    }

    onVisibleChanged: {
        if (visible && active) {
            setInitialSelection()
        }
    }

    Component.onCompleted: {
        loadWallpapers()
        if (visible && active) {
            setInitialSelection()
        }
    }

    onActiveChanged: {
        if (active && visible) {
            setInitialSelection()
        }
    }

    function handleKeyEvent(event) {
        const columns = 4
        const rows = 4
        const currentRow = Math.floor(gridIndex / columns)
        const currentCol = gridIndex % columns
        const visibleCount = wallpaperGrid.model.length

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (gridIndex >= 0) {
                const item = wallpaperGrid.currentItem
                if (item && item.wallpaperPath) {
                    SessionData.setWallpaper(item.wallpaperPath)
                }
            }
            return true
        }

        if (event.key === Qt.Key_Right) {
            if (gridIndex + 1 < visibleCount) {
                // Move right within current page
                gridIndex++
            } else if (gridIndex === visibleCount - 1 && currentPage < totalPages - 1) {
                // At last item in page, go to next page
                gridIndex = 0
                currentPage++
            }
            return true
        }

        if (event.key === Qt.Key_Left) {
            if (gridIndex > 0) {
                // Move left within current page
                gridIndex--
            } else if (gridIndex === 0 && currentPage > 0) {
                // At first item in page, go to previous page (last item)
                currentPage--
                gridIndex = Math.min(itemsPerPage - 1, wallpaperList.length - currentPage * itemsPerPage - 1)
            }
            return true
        }

        if (event.key === Qt.Key_Down) {
            if (gridIndex + columns < visibleCount) {
                // Move down within current page
                gridIndex += columns
            } else if (gridIndex >= visibleCount - columns && currentPage < totalPages - 1) {
                // In last row, go to next page
                gridIndex = currentCol
                currentPage++
            }
            return true
        }

        if (event.key === Qt.Key_Up) {
            if (gridIndex >= columns) {
                // Move up within current page
                gridIndex -= columns
            } else if (gridIndex < columns && currentPage > 0) {
                // In first row, go to previous page (last row)
                currentPage--
                const prevPageCount = Math.min(itemsPerPage, wallpaperList.length - currentPage * itemsPerPage)
                const prevPageRows = Math.ceil(prevPageCount / columns)
                gridIndex = (prevPageRows - 1) * columns + currentCol
                gridIndex = Math.min(gridIndex, prevPageCount - 1)
            }
            return true
        }

        if (event.key === Qt.Key_PageUp && currentPage > 0) {
            gridIndex = 0
            currentPage--
            return true
        }

        if (event.key === Qt.Key_PageDown && currentPage < totalPages - 1) {
            gridIndex = 0
            currentPage++
            return true
        }

        if (event.key === Qt.Key_Home && event.modifiers & Qt.ControlModifier) {
            gridIndex = 0
            currentPage = 0
            return true
        }

        if (event.key === Qt.Key_End && event.modifiers & Qt.ControlModifier) {
            gridIndex = 0
            currentPage = totalPages - 1
            return true
        }

        return false
    }

    function setInitialSelection() {
        if (!SessionData.wallpaperPath) {
            gridIndex = 0
            return
        }

        const startIndex = currentPage * itemsPerPage
        const endIndex = Math.min(startIndex + itemsPerPage, wallpaperList.length)
        const pageWallpapers = wallpaperList.slice(startIndex, endIndex)

        for (let i = 0; i < pageWallpapers.length; i++) {
            if (pageWallpapers[i] === SessionData.wallpaperPath) {
                gridIndex = i
                return
            }
        }
        gridIndex = 0
    }

    onWallpaperListChanged: {
        if (visible && active) {
            setInitialSelection()
        }
    }

    function loadWallpapers() {
        const currentWallpaper = SessionData.wallpaperPath
        
        // Try current wallpaper path / fallback to wallpaperLastPath
        if (!currentWallpaper || currentWallpaper.startsWith("#") || currentWallpaper.startsWith("we:")) {
            if (CacheData.wallpaperLastPath && CacheData.wallpaperLastPath !== "") {
                wallpaperDir = CacheData.wallpaperLastPath
            } else {
                wallpaperDir = ""
                wallpaperList = []
            }
            return
        }

        wallpaperDir = currentWallpaper.substring(0, currentWallpaper.lastIndexOf('/'))
    }

    function updateWallpaperList() {
        if (!wallpaperFolderModel || wallpaperFolderModel.count === 0) {
            wallpaperList = []
            currentPage = 0
            gridIndex = 0
            return
        }

        // Build list from FolderListModel
        const files = []
        for (let i = 0; i < wallpaperFolderModel.count; i++) {
            const filePath = wallpaperFolderModel.get(i, "filePath")
            if (filePath) {
                // Remove file:// prefix if present
                const cleanPath = filePath.toString().replace(/^file:\/\//, '')
                files.push(cleanPath)
            }
        }

        wallpaperList = files

        const currentPath = SessionData.wallpaperPath
        const selectedIndex = currentPath ? wallpaperList.indexOf(currentPath) : -1

        if (selectedIndex >= 0) {
            currentPage = Math.floor(selectedIndex / itemsPerPage)
            gridIndex = selectedIndex % itemsPerPage
        } else {
            const maxPage = Math.max(0, Math.ceil(files.length / itemsPerPage) - 1)
            currentPage = Math.min(Math.max(0, currentPage), maxPage)
            gridIndex = 0
        }
    }

    Connections {
        target: SessionData
        function onWallpaperPathChanged() {
            loadWallpapers()
        }
    }

    FolderListModel {
        id: wallpaperFolderModel

        showDirsFirst: false
        showDotAndDotDot: false
        showHidden: false
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp"]
        showFiles: true
        showDirs: false
        sortField: FolderListModel.Name
        folder: wallpaperDir ? "file://" + wallpaperDir : ""

        onStatusChanged: {
            if (status === FolderListModel.Ready) {
                updateWallpaperList()
            }
        }

        onCountChanged: {
            if (status === FolderListModel.Ready) {
                updateWallpaperList()
            }
        }
    }

    Loader {
        id: wallpaperBrowserLoader
        active: false
        asynchronous: true

        sourceComponent: FileBrowserModal {
            Component.onCompleted: {
                open()
            }
            browserTitle: "Select Wallpaper Directory"
            browserIcon: "folder_open"
            browserType: "wallpaper"
            showHiddenFiles: false
            fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp"]
            allowStacking: true
            
            onFileSelected: (path) => {
                // Set the selected wallpaper
                const cleanPath = path.replace(/^file:\/\//, '')
                SessionData.setWallpaper(cleanPath)
                
                // Extract directory from the selected file and load all wallpapers
                const dirPath = cleanPath.substring(0, cleanPath.lastIndexOf('/'))
                if (dirPath) {
                    wallpaperDir = dirPath
                    CacheData.wallpaperLastPath = dirPath
                    CacheData.saveCache()
                }
                close()
            }
            
            onDialogClosed: {
                Qt.callLater(() => wallpaperBrowserLoader.active = false)
            }
        }
    }

    Column {
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
                    const startIndex = currentPage * itemsPerPage
                    const endIndex = Math.min(startIndex + itemsPerPage, wallpaperList.length)
                    return wallpaperList.slice(startIndex, endIndex)
                }

                onModelChanged: {
                    const clampedIndex = model.length > 0 ? Math.min(Math.max(0, gridIndex), model.length - 1) : 0
                    if (gridIndex !== clampedIndex) {
                        gridIndex = clampedIndex
                    }
                }

                onCountChanged: {
                    if (count > 0) {
                        const clampedIndex = Math.min(gridIndex, count - 1)
                        currentIndex = clampedIndex
                        positionViewAtIndex(clampedIndex, GridView.Contain)
                    }
                    enableAnimation = true
                }

                Connections {
                    target: root
                    function onGridIndexChanged() {
                        if (enableAnimation && wallpaperGrid.count > 0) {
                            wallpaperGrid.currentIndex = gridIndex
                        }
                    }
                }

                delegate: Item {
                    width: wallpaperGrid.cellWidth
                    height: wallpaperGrid.cellHeight

                    property string wallpaperPath: modelData || ""
                    property bool isSelected: SessionData.wallpaperPath === modelData

                    Rectangle {
                        id: wallpaperCard
                        anchors.fill: parent
                        anchors.margins: Theme.spacingXS
                        color: Theme.surfaceContainerHighest
                        radius: Theme.cornerRadius
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            color: isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"
                            radius: parent.radius

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }

                        Image {
                            id: thumbnailImage
                            anchors.fill: parent
                            source: modelData ? `file://${modelData}` : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1.0
                                maskSource: ShaderEffectSource {
                                    sourceItem: Rectangle {
                                        width: thumbnailImage.width
                                        height: thumbnailImage.height
                                        radius: Theme.cornerRadius
                                    }
                                }
                            }
                        }

                        BusyIndicator {
                            anchors.centerIn: parent
                            running: thumbnailImage.status === Image.Loading
                            visible: running
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
                                gridIndex = index
                                if (modelData) {
                                    SessionData.setWallpaper(modelData)
                                }
                                // Don't steal focus - let mainContainer keep it for keyboard nav
                            }
                        }
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: wallpaperList.length === 0
                text: "No wallpapers found\n\nClick the folder icon below to browse"
                font.pixelSize: 14
                color: Theme.outline
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Row {
            width: parent.width
            height: 50
            spacing: Theme.spacingS

            Item {
                width: (parent.width - controlsRow.width - browseButton.width - Theme.spacingS) / 2
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
                    enabled: currentPage > 0
                    opacity: enabled ? 1.0 : 0.3
                    onClicked: {
                        if (currentPage > 0) {
                            currentPage--
                        }
                    }
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: wallpaperList.length > 0 ? `${wallpaperList.length} wallpapers  •  ${currentPage + 1} / ${totalPages}` : "No wallpapers"
                    font.pixelSize: 14
                    color: Theme.surfaceText
                    opacity: 0.7
                }

                DankActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "skip_next"
                    iconSize: 20
                    buttonSize: 32
                    enabled: currentPage < totalPages - 1
                    opacity: enabled ? 1.0 : 0.3
                    onClicked: {
                        if (currentPage < totalPages - 1) {
                            currentPage++
                        }
                    }
                }
            }

            DankActionButton {
                id: browseButton
                anchors.verticalCenter: parent.verticalCenter
                iconName: "folder_open"
                iconSize: 20
                buttonSize: 32
                opacity: 0.7
                onClicked: wallpaperBrowserLoader.active = true
            }
        }
    }
}