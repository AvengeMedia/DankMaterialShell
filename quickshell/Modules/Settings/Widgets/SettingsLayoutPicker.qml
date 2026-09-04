pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

Row {
    id: root

    readonly property var barModes: [
        {
            "key": "standard",
            "label": I18n.tr("Standard")
        },
        {
            "key": "frame",
            "label": I18n.tr("Frame")
        },
        {
            "key": "island",
            "label": I18n.tr("Island")
        }
    ]
    // Frame is a shell-wide surface; standard vs island is per bar instance.
    readonly property var targetConfig: {
        SettingsData.barConfigs;
        SettingsUiState.selectedBarId;
        const configs = SettingsData.barConfigs || [];
        return SettingsData.getBarConfig(SettingsUiState.selectedBarId) ?? configs.find(cfg => cfg.enabled) ?? configs[0] ?? null;
    }
    readonly property string activeBarMode: SettingsData.frameEnabled ? "frame" : (SettingsData.isIslandBarConfig(root.targetConfig) ? "island" : "standard")

    function applyBarMode(mode) {
        const target = root.targetConfig;
        switch (mode) {
        case "frame":
            if (SettingsData.frameEnabled)
                return;
            SettingsData.set("frameEnabled", true);
            return;
        case "island":
            if (!target)
                return;
            if (SettingsData.frameEnabled)
                SettingsData.set("frameEnabled", false);
            SettingsData.setBarIsland(target.id, true);
            return;
        default:
            if (SettingsData.frameEnabled)
                SettingsData.set("frameEnabled", false);
            if (target)
                SettingsData.setBarIsland(target.id, false);
            return;
        }
    }

    width: parent?.width ?? 0
    spacing: Theme.spacingS

    Repeater {
        model: root.barModes

        Rectangle {
            id: modeCard
            required property var modelData
            readonly property bool isActive: root.activeBarMode === modelData.key

            width: (root.width - Theme.spacingS * 2) / 3
            height: Math.round(Theme.fontSizeMedium * 7.5)
            radius: Theme.cornerRadius
            color: Theme.floatingWindowNestedSurface
            border.width: isActive ? 2 : 1
            border.color: isActive ? Theme.primary : Theme.outlineMedium

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.primary
                opacity: modeMouse.containsMouse ? 0.12 : 0
            }

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingS

                Rectangle {
                    id: screenPreview
                    readonly property real edgePad: Math.max(2, Math.round(width * 0.045))
                    readonly property real stripSize: Math.round(width * 0.11)

                    width: Math.round(Theme.iconSize * 2.9)
                    height: Math.round(width * 0.62)
                    radius: Theme.spacingXS
                    color: Theme.surfaceContainerHighest
                    border.width: 1
                    border.color: Theme.outline
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        visible: modeCard.modelData.key === "standard"
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: screenPreview.edgePad
                        height: screenPreview.stripSize
                        radius: height / 2
                        color: Theme.primary
                    }

                    Rectangle {
                        visible: modeCard.modelData.key === "frame"
                        anchors.fill: parent
                        anchors.margins: screenPreview.edgePad
                        radius: screenPreview.radius
                        color: "transparent"
                        border.width: Math.max(2, Math.round(screenPreview.stripSize * 0.55))
                        border.color: Theme.primary
                    }

                    Rectangle {
                        visible: modeCard.modelData.key === "frame"
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: screenPreview.edgePad
                        height: screenPreview.stripSize
                        radius: screenPreview.radius
                        color: Theme.primary
                    }

                    Rectangle {
                        visible: modeCard.modelData.key === "island"
                        anchors.top: parent.top
                        anchors.topMargin: screenPreview.edgePad
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.round(parent.width * 0.42)
                        height: screenPreview.stripSize
                        radius: height / 2
                        color: Theme.primary
                    }
                }

                StyledText {
                    text: modeCard.modelData.label
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: modeCard.isActive ? Theme.primary : Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            MouseArea {
                id: modeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.applyBarMode(modeCard.modelData.key)
            }
        }
    }
}
