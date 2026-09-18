pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.DankBar
import qs.Widgets

Row {
    id: root

    property bool dockPlacement: false
    property bool widgetStyle: false
    property var choices: barModes
    property string selectedKey: activeBarMode
    signal selected(string key)
    onSelected: key => {
        if (!dockPlacement && !widgetStyle)
            applyBarMode(key);
    }

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
    readonly property real cardHeightRatio: 7.5
    readonly property real previewWidthRatio: 2.9
    readonly property real previewAspect: 0.62
    readonly property real previewStripRatio: 0.55
    readonly property real previewIslandRatio: 0.42
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
        model: root.choices

        Rectangle {
            id: modeCard
            required property var modelData
            enabled: modelData.enabled ?? true
            opacity: enabled ? 1 : SettingsMetrics.disabledOpacity

            readonly property bool isActive: root.selectedKey === modelData.key

            width: (root.width - root.spacing * (root.choices.length - 1)) / Math.max(1, root.choices.length)
            height: Math.round(Theme.fontSizeMedium * root.cardHeightRatio)
            radius: Theme.cornerRadius
            color: Theme.floatingWindowNestedSurface
            border.width: isActive ? Theme.outlineWidthFocused : Theme.outlineWidth
            border.color: isActive ? Theme.primary : Theme.outlineMedium

            activeFocusOnTab: true
            Accessible.role: Accessible.RadioButton
            Accessible.name: modelData.label
            Accessible.checked: isActive
            Accessible.onPressAction: root.selected(modelData.key)
            Keys.onSpacePressed: root.selected(modelData.key)
            Keys.onReturnPressed: root.selected(modelData.key)

            FocusRing {}

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.primary
                opacity: modeMouse.containsMouse ? Theme.stateLayerHover : 0
            }

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingS

                Rectangle {
                    id: screenPreview
                    readonly property real edgePad: Math.max(2, Math.round(width * 0.045))
                    readonly property real stripSize: Math.round(width * 0.11)

                    width: Math.round(Theme.iconSize * root.previewWidthRatio)
                    height: Math.round(width * root.previewAspect)
                    radius: Theme.spacingXS
                    color: Theme.chipSurface
                    border.width: Theme.outlineWidth
                    border.color: Theme.outline
                    anchors.horizontalCenter: parent.horizontalCenter

                    BarSegment {
                        visible: root.widgetStyle
                        anchors.centerIn: parent
                        scale: (screenPreview.width - screenPreview.edgePad * 2 - Theme.spacingS) / (Theme.iconSizeLarge * 3 + Theme.spacingXS * 2)
                        spacing: modeCard.modelData.key === "segments" ? BarMetrics.segmentGap : Theme.spacingXS

                        Repeater {
                            model: 3
                            BarPillSurface {
                                required property int index
                                width: Theme.iconSizeLarge
                                height: Theme.iconSizeLarge
                                thickness: Theme.iconSizeLarge
                                style: modeCard.modelData.key
                                joinedStart: style === "segments" && index > 0
                                joinedEnd: style === "segments" && index < 2
                                color: index === 1 ? Theme.primary : Theme.primaryContainer
                            }
                        }
                    }

                    Rectangle {
                        readonly property int edge: Number(modeCard.modelData.key)
                        readonly property bool vertical: edge === SettingsData.Position.Left || edge === SettingsData.Position.Right
                        visible: root.dockPlacement
                        x: edge === SettingsData.Position.Right ? parent.width - width - screenPreview.edgePad : screenPreview.edgePad
                        y: edge === SettingsData.Position.Bottom ? parent.height - height - screenPreview.edgePad : screenPreview.edgePad
                        width: vertical ? screenPreview.stripSize : parent.width - screenPreview.edgePad * 2
                        height: vertical ? parent.height - screenPreview.edgePad * 2 : screenPreview.stripSize
                        radius: Theme.fullRadius(width, height)
                        color: Theme.primary
                    }

                    Rectangle {
                        visible: !root.widgetStyle && !root.dockPlacement && modeCard.modelData.key === "standard"
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: screenPreview.edgePad
                        height: screenPreview.stripSize
                        radius: Theme.fullRadius(width, height)
                        color: Theme.primary
                    }

                    Rectangle {
                        visible: !root.widgetStyle && modeCard.modelData.key === "frame"
                        anchors.fill: parent
                        anchors.margins: screenPreview.edgePad
                        radius: screenPreview.radius
                        color: "transparent"
                        border.width: Math.max(Theme.outlineWidthFocused, Math.round(screenPreview.stripSize * root.previewStripRatio))
                        border.color: Theme.primary
                    }

                    Rectangle {
                        visible: !root.widgetStyle && modeCard.modelData.key === "frame"
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: screenPreview.edgePad
                        height: screenPreview.stripSize
                        radius: screenPreview.radius
                        color: Theme.primary
                    }

                    Rectangle {
                        visible: !root.widgetStyle && modeCard.modelData.key === "island"
                        anchors.top: parent.top
                        anchors.topMargin: screenPreview.edgePad
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.round(parent.width * root.previewIslandRatio)
                        height: screenPreview.stripSize
                        radius: Theme.fullRadius(width, height)
                        color: Theme.primary
                    }
                }

                StyledText {
                    text: modeCard.modelData.label
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    color: modeCard.isActive ? Theme.primary : Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            MouseArea {
                id: modeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selected(modeCard.modelData.key)
            }
        }
    }
}
