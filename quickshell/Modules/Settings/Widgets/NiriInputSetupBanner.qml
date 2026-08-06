import QtCore
import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "../../../Common/ConfigIncludeResolve.js" as ConfigIncludeResolve

StyledRect {
    id: root

    property var includeStatus: ({
            "exists": false,
            "included": false,
            "configFormat": "",
            "readOnly": false
        })
    property bool checking: false
    property bool fixing: false

    readonly property bool showSetup: !includeStatus.included

    function getInputConfigPaths() {
        if (CompositorService.compositor !== "niri")
            return null;

        const configDir = Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation));
        return {
            "configFile": configDir + "/niri/config.kdl",
            "layoutFile": configDir + "/niri/dms/input.kdl",
            "grepPattern": 'include.*"dms/input.kdl"',
            "includeLine": 'include "dms/input.kdl"'
        };
    }

    function checkIncludeStatus() {
        if (CompositorService.compositor !== "niri") {
            includeStatus = {
                "exists": false,
                "included": false,
                "configFormat": "",
                "readOnly": false
            };
            return;
        }

        checking = true;
        Proc.runCommand("check-input-include", [Proc.dmsBin, "config", "resolve-include", "niri", "input.kdl"], (output, exitCode) => {
            checking = false;
            if (exitCode !== 0) {
                includeStatus = {
                    "exists": false,
                    "included": false,
                    "configFormat": "",
                    "readOnly": false
                };
                return;
            }
            try {
                includeStatus = JSON.parse(output.trim());
            } catch (e) {
                includeStatus = {
                    "exists": false,
                    "included": false,
                    "configFormat": "",
                    "readOnly": false
                };
            }
        });
    }

    function fixInclude() {
        const paths = getInputConfigPaths();
        if (!paths)
            return;

        fixing = true;
        const unixTime = Math.floor(Date.now() / 1000);
        const backupFile = paths.configFile + ".backup" + unixTime;
        const script = ConfigIncludeResolve.buildRepairScript({
            configFile: paths.configFile,
            backupFile: backupFile,
            fragmentFile: paths.layoutFile,
            grepPattern: paths.grepPattern,
            includeLine: paths.includeLine
        });
        Proc.runCommand("fix-input-include", ["sh", "-c", script], (output, exitCode) => {
            fixing = false;
            if (exitCode !== 0)
                return;
            checkIncludeStatus();
            SettingsData.updateCompositorInput();
        });
    }

    Component.onCompleted: {
        if (CompositorService.isNiri) {
            checkIncludeStatus();
        }
    }

    height: warningContent.implicitHeight + Theme.spacingL * 2
    radius: Theme.cornerRadius
    color: showSetup ? Theme.withAlpha(Theme.primary, 0.15) : Theme.withAlpha(Theme.primary, 0)
    border.color: showSetup ? Theme.withAlpha(Theme.primary, 0.3) : Theme.withAlpha(Theme.primary, 0)
    border.width: 1
    visible: showSetup && !checking && CompositorService.isNiri

    Row {
        id: warningContent
        anchors.fill: parent
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingM

        DankIcon {
            name: "warning"
            size: Theme.iconSize
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            width: parent.width - Theme.iconSize - (fixButton.visible ? fixButton.width + Theme.spacingM : 0) - Theme.spacingM
            spacing: Theme.spacingXS
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: I18n.tr("First Time Setup")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.primary
                width: parent.width
                horizontalAlignment: Text.AlignLeft
            }

            StyledText {
                text: I18n.tr("Click 'Setup' to create %1 and add include to your compositor config.").arg("dms/input")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
                horizontalAlignment: Text.AlignLeft
            }
        }

        DankButton {
            id: fixButton
            visible: root.showSetup
            text: root.fixing ? I18n.tr("Setting up...") : I18n.tr("Setup")
            backgroundColor: Theme.primary
            textColor: Theme.primaryText
            enabled: !root.fixing
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.fixInclude()
        }
    }
}
