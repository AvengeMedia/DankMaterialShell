import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Modals.Spotlight
import qs.Modules.AppDrawer
import qs.Services
import qs.Widgets

Item {
    id: spotlightKeyHandler

    property alias appLauncher: appLauncher
    property alias searchField: searchField
    property alias fileSearchController: fileSearchController
    property var parentModal: null
    property string searchMode: "apps"

    function resetScroll() {
        if (searchMode === "apps") {
            resultsView.resetScroll()
        } else {
            fileSearchResults.resetScroll()
        }
    }

    function updateSearchMode() {
        if (searchField.text.startsWith("/")) {
            if (searchMode !== "files") {
                searchMode = "files"
            }
            const query = searchField.text.substring(1)
            fileSearchController.searchQuery = query
        } else {
            if (searchMode !== "apps") {
                searchMode = "apps"
                fileSearchController.reset()
                appLauncher.searchQuery = searchField.text
            }
        }
    }

    onSearchModeChanged: {
        if (searchMode === "files") {
            appLauncher.keyboardNavigationActive = false
        } else {
            fileSearchController.keyboardNavigationActive = false
        }
    }

    anchors.fill: parent
    focus: true
    clip: false
    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            if (parentModal)
                            parentModal.hide()

                            event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            if (searchMode === "apps") {
                                appLauncher.selectNext()
                            } else {
                                fileSearchController.selectNext()
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            if (searchMode === "apps") {
                                appLauncher.selectPrevious()
                            } else {
                                fileSearchController.selectPrevious()
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Right && searchMode === "apps" && appLauncher.viewMode === "grid") {
                            appLauncher.selectNextInRow()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Left && searchMode === "apps" && appLauncher.viewMode === "grid") {
                            appLauncher.selectPreviousInRow()
                            event.accepted = true
                        } else if (event.key == Qt.Key_J && event.modifiers & Qt.ControlModifier) {
                            if (searchMode === "apps") {
                                appLauncher.selectNext()
                            } else {
                                fileSearchController.selectNext()
                            }
                            event.accepted = true
                        } else if (event.key == Qt.Key_K && event.modifiers & Qt.ControlModifier) {
                            if (searchMode === "apps") {
                                appLauncher.selectPrevious()
                            } else {
                                fileSearchController.selectPrevious()
                            }
                            event.accepted = true
                        } else if (event.key == Qt.Key_L && event.modifiers & Qt.ControlModifier && searchMode === "apps" && appLauncher.viewMode === "grid") {
                            appLauncher.selectNextInRow()
                            event.accepted = true
                        } else if (event.key == Qt.Key_H && event.modifiers & Qt.ControlModifier && searchMode === "apps" && appLauncher.viewMode === "grid") {
                            appLauncher.selectPreviousInRow()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Tab) {
                            if (searchMode === "apps") {
                                if (appLauncher.viewMode === "grid") {
                                    appLauncher.selectNextInRow()
                                } else {
                                    appLauncher.selectNext()
                                }
                            } else {
                                fileSearchController.selectNext()
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Backtab) {
                            if (searchMode === "apps") {
                                if (appLauncher.viewMode === "grid") {
                                    appLauncher.selectPreviousInRow()
                                } else {
                                    appLauncher.selectPrevious()
                                }
                            } else {
                                fileSearchController.selectPrevious()
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_N && event.modifiers & Qt.ControlModifier) {
                            if (searchMode === "apps") {
                                if (appLauncher.viewMode === "grid") {
                                    appLauncher.selectNextInRow()
                                } else {
                                    appLauncher.selectNext()
                                }
                            } else {
                                fileSearchController.selectNext()
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_P && event.modifiers & Qt.ControlModifier) {
                            if (searchMode === "apps") {
                                if (appLauncher.viewMode === "grid") {
                                    appLauncher.selectPreviousInRow()
                                } else {
                                    appLauncher.selectPrevious()
                                }
                            } else {
                                fileSearchController.selectPrevious()
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (searchMode === "apps") {
                                appLauncher.launchSelected()
                            } else if (searchMode === "files") {
                                fileSearchController.openSelected()
                            }
                            event.accepted = true
                        }
                    }

    AppLauncher {
        id: appLauncher

        viewMode: SettingsData.spotlightModalViewMode
        gridColumns: 4
        onAppLaunched: () => {
                           if (parentModal)
                           parentModal.hide()
                       }
        onViewModeSelected: mode => {
                                SettingsData.set("spotlightModalViewMode", mode)
                            }
    }

    FileSearchController {
        id: fileSearchController

        onFileOpened: () => {
                          if (parentModal)
                          parentModal.hide()
                      }
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingM
        clip: false

        Row {
            width: parent.width
            spacing: Theme.spacingM
            leftPadding: Theme.spacingS

            DankTextField {
                id: searchField

                width: parent.width - 80 - Theme.spacingL
                height: 56
                cornerRadius: Theme.cornerRadius
                backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                normalBorderColor: Theme.outlineMedium
                focusedBorderColor: Theme.primary
                leftIconName: searchMode === "files" ? "folder" : "search"
                leftIconSize: Theme.iconSize
                leftIconColor: Theme.surfaceVariantText
                leftIconFocusedColor: Theme.primary
                showClearButton: true
                textColor: Theme.surfaceText
                font.pixelSize: Theme.fontSizeLarge
                enabled: parentModal ? parentModal.spotlightOpen : true
                placeholderText: ""
                ignoreLeftRightKeys: appLauncher.viewMode !== "list"
                ignoreTabKeys: true
                keyForwardTargets: [spotlightKeyHandler]
                onTextChanged: {
                    if (searchMode === "apps") {
                        appLauncher.searchQuery = text
                    }
                }
                onTextEdited: {
                    updateSearchMode()
                }
                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Escape) {
                                        if (parentModal)
                                        parentModal.hide()

                                        event.accepted = true
                                    } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && text.length > 0) {
                                        if (searchMode === "apps") {
                                            if (appLauncher.keyboardNavigationActive && appLauncher.model.count > 0)
                                            appLauncher.launchSelected()
                                            else if (appLauncher.model.count > 0)
                                            appLauncher.launchApp(appLauncher.model.get(0))
                                        } else if (searchMode === "files") {
                                            if (fileSearchController.model.count > 0)
                                            fileSearchController.openSelected()
                                        }
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up || event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Tab || event.key
                                               === Qt.Key_Backtab || ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && text.length === 0)) {
                                        event.accepted = false
                                    }
                                }
            }

            Row {
                spacing: Theme.spacingXS
                visible: searchMode === "apps" && appLauncher.model.count > 0
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 36
                    height: 36
                    radius: Theme.cornerRadius
                    color: appLauncher.viewMode === "list" ? Theme.primaryHover : listViewArea.containsMouse ? Theme.surfaceHover : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: "view_list"
                        size: 18
                        color: appLauncher.viewMode === "list" ? Theme.primary : Theme.surfaceText
                    }

                    MouseArea {
                        id: listViewArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: () => {
                                       appLauncher.setViewMode("list")
                                   }
                    }
                }

                Rectangle {
                    width: 36
                    height: 36
                    radius: Theme.cornerRadius
                    color: appLauncher.viewMode === "grid" ? Theme.primaryHover : gridViewArea.containsMouse ? Theme.surfaceHover : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: "grid_view"
                        size: 18
                        color: appLauncher.viewMode === "grid" ? Theme.primary : Theme.surfaceText
                    }

                    MouseArea {
                        id: gridViewArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: () => {
                                       appLauncher.setViewMode("grid")
                                   }
                    }
                }
            }

            Row {
                spacing: Theme.spacingXS
                visible: searchMode === "files"
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: filenameFilterButton

                    width: 36
                    height: 36
                    radius: Theme.cornerRadius
                    color: fileSearchController.searchField === "filename" ? Theme.primaryHover : filenameFilterArea.containsMouse ? Theme.surfaceHover : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: "title"
                        size: 18
                        color: fileSearchController.searchField === "filename" ? Theme.primary : Theme.surfaceText
                    }

                    MouseArea {
                        id: filenameFilterArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: () => {
                                       fileSearchController.searchField = "filename"
                                   }
                        onEntered: {
                            filenameTooltipLoader.active = true
                            Qt.callLater(() => {
                                             if (filenameTooltipLoader.item) {
                                                 const p = mapToItem(null, width / 2, height + Theme.spacingXS)
                                                 filenameTooltipLoader.item.show(I18n.tr("Search filenames"), p.x, p.y, null)
                                             }
                                         })
                        }
                        onExited: {
                            if (filenameTooltipLoader.item)
                                filenameTooltipLoader.item.hide()

                            filenameTooltipLoader.active = false
                        }
                    }
                }

                Rectangle {
                    id: contentFilterButton

                    width: 36
                    height: 36
                    radius: Theme.cornerRadius
                    color: fileSearchController.searchField === "body" ? Theme.primaryHover : contentFilterArea.containsMouse ? Theme.surfaceHover : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: "description"
                        size: 18
                        color: fileSearchController.searchField === "body" ? Theme.primary : Theme.surfaceText
                    }

                    MouseArea {
                        id: contentFilterArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: () => {
                                       fileSearchController.searchField = "body"
                                   }
                        onEntered: {
                            contentTooltipLoader.active = true
                            Qt.callLater(() => {
                                             if (contentTooltipLoader.item) {
                                                 const p = mapToItem(null, width / 2, height + Theme.spacingXS)
                                                 contentTooltipLoader.item.show(I18n.tr("Search file contents"), p.x, p.y, null)
                                             }
                                         })
                        }
                        onExited: {
                            if (contentTooltipLoader.item)
                                contentTooltipLoader.item.hide()

                            contentTooltipLoader.active = false
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: parent.height - y

            SpotlightResults {
                id: resultsView
                anchors.fill: parent
                appLauncher: spotlightKeyHandler.appLauncher
                contextMenu: contextMenu
                visible: searchMode === "apps"
            }

            FileSearchResults {
                id: fileSearchResults
                anchors.fill: parent
                fileSearchController: spotlightKeyHandler.fileSearchController
                visible: searchMode === "files"
            }
        }
    }

    SpotlightContextMenu {
        id: contextMenu

        appLauncher: spotlightKeyHandler.appLauncher
        parentHandler: spotlightKeyHandler
    }

    MouseArea {
        anchors.fill: parent
        visible: contextMenu.visible
        z: 999
        onClicked: () => {
                       contextMenu.hide()
                   }

        MouseArea {

            x: contextMenu.x
            y: contextMenu.y
            width: contextMenu.width
            height: contextMenu.height
            onClicked: () => {}
        }
    }

    Loader {
        id: filenameTooltipLoader

        active: false
        sourceComponent: DankTooltip {}
    }

    Loader {
        id: contentTooltipLoader

        active: false
        sourceComponent: DankTooltip {}
    }
}
