import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property string widgetType: ""
    property var widgetData: null
    property var dgopModules: null
    property string iconName: ""
    property real level: 0
    property real warnLevel: 0
    property real dangerLevel: 0
    property string verticalText: "--"
    property string verticalSecondaryText: ""
    property string horizontalLabel: ""
    property string horizontalText: "--"
    property string reserveText: ""
    property string sortKey: ""
    property bool tabularDigits: true
    readonly property bool minimumWidth: SettingsData.widgetOption(widgetType, widgetData, "minimumWidth")
    readonly property real iconSize: Theme.barIconSize(barThickness, undefined, barConfig?.maximizeWidgetIcons, barConfig?.iconScale)
    readonly property real textSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)
    readonly property color levelColor: {
        if (level > dangerLevel)
            return Theme.tempDanger;
        if (level > warnLevel)
            return Theme.tempWarning;
        return Theme.widgetIconColor;
    }

    signal activated

    Ref {
        service: DgopService
        modules: root.dgopModules
        active: root.visible && root.enabled && (root.Window.window?.visible ?? false)
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? root.contentThickness : row.implicitWidth
            implicitHeight: root.isVerticalOrientation ? column.implicitHeight : row.implicitHeight

            Column {
                id: column
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.hairline(root.dpr)

                DankIcon {
                    name: root.iconName
                    size: root.iconSize
                    color: root.levelColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                NumericText {
                    isMonospace: false
                    font.features: root.tabularDigits ? ({
                            "tnum": 1
                        }) : ({})
                    text: root.verticalText
                    font.pixelSize: root.textSize
                    color: root.contentColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                NumericText {
                    isMonospace: false
                    visible: root.verticalSecondaryText !== ""
                    text: root.verticalSecondaryText
                    font.pixelSize: root.textSize
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Row {
                id: row
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: root.iconName
                    size: root.iconSize
                    color: root.levelColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    visible: root.horizontalLabel !== ""
                    text: root.horizontalLabel
                    font.pixelSize: root.textSize
                    color: root.contentColor
                    elide: Text.ElideNone
                    wrapMode: Text.NoWrap
                    anchors.verticalCenter: parent.verticalCenter
                }

                NumericText {
                    isMonospace: false
                    font.features: root.tabularDigits ? ({
                            "tnum": 1
                        }) : ({})
                    text: root.horizontalText
                    reserveText: root.minimumWidth ? root.reserveText : ""
                    width: Math.ceil(Math.max(implicitWidth, reservedWidth))
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: root.textSize
                    color: root.contentColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    MouseArea {
        visible: root.sortKey !== ""
        x: -root.leftMargin
        y: -root.topMargin
        width: root.width + root.leftMargin + root.rightMargin
        height: root.height + root.topMargin + root.bottomMargin
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onPressed: mouse => {
            root.triggerRipple(this, mouse.x, mouse.y);
            DgopService.setSortBy(root.sortKey);
            root.activated();
        }
    }
}
