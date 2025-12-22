import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    required property string pluginId
    required property var screen

    property var builtinComponent: null
    property var pluginService: null
    property string instanceId: ""
    property var instanceData: null

    readonly property bool isBuiltin: pluginId === "desktopClock" || pluginId === "systemMonitor"
    readonly property var activeComponent: isBuiltin ? builtinComponent : PluginService.pluginDesktopComponents[pluginId] ?? null

    Connections {
        target: PluginService
        enabled: !root.isBuiltin

        function onPluginLoaded(loadedPluginId) {
            if (loadedPluginId === root.pluginId)
                contentLoader.reloadComponent();
        }

        function onPluginUnloaded(unloadedPluginId) {
            if (unloadedPluginId === root.pluginId)
                contentLoader.reloadComponent();
        }
    }

    readonly property string settingsKey: instanceId ? instanceId : pluginId
    readonly property bool isInstance: instanceId !== "" && instanceData !== null
    readonly property bool usePluginService: pluginService !== null && !isInstance

    QtObject {
        id: instanceScopedPluginService

        readonly property var availablePlugins: PluginService.availablePlugins
        readonly property var loadedPlugins: PluginService.loadedPlugins
        readonly property var pluginDesktopComponents: PluginService.pluginDesktopComponents

        signal pluginDataChanged(string pluginId)
        signal pluginLoaded(string pluginId)
        signal pluginUnloaded(string pluginId)

        function loadPluginData(pluginId, key, defaultValue) {
            const cfg = root.instanceData?.config;
            if (cfg && key in cfg)
                return cfg[key];
            return SettingsData.getPluginSetting(pluginId, key, defaultValue);
        }

        function savePluginData(pluginId, key, value) {
            if (!root.instanceId)
                return false;
            var updates = {};
            updates[key] = value;
            SettingsData.updateDesktopWidgetInstanceConfig(root.instanceId, updates);
            Qt.callLater(() => pluginDataChanged(pluginId));
            return true;
        }

        function getPluginVariants(pluginId) {
            return PluginService.getPluginVariants(pluginId);
        }

        function isPluginLoaded(pluginId) {
            return PluginService.isPluginLoaded(pluginId);
        }
    }
    readonly property string screenKey: SettingsData.getScreenDisplayName(screen)

    readonly property int screenWidth: screen?.width ?? 1920
    readonly property int screenHeight: screen?.height ?? 1080

    readonly property bool useGhostPreview: !CompositorService.isNiri

    property real previewX: widgetX
    property real previewY: widgetY
    property real previewWidth: widgetWidth
    property real previewHeight: widgetHeight

    readonly property bool hasSavedPosition: {
        if (isInstance)
            return instanceData?.positions?.[screenKey]?.x !== undefined;
        if (usePluginService)
            return pluginService.loadPluginData(pluginId, "desktopX_" + screenKey, null) !== null;
        return SettingsData.getDesktopWidgetPosition(pluginId, screenKey, "x", null) !== null;
    }

    readonly property bool hasSavedSize: {
        if (isInstance)
            return instanceData?.positions?.[screenKey]?.width !== undefined;
        if (usePluginService)
            return pluginService.loadPluginData(pluginId, "desktopWidth_" + screenKey, null) !== null;
        return SettingsData.getDesktopWidgetPosition(pluginId, screenKey, "width", null) !== null;
    }

    property real savedX: {
        if (isInstance)
            return instanceData?.positions?.[screenKey]?.x ?? (screenWidth / 2 - savedWidth / 2);
        if (usePluginService)
            return pluginService.loadPluginData(pluginId, "desktopX_" + screenKey, screenWidth / 2 - savedWidth / 2);
        return SettingsData.getDesktopWidgetPosition(pluginId, screenKey, "x", screenWidth / 2 - savedWidth / 2);
    }
    property real savedY: {
        if (isInstance)
            return instanceData?.positions?.[screenKey]?.y ?? (screenHeight / 2 - savedHeight / 2);
        if (usePluginService)
            return pluginService.loadPluginData(pluginId, "desktopY_" + screenKey, screenHeight / 2 - savedHeight / 2);
        return SettingsData.getDesktopWidgetPosition(pluginId, screenKey, "y", screenHeight / 2 - savedHeight / 2);
    }
    property real savedWidth: {
        if (isInstance)
            return instanceData?.positions?.[screenKey]?.width ?? 280;
        if (usePluginService)
            return pluginService.loadPluginData(pluginId, "desktopWidth_" + screenKey, 200);
        return SettingsData.getDesktopWidgetPosition(pluginId, screenKey, "width", 280);
    }
    property real savedHeight: {
        if (isInstance)
            return instanceData?.positions?.[screenKey]?.height ?? 180;
        if (usePluginService)
            return pluginService.loadPluginData(pluginId, "desktopHeight_" + screenKey, 200);
        return SettingsData.getDesktopWidgetPosition(pluginId, screenKey, "height", 180);
    }

    property real widgetX: Math.max(0, Math.min(savedX, screenWidth - widgetWidth))
    property real widgetY: Math.max(0, Math.min(savedY, screenHeight - widgetHeight))
    property real widgetWidth: Math.max(minWidth, Math.min(savedWidth, screenWidth))
    property real widgetHeight: Math.max(minHeight, Math.min(savedHeight, screenHeight))

    property real minWidth: contentLoader.item?.minWidth ?? 100
    property real minHeight: contentLoader.item?.minHeight ?? 100
    property bool forceSquare: contentLoader.item?.forceSquare ?? false
    property bool isInteracting: dragArea.pressed || resizeArea.pressed

    property var _gridSettingsTrigger: SettingsData.desktopWidgetGridSettings
    readonly property int gridSize: {
        void _gridSettingsTrigger;
        return SettingsData.getDesktopWidgetGridSetting(screenKey, "size", 40);
    }
    readonly property bool gridEnabled: {
        void _gridSettingsTrigger;
        return SettingsData.getDesktopWidgetGridSetting(screenKey, "enabled", false);
    }

    function snapToGrid(value) {
        return Math.round(value / gridSize) * gridSize;
    }

    function savePosition() {
        if (isInstance && instanceData) {
            SettingsData.updateDesktopWidgetInstancePosition(instanceId, screenKey, {
                x: root.widgetX,
                y: root.widgetY
            });
            return;
        }
        if (usePluginService) {
            pluginService.savePluginData(pluginId, "desktopX_" + screenKey, root.widgetX);
            pluginService.savePluginData(pluginId, "desktopY_" + screenKey, root.widgetY);
            return;
        }
        SettingsData.updateDesktopWidgetPosition(pluginId, screenKey, {
            x: root.widgetX,
            y: root.widgetY
        });
    }

    function saveSize() {
        if (isInstance && instanceData) {
            SettingsData.updateDesktopWidgetInstancePosition(instanceId, screenKey, {
                width: root.widgetWidth,
                height: root.widgetHeight
            });
            return;
        }
        if (usePluginService) {
            pluginService.savePluginData(pluginId, "desktopWidth_" + screenKey, root.widgetWidth);
            pluginService.savePluginData(pluginId, "desktopHeight_" + screenKey, root.widgetHeight);
            return;
        }
        SettingsData.updateDesktopWidgetPosition(pluginId, screenKey, {
            width: root.widgetWidth,
            height: root.widgetHeight
        });
    }

    PanelWindow {
        id: widgetWindow
        screen: root.screen
        visible: root.visible && root.activeComponent !== null
        color: "transparent"

        WlrLayershell.namespace: "quickshell:desktop-widget:" + root.pluginId + (root.instanceId ? ":" + root.instanceId : "")
        WlrLayershell.layer: root.isInteracting && !CompositorService.useHyprlandFocusGrab ? WlrLayer.Overlay : WlrLayer.Bottom
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: {
            if (!root.isInteracting)
                return WlrKeyboardFocus.None;
            if (CompositorService.useHyprlandFocusGrab)
                return WlrKeyboardFocus.OnDemand;
            return WlrKeyboardFocus.Exclusive;
        }

        HyprlandFocusGrab {
            active: CompositorService.isHyprland && root.isInteracting
            windows: [widgetWindow]
        }

        Item {
            anchors.fill: parent
            focus: root.isInteracting

            Keys.onPressed: event => {
                if (!root.isInteracting)
                    return;
                switch (event.key) {
                case Qt.Key_G:
                    SettingsData.setDesktopWidgetGridSetting(root.screenKey, "enabled", !root.gridEnabled);
                    event.accepted = true;
                    break;
                case Qt.Key_Z:
                    SettingsData.setDesktopWidgetGridSetting(root.screenKey, "size", Math.max(10, root.gridSize - 10));
                    event.accepted = true;
                    break;
                case Qt.Key_X:
                    SettingsData.setDesktopWidgetGridSetting(root.screenKey, "size", Math.min(200, root.gridSize + 10));
                    event.accepted = true;
                    break;
                }
            }
        }

        anchors {
            left: true
            top: true
        }

        WlrLayershell.margins {
            left: root.widgetX
            top: root.widgetY
        }

        implicitWidth: root.widgetWidth
        implicitHeight: root.widgetHeight

        Loader {
            id: contentLoader
            anchors.fill: parent
            sourceComponent: root.activeComponent

            function reloadComponent() {
                active = false;
                active = true;
            }

            function updateInstanceData() {
                if (!item || item.instanceData === undefined)
                    return;
                item.instanceData = root.instanceData;
            }

            Connections {
                target: root
                enabled: contentLoader.item !== null

                function onInstanceDataChanged() {
                    contentLoader.updateInstanceData();
                }
            }

            onLoaded: {
                if (!item)
                    return;

                if (item.pluginService !== undefined) {
                    item.pluginService = root.isInstance ? instanceScopedPluginService : root.pluginService;
                }
                if (item.pluginId !== undefined)
                    item.pluginId = root.pluginId;
                if (item.instanceId !== undefined)
                    item.instanceId = root.instanceId;
                if (item.instanceData !== undefined)
                    item.instanceData = root.instanceData;
                if (!root.hasSavedSize) {
                    const defW = item.defaultWidth ?? item.widgetWidth ?? 280;
                    const defH = item.defaultHeight ?? item.widgetHeight ?? 180;
                    root.widgetWidth = Math.max(root.minWidth, Math.min(defW, root.screenWidth));
                    root.widgetHeight = Math.max(root.minHeight, Math.min(defH, root.screenHeight));
                }
                if (!root.hasSavedPosition) {
                    root.widgetX = Math.max(0, Math.min(root.screenWidth / 2 - root.widgetWidth / 2, root.screenWidth - root.widgetWidth));
                    root.widgetY = Math.max(0, Math.min(root.screenHeight / 2 - root.widgetHeight / 2, root.screenHeight - root.widgetHeight));
                }
                if (item.widgetWidth !== undefined)
                    item.widgetWidth = Qt.binding(() => contentLoader.width);
                if (item.widgetHeight !== undefined)
                    item.widgetHeight = Qt.binding(() => contentLoader.height);
            }
        }

        Rectangle {
            id: interactionBorder
            anchors.fill: parent
            color: "transparent"
            border.color: Theme.primary
            border.width: 2
            radius: Theme.cornerRadius
            visible: root.isInteracting && !root.useGhostPreview
            opacity: 0.8

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 48
                height: 48
                topLeftRadius: Theme.cornerRadius
                bottomRightRadius: Theme.cornerRadius
                color: Theme.primary
                opacity: resizeArea.pressed ? 1 : 0.6
            }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor

            property point startPos
            property real startX
            property real startY

            onPressed: mouse => {
                startPos = root.useGhostPreview ? Qt.point(mouse.x, mouse.y) : mapToGlobal(mouse.x, mouse.y);
                startX = root.widgetX;
                startY = root.widgetY;
                root.previewX = root.widgetX;
                root.previewY = root.widgetY;
            }

            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                const currentPos = root.useGhostPreview ? Qt.point(mouse.x, mouse.y) : mapToGlobal(mouse.x, mouse.y);
                let newX = Math.max(0, Math.min(startX + currentPos.x - startPos.x, root.screenWidth - root.widgetWidth));
                let newY = Math.max(0, Math.min(startY + currentPos.y - startPos.y, root.screenHeight - root.widgetHeight));
                if (root.gridEnabled) {
                    newX = Math.max(0, Math.min(root.snapToGrid(newX), root.screenWidth - root.widgetWidth));
                    newY = Math.max(0, Math.min(root.snapToGrid(newY), root.screenHeight - root.widgetHeight));
                }
                if (root.useGhostPreview) {
                    root.previewX = newX;
                    root.previewY = newY;
                    return;
                }
                root.widgetX = newX;
                root.widgetY = newY;
            }

            onReleased: {
                if (root.useGhostPreview) {
                    root.widgetX = root.previewX;
                    root.widgetY = root.previewY;
                }
                root.savePosition();
            }
        }

        MouseArea {
            id: resizeArea
            width: 48
            height: 48
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            acceptedButtons: Qt.RightButton
            cursorShape: pressed ? Qt.SizeFDiagCursor : Qt.ArrowCursor

            property point startPos
            property real startWidth
            property real startHeight

            onPressed: mouse => {
                startPos = root.useGhostPreview ? Qt.point(mouse.x, mouse.y) : mapToGlobal(mouse.x, mouse.y);
                startWidth = root.widgetWidth;
                startHeight = root.widgetHeight;
                root.previewWidth = root.widgetWidth;
                root.previewHeight = root.widgetHeight;
            }

            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                const currentPos = root.useGhostPreview ? Qt.point(mouse.x, mouse.y) : mapToGlobal(mouse.x, mouse.y);
                let newW = Math.max(root.minWidth, Math.min(startWidth + currentPos.x - startPos.x, root.screenWidth - root.widgetX));
                let newH = Math.max(root.minHeight, Math.min(startHeight + currentPos.y - startPos.y, root.screenHeight - root.widgetY));
                if (root.gridEnabled) {
                    newW = Math.max(root.minWidth, root.snapToGrid(newW));
                    newH = Math.max(root.minHeight, root.snapToGrid(newH));
                }
                if (root.forceSquare) {
                    const size = Math.max(newW, newH);
                    newW = Math.min(size, root.screenWidth - root.widgetX);
                    newH = Math.min(size, root.screenHeight - root.widgetY);
                }
                if (root.useGhostPreview) {
                    root.previewWidth = newW;
                    root.previewHeight = newH;
                    return;
                }
                root.widgetWidth = newW;
                root.widgetHeight = newH;
            }

            onReleased: {
                if (root.useGhostPreview) {
                    root.widgetWidth = root.previewWidth;
                    root.widgetHeight = root.previewHeight;
                }
                root.saveSize();
            }
        }
    }

    Loader {
        active: root.isInteracting && root.useGhostPreview

        sourceComponent: PanelWindow {
            id: ghostPreviewWindow
            screen: root.screen
            color: "transparent"

            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }

            mask: Region {}

            WlrLayershell.namespace: "quickshell:desktop-widget-preview"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Item {
                id: gridOverlay
                anchors.fill: parent
                visible: root.gridEnabled
                opacity: 0.3

                Repeater {
                    model: Math.ceil(root.screenWidth / root.gridSize)

                    Rectangle {
                        required property int index
                        x: index * root.gridSize
                        y: 0
                        width: 1
                        height: root.screenHeight
                        color: Theme.primary
                    }
                }

                Repeater {
                    model: Math.ceil(root.screenHeight / root.gridSize)

                    Rectangle {
                        required property int index
                        x: 0
                        y: index * root.gridSize
                        width: root.screenWidth
                        height: 1
                        color: Theme.primary
                    }
                }
            }

            Rectangle {
                x: root.previewX
                y: root.previewY
                width: root.previewWidth
                height: root.previewHeight
                color: "transparent"
                border.color: Theme.primary
                border.width: 2
                radius: Theme.cornerRadius

                Rectangle {
                    width: 48
                    height: 48
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                    }
                    topLeftRadius: Theme.cornerRadius
                    bottomRightRadius: Theme.cornerRadius
                    color: Theme.primary
                    opacity: resizeArea.pressed ? 1 : 0.6
                }
            }
        }
    }

    Loader {
        active: root.isInteracting && root.gridEnabled && !root.useGhostPreview

        sourceComponent: PanelWindow {
            screen: root.screen
            color: "transparent"

            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }

            mask: Region {}

            WlrLayershell.namespace: "quickshell:desktop-widget-grid"
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Item {
                anchors.fill: parent
                opacity: 0.3

                Repeater {
                    model: Math.ceil(root.screenWidth / root.gridSize)

                    Rectangle {
                        required property int index
                        x: index * root.gridSize
                        y: 0
                        width: 1
                        height: root.screenHeight
                        color: Theme.primary
                    }
                }

                Repeater {
                    model: Math.ceil(root.screenHeight / root.gridSize)

                    Rectangle {
                        required property int index
                        x: 0
                        y: index * root.gridSize
                        width: root.screenWidth
                        height: 1
                        color: Theme.primary
                    }
                }
            }
        }
    }

    Loader {
        active: root.isInteracting

        sourceComponent: PanelWindow {
            id: helperWindow
            screen: root.screen
            color: "transparent"

            WlrLayershell.namespace: "quickshell:desktop-widget-helper"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                bottom: true
                left: true
                right: true
            }

            implicitHeight: 60

            Rectangle {
                id: helperContent
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.spacingL
                width: helperRow.implicitWidth + Theme.spacingM * 2
                height: 32
                radius: Theme.cornerRadius
                color: Theme.surface

                Row {
                    id: helperRow
                    anchors.centerIn: parent
                    spacing: Theme.spacingM
                    height: parent.height

                    DankIcon {
                        name: "grid_on"
                        size: 16
                        color: root.gridEnabled ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: root.gridEnabled ? I18n.tr("Grid: ON", "Widget grid snap status") : I18n.tr("Grid: OFF", "Widget grid snap status")
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        color: root.gridEnabled ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 1
                        height: 16
                        color: Theme.outline
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: root.gridSize + "px"
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 1
                        height: 16
                        color: Theme.outline
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: I18n.tr("G: grid • Z/X: size", "Widget grid keyboard hints")
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        font.italic: true
                        color: Theme.surfaceText
                        opacity: 0.7
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
