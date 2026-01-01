import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: toggle

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    // API
    property bool checked: false
    property bool enabled: true
    property bool toggling: false
    property string text: ""
    property string description: ""
    property bool hideText: false

    signal clicked
    signal toggled(bool checked)
    signal toggleCompleted(bool checked)

    readonly property bool showText: text && !hideText

    readonly property int trackWidth: 52
    readonly property int trackHeight: 30
    readonly property int insetCircle: 24

    width: showText ? parent.width : trackWidth
    height: showText ? Math.max(trackHeight, textColumn.implicitHeight + Theme.spacingM * 2) : trackHeight

    function handleClick() {
        if (!enabled)
            return;
        clicked();
        toggled(!checked);
    }

    StyledRect {
        id: background
        anchors.fill: parent
        radius: showText ? Theme.cornerRadius : 0
        color: "transparent"
        visible: showText

        StateLayer {
            visible: showText
            disabled: !toggle.enabled
            stateColor: Theme.primary
            cornerRadius: parent.radius
            onClicked: toggle.handleClick()
        }
    }

    Row {
        anchors.left: parent.left
        anchors.right: toggleTrack.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        spacing: Theme.spacingXS
        visible: showText

        Column {
            id: textColumn
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXS

            StyledText {
                text: toggle.text
                font.pixelSize: Appearance.fontSize.normal
                font.weight: Font.Medium
                opacity: toggle.enabled ? 1 : 0.4
                width: parent.width
                anchors.left: parent.left
            }

            StyledText {
                text: toggle.description
                font.pixelSize: Appearance.fontSize.small
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: Math.min(implicitWidth, toggle.width - 120)
                visible: toggle.description.length > 0
                anchors.left: parent.left
            }
        }
    }

    StyledRect {
        id: toggleTrack

        width: showText ? trackWidth : Math.max(parent.width, trackWidth)
        height: showText ? trackHeight : Math.max(parent.height, trackHeight)
        anchors.right: parent.right
        anchors.rightMargin: showText ? Theme.spacingM : 0
        anchors.verticalCenter: parent.verticalCenter
        radius: Theme.cornerRadius

        color: (checked && enabled) ? Theme.primary : Theme.surfaceVariantAlpha
        opacity: toggling ? 0.6 : (enabled ? 1 : 0.4)

        border.color: (!checked || !enabled) ? Theme.outline : "transparent"

        readonly property int pad: Math.round((height - thumb.width) / 2)
        readonly property int edgeLeft: pad
        readonly property int edgeRight: width - thumb.width - pad

        StyledRect {
            id: thumb

            width: (checked && enabled) ? insetCircle : insetCircle - 4
            height: (checked && enabled) ? insetCircle : insetCircle - 4
            radius: Theme.cornerRadius
            anchors.verticalCenter: parent.verticalCenter

            color: (checked && enabled) ? Theme.surface : Theme.outline
            border.color: (checked && enabled) ? Theme.outline : Theme.outline
            border.width: (checked && enabled) ? 1 : 2

            x: (checked && enabled) ? toggleTrack.edgeRight : toggleTrack.edgeLeft

            Behavior on x {
                SequentialAnimation {
                    NumberAnimation {
                        duration: Appearance.anim.durations.normal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.emphasizedDecel
                    }
                    ScriptAction {
                        script: {
                            toggle.toggleCompleted(toggle.checked);
                        }
                    }
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.durations.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }

            Behavior on border.width {
                NumberAnimation {
                    duration: Appearance.anim.durations.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }

            DankIcon {
                id: checkIcon
                anchors.centerIn: parent
                name: "check"
                size: 20
                color: Theme.surfaceText
                filled: true
                opacity: checked && enabled ? 1 : 0
                scale: checked && enabled ? 1 : 0.6

                Behavior on opacity {
                    NumberAnimation {
                        duration: Anims.durShort
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Anims.emphasized
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Anims.durShort
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Anims.emphasized
                    }
                }
            }
        }

        StateLayer {
            disabled: !toggle.enabled
            stateColor: Theme.primary
            cornerRadius: parent.radius
            onClicked: toggle.handleClick()
        }
    }
}
