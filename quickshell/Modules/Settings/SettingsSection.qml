import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    property string title: ""
    property string iconName: ""
    property alias content: contentLoader.sourceComponent
    property bool expanded: false
    property bool collapsible: true
    property bool lazyLoad: true

    width: parent.width
    spacing: expanded ? Theme.spacingM : 0
    Component.onCompleted: {
        if (!collapsible)
            expanded = true;
    }

    MouseArea {
        width: parent.width
        height: headerRow.height
        enabled: collapsible
        hoverEnabled: collapsible
        onClicked: {
            if (collapsible)
                expanded = !expanded;
        }

        Rectangle {
            anchors.fill: parent
            color: parent.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
            radius: Theme.radiusS
        }

        Row {
            id: headerRow

            width: parent.width
            spacing: Theme.spacingS
            topPadding: Theme.spacingS
            bottomPadding: Theme.spacingS

            DankIcon {
                name: root.collapsible ? (root.expanded ? "expand_less" : "expand_more") : root.iconName
                size: Theme.iconSize - 2
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter

                Behavior on rotation {
                    NumberAnimation {
                        duration: Appearance.anim.durations.fast
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.anim.curves.standard
                    }
                }
            }

            DankIcon {
                name: root.iconName
                size: Theme.iconSize - 4
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
                visible: root.collapsible
            }

            StyledText {
                text: root.title
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.surfaceText
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        visible: expanded || !collapsible
    }

    Loader {
        id: contentLoader

        width: parent.width
        active: lazyLoad ? expanded || !collapsible : true
        visible: expanded || !collapsible
        asynchronous: true
        opacity: visible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.durations.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.standard
            }
        }
    }
}
