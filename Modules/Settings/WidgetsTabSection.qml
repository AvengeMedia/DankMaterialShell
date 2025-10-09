import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import qs.Services

Column {
    id: root

    property var items: []
    property var allWidgets: []
    property string title: ""
    property string titleIcon: "widgets"
    property string sectionId: ""

    signal itemEnabledChanged(string sectionId, string itemId, bool enabled)
    signal itemOrderChanged(var newOrder)
    signal addWidget(string sectionId)
    signal removeWidget(string sectionId, int widgetIndex)
    signal spacerSizeChanged(string sectionId, int widgetIndex, int newSize)
    signal compactModeChanged(string widgetId, var value)
    signal gpuSelectionChanged(string sectionId, int widgetIndex, int selectedIndex)
    signal diskMountSelectionChanged(string sectionId, int widgetIndex, string mountPath)
    signal controlCenterSettingChanged(string sectionId, int widgetIndex, string settingName, bool value)
    signal minimumWidthChanged(string sectionId, int widgetIndex, bool enabled)

    width: parent.width
    height: implicitHeight
    spacing: Theme.spacingM

    Row {
        width: parent.width
        spacing: Theme.spacingM

        DankIcon {
            name: root.titleIcon
            size: Theme.iconSize
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: root.title
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            width: parent.width - 60
            height: 1
        }
    }

    Column {
        id: itemsList

        width: parent.width
        spacing: Theme.spacingS

        Repeater {
            model: root.items

            delegate: Item {
                id: delegateItem

                property bool held: dragArea.pressed
                property real originalY: y

                width: itemsList.width
                height: 70
                z: held ? 2 : 1

                Rectangle {
                    id: itemBackground

                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceContainer.r,
                                   Theme.surfaceContainer.g,
                                   Theme.surfaceContainer.b, 0.8)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                          Theme.outline.b, 0.2)
                    border.width: 0

                    DankIcon {
                        name: "drag_indicator"
                        size: Theme.iconSize - 4
                        color: Theme.outline
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM + 8
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: 0.8
                    }

                    DankIcon {
                        name: modelData.icon
                        size: Theme.iconSize
                        color: modelData.enabled ? Theme.primary : Theme.outline
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM * 2 + 40
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM * 3 + 40 + Theme.iconSize
                        anchors.right: actionButtons.left
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        StyledText {
                            text: modelData.text
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: modelData.enabled ? Theme.surfaceText : Theme.outline
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        StyledText {
                            text: modelData.description
                            font.pixelSize: Theme.fontSizeSmall
                            color: modelData.enabled ? Theme.outline : Qt.rgba(
                                                           Theme.outline.r,
                                                           Theme.outline.g,
                                                           Theme.outline.b, 0.6)
                            elide: Text.ElideRight
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }
                    }

                    Row {
                        id: actionButtons

                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        Item {
                            width: 60
                            height: 32
                            visible: modelData.id === "gpuTemp"

                            DankDropdown {
                                id: gpuDropdown
                                anchors.fill: parent
                                popupWidth: -1
                                currentValue: {
                                    var selectedIndex = modelData.selectedGpuIndex
                                            !== undefined ? modelData.selectedGpuIndex : 0
                                    if (DgopService.availableGpus
                                            && DgopService.availableGpus.length > selectedIndex
                                            && selectedIndex >= 0) {
                                        var gpu = DgopService.availableGpus[selectedIndex]
                                        return gpu.driver.toUpperCase()
                                    }
                                    return DgopService.availableGpus
                                            && DgopService.availableGpus.length
                                            > 0 ? DgopService.availableGpus[0].driver.toUpperCase(
                                                      ) : ""
                                }
                                options: {
                                    var gpuOptions = []
                                    if (DgopService.availableGpus
                                            && DgopService.availableGpus.length > 0) {
                                        for (var i = 0; i < DgopService.availableGpus.length; i++) {
                                            var gpu = DgopService.availableGpus[i]
                                            gpuOptions.push(
                                                        gpu.driver.toUpperCase(
                                                            ))
                                        }
                                    }
                                    return gpuOptions
                                }
                                onValueChanged: value => {
                                                    var gpuIndex = options.indexOf(
                                                        value)
                                                    if (gpuIndex >= 0) {
                                                        root.gpuSelectionChanged(
                                                            root.sectionId,
                                                            index, gpuIndex)
                                                    }
                                                }
                            }
                        }

                        Item {
                            width: 120
                            height: 32
                            visible: modelData.id === "diskUsage"
                            DankDropdown {
                                id: diskMountDropdown
                                anchors.fill: parent
                                currentValue: {
                                    const mountPath = modelData.mountPath || "/"
                                    if (mountPath === "/") {
                                        return "root (/)"
                                    }
                                    return mountPath
                                }
                                options: {
                                    if (!DgopService.diskMounts || DgopService.diskMounts.length === 0) {
                                        return ["root (/)"]
                                    }
                                    return DgopService.diskMounts.map(mount => {
                                        if (mount.mount === "/") {
                                            return "root (/)"
                                        }
                                        return mount.mount
                                    })
                                }
                                onValueChanged: value => {
                                    const newPath = value === "root (/)" ? "/" : value
                                    root.diskMountSelectionChanged(root.sectionId, index, newPath)
                                }
                            }
                        }

                        Item {
                            width: 32
                            height: 32
                            visible: modelData.warning !== undefined && modelData.warning !== ""

                            DankIcon {
                                name: "warning"
                                size: 20
                                color: Theme.error
                                anchors.centerIn: parent
                                opacity: warningArea.containsMouse ? 1.0 : 0.8
                            }

                            MouseArea {
                                id: warningArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                            }

                            Rectangle {
                                id: warningTooltip

                                property string warningText: (modelData.warning !== undefined
                                                              && modelData.warning
                                                              !== "") ? modelData.warning : ""

                                width: Math.min(
                                           250,
                                           warningTooltipText.implicitWidth) + Theme.spacingM * 2
                                height: warningTooltipText.implicitHeight + Theme.spacingS * 2
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainer
                                border.color: Theme.outline
                                border.width: 0
                                visible: warningArea.containsMouse
                                         && warningText !== ""
                                opacity: visible ? 1 : 0
                                x: -width - Theme.spacingS
                                y: (parent.height - height) / 2
                                z: 100

                                StyledText {
                                    id: warningTooltipText
                                    anchors.centerIn: parent
                                    anchors.margins: Theme.spacingS
                                    text: warningTooltip.warningText
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    width: Math.min(250, implicitWidth)
                                    wrapMode: Text.WordWrap
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }
                            }
                        }

                        DankActionButton {
                            id: minimumWidthButton
                            buttonSize: 28
                            visible: modelData.id === "cpuUsage"
                                     || modelData.id === "memUsage"
                                     || modelData.id === "cpuTemp"
                                     || modelData.id === "gpuTemp"
                            iconName: "straighten"
                            iconSize: 16
                            iconColor: (modelData.minimumWidth !== undefined ? modelData.minimumWidth : true) ? Theme.primary : Theme.outline
                            onClicked: {
                                var currentEnabled = modelData.minimumWidth !== undefined ? modelData.minimumWidth : true
                                root.minimumWidthChanged(root.sectionId, index, !currentEnabled)
                            }
                            onEntered: {
                                minimumWidthTooltipLoader.active = true
                                if (minimumWidthTooltipLoader.item) {
                                    var currentEnabled = modelData.minimumWidth !== undefined ? modelData.minimumWidth : true
                                    const tooltipText = currentEnabled ? "Force Padding" : "Dynamic Width"
                                    const p = minimumWidthButton.mapToItem(null, minimumWidthButton.width / 2, 0)
                                    minimumWidthTooltipLoader.item.show(tooltipText, p.x, p.y - 40, null)
                                }
                            }
                            onExited: {
                                if (minimumWidthTooltipLoader.item) {
                                    minimumWidthTooltipLoader.item.hide()
                                }
                                minimumWidthTooltipLoader.active = false
                            }
                        }

                        Row {
                            spacing: Theme.spacingXS
                            visible: modelData.id === "clock"
                                     || modelData.id === "music"
                                     || modelData.id === "focusedWindow"
                                     || modelData.id === "runningApps"

                            DankActionButton {
                                id: smallSizeButton
                                buttonSize: 28
                                visible: modelData.id === "music"
                                iconName: "photo_size_select_small"
                                iconSize: 16
                                iconColor: SettingsData.mediaSize
                                           === 0 ? Theme.primary : Theme.outline
                                onClicked: {
                                    root.compactModeChanged("music", 0)
                                }
                                onEntered: {
                                    smallTooltipLoader.active = true
                                    if (smallTooltipLoader.item) {
                                        const p = smallSizeButton.mapToItem(null, smallSizeButton.width / 2, 0)
                                        smallTooltipLoader.item.show("Small", p.x, p.y - 40, null)
                                    }
                                }
                                onExited: {
                                    if (smallTooltipLoader.item) {
                                        smallTooltipLoader.item.hide()
                                    }
                                    smallTooltipLoader.active = false
                                }
                            }

                            DankActionButton {
                                id: mediumSizeButton
                                buttonSize: 28
                                visible: modelData.id === "music"
                                iconName: "photo_size_select_actual"
                                iconSize: 16
                                iconColor: SettingsData.mediaSize
                                           === 1 ? Theme.primary : Theme.outline
                                onClicked: {
                                    root.compactModeChanged("music", 1)
                                }
                                onEntered: {
                                    mediumTooltipLoader.active = true
                                    if (mediumTooltipLoader.item) {
                                        const p = mediumSizeButton.mapToItem(null, mediumSizeButton.width / 2, 0)
                                        mediumTooltipLoader.item.show("Medium", p.x, p.y - 40, null)
                                    }
                                }
                                onExited: {
                                    if (mediumTooltipLoader.item) {
                                        mediumTooltipLoader.item.hide()
                                    }
                                    mediumTooltipLoader.active = false
                                }
                            }

                            DankActionButton {
                                id: largeSizeButton
                                buttonSize: 28
                                visible: modelData.id === "music"
                                iconName: "photo_size_select_large"
                                iconSize: 16
                                iconColor: SettingsData.mediaSize
                                           === 2 ? Theme.primary : Theme.outline
                                onClicked: {
                                    root.compactModeChanged("music", 2)
                                }
                                onEntered: {
                                    largeTooltipLoader.active = true
                                    if (largeTooltipLoader.item) {
                                        const p = largeSizeButton.mapToItem(null, largeSizeButton.width / 2, 0)
                                        largeTooltipLoader.item.show("Large", p.x, p.y - 40, null)
                                    }
                                }
                                onExited: {
                                    if (largeTooltipLoader.item) {
                                        largeTooltipLoader.item.hide()
                                    }
                                    largeTooltipLoader.active = false
                                }
                            }

                            DankActionButton {
                                id: compactModeButton
                                buttonSize: 28
                                visible: modelData.id === "clock"
                                         || modelData.id === "focusedWindow"
                                         || modelData.id === "runningApps"
                                iconName: {
                                    if (modelData.id === "clock")
                                        return SettingsData.clockCompactMode ? "zoom_out" : "zoom_in"
                                    if (modelData.id === "focusedWindow")
                                        return SettingsData.focusedWindowCompactMode ? "zoom_out" : "zoom_in"
                                    if (modelData.id === "runningApps")
                                        return SettingsData.runningAppsCompactMode ? "zoom_out" : "zoom_in"
                                    return "zoom_in"
                                }
                                iconSize: 16
                                iconColor: {
                                    if (modelData.id === "clock")
                                        return SettingsData.clockCompactMode ? Theme.primary : Theme.outline
                                    if (modelData.id === "focusedWindow")
                                        return SettingsData.focusedWindowCompactMode ? Theme.primary : Theme.outline
                                    if (modelData.id === "runningApps")
                                        return SettingsData.runningAppsCompactMode ? Theme.primary : Theme.outline
                                    return Theme.outline
                                }
                                onClicked: {
                                    if (modelData.id === "clock") {
                                        root.compactModeChanged(
                                                    "clock",
                                                    !SettingsData.clockCompactMode)
                                    } else if (modelData.id === "focusedWindow") {
                                        root.compactModeChanged(
                                                    "focusedWindow",
                                                    !SettingsData.focusedWindowCompactMode)
                                    } else if (modelData.id === "runningApps") {
                                        root.compactModeChanged(
                                                    "runningApps",
                                                    !SettingsData.runningAppsCompactMode)
                                    }
                                }
                                onEntered: {
                                    compactTooltipLoader.active = true
                                    if (compactTooltipLoader.item) {
                                        let tooltipText = "Toggle Compact Mode"
                                        if (modelData.id === "clock") {
                                            tooltipText = SettingsData.clockCompactMode ? "Full Size" : "Compact"
                                        } else if (modelData.id === "focusedWindow") {
                                            tooltipText = SettingsData.focusedWindowCompactMode ? "Full Size" : "Compact"
                                        } else if (modelData.id === "runningApps") {
                                            tooltipText = SettingsData.runningAppsCompactMode ? "Full Size" : "Compact"
                                        }
                                        const p = compactModeButton.mapToItem(null, compactModeButton.width / 2, 0)
                                        compactTooltipLoader.item.show(tooltipText, p.x, p.y - 40, null)
                                    }
                                }
                                onExited: {
                                    if (compactTooltipLoader.item) {
                                        compactTooltipLoader.item.hide()
                                    }
                                    compactTooltipLoader.active = false
                                }
                            }

                            Rectangle {
                                id: compactModeTooltip
                                width: tooltipText.contentWidth + Theme.spacingM * 2
                                height: tooltipText.contentHeight + Theme.spacingS * 2
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainer
                                border.color: Theme.outline
                                border.width: 0
                                visible: false
                                opacity: visible ? 1 : 0
                                x: -width - Theme.spacingS
                                y: (parent.height - height) / 2
                                z: 100

                                StyledText {
                                    id: tooltipText
                                    anchors.centerIn: parent
                                    text: I18n.tr("Compact Mode")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }
                            }
                        }

                        DankActionButton {
                            visible: modelData.id === "controlCenterButton"
                            buttonSize: 32
                            iconName: "more_vert"
                            iconSize: 18
                            iconColor: Theme.outline
                            onClicked: {
                                console.log("Control Center three-dot button clicked for widget:", modelData.id)
                                controlCenterContextMenu.widgetData = modelData
                                controlCenterContextMenu.sectionId = root.sectionId
                                controlCenterContextMenu.widgetIndex = index
                                // Position relative to the action buttons row, not the specific button
                                var parentPos = parent.mapToItem(root, 0, 0)
                                controlCenterContextMenu.x = parentPos.x - 210 // Position to the left with margin
                                controlCenterContextMenu.y = parentPos.y - 10 // Slightly above
                                controlCenterContextMenu.open()
                            }
                        }

                        DankActionButton {
                            id: visibilityButton
                            visible: modelData.id !== "spacer"
                            buttonSize: 32
                            iconName: modelData.enabled ? "visibility" : "visibility_off"
                            iconSize: 18
                            iconColor: modelData.enabled ? Theme.primary : Theme.outline
                            onClicked: {
                                root.itemEnabledChanged(root.sectionId,
                                                        modelData.id,
                                                        !modelData.enabled)
                            }
                            onEntered: {
                                visibilityTooltipLoader.active = true
                                if (visibilityTooltipLoader.item) {
                                    const tooltipText = modelData.enabled ? "Hide" : "Show"
                                    const p = visibilityButton.mapToItem(null, visibilityButton.width / 2, 0)
                                    visibilityTooltipLoader.item.show(tooltipText, p.x, p.y - 40, null)
                                }
                            }
                            onExited: {
                                if (visibilityTooltipLoader.item) {
                                    visibilityTooltipLoader.item.hide()
                                }
                                visibilityTooltipLoader.active = false
                            }
                        }

                        Row {
                            visible: modelData.id === "spacer"
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            DankActionButton {
                                buttonSize: 24
                                iconName: "remove"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var currentSize = modelData.size || 20
                                    var newSize = Math.max(5, currentSize - 5)
                                    root.spacerSizeChanged(root.sectionId,
                                                           index,
                                                           newSize)
                                }
                            }

                            StyledText {
                                text: (modelData.size || 20).toString()
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            DankActionButton {
                                buttonSize: 24
                                iconName: "add"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var currentSize = modelData.size || 20
                                    var newSize = Math.min(5000,
                                                           currentSize + 5)
                                    root.spacerSizeChanged(root.sectionId,
                                                           index,
                                                           newSize)
                                }
                            }
                        }

                        DankActionButton {
                            buttonSize: 32
                            iconName: "close"
                            iconSize: 18
                            iconColor: Theme.error
                            onClicked: {
                                root.removeWidget(root.sectionId, index)
                            }
                        }
                    }

                    MouseArea {
                        id: dragArea

                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 60
                        hoverEnabled: true
                        cursorShape: Qt.SizeVerCursor
                        drag.target: held ? delegateItem : undefined
                        drag.axis: Drag.YAxis
                        drag.minimumY: -delegateItem.height
                        drag.maximumY: itemsList.height
                        preventStealing: true
                        onPressed: {
                            delegateItem.z = 2
                            delegateItem.originalY = delegateItem.y
                        }
                        onReleased: {
                            delegateItem.z = 1
                            if (drag.active) {
                                var newIndex = Math.round(
                                            delegateItem.y / (delegateItem.height
                                                              + itemsList.spacing))
                                newIndex = Math.max(
                                            0, Math.min(newIndex,
                                                        root.items.length - 1))
                                if (newIndex !== index) {
                                    var newItems = root.items.slice()
                                    var draggedItem = newItems.splice(index,
                                                                      1)[0]
                                    newItems.splice(newIndex, 0, draggedItem)
                                    root.itemOrderChanged(newItems.map(item => {
                                                                           return ({
                                                                                       "id": item.id,
                                                                                       "enabled": item.enabled,
                                                                                       "size": item.size
                                                                                   })
                                                                       }))
                                }
                            }
                            delegateItem.x = 0
                            delegateItem.y = delegateItem.originalY
                        }
                    }

                    Behavior on y {
                        enabled: !dragArea.held && !dragArea.drag.active

                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        width: 200
        height: 40
        radius: Theme.cornerRadius
        color: addButtonArea.containsMouse ? Theme.primaryContainer : Qt.rgba(
                                                 Theme.surfaceVariant.r,
                                                 Theme.surfaceVariant.g,
                                                 Theme.surfaceVariant.b, 0.3)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                              Theme.outline.b, 0.2)
        border.width: 0
        anchors.horizontalCenter: parent.horizontalCenter

        StyledText {
            text: I18n.tr("Add Widget")
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
            anchors.centerIn: parent
        }

        MouseArea {
            id: addButtonArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.addWidget(root.sectionId)
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }
    }

    Popup {
        id: controlCenterContextMenu

        property var widgetData: null
        property string sectionId: ""
        property int widgetIndex: -1


        width: 200
        height: 120
        padding: 0
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        onOpened: {
            console.log("Control Center context menu opened")
        }
        
        onClosed: {
            console.log("Control Center context menu closed")
        }

        background: Rectangle {
            color: Theme.popupBackground()
            radius: Theme.cornerRadius
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: 0
        }

        contentItem: Item {

            Column {
                id: menuColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: 2

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: networkToggleArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "lan"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Network Icon")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        id: networkToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: SettingsData.controlCenterShowNetworkIcon
                        onToggled: {
                            root.controlCenterSettingChanged(controlCenterContextMenu.sectionId, controlCenterContextMenu.widgetIndex, "showNetworkIcon", toggled)
                        }
                    }

                    MouseArea {
                        id: networkToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            networkToggle.checked = !networkToggle.checked
                            root.controlCenterSettingChanged(controlCenterContextMenu.sectionId, controlCenterContextMenu.widgetIndex, "showNetworkIcon", networkToggle.checked)
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: bluetoothToggleArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "bluetooth"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Bluetooth Icon")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        id: bluetoothToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: SettingsData.controlCenterShowBluetoothIcon
                        onToggled: {
                            root.controlCenterSettingChanged(controlCenterContextMenu.sectionId, controlCenterContextMenu.widgetIndex, "showBluetoothIcon", toggled)
                        }
                    }

                    MouseArea {
                        id: bluetoothToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            bluetoothToggle.checked = !bluetoothToggle.checked
                            root.controlCenterSettingChanged(controlCenterContextMenu.sectionId, controlCenterContextMenu.widgetIndex, "showBluetoothIcon", bluetoothToggle.checked)
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: audioToggleArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "volume_up"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Audio Icon")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        id: audioToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: SettingsData.controlCenterShowAudioIcon
                        onToggled: {
                            root.controlCenterSettingChanged(controlCenterContextMenu.sectionId, controlCenterContextMenu.widgetIndex, "showAudioIcon", toggled)
                        }
                    }

                    MouseArea {
                        id: audioToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            audioToggle.checked = !audioToggle.checked
                            root.controlCenterSettingChanged(controlCenterContextMenu.sectionId, controlCenterContextMenu.widgetIndex, "showAudioIcon", audioToggle.checked)
                        }
                    }
                }
            }

        }
    }

    Loader {
        id: smallTooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }

    Loader {
        id: mediumTooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }

    Loader {
        id: largeTooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }

    Loader {
        id: compactTooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }

    Loader {
        id: visibilityTooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }

    Loader {
        id: minimumWidthTooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }
}
