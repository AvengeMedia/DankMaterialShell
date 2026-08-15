import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

// AuthHudPill: top-center status pill for face authentication that DMS cannot
// see in-process (terminal sudo, doas, pkexec). It subscribes to the Gaze
// daemon's scrubbed auth-phase broadcast through the `gaze-observe` helper and
// shows the active claim's phase while it runs.
//
// The pill only renders elevation surfaces: the lock screen and polkit modal
// render their own in-process feedback, and the greeter owns its surface.
PanelWindow {
    id: root
    readonly property var log: Log.scoped("AuthHudPill")

    WlrLayershell.namespace: "dms:authhud"
    WlrLayershell.layer: LayerShell.fromEnv("DMS_OSD_LAYER", WlrLayer.Overlay, {
        "allow": ["top", "overlay"],
        "invalidLayer": WlrLayer.Overlay,
        "label": "OSDs"
    })
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    screen: modelData
    visible: root.shouldShow
    color: "transparent"

    readonly property real dpr: CompositorService.getScreenScale(screen)

    property bool observerReady: false
    property string phase: "waiting"
    property string rgbStatus: "unused"
    property string irStatus: "unused"
    property string surface: ""

    readonly property bool shouldShow: observerReady && root.surface === "elevation" && root.phase !== "idle"

    readonly property string phaseText: {
        switch (root.phase) {
        case "matched":
            return I18n.tr("Face matched");
        case "not-recognized":
            return I18n.tr("Face not recognized");
        case "unavailable":
            return I18n.tr("Face auth unavailable");
        default:
            return I18n.tr("Waiting for face");
        }
    }

    readonly property string phaseDetail: {
        if (root.phase !== "waiting")
            return "";
        const status = root.rgbStatus === "unused" ? root.irStatus : root.rgbStatus;
        switch (status) {
        case "no-face":
            return I18n.tr("Look at the camera");
        case "too-dark":
            return I18n.tr("Need more light");
        case "too-far":
            return I18n.tr("Come closer");
        case "too-close":
            return I18n.tr("Back up");
        case "not-centered":
        case "clipped":
            return I18n.tr("Center your face");
        default:
            return "";
        }
    }

    readonly property color phaseColor: {
        switch (root.phase) {
        case "matched":
            return Theme.success;
        case "not-recognized":
        case "unavailable":
            return Theme.error;
        default:
            return Theme.primary;
        }
    }

    // --- observer process -------------------------------------------------

    property string outputBuffer: ""
    property int outputConsumed: 0

    function handleObserverLine(line: string): void {
        const fields = line.trim().split(" ");
        const values = {};
        for (const field of fields) {
            const eq = field.indexOf("=");
            if (eq <= 0)
                continue;
            values[field.substring(0, eq)] = field.substring(eq + 1);
        }
        if (values["phase"] !== undefined)
            root.phase = values["phase"];
        if (values["rgb"] !== undefined)
            root.rgbStatus = values["rgb"];
        if (values["ir"] !== undefined)
            root.irStatus = values["ir"];
        if (values["surface"] !== undefined)
            root.surface = values["surface"];
        if (values["ready"] !== undefined)
            root.observerReady = true;
    }

    function drainObserverOutput(): void {
        const text = observerOutput.text;
        if (text.length > root.outputConsumed) {
            root.outputBuffer += text.substring(root.outputConsumed);
            root.outputConsumed = text.length;
        }
        let idx = -1;
        while ((idx = root.outputBuffer.indexOf("\n")) >= 0) {
            const line = root.outputBuffer.substring(0, idx);
            root.outputBuffer = root.outputBuffer.substring(idx + 1);
            root.handleObserverLine(line);
        }
    }

    Process {
        id: observerProcess

        command: ["gaze-observe"]
        running: false

        stdout: StdioCollector {
            id: observerOutput

            waitForEnd: false
            onDataChanged: root.drainObserverOutput()
        }

        onRunningChanged: {
            if (!observerProcess.running) {
                root.observerReady = false;
                root.phase = "waiting";
                root.rgbStatus = "unused";
                root.irStatus = "unused";
                root.surface = "";
                retryTimer.restart();
            }
        }
    }

    Timer {
        id: retryTimer

        interval: 10000
        repeat: false
        onTriggered: observerProcess.running = true
    }

    Component.onCompleted: observerProcess.running = true

    // --- presentation ------------------------------------------------------

    Rectangle {
        id: pill

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.px(Theme.spacingL, root.dpr)
        width: pillRow.implicitWidth + Theme.spacingL * 2
        height: pillRow.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        border.color: root.phaseColor
        border.width: 2
        opacity: root.shouldShow ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        RowLayout {
            id: pillRow

            anchors.centerIn: parent
            spacing: Theme.spacingS

            DankIcon {
                name: "face"
                size: Theme.iconSizeSmall
                color: root.phaseColor
            }

            Column {
                spacing: 2
                Layout.fillWidth: true

                StyledText {
                    text: root.phaseText
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                }

                StyledText {
                    text: root.phaseDetail
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    visible: text !== ""
                }
            }
        }
    }
}
