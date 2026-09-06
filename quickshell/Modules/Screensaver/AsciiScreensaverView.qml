pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import "ContentClassifier.js" as ContentClassifier

Item {
    id: root

    required property string content
    required property string effect
    required property int revision
    required property bool reducedMotion

    property real phase: 0
    property int noiseRevision: 0

    readonly property var rows: ContentClassifier.lines(content)
    readonly property int longestRow: {
        let longest = 1;
        for (let row of rows)
            longest = Math.max(longest, row.length);
        return longest;
    }
    readonly property var glyphs: {
        const result = [];
        let glyphIndex = 0;
        for (let rowIndex = 0; rowIndex < rows.length; rowIndex++) {
            const row = rows[rowIndex];
            for (let columnIndex = 0; columnIndex < row.length; columnIndex++) {
                const character = row[columnIndex];
                if (character !== " ") {
                    result.push({
                        character: character,
                        row: rowIndex,
                        column: columnIndex,
                        glyphIndex: glyphIndex
                    });
                    glyphIndex++;
                }
            }
        }
        return result;
    }

    readonly property bool reveal: effect === "asciiReveal"
    readonly property bool assemble: effect === "asciiAssemble"
    readonly property bool drift: effect === "asciiDrift"
    readonly property bool decrypt: effect === "asciiDecrypt"
    readonly property bool pour: effect === "asciiPour"
    readonly property bool scatter: effect === "asciiScatter"
    readonly property bool wave: effect === "asciiWave"
    readonly property bool glyphEffect: decrypt || pour || scatter || wave

    function clamp(value) {
        return Math.max(0, Math.min(1, value));
    }

    function staggeredProgress(index, count) {
        if (reducedMotion)
            return 1;
        const delay = count > 1 ? (index % count) / count * 0.55 : 0;
        return clamp((phase - delay) / 0.45);
    }

    function scrambledCharacter(index) {
        const symbols = "#@%&*+=?/\\<>[]{}01";
        return symbols[(index * 11 + noiseRevision * 7) % symbols.length];
    }

    function restart() {
        entrance.stop();
        phase = reducedMotion ? 1 : 0;
        noiseRevision = 0;
        if (!reducedMotion)
            entrance.restart();
    }

    onRevisionChanged: restart()
    Component.onCompleted: restart()

    Item {
        id: viewport
        anchors.fill: parent
        anchors.margins: Theme.spacingXL
        clip: true

        FontMetrics {
            id: metrics
            font.family: Theme.monoFontFamily
            font.pixelSize: Math.max(10, Math.min(54, viewport.width / root.longestRow, viewport.height / Math.max(1, root.rows.length) * 0.78))
        }

        Item {
            id: block
            anchors.centerIn: parent
            width: Math.min(viewport.width, root.longestRow * metrics.averageCharacterWidth)
            height: Math.min(viewport.height, root.rows.length * metrics.height)

            Column {
                id: rowsColumn
                anchors.fill: parent
                spacing: 0
                visible: !root.glyphEffect
                opacity: 0.12 + root.phase * 0.88

                Repeater {
                    model: root.rows

                    Text {
                        required property string modelData
                        required property int index
                        width: rowsColumn.width
                        height: metrics.height
                        text: modelData
                        textFormat: Text.PlainText
                        color: root.assemble && root.staggeredProgress(index, root.rows.length) < 0.72 ? Theme.tertiary : Theme.primary
                        font.family: Theme.monoFontFamily
                        font.pixelSize: metrics.font.pixelSize
                        wrapMode: Text.NoWrap
                        opacity: root.assemble ? root.staggeredProgress(index, root.rows.length) : 1
                        transform: Translate {
                            readonly property real progress: root.staggeredProgress(index, root.rows.length)
                            x: root.assemble && !root.reducedMotion ? (1 - progress) * (index % 2 ? block.width * 0.7 : -block.width * 0.7) : 0
                            y: root.assemble && !root.reducedMotion ? Math.sin(index * 2.4) * (1 - progress) * metrics.height * 2 : 0
                        }
                    }
                }

                transform: Translate {
                    x: root.drift && !root.reducedMotion ? Math.sin(root.phase * Math.PI * 2) * 42 : 0
                    y: root.drift && !root.reducedMotion ? Math.cos(root.phase * Math.PI * 2) * 26 : 0
                }
            }

            Repeater {
                model: root.glyphEffect && root.visible ? root.glyphs : []

                Text {
                    id: glyph
                    required property var modelData
                    readonly property real progress: root.staggeredProgress(modelData.glyphIndex, Math.max(1, root.glyphs.length))
                    readonly property real seedX: Math.sin((modelData.glyphIndex + 3) * 12.9898)
                    readonly property real seedY: Math.cos((modelData.glyphIndex + 7) * 8.233)

                    x: modelData.column * metrics.averageCharacterWidth
                    y: modelData.row * metrics.height
                    width: metrics.averageCharacterWidth
                    height: metrics.height
                    text: root.decrypt && progress < 0.78 ? root.scrambledCharacter(modelData.glyphIndex) : modelData.character
                    textFormat: Text.PlainText
                    color: progress < 0.72 ? (modelData.glyphIndex % 2 ? Theme.tertiary : Theme.secondary) : Theme.primary
                    font.family: Theme.monoFontFamily
                    font.pixelSize: metrics.font.pixelSize
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignTop
                    opacity: root.decrypt ? root.clamp(progress * 1.8) : progress
                    scale: root.decrypt ? 0.72 + progress * 0.28 : 1

                    transform: Translate {
                        x: root.pour && !root.reducedMotion ? (1 - glyph.progress) * glyph.seedX * metrics.averageCharacterWidth * 4
                           : root.scatter && !root.reducedMotion ? (1 - glyph.progress) * glyph.seedX * block.width * 0.75
                           : 0
                        y: root.pour && !root.reducedMotion ? -(1 - glyph.progress) * (block.height + modelData.row * metrics.height)
                           : root.scatter && !root.reducedMotion ? (1 - glyph.progress) * glyph.seedY * block.height * 0.75
                           : root.wave && !root.reducedMotion ? Math.sin(modelData.column * 0.7 + root.phase * Math.PI * 5) * (1 - root.phase) * metrics.height * 2.4
                           : 0
                    }
                }
            }

            Rectangle {
                visible: root.reveal
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * (1 - root.phase)
                color: Theme.surfaceContainerLowest

                Rectangle {
                    anchors.left: parent.left
                    width: Math.min(Theme.spacingL, parent.width)
                    height: parent.height
                    color: Theme.tertiaryContainer
                    opacity: parent.width > 0 ? 1 : 0
                }
            }
        }
    }

    Timer {
        interval: 72
        repeat: true
        running: root.visible && root.decrypt && root.phase < 0.84 && !root.reducedMotion
        onTriggered: root.noiseRevision++
    }

    SequentialAnimation {
        id: entrance
        running: false
        NumberAnimation {
            target: root
            property: "phase"
            from: 0
            to: 1
            duration: root.drift ? 7600 : root.decrypt ? 3600 : root.pour || root.scatter ? 3200 : 2500
            easing.type: root.pour ? Easing.OutBounce : root.scatter || root.assemble ? Easing.OutBack : Easing.InOutCubic
        }
        ScriptAction {
            script: {
                if (root.drift && !root.reducedMotion)
                    entrance.restart();
            }
        }
    }
}
