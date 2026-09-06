pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

Item {
    id: root

    required property string content
    required property string effect
    required property int revision
    required property bool reducedMotion
    required property bool showShapes

    property real phase: 0

    readonly property bool morph: effect === "materialMorph"
    readonly property bool typography: effect === "expressiveTypography"
    readonly property bool sweep: effect === "tonalSweep"
    readonly property bool split: effect === "splitBloom"
    readonly property bool orbit: effect === "orbitAssemble"
    readonly property bool wave: effect === "colorWave"
    readonly property real entrance: Math.min(1, phase * 2.2)
    readonly property real energy: Math.sin(phase * Math.PI * 2)

    function restart() {
        animation.stop();
        phase = reducedMotion ? 1 : 0;
        if (!reducedMotion)
            animation.restart();
    }

    onRevisionChanged: restart()
    Component.onCompleted: restart()

    Rectangle {
        anchors.centerIn: parent
        width: root.morph ? parent.width * (0.16 + root.entrance * 0.84) : parent.width
        height: root.morph ? Math.min(parent.height, width * (0.96 - root.entrance * 0.52)) : parent.height
        radius: root.morph ? height * (0.5 - root.entrance * 0.36) : Theme.cornerRadius * 2
        color: root.morph ? Theme.primaryContainer : Theme.surfaceContainer
        border.width: 1
        border.color: Theme.outlineVariant

        Behavior on width { SpringAnimation { spring: 2.4; damping: 0.22 } }
        Behavior on height { SpringAnimation { spring: 2.4; damping: 0.22 } }
        Behavior on radius { NumberAnimation { duration: 720; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        visible: root.showShapes
        width: Math.min(parent.width * 0.3, 280)
        height: Theme.spacingL
        radius: height / 2
        color: Theme.tertiaryContainer
        x: root.orbit ? parent.width / 2 + Math.cos(root.phase * Math.PI * 4) * parent.width * 0.34 * (1 - root.entrance) - width / 2 : parent.width - width - Theme.spacingXL
        y: root.orbit ? parent.height / 2 + Math.sin(root.phase * Math.PI * 4) * parent.height * 0.34 * (1 - root.entrance) - height / 2 : Theme.spacingXL
        rotation: root.orbit ? root.phase * 360 : 0
        opacity: 0.3 + root.entrance * 0.7
    }

    Rectangle {
        visible: root.showShapes
        width: Math.max(76, Math.min(parent.width * 0.12, 124))
        height: width
        radius: root.wave ? width * (0.26 + Math.abs(root.energy) * 0.24) : width / 2
        color: Theme.secondaryContainer
        x: root.orbit ? parent.width / 2 + Math.cos(root.phase * Math.PI * 4 + Math.PI) * parent.width * 0.3 * (1 - root.entrance) - width / 2 : Theme.spacingXL
        y: root.orbit ? parent.height / 2 + Math.sin(root.phase * Math.PI * 4 + Math.PI) * parent.height * 0.3 * (1 - root.entrance) - height / 2 : parent.height - height - Theme.spacingXL
        scale: 0.58 + root.entrance * 0.42

        Behavior on radius { NumberAnimation { duration: 380; easing.type: Easing.InOutCubic } }
    }

    Item {
        id: textViewport
        anchors.fill: parent
        anchors.margins: Theme.spacingXL * 2
        clip: true

        Rectangle {
            visible: root.sweep || root.wave
            x: -width + (parent.width + width) * root.phase
            width: Math.max(parent.width * 0.28, 180)
            height: parent.height
            radius: Theme.cornerRadius * 2
            color: root.wave ? Theme.tertiaryContainer : Theme.primaryContainer
            opacity: 0.88

            Rectangle {
                anchors.left: parent.right
                width: Theme.spacingL
                height: parent.height
                radius: width / 2
                color: Theme.secondaryContainer
            }
        }

        Text {
            id: baseText
            anchors.fill: parent
            visible: !root.split
            text: root.content || "DankMaterialShell"
            textFormat: Text.PlainText
            color: root.morph ? Theme.primaryText : root.wave && root.phase > 0.42 && root.phase < 0.78 ? Theme.tertiary : Theme.primary
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
            font.family: Theme.fontFamily
            font.weight: root.typography ? (root.phase < 0.32 ? Font.Light : root.phase < 0.68 ? Font.Black : Font.DemiBold) : Font.DemiBold
            font.letterSpacing: root.typography ? Math.sin(root.phase * Math.PI * 2) * 13 : 0
            font.pixelSize: 124
            fontSizeMode: Text.Fit
            minimumPixelSize: 18
            opacity: 0.16 + root.entrance * 0.84
            scale: root.typography ? 0.82 + root.entrance * 0.18 + Math.sin(root.phase * Math.PI * 3) * (1 - root.phase) * 0.05 : 1
            transform: Translate {
                y: root.wave ? Math.sin(root.phase * Math.PI * 4) * Theme.spacingL : 0
            }
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: parent.height / 2
            clip: true
            visible: root.split

            Text {
                width: textViewport.width
                height: textViewport.height
                text: root.content || "DankMaterialShell"
                textFormat: Text.PlainText
                color: Theme.primary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap
                font.family: Theme.fontFamily
                font.weight: Font.Black
                font.pixelSize: 124
                fontSizeMode: Text.Fit
                minimumPixelSize: 18
                opacity: root.entrance
                x: -(1 - root.entrance) * textViewport.width * 0.7
            }
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height / 2
            clip: true
            visible: root.split

            Text {
                width: textViewport.width
                height: textViewport.height
                y: -textViewport.height / 2
                text: root.content || "DankMaterialShell"
                textFormat: Text.PlainText
                color: Theme.tertiary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap
                font.family: Theme.fontFamily
                font.weight: Font.Black
                font.pixelSize: 124
                fontSizeMode: Text.Fit
                minimumPixelSize: 18
                opacity: root.entrance
                x: (1 - root.entrance) * textViewport.width * 0.7
            }
        }
    }

    SequentialAnimation {
        id: animation
        running: false
        NumberAnimation {
            target: root
            property: "phase"
            from: 0
            to: 1
            duration: root.typography || root.wave ? 5200 : root.sweep ? 3600 : 2600
            easing.type: root.morph || root.orbit || root.split ? Easing.OutBack : Easing.InOutCubic
        }
    }
}
