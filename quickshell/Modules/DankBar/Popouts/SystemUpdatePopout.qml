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

    customKeyboardFocus: {
        if (!shouldBeVisible)
            return WlrKeyboardFocus.None;
        if (anyModalOpen)
            return WlrKeyboardFocus.None;
        if (CompositorService.useHyprlandFocusGrab)
            return WlrKeyboardFocus.OnDemand;
        return WlrKeyboardFocus.Exclusive;
    }

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

    onShouldBeVisibleChanged: {
        if (!shouldBeVisible) {
            return;
        }
        const stale = !SystemUpdateService.lastCheckUnix || (Date.now() / 1000 - SystemUpdateService.lastCheckUnix) > 300;
        if (stale && !SystemUpdateService.isChecking && !SystemUpdateService.isUpgrading) {
            SystemUpdateService.checkForUpdates();
        }
    }

    content: Component {
        Rectangle {
            id: updaterPanel

            color: "transparent"
            focus: true

            readonly property bool hasTerminalBackend: (SystemUpdateService.backends || []).some(b => b.runsInTerminal === true)

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
                    const names = (SystemUpdateService.backends || []).map(b => b.displayName).join(", ");
                    return I18n.tr("Backends: %1").arg(names);
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
                            if (updaterPanel.hasTerminalBackend) {
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
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.1)

                StyledText {
                    id: statusText
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    visible: !SystemUpdateService.isUpgrading && (SystemUpdateService.updateCount === 0 || SystemUpdateService.hasError || SystemUpdateService.isChecking)
                    text: {
                        switch (true) {
                        case SystemUpdateService.hasError:
                            return I18n.tr("Failed: %1").arg(SystemUpdateService.errorMessage);
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
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    visible: !SystemUpdateService.isUpgrading && SystemUpdateService.updateCount > 0 && !SystemUpdateService.hasError && !SystemUpdateService.isChecking
                    clip: true
                    spacing: Theme.spacingXS
                    model: SystemUpdateService.availableUpdates

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 48
                        radius: Theme.cornerRadius
                        color: packageMouseArea.containsMouse ? Theme.primaryHoverLight : "transparent"

                        required property var modelData

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
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)

                                StyledText {
                                    anchors.centerIn: parent
                                    text: modelData.repo || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.primary
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 64 - Theme.spacingS
                                spacing: 2

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
                                    spacing: 4

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
                            cursorShape: modelData.changelogUrl ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (modelData.changelogUrl) {
                                    Qt.openUrlExternally(modelData.changelogUrl);
                                }
                            }
                        }
                    }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingS
                    visible: SystemUpdateService.isUpgrading && updaterPanel.hasTerminalBackend

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
                    visible: SystemUpdateService.isUpgrading && !updaterPanel.hasTerminalBackend
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
