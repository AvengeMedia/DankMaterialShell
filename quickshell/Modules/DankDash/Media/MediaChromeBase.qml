pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.Common
import qs.Widgets
import qs.Modules.DankDash
import "../../../DankCommon/Common/FocusNavigation.js" as FocusNavigation

Item {
    id: root

    default property alias content: cardBody.data

    required property var player
    property real artSize: DashMetrics.mediaArtSizeDash
    property real backdropRadius: DashMetrics.surfaceRadius
    property color surfaceColor: DashMetrics.cardColor
    property real baseHeight: DashMetrics.tabMinHeight
    property var focusTargets: []
    property var panelButtons: []
    property bool inlineVolume: false

    readonly property var activePlayer: root.player.activePlayer
    readonly property var presentation: root.player.presentation
    readonly property string title: presentation ? (presentation.title || I18n.tr("Unknown Track")) : I18n.tr("No Active Players")
    readonly property string artist: presentation ? (presentation.artist || I18n.tr("Unknown Artist")) : ""
    readonly property string album: presentation?.album ?? ""
    readonly property string artUrl: presentation?.artUrl ?? ""
    readonly property real padding: DashMetrics.mediaCardMargin
    readonly property string titleFontToken: root.player.options?.titleFont ?? MediaOptions.defaultTitleFont
    readonly property bool seekbarEnabled: root.player.options?.seekbar ?? MediaOptions.defaults.seekbar
    readonly property bool hasSeekbar: seekbarEnabled && !!presentation && presentation.length > 0
    readonly property bool panelOpen: panel.opened
    readonly property bool scrolling: root.player.live && !!presentation?.playing && !panel.opened
    readonly property var availableFocusTargets: root.player.lyricsFocusTarget ? [root.player.lyricsFocusTarget].concat(focusTargets) : focusTargets

    readonly property Item focusTarget: panel.opened ? panel.focusTarget : availableFocusTargets.find(item => item?.visible && item.enabled) ?? null
    readonly property Item previousFocusTarget: panel.opened ? panel.focusTarget : availableFocusTargets.filter(item => item?.visible && item.enabled).slice(-1)[0] ?? null

    implicitHeight: root.baseHeight

    function cycleFocus(backwards) {
        if (panel.opened)
            return panel.cycleFocus(backwards);
        return FocusNavigation.moveFocus(availableFocusTargets, backwards);
    }

    function buttonForPanel(panelId) {
        const usable = panelButtons.filter(button => button?.visible && button.enabled);
        return usable.find(button => button.panelId === panelId) ?? usable[0] ?? null;
    }

    function focusPanelButton(panelId) {
        return FocusNavigation.focusItem(buttonForPanel(panelId), false);
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: root.backdropRadius
        color: root.surfaceColor

        Loader {
            anchors.fill: parent
            z: -1
            active: root.player.wallpaperEnabled && !!root.presentation

            sourceComponent: MediaArtBackdrop {
                radius: root.backdropRadius
                stableHeight: root.baseHeight
                activePlayer: root.activePlayer
                artUrl: root.artUrl
            }
        }

        Item {
            id: cardBody
            anchors.fill: parent
            anchors.margins: root.padding
        }
    }

    MediaPanel {
        id: panel
        parent: root.player.contentViewport || root
        z: DashMetrics.overlayZ
        player: root.player
        visible: root.visible && active
        scrimRadius: root.backdropRadius
        returnFocusItem: root.buttonForPanel(displayedPanel)
    }
}
