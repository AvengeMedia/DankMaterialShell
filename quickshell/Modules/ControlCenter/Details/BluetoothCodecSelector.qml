pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.ControlCenter.Widgets
import qs.Services

CcSheetDialog {
    id: root

    property var device: null
    property var availableCodecs: []
    property string currentCodec: ""
    property bool isLoading: false
    property string statusMessage: ""
    property bool statusIsError: false

    readonly property var mediaCodecs: availableCodecs.filter(c => (c.category || "media") !== "call")
    readonly property var callCodecs: availableCodecs.filter(c => c.category === "call")
    readonly property bool deviceValid: device !== null && device.connected && BluetoothService.isAudioDevice(device)
    readonly property bool splitSections: mediaCodecs.length > 0 && callCodecs.length > 0

    signal codecSelected(string deviceAddress, string codecName)

    iconName: device ? BluetoothService.getDeviceIcon(device) : "headset"
    title: device ? (device.name || device.deviceName) : ""
    subtitle: I18n.tr("Audio Codec Selection")
    statusText: {
        if (isLoading)
            return I18n.tr("Loading codecs...");
        if (statusMessage.length > 0)
            return statusMessage;
        return I18n.tr("Current: %1").arg(currentCodec);
    }
    statusColor: statusIsError ? Theme.error : (isLoading ? Theme.primary : Theme.surfaceVariantText)

    function show(bluetoothDevice) {
        if (!bluetoothDevice?.connected || !BluetoothService.isAudioDevice(bluetoothDevice))
            return;
        device = bluetoothDevice;
        isLoading = true;
        availableCodecs = [];
        currentCodec = "";
        statusMessage = "";
        statusIsError = false;
        queryCodecs();
        present();
    }

    function queryCodecs() {
        if (!deviceValid) {
            dismiss();
            return;
        }
        const capturedDevice = device;
        const capturedAddress = device.address;
        BluetoothService.getAvailableCodecs(capturedDevice, (codecs, current) => {
            if (!root.deviceValid || root.device?.address !== capturedAddress)
                return;
            availableCodecs = codecs;
            currentCodec = current;
            isLoading = false;
            if (BluetoothService.wpexecChecked && !BluetoothService.wpexecAvailable && !BluetoothService.dbusBridgeAvailable) {
                statusMessage = I18n.tr("Codec switching is unavailable. WirePlumber wpexec was not found.", "bluetooth codec selector error, wpexec is a program name");
                statusIsError = true;
                return;
            }
            statusMessage = codecs.length === 0 ? I18n.tr("No codecs found") : "";
            statusIsError = false;
        });
    }

    function selectCodec(profileName) {
        if (!deviceValid || isLoading)
            return;
        const capturedDevice = device;
        const capturedAddress = device.address;
        const selectedCodec = availableCodecs.find(c => c.profile === profileName);
        if (!selectedCodec)
            return;
        BluetoothService.updateDeviceCodec(capturedAddress, selectedCodec.name);
        codecSelected(capturedAddress, selectedCodec.name);
        isLoading = true;
        BluetoothService.switchCodec(capturedDevice, profileName, (success, message) => {
            if (!root.device || root.device.address !== capturedAddress)
                return;
            isLoading = false;
            if (!success) {
                ToastService.showToast(message, ToastService.levelError);
                return;
            }
            BluetoothService.updateDeviceCodec(capturedAddress, selectedCodec.name);
            codecSelected(capturedAddress, selectedCodec.name);
            ToastService.showToast(message, ToastService.levelInfo);
            root.dismiss();
        }, selectedCodec.name);
    }

    onDeviceValidChanged: {
        if (shown && !deviceValid)
            dismiss();
    }

    onDismissed: device = null

    component CodecRow: CcListRow {
        required property var modelData

        title: modelData.name
        subtitle: modelData.description
        active: modelData.name === root.currentCodec
        showActiveCheck: true
        enabled: !root.isLoading
        clickable: !active
        onClicked: root.selectCodec(modelData.profile)

        leading: CcStatusDot {
            color: modelData.qualityColor
        }
    }

    CcSectionLabel {
        text: I18n.tr("Media")
        visible: root.splitSections && !root.isLoading
    }

    CcGroup {
        visible: !root.isLoading && root.mediaCodecs.length > 0

        Repeater {
            model: root.mediaCodecs

            CodecRow {}
        }
    }

    CcSectionLabel {
        text: I18n.tr("Calls / Headset")
        visible: root.callCodecs.length > 0 && !root.isLoading
    }

    CcGroup {
        visible: !root.isLoading && root.callCodecs.length > 0

        Repeater {
            model: root.callCodecs

            CodecRow {}
        }
    }
}
