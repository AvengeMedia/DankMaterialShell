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

    function restart() {
        phase = 0;
        if (reducedMotion) {
            phase = 1;
            return;
        }
        animation.restart();
    }

    onRevisionChanged: restart()
    Component.onCompleted: restart()

    Rectangle {
        anchors.centerIn: parent
        width: root.morph ? parent.width * (0.24 + root.phase * 0.76) : parent.width
        height: root.morph ? Math.min(parent.height, width * (0.92 - root.phase * 0.48)) : parent.height
        radius: root.morph ? height * (0.5 - root.phase * 0.36) : Theme.cornerRadius * 2
        color: root.morph ? Theme.primaryContainer : Theme.surfaceContainer
        border.width: 1
        border.color: Theme.outlineVariant

        Behavior on width { SpringAnimation { spring: 2.2; damping: 0.25 } }
        Behavior on height { SpringAnimation { spring: 2.2; damping: 0.25 } }
        Behavior on radius { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        visible: root.showShapes
        width: Math.min(parent.width * 0.26, 250)
        height: Theme.spacingL
        radius: height / 2
        color: Theme.tertiaryContainer
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Theme.spacingXL
        anchors.topMargin: Theme.spacingXL
        opacity: 0.35 + root.phase * 0.65
    }

    Rectangle {
        visible: root.showShapes
        width: Math.max(72, Math.min(parent.width * 0.11, 112))
        height: width
        radius: width / 2
        color: Theme.secondaryContainer
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.spacingXL
        anchors.bottomMargin: Theme.spacingXL
        scale: 0.75 + root.phase * 0.25
    }

    Item {
        anchors.fill: parent
        anchors.margins: Theme.spacingXL * 2
        clip: true

        Rectangle {
            visible: root.sweep
            x: -width + (parent.width + width) * root.phase
            width: Math.max(parent.width * 0.32, 180)
            height: parent.height
            radius: Theme.cornerRadius * 2
            color: Theme.primaryContainer
            opacity: 0.9
        }

        Text {
            anchors.fill: parent
            text: root.content || "DankMaterialShell"
            textFormat: Text.PlainText
            color: root.morph ? Theme.primaryText : Theme.primary
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
            font.family: Theme.fontFamily
            font.weight: root.typography && root.phase > 0.5 ? Font.Black : Font.DemiBold
            font.letterSpacing: root.typography ? (root.phase - 0.5) * 8 : 0
            font.pixelSize: 112
            fontSizeMode: Text.Fit
            minimumPixelSize: 18
            opacity: 0.25 + root.phase * 0.75
            scale: root.typography ? 0.88 + root.phase * 0.12 : 1
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
            duration: root.sweep ? 2200 : 1300
            easing.type: root.morph ? Easing.OutBack : Easing.OutCubic
        }
    }
}
