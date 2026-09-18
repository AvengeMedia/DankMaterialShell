pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.DankDash
import "../../../Common/Format.js" as Format

MediaChromeBase {
    id: root

    readonly property bool compact: width < Theme.smallBreakpoint
    readonly property real halfWidth: Math.max(0, (width - padding * 2 - Theme.spacingXL) / 2)
    readonly property real bodyHeight: Math.max(0, height - padding * 2)
    readonly property real paneWidth: artworkSize
    readonly property real paneOffset: Math.max(0, (width - padding * 2 - paneWidth * 2 - Theme.spacingXL) / 2)
    // !TODO: expose this variant? playerPaneOpen false gives art beside lyrics, or art alone with hover transport
    readonly property bool playerPane: root.player.playerPaneOpen
    readonly property bool controlsColumn: playerPane
    readonly property bool lyricsColumn: root.player.lyricsOpen && !playerPane
    readonly property bool splitPanes: controlsColumn || lyricsColumn
    readonly property bool artTransport: !playerPane && !!root.presentation
    readonly property real naturalArtSize: Math.max(0, Math.min(artSize, compact ? width / 2 : halfWidth))
    readonly property real artworkSize: compact ? naturalArtSize : Math.max(naturalArtSize, Math.min(halfWidth, bodyHeight))
    readonly property real columnHeight: compact ? artworkSize : Math.max(artworkSize, paneHeight)
    readonly property real paneHeight: Math.max(artworkSize, headerHeight + controls.implicitHeight)
    readonly property real paneMinHeight: Math.max(naturalArtSize, headerHeight + controls.implicitHeight)
    readonly property real headerHeight: sourceRow.height + Theme.spacingL
    readonly property real renderScale: Window.window?.devicePixelRatio ?? Screen.devicePixelRatio
    readonly property int artSide: TrackArtService.resolvedArtSide
    readonly property bool lowResArt: artSide > 0 && artSide < artworkSize * renderScale * DashMetrics.mediaArtLowResRatio

    artSize: DashMetrics.mediaArtSizeDash
    surfaceColor: DashMetrics.cardColor
    baseHeight: Math.max(DashMetrics.tabMinHeight, padding * 2 + (compact ? naturalArtSize + Theme.spacingXL + paneMinHeight : Math.max(naturalArtSize, paneMinHeight)))
    focusTargets: (viewToggle.visible ? [viewToggle] : []).concat(artTransportLoader.item?.focusTargets ?? [], [playerButton], seekbar.canSeek && seekBlock.visible ? [seekbar] : [], transport.focusTargets, sourceGroup.focusTargets)
    panelButtons: [playerButton].concat(sourceGroup.panelButtons)
    inlineVolume: true

    Item {
        id: artPane

        x: root.compact || !root.splitPanes ? (parent.width - width) / 2 : root.paneOffset + (I18n.isRtl ? root.paneWidth + Theme.spacingXL : 0)
        y: root.compact && root.splitPanes ? 0 : (parent.height - height) / 2
        width: root.compact ? parent.width : root.paneWidth
        height: root.columnHeight

        Behavior on x {
            enabled: !SettingsData.reduceMotion && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveDefaultSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
            }
        }

        Item {
            id: art
            anchors.centerIn: parent
            width: root.artworkSize * (root.lowResArt ? DashMetrics.mediaArtLowResScale : 1)
            height: width

            HoverHandler {
                id: artHover
            }

            MediaArtView {
                anchors.fill: parent
                player: root.player
                showLyrics: root.playerPane
                holdArt: TrackArtService.loading && TrackArtService.resolvedArtUrl === ""
            }

            Rectangle {
                id: viewTogglePill

                readonly property bool keyboardFocused: viewToggle.activeFocus && (root.Window.activeFocusItem?.visualFocus ?? false)
                readonly property bool revealed: artHover.hovered || keyboardFocused

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingM
                width: viewToggle.width + Theme.spacingXS * 2
                height: viewToggle.height + Theme.spacingXS * 2
                radius: Theme.fullRadius(width, height)
                color: Theme.chipSurface
                visible: root.player.lyricsEnabled
                opacity: revealed ? 1 : 0

                Behavior on opacity {
                    enabled: !SettingsData.reduceMotion && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
                    NumberAnimation {
                        duration: Theme.expressiveDurations.expressiveEffects
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                    }
                }

                DankButtonGroup {
                    id: viewToggle

                    anchors.centerIn: parent
                    size: "small"
                    checkEnabled: false
                    enabled: !!root.presentation
                    labelOnlySelected: true
                    maximumWidth: art.width - (Theme.spacingM + Theme.spacingXS) * 2
                    model: [
                        {
                            "text": I18n.tr("Artwork", "noun, media player album art view toggle and art style option"),
                            "icon": "image"
                        },
                        {
                            "text": I18n.tr("Lyrics", "Media player lyrics button"),
                            "icon": "lyrics"
                        }
                    ]
                    currentIndex: root.player.lyricsOpen ? 1 : 0
                    selectedColor: MediaAccentService.accentContainer
                    selectedContentColor: MediaAccentService.onAccentContainer
                    unselectedColor: Theme.withAlpha(MediaAccentService.accentContainer, 0)
                    unselectedContentColor: Theme.onSurfaceVariant
                    onActiveFocusChanged: {
                        if (activeFocus)
                            requestFocus(false);
                    }
                    onSelectionChanged: (index, selected) => {
                        if (!selected || (index === 1) === root.player.lyricsOpen)
                            return;
                        root.player.toggleLyrics(viewToggle);
                    }
                }
            }

            Loader {
                id: artTransportLoader
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.spacingM
                active: root.artTransport

                sourceComponent: Rectangle {
                    readonly property var focusTargets: [previousButton, playButton, nextButton]
                    readonly property bool focusWithin: previousButton.activeFocus || playButton.activeFocus || nextButton.activeFocus

                    width: artTransportRow.width + Theme.spacingM * 2
                    height: Theme.buttonHeightM + Theme.spacingXS * 2
                    radius: Theme.fullRadius(width, height)
                    color: Theme.withAlpha(Theme.surfaceContainerLowest, DashMetrics.mediaArtOverlayAlpha)
                    opacity: artHover.hovered || focusWithin ? 1 : 0

                    Behavior on opacity {
                        enabled: !SettingsData.reduceMotion && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
                        NumberAnimation {
                            duration: Theme.expressiveDurations.expressiveEffects
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                        }
                    }

                    Row {
                        id: artTransportRow
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS
                        LayoutMirroring.enabled: false

                        ArtTransportButton {
                            id: previousButton
                            mediaAction: "previous"
                        }

                        ArtTransportButton {
                            id: playButton
                            mediaAction: "play"
                            buttonSize: Theme.buttonHeightM
                            width: buttonSize
                            containerColor: MediaAccentService.accentContainer
                            contentColor: MediaAccentService.onAccentContainer
                        }

                        ArtTransportButton {
                            id: nextButton
                            mediaAction: "next"
                        }
                    }
                }
            }
        }
    }

    component ArtTransportButton: MediaTransportButton {
        player: root.player
        round: true
        checkable: false
        buttonSize: Theme.minimumTouchTargetSize
        variant: "tonal"
        containerColor: "transparent"
        contentColor: Theme.onSurface
    }

    Item {
        id: contentPane

        x: root.compact ? 0 : root.paneOffset + (I18n.isRtl ? 0 : root.paneWidth + Theme.spacingXL)
        y: root.compact ? root.artworkSize + Theme.spacingXL : (parent.height - height) / 2
        width: root.compact ? parent.width : root.paneWidth
        height: root.compact ? root.paneHeight : root.columnHeight
        visible: root.splitPanes

        Loader {
            id: lyricsView
            y: controls.y
            width: parent.width
            height: parent.height - controls.y
            active: root.lyricsColumn && root.player.live
            onLoaded: item.forceActiveFocus(Qt.PopupFocusReason)

            sourceComponent: LyricsOverlay {
                player: root.player
                radius: DashMetrics.surfaceRadius
            }
        }

        Column {
            id: controls
            visible: root.controlsColumn
            y: root.headerHeight + (parent.height - root.headerHeight - height) / 2
            width: parent.width
            spacing: Theme.spacingL

            Rectangle {
                width: parent.width
                height: metadata.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadiusL
                color: DashMetrics.cardColor

                Column {
                    id: metadata
                    x: Theme.spacingL
                    y: Theme.spacingL
                    width: parent.width - Theme.spacingL * 2
                    spacing: Theme.spacingXS

                    TextMetrics {
                        id: fullSizeTitle
                        text: root.title
                        font: Qt.font({
                            family: titleText.font.family,
                            weight: titleText.font.weight,
                            pixelSize: Theme.fontSizeXXLarge
                        })
                    }

                    FontMetrics {
                        id: fullSizeTitleFont
                        font: fullSizeTitle.font
                    }

                    ScrollingText {
                        id: titleText

                        readonly property real fittedPixelSize: {
                            if (fullSizeTitle.advanceWidth <= width)
                                return Theme.fontSizeXXLarge;
                            const fitted = Math.floor(Theme.fontSizeXXLarge * width / fullSizeTitle.advanceWidth);
                            return Math.max(Theme.fontSizeXLarge, fitted);
                        }

                        width: parent.width
                        height: Math.ceil(fullSizeTitleFont.height)
                        text: root.title
                        fontToken: root.titleFontToken
                        color: Theme.onSurface
                        font.pixelSize: fittedPixelSize
                        horizontalAlignment: Text.AlignHCenter
                        active: root.scrolling
                        loop: true
                        fadeEdges: true
                        pxPerMs: DashMetrics.mediaTextScrollSpeed / 1000
                    }

                    ScrollingText {
                        width: parent.width
                        text: [root.artist, root.album].filter(Boolean).join(" \u00b7 ") || "\u00a0"
                        color: Theme.onSurfaceVariant
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignHCenter
                        active: root.scrolling
                        loop: true
                        fadeEdges: true
                        pxPerMs: DashMetrics.mediaTextScrollSpeed / 1000
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: playback.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadiusL
                color: DashMetrics.cardColor
                visible: root.hasSeekbar || transport.hasControls

                Column {
                    id: playback
                    x: Theme.spacingL
                    y: Theme.spacingL
                    width: parent.width - Theme.spacingL * 2
                    spacing: Theme.spacingS

                    Item {
                        id: seekBlock
                        width: parent.width
                        height: Theme.buttonHeightXS
                        visible: root.hasSeekbar
                        LayoutMirroring.enabled: false
                        LayoutMirroring.childrenInherit: true

                        NumericText {
                            id: elapsed
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.ceil(reservedWidth)
                            text: Format.formatDuration(seekbar.value * (root.presentation?.length ?? 0))
                            reserveText: duration.text.replace(/\d/g, "8")
                            isMonospace: false
                            color: Theme.onSurfaceVariant
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        MediaSeekbar {
                            id: seekbar
                            anchors.left: elapsed.right
                            anchors.right: duration.left
                            anchors.margins: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            player: root.player
                        }

                        NumericText {
                            id: duration
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.ceil(reservedWidth)
                            text: Format.formatDuration(root.presentation?.length ?? 0)
                            reserveText: text.replace(/\d/g, "8")
                            isMonospace: false
                            color: Theme.onSurfaceVariant
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    MediaTransport {
                        id: transport
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(parent.width, implicitWidth)
                        player: root.player
                        presentation: root.presentation
                        visible: hasControls
                    }
                }
            }

            MediaSourceGroup {
                id: sourceGroup
                width: parent.width
                player: root.player
            }
        }

        Item {
            id: sourceRow

            y: Math.round((controls.y - height) / 2)
            width: parent.width
            height: Theme.buttonHeightXS

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingS
                visible: !!root.presentation

                StyledText {
                    id: sourceLabel
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, sourceRow.width / 2)
                    text: I18n.tr("Listening from", "Label before the active media player")
                    color: Theme.onSurfaceVariant
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }

                DankButton {
                    id: playerButton

                    readonly property string panelId: "players"

                    maximumWidth: Math.max(0, sourceRow.width - sourceLabel.width - parent.spacing)
                    buttonHeight: Theme.buttonHeightXS
                    horizontalPadding: Theme.spacingM
                    text: root.presentation?.identity ?? ""
                    backgroundColor: MediaAccentService.accentContainer
                    textColor: MediaAccentService.onAccentContainer
                    tooltipText: I18n.tr("Players", "Media player selection")
                    Accessible.name: I18n.tr("Players", "Media player selection") + ": " + text
                    onClicked: root.player.togglePanel("players")
                }
            }
        }
    }
}
