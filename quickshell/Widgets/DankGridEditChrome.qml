import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string sizeText: ""
    property bool dragging: false
    property bool resizing: false
    property bool hasOptions: false
    property bool atDefault: false
    property bool removable: true
    property bool horizontalResize: false
    property bool edgeResize: false
    property real cornerRadius: Theme.cornerRadiusXL
    property real buttonSize: Theme.iconSizeLarge
    property real iconSize: Theme.iconSizeSmall
    property real edgeBandWidth: Theme.spacingL
    readonly property real touchTargetSize: Math.max(Theme.minimumTouchTargetSize, buttonSize)
    readonly property real contentInset: touchTargetSize / 2
    readonly property bool showOptionsButton: hasOptions && width - contentInset * 2 >= touchTargetSize * (horizontalResize ? 3 : 2)

    signal removeRequested
    signal optionsRequested(var anchor)
    signal resizeStarted(real px, real py, int signX)
    signal resizeCanceled
    signal resizeMoved(real px, real py)
    signal resizeEnded

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.contentInset
        radius: root.cornerRadius
        color: root.dragging || root.resizing ? Theme.withAlpha(Theme.primary, Theme.stateLayerDrag) : "transparent"
        border.color: Theme.primary
        border.width: Theme.outlineWidthFocused
    }

    Rectangle {
        x: I18n.isRtl ? root.width - root.contentInset - width - (root.touchTargetSize - root.buttonSize) / 2 : root.contentInset + (root.touchTargetSize - root.buttonSize) / 2
        y: root.contentInset - height / 2
        width: root.buttonSize + (root.showOptionsButton ? root.touchTargetSize : 0)
        height: root.buttonSize
        radius: Theme.fullRadius(width, height)
        color: Theme.surfaceContainerHighest
        border.color: Theme.primary
        border.width: Theme.outlineWidth
        visible: root.removable
    }

    DankActionButton {
        id: removeButton

        x: I18n.isRtl ? root.width - root.contentInset - width : root.contentInset
        y: 0
        width: root.touchTargetSize
        height: root.touchTargetSize
        buttonSize: root.buttonSize
        iconSize: root.iconSize
        iconName: "close"
        iconColor: Theme.error
        tooltipText: I18n.tr("Remove")
        visible: root.removable
        enabled: !root.dragging && !root.resizing
        onClicked: root.removeRequested()
        onPressAndHold: {
            if (root.hasOptions)
                root.optionsRequested(removeButton);
        }
        Shortcut {
            sequences: ["Menu", "Shift+F10"]
            enabled: root.hasOptions && removeButton.activeFocus && removeButton.enabled
            onActivated: root.optionsRequested(removeButton)
        }
    }

    DankActionButton {
        id: optionsButton

        x: I18n.isRtl ? root.width - root.contentInset - root.touchTargetSize - width : root.contentInset + root.touchTargetSize
        y: 0
        width: root.touchTargetSize
        height: root.touchTargetSize
        buttonSize: root.buttonSize
        iconSize: root.iconSize
        iconName: "tune"
        iconColor: Theme.primary
        tooltipText: I18n.tr("Options")
        visible: root.showOptionsButton
        enabled: !root.dragging && !root.resizing
        onClicked: root.optionsRequested(optionsButton)
    }

    Rectangle {
        anchors.centerIn: parent
        width: sizeLabel.implicitWidth + Theme.spacingM * 2
        height: root.buttonSize
        radius: Theme.fullRadius(width, height)
        color: root.atDefault ? Theme.primary : Theme.surfaceContainerHighest
        visible: root.resizing && root.sizeText.length > 0

        StyledText {
            id: sizeLabel
            anchors.centerIn: parent
            text: root.sizeText
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Theme.fontWeightMedium
            color: root.atDefault ? Theme.onPrimary : Theme.surfaceText
        }
    }

    readonly property real gripRadius: Math.max(0, Math.min(cornerRadius, width / 2 - contentInset, height / 2 - contentInset) - Theme.outlineWidthFocused / 2)
    readonly property real handleOverhang: edgeResize ? contentInset : Theme.spacingS / 2
    readonly property real gripInset: handleOverhang - Theme.spacingS / 2

    component ResizeBand: MouseArea {
        property int signX: 1
        property bool lockX: false
        property bool lockY: false
        property real startX: 0
        property real startY: 0

        enabled: visible && !root.dragging
        hoverEnabled: true
        preventStealing: true

        onPressed: mouse => {
            const p = mapToItem(root, mouse.x, mouse.y);
            startX = p.x - root.contentInset;
            startY = p.y - root.contentInset;
            root.resizeStarted(startX, startY, signX);
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const p = mapToItem(root, mouse.x, mouse.y);
            root.resizeMoved(lockX ? startX : p.x - root.contentInset, lockY ? startY : p.y - root.contentInset);
        }
        onReleased: root.resizeEnded()
        onCanceled: root.resizeCanceled()
    }

    component Handle: Item {
        id: handleItem

        property int signX: 1
        readonly property bool diagonalFlipped: (signX > 0) === I18n.isRtl

        y: root.horizontalResize ? (root.height - height) / 2 : root.height - root.contentInset - height + root.handleOverhang
        width: root.touchTargetSize
        height: root.touchTargetSize

        Rectangle {
            anchors.centerIn: parent
            width: Theme.spacingM
            height: root.buttonSize
            radius: Theme.fullRadius(width, height)
            color: Theme.primary
            visible: root.horizontalResize
        }

        DankResizeGrip {
            anchors.fill: parent
            anchors.leftMargin: handleItem.signX < 0 ? root.gripInset : 0
            anchors.rightMargin: handleItem.signX > 0 ? root.gripInset : 0
            anchors.bottomMargin: root.gripInset
            visible: !root.horizontalResize
            gripRadius: root.gripRadius
            mirrored: handleItem.diagonalFlipped
        }

        ResizeBand {
            anchors.fill: parent
            signX: handleItem.signX
            cursorShape: root.horizontalResize ? Qt.SizeHorCursor : (handleItem.diagonalFlipped ? Qt.SizeBDiagCursor : Qt.SizeFDiagCursor)
        }
    }

    Handle {
        anchors.right: parent.right
        anchors.rightMargin: root.contentInset - (root.horizontalResize ? width / 2 : root.handleOverhang)
        z: 1
    }

    Loader {
        anchors.fill: parent
        active: root.edgeResize && root.visible

        sourceComponent: Item {
            ResizeBand {
                anchors.right: parent.right
                anchors.rightMargin: root.contentInset - root.edgeBandWidth / 2
                y: root.contentInset - root.edgeBandWidth / 2
                width: root.edgeBandWidth
                height: root.height - root.contentInset * 2 + root.edgeBandWidth
                lockY: true
                cursorShape: Qt.SizeHorCursor
            }

            ResizeBand {
                anchors.left: parent.left
                anchors.leftMargin: root.contentInset - root.edgeBandWidth / 2
                y: root.contentInset - root.edgeBandWidth / 2
                width: root.edgeBandWidth
                height: root.height - root.contentInset * 2 + root.edgeBandWidth
                signX: -1
                lockY: true
                cursorShape: Qt.SizeHorCursor
            }

            ResizeBand {
                anchors.left: parent.left
                anchors.leftMargin: root.contentInset - root.edgeBandWidth / 2
                y: root.height - root.contentInset - root.edgeBandWidth / 2
                width: root.width - root.contentInset * 2 + root.edgeBandWidth
                height: root.edgeBandWidth
                visible: !root.horizontalResize
                lockX: true
                cursorShape: Qt.SizeVerCursor
            }

            Handle {
                anchors.left: parent.left
                anchors.leftMargin: root.contentInset - (root.horizontalResize ? width / 2 : root.handleOverhang)
                signX: -1
            }
        }
    }
}
