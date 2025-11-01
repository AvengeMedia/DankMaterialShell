import Qt.labs.folderlistmodel
import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

Item {
    id: root

    implicitWidth: 700
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
    property int lastPage: 0
    property bool enableAnimation: false
    property string homeDir: StandardPaths.writableLocation(StandardPaths.HomeLocation)
    property string selectedFileName: ""
    property var targetScreen: null
    property string targetScreenName: targetScreen ? targetScreen.name : ""

    signal requestTabChange(int newIndex)

    function getCurrentWallpaper() {
        if (SessionData.perMonitorWallpaper && targetScreenName) {
            return SessionData.getMonitorWallpaper(targetScreenName)
        }
        return SessionData.wallpaperPath
    }

    function setCurrentWallpaper(path) {
        if (SessionData.perMonitorWallpaper && targetScreenName) {
            SessionData.setMonitorWallpaper(targetScreenName, path)
        } else {
            SessionData.setWallpaper(path)
        }
    }

    onCurrentPageChanged: {
        if (currentPage !== lastPage) {
            enableAnimation = false
            lastPage = currentPage
        }
        updateSelectedFileName()
    }

    onGridIndexChanged: {
        updateSelectedFileName()
    }

    onVisibleChanged: {
        if (visible && active) {
            setInitialSelection()
        }
    }

    Component.onCompleted: {
        loadWallpaperDirectory()
    }

    onActiveChanged: {
        if (active && visible) {
            setInitialSelection()
        }
    }

    function handleKeyEvent(event) {
        const columns = 4
        const currentCol = gridIndex % columns
        const visibleCount = Math.min(itemsPerPage, wallpaperFolderModel.count - currentPage * itemsPerPage)

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (gridIndex >= 0 && gridIndex < visibleCount) {
                const absoluteIndex = currentPage * itemsPerPage + gridIndex
                if (absoluteIndex < wallpaperFolderModel.count) {
                    const filePath = wallpaperFolderModel.get(absoluteIndex, "filePath")
                    if (filePath) {
                        setCurrentWallpaper(filePath.toString().replace(/^file:\/\//, ''))
                    }
                }
            }
            return true
        }

        if (event.key === Qt.Key_Right) {
            if (gridIndex + 1 < visibleCount) {
                gridIndex++
            } else if (currentPage < totalPages - 1) {
                gridIndex = 0
                currentPage++
            }
            return true
        }

        if (event.key === Qt.Key_Left) {
            if (gridIndex > 0) {
                gridIndex--
            } else if (currentPage > 0) {
                currentPage--
                const prevPageCount = Math.min(itemsPerPage, wallpaperFolderModel.count - currentPage * itemsPerPage)
                gridIndex = prevPageCount - 1
            }
            return true
        }

        if (event.key === Qt.Key_Down) {
            if (gridIndex + columns < visibleCount) {
                gridIndex += columns
            } else if (currentPage < totalPages - 1) {
                gridIndex = currentCol
                currentPage++
            }
            return true
        }

        if (event.key === Qt.Key_Up) {
            if (gridIndex >= columns) {
                gridIndex -= columns
            } else if (currentPage > 0) {
                currentPage--
                const prevPageCount = Math.min(itemsPerPage, wallpaperFolderModel.count - currentPage * itemsPerPage)
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
            currentPage = totalPages - 1
            const lastPageCount = Math.min(itemsPerPage, wallpaperFolderModel.count - currentPage * itemsPerPage)
            gridIndex = Math.max(0, lastPageCount - 1)
            return true
        }

        return false
    }

    function setInitialSelection() {
        const currentWallpaper = getCurrentWallpaper()
        if (!currentWallpaper || wallpaperFolderModel.count === 0) {
            gridIndex = 0
            updateSelectedFileName()
            Qt.callLater(() => {
                             enableAnimation = true
                         })
            return
        }

        for (var i = 0; i < wallpaperFolderModel.count; i++) {
            const filePath = wallpaperFolderModel.get(i, "filePath")
            if (filePath && filePath.toString().replace(/^file:\/\//, '') === currentWallpaper) {
                const targetPage = Math.floor(i / itemsPerPage)
                const targetIndex = i % itemsPerPage
                currentPage = targetPage
                gridIndex = targetIndex
                updateSelectedFileName()
                Qt.callLater(() => {
                                 enableAnimation = true
                             })
                return
            }
        }
        gridIndex = 0
        updateSelectedFileName()
        Qt.callLater(() => {
                         enableAnimation = true
                     })
    }

    function loadWallpaperDirectory() {
        const currentWallpaper = getCurrentWallpaper()

        if (!currentWallpaper || currentWallpaper.startsWith("#")) {
            if (CacheData.wallpaperLastPath && CacheData.wallpaperLastPath !== "") {
                wallpaperDir = CacheData.wallpaperLastPath
            } else {
                wallpaperDir = ""
            }
            return
        }

        wallpaperDir = currentWallpaper.substring(0, currentWallpaper.lastIndexOf('/'))
    }

    function updateSelectedFileName() {
        if (wallpaperFolderModel.count === 0) {
            selectedFileName = ""
            return
        }

        const absoluteIndex = currentPage * itemsPerPage + gridIndex
        if (absoluteIndex < wallpaperFolderModel.count) {
            const filePath = wallpaperFolderModel.get(absoluteIndex, "filePath")
            if (filePath) {
                const pathStr = filePath.toString().replace(/^file:\/\//, '')
                selectedFileName = pathStr.substring(pathStr.lastIndexOf('/') + 1)
                return
            }
        }
        selectedFileName = ""
    }

    Connections {
        target: SessionData
        function onWallpaperPathChanged() {
            loadWallpaperDirectory()
            if (visible && active) {
                setInitialSelection()
            }
        }
        function onMonitorWallpapersChanged() {
            loadWallpaperDirectory()
            if (visible && active) {
                setInitialSelection()
            }
        }
    }

    onTargetScreenNameChanged: {
        loadWallpaperDirectory()
        if (visible && active) {
            setInitialSelection()
        }
    }

    Connections {
        target: wallpaperFolderModel
        function onCountChanged() {
            if (wallpaperFolderModel.status === FolderListModel.Ready) {
                if (visible && active) {
                    setInitialSelection()
                }
                updateSelectedFileName()
            }
        }
        function onStatusChanged() {
            if (wallpaperFolderModel.status === FolderListModel.Ready && wallpaperFolderModel.count > 0) {
                if (visible && active) {
                    setInitialSelection()
                }
                updateSelectedFileName()
            }
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

            onFileSelected: path => {
                                const cleanPath = path.replace(/^file:\/\//, '')
                                setCurrentWallpaper(cleanPath)

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
                    const endIndex = Math.min(startIndex + itemsPerPage, wallpaperFolderModel.count)
                    const items = []
                    for (var i = startIndex; i < endIndex; i++) {
                        const filePath = wallpaperFolderModel.get(i, "filePath")
                        if (filePath) {
                            items.push(filePath.toString().replace(/^file:\/\//, ''))
                        }
                    }
                    return items
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
                        if (wallpaperGrid.count > 0) {
                            wallpaperGrid.currentIndex = gridIndex
                            if (!enableAnimation) {
                                wallpaperGrid.positionViewAtIndex(gridIndex, GridView.Contain)
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
                                    setCurrentWallpaper(modelData)
                                }
                            }
                        }
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: wallpaperFolderModel.count === 0
                text: "No wallpapers found\n\nClick the folder icon below to browse"
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
                        text: wallpaperFolderModel.count > 0 ? `${wallpaperFolderModel.count} wallpapers  •  ${currentPage + 1} / ${totalPages}` : "No wallpapers"
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
}
