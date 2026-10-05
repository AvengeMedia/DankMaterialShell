import QtQuick
import qs.Common

QtObject {
    id: root

    property string instanceId: ""
    property var instanceData: null
    property var screen: null
    property real minWidth: 100
    property real minHeight: 100
    property bool forceSquare: false
    property bool lockScreen: false

    readonly property bool isInstance: instanceId !== "" && instanceData !== null
    readonly property bool syncPositionAcrossScreens: instanceData?.config?.syncPositionAcrossScreens ?? false
    readonly property string screenKey: SettingsData.getScreenDisplayName(screen)
    readonly property string positionKey: syncPositionAcrossScreens ? "_synced" : screenKey
    readonly property var storedPositions: SessionData.desktopWidgetInstancePositions[instanceId] ?? null

    readonly property int screenWidth: screen?.width ?? 1920
    readonly property int screenHeight: screen?.height ?? 1080

    function storedGeometry(key) {
        if (!isInstance)
            return undefined;
        return storedPositions?.[positionKey]?.[key];
    }

    function storedCoordinate(key, extent, fallback) {
        const val = storedGeometry(key);
        if (val === undefined)
            return fallback;
        return syncPositionAcrossScreens ? val * extent : val;
    }

    readonly property bool hasSavedPosition: storedGeometry("x") !== undefined
    readonly property bool hasSavedSize: storedGeometry("width") !== undefined

    property real defaultWidth: 280
    property real defaultHeight: 180
    property real defaultX: screenWidth / 2 - savedWidth / 2
    property real defaultY: screenHeight / 2 - savedHeight / 2

    readonly property real savedX: storedCoordinate("x", screenWidth, defaultX)
    readonly property real savedY: storedCoordinate("y", screenHeight, defaultY)
    readonly property real savedWidth: storedGeometry("width") ?? defaultWidth
    readonly property real savedHeight: forceSquare ? savedWidth : (storedGeometry("height") ?? defaultHeight)

    property real dragOverrideX: -1
    property real dragOverrideY: -1
    property real dragOverrideW: -1
    property real dragOverrideH: -1
    property bool squareSnapped: false

    readonly property real effectiveX: dragOverrideX >= 0 ? dragOverrideX : savedX
    readonly property real effectiveY: dragOverrideY >= 0 ? dragOverrideY : savedY
    readonly property real effectiveW: dragOverrideW >= 0 ? dragOverrideW : savedWidth
    readonly property real effectiveH: dragOverrideH >= 0 ? dragOverrideH : savedHeight

    readonly property real widgetX: Math.max(0, Math.min(effectiveX, screenWidth - widgetWidth))
    readonly property real widgetY: Math.max(0, Math.min(effectiveY, screenHeight - widgetHeight))
    readonly property real widgetWidth: Math.max(minWidth, Math.min(effectiveW, screenWidth))
    readonly property real widgetHeight: Math.max(minHeight, Math.min(effectiveH, screenHeight))

    property var _gridSettingsTrigger: lockScreen ? SessionData.lockScreenWidgetGridSettings : SessionData.desktopWidgetGridSettings
    readonly property int gridSize: {
        void _gridSettingsTrigger;
        return SessionData.getWidgetGridSetting(lockScreen, screenKey, "size", 40);
    }
    readonly property bool gridEnabled: {
        void _gridSettingsTrigger;
        return SessionData.getWidgetGridSetting(lockScreen, screenKey, "enabled", false);
    }

    function snapToGrid(value) {
        return Math.round(value / gridSize) * gridSize;
    }

    function clearDragOverrides() {
        dragOverrideX = -1;
        dragOverrideY = -1;
        dragOverrideW = -1;
        dragOverrideH = -1;
        squareSnapped = false;
    }

    function requestResize(width, height) {
        if (width < minWidth || height < minHeight)
            return;
        if (width > screenWidth || height > screenHeight)
            return;
        dragOverrideW = width;
        dragOverrideH = height;
    }

    function clearResize() {
        dragOverrideW = -1;
        dragOverrideH = -1;
    }

    function saveGeometry(updates) {
        if (!isInstance)
            return;
        SessionData.updateDesktopWidgetInstancePosition(instanceId, positionKey, updates);
    }

    function savePosition(finalX, finalY) {
        saveGeometry({
            x: syncPositionAcrossScreens ? finalX / screenWidth : finalX,
            y: syncPositionAcrossScreens ? finalY / screenHeight : finalY
        });
    }

    function saveSize(finalW, finalH) {
        const sizeVal = forceSquare ? Math.max(finalW, finalH) : finalW;
        saveGeometry({
            width: sizeVal,
            height: forceSquare ? sizeVal : finalH
        });
    }

    function saveDefaultGeometry(defaultWidth, defaultHeight) {
        if (!hasSavedSize) {
            const finalW = Math.max(minWidth, Math.min(defaultWidth, screenWidth));
            const finalH = Math.max(minHeight, Math.min(defaultHeight, screenHeight));
            saveSize(finalW, finalH);
        }
        if (hasSavedPosition)
            return;
        const finalX = Math.max(0, Math.min(screenWidth / 2 - widgetWidth / 2, screenWidth - widgetWidth));
        const finalY = Math.max(0, Math.min(screenHeight / 2 - widgetHeight / 2, screenHeight - widgetHeight));
        savePosition(finalX, finalY);
    }

    function dragMoveTo(startX, startY, dx, dy) {
        let newX = Math.max(0, Math.min(startX + dx, screenWidth - widgetWidth));
        let newY = Math.max(0, Math.min(startY + dy, screenHeight - widgetHeight));
        if (!gridEnabled)
            return Qt.point(newX, newY);
        newX = Math.max(0, Math.min(snapToGrid(newX), screenWidth - widgetWidth));
        newY = Math.max(0, Math.min(snapToGrid(newY), screenHeight - widgetHeight));
        return Qt.point(newX, newY);
    }

    function dragResizeTo(startWidth, startHeight, dx, dy) {
        let newW = Math.max(minWidth, Math.min(startWidth + dx, screenWidth - widgetX));
        let newH = Math.max(minHeight, Math.min(startHeight + dy, screenHeight - widgetY));
        if (gridEnabled) {
            newW = Math.max(minWidth, snapToGrid(newW));
            newH = Math.max(minHeight, snapToGrid(newH));
        }
        if (!forceSquare) {
            squareSnapped = Math.abs(newW - newH) <= (gridEnabled ? gridSize / 2 : Theme.spacingL);
            if (!squareSnapped)
                return Qt.size(newW, newH);
        }
        const size = Math.max(newW, newH);
        return Qt.size(Math.min(size, screenWidth - widgetX), Math.min(size, screenHeight - widgetY));
    }
}
