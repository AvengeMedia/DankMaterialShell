import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Modules.ControlCenter
import qs.Modules.DankDash
import qs.Services
import qs.Widgets
import "../utils/widgets.js" as WidgetUtils

Item {
    id: root

    property var widgetData: ({})
    property var widgetDef: null
    property var host: null
    property bool live: true
    property bool interactive: true
    property real columns: 2
    property real rows: 2
    property bool compact: false

    signal optionChanged(string key, var value)

    readonly property var savedOrder: WidgetUtils.cardOrder(widgetData)
    property var previewOrder: null
    property string draggedAction: ""
    property point dragPosition: Qt.point(0, 0)
    property point grabOffset: Qt.point(0, 0)
    readonly property var order: previewOrder ?? savedOrder
    readonly property int split: order.indexOf(WidgetUtils.CARD_IDENTITY)
    readonly property int leadingColumns: WidgetUtils.actionColumns(rows, split)
    readonly property int trailingColumns: WidgetUtils.actionColumns(rows, order.length - split - 1)
    // Grid pitch keeps card buttons in line with small tiles outside the card.
    readonly property real pitch: host?.cellWidth ?? CcMetrics.columnWidth + CcMetrics.gridGap
    readonly property real buttonInset: Math.max(0, (pitch - CcMetrics.gridGap - CcMetrics.iconBoxSize) / 2)
    readonly property real identityStart: leadingColumns * pitch
    readonly property real identityWidth: Math.max(0, width - (leadingColumns + trailingColumns) * pitch)
    readonly property bool wide: identityWidth >= height * 2
    readonly property bool background: widgetData?.background === true
    readonly property bool tall: height >= CcMetrics.gridRowUnit * 2
    readonly property real inset: background ? (tall ? Theme.spacingM : Theme.spacingS) : 0
    readonly property real avatarSide: Math.min(identityWidth, height) - inset * 2
    readonly property string shape: widgetData?.shape ?? WidgetUtils.USER_SHAPES[0]
    readonly property bool editMode: host?.editMode ?? false
    readonly property bool tapToClose: interactive && (host?.tapToClose ?? false)
    readonly property Item passthrough: passthroughArea
    // Only a bare avatar gets the circle outline; any button beside it turns the card into a pill.
    readonly property real bodyRadius: {
        if (!background && savedOrder.length === 1)
            return Theme.fullRadius(avatarSide, avatarSide);
        return tall ? Math.min(CcMetrics.tallTileRadius, width / 2, height / 2) : Theme.fullRadius(width, height);
    }
    readonly property real fallbackGlyphRatio: 0.5
    readonly property string avatarSource: PortalService.profileImageUrl
    readonly property bool hasImage: picture.status === Image.Ready

    width: parent?.width ?? 0
    height: parent?.height ?? 0
    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true
    Accessible.role: Accessible.StaticText
    Accessible.name: UserInfoService.fullName || UserInfoService.username

    function actionSlot(id) {
        const index = order.indexOf(id);
        const leading = index < split;
        const count = leading ? split : order.length - split - 1;
        const position = leading ? index : index - split - 1;
        const perLine = WidgetUtils.actionColumns(rows, count);
        const lines = Math.ceil(count / perLine);
        const size = CcMetrics.iconBoxSize;
        const start = leading ? 0 : width + CcMetrics.gridGap - trailingColumns * pitch;
        const x = start + (position % perLine) * pitch + buttonInset;
        return Qt.point(I18n.isRtl ? width - x - size : x, (height - lines * pitch + pitch - size) / 2 + Math.floor(position / perLine) * pitch);
    }

    // Splitting at the identity's centre stops a swap across it from flickering back.
    function reorderTarget(point) {
        const identityX = I18n.isRtl ? width - identityStart - identityWidth : identityStart;
        if (point.x >= identityX && point.x < identityX + identityWidth) {
            const leading = (point.x < identityX + identityWidth / 2) !== I18n.isRtl;
            return (order.indexOf(draggedAction) < split) === leading ? "" : WidgetUtils.CARD_IDENTITY;
        }
        const half = pitch / 2;
        const center = CcMetrics.iconBoxSize / 2;
        return order.find(id => {
            if (id === draggedAction || id === WidgetUtils.CARD_IDENTITY)
                return false;
            const slot = actionSlot(id);
            return Math.abs(point.x - slot.x - center) < half && Math.abs(point.y - slot.y - center) < half;
        }) ?? "";
    }

    function beginReorder(id, scenePoint) {
        const point = mapFromItem(null, scenePoint.x, scenePoint.y);
        const slot = actionSlot(id);
        grabOffset = Qt.point(point.x - slot.x, point.y - slot.y);
        dragPosition = slot;
        previewOrder = savedOrder.slice();
        draggedAction = id;
    }

    function moveReorder(scenePoint) {
        if (draggedAction === "")
            return;
        const point = mapFromItem(null, scenePoint.x, scenePoint.y);
        dragPosition = Qt.point(point.x - grabOffset.x, point.y - grabOffset.y);
        const target = reorderTarget(point);
        if (target !== "")
            previewOrder = WidgetUtils.moveInOrder(previewOrder, draggedAction, target);
    }

    function finishReorder() {
        if (draggedAction === "")
            return;
        if (JSON.stringify(previewOrder) !== JSON.stringify(savedOrder))
            optionChanged("actions", previewOrder);
        draggedAction = "";
        previewOrder = null;
    }

    function passesThrough(point) {
        const targets = [shapeButton];
        for (let i = 0; i < actionRepeater.count; i++)
            targets.push(actionRepeater.itemAt(i));
        return targets.some(item => item?.visible && item.contains(mapToItem(item, point.x, point.y)));
    }

    onEditModeChanged: finishReorder()

    Rectangle {
        anchors.fill: parent
        radius: root.bodyRadius
        color: CcMetrics.tileInactiveColor
        border.width: Theme.layerOutlineWidth
        border.color: Theme.outlineMedium
        visible: root.background
    }

    Item {
        id: identityArea

        anchors.left: parent.left
        anchors.leftMargin: root.identityStart
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.identityWidth
    }

    UserIdentity {
        anchors.fill: identityArea
        anchors.margins: root.inset
        visible: root.wide
        live: root.live && root.wide
        options: DashRegistry.resolvedOptions("user", root.widgetData)
        avatarSize: height
        stacked: root.rows >= 2
        contentColor: Theme.onSurface
        mutedColor: Theme.onSurfaceVariant
    }

    Item {
        id: avatar

        anchors.centerIn: identityArea
        width: root.avatarSide
        height: root.avatarSide
        visible: !root.wide

        DankMaterialShape {
            anchors.fill: parent
            shape: root.shape
            color: Theme.primaryContainer
            visible: !root.hasImage
        }

        DankIcon {
            anchors.centerIn: parent
            name: "person"
            size: Math.round(root.avatarSide * root.fallbackGlyphRatio)
            color: Theme.onPrimaryContainer
            filled: true
            visible: !root.hasImage
        }

        Item {
            id: avatarMask

            anchors.fill: parent
            layer.enabled: root.hasImage
            visible: false

            DankMaterialShape {
                anchors.fill: parent
                shape: root.shape
            }
        }

        Image {
            id: picture

            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            retainWhileLoading: true
            visible: root.hasImage
            sourceSize.width: Math.max(1, Math.ceil(width * Screen.devicePixelRatio))
            sourceSize.height: Math.max(1, Math.ceil(height * Screen.devicePixelRatio))
            source: avatar.visible ? root.avatarSource : ""
            layer.enabled: root.hasImage
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: avatarMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
        }
    }

    StyledButton {
        objectName: "userCloseButton"
        anchors.fill: parent
        visible: root.tapToClose
        radius: root.bodyRadius
        Accessible.name: I18n.tr("Close")
        onClicked: root.host?.closeRequested()

        FocusRing {
            visible: parent.visualFocus
        }

        StateLayer {
            control: parent
            cornerRadius: root.bodyRadius
        }
    }

    Repeater {
        id: actionRepeater

        model: ScriptModel {
            values: WidgetUtils.BUTTON_IDS.filter(id => root.savedOrder.includes(id))
        }

        Item {
            id: action

            required property string modelData
            readonly property var definition: root.host?.model?.getWidgetForId(modelData) ?? null
            readonly property point slot: root.actionSlot(modelData)
            readonly property bool held: root.draggedAction === modelData

            x: held ? root.dragPosition.x : slot.x
            y: held ? root.dragPosition.y : slot.y
            z: held ? 1 : 0
            width: CcMetrics.iconBoxSize
            height: width

            Behavior on x {
                enabled: !action.held && CcMetrics.animationsEnabled
                NumberAnimation {
                    duration: Theme.expressiveDurations.expressiveFastSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
                }
            }

            Behavior on y {
                enabled: !action.held && CcMetrics.animationsEnabled
                NumberAnimation {
                    duration: Theme.expressiveDurations.expressiveFastSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
                }
            }

            DankActionButton {
                anchors.fill: parent
                buttonSize: CcMetrics.iconBoxSize
                iconName: action.definition?.icon ?? ""
                iconSize: CcMetrics.iconBoxIconSize
                iconColor: CcMetrics.actionIconColor(action.modelData)
                backgroundColor: root.background ? "transparent" : CcMetrics.tileInactiveColor
                border.width: root.background ? 0 : Theme.layerOutlineWidth
                border.color: Theme.outlineMedium
                tooltipText: action.definition?.text ?? ""
                onClicked: {
                    if (root.interactive)
                        WidgetUtils.triggerButton(root.host, action.modelData);
                }
            }

            DragHandler {
                target: null
                enabled: root.editMode
                cursorShape: Qt.ClosedHandCursor
                onActiveChanged: {
                    if (active) {
                        root.beginReorder(action.modelData, centroid.scenePressPosition);
                        return;
                    }
                    root.finishReorder();
                }
                onCentroidChanged: {
                    if (active)
                        root.moveReorder(centroid.scenePosition);
                }
            }
        }
    }

    StyledButton {
        objectName: "userAvatarButton"
        x: identityArea.x + (!root.wide ? (identityArea.width - width) / 2 : I18n.isRtl ? identityArea.width - root.inset - width : root.inset)
        y: (root.height - height) / 2
        width: root.avatarSide
        height: root.avatarSide
        radius: Theme.fullRadius(width, height)
        visible: root.interactive
        Accessible.name: I18n.tr("Users & accounts", "settings sidebar category")
        onClicked: root.host?.accountsRequested()

        FocusRing {
            visible: parent.visualFocus
        }

        StateLayer {
            control: parent
            cornerRadius: parent.radius
            tooltipText: parent.Accessible.name
        }
    }

    DankActionButton {
        id: shapeButton

        anchors.bottom: avatar.bottom
        anchors.left: avatar.left
        buttonSize: CcMetrics.shapeButtonSize
        iconSize: Theme.iconSizeSmall
        iconName: "shuffle"
        iconColor: Theme.onSurface
        backgroundColor: Theme.surfaceContainerHighest
        Accessible.name: I18n.tr("Shuffle")
        visible: root.editMode && avatar.visible
        onClicked: root.optionChanged("shape", WidgetUtils.nextUserShape(root.shape))
    }

    // Edit-mode grid input skips these points so the shape and card buttons stay clickable.
    Item {
        id: passthroughArea

        anchors.fill: parent
        containmentMask: QtObject {
            function contains(point: point): bool {
                return root.passesThrough(point);
            }
        }
    }
}
