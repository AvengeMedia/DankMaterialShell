pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.ControlCenter.Widgets
import qs.Modules.DankDash.Overview
import "../../Common/GridLayout.js" as GridUtils
import "utils/widgets.js" as WidgetUtils
import "../../DankCommon/Common/FocusNavigation.js" as FocusNavigation

Item {
    id: root

    property string entryId: ""
    property var definitions: []
    property bool editMode: false
    property bool live: Window.window?.visible ?? false
    property int columns: width < Theme.smallBreakpoint ? 2 : 4
    property real cardRadius: Theme.cornerRadiusXL
    readonly property var widgets: WidgetUtils.resolve(definitions, DashRegistry.widgetLayout(entryId))
    readonly property var addable: definitions.filter(d => !widgets.some(w => w.id === d.id))
    readonly property Item focusTarget: grid
    readonly property bool blocksTabNavigation: editMode || addMenu.open || widgetMenu.open
    readonly property bool cardResizing: grid.sizePreview !== null

    implicitHeight: Math.max(DashMetrics.tabMinHeight, grid.implicitHeight)
    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    function save(items) {
        DashRegistry.setWidgetLayout(entryId, items);
    }

    function resetWidgets() {
        DashRegistry.setWidgetLayout(entryId, null);
    }

    function clearWidgets() {
        save([]);
    }

    function openAddMenu(anchor) {
        addMenu.openAt(anchor);
    }

    function focusTargets() {
        const targets = [];
        function collect(item) {
            if (!item.visible || !item.enabled)
                return;
            if (item.activeFocusOnTab) {
                targets.push(item);
                return;
            }
            for (const child of item.children)
                collect(child);
        }
        for (let i = 0; i < slots.count; i++) {
            const slot = slots.itemAt(i);
            if (slot)
                collect(slot);
        }
        return targets;
    }

    function cycleFocus(backwards) {
        return FocusNavigation.moveFocus(focusTargets(), backwards);
    }

    function revealFocus() {
        const target = root.Window.window?.activeFocusItem;
        if (!target)
            return;
        let ancestor = target.parent;
        while (ancestor && ancestor !== root)
            ancestor = ancestor.parent;
        if (!ancestor)
            return;
        while (ancestor && !("contentY" in ancestor && "contentHeight" in ancestor))
            ancestor = ancestor.parent;
        if (!ancestor)
            return;
        const point = target.mapToItem(ancestor, 0, 0);
        let offset = 0;
        if (point.y < Theme.spacingS)
            offset = point.y - Theme.spacingS;
        if (point.y + target.height > ancestor.height - Theme.spacingS)
            offset = point.y + target.height - ancestor.height + Theme.spacingS;
        ancestor.contentY = Math.max(0, Math.min(ancestor.contentHeight - ancestor.height, ancestor.contentY + offset));
    }

    readonly property Item windowFocusItem: Window.activeFocusItem
    onWindowFocusItemChanged: {
        if (live)
            revealFocus();
    }

    function specFor(id) {
        return definitions.find(d => d.id === id) ?? null;
    }

    function updateWidget(index, changes) {
        grid.commitChange(index, changes);
    }

    function handleKeyEvent(event) {
        if (event.key !== Qt.Key_Escape || !(addMenu.open || widgetMenu.open))
            return false;
        addMenu.close();
        widgetMenu.close();
        return true;
    }

    onEditModeChanged: {
        addMenu.close();
        widgetMenu.close();
    }

    DankEditableGrid {
        id: grid
        width: parent.width
        editMode: root.editMode
        sourceItems: root.widgets
        slotLayout: GridUtils.packCards(layoutItems, placementOrder, root.columns, width, DashMetrics.gridGap, DashMetrics.gridRowUnit, I18n.isRtl, id => root.specFor(id) !== null)
        onLayoutCommitted: items => root.save(WidgetUtils.resolve(root.definitions, items))

        function requestFocus(backwards) {
            const targets = root.focusTargets();
            FocusNavigation.focusItem(backwards ? targets[targets.length - 1] : targets[0], backwards);
        }

        Repeater {
            id: slots
            model: grid.tileModel

            DankEditableGridSlot {
                id: slot
                grid: grid
                readonly property var widget: JSON.parse(json)
                readonly property var spec: root.specFor(widget.id)

                onResizeRequested: (requestedWidth, requestedHeight) => {
                    const cellWidth = (grid.width + DashMetrics.gridGap) / root.columns;
                    grid.previewSize(index, {
                        w: GridUtils.dimension(Math.round((requestedWidth + DashMetrics.gridGap) / cellWidth), spec.minW, spec.maxW, spec.w),
                        h: GridUtils.dimension(Math.round((requestedHeight + DashMetrics.gridGap) / (DashMetrics.gridRowUnit + DashMetrics.gridGap)), spec.minH, spec.maxH, spec.h)
                    });
                }

                Loader {
                    id: content
                    anchors.fill: parent
                    sourceComponent: slot.spec?.component ?? null
                    active: root.live && slot.spec !== null
                    enabled: !root.editMode
                    clip: true
                    onLoaded: {
                        if ("live" in item)
                            item.live = Qt.binding(() => root.live);
                        if ("widgetId" in item)
                            item.widgetId = slot.widget.id;
                        if ("widgetOptions" in item)
                            item.widgetOptions = Qt.binding(() => slot.widget);
                    }
                }

                DashEditChrome {
                    anchors.fill: parent
                    anchors.margins: -contentInset
                    z: 2
                    visible: root.editMode
                    enabled: slot.interactionEnabled
                    cornerRadius: root.cardRadius
                    dragging: slot.dragging
                    resizing: slot.resizing
                    hasOptions: true
                    sizeText: (grid.sizePreview?.index === slot.index ? grid.sizePreview.changes.w : slot.widget.w) + "×" + (grid.sizePreview?.index === slot.index ? grid.sizePreview.changes.h : slot.widget.h)
                    onRemoveRequested: root.save(root.widgets.filter((w, i) => i !== slot.index))
                    onOptionsRequested: anchor => {
                        widgetMenu.widgetId = slot.widget.id;
                        widgetMenu.openAt(anchor);
                    }
                    onResizeStarted: (px, py) => slot.beginResize(px, py)
                    onResizeMoved: (px, py) => slot.resizeTo(px, py)
                    onResizeEnded: slot.finishResize()
                    onResizeCanceled: slot.cancelResize()
                }
            }
        }
    }

    CcEmptyState {
        anchors.centerIn: parent
        visible: root.widgets.length === 0
        iconName: "widgets"
        title: I18n.tr("No widgets")
        subtitle: I18n.tr("Add widget")
    }

    CcMenu {
        id: addMenu
        parent: root.Window.window?.contentItem ?? root
        items: root.addable.map(spec => ({
                    label: spec.text,
                    iconName: spec.icon,
                    action: () => root.save(WidgetUtils.resolve(root.definitions, root.widgets.concat([
                            {
                                id: spec.id
                            }
                        ])))
                }))
    }

    CcMenu {
        id: widgetMenu
        parent: root.Window.window?.contentItem ?? root
        property string widgetId: ""
        readonly property int widgetIndex: root.widgets.findIndex(w => w.id === widgetId)
        readonly property var widget: root.widgets[widgetIndex] ?? {}
        readonly property var spec: root.specFor(widgetId)
        readonly property int row: grid.slotLayout.slots[widgetIndex]?.row ?? 0
        items: [
            {
                label: I18n.tr("Move up"),
                iconName: "arrow_upward",
                enabled: row > 0,
                action: () => root.updateWidget(widgetIndex, {
                        row: row - 1
                    })
            },
            {
                label: I18n.tr("Move down"),
                iconName: "arrow_downward",
                enabled: widgetIndex >= 0,
                action: () => root.updateWidget(widgetIndex, {
                        row: row + 1
                    })
            },
            {
                label: I18n.tr("Width", "noun, size label, also used in widget resize menu") + " +",
                iconName: "add",
                enabled: widget.w < (spec?.maxW ?? spec?.w ?? 1),
                action: () => root.updateWidget(widgetIndex, {
                        w: widget.w + 1
                    })
            },
            {
                label: I18n.tr("Width") + " −",
                iconName: "remove",
                enabled: widget.w > (spec?.minW ?? 1),
                action: () => root.updateWidget(widgetIndex, {
                        w: widget.w - 1
                    })
            },
            {
                label: I18n.tr("Height", "noun, size label, also used in widget resize menu") + " +",
                iconName: "add",
                enabled: widget.h < (spec?.maxH ?? spec?.h ?? 1),
                action: () => root.updateWidget(widgetIndex, {
                        h: widget.h + 1
                    })
            },
            {
                label: I18n.tr("Height") + " −",
                iconName: "remove",
                enabled: widget.h > (spec?.minH ?? 1),
                action: () => root.updateWidget(widgetIndex, {
                        h: widget.h - 1
                    })
            },
            {
                label: I18n.tr("Show graphics", "Dashboard widget option for decorative data graphics"),
                iconName: widget.graphics ? "check_box" : "check_box_outline_blank",
                visible: spec?.graphics === true,
                action: () => root.updateWidget(widgetIndex, {
                        graphics: !widget.graphics
                    })
            }
        ]
    }
}
