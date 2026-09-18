pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.DankDash
import "../../../Common/Format.js" as Format

Item {
    id: root

    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true

    required property var controller
    required property var part
    required property color accent
    property bool synced: true
    property bool following: true
    property int distance: 0
    property bool animationsEnabled: true
    property bool inViewport: false
    property real leadFontSize: Theme.fontSizeXLarge

    readonly property bool current: synced && controller.sampleTime >= part.t && controller.sampleTime < part.e
    readonly property bool highlighted: synced && controller.sampleTime >= part.t && (current || distance === 0)
    readonly property bool timedWords: synced && part.w.length > 0
    readonly property bool emphasize: synced && following
    readonly property bool lead: current || (distance === 0 && !part.background)
    readonly property int reach: lead ? 0 : Math.max(1, distance)
    readonly property real textScale: reach === 0 || !emphasize ? 1 : reach === 1 ? (Theme.fontSizeMedium + Theme.fontSizeLarge) / (Theme.fontSizeXLarge * 2) : Theme.fontSizeSmall / Theme.fontSizeXLarge
    readonly property int wordRevision: highlighted ? controller.wordRevision : -1
    readonly property bool animateWords: current && timedWords && animationsEnabled && controller.enabled && controller.playing && visible && inViewport
    readonly property int alignment: part.side === 0 ? Text.AlignHCenter : (part.side < 0) !== I18n.isRtl ? Text.AlignLeft : Text.AlignRight
    property real wordStart: -1
    property real wordProgress: 1

    implicitHeight: Math.ceil(line.implicitHeight * textScale) + Theme.spacingS
    opacity: reach === 0 || !emphasize ? 1 : reach === 1 ? DashMetrics.lyricsNearOpacity : reach === 2 ? DashMetrics.lyricsFarOpacity : 0
    onWordRevisionChanged: updateWordProgress()
    onAnimateWordsChanged: updateWordProgress()

    function highlightedText(activeOnly) {
        return part.w.map(word => {
            const sung = highlighted && (activeOnly ? word.t === wordStart : word.t < wordStart);
            const color = sung ? accent : activeOnly ? "transparent" : Theme.onSurfaceVariant;
            return '<font color="' + color + '">' + Format.escapeHtml(word.x).replace(/\n/g, "<br>") + '</font>';
        }).join("");
    }

    function updateWordProgress() {
        wordMotion.stop();
        if (!highlighted || !timedWords) {
            wordStart = -1;
            wordProgress = 1;
            return;
        }
        const at = controller.currentTime();
        const timing = controller.wordTiming(part, at);
        wordStart = timing.t;
        wordProgress = animationsEnabled && timing.e > timing.t ? Math.max(0, Math.min(1, (at - timing.t) / (timing.e - timing.t))) : 1;
        if (!animateWords || controller.rate <= 0 || timing.e <= at || wordProgress >= 1)
            return;
        wordMotion.from = wordProgress;
        wordMotion.duration = Math.ceil(Math.min(2147483647, (timing.e - at) * 1000 / controller.rate));
        wordMotion.start();
    }

    Behavior on opacity {
        enabled: root.animationsEnabled
        NumberAnimation {
            duration: Theme.expressiveDurations.expressiveEffects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
        }
    }

    NumberAnimation {
        id: wordMotion
        target: root
        property: "wordProgress"
        to: 1
    }

    Item {
        width: parent.width
        height: Math.ceil(line.implicitHeight * root.textScale)

        StyledText {
            id: line
            anchors.centerIn: parent
            width: parent.width
            text: root.timedWords ? root.highlightedText(false) : root.part.x || "\u00a0"
            textFormat: root.timedWords ? Text.StyledText : Text.PlainText
            Accessible.name: root.part.x
            Accessible.description: root.part.voiceName || ""
            color: root.highlighted ? root.accent : Theme.onSurfaceVariant
            Behavior on color {
                enabled: root.animationsEnabled
                ColorAnimation {
                    duration: Theme.expressiveDurations.expressiveEffects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                }
            }
            font.pixelSize: root.part.background || !root.emphasize ? Math.round(root.leadFontSize * Theme.fontSizeLarge / Theme.fontSizeXLarge) : root.leadFontSize
            font.weight: root.synced && !root.part.background ? Theme.fontWeightBold : Theme.fontWeightMedium
            scale: root.textScale
            Behavior on scale {
                enabled: root.animationsEnabled
                NumberAnimation {
                    duration: Theme.expressiveDurations.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
                }
            }
            transformOrigin: root.alignment === Text.AlignHCenter ? Item.Center : root.alignment === Text.AlignLeft ? Item.Left : Item.Right
            lineHeight: DashMetrics.lyricsLineHeight
            horizontalAlignment: root.alignment
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            elide: Text.ElideNone

            StyledText {
                anchors.fill: parent
                visible: root.highlighted && root.timedWords
                text: root.timedWords ? root.highlightedText(true) : ""
                textFormat: Text.StyledText
                Accessible.ignored: true
                font: line.font
                opacity: root.wordProgress
                lineHeight: line.lineHeight
                horizontalAlignment: line.horizontalAlignment
                wrapMode: line.wrapMode
                elide: Text.ElideNone
                Behavior on opacity {
                    enabled: false
                }
            }
        }
    }
}
