import QtQuick
import qs.Common
import qs.Modules.ControlCenter.Widgets

CompoundPill {
    id: root

    iconName: SessionData.doNotDisturb ? "do_not_disturb_on" : "do_not_disturb_off"
    iconColor: SessionData.doNotDisturb ? Theme.primary : Theme.surfaceText
    primaryText: I18n.tr("Do Not Disturb")
    isActive: SessionData.doNotDisturb

    secondaryText: {
        if (!SessionData.doNotDisturb)
            return I18n.tr("Off");
        if (SessionData.doNotDisturbUntil <= 0)
            return I18n.tr("On");
        const d = new Date(SessionData.doNotDisturbUntil);
        const use24h = (typeof SettingsData !== "undefined") ? SettingsData.use24HourClock : true;
        const pad = n => n < 10 ? "0" + n : "" + n;
        if (use24h)
            return I18n.tr("Until %1").arg(pad(d.getHours()) + ":" + pad(d.getMinutes()));
        const suffix = d.getHours() >= 12 ? "PM" : "AM";
        const h12 = ((d.getHours() + 11) % 12) + 1;
        return I18n.tr("Until %1").arg(h12 + ":" + pad(d.getMinutes()) + " " + suffix);
    }

    onToggled: SessionData.setDoNotDisturb(!SessionData.doNotDisturb)
}
