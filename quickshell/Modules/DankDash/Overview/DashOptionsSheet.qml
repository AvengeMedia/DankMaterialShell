import QtQuick
import qs.Services
import qs.Common
import qs.Widgets
import qs.Modules.Settings.Widgets
import qs.Modules.ControlCenter.Widgets
import qs.Modules.DankDash

CcSheetDialog {
    id: root

    property string entryId: ""

    readonly property var entry: DashRegistry.entry(entryId)
    readonly property var specs: DashRegistry.sheetOptionSpecs(entryId)

    function presentFor(id) {
        entryId = id;
        present();
    }

    panelWidth: DashMetrics.optionSheetWidth
    iconName: entry?.icon ?? "tune"
    title: entry?.text ?? ""
    subtitle: I18n.tr("Options")

    SettingsGroup {
        width: parent.width
        slotColor: Theme.chipSurface

        Repeater {
            model: root.specs

            DashOptionRow {
                required property var modelData

                entryId: root.entryId
                spec: modelData
            }
        }
    }

    SettingsNavRow {
        visible: root.entryId === "weather" || root.entryId === "media"
        width: parent.width
        title: root.entryId === "media" ? I18n.tr("Media player") : I18n.tr("Weather")
        iconName: "settings"
        onClicked: {
            root.dismiss();
            PopoutService.openSettingsWithTab(root.entryId === "media" ? "media_player" : "weather");
        }
    }

    DankButton {
        anchors.right: parent.right
        text: I18n.tr("Reset to default")
        iconName: "restart_alt"
        buttonHeight: Theme.buttonHeightXS
        backgroundColor: "transparent"
        textColor: Theme.primary
        enabled: DashRegistry.hasStoredOptions(root.entryId)
        onClicked: DashRegistry.resetOptions(root.entryId)
    }
}
