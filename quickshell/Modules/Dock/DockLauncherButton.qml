import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root
    required property var options

    clip: false
    property var dockApps: null
    property bool isVertical: root.options.position === SettingsData.Position.Left || root.options.position === SettingsData.Position.Right
    property bool isHovered: mouseArea.containsMouse
    property bool showTooltip: mouseArea.containsMouse
    property real actualIconSize: 40

    readonly property string tooltipText: I18n.tr("Applications")

    readonly property var effectiveLogoColor: {
        const override = root.options.launcherLogoColorOverride;
        if (override === "primary")
            return Theme.primary;
        if (override === "surface")
            return Theme.surfaceText;
        return override;
    }

    function activate() {
        PopoutService.toggleDankLauncherV2();
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: root.activate()
    }

    property real indicatorLane: 0
    readonly property real laneOffset: (root.options.position === SettingsData.Position.Bottom || root.options.position === SettingsData.Position.Right ? -1 : 1) * root.indicatorLane / 2
    readonly property real hoverAnimOffset: hoverBounce.offset

    DockHoverBounce {
        id: hoverBounce
        hovered: root.isHovered
        suppressed: mouseArea.pressed
        barHosted: root.dockApps?.barHosted ?? false
        position: root.options.position
        distance: root.actualIconSize
    }

    Item {
        id: visualContent
        anchors.fill: parent

        transform: Translate {
            x: isVertical ? hoverAnimOffset : 0
            y: isVertical ? 0 : hoverAnimOffset
        }

        Item {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.isVertical ? root.laneOffset : 0
            anchors.verticalCenterOffset: root.isVertical ? 0 : root.laneOffset
            width: actualIconSize
            height: actualIconSize
            scale: root.options.enlargeOnHover && root.isHovered ? (root.options.enlargePercentage ?? 125) / 100 : 1

            LauncherLogo {
                anchors.centerIn: parent
                mode: root.options.launcherLogoMode
                size: actualIconSize + root.options.launcherLogoSizeOffset
                appsIconSize: actualIconSize - 4
                appsIconColor: Theme.widgetIconColor
                colorOverride: effectiveLogoColor
                brightness: root.options.launcherLogoBrightness
                contrast: root.options.launcherLogoContrast
                customPath: root.options.launcherLogoCustomPath
            }
        }
    }
}
