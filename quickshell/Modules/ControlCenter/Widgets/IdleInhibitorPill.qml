import QtQuick
import qs.Common
import qs.Modules.ControlCenter.Widgets
import qs.Services
import "../../../Common/Format.js" as Format

CompoundPill {
    id: root

    iconName: SessionService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"
    iconColor: SessionService.idleInhibited ? Theme.primary : Theme.surfaceText
    primaryText: I18n.tr("Keep Awake")
    isActive: SessionService.idleInhibited

    secondaryText: {
        if (!SessionService.idleInhibited)
            return I18n.tr("Off");
        if (SessionData.idleInhibitedUntil <= 0)
            return I18n.tr("On");
        return I18n.tr("Until %1").arg(Format.formatUntil(SessionData.idleInhibitedUntil, SettingsData.use24HourClock));
    }

    onToggled: SessionService.toggleIdleInhibit()
}
