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
    property real columns: 4
    property real rows: 1
    property bool compact: columns <= 2 && rows === 1
    property bool toggle: !opensPage
    property Component expandedContent: null
    property real expandedMinimumHeight: Theme.listItemHeight
    readonly property Item expandedItem: expandedLoader.item
    readonly property bool expanded: expandedContent !== null && width >= CcMetrics.expandedTileMinWidth && height >= headerHeight + expandedMinimumHeight + tilePadding * 2 + Theme.spacingM
    readonly property real tilePadding: tall && !narrow ? Theme.spacingM : Theme.spacingS
    readonly property real baseIconExtent: Math.min(Math.max(Theme.minimumTouchTargetSize, CcMetrics.iconBoxSize), height - tilePadding * 2, width - tilePadding * 2)
    readonly property real iconExtent: stacked ? Math.max(0, Math.min(baseIconExtent, height - tilePadding * 2 - Theme.spacingS - titleLabel.implicitHeight)) : baseIconExtent
    readonly property real headerHeight: Math.max(baseIconExtent, Theme.fontSizeLarge + Theme.fontSizeMedium + Theme.spacingS)
    readonly property bool stacked: tall && !expanded && width <= height
    readonly property bool narrow: width < CcMetrics.expandedTileMinWidth
    readonly property real labelHeight: titleLabel.implicitHeight + (showSubtitle ? Theme.spacingXXS + subtitleLabel.implicitHeight : 0)
    readonly property bool showSubtitle: subtitle !== "" && (!stacked || height - tilePadding * 2 >= iconExtent + Theme.spacingS + titleLabel.implicitHeight + Theme.spacingXXS + subtitleLabel.implicitHeight)
    property bool showExpand: false
    property bool opensPage: false
    property Component tallContent: null
    property bool interactive: true
    property bool iconBlinking: false
    property real iconRotation: 0

    signal clicked
    signal expandClicked
    signal wheel(var wheelEvent)

    readonly property bool tall: height >= CcMetrics.gridRowUnit * 2
    readonly property bool hasIconBox: (showExpand || opensPage || expanded) && !compact
    readonly property real restRadius: {
        if (active)
            return Math.min(CcMetrics.tileActiveRadius, width / 2, height / 2);
        return tall ? Math.min(CcMetrics.tallTileRadius, width / 2, height / 2) : Theme.fullRadius(width, height);
    }
    readonly property bool acceptsInput: interactive && enabled
    readonly property bool bodyActive: active && !hasIconBox
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
            return active ? CcMetrics.tileActiveContent : CcMetrics.tileInactiveContent;
        return bodyActive ? CcMetrics.tileActiveContent : CcMetrics.tileInactiveIcon;
    }
    readonly property color iconBoxColor: {
        if (!enabled)
            return Theme.onSurface_12;
        return active ? CcMetrics.tileActiveColor : CcMetrics.tileInactiveColor;
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
    Accessible.role: toggle && (!showExpand || compact) && !opensPage ? Accessible.CheckBox : Accessible.Button
    Accessible.checkable: toggle && (!showExpand || compact) && !opensPage
    Accessible.checked: active
    Accessible.name: title
    Accessible.description: subtitle
    Accessible.onPressAction: activate()
    Accessible.onToggleAction: {
        if (toggle && (!showExpand || compact) && !opensPage)
            activate();
    }

    function activate() {
        if (!acceptsInput)
            return;
        if (showExpand && !compact && !opensPage) {
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
        enabled: CcMetrics.animationsEnabled && !SettingsData.reduceMotion
        NumberAnimation {
            duration: Theme.expressiveDurations.expressiveEffects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
        }
    }

    Behavior on iconBoxRadius {
        enabled: CcMetrics.animationsEnabled && !SettingsData.reduceMotion
        NumberAnimation {
            duration: Theme.expressiveDurations.expressiveEffects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
        }
    }

    Rectangle {
        id: body

        anchors.fill: parent
        radius: root.bodyRadius
        color: root.bodyColor
        border.width: root.bodyActive ? 0 : Theme.layerOutlineWidth
        border.color: Theme.outlineMedium

        Behavior on color {
            enabled: CcMetrics.animationsEnabled && !SettingsData.reduceMotion
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
            anchors.bottomMargin: root.expanded ? root.height - root.headerHeight - root.tilePadding * 2 : 0
            stateColor: root.contentColor
            cornerRadius: root.bodyRadius
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            tooltipText: root.compact ? [root.title, root.subtitle].filter(text => text !== "").join(" · ") : ""
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    if (root.showExpand || root.opensPage)
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
            filled: root.active
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
            anchors.margins: root.tilePadding
            visible: !root.compact

            Rectangle {
                id: iconBox
                objectName: "tileIconBox"

                x: root.stacked && root.narrow ? (parent.width - width) / 2 : root.LayoutMirroring.enabled ? parent.width - width : 0
                y: root.stacked ? Math.max(0, (parent.height - height - Theme.spacingS - root.labelHeight) / 2) : root.expanded ? 0 : (parent.height - height) / 2
                width: root.iconExtent
                height: width
                radius: root.hasIconBox ? root.iconBoxRadius : 0
                color: root.hasIconBox ? root.iconBoxColor : "transparent"
                border.width: root.hasIconBox && !root.active ? Theme.layerOutlineWidth : 0
                border.color: Theme.outlineMedium
                activeFocusOnTab: root.showExpand && root.toggle && root.acceptsInput
                Accessible.role: root.toggle ? Accessible.CheckBox : Accessible.Button
                Accessible.name: root.title
                Accessible.description: root.subtitle
                Accessible.checkable: root.toggle
                Accessible.checked: root.active
                Accessible.ignored: !root.showExpand || !root.toggle
                Accessible.onPressAction: activate()
                Accessible.onToggleAction: activate()

                function activate() {
                    if (root.acceptsInput && root.toggle)
                        root.clicked();
                }

                Keys.onPressed: event => {
                    if (!root.acceptsInput || !root.toggle)
                        return;
                    switch (event.key) {
                    case Qt.Key_Space:
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        activate();
                        event.accepted = true;
                        break;
                    }
                }

                DankIcon {
                    id: tileIcon
                    anchors.centerIn: parent
                    name: root.iconName
                    size: root.hasIconBox ? CcMetrics.iconBoxIconSize : CcMetrics.tileIconSize
                    color: root.iconColor
                    filled: root.active
                    rotation: root.iconRotation

                    DankBlink {
                        target: tileIcon
                        running: root.iconBlinking && !root.compact && root.visible && root.live
                    }
                }

                StateLayer {
                    id: boxLayer
                    visible: root.showExpand && root.toggle
                    enabled: visible && root.acceptsInput
                    disabled: !root.acceptsInput
                    stateColor: root.iconColor
                    cornerRadius: root.iconBoxRadius
                    onClicked: iconBox.activate()
                }

                FocusRing {
                    radius: root.iconBoxRadius + Theme.focusRingOffset
                    visible: iconBox.activeFocus
                }
            }

            Loader {
                id: meterLoader
                anchors.left: iconBox.right
                anchors.leftMargin: CcMetrics.tileTextGap
                anchors.right: parent.right
                y: iconBox.y
                height: iconBox.height
                active: root.stacked && !root.narrow && root.tallContent !== null
                sourceComponent: root.tallContent
            }

            Item {
                id: labels
                objectName: "tileLabels"
                x: root.stacked || root.LayoutMirroring.enabled ? 0 : root.baseIconExtent + CcMetrics.tileTextGap
                width: root.stacked ? parent.width : Math.max(0, parent.width - root.baseIconExtent - CcMetrics.tileTextGap)
                y: root.stacked ? iconBox.y + iconBox.height + Theme.spacingS : root.expanded ? (root.headerHeight - height) / 2 : (parent.height - height) / 2
                height: root.labelHeight

                StyledText {
                    id: titleLabel
                    objectName: "tileTitle"
                    width: parent.width
                    text: root.title
                    color: root.contentColor
                    font.pixelSize: root.narrow ? Theme.fontSizeMedium : Theme.fontSizeLarge
                    font.weight: Theme.fontWeightMedium
                    elide: Text.ElideRight
                    wrapMode: root.stacked ? Text.Wrap : Text.NoWrap
                    maximumLineCount: root.stacked ? 2 : 1
                    horizontalAlignment: root.stacked && root.narrow ? Text.AlignHCenter : Text.AlignLeft
                }

                StyledText {
                    id: subtitleLabel
                    objectName: "tileSubtitle"
                    y: titleLabel.implicitHeight + Theme.spacingXXS
                    width: parent.width
                    text: root.subtitle
                    color: root.subtitleColor
                    font.pixelSize: root.narrow ? Theme.fontSizeSmall : Theme.fontSizeMedium
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    horizontalAlignment: root.stacked && root.narrow ? Text.AlignHCenter : Text.AlignLeft
                    visible: root.showSubtitle
                }
            }

            Loader {
                id: expandedLoader
                objectName: "tileExpandedContent"
                anchors.left: parent.left
                anchors.right: parent.right
                y: root.headerHeight + Theme.spacingM
                height: Math.max(0, parent.height - y)
                active: root.expanded && root.live
                visible: root.expanded
                enabled: root.acceptsInput
                sourceComponent: root.expandedContent
            }
        }
    }
    Binding {
        target: expandedLoader.item
        property: "tile"
        value: root
        when: expandedLoader.item !== null && "tile" in expandedLoader.item
    }
}
