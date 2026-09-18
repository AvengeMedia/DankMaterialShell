pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.ControlCenter.Widgets
import qs.Services

CcSheetDialog {
    id: root

    property var node: null
    property var availablePorts: []
    property string currentPort: ""
    property bool isLoading: false

    readonly property bool nodeValid: node !== null && node.isSink

    signal portSelected(string sinkName, string portName)

    iconName: node ? AudioService.sinkIcon(node) : "speaker"
    title: node ? AudioService.displayName(node) : ""
    subtitle: I18n.tr("Port Selection", "audio port selector modal subtitle")
    statusText: {
        if (isLoading)
            return I18n.tr("Loading ports...", "audio port selector loading state");
        if (availablePorts.length === 0)
            return I18n.tr("No ports found", "audio port selector empty state");
        return I18n.tr("Current: %1", "audio port selector active port label, %1 is the port name").arg(portDescription(currentPort));
    }
    statusColor: isLoading ? Theme.primary : Theme.surfaceVariantText

    function show(sinkNode) {
        if (!sinkNode || !sinkNode.isSink)
            return;
        node = sinkNode;
        isLoading = true;
        availablePorts = [];
        currentPort = "";
        populateFromCache();
        AudioService.refreshSinkPorts(() => {
            root.isLoading = false;
        });
        present();
    }

    function populateFromCache() {
        const info = AudioService.getSinkPorts(node);
        if (!info) {
            availablePorts = [];
            currentPort = "";
            return;
        }
        availablePorts = (info.ports || []).slice().sort((a, b) => b.priority - a.priority);
        currentPort = info.active || "";
        isLoading = false;
    }

    function portDescription(portName) {
        const port = availablePorts.find(p => p.name === portName);
        return port ? port.description : portName;
    }

    function selectPort(portName) {
        if (!nodeValid || isLoading)
            return;
        const port = availablePorts.find(p => p.name === portName);
        if (!port || port.availability === "no")
            return;
        const capturedName = node.name;
        isLoading = true;
        AudioService.setSinkPort(capturedName, portName, (success, message) => {
            isLoading = false;
            if (!root.node || root.node.name !== capturedName)
                return;
            if (!success) {
                ToastService.showToast(message, ToastService.levelError);
                return;
            }
            root.portSelected(capturedName, portName);
            ToastService.showToast(message, ToastService.levelInfo);
            root.dismiss();
        });
    }

    onNodeValidChanged: {
        if (shown && !nodeValid)
            dismiss();
    }

    onDismissed: node = null

    readonly property var audioSinkPorts: AudioService.sinkPorts

    onAudioSinkPortsChanged: {
        if (!nodeValid)
            return;
        populateFromCache();
        isLoading = false;
    }

    CcGroup {
        visible: root.availablePorts.length > 0

        Repeater {
            model: root.availablePorts

            CcListRow {
                required property var modelData

                readonly property bool unavailable: modelData.availability === "no"

                title: modelData.description
                subtitle: {
                    if (unavailable)
                        return I18n.tr("Unavailable", "audio port availability status");
                    if (modelData.availability === "yes")
                        return I18n.tr("Available", "audio port availability status");
                    return "";
                }
                active: modelData.name === root.currentPort
                showActiveCheck: true
                enabled: !unavailable && !root.isLoading
                clickable: !active
                onClicked: root.selectPort(modelData.name)
            }
        }
    }
}
