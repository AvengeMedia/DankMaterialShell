pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Modules.ControlCenter
import qs.Widgets

CcTile {
    id: root

    readonly property var toplevels: host?.runningToplevels ?? []
    readonly property var appIds: {
        const ids = [];
        for (const toplevel of toplevels) {
            const id = toplevel?.appId ?? "";
            if (!ids.includes(id))
                ids.push(id);
        }
        return ids;
    }
    readonly property bool showCount: widgetData?.showCount !== false
    readonly property string countText: toplevels.length === 1 ? I18n.tr("%1 window", "singular, %1 is 1, open windows in the control center footer").arg(1) : I18n.tr("%1 windows", "plural, %1 is a count of open windows in the control center footer").arg(toplevels.length)

    opensPage: true
    title: widgetDef?.text ?? ""
    subtitle: countText
    acceptsInput: interactive && toplevels.length > 0
    onClicked: expandClicked()

    bodyContent: Component {
        Item {
            id: body

            readonly property real iconBox: Math.max(0, Math.min(CcMetrics.iconBoxSize, height - Theme.spacingS * 2))
            readonly property int iconCount: Math.max(1, Math.min(root.appIds.length, CcMetrics.runningAppsMaxIcons, Math.floor((width - Theme.spacingS * 2 + Theme.spacingXS) / (iconBox + Theme.spacingXS))))
            readonly property real chevronRoom: chevron.width + Theme.spacingXS
            readonly property real textRoom: width - Theme.spacingS * 2 - icons.width - Theme.spacingM
            // Drop the wording, then the chevron, then the count itself as the pill narrows.
            readonly property string label: {
                if (!root.showCount || root.toplevels.length === 0)
                    return "";
                if (fullMetrics.advanceWidth + chevronRoom <= textRoom)
                    return root.countText;
                return shortMetrics.advanceWidth <= textRoom ? String(root.toplevels.length) : "";
            }
            readonly property bool showChevron: label !== "" && (label === root.countText || shortMetrics.advanceWidth + chevronRoom <= textRoom)

            StyledTextMetrics {
                id: fullMetrics
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
                text: root.countText
            }

            StyledTextMetrics {
                id: shortMetrics
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
                text: String(root.toplevels.length)
            }

            Row {
                id: icons

                anchors.left: parent.left
                anchors.leftMargin: body.label === "" ? (parent.width - width) / 2 : Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS

                Repeater {
                    model: ScriptModel {
                        values: root.appIds.length > 0 ? root.appIds.slice(0, body.iconCount) : [""]
                    }

                    Rectangle {
                        required property string modelData

                        width: body.iconBox
                        height: width
                        radius: Theme.fullRadius(width, height)
                        color: CcMetrics.iconBoxInactiveColor

                        CcAppIcon {
                            anchors.centerIn: parent
                            appId: parent.modelData
                            iconSize: Math.min(CcMetrics.runningAppsIconSize, parent.width)
                        }
                    }
                }
            }

            StyledText {
                objectName: "runningAppsLabel"
                anchors.left: icons.right
                anchors.leftMargin: Theme.spacingS
                anchors.right: body.showChevron ? chevron.left : parent.right
                anchors.rightMargin: body.showChevron ? Theme.spacingXS : Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                text: body.label
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
                color: root.contentColor
                elide: Text.ElideRight
                visible: body.label !== ""
            }

            DankIcon {
                id: chevron

                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                name: I18n.isRtl ? "chevron_left" : "chevron_right"
                size: Theme.iconSizeSmall
                color: Theme.onSurfaceVariant
                visible: body.showChevron
            }
        }
    }
}
