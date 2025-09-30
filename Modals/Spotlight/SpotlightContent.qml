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
    property var parentModal: null

    anchors.fill: parent
    focus: true
    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            if (parentModal)
                            parentModal.hide()

                            event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            appLauncher.selectNext()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            appLauncher.selectPrevious()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Right && appLauncher.viewMode === "grid") {
                            appLauncher.selectNextInRow()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Left && appLauncher.viewMode === "grid") {
                            appLauncher.selectPreviousInRow()
                            event.accepted = true
                        } else if (event.key == Qt.Key_J && event.modifiers & Qt.ControlModifier) {
                            appLauncher.selectNext()
                            event.accepted = true
                        } else if (event.key == Qt.Key_K && event.modifiers & Qt.ControlModifier) {
                            appLauncher.selectPrevious()
                            event.accepted = true
                        } else if (event.key == Qt.Key_L && event.modifiers & Qt.ControlModifier && appLauncher.viewMode === "grid") {
                            appLauncher.selectNextInRow()
                            event.accepted = true
                        } else if (event.key == Qt.Key_H && event.modifiers & Qt.ControlModifier && appLauncher.viewMode === "grid") {
                            appLauncher.selectPreviousInRow()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Tab) {
                            if (appLauncher.viewMode === "grid") {
                                appLauncher.selectNextInRow()
                            } else {
                                appLauncher.selectNext()
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Backtab) {
                            if (appLauncher.viewMode === "grid") {
                                appLauncher.selectPreviousInRow()
                            } else {
                                appLauncher.selectPrevious()
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_N && event.modifiers & Qt.ControlModifier) {
                            if (appLauncher.viewMode === "grid") {
                                appLauncher.selectNextInRow()
                            } else {
                                appLauncher.selectNext()
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_P && event.modifiers & Qt.ControlModifier) {
                            if (appLauncher.viewMode === "grid") {
                                appLauncher.selectPreviousInRow()
                            } else {
                                appLauncher.selectPrevious()
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            appLauncher.launchSelected()
                            event.accepted = true
                        } else if (!searchField.activeFocus && event.text && event.text.length > 0 && event.text.match(/[a-zA-Z0-9\\s]/)) {
                            searchField.forceActiveFocus()
                            searchField.insertText(event.text)
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
                                SettingsData.setSpotlightModalViewMode(mode)
                            }
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingM

        Rectangle {
            width: parent.width
            height: categorySelector.height + Theme.spacingS * 2
            radius: Theme.cornerRadius
            color: "transparent"
            visible: appLauncher.categories.length > 1 || appLauncher.model.count > 0

            CategorySelector {
                id: categorySelector

                anchors.centerIn: parent
                width: parent.width - Theme.spacingS * 2
                categories: appLauncher.categories
                selectedCategory: appLauncher.selectedCategory
                compact: false
                onCategorySelected: category => {
                                        appLauncher.setCategory(category)
                                    }
            }
        }

        Row {
            width: parent.width
            spacing: Theme.spacingM
            leftPadding: Theme.spacingS

            DankTextField {
                id: searchField

                width: parent.width - 80 - Theme.spacingL
                height: 56
                cornerRadius: Theme.cornerRadius
                backgroundColor: Theme.surfaceContainerHigh
                normalBorderColor: Theme.outlineMedium
                focusedBorderColor: Theme.primary
                leftIconName: "search"
                leftIconSize: Theme.iconSize
                leftIconColor: Theme.surfaceVariantText
                leftIconFocusedColor: Theme.primary
                showClearButton: true
                textColor: Theme.surfaceText
                font.pixelSize: Theme.fontSizeLarge
                enabled: parentModal ? parentModal.spotlightOpen : true
                placeholderText: ""
                ignoreLeftRightKeys: true
                keyForwardTargets: [spotlightKeyHandler]
                text: appLauncher.searchQuery
                onTextEdited: () => {
                                  appLauncher.searchQuery = text
                              }
                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Escape) {
                                        if (parentModal)
                                        parentModal.hide()

                                        event.accepted = true
                                    } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && text.length > 0) {
                                        if (appLauncher.keyboardNavigationActive && appLauncher.model.count > 0)
                                        appLauncher.launchSelected()
                                        else if (appLauncher.model.count > 0)
                                        appLauncher.launchApp(appLauncher.model.get(0))
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up || event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab || ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && text.length === 0)) {
                                        event.accepted = false
                                    }
                                }
            }

            Row {
                spacing: Theme.spacingXS
                visible: appLauncher.model.count > 0
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
        }

        SpotlightResults {
            appLauncher: spotlightKeyHandler.appLauncher
            contextMenu: contextMenu
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
                       contextMenu.close()
                   }

        MouseArea {

            // Prevent closing when clicking on the menu itself
            x: contextMenu.x
            y: contextMenu.y
            width: contextMenu.width
            height: contextMenu.height
            onClicked: () => {}
        }
    }
}
