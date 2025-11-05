import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Modules.AppDrawer
import qs.Services
import qs.Widgets

DankPopout {
    id: appDrawerPopout

    layerNamespace: "dms:app-launcher"

    property var triggerScreen: null

    // Setting to Exclusive, so virtual keyboards can send input to app drawer
    WlrLayershell.keyboardFocus: shouldBeVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None 

    function show() {
        open()
    }

    function setTriggerPosition(x, y, width, section, screen) {
        triggerX = x
        triggerY = y
        triggerWidth = width
        triggerSection = section
        triggerScreen = screen
    }

    popupWidth: 520
    popupHeight: 600
    triggerX: Theme.spacingL
    triggerY: Math.max(26 + SettingsData.dankBarInnerPadding + 4, Theme.barHeight - 4 - (8 - SettingsData.dankBarInnerPadding)) + SettingsData.dankBarSpacing + SettingsData.dankBarBottomGap - 2
    triggerWidth: 40
    positioning: ""
    screen: triggerScreen

    onShouldBeVisibleChanged: {
        if (shouldBeVisible) {
            appLauncher.searchQuery = ""
            appLauncher.selectedIndex = 0
            appLauncher.setCategory(I18n.tr("All"))
            Qt.callLater(() => {
                             if (contentLoader.item && contentLoader.item.searchField) {
                                 contentLoader.item.searchField.text = ""
                                 contentLoader.item.searchField.forceActiveFocus()
                             }
                         })
        }
    }

    AppLauncher {
        id: appLauncher

        viewMode: SettingsData.appLauncherViewMode
        gridColumns: 4
        onAppLaunched: appDrawerPopout.close()
        onViewModeSelected: function (mode) {
            SettingsData.set("appLauncherViewMode", mode)
        }
    }

    content: Component {
        Rectangle {
            id: launcherPanel

            property alias searchField: searchField

            color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            radius: Theme.cornerRadius
            antialiasing: true
            smooth: true

            // Multi-layer border effect
            Repeater {
                model: [{
                        "margin": -3,
                        "color": Qt.rgba(0, 0, 0, 0.05),
                        "z": -3
                    }, {
                        "margin": -2,
                        "color": Qt.rgba(0, 0, 0, 0.08),
                        "z": -2
                    }, {
                        "margin": 0,
                        "color": Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12),
                        "z": -1
                    }]
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: modelData.margin
                    color: "transparent"
                    radius: parent.radius + Math.abs(modelData.margin)
                    border.color: modelData.color
                    border.width: 0
                    z: modelData.z
                }
            }

            Item {
                id: keyHandler

                anchors.fill: parent
                focus: true
                readonly property var keyMappings: {
                    const mappings = {}
                    mappings[Qt.Key_Escape] = () => appDrawerPopout.close()
                    mappings[Qt.Key_Down] = () => appLauncher.selectNext()
                    mappings[Qt.Key_Up] = () => appLauncher.selectPrevious()
                    mappings[Qt.Key_Return] = () => appLauncher.launchSelected()
                    mappings[Qt.Key_Enter] = () => appLauncher.launchSelected()
                    mappings[Qt.Key_Tab] = () => appLauncher.viewMode === "grid" ? appLauncher.selectNextInRow() : appLauncher.selectNext()
                    mappings[Qt.Key_Backtab] = () => appLauncher.viewMode === "grid" ? appLauncher.selectPreviousInRow() : appLauncher.selectPrevious()

                    if (appLauncher.viewMode === "grid") {
                        mappings[Qt.Key_Right] = () => appLauncher.selectNextInRow()
                        mappings[Qt.Key_Left] = () => appLauncher.selectPreviousInRow()
                    }

                    return mappings
                }

                Keys.onPressed: function (event) {
                    if (keyMappings[event.key]) {
                        keyMappings[event.key]()
                        event.accepted = true
                        return
                    }

                    if (event.key === Qt.Key_N && event.modifiers & Qt.ControlModifier) {
                        appLauncher.selectNext()
                        event.accepted = true
                        return
                    }

                    if (event.key === Qt.Key_P && event.modifiers & Qt.ControlModifier) {
                        appLauncher.selectPrevious()
                        event.accepted = true
                        return
                    }

                    if (event.key === Qt.Key_J && event.modifiers & Qt.ControlModifier) {
                        appLauncher.selectNext()
                        event.accepted = true
                        return
                    }

                    if (event.key === Qt.Key_K && event.modifiers & Qt.ControlModifier) {
                        appLauncher.selectPrevious()
                        event.accepted = true
                        return
                    }

                    if (appLauncher.viewMode === "grid") {
                        if (event.key === Qt.Key_L && event.modifiers & Qt.ControlModifier) {
                            appLauncher.selectNextInRow()
                            event.accepted = true
                            return
                        }

                        if (event.key === Qt.Key_H && event.modifiers & Qt.ControlModifier) {
                            appLauncher.selectPreviousInRow()
                            event.accepted = true
                            return
                        }
                    }

                }

                Column {
                    width: parent.width - Theme.spacingS * 2
                    height: parent.height - Theme.spacingS * 2
                    x: Theme.spacingS
                    y: Theme.spacingS
                    spacing: Theme.spacingS

                    Item {
                        width: parent.width
                        height: 40

                        StyledText {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Applications")
                            font.pixelSize: Theme.fontSizeLarge + 4
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }

                        StyledText {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            text: appLauncher.model.count + " apps"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                        }
                    }

                    DankTextField {
                        id: searchField

                        width: parent.width - Theme.spacingS * 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 52
                        cornerRadius: Theme.cornerRadius
                        backgroundColor: Theme.withAlpha(Theme.surfaceVariant, Theme.popupTransparency)
                        normalBorderColor: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                        focusedBorderColor: Theme.primary
                        leftIconName: "search"
                        leftIconSize: Theme.iconSize
                        leftIconColor: Theme.surfaceVariantText
                        leftIconFocusedColor: Theme.primary
                        showClearButton: true
                        font.pixelSize: Theme.fontSizeLarge
                        enabled: appDrawerPopout.shouldBeVisible
                        ignoreLeftRightKeys: appLauncher.viewMode !== "list"
                        ignoreTabKeys: true
                        keyForwardTargets: [keyHandler]
                        onTextEdited: {
                            appLauncher.searchQuery = text
                        }
                        Keys.onPressed: function (event) {
                            if (event.key === Qt.Key_Escape) {
                                appDrawerPopout.close()
                                event.accepted = true
                                return
                            }

                            const isEnterKey = [Qt.Key_Return, Qt.Key_Enter].includes(event.key)
                            const hasText = text.length > 0

                            if (isEnterKey && hasText) {
                                if (appLauncher.keyboardNavigationActive && appLauncher.model.count > 0) {
                                    appLauncher.launchSelected()
                                } else if (appLauncher.model.count > 0) {
                                    appLauncher.launchApp(appLauncher.model.get(0))
                                }
                                event.accepted = true
                                return
                            }

                            const navigationKeys = [Qt.Key_Down, Qt.Key_Up, Qt.Key_Left, Qt.Key_Right, Qt.Key_Tab, Qt.Key_Backtab]
                            const isNavigationKey = navigationKeys.includes(event.key)
                            const isEmptyEnter = isEnterKey && !hasText

                            event.accepted = !(isNavigationKey || isEmptyEnter)
                        }

                        Connections {
                            function onShouldBeVisibleChanged() {
                                if (!appDrawerPopout.shouldBeVisible) {
                                    searchField.focus = false
                                }
                            }

                            target: appDrawerPopout
                        }
                    }

                    Row {
                        width: parent.width
                        height: 40
                        spacing: Theme.spacingM
                        visible: searchField.text.length === 0
                        leftPadding: Theme.spacingS

                        Rectangle {
                            width: 180
                            height: 40
                            radius: Theme.cornerRadius
                            color: "transparent"

                            DankDropdown {
                                anchors.fill: parent
                                text: ""
                                dropdownWidth: 180
                                currentValue: appLauncher.selectedCategory
                                options: appLauncher.categories
                                optionIcons: appLauncher.categoryIcons
                                onValueChanged: function (value) {
                                    appLauncher.setCategory(value)
                                }
                            }
                        }

                        Item {
                            width: parent.width - 290
                            height: 1
                        }

                        Row {
                            spacing: 4
                            anchors.verticalCenter: parent.verticalCenter

                            DankActionButton {
                                buttonSize: 36
                                circular: false
                                iconName: "view_list"
                                iconSize: 20
                                iconColor: appLauncher.viewMode === "list" ? Theme.primary : Theme.surfaceText
                                backgroundColor: appLauncher.viewMode === "list" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                                onClicked: {
                                    appLauncher.setViewMode("list")
                                }
                            }

                            DankActionButton {
                                buttonSize: 36
                                circular: false
                                iconName: "grid_view"
                                iconSize: 20
                                iconColor: appLauncher.viewMode === "grid" ? Theme.primary : Theme.surfaceText
                                backgroundColor: appLauncher.viewMode === "grid" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                                onClicked: {
                                    appLauncher.setViewMode("grid")
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: {
                            let usedHeight = 40 + Theme.spacingS
                            usedHeight += 52 + Theme.spacingS
                            usedHeight += (searchField.text.length === 0 ? 40 : 0)
                            return parent.height - usedHeight
                        }
                        radius: Theme.cornerRadius
                        color: "transparent"

                        DankListView {
                            id: appList

                            property int itemHeight: 72
                            property int iconSize: 56
                            property bool showDescription: true
                            property int itemSpacing: Theme.spacingS
                            property bool hoverUpdatesSelection: false
                            property bool keyboardNavigationActive: appLauncher.keyboardNavigationActive

                            signal keyboardNavigationReset
                            signal itemClicked(int index, var modelData)
                            signal itemRightClicked(int index, var modelData, real mouseX, real mouseY)

                            function ensureVisible(index) {
                                if (index < 0 || index >= count)
                                    return

                                var itemY = index * (itemHeight + itemSpacing)
                                var itemBottom = itemY + itemHeight
                                if (itemY < contentY)
                                    contentY = itemY
                                else if (itemBottom > contentY + height)
                                    contentY = itemBottom - height
                            }

                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS
                            anchors.bottomMargin: Theme.spacingS
                            visible: appLauncher.viewMode === "list"
                            model: appLauncher.model
                            currentIndex: appLauncher.selectedIndex
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

                            onItemClicked: function (index, modelData) {
                                appLauncher.launchApp(modelData)
                            }
                            onItemRightClicked: function (index, modelData, mouseX, mouseY) {
                                contextMenu.show(mouseX, mouseY, modelData)
                            }
                            onKeyboardNavigationReset: {
                                appLauncher.keyboardNavigationActive = false
                            }

                            delegate: AppLauncherListDelegate {
                                listView: appList
                                itemHeight: appList.itemHeight
                                iconSize: appList.iconSize
                                showDescription: appList.showDescription
                                hoverUpdatesSelection: appList.hoverUpdatesSelection
                                keyboardNavigationActive: appList.keyboardNavigationActive
                                isCurrentItem: ListView.isCurrentItem
                                mouseAreaLeftMargin: Theme.spacingS
                                mouseAreaRightMargin: Theme.spacingS
                                mouseAreaBottomMargin: Theme.spacingM
                                iconMargins: Theme.spacingXS
                                iconFallbackLeftMargin: Theme.spacingS
                                iconFallbackRightMargin: Theme.spacingS
                                iconFallbackBottomMargin: Theme.spacingM
                                onItemClicked: (idx, modelData) => appList.itemClicked(idx, modelData)
                                onItemRightClicked: (idx, modelData, mouseX, mouseY) => {
                                    const panelPos = contextMenu.parent.mapFromItem(null, mouseX, mouseY)
                                    appList.itemRightClicked(idx, modelData, panelPos.x, panelPos.y)
                                }
                                onKeyboardNavigationReset: appList.keyboardNavigationReset
                            }
                        }

                        DankGridView {
                            id: appGrid

                            property int currentIndex: appLauncher.selectedIndex
                            property int columns: 4
                            property bool adaptiveColumns: false
                            property int minCellWidth: 120
                            property int maxCellWidth: 160
                            property int cellPadding: 8
                            property real iconSizeRatio: 0.6
                            property int maxIconSize: 56
                            property int minIconSize: 32
                            property bool hoverUpdatesSelection: false
                            property bool keyboardNavigationActive: appLauncher.keyboardNavigationActive
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

                                var itemY = Math.floor(index / actualColumns) * cellHeight
                                var itemBottom = itemY + cellHeight
                                if (itemY < contentY)
                                    contentY = itemY
                                else if (itemBottom > contentY + height)
                                    contentY = itemBottom - height
                            }

                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS
                            anchors.bottomMargin: Theme.spacingS
                            visible: appLauncher.viewMode === "grid"
                            model: appLauncher.model
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

                            onItemClicked: function (index, modelData) {
                                appLauncher.launchApp(modelData)
                            }
                            onItemRightClicked: function (index, modelData, mouseX, mouseY) {
                                contextMenu.show(mouseX, mouseY, modelData)
                            }
                            onKeyboardNavigationReset: {
                                appLauncher.keyboardNavigationActive = false
                            }

                            delegate: AppLauncherGridDelegate {
                                gridView: appGrid
                                cellWidth: appGrid.cellWidth
                                cellHeight: appGrid.cellHeight
                                cellPadding: appGrid.cellPadding
                                minIconSize: appGrid.minIconSize
                                maxIconSize: appGrid.maxIconSize
                                iconSizeRatio: appGrid.iconSizeRatio
                                hoverUpdatesSelection: appGrid.hoverUpdatesSelection
                                keyboardNavigationActive: appGrid.keyboardNavigationActive
                                currentIndex: appGrid.currentIndex
                                mouseAreaLeftMargin: Theme.spacingS
                                mouseAreaRightMargin: Theme.spacingS
                                mouseAreaBottomMargin: Theme.spacingS
                                iconFallbackLeftMargin: Theme.spacingS
                                iconFallbackRightMargin: Theme.spacingS
                                iconFallbackBottomMargin: Theme.spacingS
                                iconMaterialSizeAdjustment: Theme.spacingL
                                onItemClicked: (idx, modelData) => appGrid.itemClicked(idx, modelData)
                                onItemRightClicked: (idx, modelData, mouseX, mouseY) => {
                                    const panelPos = contextMenu.parent.mapFromItem(null, mouseX, mouseY)
                                    appGrid.itemRightClicked(idx, modelData, panelPos.x, panelPos.y)
                                }
                                onKeyboardNavigationReset: appGrid.keyboardNavigationReset
                            }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: contextMenu

        property var currentApp: null
        readonly property var desktopEntry: (currentApp && !currentApp.isPlugin && appLauncher && appLauncher._uniqueApps && currentApp.appIndex >= 0 && currentApp.appIndex < appLauncher._uniqueApps.length) ? appLauncher._uniqueApps[currentApp.appIndex] : null
        readonly property string appId: desktopEntry ? (desktopEntry.id || desktopEntry.execString || "") : ""
        readonly property bool isPinned: appId && SessionData.isPinnedApp(appId)

        function show(x, y, app) {
            currentApp = app
            contextMenu.x = x + 4
            contextMenu.y = y + 4
            contextMenu.open()
        }

        function hide() {
            contextMenu.close()
        }

        width: Math.max(180, menuColumn.implicitWidth + Theme.spacingS * 2)
        height: menuColumn.implicitHeight + Theme.spacingS * 2
        padding: 0
        closePolicy: Popup.CloseOnPressOutside
        modal: false
        dim: false

        background: Rectangle {
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: 1

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 4
                anchors.leftMargin: 2
                anchors.rightMargin: -2
                anchors.bottomMargin: -4
                radius: parent.radius
                color: Qt.rgba(0, 0, 0, 0.15)
                z: -1
            }
        }

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.shortDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: Theme.shortDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Column {
            id: menuColumn

            anchors.fill: parent
            anchors.margins: Theme.spacingS
            spacing: 1

            Rectangle {
                width: parent.width
                height: 32
                radius: Theme.cornerRadius
                color: pinMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    DankIcon {
                        name: contextMenu.isPinned ? "keep_off" : "push_pin"
                        size: Theme.iconSize - 2
                        color: Theme.surfaceText
                        opacity: 0.7
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: contextMenu.isPinned ? I18n.tr("Unpin from Dock") : I18n.tr("Pin to Dock")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        font.weight: Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: pinMouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!contextMenu.desktopEntry) {
                            return
                        }

                        if (contextMenu.isPinned) {
                            SessionData.removePinnedApp(contextMenu.appId)
                        } else {
                            SessionData.addPinnedApp(contextMenu.appId)
                        }
                        contextMenu.hide()
                    }
                }
            }

            Rectangle {
                width: parent.width - Theme.spacingS * 2
                height: 5
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 1
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                }
            }

            Repeater {
                model: contextMenu.desktopEntry && contextMenu.desktopEntry.actions ? contextMenu.desktopEntry.actions : []

                Rectangle {
                    width: Math.max(parent.width, actionRow.implicitWidth + Theme.spacingS * 2)
                    height: 32
                    radius: Theme.cornerRadius
                    color: actionMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                    Row {
                        id: actionRow
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.iconSize - 2
                            height: Theme.iconSize - 2
                            visible: modelData.icon && modelData.icon !== ""

                            IconImage {
                                anchors.fill: parent
                                source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                                smooth: true
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                        }

                        StyledText {
                            text: modelData.name || ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: actionMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData && contextMenu.desktopEntry) {
                                SessionService.launchDesktopAction(contextMenu.desktopEntry, modelData)
                                if (contextMenu.currentApp) {
                                    appLauncher.appLaunched(contextMenu.currentApp)
                                }
                            }
                            contextMenu.hide()
                        }
                    }
                }
            }

            Rectangle {
                visible: contextMenu.desktopEntry && contextMenu.desktopEntry.actions && contextMenu.desktopEntry.actions.length > 0
                width: parent.width - Theme.spacingS * 2
                height: 5
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 1
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                }
            }

            Rectangle {
                width: parent.width
                height: 32
                radius: Theme.cornerRadius
                color: launchMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    DankIcon {
                        name: "launch"
                        size: Theme.iconSize - 2
                        color: Theme.surfaceText
                        opacity: 0.7
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: I18n.tr("Launch")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        font.weight: Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: launchMouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (contextMenu.currentApp)
                            appLauncher.launchApp(contextMenu.currentApp)

                        contextMenu.hide()
                    }
                }
            }

            Rectangle {
                visible: SessionService.hasPrimeRun
                width: parent.width - Theme.spacingS * 2
                height: 5
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 1
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                }
            }

            Rectangle {
                visible: SessionService.hasPrimeRun
                width: parent.width
                height: 32
                radius: Theme.cornerRadius
                color: primeRunMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    DankIcon {
                        name: "memory"
                        size: Theme.iconSize - 2
                        color: Theme.surfaceText
                        opacity: 0.7
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: I18n.tr("Launch on dGPU")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        font.weight: Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: primeRunMouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (contextMenu.desktopEntry) {
                            SessionService.launchDesktopEntry(contextMenu.desktopEntry, true)
                            if (contextMenu.currentApp) {
                                appLauncher.appLaunched(contextMenu.currentApp)
                            }
                        }
                        contextMenu.hide()
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        visible: contextMenu.visible
        z: 999
        onClicked: {
            contextMenu.hide()
        }

        MouseArea {
            x: contextMenu.x
            y: contextMenu.y
            width: contextMenu.width
            height: contextMenu.height
            onClicked: {

                // Prevent closing when clicking on the menu itself
            }
        }
    }
}
