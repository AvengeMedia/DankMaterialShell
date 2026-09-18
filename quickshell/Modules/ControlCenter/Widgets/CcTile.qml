import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var widgetData: ({})
    property var widgetDef: null
    property var host: null
    property bool live: true
    property string iconName: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool compact: false
    property bool showExpand: false
    property bool interactive: true
    property bool iconBlinking: false
    property real iconRotation: 0

    signal clicked
    signal expandClicked
    signal wheel(var wheelEvent)

    readonly property bool hasIconBox: showExpand && !compact
    readonly property real restRadius: active ? Math.min(CcMetrics.tileActiveRadius, width / 2, height / 2) : Theme.fullRadius(width, height)
    readonly property bool acceptsInput: interactive && enabled
    readonly property bool bodyActive: active && interactive && !hasIconBox
    readonly property color bodyColor: {
        if (!enabled)
            return Theme.onSurface_12;
        return bodyActive ? CcMetrics.tileActiveColor : CcMetrics.tileInactiveColor;
    }
    readonly property color contentColor: {
        if (!enabled)
            return Theme.onSurface_38;
        return bodyActive ? CcMetrics.tileActiveContent : CcMetrics.tileInactiveContent;
    }
    readonly property color subtitleColor: {
        if (!enabled)
            return Theme.onSurface_38;
        return bodyActive ? CcMetrics.tileActiveContent : CcMetrics.tileInactiveSubtitle;
    }
    readonly property color iconColor: {
        if (!enabled)
            return Theme.onSurface_38;
        if (hasIconBox)
            return active && interactive ? CcMetrics.tileActiveContent : CcMetrics.tileInactiveContent;
        return bodyActive ? CcMetrics.tileActiveContent : CcMetrics.tileInactiveIcon;
    }
    readonly property color iconBoxColor: {
        if (!enabled)
            return Theme.onSurface_12;
        return active && interactive ? CcMetrics.tileActiveColor : Theme.surfaceContainerHighest;
    }

    property real bodyRadius: bodyLayer.pressed ? Math.min(Theme.cornerRadiusM, width / 2, height / 2) : restRadius
    property real iconBoxRadius: {
        if (boxLayer.pressed)
            return Math.min(Theme.cornerRadiusS, CcMetrics.iconBoxSize / 2);
        if (active)
            return Math.min(CcMetrics.iconBoxActiveRadius, CcMetrics.iconBoxSize / 2);
        return Theme.fullRadius(CcMetrics.iconBoxSize, CcMetrics.iconBoxSize);
    }

    width: parent?.width ?? 0
    height: CcMetrics.tileHeight
    activeFocusOnTab: acceptsInput
    Accessible.role: Accessible.Button
    Accessible.name: title
    Accessible.description: subtitle
    Accessible.onPressAction: activate()

    function activate() {
        if (!acceptsInput)
            return;
        if (hasIconBox) {
            expandClicked();
            return;
        }
        clicked();
    }

    Keys.onPressed: event => {
        if (!acceptsInput)
            return;
        switch (event.key) {
        case Qt.Key_Space:
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.activate();
            event.accepted = true;
            break;
        }
    }

    Behavior on bodyRadius {
        enabled: CcMetrics.animationsEnabled
        NumberAnimation {
            duration: Theme.expressiveDurations.expressiveFastSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
        }
    }

    Behavior on iconBoxRadius {
        enabled: CcMetrics.animationsEnabled
        NumberAnimation {
            duration: Theme.expressiveDurations.expressiveFastSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
        }
    }

    Rectangle {
        id: body

        anchors.fill: parent
        radius: root.bodyRadius
        color: root.bodyColor

        Behavior on color {
            enabled: CcMetrics.animationsEnabled
            ColorAnimation {
                duration: Theme.expressiveDurations.expressiveEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
            }
        }

        StateLayer {
            id: bodyLayer
            enabled: root.acceptsInput
            disabled: !root.acceptsInput
            stateColor: root.contentColor
            cornerRadius: root.bodyRadius
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    root.expandClicked();
                    return;
                }
                root.activate();
            }
            onWheel: wheelEvent => {
                wheelEvent.accepted = false;
                root.wheel(wheelEvent);
            }
        }

        FocusRing {
            radius: root.bodyRadius + Theme.focusRingOffset
            visible: root.activeFocus
        }

        DankIcon {
            id: compactIcon
            anchors.centerIn: parent
            name: root.iconName
            size: CcMetrics.tileIconSize
            color: root.iconColor
            rotation: root.iconRotation
            visible: root.compact

            DankBlink {
                target: compactIcon
                running: root.iconBlinking && root.compact && root.visible && root.live
            }
        }

        Item {
            id: content
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingS
            anchors.rightMargin: CcMetrics.tilePaddingH
            visible: !root.compact

            Rectangle {
                id: iconBox

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: CcMetrics.iconBoxSize
                height: CcMetrics.iconBoxSize
                radius: root.hasIconBox ? root.iconBoxRadius : 0
                color: root.hasIconBox ? root.iconBoxColor : "transparent"
                activeFocusOnTab: root.hasIconBox && root.acceptsInput
                Accessible.role: Accessible.CheckBox
                Accessible.name: root.title
                Accessible.description: root.subtitle
                Accessible.checkable: true
                Accessible.checked: root.active
                Accessible.ignored: !root.hasIconBox
                Accessible.onPressAction: {
                    if (root.acceptsInput)
                        root.clicked();
                }
                Accessible.onToggleAction: {
                    if (root.acceptsInput)
                        root.clicked();
                }

                Keys.onPressed: event => {
                    if (!root.acceptsInput)
                        return;
                    switch (event.key) {
                    case Qt.Key_Space:
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.clicked();
                        event.accepted = true;
                        break;
                    }
                }

                Behavior on color {
                    enabled: CcMetrics.animationsEnabled
                    ColorAnimation {
                        duration: Theme.expressiveDurations.expressiveEffects
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                    }
                }

                DankIcon {
                    id: tileIcon
                    anchors.centerIn: parent
                    name: root.iconName
                    size: root.hasIconBox ? CcMetrics.iconBoxIconSize : CcMetrics.tileIconSize
                    color: root.iconColor
                    rotation: root.iconRotation

                    DankBlink {
                        target: tileIcon
                        running: root.iconBlinking && !root.compact && root.visible && root.live
                    }
                }

                StateLayer {
                    id: boxLayer
                    visible: root.hasIconBox
                    enabled: root.hasIconBox && root.acceptsInput
                    disabled: !root.acceptsInput
                    stateColor: root.iconColor
                    cornerRadius: root.iconBoxRadius
                    onClicked: root.clicked()
                }

                FocusRing {
                    radius: root.iconBoxRadius + Theme.focusRingOffset
                    visible: iconBox.activeFocus
                }
            }

            Item {
                anchors.left: iconBox.right
                anchors.leftMargin: CcMetrics.tileTextGap
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: titleLabel.implicitHeight + (root.subtitle !== "" ? Theme.spacingXXS + subtitleLabel.implicitHeight : 0)

                StyledText {
                    id: titleLabel
                    width: parent.width
                    text: root.title
                    color: root.contentColor
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Theme.fontWeightMedium
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    horizontalAlignment: Text.AlignLeft
                }

                StyledText {
                    id: subtitleLabel
                    y: titleLabel.implicitHeight + Theme.spacingXXS
                    width: parent.width
                    text: root.subtitle
                    color: root.subtitleColor
                    font.pixelSize: Theme.fontSizeMedium
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    horizontalAlignment: Text.AlignLeft
                    visible: text !== ""
                }
            }
        }
    }
}
