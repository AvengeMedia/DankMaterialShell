import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var node: null
    property bool modalVisible: false
    property var availablePorts: []
    property string currentPort: ""
    property bool isLoading: false

    readonly property bool nodeValid: node !== null && node.isSink

    signal portSelected(string sinkName, string portName)

    function show(sinkNode) {
        if (!sinkNode || !sinkNode.isSink)
            return;
        node = sinkNode;
        isLoading = true;
        availablePorts = [];
        currentPort = "";
        visible = true;
        modalVisible = true;

        populateFromCache();
        AudioService.refreshSinkPorts(() => {
            root.isLoading = false;
        });

        Qt.callLater(() => {
            focusScope.forceActiveFocus();
        });
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

    function hide() {
        if (!modalVisible)
            return;
        modalVisible = false;
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
        AudioService.setSinkPort(capturedName, portName, function (success, message) {
            isLoading = false;
            if (!root.node || root.node.name !== capturedName)
                return;

            if (success) {
                root.portSelected(capturedName, portName);
                ToastService.showToast(message, ToastService.levelInfo);
                Qt.callLater(root.hide);
                return;
            }
            ToastService.showToast(message, ToastService.levelError);
        });
    }

    onNodeValidChanged: {
        if (modalVisible && !nodeValid) {
            hide();
        }
    }

    Connections {
        target: AudioService
        function onSinkPortsChanged() {
            if (!root.nodeValid)
                return;
            root.populateFromCache();
            root.isLoading = false;
        }
    }

    visible: false
    anchors.fill: parent
    z: 2000

    MouseArea {
        id: modalBlocker
        anchors.fill: parent
        visible: root.visible
        enabled: root.visible
        hoverEnabled: true
        preventStealing: true
        propagateComposedEvents: false

        onClicked: root.hide()
        onWheel: wheel => {
            wheel.accepted = true;
        }
        onPositionChanged: mouse => {
            mouse.accepted = true;
        }
    }

    Rectangle {
        id: modalBackground
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, BlurService.enabled ? 0.72 : 0.5)
        opacity: modalVisible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
    }

    FocusScope {
        id: focusScope

        anchors.fill: parent
        focus: root.visible
        enabled: root.visible

        Keys.onEscapePressed: event => {
            root.hide();
            event.accepted = true;
        }
    }

    Rectangle {
        id: modalContent
        anchors.centerIn: parent
        width: 320
        height: contentColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainer, BlurService.enabled ? 0.96 : Theme.popupTransparency)
        border.color: BlurService.enabled ? BlurService.borderColor : Theme.outlineMedium
        border.width: BlurService.enabled ? BlurService.borderWidth : Theme.layerOutlineWidth
        opacity: modalVisible ? 1 : 0
        scale: modalVisible ? 1 : 0.9

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            propagateComposedEvents: false
            onClicked: mouse => {
                mouse.accepted = true;
            }
            onWheel: wheel => {
                wheel.accepted = true;
            }
            onPositionChanged: mouse => {
                mouse.accepted = true;
            }
        }

        Column {
            id: contentColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM

                DankIcon {
                    name: root.node ? AudioService.sinkIcon(root.node) : "speaker"
                    size: Theme.iconSize + 4
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXXS

                    StyledText {
                        text: root.node ? AudioService.displayName(root.node) : ""
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }

                    StyledText {
                        text: I18n.tr("Port Selection", "audio port selector modal subtitle")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.outlineLight
            }

            StyledText {
                text: {
                    if (root.isLoading)
                        return I18n.tr("Loading ports...", "audio port selector loading state");
                    if (root.availablePorts.length === 0)
                        return I18n.tr("No ports found", "audio port selector empty state");
                    return I18n.tr("Current: %1", "audio port selector active port label, %1 is the port name").arg(root.portDescription(root.currentPort));
                }
                font.pixelSize: Theme.fontSizeSmall
                color: root.isLoading ? Theme.primary : Theme.surfaceTextMedium
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
                width: parent.width
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS
                visible: root.availablePorts.length > 0

                Repeater {
                    model: root.availablePorts

                    Rectangle {
                        required property var modelData

                        readonly property bool isCurrent: modelData.name === root.currentPort
                        readonly property bool unavailable: modelData.availability === "no"

                        width: parent.width
                        height: 48
                        radius: Theme.cornerRadius
                        opacity: unavailable ? 0.45 : 1
                        color: {
                            if (isCurrent)
                                return Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency);
                            else if (portMouseArea.containsMouse)
                                return Theme.surfaceHover;
                            else
                                return "transparent";
                        }
                        border.color: "transparent"
                        border.width: 0

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.right: portCheck.left
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXXS

                            StyledText {
                                text: modelData.description
                                font.pixelSize: Theme.fontSizeMedium
                                color: isCurrent ? Theme.primary : Theme.surfaceText
                                font.weight: isCurrent ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            StyledText {
                                text: {
                                    if (modelData.availability === "no")
                                        return I18n.tr("Unavailable", "audio port availability status");
                                    if (modelData.availability === "yes")
                                        return I18n.tr("Available", "audio port availability status");
                                    return "";
                                }
                                visible: text.length > 0
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceTextMedium
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        DankIcon {
                            id: portCheck
                            name: "check"
                            size: Theme.iconSize - 4
                            color: Theme.primary
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            visible: isCurrent
                        }

                        DankRipple {
                            id: portRipple
                            cornerRadius: parent.radius
                        }

                        MouseArea {
                            id: portMouseArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !isCurrent && !unavailable && !root.isLoading
                            onPressed: mouse => portRipple.trigger(mouse.x, mouse.y)
                            onClicked: {
                                root.selectPort(modelData.name);
                            }
                        }
                    }
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
                onRunningChanged: {
                    if (!running && !root.modalVisible) {
                        root.visible = false;
                        root.node = null;
                    }
                }
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
    }
}
