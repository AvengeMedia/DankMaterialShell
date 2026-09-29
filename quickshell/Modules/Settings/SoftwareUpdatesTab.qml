import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    property var parentModal: null

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    Ref {
        service: SystemUpdateService
        modules: ["releases"]
    }

    ConfirmModal {
        id: updateConfirm
    }

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
    property bool packagesExpanded: false
    property int nowUnix: Math.floor(Date.now() / 1000)

    readonly property int packageListCap: 60
    readonly property bool upgradeRunsInTerminal: SystemUpdateService.useCustomCommand || (SystemUpdateService.backends || []).some(b => b.runsInTerminal === true)
    readonly property int systemCount: SystemUpdateService.systemUpdates.length
    readonly property int flatpakCount: SystemUpdateService.systemUpdates.filter(p => p.repo === "flatpak").length
    readonly property bool busy: SystemUpdateService.isChecking || SystemUpdateService.isUpgrading
    readonly property bool anythingToInstall: SystemUpdateService.updateCount > 0 && SystemUpdateService.helperAvailable
    readonly property string displayVersion: {
        const semver = ShellVersionService.semverVersion.replace(/^v/, "");
        const base = semver.match(/^\d+\.\d+/);
        return base ? base[0] : semver || SystemUpdateService.shellRunning.replace(/^v/, "");
    }
    readonly property var notesRelease: SystemUpdateService.notesRelease
    readonly property int serviceLastCheckUnix: SystemUpdateService.lastCheckUnix

    onServiceLastCheckUnixChanged: nowUnix = Math.floor(Date.now() / 1000)

    Component.onCompleted: {
        customIntervalSelected = !intervalOptions.some(o => o.seconds === SettingsData.updaterIntervalSeconds);
        nowUnix = Math.floor(Date.now() / 1000);
    }

    readonly property var notifyOptions: [
        {
            label: I18n.tr("Every check"),
            seconds: 0
        },
        {
            label: I18n.tr("Every %1", "update check interval option, %1 is a duration such as 30 minutes").arg(I18n.duration(3600)),
            seconds: 3600
        },
        {
            label: I18n.tr("Every %1", "update check interval option, %1 is a duration such as 30 minutes").arg(I18n.duration(4 * 3600)),
            seconds: 4 * 3600
        },
        {
            label: I18n.tr("Once a day"),
            seconds: 86400
        },
        {
            label: I18n.tr("Once a week"),
            seconds: 7 * 86400
        }
    ]

    function intervalLabelFor(seconds) {
        for (const opt of intervalOptions) {
            if (opt.seconds === seconds)
                return opt.label;
        }
        return customIntervalLabel;
    }

    function intervalSecondsFor(label) {
        for (const opt of intervalOptions) {
            if (opt.label === label)
                return opt.seconds;
        }
        return 86400;
    }

    function lastCheckedText() {
        const last = SystemUpdateService.lastCheckUnix;
        if (!last)
            return "";
        const delta = Math.max(0, nowUnix - last);
        if (delta < 90)
            return I18n.tr("checked just now");
        if (delta < 3600)
            return I18n.tr("checked %1m ago", "system update last check time, %1 is minutes").arg(Math.round(delta / 60));
        if (delta < 86400)
            return I18n.tr("checked %1h ago", "system update last check time, %1 is hours").arg(Math.round(delta / 3600));
        return I18n.tr("checked %1d ago", "system update last check time, %1 is days").arg(Math.round(delta / 86400));
    }

    function countText(count) {
        return count === 1 ? I18n.tr("%1 update", "singular, %1 is 1, available system update count").arg(count) : I18n.tr("%1 updates", "plural, %1 is a count of available system updates").arg(count);
    }

    function installMethodLabel() {
        switch (SystemUpdateService.shellInstallMethod) {
        case "pacman":
        case "rpm":
        case "dpkg":
        case "xbps":
            return SystemUpdateService.shellPackageName || SystemUpdateService.shellInstallMethod;
        case "nix":
            return "Nix";
        default:
            return "";
        }
    }

    function channelLabel() {
        switch (SystemUpdateService.shellChannel) {
        case "stable":
            return I18n.tr("Stable", "release channel");
        case "git":
            return I18n.tr("Git", "release channel that follows the master branch");
        default:
            return I18n.tr("Unknown");
        }
    }

    function heroStatus() {
        const checked = lastCheckedText();
        switch (true) {
        case !SystemUpdateService.sysupdateAvailable:
            return I18n.tr("Unavailable");
        case SystemUpdateService.isUpgrading:
            return I18n.tr("Upgrading...", "system update popout status while packages upgrade");
        case SystemUpdateService.isChecking:
            return I18n.tr("Checking for updates...");
        case SystemUpdateService.restartPending:
            return I18n.tr("Requires restart");
        case SystemUpdateService.hasError:
            return I18n.tr("Failed: %1", "system update error status, %1 is the error message").arg(SystemUpdateService.errorMessage);
        case !SystemUpdateService.helperAvailable:
            return I18n.tr("No supported package manager found.");
        case SystemUpdateService.shellUpdateAvailable: {
            const shell = I18n.tr("DMS %1 available", "software updates hero, %1 is the new DMS version").arg(SystemUpdateService.shellUpdateVersion);
            return root.systemCount > 0 ? shell + " · " + root.countText(root.systemCount) : shell;
        }
        case root.systemCount > 0:
            return checked ? root.countText(root.systemCount) + " · " + checked : root.countText(root.systemCount);
        default:
            return checked ? I18n.tr("Up to date") + " · " + checked : I18n.tr("Up to date");
        }
    }

    function primaryLabel() {
        switch (true) {
        case SystemUpdateService.isUpgrading:
            return I18n.tr("Cancel");
        case SystemUpdateService.restartPending:
            return I18n.tr("Restart DMS");
        case root.anythingToInstall:
            return I18n.tr("Update All");
        default:
            return I18n.tr("Check for updates");
        }
    }

    function primaryIcon() {
        switch (true) {
        case SystemUpdateService.isUpgrading:
            return "stop";
        case SystemUpdateService.restartPending:
            return "restart_alt";
        case root.anythingToInstall:
            return "system_update_alt";
        default:
            return "refresh";
        }
    }

    function primaryAction() {
        switch (true) {
        case SystemUpdateService.isUpgrading:
            SystemUpdateService.cancelUpdates();
            return;
        case SystemUpdateService.restartPending:
            SystemUpdateService.restartShell();
            return;
        case root.anythingToInstall:
            root.confirmUpdateAll();
            return;
        default:
            SystemUpdateService.checkForUpdates();
        }
    }

    function confirmUpdateAll() {
        updateConfirm.showWithOptions({
            "title": I18n.tr("Install %1?", "confirm dialog title, %1 is an update count such as '34 updates'").arg(root.countText(SystemUpdateService.updateCount)),
            "message": root.upgradeRunsInTerminal ? I18n.tr("The upgrade runs in a terminal window and may ask for your password.") : I18n.tr("You may be asked for your password. Keep the shell running until it finishes."),
            "confirmText": I18n.tr("Update All"),
            "onConfirm": () => root.runUpdateAll()
        });
    }

    function runUpdateAll() {
        SystemUpdateService.runUpdates({
            includeFlatpak: SettingsData.updaterIncludeFlatpak,
            includeAUR: SettingsData.updaterAllowAUR,
            terminal: SessionData.terminalOverride
        });
        packagesExpanded = false;
    }

    SettingsPage {
        id: mainColumn

        DankCard {
            id: hero
            width: parent.width
            height: heroColumn.implicitHeight + SettingsMetrics.heroPadding * 3
            restRadius: Theme.cornerRadiusXL
            color: Theme.surfaceContainerLow
            pad: 0
            clipContent: true
            showFocusRing: false

            // The danklinux.com release banner, tinted to the accent.
            Image {
                anchors.fill: parent
                source: "file://" + Theme.shellDir + "/assets/release-banner.svg"
                fillMode: Image.Stretch
                asynchronous: true
                cache: false
                sourceSize: Qt.size(width, height)
                opacity: Theme.pendingOpacity
                layer.enabled: true
                layer.effect: MultiEffect {
                    colorization: 1
                    colorizationColor: Theme.primary
                }
            }

            Column {
                id: heroColumn
                anchors.centerIn: parent
                width: parent.width - SettingsMetrics.heroPadding * 2
                spacing: Theme.spacingS

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingS

                    StyledText {
                        id: heroBrand
                        text: "DMS"
                        font.pixelSize: Theme.fontSizeDisplayLarge
                        font.weight: Theme.shiftedFontWeight(Font.ExtraBold)
                        font.letterSpacing: -Theme.fontSizeDisplayLarge * 0.04
                        color: Theme.surfaceText
                    }

                    // The blog's silver-to-accent version number.
                    GradientText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.displayVersion
                        font: heroBrand.font
                    }
                }

                StyledText {
                    width: parent.width
                    visible: ShellVersionService.shellCodename !== ""
                    text: ShellVersionService.shellCodename.toUpperCase()
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Theme.fontWeightBold
                    font.letterSpacing: Theme.fontSizeMedium * 0.25
                    color: Theme.primary
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: Theme.spacingM
                    spacing: Theme.spacingS
                    visible: SystemUpdateService.sysupdateAvailable

                    DankButton {
                        id: primaryButton
                        anchors.verticalCenter: parent.verticalCenter
                        buttonHeight: Theme.buttonHeightS
                        text: root.primaryLabel()
                        iconName: root.primaryIcon()
                        busy: SystemUpdateService.isChecking
                        enabled: !SystemUpdateService.isChecking
                        backgroundColor: Theme.primary
                        textColor: Theme.onPrimary
                        onClicked: root.primaryAction()
                    }

                    // Re-check while the primary button is busy installing or restarting.
                    DankActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.anythingToInstall || SystemUpdateService.restartPending
                        enabled: !root.busy
                        buttonSize: Theme.buttonHeightS
                        iconName: "refresh"
                        iconColor: Theme.surfaceText
                        backgroundColor: Theme.chipSurface
                        tooltipText: I18n.tr("Check for updates")
                        onClicked: SystemUpdateService.checkForUpdates()
                    }
                }

                StyledText {
                    width: parent.width
                    topPadding: Theme.spacingXS
                    text: root.heroStatus()
                    font.pixelSize: Theme.fontSizeSmall
                    color: SystemUpdateService.hasError && !root.busy ? Theme.error : Theme.surfaceVariantText
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Item {
                    width: parent.width
                    height: rebootChip.implicitHeight
                    visible: SystemUpdateService.rebootRecommended

                    DankBadge {
                        id: rebootChip
                        anchors.horizontalCenter: parent.horizontalCenter
                        maximumWidth: parent.width
                        text: I18n.tr("Reboot recommended", "chip shown after a kernel or systemd upgrade") + " · " + SystemUpdateService.rebootPackages.join(", ")
                        color: Theme.tertiaryContainer
                        textColor: Theme.onTertiaryContainer
                    }
                }

                StyledText {
                    width: parent.width
                    visible: SystemUpdateService.hasError && !root.busy && SystemUpdateService.errorHint !== ""
                    text: SystemUpdateService.errorHint
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                M3WaveProgress {
                    id: upgradeWave
                    width: parent.width
                    height: Theme.spacingM
                    visible: SystemUpdateService.isUpgrading
                    isPlaying: visible
                    value: 1
                    trackColor: "transparent"
                    playheadColor: "transparent"
                }
            }
        }

        SettingsCard {
            width: parent.width
            title: "DankMaterialShell"
            iconName: "deployed_code"
            settingKey: "softwareUpdatesShell"
            tags: ["dms", "shell", "version", "channel", "restart"]

            SettingsRow {
                title: I18n.tr("Version")
                iconName: "tag"
                subtitle: {
                    const running = SystemUpdateService.shellRunning || ShellVersionService.shellVersion;
                    const to = SystemUpdateService.shellUpdateVersion;
                    if (to)
                        return running + " → " + to;
                    return running;
                }
                trailingBadge: root.installMethodLabel()
            }

            SettingsRow {
                title: I18n.tr("Channel")
                iconName: "alt_route"
                subtitle: root.channelLabel()
                trailingBadge: SystemUpdateService.shellManagedExternally ? I18n.tr("Managed by Nix") : ""
            }

            SettingsRow {
                visible: SystemUpdateService.shellChannel === "git" && SystemUpdateService.commitsBehind >= 0
                title: SystemUpdateService.commitsBehind === 0 ? I18n.tr("Up to date with master") : I18n.tr("%1 commits behind master", "git channel row, %1 is a count").arg(SystemUpdateService.commitsBehind)
                iconName: "commit"
                clickable: true
                showChevron: true
                onClicked: Qt.openUrlExternally("https://github.com/AvengeMedia/DankMaterialShell/commits/master")
            }

            SettingsNavRow {
                visible: root.notesRelease !== null
                title: I18n.tr("Release notes")
                iconName: "auto_awesome"
                hint: root.notesRelease?.codename ? "v" + root.notesRelease.version + " · " + root.notesRelease.codename : "v" + (root.notesRelease?.version ?? "")
                onClicked: root.parentModal?.navigateTo("updater_changelog")
            }

            SettingsRow {
                visible: SystemUpdateService.restartPending
                title: I18n.tr("Requires restart")
                iconName: "restart_alt"
                iconColor: Theme.warning
                subtitle: SystemUpdateService.shellInstalled ? I18n.tr("Installed %1, still running %2", "%1 is the installed version, %2 the running one").arg(SystemUpdateService.shellInstalled).arg(SystemUpdateService.shellRunning) : I18n.tr("A newer dms binary is installed.")

                DankButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Restart DMS")
                    iconName: "restart_alt"
                    backgroundColor: Theme.chipSurface
                    textColor: Theme.surfaceText
                    onClicked: SystemUpdateService.restartShell()
                }
            }
        }

        SettingsCard {
            width: parent.width
            visible: SystemUpdateService.sysupdateAvailable
            title: I18n.tr("System packages")
            iconName: "inventory_2"
            settingKey: "softwareUpdatesSystem"
            tags: ["system", "packages", "flatpak", "aur"]

            SettingsRow {
                title: {
                    if (!SystemUpdateService.helperAvailable)
                        return I18n.tr("No supported package manager found.");
                    if (root.systemCount === 0)
                        return I18n.tr("Up to date");
                    const base = root.countText(root.systemCount);
                    return root.flatpakCount > 0 ? base + " · " + I18n.tr("%1 Flatpak", "count of flatpak updates, %1 is a number").arg(root.flatpakCount) : base;
                }
                subtitle: {
                    const distro = SystemUpdateService.distributionPretty || SystemUpdateService.distribution;
                    const names = (SystemUpdateService.backends || []).map(b => b.displayName).join(", ");
                    return distro && names ? distro + " · " + names : distro || names;
                }
                iconName: root.packagesExpanded ? "expand_less" : "expand_more"
                clickable: root.systemCount > 0
                onClicked: root.packagesExpanded = !root.packagesExpanded

                DankButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.systemCount > 0 && !SystemUpdateService.isUpgrading
                    text: I18n.tr("Update All")
                    iconName: "system_update_alt"
                    backgroundColor: Theme.chipSurface
                    textColor: Theme.surfaceText
                    enabled: !root.busy
                    onClicked: root.confirmUpdateAll()
                }
            }

            Repeater {
                model: root.packagesExpanded && !SystemUpdateService.isUpgrading ? SystemUpdateService.systemUpdates.slice(0, root.packageListCap) : []

                delegate: SettingsRow {
                    id: packageRow
                    required property var modelData

                    title: modelData.name || ""
                    subtitle: {
                        const from = modelData.fromVersion || "";
                        const to = modelData.toVersion || "";
                        const version = from && to ? from + " → " + to : to || from;
                        const repo = modelData.repo || "";
                        return repo && version ? repo + " · " + version : repo || version;
                    }

                    DankActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "visibility_off"
                        visible: SystemUpdateService.canIgnorePackage(packageRow.modelData)
                        tooltipText: I18n.tr("Ignore package", "tooltip, exclude a package from system updates")
                        onClicked: SystemUpdateService.ignorePackage(packageRow.modelData.name)
                    }
                }
            }

            SettingsRow {
                visible: root.packagesExpanded && !SystemUpdateService.isUpgrading && root.systemCount > root.packageListCap
                title: I18n.tr("and %1 more", "%1 is the number of update rows not shown").arg(root.systemCount - root.packageListCap)
                titleColor: Theme.surfaceVariantText
            }

            SettingsRow {
                visible: SystemUpdateService.isUpgrading
                body: DankFlickable {
                    id: upgradeLog
                    width: parent.width
                    height: Math.min(logText.implicitHeight, Theme.listItemHeight * 5)
                    contentWidth: width
                    contentHeight: logText.implicitHeight
                    clip: true
                    onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

                    StyledText {
                        id: logText
                        width: upgradeLog.width
                        text: root.upgradeRunsInTerminal ? I18n.tr("Running in terminal") : (SystemUpdateService.recentLog || []).join("\n")
                        font.family: Theme.monoFontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.onSurface
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    }
                }
            }

            SettingsRow {
                visible: SystemUpdateService.hasError && !root.busy
                title: I18n.tr("Failed: %1", "system update error status, %1 is the error message").arg(SystemUpdateService.errorMessage)
                titleColor: Theme.error
                subtitle: SystemUpdateService.errorHint
                iconName: "error_outline"
                iconColor: Theme.error
            }
        }

        SettingsCard {
            width: parent.width
            title: I18n.tr("Options")
            iconName: "tune"
            settingKey: "systemUpdater"
            collapsible: true
            expanded: false

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
                placeholderText: "1440"
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
                settingKey: "systemUpdaterPauseOnBattery"
                tags: ["battery", "power", "pause"]
                resetKeys: ["updaterPauseOnBattery"]
                visible: BatteryService.batteryAvailable
                text: I18n.tr("Pause checks on battery")
                checked: SettingsData.updaterPauseOnBattery
                onToggled: checked => SettingsData.set("updaterPauseOnBattery", checked)
            }

            SettingsToggleRow {
                settingKey: "systemUpdaterNotify"
                tags: ["notify", "notification", "alert"]
                resetKeys: ["updaterNotify"]
                text: I18n.tr("Notify me on new updates")
                description: I18n.tr("Only when the count grows.")
                checked: SettingsData.updaterNotify
                onToggled: checked => SettingsData.set("updaterNotify", checked)
            }

            SettingsDropdownRow {
                settingKey: "systemUpdaterNotifyMin"
                tags: ["notify", "notification", "frequency", "throttle"]
                resetKeys: ["updaterNotifyMinSeconds"]
                visible: SettingsData.updaterNotify
                text: I18n.tr("Notify at most")
                options: root.notifyOptions.map(o => o.label)
                currentValue: (root.notifyOptions.find(o => o.seconds === SettingsData.updaterNotifyMinSeconds) ?? root.notifyOptions[root.notifyOptions.length - 1]).label
                onValueChanged: label => {
                    const opt = root.notifyOptions.find(o => o.label === label);
                    if (opt)
                        SettingsData.set("updaterNotifyMinSeconds", opt.seconds);
                }
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
                visible: root.upgradeRunsInTerminal
                checked: SettingsData.updaterReopenAfterUpgrade
                onToggled: checked => SettingsData.set("updaterReopenAfterUpgrade", checked)
            }

            TerminalPickerRow {}
        }

        SettingsCard {
            id: ignoredPackagesCard
            width: parent.width
            iconName: "visibility_off"
            title: I18n.tr("Ignored packages")
            settingKey: "systemUpdaterIgnoredPackages"
            tags: ["system", "update", "package", "ignore"]
            collapsible: true
            expanded: false

            property bool errorIsInvalidName: false

            function addIgnoredPackage() {
                const name = newIgnoredPackageField.value.trim();
                if (name === "")
                    return;
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
                        onClicked: SystemUpdateService.unignorePackage(ignoredRow.modelData)
                    }
                }
            }
        }

        SettingsCard {
            width: parent.width
            iconName: "terminal"
            title: I18n.tr("Advanced")
            settingKey: "systemUpdaterAdvanced"
            collapsible: true
            expanded: false

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

            SettingsNoteRow {
                enabled: SettingsData.updaterUseCustomCommand
                text: I18n.tr("Custom command and terminal params are split on whitespace; paths with spaces will break.")
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
