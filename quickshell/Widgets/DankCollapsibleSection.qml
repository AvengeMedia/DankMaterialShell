import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

ColumnLayout {
    id: root

    required property string title
    property string description: ""
    property bool expanded: false
    property bool showBackground: false
    property alias headerColor: headerRect.color

    signal toggleRequested

    spacing: Theme.spacingS
    Layout.fillWidth: true

    Rectangle {
        id: headerRect
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(titleRow.implicitHeight + Theme.paddingM * 2, 48)
        radius: Theme.cornerRadius
        color: "transparent"

        RowLayout {
            id: titleRow
            anchors.fill: parent
            anchors.leftMargin: Theme.paddingM
            anchors.rightMargin: Theme.paddingM
            spacing: Theme.spacingM

            StyledText {
                text: root.title
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                Layout.fillWidth: true
            }

            DankIcon {
                name: "expand_more"
                size: Theme.iconSizeSmall
                rotation: root.expanded ? 180 : 0

                Behavior on rotation {
                    enabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
                    NumberAnimation {
                        easing.type: Easing.BezierSpline
                        duration: Theme.shortDuration
                        easing.bezierCurve: Theme.expressiveCurves.standard
                    }
                }
            }
        }

        StateLayer {
            anchors.fill: parent
            onClicked: {
                root.toggleRequested();
                root.expanded = !root.expanded;
            }
        }
    }

    default property alias content: contentColumn.data

    Item {
        id: contentWrapper
        Layout.fillWidth: true
        Layout.preferredHeight: root.expanded ? (contentColumn.implicitHeight + Theme.spacingS * 2) : 0
        clip: true

        Behavior on Layout.preferredHeight {
            enabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
            DankAnim {
                duration: Theme.expressiveDurations.expressiveDefaultSpatial
                easing.bezierCurve: Theme.expressiveCurves.standard
            }
        }

        Rectangle {
            id: backgroundRect
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: Theme.surfaceContainer
            opacity: root.showBackground && root.expanded ? 1.0 : 0.0
            visible: root.showBackground

            Behavior on opacity {
                enabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
                NumberAnimation {
                    easing.type: Easing.BezierSpline
                    duration: Theme.shortDuration
                    easing.bezierCurve: Theme.expressiveCurves.standard
                }
            }
        }

        ColumnLayout {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            y: Theme.spacingS
            anchors.leftMargin: Theme.paddingM
            anchors.rightMargin: Theme.paddingM
            anchors.bottomMargin: Theme.spacingS
            spacing: Theme.spacingS
            opacity: root.expanded ? 1.0 : 0.0

            Behavior on opacity {
                enabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
                NumberAnimation {
                    easing.type: Easing.BezierSpline
                    duration: Theme.shortDuration
                    easing.bezierCurve: Theme.expressiveCurves.standard
                }
            }

            StyledText {
                id: descriptionText
                Layout.fillWidth: true
                Layout.topMargin: root.description !== "" ? Theme.spacingXS : 0
                Layout.bottomMargin: root.description !== "" ? Theme.spacingS : 0
                visible: root.description !== ""
                text: root.description
                color: Theme.surfaceTextSecondary
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }
        }
    }
}
