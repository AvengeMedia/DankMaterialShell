import QtQuick
import QtQuick.Controls
import qs.Common

Item {
    id: root

    property string text: ""

    function show(text, item, offsetX, offsetY, preferredSide) {
        if (!item)
            return;

        let windowContentItem = item.Window?.window?.contentItem;
        if (!windowContentItem) {
            let current = item;
            while (current) {
                if (current.Window?.window?.contentItem) {
                    windowContentItem = current.Window.window.contentItem;
                    break;
                }
                current = current.parent;
            }
        }
        if (!windowContentItem)
            return;

        tooltip.parent = windowContentItem;
        tooltip.text = text;

        const itemPos = item.mapToItem(windowContentItem, 0, 0);
        const parentWidth = windowContentItem.width;
        const parentHeight = windowContentItem.height;
        const tooltipWidth = tooltip.implicitWidth;
        const tooltipHeight = tooltip.implicitHeight;

        const side = preferredSide || _determineBestSide(itemPos, item, parentWidth, parentHeight, tooltipWidth, tooltipHeight);

        let targetX = 0;
        let targetY = 0;

        switch (side) {
        case "left":
            targetX = itemPos.x - tooltipWidth - 8;
            targetY = itemPos.y + (item.height - tooltipHeight) / 2;
            break;
        case "right":
            targetX = itemPos.x + item.width + 8;
            targetY = itemPos.y + (item.height - tooltipHeight) / 2;
            break;
        case "top":
            targetX = itemPos.x + (item.width - tooltipWidth) / 2;
            targetY = itemPos.y - tooltipHeight - 8;
            break;
        case "bottom":
        default:
            targetX = itemPos.x + (item.width - tooltipWidth) / 2;
            targetY = itemPos.y + item.height + 8;
            break;
        }

        tooltip.x = Math.max(4, Math.min(parentWidth - tooltipWidth - 4, targetX + (offsetX || 0)));
        tooltip.y = Math.max(4, Math.min(parentHeight - tooltipHeight - 4, targetY + (offsetY || 0)));

        tooltip.open();
    }

    function _determineBestSide(itemPos, item, parentWidth, parentHeight, tooltipWidth, tooltipHeight) {
        const itemCenterX = itemPos.x + item.width / 2;
        const itemCenterY = itemPos.y + item.height / 2;

        const spaceLeft = itemPos.x;
        const spaceRight = parentWidth - (itemPos.x + item.width);
        const spaceTop = itemPos.y;
        const spaceBottom = parentHeight - (itemPos.y + item.height);

        if (spaceRight >= tooltipWidth + 16) {
            return "right";
        }
        if (spaceLeft >= tooltipWidth + 16) {
            return "left";
        }
        if (spaceBottom >= tooltipHeight + 16) {
            return "bottom";
        }
        if (spaceTop >= tooltipHeight + 16) {
            return "top";
        }

        if (itemCenterX > parentWidth / 2) {
            return "left";
        }
        return "right";
    }

    function hide() {
        tooltip.close();
    }

    Popup {
        id: tooltip

        property string text: ""

        implicitWidth: Math.min(300, Math.max(120, textContent.implicitWidth + Theme.spacingM * 2))
        implicitHeight: textContent.implicitHeight + Theme.spacingS * 2
        width: implicitWidth
        height: implicitHeight

        padding: 0
        closePolicy: Popup.NoAutoClose
        modal: false
        dim: false

        background: Rectangle {
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
            radius: Theme.cornerRadius
            border.width: 1
            border.color: Theme.outlineMedium
        }

        contentItem: Text {
            id: textContent

            text: tooltip.text
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            wrapMode: Text.NoWrap
            maximumLineCount: 1
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: Theme.shorterDuration
                easing.type: Theme.standardEasing
            }
        }
    }
}
