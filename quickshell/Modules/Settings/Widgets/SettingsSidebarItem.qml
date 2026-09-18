import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string iconName: ""
    property string title: ""
    property string hint: ""
    property string accent: ""
    property bool active: false
    property bool highlighted: false

    signal clicked

    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: title
    Accessible.description: hint
    Accessible.onPressAction: clicked()

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Space:
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.clicked();
            event.accepted = true;
            break;
        }
    }

    readonly property var accentPair: Theme.accent(accent)
    readonly property color badgeColor: accentPair?.container ?? Theme.withAlpha(Theme.primary, Theme.tonalTintAlpha)
    readonly property color glyphColor: accentPair?.onContainer ?? Theme.primary
    property bool isFirstInGroup: true
    property bool isLastInGroup: true
    readonly property real topRadius: isFirstInGroup ? Theme.groupedListOuterRadius : Theme.groupedListInnerRadius
    readonly property real bottomRadius: isLastInGroup ? Theme.groupedListOuterRadius : Theme.groupedListInnerRadius

    width: parent?.width ?? 0
    height: Math.max(SettingsMetrics.navItemMinHeight, textColumn.implicitHeight + Theme.spacingS * 2)
    topLeftRadius: topRadius
    topRightRadius: topRadius
    bottomLeftRadius: bottomRadius
    bottomRightRadius: bottomRadius
    color: active ? SettingsMetrics.selectedRowColor : SettingsMetrics.rowColor

    Behavior on color {
        enabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
        ColorAnimation {
            duration: SettingsMetrics.fadeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
        }
    }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: root.topRadius
        topRightRadius: root.topRadius
        bottomLeftRadius: root.bottomRadius
        bottomRightRadius: root.bottomRadius
        color: Theme.surfaceText
        opacity: mouseArea.pressed ? Theme.stateLayerPressed : (mouseArea.containsMouse || root.highlighted ? Theme.stateLayerHover : 0)

        Behavior on opacity {
            enabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
            NumberAnimation {
                duration: SettingsMetrics.fadeDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
            }
        }
    }

    DankRipple {
        id: ripple
        rippleColor: Theme.surfaceText
        topLeftRadius: root.topRadius
        topRightRadius: root.topRadius
        bottomLeftRadius: root.bottomRadius
        bottomRightRadius: root.bottomRadius
    }

    Rectangle {
        id: iconCircle
        width: SettingsMetrics.navIconSize
        height: SettingsMetrics.navIconSize
        radius: Theme.fullRadius(width, height)
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingL
        anchors.verticalCenter: parent.verticalCenter
        color: root.badgeColor

        Behavior on color {
            enabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
            ColorAnimation {
                duration: SettingsMetrics.fadeDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
            }
        }

        DankIcon {
            anchors.centerIn: parent
            name: root.iconName
            size: Theme.iconSizeMedium
            color: root.glyphColor
        }
    }

    Column {
        id: textColumn
        anchors.left: iconCircle.right
        anchors.leftMargin: Theme.spacingM
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingL
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXXS

        StyledText {
            width: parent.width
            text: root.title
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceText
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignLeft
        }

        StyledText {
            width: parent.width
            text: root.hint
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            visible: root.hint !== ""
            horizontalAlignment: Text.AlignLeft
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => ripple.trigger(mouse.x, mouse.y)
        onClicked: root.clicked()
    }
}
