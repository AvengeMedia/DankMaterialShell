import QtQuick
import qs.Common

CcTileActions {
    signal selected(int minutes)

    actions: [15, 30, 60, 120, 0].map(minutes => ({
                text: minutes === 0 ? I18n.tr("Until I turn it off") : minutes < 60 ? I18n.tr("%1 min", "short duration chip, %1 is a number of minutes").arg(minutes) : I18n.duration(minutes * 60),
                icon: minutes === 0 ? "block" : "timer",
                trigger: () => selected(minutes)
            }))
}
