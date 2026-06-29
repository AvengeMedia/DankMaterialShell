import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string initialDeviceName: ""
    property string instanceId: ""
    property string screenName: ""
    property string screenModel: ""

    signal deviceNameChanged(string newDeviceName)

    property string currentDeviceName: ""

    function getScreenPinKey() {
        if (!screenName)
            return "";
        const screen = Quickshell.screens.find(s => s.name === screenName);
        if (screen)
            return SettingsData.getScreenDisplayName(screen);
        if (SettingsData.displayNameMode === "model" && screenModel && screenModel.length > 0)
            return screenModel;
        return screenName;
    }

    function resolveCurrentDevice() {
        const devices = DisplayService.devices || [];
        if (!DisplayService.brightnessAvailable || devices.length === 0)
            return "";

        const pinKey = getScreenPinKey();
        if (pinKey.length > 0) {
            const pins = SettingsData.brightnessDevicePins || {};
            const pinnedDevice = pins[pinKey];
            if (pinnedDevice && pinnedDevice.length > 0) {
                const found = devices.find(d => d.name === pinnedDevice);
                if (found)
                    return found.name;
            }
        }

        if (instanceId) {
            const widgets = SettingsData.controlCenterWidgets || [];
            const widget = widgets.find(w => w.id === "brightnessSlider" && w.instanceId === instanceId);
            if (widget && typeof widget.deviceName === "string" && widget.deviceName.length > 0) {
                const found = devices.find(d => d.name === widget.deviceName);
                if (found)
                    return found.name;
            }
        }

        if (DisplayService.currentDevice) {
            const found = devices.find(d => d.name === DisplayService.currentDevice);
            if (found)
                return found.name;
        }

        if (initialDeviceName && initialDeviceName.length > 0) {
            const found = devices.find(d => d.name === initialDeviceName);
            if (found)
                return found.name;
        }

        const backlight = devices.find(d => d.class === "backlight");
        if (backlight)
            return backlight.name;

        const ddc = devices.find(d => d.class === "ddc");
        if (ddc)
            return ddc.name;

        return devices[0].name;
    }

    function selectDevice(deviceName) {
        if (!deviceName || deviceName === root.currentDeviceName) {
            return;
        }
        const pinKey = getScreenPinKey();
        if (pinKey.length > 0) {
            const pins = SettingsData.brightnessDevicePins || {};
            const existing = pins[pinKey];
            if (existing && existing !== deviceName) {
                const next = JSON.parse(JSON.stringify(pins));
                delete next[pinKey];
                SettingsData.set("brightnessDevicePins", next);
            }
        }
        root.currentDeviceName = deviceName;
        DisplayService.setCurrentDevice(deviceName, true);
        Qt.callLater(() => root.deviceNameChanged(deviceName));
    }

    Component.onCompleted: {
        root.currentDeviceName = resolveCurrentDevice();
    }

    function isDevicePinnedToScreen(deviceName) {
        const pinKey = getScreenPinKey();
        if (!pinKey || !deviceName)
            return false;
        const pins = SettingsData.brightnessDevicePins || {};
        return pins[pinKey] === deviceName;
    }

    function togglePinForDevice(deviceName) {
        const pinKey = getScreenPinKey();
        if (!pinKey || !deviceName)
            return;
        const pins = JSON.parse(JSON.stringify(SettingsData.brightnessDevicePins || {}));
        if (pins[pinKey] === deviceName) {
            delete pins[pinKey];
        } else {
            pins[pinKey] = deviceName;
        }
        SettingsData.set("brightnessDevicePins", pins);
    }

    implicitHeight: {
        if (height > 0) {
            return height;
        }
        return brightnessContent.height + Theme.spacingM;
    }
    radius: Theme.cornerRadius
    color: Theme.nestedSurface
    border.color: Theme.outlineMedium
    border.width: Theme.layerOutlineWidth

    DankFlickable {
        id: brightnessContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingM
        anchors.topMargin: Theme.spacingM
        contentHeight: brightnessColumn.height
        clip: true

        Column {
            id: brightnessColumn
            width: parent.width
            spacing: Theme.spacingS

            Item {
                width: parent.width
                height: 100
                visible: !DisplayService.brightnessAvailable || !DisplayService.devices || DisplayService.devices.length === 0

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM

                    DankIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: DisplayService.brightnessAvailable ? "brightness_6" : "error"
                        size: 32
                        color: DisplayService.brightnessAvailable ? Theme.primary : Theme.error
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: DisplayService.brightnessAvailable ? I18n.tr("No brightness devices available") : I18n.tr("Brightness control not available")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Rectangle {
                id: monitorHeader
                width: parent.width
                height: 40
                visible: screenName && screenName.length > 0 && DisplayService.devices && DisplayService.devices.length > 1
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)

                property bool currentDevicePinned: root.isDevicePinnedToScreen(currentDeviceName)

                Item {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM

                    Row {
                        anchors.left: parent.left
                        anchors.right: globalPinButton.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "monitor"
                            size: Theme.iconSize
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: root.getScreenPinKey() || I18n.tr("Unknown Monitor")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            width: parent.width - Theme.iconSize - Theme.spacingM
                        }
                    }

                    Rectangle {
                        id: globalPinButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: globalPinRow.width + Theme.spacingS * 2
                        height: 28
                        radius: height / 2
                        color: monitorHeader.currentDevicePinned ? Theme.primaryPressed : Theme.withAlpha(Theme.surfaceText, 0.05)

                        Row {
                            id: globalPinRow
                            anchors.centerIn: parent
                            spacing: 4

                            DankIcon {
                                name: "push_pin"
                                size: 16
                                color: monitorHeader.currentDevicePinned ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: monitorHeader.currentDevicePinned ? I18n.tr("Pinned") : I18n.tr("Pin")
                                font.pixelSize: Theme.fontSizeSmall
                                color: monitorHeader.currentDevicePinned ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        DankRipple {
                            id: globalPinRipple
                            cornerRadius: parent.radius
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: currentDeviceName && currentDeviceName.length > 0
                            onPressed: mouse => globalPinRipple.trigger(mouse.x, mouse.y)
                            onClicked: root.togglePinForDevice(currentDeviceName)
                        }
                    }
                }
            }

            Repeater {
                model: DisplayService.devices || []
                delegate: Rectangle {
                    id: deviceCard

                    required property var modelData
                    required property int index

                    readonly property bool selected: !!(modelData && modelData.name === root.currentDeviceName)
                    readonly property bool devicePinnedHere: {
                        SettingsData.brightnessDevicePins;
                        return root.isDevicePinnedToScreen(modelData ? modelData.name : "");
                    }

                    property real deviceBrightness: {
                        DisplayService.brightnessVersion;
                        return DisplayService.getDeviceBrightness(modelData.name);
                    }

                    width: parent.width
                    height: 100
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                    border.color: selected ? Theme.primary : Theme.outlineStrong
                    border.width: selected ? 2 : 0

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        Item {
                            width: parent.width
                            height: Math.max(deviceIconColumn.height, deviceInfoColumn.height, rightControls.height)

                            Row {
                                anchors.left: parent.left
                                anchors.right: rightControls.left
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingM

                                Column {
                                    id: deviceIconColumn
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    DankIcon {
                                        name: {
                                            const deviceClass = modelData.class || "";
                                            const deviceName = modelData.name || "";

                                            if (deviceClass === "backlight" || deviceClass === "ddc") {
                                                if (deviceBrightness <= 33)
                                                    return "brightness_low";
                                                if (deviceBrightness <= 66)
                                                    return "brightness_medium";
                                                return "brightness_high";
                                            } else if (deviceName.includes("kbd")) {
                                                return "keyboard";
                                            } else {
                                                return "lightbulb";
                                            }
                                        }
                                        size: Theme.iconSize
                                        color: deviceCard.selected ? Theme.primary : Theme.surfaceText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    StyledText {
                                        text: Math.round(deviceBrightness) + "%"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }

                                Column {
                                    id: deviceInfoColumn
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - deviceIconColumn.width - Theme.spacingM

                                    StyledText {
                                        text: {
                                            const name = modelData.name || "";
                                            const deviceClass = modelData.class || "";
                                            if (deviceClass === "backlight") {
                                                return name.replace("_", " ").replace(/\b\w/g, c => c.toUpperCase());
                                            }
                                            return name;
                                        }
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                        font.weight: deviceCard.selected ? Font.Medium : Font.Normal
                                        elide: Text.ElideRight
                                        width: parent.width
                                        horizontalAlignment: Text.AlignLeft
                                    }

                                    StyledText {
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                        width: parent.width
                                        horizontalAlignment: Text.AlignLeft
                                    }

                                    StyledText {
                                        text: {
                                            const deviceClass = modelData.class || "";
                                            if (deviceClass === "backlight")
                                                return I18n.tr("Backlight device");
                                            if (deviceClass === "ddc")
                                                return I18n.tr("DDC/CI monitor");
                                            if (deviceClass === "leds")
                                                return I18n.tr("LED device");
                                            return deviceClass;
                                        }
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                        width: parent.width
                                        horizontalAlignment: Text.AlignLeft
                                    }
                                }
                            }

                            Row {
                                id: rightControls
                                height: 28
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingS
                                z: 1

                                Row {
                                    id: exponentControls
                                    height: 28
                                    spacing: Theme.spacingXS
                                    visible: SessionData.getBrightnessExponential(modelData.name)

                                    StyledRect {
                                        width: 28
                                        height: 28
                                        radius: Theme.cornerRadius
                                        color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                                        opacity: SessionData.getBrightnessExponent(modelData.name) > 1.0 ? 1.0 : 0.4

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "remove"
                                            size: 14
                                            color: Theme.surfaceText
                                        }

                                        StateLayer {
                                            stateColor: Theme.primary
                                            cornerRadius: parent.radius
                                            enabled: SessionData.getBrightnessExponent(modelData.name) > 1.0
                                            onClicked: {
                                                const current = SessionData.getBrightnessExponent(modelData.name);
                                                const newValue = Math.max(1.0, Math.round((current - 0.1) * 10) / 10);
                                                SessionData.setBrightnessExponent(modelData.name, newValue);
                                            }
                                        }
                                    }

                                    StyledRect {
                                        width: 50
                                        height: 28
                                        radius: Theme.cornerRadius
                                        color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                                        border.width: 0

                                        StyledText {
                                            anchors.centerIn: parent
                                            text: SessionData.getBrightnessExponent(modelData.name).toFixed(1)
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Medium
                                            color: Theme.primary
                                        }
                                    }

                                    StyledRect {
                                        width: 28
                                        height: 28
                                        radius: Theme.cornerRadius
                                        color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                                        opacity: SessionData.getBrightnessExponent(modelData.name) < 2.5 ? 1.0 : 0.4

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "add"
                                            size: 14
                                            color: Theme.surfaceText
                                        }

                                        StateLayer {
                                            stateColor: Theme.primary
                                            cornerRadius: parent.radius
                                            enabled: SessionData.getBrightnessExponent(modelData.name) < 2.5
                                            onClicked: {
                                                const current = SessionData.getBrightnessExponent(modelData.name);
                                                const newValue = Math.min(2.5, Math.round((current + 0.1) * 10) / 10);
                                                SessionData.setBrightnessExponent(modelData.name, newValue);
                                            }
                                        }
                                    }
                                }

                                StyledRect {
                                    id: pinButton
                                    width: 28
                                    height: 28
                                    radius: Theme.cornerRadius
                                    visible: root.screenName && root.screenName.length > 0 && DisplayService.devices && DisplayService.devices.length > 1
                                    color: devicePinnedHere ? Theme.primaryPressed : Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "push_pin"
                                        size: 14
                                        color: devicePinnedHere ? Theme.primary : Theme.surfaceText
                                    }

                                    StateLayer {
                                        stateColor: Theme.primary
                                        cornerRadius: parent.radius
                                        onClicked: root.togglePinForDevice(modelData.name)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 24
                            radius: height / 2
                            color: SessionData.getBrightnessExponential(modelData.name) ? Theme.primaryHover : Theme.withAlpha(Theme.surfaceText, 0.05)

                            Row {
                                anchors.centerIn: parent
                                spacing: 4

                                DankIcon {
                                    name: "show_chart"
                                    size: 14
                                    color: SessionData.getBrightnessExponential(modelData.name) ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: SessionData.getBrightnessExponential(modelData.name) ? I18n.tr("Exponential") : I18n.tr("Linear")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: SessionData.getBrightnessExponential(modelData.name) ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            DankRipple {
                                id: expToggleRipple
                                cornerRadius: parent.radius
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => expToggleRipple.trigger(mouse.x, mouse.y)
                                onClicked: {
                                    const currentState = SessionData.getBrightnessExponential(modelData.name);
                                    SessionData.setBrightnessExponential(modelData.name, !currentState);
                                }
                            }
                        }
                    }

                    DankRipple {
                        id: deviceRipple
                        cornerRadius: parent.radius
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.bottomMargin: 28
                        anchors.rightMargin: rightControls.width + Theme.spacingS
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => deviceRipple.trigger(mouse.x, mouse.y)
                        onClicked: root.selectDevice(modelData.name)
                    }
                }
            }
        }
    }
}
