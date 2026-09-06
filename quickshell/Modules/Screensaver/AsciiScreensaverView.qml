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
    readonly property var rows: ContentClassifier.lines(content)
    readonly property int longestRow: {
        let longest = 1;
        for (let row of rows)
            longest = Math.max(longest, row.length);
        return longest;
    }
    readonly property bool reveal: effect === "asciiReveal"
    readonly property bool assemble: effect === "asciiAssemble"
    readonly property bool drift: effect === "asciiDrift"

    function restart() {
        phase = reducedMotion ? 1 : 0;
        if (!reducedMotion)
            entrance.restart();
    }

    onRevisionChanged: restart()
    Component.onCompleted: restart()

    Item {
        id: viewport
        anchors.fill: parent
        anchors.margins: Theme.spacingXL * 2
        clip: true

        Item {
            id: block
            anchors.centerIn: parent
            width: Math.min(viewport.width, root.longestRow * metrics.averageCharacterWidth)
            height: Math.min(viewport.height, rowsColumn.implicitHeight)
            opacity: 0.18 + root.phase * 0.82
            transform: Translate {
                x: root.drift && !root.reducedMotion ? Math.sin(root.phase * Math.PI * 2) * 24 : 0
                y: root.drift && !root.reducedMotion ? Math.cos(root.phase * Math.PI * 2) * 14 : 0
            }

            FontMetrics {
                id: metrics
                font.family: Theme.monoFontFamily
                font.pixelSize: Math.max(10, Math.min(42, viewport.width / root.longestRow, viewport.height / Math.max(1, root.rows.length) * 0.82))
            }

            Column {
                id: rowsColumn
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Repeater {
                    model: root.rows

                    Text {
                        required property string modelData
                        required property int index
                        width: rowsColumn.width
                        text: modelData
                        textFormat: Text.PlainText
                        color: Theme.primary
                        font.family: Theme.monoFontFamily
                        font.pixelSize: metrics.font.pixelSize
                        wrapMode: Text.NoWrap
                        opacity: root.assemble ? Math.max(0, Math.min(1, root.phase * root.rows.length - index)) : 1
                        transform: Translate {
                            x: root.assemble && !root.reducedMotion ? (1 - Math.max(0, Math.min(1, root.phase * root.rows.length - index))) * (index % 2 ? 56 : -56) : 0
                        }
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
            }
        }
    }

    SequentialAnimation {
        id: entrance
        running: false
        NumberAnimation {
            target: root
            property: "phase"
            from: 0
            to: 1
            duration: root.drift ? 7000 : 2100
            easing.type: root.assemble ? Easing.OutBack : Easing.InOutCubic
        }
        ScriptAction {
            script: {
                if (root.drift && !root.reducedMotion)
                    entrance.restart();
            }
        }
    }
}
