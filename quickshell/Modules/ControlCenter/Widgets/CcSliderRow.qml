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
    property bool interactive: true
    property real columns: 4
    property real rows: 1
    property bool compact: columns <= 2 && rows === 1
    property string iconName: ""
    property string iconLabel: ""
    property string iconTooltip: ""
    property string sliderLabel: ""
    property alias slider: slider
    property alias minimum: slider.minimum
    property alias maximum: slider.maximum
    property alias unit: slider.unit
    property alias valueOverride: slider.valueOverride
    property alias wheelStep: slider.wheelStep
    property bool sliderEnabled: true
    property alias isDragging: slider.isDragging
    readonly property bool tall: height >= CcMetrics.gridRowUnit * 2
    readonly property bool vertical: tall && width < height
    readonly property bool showLabel: tall && !vertical && width >= CcMetrics.expandedTileMinWidth
    readonly property bool showNumber: tall && (!vertical || height >= CcMetrics.gridRowUnit * 3)
    readonly property real bodyRadius: tall ? CcMetrics.tallTileRadius : Theme.cornerRadiusM
    readonly property real contentPadding: tall ? (vertical ? Theme.spacingS : Theme.spacingM) : 0
    readonly property real actionSize: Math.min(compact ? Theme.minimumTouchTargetSize : Math.max(Theme.minimumTouchTargetSize, CcMetrics.iconBoxSize), width - contentPadding * 2, tall ? Math.min(CcMetrics.tileHeight, height - contentPadding * 2 - Theme.minimumTouchTargetSize - (vertical ? Theme.spacingS : Theme.spacingM)) : height)

    signal iconClicked
    signal expandClicked
    signal sliderValueChanged(int newValue)

    width: parent?.width ?? 0
    height: CcMetrics.sliderRowHeight

    Rectangle {
        anchors.fill: parent
        radius: root.bodyRadius
        color: CcMetrics.tileInactiveColor
        border.width: Theme.layerOutlineWidth
        border.color: Theme.outlineMedium
        visible: root.tall
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: root.contentPadding

        DankActionButton {
            id: action
            objectName: "sliderAction"
            x: root.vertical ? (parent.width - width) / 2 : root.LayoutMirroring.enabled ? parent.width - width : 0
            y: root.vertical ? parent.height - height : root.tall ? 0 : (parent.height - height) / 2
            buttonSize: root.actionSize
            backgroundColor: CcMetrics.tileInactiveColor
            border.width: Theme.layerOutlineWidth
            border.color: Theme.outlineMedium
            iconName: root.iconName
            iconSize: CcMetrics.iconBoxIconSize
            iconColor: CcMetrics.tileInactiveContent
            enabled: root.sliderEnabled && root.interactive
            tooltipText: root.iconTooltip
            Accessible.name: root.iconLabel
            onClicked: root.iconClicked()
        }

        Column {
            id: labels
            anchors.left: root.vertical ? parent.left : action.right
            anchors.leftMargin: root.vertical ? 0 : Theme.spacingM
            anchors.right: parent.right
            y: root.vertical ? 0 : (action.height - height) / 2
            spacing: Theme.spacingXXS
            visible: root.tall

            StyledText {
                width: parent.width
                text: root.sliderLabel
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Theme.fontWeightMedium
                color: root.sliderEnabled ? Theme.surfaceText : Theme.onSurface_38
                elide: Text.ElideRight
                visible: root.showLabel
            }

            StyledText {
                width: parent.width
                text: slider.formatValue(slider.valueOverride >= 0 ? slider.valueOverride : slider.value)
                font.pixelSize: root.vertical ? Theme.fontSizeLarge : Theme.fontSizeMedium
                color: root.sliderEnabled ? Theme.surfaceVariantText : Theme.onSurface_38
                horizontalAlignment: root.vertical ? Text.AlignHCenter : Text.AlignLeft
                visible: root.showNumber
            }
        }

        Item {
            id: trackArea
            objectName: "sliderTrackArea"
            anchors.left: root.tall ? parent.left : action.right
            anchors.leftMargin: root.tall ? 0 : CcMetrics.gridGap
            anchors.right: parent.right
            y: root.vertical ? (root.showNumber ? labels.height + Theme.spacingS : 0) : root.tall ? action.height + Theme.spacingM : 0
            height: Math.max(0, (root.vertical ? action.y - Theme.spacingS : parent.height) - y)

            DankSlider {
                id: slider
                anchors.centerIn: parent
                width: root.vertical ? parent.height : parent.width
                rotation: root.vertical ? -90 : 0
                LayoutMirroring.enabled: !root.vertical && I18n.isRtl
                enabled: root.sliderEnabled && root.interactive
                wheelInsideScrollable: true
                size: {
                    if (!root.tall)
                        return "s";
                    const extent = root.vertical ? trackArea.width : trackArea.height;
                    if (extent >= Theme.sliderHandleHeightXL + Theme.spacingXS)
                        return "xl";
                    if (extent >= Theme.sliderHandleHeightL + Theme.spacingXS)
                        return "l";
                    return "m";
                }
                Accessible.name: root.sliderLabel
                showValue: !root.vertical
                onSliderValueChanged: newValue => root.sliderValueChanged(newValue)
            }
        }
    }
}
