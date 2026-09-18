pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets
import "../../../DankCommon/Common/FocusNavigation.js" as FocusNavigation

RowLayout {
    id: root

    required property var player
    required property var presentation

    readonly property var focusTargets: [shuffleButton, previousButton, playButton, nextButton, repeatButton]
    readonly property bool hasControls: !!presentation && (presentation.play || presentation.previous || presentation.next || presentation.shuffle || presentation.repeat)

    spacing: Theme.spacingS
    implicitHeight: Theme.buttonHeightM
    height: implicitHeight
    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true

    Keys.onPressed: event => event.accepted = FocusNavigation.handleHorizontalKey(event, focusTargets, false)

    TransportButton {
        id: shuffleButton
        mediaAction: "shuffle"
    }

    TransportButton {
        id: previousButton
        mediaAction: "previous"
    }

    TransportButton {
        id: playButton
        mediaAction: "play"
        size: "m"
        Layout.preferredWidth: Theme.buttonHeightM + Theme.spacingS
        variant: "filled"
        iconSize: Theme.iconSizeLarge
        containerColor: MediaAccentService.accentContainer
        contentColor: MediaAccentService.onAccentContainer
    }

    TransportButton {
        id: nextButton
        mediaAction: "next"
    }

    TransportButton {
        id: repeatButton
        mediaAction: "repeat"
    }

    component TransportButton: MediaTransportButton {
        player: root.player
        Layout.fillWidth: true
        Layout.preferredWidth: Theme.minimumTouchTargetSize
        Layout.minimumWidth: Theme.iconSizeMedium + Theme.spacingXS * 2
        Layout.alignment: Qt.AlignVCenter
        round: false
        buttonSize: size === "m" ? Theme.buttonHeightM : Theme.minimumTouchTargetSize
        variant: "tonal"
        containerColor: checked ? MediaAccentService.accentContainer : MediaAccentService.accentSecondaryContainer
        contentColor: checked ? MediaAccentService.onAccentContainer : MediaAccentService.onAccentSecondaryContainer
    }
}
