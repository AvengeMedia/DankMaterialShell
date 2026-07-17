import QtQuick
import Quickshell.Wayland
import qs.Common
import qs.Modals
import qs.Services
import qs.Widgets

DankPopout {
    id: systemUpdatePopout

    layerNamespace: "dms:system-update"

    property var parentWidget: null
    property var triggerScreen: null

    Ref {
        service: SystemUpdateService
    }

    property bool _reopenAfterUpgrade: false

    readonly property bool polkitModalOpen: polkitAuthSurfaceModal.shouldBeVisible
    readonly property bool anyModalOpen: polkitModalOpen

    Connections {
        target: PolkitService.agent
        enabled: PolkitService.polkitAvailable && systemUpdatePopout.shouldBeVisible

        function onAuthenticationRequestStarted() {
            polkitAuthSurfaceModal.open();
        }
    }

    PolkitAuthSurfaceModal {
        id: polkitAuthSurfaceModal
        parentPopout: systemUpdatePopout
    }

    backgroundInteractive: !anyModalOpen

    customKeyboardFocus: anyModalOpen ? WlrKeyboardFocus.None : null

    Connections {
        target: SystemUpdateService
        function onIsUpgradingChanged() {
            if (SystemUpdateService.isUpgrading) {
                return;
            }
            if (!systemUpdatePopout._reopenAfterUpgrade) {
                return;
            }
            systemUpdatePopout._reopenAfterUpgrade = false;
            systemUpdatePopout.open();
        }
    }

    popupWidth: 440
    popupHeight: 560
    triggerWidth: 55
    positioning: ""
    screen: triggerScreen
    shouldBeVisible: false

    onBackgroundClicked: {
        if (anyModalOpen)
            return;
        close();
    }

    content: Component {
        Rectangle {
            id: updaterPanel

            color: "transparent"
            focus: true

            readonly property bool upgradeRunsInTerminal: SystemUpdateService.useCustomCommand || (SystemUpdateService.backends || []).some(b => b.runsInTerminal === true)

            property int nowUnix: Math.floor(Date.now() / 1000)

            Connections {
                target: systemUpdatePopout
                function onShouldBeVisibleChanged() {
                    if (systemUpdatePopout.shouldBeVisible) {
                        updaterPanel.nowUnix = Math.floor(Date.now() / 1000);
                    }
                }
            }

            function distroLabel() {
                const pretty = (SystemUpdateService.distributionPretty || "").trim();
                if (pretty) {
                    return pretty.split(/\s+/)[0];
                }
                const id = (SystemUpdateService.distribution || "").trim();
                if (id) {
                    return id.charAt(0).toUpperCase() + id.slice(1);
                }
                return I18n.tr("System");
            }

            function lastCheckedText() {
                const last = SystemUpdateService.lastCheckUnix;
                if (!last) {
                    return "";
                }
                const delta = Math.max(0, nowUnix - last);
                if (delta < 90) {
                    return I18n.tr("checked just now");
                }
                if (delta < 3600) {
                    return I18n.tr("checked %1m ago").arg(Math.round(delta / 60));
                }
                if (delta < 86400) {
                    return I18n.tr("checked %1h ago").arg(Math.round(delta / 3600));
                }
                return I18n.tr("checked %1d ago").arg(Math.round(delta / 86400));
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    systemUpdatePopout.close();
                    event.accepted = true;
                }
            }

            Component.onCompleted: {
                if (systemUpdatePopout.shouldBeVisible) {
                    forceActiveFocus();
                }
            }

            Item {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: Theme.spacingL
                anchors.rightMargin: Theme.spacingL
                anchors.topMargin: Theme.spacingL
                height: 40

                StyledText {
                    text: I18n.tr("System Updates")
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            switch (true) {
                            case SystemUpdateService.isUpgrading:
                                return I18n.tr("Upgrading...");
                            case SystemUpdateService.isChecking:
                                return I18n.tr("Checking...");
                            case SystemUpdateService.hasError:
                                return I18n.tr("Error");
                            case SystemUpdateService.updateCount === 0:
                                return I18n.tr("Up to date");
                            case SystemUpdateService.updateCount === 1:
                                return I18n.tr("%1 update").arg(SystemUpdateService.updateCount);
                            default:
                                return I18n.tr("%1 updates").arg(SystemUpdateService.updateCount);
                            }
                        }
                        font.pixelSize: Theme.fontSizeMedium
                        color: SystemUpdateService.hasError ? Theme.error : Theme.surfaceVariantText
                    }

                    DankActionButton {
                        id: refreshButton
                        buttonSize: 28
                        iconName: "refresh"
                        iconSize: 18
                        iconColor: Theme.surfaceText
                        enabled: !SystemUpdateService.isChecking && !SystemUpdateService.isUpgrading
                        opacity: enabled ? 1.0 : 0.5
                        onClicked: SystemUpdateService.checkForUpdates()

                        RotationAnimator on rotation {
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: SystemUpdateService.isChecking

                            onRunningChanged: {
                                if (!running)
                                    refreshButton.rotation = 0;
                            }
                        }
                    }
                }
            }

            StyledText {
                id: backendsRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: header.bottom
                anchors.leftMargin: Theme.spacingL
                anchors.rightMargin: Theme.spacingL
                anchors.topMargin: Theme.spacingS
                visible: SystemUpdateService.backends.length > 0 && !SystemUpdateService.isUpgrading
                text: {
                    const kinds = [];
                    for (const b of SystemUpdateService.backends || []) {
                        const label = b.repo === "flatpak" ? I18n.tr("Flatpak") : I18n.tr("System");
                        if (!kinds.includes(label)) {
                            kinds.push(label);
                        }
                    }
                    const distro = updaterPanel.distroLabel();
                    const checked = updaterPanel.lastCheckedText();
                    const base = `${distro}: ${kinds.join(", ")}`;
                    return checked ? `${base} · ${checked}` : base;
                }
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
            }

            Row {
                id: buttonsRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: Theme.spacingL
                anchors.rightMargin: Theme.spacingL
                anchors.bottomMargin: Theme.spacingL
                spacing: Theme.spacingM
                height: 44

                Rectangle {
                    width: (parent.width - Theme.spacingM) / 2
                    height: parent.height
                    radius: Theme.cornerRadius
                    color: primaryMouseArea.containsMouse && primaryMouseArea.enabled ? Theme.primaryHover : Theme.secondaryHover
                    opacity: primaryMouseArea.enabled ? 1.0 : 0.5

                    StyledText {
                        anchors.centerIn: parent
                        text: SystemUpdateService.isUpgrading ? I18n.tr("Cancel") : I18n.tr("Update All")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.primary
                    }

                    MouseArea {
                        id: primaryMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: SystemUpdateService.isUpgrading || SystemUpdateService.updateCount > 0
                        onClicked: {
                            if (SystemUpdateService.isUpgrading) {
                                SystemUpdateService.cancelUpdates();
                                return;
                            }
                            const opts = {
                                includeFlatpak: SettingsData.updaterIncludeFlatpak,
                                includeAUR: SettingsData.updaterAllowAUR,
                                terminal: SessionData.terminalOverride
                            };
                            if (updaterPanel.upgradeRunsInTerminal) {
                                systemUpdatePopout._reopenAfterUpgrade = true;
                                SystemUpdateService.runUpdates(opts);
                                systemUpdatePopout.close();
                                return;
                            }
                            SystemUpdateService.runUpdates(opts);
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - Theme.spacingM) / 2
                    height: parent.height
                    radius: Theme.cornerRadius
                    color: closeMouseArea.containsMouse ? Theme.errorPressed : Theme.secondaryHover

                    StyledText {
                        anchors.centerIn: parent
                        text: I18n.tr("Close")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: closeMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: systemUpdatePopout.close()
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
            }

            Rectangle {
                id: bodyArea
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: backendsRow.visible ? backendsRow.bottom : header.bottom
                anchors.bottom: buttonsRow.top
                anchors.leftMargin: Theme.spacingL
                anchors.rightMargin: Theme.spacingL
                anchors.topMargin: Theme.spacingM
                anchors.bottomMargin: Theme.spacingM
                radius: Theme.cornerRadius
                color: Theme.surfaceLight

                StyledText {
                    id: statusText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: ignoredSection.top
                    anchors.margins: Theme.spacingM
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    visible: !SystemUpdateService.isUpgrading && (SystemUpdateService.updateCount === 0 || SystemUpdateService.hasError || SystemUpdateService.isChecking)
                    text: {
                        switch (true) {
                        case SystemUpdateService.hasError:
                            const msg = I18n.tr("Failed: %1").arg(SystemUpdateService.errorMessage);
                            return SystemUpdateService.errorHint ? `${msg}\n\n${SystemUpdateService.errorHint}` : msg;
                        case !SystemUpdateService.helperAvailable:
                            return I18n.tr("No supported package manager found.");
                        case SystemUpdateService.isChecking:
                            return I18n.tr("Checking for updates...");
                        default:
                            return I18n.tr("Your system is up to date!");
                        }
                    }
                    font.pixelSize: Theme.fontSizeMedium
                    color: SystemUpdateService.hasError ? Theme.error : Theme.surfaceText
                    wrapMode: Text.WordWrap
                }

                DankListView {
                    id: packagesList
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: ignoredSection.top
                    anchors.margins: Theme.spacingS
                    visible: !SystemUpdateService.isUpgrading && SystemUpdateService.updateCount > 0 && !SystemUpdateService.hasError && !SystemUpdateService.isChecking
                    clip: true
                    spacing: Theme.spacingXS
                    model: SystemUpdateService.availableUpdates

                    delegate: Rectangle {
                        id: packageRow
                        width: ListView.view.width
                        height: 48
                        radius: Theme.cornerRadius
                        color: rowHoverHandler.hovered ? Theme.primaryHoverLight : Theme.withAlpha(Theme.primaryHoverLight, 0)

                        required property var modelData

                        HoverHandler {
                            id: rowHoverHandler
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.spacingM
                            anchors.rightMargin: Theme.spacingM
                            spacing: Theme.spacingS

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 64
                                height: 18
                                radius: 9
                                color: Theme.primaryPressed

                                StyledText {
                                    anchors.centerIn: parent
                                    text: modelData.repo || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.primary
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 64 - Theme.spacingS * 2 - 28
                                spacing: Theme.spacingXXS

                                StyledText {
                                    width: parent.width
                                    text: modelData.name || ""
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingXS

                                    StyledText {
                                        text: {
                                            const from = modelData.fromVersion || "";
                                            const to = modelData.toVersion || "";
                                            if (from && to)
                                                return `${from} →`;
                                            return "";
                                        }
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        visible: text !== ""
                                    }

                                    StyledText {
                                        text: modelData.toVersion || modelData.fromVersion || ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.primary
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                        width: parent.width - (parent.children[0].visible ? parent.children[0].implicitWidth + 4 : 0)
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: packageMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: packageRow.modelData.changelogUrl ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (packageRow.modelData.changelogUrl) {
                                    Qt.openUrlExternally(packageRow.modelData.changelogUrl);
                                }
                            }
                        }

                        DankActionButton {
                            anchors.right: packageRow.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: packageRow.verticalCenter
                            buttonSize: 24
                            iconName: "visibility_off"
                            iconSize: 16
                            iconColor: Theme.surfaceVariantText
                            visible: rowHoverHandler.hovered && SystemUpdateService.canIgnorePackage(packageRow.modelData)
                            tooltipText: I18n.tr("Ignore this package")
                            onClicked: SystemUpdateService.ignorePackage(packageRow.modelData.name)
                        }
                    }
                }

                Column {
                    id: ignoredSection
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingXS

                    readonly property var ignoredNames: SettingsData.updaterIgnoredPackages || []
                    readonly property bool shown: ignoredNames.length > 0 && !SystemUpdateService.isUpgrading && !SystemUpdateService.isChecking
                    property bool expanded: false

                    visible: shown
                    height: shown ? implicitHeight : 0

                    Rectangle {
                        id: ignoredToggle
                        width: parent.width
                        height: 32
                        radius: Theme.cornerRadius
                        color: ignoredToggleArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight

                        DankIcon {
                            id: ignoredToggleIcon
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            name: "visibility_off"
                            size: 16
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            anchors.left: ignoredToggleIcon.right
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Ignored (%1)").arg(ignoredSection.ignoredNames.length)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        DankIcon {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            name: ignoredSection.expanded ? "expand_less" : "expand_more"
                            size: 16
                            color: Theme.surfaceVariantText
                        }

                        MouseArea {
                            id: ignoredToggleArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ignoredSection.expanded = !ignoredSection.expanded
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }

                    DankListView {
                        width: parent.width
                        height: ignoredSection.expanded ? Math.min(contentHeight, 150) : 0
                        visible: ignoredSection.expanded
                        clip: true
                        spacing: Theme.spacingXS
                        model: ignoredSection.ignoredNames

                        delegate: Rectangle {
                            id: ignoredRow
                            width: ListView.view.width
                            height: 32
                            radius: Theme.cornerRadius
                            color: Theme.surfaceLight

                            required property string modelData

                            StyledText {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.right: restoreButton.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: ignoredRow.modelData
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                            }

                            DankActionButton {
                                id: restoreButton
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter
                                buttonSize: 24
                                iconName: "visibility"
                                iconSize: 16
                                iconColor: Theme.surfaceVariantText
                                tooltipText: I18n.tr("Stop ignoring %1").arg(ignoredRow.modelData)
                                onClicked: SystemUpdateService.unignorePackage(ignoredRow.modelData)
                            }
                        }
                    }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingS
                    visible: SystemUpdateService.isUpgrading && updaterPanel.upgradeRunsInTerminal

                    DankIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "terminal"
                        size: 32
                        color: Theme.primary
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Running in terminal")
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("AUR helpers are interactive — see the terminal window for prompts. This popout will return to idle when the upgrade exits.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                DankFlickable {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    visible: SystemUpdateService.isUpgrading && !updaterPanel.upgradeRunsInTerminal
                    contentWidth: width
                    contentHeight: logText.implicitHeight
                    clip: true

                    onContentHeightChanged: {
                        if (contentHeight > height) {
                            contentY = contentHeight - height;
                        }
                    }

                    StyledText {
                        id: logText
                        width: parent.width
                        text: (SystemUpdateService.recentLog || []).join("\n")
                        font.family: Theme.monoFontFamily || "monospace"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        wrapMode: Text.NoWrap
                    }
                }
            }
        }
    }
}
