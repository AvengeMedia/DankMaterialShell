import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets
import qs.Modules.ControlCenter.Widgets
import qs.Modules.DankDash

CcSheetDialog {
    id: root

    property string appId: ""
    readonly property int minutes: WellbeingService.appLimitMinutes(appId)

    function presentFor(id) {
        appId = id;
        present();
    }

    panelWidth: DashMetrics.optionSheetWidth
    iconName: "timer"
    title: WellbeingService.appName(appId)
    subtitle: I18n.tr("Daily limit")
    showScrollBar: false

    SettingsGroup {
        width: parent.width
        slotColor: Theme.chipSurface

        SettingsRow {
            title: I18n.tr("Daily limit")
            subtitle: root.minutes > 0 ? I18n.tr("Notifies when today's use of this app passes the limit") : I18n.tr("Off")

            DurationSteppers {
                anchors.verticalCenter: parent.verticalCenter
                minutes: root.minutes
                onCommitted: next => WellbeingService.setAppLimit(root.appId, next)
            }
        }
    }
}
