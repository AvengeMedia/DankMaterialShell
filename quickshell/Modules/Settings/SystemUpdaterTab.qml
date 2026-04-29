import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    readonly property var intervalOptions: [
        {
            label: I18n.tr("Every 15 minutes"),
            seconds: 900
        },
        {
            label: I18n.tr("Every 30 minutes"),
            seconds: 1800
        },
        {
            label: I18n.tr("Every hour"),
            seconds: 3600
        },
        {
            label: I18n.tr("Every 4 hours"),
            seconds: 14400
        },
        {
            label: I18n.tr("Once a day"),
            seconds: 86400
        }
    ]

    function intervalLabelFor(seconds) {
        for (const opt of intervalOptions) {
            if (opt.seconds === seconds) {
                return opt.label;
            }
        }
        return intervalOptions[1].label;
    }

    function intervalSecondsFor(label) {
        for (const opt of intervalOptions) {
            if (opt.label === label) {
                return opt.seconds;
            }
        }
        return 1800;
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            topPadding: 4
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                width: parent.width
                iconName: "refresh"
                title: I18n.tr("System Updater")
                settingKey: "systemUpdater"

                StyledText {
                    width: parent.width - Theme.spacingM * 2
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    visible: SystemUpdateService.backends.length > 0
                    text: {
                        const names = (SystemUpdateService.backends || []).map(b => b.displayName).join(", ");
                        return I18n.tr("Detected backends: %1").arg(names);
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                SettingsDropdownRow {
                    text: I18n.tr("Check interval")
                    description: I18n.tr("How often the server polls for new updates.")
                    options: root.intervalOptions.map(o => o.label)
                    currentValue: root.intervalLabelFor(SettingsData.updaterIntervalSeconds)
                    onValueChanged: label => {
                        const secs = root.intervalSecondsFor(label);
                        SettingsData.set("updaterIntervalSeconds", secs);
                        SystemUpdateService.setInterval(secs);
                    }
                }

                SettingsToggleRow {
                    text: I18n.tr("Include Flatpak updates")
                    description: I18n.tr("Apply Flatpak updates alongside system updates when running 'Update All'.")
                    visible: (SystemUpdateService.backends || []).some(b => b.repo === "flatpak")
                    checked: SettingsData.updaterIncludeFlatpak
                    onToggled: checked => SettingsData.set("updaterIncludeFlatpak", checked)
                }

                SettingsToggleRow {
                    text: I18n.tr("Include AUR updates")
                    description: I18n.tr("Run paru/yay with AUR enabled when 'Update All' is clicked.")
                    visible: (SystemUpdateService.backends || []).some(b => b.id === "paru" || b.id === "yay")
                    checked: SettingsData.updaterAllowAUR
                    onToggled: checked => SettingsData.set("updaterAllowAUR", checked)
                }

                TerminalPickerRow {}
            }

            SettingsCard {
                width: parent.width
                iconName: "tune"
                title: I18n.tr("Advanced")
                settingKey: "systemUpdaterAdvanced"

                SettingsToggleRow {
                    text: I18n.tr("Use custom command")
                    description: I18n.tr("Open a terminal and run a custom command instead of the in-shell upgrade flow.")
                    checked: SettingsData.updaterUseCustomCommand
                    onToggled: checked => {
                        if (!checked) {
                            updaterCustomCommand.text = "";
                            updaterTerminalCustomClass.text = "";
                            SettingsData.set("updaterCustomCommand", "");
                            SettingsData.set("updaterTerminalAdditionalParams", "");
                        }
                        SettingsData.set("updaterUseCustomCommand", checked);
                    }
                }

                Rectangle {
                    width: parent.width - Theme.spacingM * 2
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    visible: SettingsData.updaterUseCustomCommand
                    height: warnText.implicitHeight + Theme.spacingS * 2
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)

                    StyledText {
                        id: warnText
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        text: I18n.tr("Custom command and terminal params are split on whitespace; paths with spaces will break.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.warning
                        wrapMode: Text.WordWrap
                    }
                }

                FocusScope {
                    width: parent.width - Theme.spacingM * 2
                    height: customCommandColumn.implicitHeight
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    visible: SettingsData.updaterUseCustomCommand

                    Column {
                        id: customCommandColumn
                        width: parent.width
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("Custom update command")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        DankTextField {
                            id: updaterCustomCommand
                            width: parent.width
                            placeholderText: "topgrade --no-retry"
                            backgroundColor: Theme.surfaceContainerHighest
                            normalBorderColor: Theme.outlineMedium
                            focusedBorderColor: Theme.primary

                            Component.onCompleted: {
                                if (SettingsData.updaterCustomCommand) {
                                    text = SettingsData.updaterCustomCommand;
                                }
                            }

                            onTextEdited: SettingsData.set("updaterCustomCommand", text.trim())

                            MouseArea {
                                anchors.fill: parent
                                onPressed: mouse => {
                                    updaterCustomCommand.forceActiveFocus();
                                    mouse.accepted = false;
                                }
                            }
                        }
                    }
                }

                FocusScope {
                    width: parent.width - Theme.spacingM * 2
                    height: terminalParamsColumn.implicitHeight
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    visible: SettingsData.updaterUseCustomCommand

                    Column {
                        id: terminalParamsColumn
                        width: parent.width
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("Terminal additional parameters")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        DankTextField {
                            id: updaterTerminalCustomClass
                            width: parent.width
                            placeholderText: "-T updater"
                            backgroundColor: Theme.surfaceContainerHighest
                            normalBorderColor: Theme.outlineMedium
                            focusedBorderColor: Theme.primary

                            Component.onCompleted: {
                                if (SettingsData.updaterTerminalAdditionalParams) {
                                    text = SettingsData.updaterTerminalAdditionalParams;
                                }
                            }

                            onTextEdited: SettingsData.set("updaterTerminalAdditionalParams", text.trim())

                            MouseArea {
                                anchors.fill: parent
                                onPressed: mouse => {
                                    updaterTerminalCustomClass.forceActiveFocus();
                                    mouse.accepted = false;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
