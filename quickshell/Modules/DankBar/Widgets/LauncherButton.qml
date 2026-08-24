import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property bool isActive: false
    property var hyprlandOverviewLoader: null

    content: Component {
        Item {
            implicitWidth: root.widgetThickness - root.horizontalPadding * 2
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2

            LauncherLogo {
                anchors.centerIn: parent
                mode: SettingsData.launcherLogoMode
                size: Theme.barIconSize(root.barThickness, SettingsData.launcherLogoSizeOffset, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                appsIconSize: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                appsIconColor: Theme.widgetIconColor
                colorOverride: Theme.effectiveLogoColor
                brightness: SettingsData.launcherLogoBrightness
                contrast: SettingsData.launcherLogoContrast
                customPath: SettingsData.launcherLogoCustomPath
            }
        }
    }

    onRightClicked: {
        if (CompositorService.isNiri) {
            NiriService.toggleOverview();
        } else if (root.hyprlandOverviewLoader?.item) {
            root.hyprlandOverviewLoader.item.overviewOpen = !root.hyprlandOverviewLoader.item.overviewOpen;
        }
    }
}
