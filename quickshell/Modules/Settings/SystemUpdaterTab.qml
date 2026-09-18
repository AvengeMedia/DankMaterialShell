import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    readonly property var intervalOptions: [
        {
            label: I18n.tr("Every %1", "update check interval option, %1 is a duration such as 30 minutes").arg(I18n.duration(900)),
            seconds: 900
        },
        {
            label: I18n.tr("Every %1", "update check interval option, %1 is a duration such as 30 minutes").arg(I18n.duration(1800)),
            seconds: 1800
        },
        {
            label: I18n.tr("Every hour"),
            seconds: 3600
        },
        {
            label: I18n.tr("Every %1", "update check interval option, %1 is a duration such as 30 minutes").arg(I18n.duration(14400)),
            seconds: 14400
        },
        {
            label: I18n.tr("Once a day"),
            seconds: 86400
        }
    ]

    readonly property string customIntervalLabel: I18n.tr("Custom")
    property bool customIntervalSelected: false

    Component.onCompleted: {
        customIntervalSelected = !intervalOptions.some(o => o.seconds === SettingsData.updaterIntervalSeconds);
    }

    function intervalLabelFor(seconds) {
        for (const opt of intervalOptions) {
            if (opt.seconds === seconds) {
                return opt.label;
            }
        }
        return customIntervalLabel;
    }

    function intervalSecondsFor(label) {
        for (const opt of intervalOptions) {
            if (opt.label === label) {
                return opt.seconds;
            }
        }
        return 1800;
    }

    SettingsPage {
        id: mainColumn

        SettingsCard {
            width: parent.width
            settingKey: "systemUpdater"

            SettingsRow {
                visible: SystemUpdateService.backends.length > 0
                body: StyledText {
                    width: parent.width
                    text: {
                        const names = (SystemUpdateService.backends || []).map(b => b.displayName).join(", ");
                        return I18n.tr("Detected backends: %1", "system updater settings, %1 is a comma-separated list of package manager names").arg(names);
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }
            }

            SettingsDropdownRow {
                settingKey: "systemUpdaterCheckInterval"
                resetKeys: ["updaterIntervalSeconds"]
                resetByKeys: false
                onResetRequested: {
                    root.customIntervalSelected = false;
                    SettingsData.resetToDefault(["updaterIntervalSeconds"]);
                    SystemUpdateService.setInterval(SettingsData.updaterIntervalSeconds);
                }
                tags: ["interval", "poll", "frequency"]
                text: I18n.tr("Check interval")
                options: root.intervalOptions.map(o => o.label).concat([root.customIntervalLabel])
                currentValue: root.customIntervalSelected ? root.customIntervalLabel : root.intervalLabelFor(SettingsData.updaterIntervalSeconds)
                onValueChanged: label => {
                    if (label === root.customIntervalLabel) {
                        root.customIntervalSelected = true;
                        return;
                    }
                    root.customIntervalSelected = false;
                    const secs = root.intervalSecondsFor(label);
                    SettingsData.set("updaterIntervalSeconds", secs);
                    SystemUpdateService.setInterval(secs);
                }
            }

            SettingsTextFieldRow {
                id: customIntervalField
                leftIconName: "timer"
                visible: root.customIntervalSelected
                text: I18n.tr("Custom interval in minutes (minimum 5)")
                placeholderText: "30"
                value: Math.round(SettingsData.updaterIntervalSeconds / 60).toString()
                validator: IntValidator {
                    bottom: 5
                }
                onValueEdited: value => {
                    const minutes = parseInt(value, 10);
                    if (isNaN(minutes) || minutes < 5)
                        return;
                    const seconds = minutes * 60;
                    SettingsData.set("updaterIntervalSeconds", seconds);
                    SystemUpdateService.setInterval(seconds);
                }
            }

            SettingsToggleRow {
                settingKey: "systemUpdaterCheckOnStart"
                tags: ["startup", "check", "boot"]
                resetKeys: ["updaterCheckOnStart"]
                text: I18n.tr("Check on startup")
                checked: SettingsData.updaterCheckOnStart
                onToggled: checked => SettingsData.set("updaterCheckOnStart", checked)
            }

            SettingsToggleRow {
                settingKey: "systemUpdaterFlatpak"
                tags: ["flatpak", "include"]
                resetKeys: ["updaterIncludeFlatpak"]
                text: I18n.tr("Include Flatpak updates")
                visible: (SystemUpdateService.backends || []).some(b => b.repo === "flatpak")
                checked: SettingsData.updaterIncludeFlatpak
                onToggled: checked => SettingsData.set("updaterIncludeFlatpak", checked)
            }

            SettingsToggleRow {
                settingKey: "systemUpdaterAUR"
                tags: ["aur", "paru", "yay", "shelly"]
                resetKeys: ["updaterAllowAUR"]
                text: I18n.tr("Include AUR updates")
                visible: (SystemUpdateService.backends || []).some(b => ["paru", "yay", "shelly"].includes(b.id))
                checked: SettingsData.updaterAllowAUR
                onToggled: checked => SettingsData.set("updaterAllowAUR", checked)
            }

            SettingsToggleRow {
                settingKey: "systemUpdaterReopenAfterUpgrade"
                tags: ["reopen", "popout", "terminal", "upgrade"]
                resetKeys: ["updaterReopenAfterUpgrade"]
                text: I18n.tr("Reopen panel after update")
                visible: SystemUpdateService.useCustomCommand || (SystemUpdateService.backends || []).some(b => b.runsInTerminal === true)
                checked: SettingsData.updaterReopenAfterUpgrade
                onToggled: checked => SettingsData.set("updaterReopenAfterUpgrade", checked)
            }

            TerminalPickerRow {}
        }

        SettingsCard {
            id: ignoredPackagesCard
            width: parent.width
            iconName: "inventory_2"
            title: I18n.tr("Ignored packages")
            settingKey: "systemUpdaterIgnoredPackages"
            tags: ["system", "update", "package", "ignore"]

            property bool errorIsInvalidName: false

            function addIgnoredPackage() {
                const name = newIgnoredPackageField.value.trim();
                if (name === "") {
                    return;
                }
                errorIsInvalidName = !/^[A-Za-z0-9@._+:-]+$/.test(name);
                if (errorIsInvalidName) {
                    ignoredPackageError.visible = true;
                    return;
                }
                ignoredPackageError.visible = !SystemUpdateService.ignorePackage(name);
                if (ignoredPackageError.visible)
                    return;
                newIgnoredPackageField.value = "";
            }

            SettingsTextFieldRow {
                id: newIgnoredPackageField
                leftIconName: "inventory_2"
                text: I18n.tr("Name")
                description: {
                    if (SettingsData.updaterUseCustomCommand)
                        return I18n.tr("Ignored packages only apply to the built-in updater. Your custom command controls its own exclusions.");
                    if (SystemUpdateService.pkgManager === "shelly")
                        return I18n.tr("With Shelly, only Flatpak packages in the current update list can be ignored.");
                    return (SettingsData.updaterIgnoredPackages || []).length > 0 ? I18n.tr("Ignored packages are hidden from the updater and skipped by 'Update All'.") : I18n.tr("No packages ignored. Add one here or hover an update in the popout and click the hide button.");
                }
                placeholderText: I18n.tr("Package name (e.g., docker)")
                onAccepted: ignoredPackagesCard.addIgnoredPackage()
                onValueEdited: ignoredPackageError.visible = false

                actions: DankIconButton {
                    variant: "filled"
                    iconName: "add"
                    tooltipText: I18n.tr("Ignore package", "tooltip, exclude a package from system updates")
                    enabled: newIgnoredPackageField.value.trim() !== ""
                    onClicked: ignoredPackagesCard.addIgnoredPackage()
                }
            }

            SettingsRow {
                id: ignoredPackageError
                visible: false
                title: ignoredPackagesCard.errorIsInvalidName ? I18n.tr("Invalid package name — letters, digits and @._+:- only.") : I18n.tr("With Shelly, only Flatpak packages in the current update list can be ignored.")
                titleColor: Theme.error
            }

            SettingsCard {
                iconName: "visibility_off"
                title: I18n.tr("Ignored (%1)", "ignored update packages section title, %1 is a count").arg((SettingsData.updaterIgnoredPackages || []).length)
                collapsible: true
                expanded: false
                visible: (SettingsData.updaterIgnoredPackages || []).length > 0

                Repeater {
                    model: SettingsData.updaterIgnoredPackages

                    delegate: SettingsRow {
                        id: ignoredRow
                        required property string modelData
                        required property int index

                        title: modelData
                        iconName: "visibility_off"

                        DankActionButton {
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: "delete"
                            iconColor: Theme.error
                            tooltipText: I18n.tr("Stop ignoring %1", "system updater button tooltip, %1 is the package name").arg(ignoredRow.modelData)
                            onClicked: {
                                const list = (SettingsData.updaterIgnoredPackages || []).slice();
                                list.splice(ignoredRow.index, 1);
                                SettingsData.set("updaterIgnoredPackages", list);
                            }
                        }
                    }
                }
            }
        }

        SettingsCard {
            width: parent.width
            iconName: "tune"
            title: I18n.tr("Advanced")
            settingKey: "systemUpdaterAdvanced"

            SettingsToggleRow {
                settingKey: "systemUpdaterCustomCommand"
                tags: ["custom", "command", "terminal"]
                text: I18n.tr("Use custom command")
                checked: SettingsData.updaterUseCustomCommand
                onToggled: checked => {
                    if (!checked) {
                        updaterCustomCommand.value = "";
                        updaterTerminalCustomClass.value = "";
                        SettingsData.set("updaterCustomCommand", "");
                        SettingsData.set("updaterTerminalAdditionalParams", "");
                    }
                    SettingsData.set("updaterUseCustomCommand", checked);
                }
            }

            SettingsRow {
                enabled: SettingsData.updaterUseCustomCommand
                body: Rectangle {
                    width: parent.width
                    height: warnText.implicitHeight + Theme.spacingS * 2
                    radius: Theme.cornerRadius
                    color: Theme.warningHover

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
            }

            SettingsTextFieldRow {
                id: updaterCustomCommand
                leftIconName: "terminal"
                visible: SettingsData.updaterUseCustomCommand
                resetKeys: ["updaterCustomCommand"]
                text: I18n.tr("Custom update command")
                placeholderText: "topgrade --no-retry"
                value: SettingsData.updaterCustomCommand
                onValueEdited: value => SettingsData.set("updaterCustomCommand", value.trim())
            }

            SettingsTextFieldRow {
                id: updaterTerminalCustomClass
                leftIconName: "terminal"
                visible: SettingsData.updaterUseCustomCommand
                resetKeys: ["updaterTerminalAdditionalParams"]
                text: I18n.tr("Terminal additional parameters")
                placeholderText: "-T updater"
                value: SettingsData.updaterTerminalAdditionalParams
                onValueEdited: value => SettingsData.set("updaterTerminalAdditionalParams", value.trim())
            }
        }
    }
}
