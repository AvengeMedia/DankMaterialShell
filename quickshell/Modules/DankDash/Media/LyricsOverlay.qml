pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.DankDash

FocusScope {
    id: root

    required property var player
    property real radius: DashMetrics.mediaArtRadius
    property Item blurSource: null
    property Item backgroundParent: null
    property real backgroundRadius: radius
    property bool following: true
    property bool followSnap: false
    property Item followedItem: null
    property real followedY: 0

    readonly property var controller: root.player.lyrics
    readonly property bool ready: controller.state === "ready"
    readonly property bool unsynced: ready && !controller.synced
    readonly property bool showFollow: ready && controller.synced && !following
    readonly property bool animationsEnabled: !SettingsData.reduceMotion && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
    readonly property int activeIndex: controller.activeIndex
    readonly property int firstFocusedIndex: controller.focusedGroups[0] ?? -1
    readonly property string trackKey: controller.trackKey
    readonly property bool userScrolling: transcript.isUserScrolling || transcript.dragging
    readonly property real currentLineY: transcript.currentItem?.y ?? 0
    readonly property real shapeInset: Math.ceil(Math.min(radius, width / 2, height / 2) * (1 - Math.SQRT1_2))
    readonly property bool compact: content.height < Theme.listItemTwoLineHeight * 2
    readonly property real leadFontSize: Math.round(Math.max(Theme.fontSizeXLarge, Math.min(Theme.fontSizeDisplay, transcript.height / DashMetrics.lyricsLeadHeightDivisor, transcript.width / DashMetrics.lyricsLeadWidthDivisor)))
    readonly property string message: {
        switch (controller.state) {
        case "loading":
            return controller.showLoading ? I18n.tr("Loading...") : "";
        case "instrumental":
            return I18n.tr("Instrumental", "Track has no lyrics because it is instrumental");
        case "error":
            return I18n.tr("Unavailable");
        case "none":
            return I18n.tr("No results");
        }
        return "";
    }

    activeFocusOnTab: true
    Accessible.role: Accessible.Pane
    Accessible.name: I18n.tr("Lyrics", "Media player lyrics button")
    onActiveIndexChanged: followTimer.restart()
    onFirstFocusedIndexChanged: followTimer.restart()
    onReadyChanged: followTimer.restart()
    onWidthChanged: snapToCurrent()
    onHeightChanged: snapToCurrent()
    onTrackKeyChanged: {
        following = true;
        followMotion.stop();
        transcript.stopMomentum();
        transcript.savedY = 0;
        transcript.positionViewAtBeginning();
    }
    onUserScrollingChanged: {
        if (userScrolling)
            browse();
    }
    onCurrentLineYChanged: {
        if (!followedItem || transcript.currentItem !== followedItem || transcript.currentIndex !== Math.max(0, activeIndex))
            return;
        const shift = currentLineY - followedY;
        followedY = currentLineY;
        if (shift === 0 || !following)
            return;
        if (followMotion.running) {
            followTimer.restart();
            return;
        }
        transcript.contentY = Math.max(transcript.originY, Math.min(transcript.maximumContentY, transcript.contentY + shift));
    }

    Binding {
        target: root.player
        property: "lyricsFocusTarget"
        value: root
        restoreMode: Binding.RestoreBindingOrValue
    }

    function browse() {
        following = false;
        followMotion.stop();
    }

    function snapToCurrent() {
        followSnap = true;
        followTimer.restart();
    }

    function followCurrent() {
        const snap = followSnap;
        followSnap = false;
        if (!ready || !controller.synced || !following || transcript.count === 0)
            return;
        followMotion.stop();
        transcript.stopMomentum();
        const previous = transcript.contentY;
        transcript.currentIndex = Math.max(0, activeIndex);
        transcript.forceLayout();
        transcript.positionViewAtIndex(transcript.currentIndex, ListView.Center);
        if (transcript.currentItem && transcript.currentItem.height > transcript.height)
            transcript.positionViewAtIndex(transcript.currentIndex, ListView.Beginning);
        let target = transcript.contentY;
        const first = transcript.itemAtIndex(controller.focusedGroups[0] ?? transcript.currentIndex);
        const last = transcript.currentItem;
        if (first && last && last.y + last.height - first.y <= transcript.height)
            target = Math.max(transcript.originY, Math.min(transcript.maximumContentY, (first.y + last.y + last.height - transcript.height) / 2));
        target = Math.round(target);
        transcript.contentY = target;
        followedItem = last;
        followedY = last?.y ?? 0;
        if (snap || !animationsEnabled || Math.abs(target - previous) > transcript.height)
            return;
        transcript.contentY = previous;
        followMotion.from = previous;
        followMotion.to = target;
        followMotion.restart();
    }

    function scrollBy(amount) {
        browse();
        transcript.stopMomentum();
        transcript.contentY = Math.max(transcript.originY, Math.min(transcript.maximumContentY, transcript.contentY + amount));
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Escape:
            root.player.lyricsOpen = false;
            break;
        case Qt.Key_Up:
            scrollBy(-Theme.listItemHeight);
            break;
        case Qt.Key_Down:
            scrollBy(Theme.listItemHeight);
            break;
        case Qt.Key_PageUp:
            scrollBy(-transcript.height);
            break;
        case Qt.Key_PageDown:
            scrollBy(transcript.height);
            break;
        case Qt.Key_Home:
            browse();
            transcript.stopMomentum();
            transcript.positionViewAtBeginning();
            break;
        case Qt.Key_End:
            browse();
            transcript.stopMomentum();
            transcript.positionViewAtEnd();
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    Timer {
        id: followTimer
        interval: 0
        onTriggered: root.followCurrent()
    }

    NumberAnimation {
        id: followMotion
        target: transcript
        property: "contentY"
        duration: Theme.expressiveDurations.expressiveDefaultSpatial
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
    }

    NumberAnimation on opacity {
        running: root.animationsEnabled
        from: 0
        to: 1
        duration: Theme.expressiveDurations.expressiveEffects
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
    }

    Item {
        parent: root.backgroundParent ?? root
        anchors.fill: parent
        opacity: root.backgroundParent ? root.opacity : 1

        BackdropBlur {
            anchors.fill: parent
            radius: root.backgroundRadius
            sourceItem: root.blurSource
        }

        Rectangle {
            anchors.fill: parent
            radius: root.backgroundRadius
            color: root.blurSource ? Theme.withAlpha(Theme.surfaceContainerLowest, DashMetrics.lyricsScrimAlpha) : Theme.foregroundColor(Theme.surfaceContainerLowest, false)
            antialiasing: true
        }
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: Math.max(0, root.shapeInset - Theme.spacingM)

        StyledText {
            id: heading
            anchors.top: parent.top
            anchors.topMargin: Theme.spacingM
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - Theme.spacingM * 2
            text: root.unsynced ? I18n.tr("Unsynced", "Lyrics have no timestamps") : I18n.tr("Lyrics", "Media player lyrics button")
            color: Theme.onSurfaceVariant
            font.pixelSize: Theme.fontSizeSmall
            horizontalAlignment: Text.AlignHCenter
            visible: !root.compact
        }

        DankListView {
            id: transcript
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: heading.visible ? heading.bottom : parent.top
            anchors.bottom: followButton.top
            anchors.margins: Theme.spacingM
            clip: true
            visible: root.ready
            reuseItems: true
            spacing: Theme.spacingXXS
            model: root.controller.synced ? root.controller.lines : root.controller.plainLines
            add: null
            remove: null
            displaced: null
            move: null
            header: Item {
                height: root.controller.synced ? transcript.height / 3 : Theme.spacingS
            }
            footer: Item {
                width: transcript.width
                height: Math.max(root.controller.synced ? transcript.height / 3 : Theme.spacingS, credit.implicitHeight + Theme.spacingM * 2)

                StyledText {
                    id: credit
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingM
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, parent.width)
                    text: root.controller.attributionName
                    color: Theme.outline
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }

                StateLayer {
                    anchors.fill: credit
                    anchors.margins: -Theme.spacingXS
                    cornerRadius: Theme.cornerRadius
                    stateColor: Theme.outline
                    visible: root.controller.attributionUrl !== ""
                    tooltipText: root.controller.attributionText || root.controller.attributionUrl
                    onClicked: Qt.openUrlExternally(root.controller.attributionUrl)
                }
            }
            onCountChanged: followTimer.restart()

            delegate: Item {
                id: lyric
                required property int index
                required property var modelData
                width: transcript.width
                height: vocals.implicitHeight

                Column {
                    id: vocals
                    width: parent.width

                    Repeater {
                        model: root.controller.synced ? lyric.modelData.parts : [
                            {
                                x: lyric.modelData,
                                w: [],
                                cues: [],
                                side: 0,
                                voiceName: "",
                                background: false
                            }
                        ]

                        delegate: LyricsVocal {
                            required property var modelData
                            width: vocals.width
                            controller: root.controller
                            part: modelData
                            accent: modelData.chorus ? MediaAccentService.lyricsGroupAccent : MediaAccentService.lyricsAccents[(modelData.voiceIndex ?? 0) % MediaAccentService.lyricsAccents.length]
                            synced: root.controller.synced
                            following: root.following
                            leadFontSize: root.leadFontSize
                            distance: lyric ? Math.abs(lyric.index - root.activeIndex) : 0
                            animationsEnabled: root.animationsEnabled
                            inViewport: {
                                if (!lyric)
                                    return false;
                                const top = lyric.y + y;
                                return top + height > transcript.contentY && top < transcript.contentY + transcript.height;
                            }
                        }
                    }
                }
            }
        }

        DankButton {
            id: followButton
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spacingM
            buttonHeight: Theme.buttonHeightXS
            maximumWidth: Math.max(0, parent.width - Theme.spacingM * 2)
            wrapText: true
            height: root.showFollow ? implicitHeight : 0
            visible: root.showFollow
            text: root.compact ? "" : I18n.tr("Follow playback", "Resume automatic scrolling of lyrics")
            Accessible.name: I18n.tr("Follow playback", "Resume automatic scrolling of lyrics")
            tooltipText: root.compact ? Accessible.name : ""
            iconName: "my_location"
            backgroundColor: Theme.chipSurface
            textColor: MediaAccentService.readableAccent
            onClicked: {
                root.following = true;
                root.forceActiveFocus(Qt.OtherFocusReason);
                root.followCurrent();
            }
        }

        Column {
            anchors.centerIn: parent
            width: parent.width - Theme.spacingL * 2
            spacing: Theme.spacingM
            visible: !root.ready

            StyledText {
                width: parent.width
                text: root.message
                color: Theme.onSurfaceVariant
                font.pixelSize: Theme.fontSizeMedium
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }

            DankButton {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.tr("Retry")
                visible: root.controller.state === "error"
                onClicked: root.controller.request()
            }
        }
    }
}
