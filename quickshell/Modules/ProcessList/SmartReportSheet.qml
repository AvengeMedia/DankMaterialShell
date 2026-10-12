import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets
import qs.Modules.ControlCenter.Widgets
import qs.DCommon.Widgets
import "Drives.js" as Drives

CcSheetDialog {
    id: root

    // "running" | "done" | "error" | "missing"
    property string state_: "running"
    property var sections: []
    property string errorText: ""
    property int _gen: 0

    readonly property var sectionTitles: ({
            "health": I18n.tr("Health"),
            "errors": I18n.tr("Errors"),
            // smartctl's own JSON names; no translatable label
            "attributes": "ata_smart_attributes (value / worst / thresh / raw)",
            "selftest": "self_test_log"
        })

    // Covers every way of closing, so a running report can't write into a closed sheet
    onShownChanged: {
        if (!shown) {
            _gen++;
        }
    }

    function open(drive) {
        title = drive.model || drive.name || drive.device;
        subtitle = drive.device;
        const gen = ++_gen;
        sections = [];
        errorText = "";
        if (!DriveService.smartctlPath) {
            state_ = "missing";
            present();
            return;
        }
        state_ = "running";
        present();
        const started = DriveService.fullReport(drive, (exitCode, stdout, stderr) => {
            if (gen !== _gen)
                return;
            if (exitCode === 126) {
                dismiss();
                return;
            }
            const r = Drives.parseReport(stdout);
            if (exitCode === 127 || (!r.sections.length && r.error)) {
                errorText = stderr || r.error || I18n.tr("Error");
                state_ = "error";
                return;
            }
            sections = r.sections;
            errorText = r.error;
            state_ = "done";
        });
        if (!started) {
            errorText = I18n.tr("Error");
            state_ = DriveService.smartctlPath ? "error" : "missing";
        }
    }

    iconName: "monitor_heart"
    showScrollBar: false

    DLoadingIndicator {
        visible: root.state_ === "running"
        anchors.horizontalCenter: parent.horizontalCenter
    }

    SettingsNoteRow {
        width: parent.width
        visible: root.state_ === "missing"
        text: I18n.tr("smartmontools is required to read SMART data")
    }

    SettingsNoteRow {
        width: parent.width
        visible: root.state_ === "done" && root.sections.length === 0 && root.errorText === ""
        text: I18n.tr("No results")
    }

    DButton {
        visible: root.state_ === "missing" && DriveService.installCommand !== ""
        text: I18n.tr("Install")
        onClicked: DriveService.install()
    }

    SettingsNoteRow {
        width: parent.width
        visible: (root.state_ === "error" || root.state_ === "done") && root.errorText !== ""
        text: root.errorText
        monospace: true
        maxHeight: 160
    }

    Repeater {
        model: root.state_ === "done" ? root.sections : []

        SettingsGroup {
            id: group
            required property var modelData
            width: parent.width
            slotColor: Theme.chipSurface

            Item {
                width: group.width
                height: heading.implicitHeight + Theme.spacingS * 2

                StyledText {
                    id: heading
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.sectionTitles[group.modelData.id] || group.modelData.id
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    font.family: group.modelData.id === "attributes" || group.modelData.id === "selftest" ? Theme.monoFontFamily : Theme.fontFamily
                    color: Theme.surfaceVariantText
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }
            }

            Repeater {
                model: group.modelData.rows

                Item {
                    id: line
                    required property var modelData
                    width: group.width
                    height: Math.max(key.implicitHeight, val.implicitHeight) + Theme.spacingS * 2

                    StyledText {
                        id: key
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.45
                        text: line.modelData.key
                        font.family: Theme.monoFontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        wrapMode: Text.NoWrap
                        elide: Text.ElideRight
                    }

                    StyledText {
                        id: val
                        anchors.left: key.right
                        anchors.right: parent.right
                        anchors.margins: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        text: line.modelData.value
                        font.pixelSize: Theme.fontSizeSmall
                        font.features: {
                            "tnum": 1
                        }
                        color: Theme.surfaceVariantText
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
