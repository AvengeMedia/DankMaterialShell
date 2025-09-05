import QtQuick
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

    property string triggerSection: "left"
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
    triggerY: Theme.barHeight - 4 + SettingsData.topBarSpacing + Theme.spacingXS
    triggerWidth: 40
    positioning: "center"
    WlrLayershell.namespace: "quickshell-launcher"
    screen: triggerScreen

    onShouldBeVisibleChanged: {
        if (shouldBeVisible) {
            appLauncher.searchQuery = ""
            appLauncher.selectedIndex = 0
            appLauncher.setCategory("All")
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
            SettingsData.setAppLauncherViewMode(mode)
        }
    }

    content: Component {
        Rectangle {
            id: launcherPanel

            property alias searchField: searchField

            color: Theme.popupBackground()
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
                    border.width: 1
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

                    if (!searchField.activeFocus && event.text && /[a-zA-Z0-9\s]/.test(event.text)) {
                        searchField.forceActiveFocus()
                        searchField.insertText(event.text)
                        event.accepted = true
                    }
                }

                Column {
                    width: parent.width - Theme.spacingL * 2
                    height: parent.height - Theme.spacingL * 2
                    x: Theme.spacingL
                    y: Theme.spacingL
                    spacing: Theme.spacingL

                    Row {
                        width: parent.width
                        height: 40

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Applications"
                            font.pixelSize: Theme.fontSizeLarge + 4
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }

                        Item {
                            width: parent.width - 200
                            height: 1
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: appLauncher.model.count + " apps"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                        }
                    }

                    DankTextField {
                        id: searchField

                        width: parent.width
                        height: 52
                        cornerRadius: Theme.cornerRadius
                        backgroundColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * 0.7)
                        normalBorderColor: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                        focusedBorderColor: Theme.primary
                        leftIconName: "search"
                        leftIconSize: Theme.iconSize
                        leftIconColor: Theme.surfaceVariantText
                        leftIconFocusedColor: Theme.primary
                        showClearButton: true
                        font.pixelSize: Theme.fontSizeLarge
                        enabled: appDrawerPopout.shouldBeVisible
                        ignoreLeftRightKeys: true
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

                            const navigationKeys = [Qt.Key_Down, Qt.Key_Up, Qt.Key_Left, Qt.Key_Right]
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

                        Item {
                            width: 200
                            height: 36

                            DankDropdown {
                                anchors.fill: parent
                                text: ""
                                currentValue: appLauncher.selectedCategory
                                options: appLauncher.categories
                                optionIcons: appLauncher.categoryIcons
                                onValueChanged: function (value) {
                                    appLauncher.setCategory(value)
                                }
                            }
                        }

                        Item {
                            width: parent.width - 300
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
                            let usedHeight = 40 + Theme.spacingL
                            usedHeight += 52 + Theme.spacingL
                            usedHeight += (searchField.text.length === 0 ? 40 + Theme.spacingL : 0)
                            return parent.height - usedHeight
                        }
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.1)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.05)
                        border.width: 1

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
                            anchors.margins: Theme.spacingS
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

                            delegate: Rectangle {
                                width: ListView.view.width
                                height: appList.itemHeight
                                radius: Theme.cornerRadius
                                color: ListView.isCurrentItem ? Theme.primaryPressed : listMouseArea.containsMouse ? Theme.primaryHoverLight : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.03)
                                border.color: ListView.isCurrentItem ? Theme.primarySelected : Theme.outlineMedium
                                border.width: ListView.isCurrentItem ? 2 : 1

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingL

                                    Item {
                                        width: appList.iconSize
                                        height: appList.iconSize
                                        anchors.verticalCenter: parent.verticalCenter

                                        IconImage {
                                            id: listIconImg

                                            anchors.fill: parent
                                            source: Quickshell.iconPath(model.icon, true)
                                            smooth: true
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
                                                font.pixelSize: appList.iconSize * 0.4
                                                color: Theme.primary
                                                font.weight: Font.Bold
                                            }
                                        }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - appList.iconSize - Theme.spacingL
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
                                            visible: appList.showDescription && model.comment && model.comment.length > 0
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
                                    onEntered: {
                                        if (appList.hoverUpdatesSelection && !appList.keyboardNavigationActive)
                                            appList.currentIndex = index
                                    }
                                    onPositionChanged: {
                                        appList.keyboardNavigationReset()
                                    }
                                    onClicked: mouse => {
                                                   if (mouse.button === Qt.LeftButton) {
                                                       appList.itemClicked(index, model)
                                                   } else if (mouse.button === Qt.RightButton) {
                                                       var panelPos = mapToItem(contextMenu.parent, mouse.x, mouse.y)
                                                       appList.itemRightClicked(index, model, panelPos.x, panelPos.y)
                                                   }
                                               }
                                }
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
                            anchors.margins: Theme.spacingS
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

                            delegate: Rectangle {
                                width: appGrid.cellWidth - appGrid.cellPadding
                                height: appGrid.cellHeight - appGrid.cellPadding
                                radius: Theme.cornerRadius
                                color: appGrid.currentIndex === index ? Theme.primaryPressed : gridMouseArea.containsMouse ? Theme.primaryHoverLight : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.03)
                                border.color: appGrid.currentIndex === index ? Theme.primarySelected : Theme.outlineMedium
                                border.width: appGrid.currentIndex === index ? 2 : 1

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingS

                                    Item {
                                        property int iconSize: Math.min(appGrid.maxIconSize, Math.max(appGrid.minIconSize, appGrid.cellWidth * appGrid.iconSizeRatio))

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
                                        width: appGrid.cellWidth - 12
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
                                    onEntered: {
                                        if (appGrid.hoverUpdatesSelection && !appGrid.keyboardNavigationActive)
                                            appGrid.currentIndex = index
                                    }
                                    onPositionChanged: {
                                        appGrid.keyboardNavigationReset()
                                    }
                                    onClicked: mouse => {
                                                   if (mouse.button === Qt.LeftButton) {
                                                       appGrid.itemClicked(index, model)
                                                   } else if (mouse.button === Qt.RightButton) {
                                                       var panelPos = mapToItem(contextMenu.parent, mouse.x, mouse.y)
                                                       appGrid.itemRightClicked(index, model, panelPos.x, panelPos.y)
                                                   }
                                               }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: contextMenu

        property var currentApp: null
        property bool menuVisible: false

        readonly property string appId: (currentApp && currentApp.desktopEntry) ? (currentApp.desktopEntry.id || currentApp.desktopEntry.execString || "") : ""
        readonly property bool isPinned: appId && SessionData.isPinnedApp(appId)

        function show(x, y, app) {
            currentApp = app

            const menuWidth = 180
            const menuHeight = menuColumn.implicitHeight + Theme.spacingS * 2

            let finalX = x + 8
            let finalY = y + 8

            if (finalX + menuWidth > appDrawerPopout.popupWidth) {
                finalX = x - menuWidth - 8
            }

            if (finalY + menuHeight > appDrawerPopout.popupHeight) {
                finalY = y - menuHeight - 8
            }

            finalX = Math.max(8, Math.min(finalX, appDrawerPopout.popupWidth - menuWidth - 8))
            finalY = Math.max(8, Math.min(finalY, appDrawerPopout.popupHeight - menuHeight - 8))

            contextMenu.x = finalX
            contextMenu.y = finalY
            contextMenu.visible = true
            contextMenu.menuVisible = true
        }

        function close() {
            contextMenu.menuVisible = false
            Qt.callLater(() => {
                             contextMenu.visible = false
                         })
        }

        visible: false
        width: 180
        height: menuColumn.implicitHeight + Theme.spacingS * 2
        radius: Theme.cornerRadius
        color: Theme.popupBackground()
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1
        z: 1000
        opacity: menuVisible ? 1 : 0
        scale: menuVisible ? 1 : 0.85

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.leftMargin: 2
            anchors.rightMargin: -2
            anchors.bottomMargin: -4
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.15)
            z: parent.z - 1
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
                        text: contextMenu.isPinned ? "Unpin from Dock" : "Pin to Dock"
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
                        if (!contextMenu.currentApp || !contextMenu.currentApp.desktopEntry) {
                            return
                        }

                        if (contextMenu.isPinned) {
                            SessionData.removePinnedApp(contextMenu.appId)
                        } else {
                            SessionData.addPinnedApp(contextMenu.appId)
                        }
                        contextMenu.close()
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
                        text: "Launch"
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

                        contextMenu.close()
                    }
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        visible: contextMenu.visible
        z: 999
        onClicked: {
            contextMenu.close()
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
