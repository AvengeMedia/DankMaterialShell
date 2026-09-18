pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Templates as T
import qs.Common
import qs.Services
import qs.Widgets
import "../../../Common/QmlUtils.js" as QmlUtils

T.Control {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    readonly property bool isSettingsRow: true
    property Item groupItem: root

    property string tab: ""
    property var tags: []
    property string settingKey: ""

    property string title: ""
    property string subtitle: ""
    property color subtitleColor: Theme.surfaceVariantText
    property string iconName: ""
    property bool clickable: false
    property bool showChevron: false
    property string trailingBadge: ""
    property color trailingBadgeColor: Theme.surfaceVariantText
    property bool paintBackground: !(parent?.isSettingsGroupHost ?? false)
    property real paddingH: SettingsMetrics.rowPaddingH
    property real paddingV: SettingsMetrics.rowPaddingV
    property color rowColor: SettingsMetrics.rowColor
    property color iconColor: Theme.primary
    property color titleColor: Theme.surfaceText

    property var resetStore: SettingsData
    property var resetKeys: settingKey !== "" && resetStore === SettingsData && SettingsData.hasSetting(settingKey) ? [settingKey] : []
    property bool modified: resetKeys.length > 0 && resetStore?.isDefault(resetKeys) === false
    property bool resetByKeys: true
    property bool resetInHeader: true

    default property alias trailing: trailingSlot.data
    property alias leading: leadingSlot.data
    property alias body: bodySlot.data

    readonly property bool hasBody: bodySlot.visibleChildren.length > 0
    readonly property bool hasText: title !== "" || subtitle !== ""
    readonly property bool isHighlighted: settingKey !== "" && SettingsSearchService.highlightSection === settingKey
    readonly property bool isFirstInGroup: _edge(true)
    readonly property bool isLastInGroup: _edge(false)
    property real topRadius: isFirstInGroup ? Theme.groupedListOuterRadius : Theme.groupedListInnerRadius
    property real bottomRadius: isLastInGroup ? Theme.groupedListOuterRadius : Theme.groupedListInnerRadius
    readonly property real minHeight: subtitle !== "" ? Theme.listItemTwoLineHeight : Theme.listItemHeight

    signal clicked
    signal resetRequested

    onResetRequested: {
        if (resetByKeys)
            resetStore.resetToDefault(resetKeys);
    }

    focusPolicy: clickable ? Qt.StrongFocus : Qt.NoFocus
    Accessible.role: clickable ? Accessible.Button : Accessible.NoRole
    Accessible.name: title
    Accessible.description: subtitle
    Accessible.onPressAction: {
        if (clickable && enabled)
            clicked();
    }

    Keys.onPressed: event => {
        if (!clickable || !enabled)
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

    function _edge(first) {
        if (groupItem.parent?.isSettingsGroupHost)
            return groupItem.parent.isEdge(groupItem, first);
        const siblings = groupItem.parent?.visibleChildren;
        if (!siblings)
            return true;
        let seen = null;
        for (let i = 0; i < siblings.length; i++) {
            const c = siblings[i];
            if (c.isSettingsRow !== true)
                continue;
            if (first)
                return c === groupItem;
            seen = c;
        }
        return seen === groupItem;
    }

    width: parent?.width ?? 0
    height: implicitHeight
    implicitHeight: paddingV * 2 + headerLine.height + (hasBody ? bodySlot.height + (headerLine.height > 0 ? Theme.spacingM : 0) : 0)

    Component.onCompleted: {
        if (!settingKey)
            return;
        const key = settingKey;
        Qt.callLater(() => {
            if (!root.parent)
                return;
            const flickable = QmlUtils.findParentFlickable(root.parent);
            if (flickable)
                SettingsSearchService.registerCard(key, root, flickable, QmlUtils.findParentCollapsible(root.parent));
        });
    }

    Component.onDestruction: {
        if (settingKey)
            SettingsSearchService.unregisterCard(settingKey, root);
    }

    Rectangle {
        anchors.fill: parent
        visible: root.paintBackground
        color: root.isHighlighted ? Theme.blend(root.rowColor, Theme.primary, SettingsMetrics.highlightBlend) : root.rowColor
        topLeftRadius: root.topRadius
        topRightRadius: root.topRadius
        bottomLeftRadius: root.bottomRadius
        bottomRightRadius: root.bottomRadius
    }

    Rectangle {
        anchors.fill: parent
        visible: !root.paintBackground && root.isHighlighted
        color: SettingsMetrics.rowHighlightColor
        topLeftRadius: root.topRadius
        topRightRadius: root.topRadius
        bottomLeftRadius: root.bottomRadius
        bottomRightRadius: root.bottomRadius
    }

    Rectangle {
        id: stateLayer
        anchors.fill: parent
        visible: root.clickable
        color: Theme.surfaceText
        opacity: !root.enabled ? 0 : (clickControl.down ? Theme.stateLayerPressed : (clickControl.hovered ? Theme.stateLayerHover : 0))
        topLeftRadius: root.topRadius
        topRightRadius: root.topRadius
        bottomLeftRadius: root.bottomRadius
        bottomRightRadius: root.bottomRadius

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
        visible: root.clickable
        rippleColor: Theme.surfaceText
        topLeftRadius: root.topRadius
        topRightRadius: root.topRadius
        bottomLeftRadius: root.bottomRadius
        bottomRightRadius: root.bottomRadius
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.focusRingWidth / 2
        topLeftRadius: Math.max(0, root.topRadius - Theme.focusRingWidth / 2)
        topRightRadius: topLeftRadius
        bottomLeftRadius: Math.max(0, root.bottomRadius - Theme.focusRingWidth / 2)
        bottomRightRadius: bottomLeftRadius
        color: "transparent"
        border.width: Theme.focusRingWidth
        border.color: Theme.focusRingColor
        visible: root.visualFocus && root.clickable
    }

    StyledButton {
        id: clickControl
        anchors.fill: parent
        enabled: root.clickable && root.enabled
        hoverEnabled: root.clickable
        focusPolicy: Qt.ClickFocus
        background: null
        Accessible.ignored: true
        onPressedChanged: {
            if (pressed)
                ripple.trigger(pressX, pressY);
        }
        onClicked: root.clicked()

        HoverHandler {
            cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
    }

    Column {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.paddingV
        anchors.leftMargin: root.paddingH
        anchors.rightMargin: root.paddingH
        spacing: Theme.spacingM

        Item {
            id: headerLine
            visible: height > 0
            width: parent.width
            implicitHeight: Math.max(textColumn.implicitHeight, trailingArea.implicitHeight, leadingArea.visible ? leadingArea.implicitHeight : 0)
            height: Math.max(implicitHeight, (root.hasText || trailingSlot.children.length > 0 ? root.minHeight : 0) - root.paddingV * 2)

            Row {
                id: leadingArea
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingL
                visible: leadingSlot.children.length > 0 || leadingIcon.visible
                opacity: root.enabled ? 1 : SettingsMetrics.disabledOpacity

                Row {
                    id: leadingSlot
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS
                    visible: children.length > 0
                }

                DankIcon {
                    id: leadingIcon
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.iconName
                    size: Theme.iconSize
                    color: root.iconColor
                    visible: root.iconName !== ""
                }
            }

            Column {
                id: textColumn
                anchors.left: leadingArea.visible ? leadingArea.right : parent.left
                anchors.leftMargin: leadingArea.visible ? Theme.spacingL : 0
                anchors.right: resetButton.visible ? resetButton.left : (trailingArea.visible ? trailingArea.left : parent.right)
                anchors.rightMargin: resetButton.visible || trailingArea.visible ? SettingsMetrics.rowContentSpacing : 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXXS
                opacity: root.enabled ? 1 : SettingsMetrics.disabledOpacity
                visible: root.hasText

                StyledText {
                    width: parent.width
                    text: root.title
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Theme.fontWeightMedium
                    color: root.titleColor
                    wrapMode: Text.WordWrap
                    visible: root.title !== ""
                    horizontalAlignment: Text.AlignLeft
                }

                StyledText {
                    width: parent.width
                    text: root.subtitle
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.subtitleColor
                    wrapMode: Text.WordWrap
                    visible: root.subtitle !== ""
                    horizontalAlignment: Text.AlignLeft
                }
            }

            DankActionButton {
                id: resetButton
                anchors.right: trailingArea.visible ? trailingArea.left : parent.right
                anchors.rightMargin: trailingArea.visible ? Theme.spacingS : 0
                anchors.verticalCenter: parent.verticalCenter
                buttonSize: Theme.iconButtonSize
                iconName: "restart_alt"
                iconSize: Theme.iconSizeMedium
                iconColor: Theme.surfaceVariantText
                tooltipText: I18n.tr("Reset to default")
                Accessible.name: I18n.tr("Reset to default")
                visible: root.modified && root.resetInHeader
                enabled: root.enabled
                onClicked: root.resetRequested()
            }

            Row {
                id: trailingArea
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS
                visible: trailingSlot.children.length > 0 || root.showChevron || root.trailingBadge !== ""

                Row {
                    id: trailingSlot
                    spacing: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: root.trailingBadge
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.trailingBadgeColor
                    visible: root.trailingBadge !== ""
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankIcon {
                    name: "chevron_right"
                    size: Theme.iconSize
                    color: Theme.surfaceVariantText
                    rotation: I18n.isRtl ? 180 : 0
                    visible: root.showChevron
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Column {
            id: bodySlot
            width: parent.width
            spacing: Theme.spacingM
        }
    }
}
