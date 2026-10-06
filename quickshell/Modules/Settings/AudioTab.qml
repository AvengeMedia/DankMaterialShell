import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    readonly property var log: Log.scoped("AudioTab")

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var outputDevices: []
    property var inputDevices: []
    property var parentModal: null
    property var editingDevice: null
    property string editingDeviceType: ""
    property bool isReloadingAudio: false
    property var hiddenOutputDeviceNames: SessionData.hiddenOutputDeviceNames ?? []
    property var hiddenInputDeviceNames: SessionData.hiddenInputDeviceNames ?? []
    property bool showHiddenOutputDevices: false
    property bool showHiddenInputDevices: false

    function openRenameDialog(device, type) {
        editingDevice = device;
        editingDeviceType = type;
        renameDialog.show(AudioService.displayName(device));
    }

    function saveDeviceName(name) {
        if (!editingDevice)
            return;
        AudioService.setDeviceAlias(editingDevice.name, name);
        renameDialog.hide();
    }

    function persistHiddenOutputDeviceNames(deviceNames) {
        const uniqueNames = [...new Set(deviceNames)];
        hiddenOutputDeviceNames = uniqueNames;
        SessionData.setHiddenOutputDeviceNames(uniqueNames);
    }

    function persistHiddenInputDeviceNames(deviceNames) {
        const uniqueNames = [...new Set(deviceNames)];
        hiddenInputDeviceNames = uniqueNames;
        SessionData.setHiddenInputDeviceNames(uniqueNames);
    }

    function updateDeviceList() {
        const allNodes = AudioService.allNodes;

        // Sort devices: active first, then alphabetically by name
        const sortDevices = (a, b) => {
            if (a === AudioService.sink && b !== AudioService.sink)
                return -1;
            if (b === AudioService.sink && a !== AudioService.sink)
                return 1;
            const nameA = AudioService.displayName(a).toLowerCase();
            const nameB = AudioService.displayName(b).toLowerCase();
            return nameA.localeCompare(nameB);
        };

        const outputs = allNodes.filter(node => {
            return node.audio && node.isSink && (SettingsData.audioShowStreamDevices || !node.isStream);
        });
        outputDevices = outputs.sort(sortDevices);

        const inputs = allNodes.filter(node => {
            return node.audio && !node.isSink && (SettingsData.audioShowStreamDevices || !node.isStream);
        });

        const sortInputs = (a, b) => {
            if (a === AudioService.source && b !== AudioService.source)
                return -1;
            if (b === AudioService.source && a !== AudioService.source)
                return 1;
            const nameA = AudioService.displayName(a).toLowerCase();
            const nameB = AudioService.displayName(b).toLowerCase();
            return nameA.localeCompare(nameB);
        };

        inputDevices = inputs.sort(sortInputs);
    }

    Component.onCompleted: {
        AudioService.addRef();
        hiddenOutputDeviceNames = SessionData.hiddenOutputDeviceNames ?? [];
        hiddenInputDeviceNames = SessionData.hiddenInputDeviceNames ?? [];
        updateDeviceList();
    }

    Component.onDestruction: AudioService.removeRef()

    Connections {
        target: AudioService
        function onDeviceRevisionChanged() {
            root.updateDeviceList();
        }
    }

    Connections {
        target: SettingsData
        function onAudioShowStreamDevicesChanged() {
            root.updateDeviceList();
        }
    }

    Connections {
        target: AudioService
        function onWireplumberReloadStarted() {
            root.isReloadingAudio = true;
        }
        function onWireplumberReloadCompleted(success) {
            Qt.callLater(() => {
                delayTimer.start();
            });
        }
        function onDeviceAliasChanged(nodeName, newAlias) {
            root.updateDeviceList();
        }
    }

    Timer {
        id: delayTimer
        interval: 2000
        repeat: false
        onTriggered: {
            root.isReloadingAudio = false;
            root.updateDeviceList();
        }
    }

    SettingsPage {
        id: mainColumn

        SettingsCard {
            tab: "audio"
            tags: ["audio", "accessibility", "mono"]
            title: I18n.tr("Mono Audio", "Audio settings: mono audio toggle")
            settingKey: "audioMono"
            iconName: "a11y"

            SettingsToggleRow {
                tab: "audio"
                tags: ["audio", "mono"]
                settingKey: "audioMono"
                text: I18n.tr("Mono Audio", "Audio settings: mono audio toggle")
                description: I18n.tr("Mix all stereo content into a single channel", "Audio settings mono description")
                enabled: AudioService.monoSettingSupported
                checked: SettingsData.audioMono
                onToggled: checked => {
                    SettingsData.set("audioMono", checked);
                    AudioService.setMonoSetting(checked, (ok, message) => {
                        if (!ok) {
                            SettingsData.set("audioMono", !checked);
                        }
                    });
                }
            }
        }

        SettingsCard {
            tab: "audio"
            tags: ["audio", "device", "output", "speaker"]
            title: I18n.tr("Output devices")
            settingKey: "audioOutputDevices"
            iconName: "volume_up"

            SettingsToggleRow {
                tab: "audio"
                tags: ["audio", "virtual", "stream", "obs", "loopback", "device", "sink"]
                settingKey: "audioShowStreamDevices"
                text: I18n.tr("Show virtual devices")
                checked: SettingsData.audioShowStreamDevices
                onToggled: checked => SettingsData.set("audioShowStreamDevices", checked)
            }

            SettingsRow {
                body: StyledText {
                    width: parent.width
                    text: I18n.tr("Set custom names for your audio output devices", "Audio settings description")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignLeft
                }
            }

            Repeater {
                model: root.outputDevices.filter(d => !root.hiddenOutputDeviceNames.includes(d.name))

                delegate: Column {
                    required property var modelData
                    width: parent?.width ?? 0
                    spacing: 0

                    DeviceAliasRow {
                        deviceNode: modelData
                        deviceType: "output"
                        showHideButton: true

                        onEditRequested: device => root.openRenameDialog(device, "output")

                        onHideRequested: device => {
                            root.persistHiddenOutputDeviceNames([...root.hiddenOutputDeviceNames, device.name]);
                        }
                    }

                    Item {
                        width: parent.width
                        height: maxVolSlider.height

                        StyledText {
                            id: maxVolLabel
                            text: I18n.tr("Max volume") + " · " + maxVolSlider.value + "%"
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM + Theme.iconSize + Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            horizontalAlignment: Text.AlignLeft
                        }

                        DSlider {
                            id: maxVolSlider
                            upDownKeysStep: false
                            anchors.left: maxVolLabel.right
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            minimum: 100
                            maximum: 200
                            step: 5
                            showValue: true
                            wheelEnabled: false
                            centerMinimum: true
                            onSliderValueChanged: newValue => {
                                SessionData.setDeviceMaxVolume(modelData.name, newValue);
                            }
                        }

                        Binding {
                            target: maxVolSlider
                            property: "value"
                            value: SessionData.deviceMaxVolumes[modelData.name] ?? 100
                            when: !maxVolSlider.isDragging
                        }
                    }
                }
            }

            SettingsRow {
                visible: root.outputDevices.filter(d => !root.hiddenOutputDeviceNames.includes(d.name)).length === 0 && root.hiddenOutputDeviceNames.length === 0
                body: StyledText {
                    width: parent.width
                    text: I18n.tr("No output devices found", "Audio settings empty state")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: Theme.spacingM
                }
            }

            SettingsRow {
                visible: root.hiddenOutputDeviceNames.length > 0
                body: Column {
                    width: parent.width
                    spacing: 0

                    Item {
                        width: parent.width
                        height: 36

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DIcon {
                                name: "visibility_off"
                                size: Theme.iconSizeMedium
                                color: Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: I18n.tr("Hidden (%1)", "count of hidden audio devices").arg(root.hiddenOutputDeviceNames.length)
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        DIcon {
                            name: root.showHiddenOutputDevices ? "expand_less" : "expand_more"
                            size: Theme.iconSizeMedium
                            color: Theme.surfaceVariantText
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showHiddenOutputDevices = !root.showHiddenOutputDevices
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 0
                        visible: root.showHiddenOutputDevices

                        Repeater {
                            model: root.outputDevices.filter(d => root.hiddenOutputDeviceNames.includes(d.name))

                            delegate: DeviceAliasRow {
                                required property var modelData
                                deviceNode: modelData
                                deviceType: "output"
                                isHidden: true
                                showHideButton: true

                                onHideRequested: device => {
                                    root.persistHiddenOutputDeviceNames(root.hiddenOutputDeviceNames.filter(n => n !== device.name));
                                }
                            }
                        }
                    }
                }
            }
        }

        SettingsCard {
            tab: "audio"
            tags: ["audio", "device", "input", "microphone"]
            title: I18n.tr("Input devices")
            settingKey: "audioInputDevices"
            iconName: "mic"

            SettingsRow {
                body: Column {
                    width: parent.width
                    spacing: Theme.spacingM

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Set custom names for your audio input devices", "Audio settings description")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignLeft
                    }

                    Repeater {
                        model: root.inputDevices.filter(d => !root.hiddenInputDeviceNames.includes(d.name))

                        delegate: DeviceAliasRow {
                            required property var modelData

                            deviceNode: modelData
                            deviceType: "input"
                            showHideButton: true

                            onEditRequested: device => root.openRenameDialog(device, "input")

                            onHideRequested: device => {
                                root.persistHiddenInputDeviceNames([...root.hiddenInputDeviceNames, device.name]);
                            }
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("No input devices found", "Audio settings empty state")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        horizontalAlignment: Text.AlignHCenter
                        visible: root.inputDevices.filter(d => !root.hiddenInputDeviceNames.includes(d.name)).length === 0 && root.hiddenInputDeviceNames.length === 0
                        topPadding: Theme.spacingM
                    }

                    Column {
                        width: parent.width
                        spacing: 0
                        visible: root.hiddenInputDeviceNames.length > 0

                        Item {
                            width: parent.width
                            height: 36

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingS

                                DIcon {
                                    name: "visibility_off"
                                    size: Theme.iconSizeMedium
                                    color: Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: I18n.tr("Hidden (%1)", "count of hidden audio devices").arg(root.hiddenInputDeviceNames.length)
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            DIcon {
                                name: root.showHiddenInputDevices ? "expand_less" : "expand_more"
                                size: Theme.iconSizeMedium
                                color: Theme.surfaceVariantText
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showHiddenInputDevices = !root.showHiddenInputDevices
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 0
                            visible: root.showHiddenInputDevices

                            Repeater {
                                model: root.inputDevices.filter(d => root.hiddenInputDeviceNames.includes(d.name))

                                delegate: DeviceAliasRow {
                                    required property var modelData
                                    deviceNode: modelData
                                    deviceType: "input"
                                    isHidden: true
                                    showHideButton: true

                                    onHideRequested: device => {
                                        root.persistHiddenInputDeviceNames(root.hiddenInputDeviceNames.filter(n => n !== device.name));
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
        id: loadingOverlay
        anchors.fill: parent
        color: Theme.withAlpha(Theme.hostSurface, 0.9)
        visible: root.isReloadingAudio
        z: 100

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingL

            DLoadingIndicator {
                contained: true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Column {
                spacing: Theme.spacingS
                anchors.horizontalCenter: parent.horizontalCenter

                StyledText {
                    text: I18n.tr("Restarting audio system...", "Loading overlay while WirePlumber restarts")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Theme.fontWeightMedium
                    color: Theme.surfaceText
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: I18n.tr("This may take a few seconds", "Loading overlay subtitle")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    SettingsRenameDialog {
        id: renameDialog
        parent: root.parentModal?.modalFocusScope ?? root
        title: I18n.tr("Set custom device name")
        supportingText: root.editingDevice?.name ?? ""
        labelText: I18n.tr("Custom name")
        leftIconName: root.editingDeviceType === "input" ? "mic" : "speaker"
        onAccepted: name => root.saveDeviceName(name)

        aboveField: StyledText {
            visible: AudioService.hasDeviceAlias(root.editingDevice?.name ?? "")
            text: I18n.tr("Original: %1", "Shows the original device name before renaming").arg(AudioService.originalName(root.editingDevice))
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: parent.width
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignLeft
        }

        belowField: StyledText {
            width: parent.width
            text: I18n.tr("Press Enter and the audio system will restart to apply the change", "Audio device rename dialog hint")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignLeft
        }
    }
}
