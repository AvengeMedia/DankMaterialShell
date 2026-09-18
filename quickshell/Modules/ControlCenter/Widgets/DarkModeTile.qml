import QtQuick
import qs.Common

CcTile {

    iconName: "contrast"
    iconRotation: SessionData.isLightMode ? 180 : 0
    title: {
        if (SettingsData.matugenSmartMode && Theme.currentTheme === Theme.dynamic)
            return SessionData.isLightMode ? I18n.tr("Auto (Light Mode)", "dark mode toggle label when matugen smart mode resolved light") : I18n.tr("Auto (Dark Mode)", "dark mode toggle label when matugen smart mode resolved dark");
        return I18n.tr("Dark mode");
    }
    active: !SessionData.isLightMode

    onClicked: {
        const newMode = !SessionData.isLightMode;
        Theme.screenTransition();
        Theme.setLightMode(newMode);
    }
}
