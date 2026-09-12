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
    readonly property bool prism: effect === "prismEcho"
    readonly property bool radial: effect === "radialBurst"
    readonly property bool wipe: effect === "elasticWipe"
    readonly property bool stack: effect === "kineticStack"
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
            visible: root.radial
            anchors.centerIn: parent
            width: Math.max(parent.width, parent.height) * 1.45
            height: width
            radius: width / 2
            color: Theme.primaryContainer
            scale: 0.02 + root.entrance * 0.98
            opacity: 0.18 + root.entrance * 0.72
        }

        Repeater {
            model: root.radial && root.showShapes ? 12 : 0

            Rectangle {
                required property int index
                readonly property real angle: index / 12 * Math.PI * 2
                readonly property real distance: Math.min(textViewport.width, textViewport.height) * (0.08 + root.entrance * 0.44)
                width: index % 3 === 0 ? Theme.spacingL : Theme.spacingM
                height: index % 2 === 0 ? width : width * 2.2
                radius: width / 2
                color: index % 3 === 0 ? Theme.primary : index % 3 === 1 ? Theme.secondaryContainer : Theme.tertiaryContainer
                x: textViewport.width / 2 + Math.cos(angle) * distance - width / 2
                y: textViewport.height / 2 + Math.sin(angle) * distance - height / 2
                rotation: angle * 180 / Math.PI + 90
                opacity: Math.sin(root.entrance * Math.PI) * 0.92
                scale: 0.25 + Math.sin(root.entrance * Math.PI) * 0.75
            }
        }

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
            visible: !root.split && !root.wipe
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

        Text {
            anchors.fill: parent
            visible: root.prism || root.stack
            text: baseText.text
            textFormat: Text.PlainText
            color: Theme.secondary
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
            font: baseText.font
            opacity: root.prism ? 0.74 : 0.5
            transform: Translate {
                x: root.prism ? Math.sin(root.phase * Math.PI * 8) * Theme.spacingXL * (1 - root.phase * 0.72)
                   : -(1 - root.entrance) * Theme.spacingXL * 5
                y: root.prism ? Math.cos(root.phase * Math.PI * 6) * Theme.spacingM
                   : -(1 - root.entrance) * Theme.spacingXL * 2
            }
        }

        Text {
            anchors.fill: parent
            visible: root.prism || root.stack
            text: baseText.text
            textFormat: Text.PlainText
            color: Theme.tertiary
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
            font: baseText.font
            opacity: root.prism ? 0.7 : 0.5
            transform: Translate {
                x: root.prism ? -Math.cos(root.phase * Math.PI * 7) * Theme.spacingXL * (1 - root.phase * 0.72)
                   : (1 - root.entrance) * Theme.spacingXL * 5
                y: root.prism ? -Math.sin(root.phase * Math.PI * 5) * Theme.spacingM
                   : (1 - root.entrance) * Theme.spacingXL * 2
            }
        }

        Text {
            anchors.fill: parent
            visible: root.prism || root.stack
            text: baseText.text
            textFormat: Text.PlainText
            color: Theme.primary
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
            font: baseText.font
            opacity: root.entrance
            scale: root.stack ? 0.72 + root.entrance * 0.28 : 1
        }

        Item {
            anchors.centerIn: parent
            visible: root.wipe
            width: parent.width * root.entrance
            height: parent.height * (0.2 + root.entrance * 0.8)
            clip: true

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.primaryContainer
                opacity: 0.9
            }

            Text {
                width: textViewport.width
                height: textViewport.height
                x: -(textViewport.width - parent.width) / 2
                y: -(textViewport.height - parent.height) / 2
                text: baseText.text
                textFormat: Text.PlainText
                color: Theme.primaryText
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap
                font: baseText.font
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
            duration: root.prism ? 5800
                      : root.typography || root.wave ? 5200
                      : root.radial || root.stack ? 4200
                      : root.sweep ? 3600
                      : root.wipe ? 3200
                      : 2600
            easing.type: root.morph || root.orbit || root.split || root.radial || root.wipe || root.stack ? Easing.OutBack : Easing.InOutCubic
        }
    }
}
