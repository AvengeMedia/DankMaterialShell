import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

    DankTooltipV2 {
        id: sharedTooltip
    }

    signal itemEnabledChanged(string sectionId, string itemId, bool enabled)
    signal itemOrderChanged(var newOrder)
    signal addWidget(string sectionId)
    signal removeWidget(string sectionId, int widgetIndex)
    signal spacerSizeChanged(string sectionId, int widgetIndex, int newSize)
    signal compactModeChanged(string widgetId, var value)
    signal gpuSelectionChanged(string sectionId, int widgetIndex, int selectedIndex)
    signal diskMountSelectionChanged(string sectionId, int widgetIndex, string mountPath)
    signal controlCenterSettingChanged(string sectionId, int widgetIndex, string settingName, bool value)
    signal privacySettingChanged(string sectionId, int widgetIndex, string settingName, bool value)
    signal minimumWidthChanged(string sectionId, int widgetIndex, bool enabled)
    signal showSwapChanged(string sectionId, int widgetIndex, bool enabled)
    signal showInGbChanged(string sectionId, int widgetIndex, bool enabled)
    signal diskUsageModeChanged(string sectionId, int widgetIndex, int mode)
    signal overflowSettingChanged(string sectionId, int widgetIndex, string settingName, var value)

    function cloneWidgetData(widget) {
        var result = {
            "id": widget.id,
            "enabled": widget.enabled
        };
        var keys = ["size", "selectedGpuIndex", "pciId", "mountPath", "diskUsageMode", "minimumWidth", "showSwap", "showInGb", "mediaSize", "clockCompactMode", "focusedWindowCompactMode", "runningAppsCompactMode", "keyboardLayoutNameCompactMode", "runningAppsGroupByApp", "runningAppsCurrentWorkspace", "runningAppsCurrentMonitor", "showNetworkIcon", "showBluetoothIcon", "showAudioIcon", "showAudioPercent", "showVpnIcon", "showBrightnessIcon", "showBrightnessPercent", "showMicIcon", "showMicPercent", "showBatteryIcon", "showPrinterIcon", "showScreenSharingIcon", "barMaxVisibleApps", "barMaxVisibleRunningApps", "barShowOverflowBadge"];
        for (var i = 0; i < keys.length; i++) {
            if (widget[keys[i]] !== undefined)
                result[keys[i]] = widget[keys[i]];
        }
        return result;
    }

    width: parent.width
    height: implicitHeight
    spacing: Theme.spacingM

    RowLayout {
        width: parent.width
        spacing: Theme.spacingM

        DankIcon {
            name: root.titleIcon
            size: Theme.iconSize
            color: Theme.primary
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            text: root.title
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Medium
            color: Theme.surfaceText
            Layout.alignment: Qt.AlignVCenter
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
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.8)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
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
                            text: {
                                if (modelData.id === "gpuTemp") {
                                    var selectedIdx = modelData.selectedGpuIndex !== undefined ? modelData.selectedGpuIndex : 0;
                                    if (DgopService.availableGpus && DgopService.availableGpus.length > selectedIdx) {
                                        var gpu = DgopService.availableGpus[selectedIdx];
                                        return gpu.driver ? gpu.driver.toUpperCase() : "";
                                    }
                                    return I18n.tr("No GPU detected");
                                }
                                return modelData.description;
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: modelData.enabled ? Theme.outline : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.6)
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

                        DankActionButton {
                            id: gpuMenuButton
                            visible: modelData.id === "gpuTemp"
                            buttonSize: 32
                            iconName: "more_vert"
                            iconSize: 18
                            iconColor: Theme.outline
                            onClicked: {
                                gpuContextMenu.widgetData = modelData;
                                gpuContextMenu.sectionId = root.sectionId;
                                gpuContextMenu.widgetIndex = index;

                                var buttonPos = gpuMenuButton.mapToItem(root, 0, 0);
                                var popupWidth = gpuContextMenu.width;
                                var popupHeight = gpuContextMenu.height;

                                var xPos = buttonPos.x - popupWidth - Theme.spacingS;
                                if (xPos < 0) {
                                    xPos = buttonPos.x + gpuMenuButton.width + Theme.spacingS;
                                }

                                var yPos = buttonPos.y - popupHeight / 2 + gpuMenuButton.height / 2;
                                if (yPos < 0) {
                                    yPos = Theme.spacingS;
                                } else if (yPos + popupHeight > root.height) {
                                    yPos = root.height - popupHeight - Theme.spacingS;
                                }

                                gpuContextMenu.x = xPos;
                                gpuContextMenu.y = yPos;
                                gpuContextMenu.open();
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
                                    const mountPath = modelData.mountPath || "/";
                                    if (mountPath === "/") {
                                        return "root (/)";
                                    }
                                    return mountPath;
                                }
                                options: {
                                    if (!DgopService.diskMounts || DgopService.diskMounts.length === 0) {
                                        return ["root (/)"];
                                    }
                                    return DgopService.diskMounts.map(mount => {
                                        if (mount.mount === "/") {
                                            return "root (/)";
                                        }
                                        return mount.mount;
                                    });
                                }
                                onValueChanged: value => {
                                    const newPath = value === "root (/)" ? "/" : value;
                                    root.diskMountSelectionChanged(root.sectionId, index, newPath);
                                }
                            }
                        }

                        DankActionButton {
                            id: diskMenuButton
                            visible: modelData.id === "diskUsage"
                            buttonSize: 32
                            iconName: "more_vert"
                            iconSize: 18
                            iconColor: Theme.outline
                            onClicked: {
                                diskUsageContextMenu.widgetData = modelData;
                                diskUsageContextMenu.sectionId = root.sectionId;
                                diskUsageContextMenu.widgetIndex = index;

                                var buttonPos = diskMenuButton.mapToItem(root, 0, 0);
                                var xPos = buttonPos.x - diskUsageContextMenu.width - Theme.spacingS;
                                if (xPos < 0)
                                    xPos = buttonPos.x + diskMenuButton.width + Theme.spacingS;
                                var yPos = buttonPos.y - diskUsageContextMenu.height / 2 + diskMenuButton.height / 2;
                                if (yPos < 0)
                                    yPos = Theme.spacingS;
                                else if (yPos + diskUsageContextMenu.height > root.height)
                                    yPos = root.height - diskUsageContextMenu.height - Theme.spacingS;

                                diskUsageContextMenu.x = xPos;
                                diskUsageContextMenu.y = yPos;
                                diskUsageContextMenu.open();
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

                                property string warningText: (modelData.warning !== undefined && modelData.warning !== "") ? modelData.warning : ""

                                width: Math.min(250, warningTooltipText.implicitWidth) + Theme.spacingM * 2
                                height: warningTooltipText.implicitHeight + Theme.spacingS * 2
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainer
                                border.color: Theme.outline
                                border.width: 0
                                visible: warningArea.containsMouse && warningText !== ""
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
                            visible: modelData.id === "cpuUsage" || modelData.id === "memUsage" || modelData.id === "cpuTemp" || modelData.id === "gpuTemp"
                            iconName: "straighten"
                            iconSize: 16
                            iconColor: (modelData.minimumWidth !== undefined ? modelData.minimumWidth : true) ? Theme.primary : Theme.outline
                            onClicked: {
                                var currentEnabled = modelData.minimumWidth !== undefined ? modelData.minimumWidth : true;
                                root.minimumWidthChanged(root.sectionId, index, !currentEnabled);
                            }
                            onEntered: {
                                var currentEnabled = modelData.minimumWidth !== undefined ? modelData.minimumWidth : true;
                                const tooltipText = currentEnabled ? "Force Padding" : "Dynamic Width";
                                sharedTooltip.show(tooltipText, minimumWidthButton, 0, 0, "bottom");
                            }
                            onExited: {
                                sharedTooltip.hide();
                            }
                        }

                        DankActionButton {
                            id: memMenuButton
                            visible: modelData.id === "memUsage"
                            buttonSize: 32
                            iconName: "more_vert"
                            iconSize: 18
                            iconColor: Theme.outline
                            onClicked: {
                                memUsageContextMenu.widgetData = modelData;
                                memUsageContextMenu.sectionId = root.sectionId;
                                memUsageContextMenu.widgetIndex = index;

                                var buttonPos = memMenuButton.mapToItem(root, 0, 0);
                                var popupWidth = memUsageContextMenu.width;
                                var popupHeight = memUsageContextMenu.height;

                                var xPos = buttonPos.x - popupWidth - Theme.spacingS;
                                if (xPos < 0) {
                                    xPos = buttonPos.x + memMenuButton.width + Theme.spacingS;
                                }

                                var yPos = buttonPos.y - popupHeight / 2 + memMenuButton.height / 2;
                                if (yPos < 0) {
                                    yPos = Theme.spacingS;
                                } else if (yPos + popupHeight > root.height) {
                                    yPos = root.height - popupHeight - Theme.spacingS;
                                }

                                memUsageContextMenu.x = xPos;
                                memUsageContextMenu.y = yPos;
                                memUsageContextMenu.open();
                            }
                        }

                        DankActionButton {
                            id: musicMenuButton
                            visible: modelData.id === "music"
                            buttonSize: 32
                            iconName: "more_vert"
                            iconSize: 18
                            iconColor: Theme.outline
                            onClicked: {
                                musicContextMenu.widgetData = modelData;
                                musicContextMenu.sectionId = root.sectionId;
                                musicContextMenu.widgetIndex = index;

                                var buttonPos = musicMenuButton.mapToItem(root, 0, 0);
                                var popupWidth = musicContextMenu.width;
                                var popupHeight = musicContextMenu.height;

                                var xPos = buttonPos.x - popupWidth - Theme.spacingS;
                                if (xPos < 0)
                                    xPos = buttonPos.x + musicMenuButton.width + Theme.spacingS;

                                var yPos = buttonPos.y - popupHeight / 2 + musicMenuButton.height / 2;
                                if (yPos < 0) {
                                    yPos = Theme.spacingS;
                                } else if (yPos + popupHeight > root.height) {
                                    yPos = root.height - popupHeight - Theme.spacingS;
                                }

                                musicContextMenu.x = xPos;
                                musicContextMenu.y = yPos;
                                musicContextMenu.open();
                            }
                        }

                        DankActionButton {
                            id: runningAppsMenuButton
                            visible: modelData.id === "runningApps"
                            buttonSize: 32
                            iconName: "more_vert"
                            iconSize: 18
                            iconColor: Theme.outline
                            onClicked: {
                                runningAppsContextMenu.widgetData = modelData;
                                runningAppsContextMenu.sectionId = root.sectionId;
                                runningAppsContextMenu.widgetIndex = index;

                                var buttonPos = runningAppsMenuButton.mapToItem(root, 0, 0);
                                var popupWidth = runningAppsContextMenu.width;
                                var popupHeight = runningAppsContextMenu.height;

                                var xPos = buttonPos.x - popupWidth - Theme.spacingS;
                                if (xPos < 0)
                                    xPos = buttonPos.x + runningAppsMenuButton.width + Theme.spacingS;

                                var yPos = buttonPos.y - popupHeight / 2 + runningAppsMenuButton.height / 2;
                                if (yPos < 0) {
                                    yPos = Theme.spacingS;
                                } else if (yPos + popupHeight > root.height) {
                                    yPos = root.height - popupHeight - Theme.spacingS;
                                }

                                runningAppsContextMenu.x = xPos;
                                runningAppsContextMenu.y = yPos;
                                runningAppsContextMenu.open();
                            }
                        }

                        Row {
                            spacing: Theme.spacingXS
                            visible: modelData.id === "clock" || modelData.id === "focusedWindow" || modelData.id === "keyboard_layout_name" || modelData.id === "appsDock"

                            DankActionButton {
                                id: compactModeButton
                                buttonSize: 28
                                visible: modelData.id === "clock" || modelData.id === "focusedWindow" || modelData.id === "keyboard_layout_name"
                                iconName: {
                                    const isCompact = (() => {
                                            switch (modelData.id) {
                                            case "clock":
                                                return modelData.clockCompactMode !== undefined ? modelData.clockCompactMode : SettingsData.clockCompactMode;
                                            case "focusedWindow":
                                                return modelData.focusedWindowCompactMode !== undefined ? modelData.focusedWindowCompactMode : SettingsData.focusedWindowCompactMode;
                                            case "keyboard_layout_name":
                                                return modelData.keyboardLayoutNameCompactMode !== undefined ? modelData.keyboardLayoutNameCompactMode : SettingsData.keyboardLayoutNameCompactMode;
                                            default:
                                                return false;
                                            }
                                        })();
                                    return isCompact ? "zoom_out" : "zoom_in";
                                }
                                iconSize: 16
                                iconColor: {
                                    const isCompact = (() => {
                                            switch (modelData.id) {
                                            case "clock":
                                                return modelData.clockCompactMode !== undefined ? modelData.clockCompactMode : SettingsData.clockCompactMode;
                                            case "focusedWindow":
                                                return modelData.focusedWindowCompactMode !== undefined ? modelData.focusedWindowCompactMode : SettingsData.focusedWindowCompactMode;
                                            case "keyboard_layout_name":
                                                return modelData.keyboardLayoutNameCompactMode !== undefined ? modelData.keyboardLayoutNameCompactMode : SettingsData.keyboardLayoutNameCompactMode;
                                            default:
                                                return false;
                                            }
                                        })();
                                    return isCompact ? Theme.primary : Theme.outline;
                                }
                                onClicked: {
                                    const currentValue = (() => {
                                            switch (modelData.id) {
                                            case "clock":
                                                return modelData.clockCompactMode !== undefined ? modelData.clockCompactMode : SettingsData.clockCompactMode;
                                            case "focusedWindow":
                                                return modelData.focusedWindowCompactMode !== undefined ? modelData.focusedWindowCompactMode : SettingsData.focusedWindowCompactMode;
                                            case "keyboard_layout_name":
                                                return modelData.keyboardLayoutNameCompactMode !== undefined ? modelData.keyboardLayoutNameCompactMode : SettingsData.keyboardLayoutNameCompactMode;
                                            default:
                                                return false;
                                            }
                                        })();
                                    root.compactModeChanged(modelData.id, !currentValue);
                                }
                                onEntered: {
                                    const isCompact = (() => {
                                            switch (modelData.id) {
                                            case "clock":
                                                return modelData.clockCompactMode !== undefined ? modelData.clockCompactMode : SettingsData.clockCompactMode;
                                            case "focusedWindow":
                                                return modelData.focusedWindowCompactMode !== undefined ? modelData.focusedWindowCompactMode : SettingsData.focusedWindowCompactMode;
                                            case "keyboard_layout_name":
                                                return modelData.keyboardLayoutNameCompactMode !== undefined ? modelData.keyboardLayoutNameCompactMode : SettingsData.keyboardLayoutNameCompactMode;
                                            default:
                                                return false;
                                            }
                                        })();
                                    const tooltipText = isCompact ? "Full Size" : "Compact";
                                    sharedTooltip.show(tooltipText, compactModeButton, 0, 0, "bottom");
                                }
                                onExited: {
                                    sharedTooltip.hide();
                                }
                            }

                            DankActionButton {
                                id: appsDockMenuButton
                                buttonSize: 32
                                visible: modelData.id === "appsDock"
                                iconName: "more_vert"
                                iconSize: 18
                                iconColor: Theme.outline
                                onClicked: {
                                    appsDockContextMenu.widgetData = modelData;
                                    appsDockContextMenu.sectionId = root.sectionId;
                                    appsDockContextMenu.widgetIndex = index;

                                    var buttonPos = appsDockMenuButton.mapToItem(root, 0, 0);
                                    var popupWidth = appsDockContextMenu.width;
                                    var popupHeight = appsDockContextMenu.height;

                                    var xPos = buttonPos.x - popupWidth - Theme.spacingS;
                                    if (xPos < 0)
                                        xPos = buttonPos.x + appsDockMenuButton.width + Theme.spacingS;

                                    var yPos = buttonPos.y - popupHeight / 2 + appsDockMenuButton.height / 2;
                                    if (yPos < 0) {
                                        yPos = Theme.spacingS;
                                    } else if (yPos + popupHeight > root.height) {
                                        yPos = root.height - popupHeight - Theme.spacingS;
                                    }

                                    appsDockContextMenu.x = xPos;
                                    appsDockContextMenu.y = yPos;
                                    appsDockContextMenu.open();
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
                            id: ccMenuButton
                            visible: modelData.id === "controlCenterButton"
                            buttonSize: 32
                            iconName: "more_vert"
                            iconSize: 18
                            iconColor: Theme.outline
                            onClicked: {
                                controlCenterContextMenu.widgetData = modelData;
                                controlCenterContextMenu.sectionId = root.sectionId;
                                controlCenterContextMenu.widgetIndex = index;

                                var buttonPos = ccMenuButton.mapToItem(root, 0, 0);
                                var popupWidth = controlCenterContextMenu.width;
                                var popupHeight = controlCenterContextMenu.height;

                                var xPos = buttonPos.x - popupWidth - Theme.spacingS;
                                if (xPos < 0) {
                                    xPos = buttonPos.x + ccMenuButton.width + Theme.spacingS;
                                }

                                var yPos = buttonPos.y - popupHeight / 2 + ccMenuButton.height / 2;
                                if (yPos < 0) {
                                    yPos = Theme.spacingS;
                                } else if (yPos + popupHeight > root.height) {
                                    yPos = root.height - popupHeight - Theme.spacingS;
                                }

                                controlCenterContextMenu.x = xPos;
                                controlCenterContextMenu.y = yPos;
                                controlCenterContextMenu.open();
                            }
                        }

                        DankActionButton {
                            id: privacyMenuButton
                            visible: modelData.id === "privacyIndicator"
                            buttonSize: 32
                            iconName: "more_vert"
                            iconSize: 18
                            iconColor: Theme.outline
                            onClicked: {
                                privacyContextMenu.widgetData = modelData;
                                privacyContextMenu.sectionId = root.sectionId;
                                privacyContextMenu.widgetIndex = index;

                                var buttonPos = privacyMenuButton.mapToItem(root, 0, 0);
                                var popupWidth = privacyContextMenu.width;
                                var popupHeight = privacyContextMenu.height;

                                var xPos = buttonPos.x - popupWidth - Theme.spacingS;
                                if (xPos < 0) {
                                    xPos = buttonPos.x + privacyMenuButton.width + Theme.spacingS;
                                }

                                var yPos = buttonPos.y - popupHeight / 2 + privacyMenuButton.height / 2;
                                if (yPos < 0) {
                                    yPos = Theme.spacingS;
                                } else if (yPos + popupHeight > root.height) {
                                    yPos = root.height - popupHeight - Theme.spacingS;
                                }

                                privacyContextMenu.x = xPos;
                                privacyContextMenu.y = yPos;
                                privacyContextMenu.open();
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
                                root.itemEnabledChanged(root.sectionId, modelData.id, !modelData.enabled);
                            }
                            onEntered: {
                                const tooltipText = modelData.enabled ? "Hide" : "Show";
                                sharedTooltip.show(tooltipText, visibilityButton, 0, 0, "bottom");
                            }
                            onExited: {
                                sharedTooltip.hide();
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
                                    var currentSize = modelData.size || 20;
                                    var newSize = Math.max(5, currentSize - 5);
                                    root.spacerSizeChanged(root.sectionId, index, newSize);
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
                                    var currentSize = modelData.size || 20;
                                    var newSize = Math.min(5000, currentSize + 5);
                                    root.spacerSizeChanged(root.sectionId, index, newSize);
                                }
                            }
                        }

                        DankActionButton {
                            buttonSize: 32
                            iconName: "close"
                            iconSize: 18
                            iconColor: Theme.error
                            onClicked: {
                                root.removeWidget(root.sectionId, index);
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
                            delegateItem.z = 2;
                            delegateItem.originalY = delegateItem.y;
                        }
                        onReleased: {
                            delegateItem.z = 1;
                            if (drag.active) {
                                var newIndex = Math.round(delegateItem.y / (delegateItem.height + itemsList.spacing));
                                newIndex = Math.max(0, Math.min(newIndex, root.items.length - 1));
                                if (newIndex !== index) {
                                    var newItems = root.items.slice();
                                    var draggedItem = newItems.splice(index, 1)[0];
                                    newItems.splice(newIndex, 0, draggedItem);
                                    root.itemOrderChanged(newItems.map(item => root.cloneWidgetData(item)));
                                }
                            }
                            delegateItem.x = 0;
                            delegateItem.y = delegateItem.originalY;
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
        color: addButtonArea.containsMouse ? Theme.primaryContainer : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
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
                root.addWidget(root.sectionId);
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
        id: memUsageContextMenu

        property var widgetData: null
        property string sectionId: ""
        property int widgetIndex: -1

        width: 200
        height: 80
        padding: 0
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: 0
        }

        contentItem: Item {
            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: 2

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: swapToggleArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "swap_horiz"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Show Swap")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        id: swapToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: memUsageContextMenu.widgetData?.showSwap ?? false
                        onToggled: {
                            root.showSwapChanged(memUsageContextMenu.sectionId, memUsageContextMenu.widgetIndex, toggled);
                        }
                    }

                    MouseArea {
                        id: swapToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            swapToggle.checked = !swapToggle.checked;
                            root.showSwapChanged(memUsageContextMenu.sectionId, memUsageContextMenu.widgetIndex, swapToggle.checked);
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: gbToggleArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "straighten"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Show in GB")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        id: gbToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: memUsageContextMenu.widgetData?.showInGb ?? false
                        onToggled: {
                            root.showInGbChanged(memUsageContextMenu.sectionId, memUsageContextMenu.widgetIndex, toggled);
                        }
                    }

                    MouseArea {
                        id: gbToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            gbToggle.checked = !gbToggle.checked;
                            root.showInGbChanged(memUsageContextMenu.sectionId, memUsageContextMenu.widgetIndex, gbToggle.checked);
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: diskUsageContextMenu

        property var widgetData: null
        property string sectionId: ""
        property int widgetIndex: -1
        readonly property var currentWidgetData: (widgetIndex >= 0 && widgetIndex < root.items.length) ? root.items[widgetIndex] : widgetData

        width: 240
        height: diskMenuColumn.implicitHeight + Theme.spacingS * 2
        padding: 0
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: 0
        }

        contentItem: Item {
            Column {
                id: diskMenuColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: 2

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: "transparent"

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Disk Usage Display")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                }

                Repeater {
                    model: [
                        { label: I18n.tr("Percentage"), mode: 0, icon: "percent" },
                        { label: I18n.tr("Total"), mode: 1, icon: "storage" },
                        { label: I18n.tr("Remaining"), mode: 2, icon: "hourglass_empty" },
                        { label: I18n.tr("Remaining / Total"), mode: 3, icon: "pie_chart" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: diskMenuColumn.width
                        height: 32
                        radius: Theme.cornerRadius
                        color: diskOptionArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                        function isSelected() {
                            return (diskUsageContextMenu.currentWidgetData?.diskUsageMode ?? 0) === modelData.mode;
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: modelData.icon
                                size: 16
                                color: isSelected() ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                color: isSelected() ? Theme.primary : Theme.surfaceText
                                font.weight: isSelected() ? Font.Medium : Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        DankIcon {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            name: "check"
                            size: 16
                            color: Theme.primary
                            visible: isSelected()
                        }

                        MouseArea {
                            id: diskOptionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.diskUsageModeChanged(diskUsageContextMenu.sectionId, diskUsageContextMenu.widgetIndex, modelData.mode);
                                diskUsageContextMenu.close();
                            }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: controlCenterContextMenu

        property var widgetData: null
        property string sectionId: ""
        property int widgetIndex: -1

        width: 220
        height: menuColumn.implicitHeight + Theme.spacingS * 2
        padding: 0
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.surfaceContainer
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

                Repeater {
                    model: [
                        {
                            icon: "lan",
                            label: I18n.tr("Network"),
                            setting: "showNetworkIcon"
                        },
                        {
                            icon: "vpn_lock",
                            label: I18n.tr("VPN"),
                            setting: "showVpnIcon"
                        },
                        {
                            icon: "bluetooth",
                            label: I18n.tr("Bluetooth"),
                            setting: "showBluetoothIcon"
                        },
                        {
                            icon: "volume_up",
                            label: I18n.tr("Audio"),
                            setting: "showAudioIcon"
                        },
                        {
                            icon: "percent",
                            label: I18n.tr("Volume"),
                            setting: "showAudioPercent"
                        },
                        {
                            icon: "mic",
                            label: I18n.tr("Microphone"),
                            setting: "showMicIcon"
                        },
                        {
                            icon: "percent",
                            label: I18n.tr("Microphone Volume"),
                            setting: "showMicPercent"
                        },
                        {
                            icon: "brightness_high",
                            label: I18n.tr("Brightness"),
                            setting: "showBrightnessIcon"
                        },
                        {
                            icon: "percent",
                            label: I18n.tr("Brightness Value"),
                            setting: "showBrightnessPercent"
                        },
                        {
                            icon: "battery_full",
                            label: I18n.tr("Battery"),
                            setting: "showBatteryIcon"
                        },
                        {
                            icon: "print",
                            label: I18n.tr("Printer"),
                            setting: "showPrinterIcon"
                        },
                        {
                            icon: "screen_record",
                            label: I18n.tr("Screen Sharing"),
                            setting: "showScreenSharingIcon"
                        }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        function getCheckedState() {
                            var wd = controlCenterContextMenu.widgetData;
                            switch (modelData.setting) {
                            case "showNetworkIcon":
                                return wd?.showNetworkIcon ?? SettingsData.controlCenterShowNetworkIcon;
                            case "showVpnIcon":
                                return wd?.showVpnIcon ?? SettingsData.controlCenterShowVpnIcon;
                            case "showBluetoothIcon":
                                return wd?.showBluetoothIcon ?? SettingsData.controlCenterShowBluetoothIcon;
                            case "showAudioIcon":
                                return wd?.showAudioIcon ?? SettingsData.controlCenterShowAudioIcon;
                            case "showAudioPercent":
                                return wd?.showAudioPercent ?? SettingsData.controlCenterShowAudioPercent;
                            case "showMicIcon":
                                return wd?.showMicIcon ?? SettingsData.controlCenterShowMicIcon;
                            case "showMicPercent":
                                return wd?.showMicPercent ?? SettingsData.controlCenterShowMicPercent;
                            case "showBrightnessIcon":
                                return wd?.showBrightnessIcon ?? SettingsData.controlCenterShowBrightnessIcon;
                            case "showBrightnessPercent":
                                return wd?.showBrightnessPercent ?? SettingsData.controlCenterShowBrightnessPercent;
                            case "showBatteryIcon":
                                return wd?.showBatteryIcon ?? SettingsData.controlCenterShowBatteryIcon;
                            case "showPrinterIcon":
                                return wd?.showPrinterIcon ?? SettingsData.controlCenterShowPrinterIcon;
                            case "showScreenSharingIcon":
                                return wd?.showScreenSharingIcon ?? SettingsData.controlCenterShowScreenSharingIcon;
                            default:
                                return false;
                            }
                        }

                        width: menuColumn.width
                        height: 32
                        radius: Theme.cornerRadius
                        color: toggleArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: modelData.icon
                                size: 16
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        DankToggle {
                            id: toggle
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 20
                            checked: getCheckedState()
                            onToggled: {
                                root.controlCenterSettingChanged(controlCenterContextMenu.sectionId, controlCenterContextMenu.widgetIndex, modelData.setting, toggled);
                            }
                        }

                        MouseArea {
                            id: toggleArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                toggle.checked = !toggle.checked;
                                root.controlCenterSettingChanged(controlCenterContextMenu.sectionId, controlCenterContextMenu.widgetIndex, modelData.setting, toggle.checked);
                            }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: privacyContextMenu

        property var widgetData: null
        property string sectionId: ""
        property int widgetIndex: -1

        width: 200
        height: 160
        padding: 0
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        onOpened: {
            console.log("Privacy context menu opened");
        }

        onClosed: {
            console.log("Privacy Center context menu closed");
        }

        background: Rectangle {
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: 0
        }

        contentItem: Item {

            Column {
                id: menuPrivacyColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: 2

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Always on icons")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: micToggleArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "mic"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Microphone")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        id: micToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: SettingsData.privacyShowMicIcon
                        onToggled: toggled => {
                            root.privacySettingChanged(privacyContextMenu.sectionId, privacyContextMenu.widgetIndex, "showMicIcon", toggled);
                        }
                    }

                    MouseArea {
                        id: micToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            micToggle.checked = !micToggle.checked;
                            root.privacySettingChanged(privacyContextMenu.sectionId, privacyContextMenu.widgetIndex, "showMicIcon", micToggle.checked);
                        }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: cameraToggleArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "camera_video"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Camera")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        id: cameraToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: SettingsData.privacyShowCameraIcon
                        onToggled: toggled => {
                            root.privacySettingChanged(privacyContextMenu.sectionId, privacyContextMenu.widgetIndex, "showCameraIcon", toggled);
                        }
                    }

                    MouseArea {
                        id: cameraToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            cameraToggle.checked = !cameraToggle.checked;
                            root.privacySettingChanged(privacyContextMenu.sectionId, privacyContextMenu.widgetIndex, "showCameraIcon", cameraToggle.checked);
                        }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: screenshareToggleArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "screen_share"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Screen sharing")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        id: screenshareToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: SettingsData.privacyShowScreenShareIcon
                        onToggled: toggled => {
                            root.privacySettingChanged(privacyContextMenu.sectionId, privacyContextMenu.widgetIndex, "showScreenSharingIcon", toggled);
                        }
                    }

                    MouseArea {
                        id: screenshareToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            screenshareToggle.checked = !screenshareToggle.checked;
                            root.privacySettingChanged(privacyContextMenu.sectionId, privacyContextMenu.widgetIndex, "showScreenSharingIcon", screenshareToggle.checked);
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: gpuContextMenu

        property var widgetData: null
        property string sectionId: ""
        property int widgetIndex: -1

        width: 250
        height: gpuMenuColumn.implicitHeight + Theme.spacingS * 2
        padding: 0
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: 0
        }

        contentItem: Item {
            Column {
                id: gpuMenuColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: 2

                Repeater {
                    model: DgopService.availableGpus || []

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: gpuMenuColumn.width
                        height: 40
                        radius: Theme.cornerRadius
                        color: gpuOptionArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                        property bool isSelected: {
                            var selectedIdx = gpuContextMenu.widgetData ? (gpuContextMenu.widgetData.selectedGpuIndex !== undefined ? gpuContextMenu.widgetData.selectedGpuIndex : 0) : 0;
                            return index === selectedIdx;
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: checkIcon.left
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "memory"
                                size: 18
                                color: isSelected ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    text: modelData.driver ? modelData.driver.toUpperCase() : ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: isSelected ? Theme.primary : Theme.surfaceText
                                }

                                StyledText {
                                    text: modelData.displayName || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    elide: Text.ElideRight
                                    width: 180
                                }
                            }
                        }

                        DankIcon {
                            id: checkIcon
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            name: "check"
                            size: 18
                            color: Theme.primary
                            visible: isSelected
                        }

                        MouseArea {
                            id: gpuOptionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.gpuSelectionChanged(gpuContextMenu.sectionId, gpuContextMenu.widgetIndex, index);
                                gpuContextMenu.close();
                            }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: musicContextMenu

        property var widgetData: null
        property string sectionId: ""
        property int widgetIndex: -1

        width: 180
        height: musicMenuColumn.implicitHeight + Theme.spacingS * 2
        padding: 0
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: 0
        }

        contentItem: Item {
            Column {
                id: musicMenuColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: 2

                Repeater {
                    model: [
                        {
                            icon: "photo_size_select_small",
                            label: I18n.tr("Small"),
                            sizeValue: 0
                        },
                        {
                            icon: "photo_size_select_actual",
                            label: I18n.tr("Medium"),
                            sizeValue: 1
                        },
                        {
                            icon: "photo_size_select_large",
                            label: I18n.tr("Large"),
                            sizeValue: 2
                        },
                        {
                            icon: "fit_screen",
                            label: I18n.tr("Largest"),
                            sizeValue: 3
                        }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        function isSelected() {
                            var wd = musicContextMenu.widgetData;
                            var currentSize = wd?.mediaSize ?? SettingsData.mediaSize;
                            return currentSize === modelData.sizeValue;
                        }

                        width: musicMenuColumn.width
                        height: Math.max(18, Theme.fontSizeSmall) + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: musicOptionArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: modelData.icon
                                size: 18
                                color: isSelected() ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: isSelected() ? Font.Medium : Font.Normal
                                color: isSelected() ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        DankIcon {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            name: "check"
                            size: 16
                            color: Theme.primary
                            visible: isSelected()
                        }

                        MouseArea {
                            id: musicOptionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.compactModeChanged("music", modelData.sizeValue);
                                musicContextMenu.close();
                            }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: runningAppsContextMenu

        property var widgetData: null
        property string sectionId: ""
        property int widgetIndex: -1

        readonly property var currentWidgetData: (widgetIndex >= 0 && widgetIndex < root.items.length) ? root.items[widgetIndex] : widgetData

        width: 240
        height: runningAppsMenuColumn.implicitHeight + Theme.spacingS * 2
        padding: 0
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: 0
        }

        contentItem: Item {
            Column {
                id: runningAppsMenuColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: 2

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: "transparent"

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Running Apps Settings")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: raCompactArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "zoom_in"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Compact Mode")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        id: raCompactToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: runningAppsContextMenu.currentWidgetData?.runningAppsCompactMode ?? SettingsData.runningAppsCompactMode
                        onToggled: {
                            root.overflowSettingChanged(runningAppsContextMenu.sectionId, runningAppsContextMenu.widgetIndex, "runningAppsCompactMode", toggled);
                        }
                    }

                    MouseArea {
                        id: raCompactArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            raCompactToggle.checked = !raCompactToggle.checked;
                            root.overflowSettingChanged(runningAppsContextMenu.sectionId, runningAppsContextMenu.widgetIndex, "runningAppsCompactMode", raCompactToggle.checked);
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: raGroupArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "apps"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Group by App")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        id: raGroupToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: runningAppsContextMenu.currentWidgetData?.runningAppsGroupByApp ?? SettingsData.runningAppsGroupByApp
                        onToggled: {
                            root.overflowSettingChanged(runningAppsContextMenu.sectionId, runningAppsContextMenu.widgetIndex, "runningAppsGroupByApp", toggled);
                        }
                    }

                    MouseArea {
                        id: raGroupArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            raGroupToggle.checked = !raGroupToggle.checked;
                            root.overflowSettingChanged(runningAppsContextMenu.sectionId, runningAppsContextMenu.widgetIndex, "runningAppsGroupByApp", raGroupToggle.checked);
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: raWorkspaceArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "workspaces"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Current Workspace", "Running apps filter: only show apps from the active workspace")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        id: raWorkspaceToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: runningAppsContextMenu.currentWidgetData?.runningAppsCurrentWorkspace ?? SettingsData.runningAppsCurrentWorkspace
                        onToggled: {
                            root.overflowSettingChanged(runningAppsContextMenu.sectionId, runningAppsContextMenu.widgetIndex, "runningAppsCurrentWorkspace", toggled);
                        }
                    }

                    MouseArea {
                        id: raWorkspaceArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            raWorkspaceToggle.checked = !raWorkspaceToggle.checked;
                            root.overflowSettingChanged(runningAppsContextMenu.sectionId, runningAppsContextMenu.widgetIndex, "runningAppsCurrentWorkspace", raWorkspaceToggle.checked);
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    radius: Theme.cornerRadius
                    color: raDisplayArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "monitor"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Current Monitor", "Running apps filter: only show apps from the same monitor")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        id: raDisplayToggle
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 20
                        checked: runningAppsContextMenu.currentWidgetData?.runningAppsCurrentMonitor ?? SettingsData.runningAppsCurrentMonitor
                        onToggled: {
                            root.overflowSettingChanged(runningAppsContextMenu.sectionId, runningAppsContextMenu.widgetIndex, "runningAppsCurrentMonitor", toggled);
                        }
                    }

                    MouseArea {
                        id: raDisplayArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            raDisplayToggle.checked = !raDisplayToggle.checked;
                            root.overflowSettingChanged(runningAppsContextMenu.sectionId, runningAppsContextMenu.widgetIndex, "runningAppsCurrentMonitor", raDisplayToggle.checked);
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: appsDockContextMenu

        property var widgetData: null
        property string sectionId: ""
        property int widgetIndex: -1

        // Dynamically get current widget data from the items list
        readonly property var currentWidgetData: (widgetIndex >= 0 && widgetIndex < root.items.length) ? root.items[widgetIndex] : widgetData

        width: 320
        height: appsDockMenuColumn.implicitHeight + Theme.spacingS * 2
        padding: 0
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
            border.width: 0
        }

        contentItem: Item {
            Column {
                id: appsDockMenuColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingS

                StyledText {
                    text: I18n.tr("Apps Dock Settings")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    leftPadding: Theme.spacingS
                }

                StyledText {
                    text: I18n.tr("Overflow")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    leftPadding: Theme.spacingS
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Max Pinned Apps")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            width: 120
                        }

                        Row {
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            DankActionButton {
                                buttonSize: 24
                                iconName: "remove"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var current = appsDockContextMenu.currentWidgetData?.barMaxVisibleApps ?? SettingsData.barMaxVisibleApps;
                                    var newVal = Math.max(0, current - 1);
                                    root.overflowSettingChanged(appsDockContextMenu.sectionId, appsDockContextMenu.widgetIndex, "barMaxVisibleApps", newVal);
                                }
                            }

                            StyledText {
                                text: {
                                    var val = appsDockContextMenu.currentWidgetData?.barMaxVisibleApps ?? SettingsData.barMaxVisibleApps;
                                    return val === 0 ? I18n.tr("All") : val;
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignHCenter
                                width: 30
                            }

                            DankActionButton {
                                buttonSize: 24
                                iconName: "add"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var current = appsDockContextMenu.currentWidgetData?.barMaxVisibleApps ?? SettingsData.barMaxVisibleApps;
                                    var newVal = current + 1;
                                    root.overflowSettingChanged(appsDockContextMenu.sectionId, appsDockContextMenu.widgetIndex, "barMaxVisibleApps", newVal);
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Max Running Apps")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            width: 120
                        }

                        Row {
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            DankActionButton {
                                buttonSize: 24
                                iconName: "remove"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var current = appsDockContextMenu.currentWidgetData?.barMaxVisibleRunningApps ?? SettingsData.barMaxVisibleRunningApps;
                                    var newVal = Math.max(0, current - 1);
                                    root.overflowSettingChanged(appsDockContextMenu.sectionId, appsDockContextMenu.widgetIndex, "barMaxVisibleRunningApps", newVal);
                                }
                            }

                            StyledText {
                                text: {
                                    var val = appsDockContextMenu.currentWidgetData?.barMaxVisibleRunningApps ?? SettingsData.barMaxVisibleRunningApps;
                                    return val === 0 ? I18n.tr("All") : val;
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignHCenter
                                width: 30
                            }

                            DankActionButton {
                                buttonSize: 24
                                iconName: "add"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var current = appsDockContextMenu.currentWidgetData?.barMaxVisibleRunningApps ?? SettingsData.barMaxVisibleRunningApps;
                                    var newVal = current + 1;
                                    root.overflowSettingChanged(appsDockContextMenu.sectionId, appsDockContextMenu.widgetIndex, "barMaxVisibleRunningApps", newVal);
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.15
                    }

                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: Theme.cornerRadius
                        color: badgeToggleArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "notifications"
                                size: 16
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: I18n.tr("Show Badge")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        DankToggle {
                            id: badgeToggle
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 20
                            checked: appsDockContextMenu.currentWidgetData?.barShowOverflowBadge ?? SettingsData.barShowOverflowBadge
                            onToggled: {
                                root.overflowSettingChanged(appsDockContextMenu.sectionId, appsDockContextMenu.widgetIndex, "barShowOverflowBadge", toggled);
                            }
                        }

                        MouseArea {
                            id: badgeToggleArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                badgeToggle.checked = !badgeToggle.checked;
                                root.overflowSettingChanged(appsDockContextMenu.sectionId, appsDockContextMenu.widgetIndex, "barShowOverflowBadge", badgeToggle.checked);
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.15
                    }

                    StyledText {
                        text: I18n.tr("Visual Effects")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        leftPadding: Theme.spacingS
                        topPadding: Theme.spacingXS
                    }

                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: Theme.cornerRadius
                        color: hideIndicatorsArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "visibility_off"
                                size: 16
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: I18n.tr("Hide Indicators")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        DankToggle {
                            id: hideIndicatorsToggle
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 20
                            checked: SettingsData.appsDockHideIndicators
                            onToggled: {
                                SettingsData.set("appsDockHideIndicators", toggled);
                            }
                        }

                        MouseArea {
                            id: hideIndicatorsArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                hideIndicatorsToggle.checked = !hideIndicatorsToggle.checked;
                                SettingsData.set("appsDockHideIndicators", hideIndicatorsToggle.checked);
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: Theme.cornerRadius
                        color: colorizeActiveArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "palette"
                                size: 16
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: I18n.tr("Colorize Active")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        DankToggle {
                            id: colorizeActiveToggle
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 20
                            checked: SettingsData.appsDockColorizeActive
                            onToggled: {
                                SettingsData.set("appsDockColorizeActive", toggled);
                            }
                        }

                        MouseArea {
                            id: colorizeActiveArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                colorizeActiveToggle.checked = !colorizeActiveToggle.checked;
                                SettingsData.set("appsDockColorizeActive", colorizeActiveToggle.checked);
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: SettingsData.appsDockColorizeActive
                        leftPadding: Theme.spacingL + Theme.spacingS

                        StyledText {
                            text: I18n.tr("Active Color")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            width: 90
                        }

                        DankButtonGroup {
                            anchors.verticalCenter: parent.verticalCenter
                            model: ["pri", "sec", "pc", "err", "ok"]
                            buttonHeight: 22
                            minButtonWidth: 32
                            buttonPadding: 4
                            checkIconSize: 10
                            textSize: 9
                            spacing: 1
                            currentIndex: {
                                switch (SettingsData.appsDockActiveColorMode) {
                                case "secondary":
                                    return 1;
                                case "primaryContainer":
                                    return 2;
                                case "error":
                                    return 3;
                                case "success":
                                    return 4;
                                default:
                                    return 0;
                                }
                            }
                            onSelectionChanged: (index, selected) => {
                                if (!selected)
                                    return;
                                const modes = ["primary", "secondary", "primaryContainer", "error", "success"];
                                SettingsData.set("appsDockActiveColorMode", modes[index]);
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: Theme.cornerRadius
                        color: enlargeOnHoverArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "zoom_in"
                                size: 16
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: I18n.tr("Enlarge on Hover")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        DankToggle {
                            id: enlargeOnHoverToggle
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 20
                            checked: SettingsData.appsDockEnlargeOnHover
                            onToggled: {
                                SettingsData.set("appsDockEnlargeOnHover", toggled);
                            }
                        }

                        MouseArea {
                            id: enlargeOnHoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                enlargeOnHoverToggle.checked = !enlargeOnHoverToggle.checked;
                                SettingsData.set("appsDockEnlargeOnHover", enlargeOnHoverToggle.checked);
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: SettingsData.appsDockEnlargeOnHover

                        StyledText {
                            text: I18n.tr("Enlargement %")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            width: 120
                        }

                        Row {
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            DankActionButton {
                                buttonSize: 24
                                iconName: "remove"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var current = SettingsData.appsDockEnlargePercentage;
                                    var newVal = Math.max(100, current - 5);
                                    SettingsData.set("appsDockEnlargePercentage", newVal);
                                }
                            }

                            StyledText {
                                text: SettingsData.appsDockEnlargePercentage + "%"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignHCenter
                                width: 50
                            }

                            DankActionButton {
                                buttonSize: 24
                                iconName: "add"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var current = SettingsData.appsDockEnlargePercentage;
                                    var newVal = Math.min(150, current + 5);
                                    SettingsData.set("appsDockEnlargePercentage", newVal);
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Icon Size %")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            width: 120
                        }

                        Row {
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            DankActionButton {
                                buttonSize: 24
                                iconName: "remove"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var current = SettingsData.appsDockIconSizePercentage;
                                    var newVal = Math.max(50, current - 5);
                                    SettingsData.set("appsDockIconSizePercentage", newVal);
                                }
                            }

                            StyledText {
                                text: SettingsData.appsDockIconSizePercentage + "%"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignHCenter
                                width: 50
                            }

                            DankActionButton {
                                buttonSize: 24
                                iconName: "add"
                                iconSize: 14
                                iconColor: Theme.outline
                                onClicked: {
                                    var current = SettingsData.appsDockIconSizePercentage;
                                    var newVal = Math.min(200, current + 5);
                                    SettingsData.set("appsDockIconSizePercentage", newVal);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
