import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.I3
import Quickshell.WindowManager
import qs.Common
import qs.Services
import qs.Widgets

DankOSD {
    id: root

    property string workspaceLabel: ""
    property var lastActiveWorkspaceId: null

    readonly property real horizontalPadding: Theme.spacingL
    readonly property real itemSpacing: Theme.spacingM
    readonly property real textWidth: Math.ceil(textMetrics.width)
    readonly property real digitReserve: Math.ceil(digitMetrics.width)
    readonly property var activeWorkspace: root.getActiveWorkspace()
    readonly property bool useExtWorkspace: {
        if (Quickshell.env("DMS_FORCE_EXTWS") === "1")
            return (WindowManager.windowsets?.length ?? 0) > 0;
        if (!CompositorService.compositorDetected)
            return false;
        switch (CompositorService.compositor) {
        case "niri":
        case "hyprland":
        case "mango":
        case "sway":
        case "scroll":
        case "miracle":
            return false;
        default:
            return (WindowManager.windowsets?.length ?? 0) > 0;
        }
    }

    osdWidth: Math.min(
        Math.max(140, horizontalPadding * 2 + Theme.iconSize + itemSpacing + textWidth + digitReserve),
        screenWidth - Theme.spacingM * 2
    )
    osdHeight: 48
    autoHideInterval: 1500
    enableMouseInteraction: false

    function stripSwayWorkspaceNumber(num, name) {
        if (num === undefined || num === -1)
            return name ?? "";
        if (typeof name !== "string")
            return "";
        const prefix = num + ":";
        if (!name.startsWith(prefix))
            return name;
        return name.slice(prefix.length);
    }

    function isSpecialHyprlandName(name) {
        return name === "special" || name.startsWith("special:");
    }

    function inOverview() {
        if (CompositorService.isNiri)
            return NiriService.inOverview;
        if (CompositorService.isMango)
            return MangoService.isOutputInOverview(root.screen?.name);
        return false;
    }

    function getActiveWorkspace() {
        const screenName = root.screen?.name ?? "";

        if (CompositorService.isNiri) {
            const ws = NiriService.allWorkspaces.find(w => (!screenName || w.output === screenName) && w.is_active);
            if (!ws)
                return null;
            return {
                "id": ws.id,
                "idx": ws.idx,
                "name": ws.name ?? "",
                "output": ws.output ?? ""
            };
        }

        if (CompositorService.isHyprland) {
            const monitor = Hyprland.monitors?.values.find(m => !screenName || m.name === screenName);
            const ws = monitor?.activeWorkspace;
            if (!ws)
                return null;
            const name = ws.name ?? "";
            if (root.isSpecialHyprlandName(name))
                return null;
            const id = ws.id;
            return {
                "id": id,
                "idx": id > 0 ? id : null,
                "name": (name !== "" && name !== String(id)) ? name : "",
                "output": monitor?.name ?? screenName
            };
        }

        if (CompositorService.isMango) {
            const tags = MangoService.getActiveTags(screenName);
            if (tags.length === 0)
                return null;
            const tag = tags[0];
            return {
                "id": tag,
                "idx": tag + 1,
                "name": "",
                "output": screenName
            };
        }

        if (CompositorService.isSway || CompositorService.isScroll || CompositorService.isMiracle) {
            const workspaces = I3.workspaces?.values || [];
            const onScreen = workspaces.filter(w => !screenName || w.monitor?.name === screenName);
            const ws = onScreen.find(w => w.focused) || onScreen.find(w => w.visible) || onScreen.find(w => w.active) || onScreen[0];
            if (!ws)
                return null;
            const num = ws.number;
            const name = root.stripSwayWorkspaceNumber(num, ws.name);
            return {
                "id": (num !== undefined && num !== -1) ? num : name,
                "idx": (num !== undefined && num > 0) ? num : null,
                "name": name,
                "output": ws.monitor?.name ?? screenName
            };
        }

        if (root.useExtWorkspace && root.screen) {
            const projection = WindowManager.screenProjection(root.screen);
            const ws = projection?.windowsets?.find(w => w.active);
            if (!ws)
                return null;
            const name = (ws.name ?? "").trim();
            const id = ws.id || name;
            if (id === undefined || id === null || id === "")
                return null;
            const parsed = parseInt(name, 10);
            return {
                "id": id,
                "idx": (name !== "" && String(parsed) === name) ? parsed : null,
                "name": name,
                "output": screenName
            };
        }

        return null;
    }

    function handleWorkspaceChange() {
        if (!SettingsData.osdWorkspaceEnabled)
            return;

        const ws = root.activeWorkspace;
        if (!ws || ws.id === undefined || ws.id === null)
            return;

        if (root.lastActiveWorkspaceId === null) {
            root.lastActiveWorkspaceId = ws.id;
            return;
        }
        if (root.lastActiveWorkspaceId === ws.id)
            return;
        if (root.inOverview())
            return;

        root.lastActiveWorkspaceId = ws.id;
        root.updateWorkspaceInfo(ws);
        root.show();
    }

    function updateWorkspaceInfo(ws) {
        if (!ws)
            return;
        const num = (ws.idx !== undefined && ws.idx !== null && ws.idx > 0) ? ws.idx : (typeof ws.id === "number" && ws.id > 0 ? ws.id : null);
        const name = (ws.name ?? "").trim();

        if (num !== null) {
            if (name !== "" && name !== String(num)) {
                root.workspaceLabel = I18n.tr("Workspace %1: %2", "workspace switch OSD, %1 is workspace number, %2 is workspace name").arg(num).arg(name);
            } else {
                root.workspaceLabel = I18n.tr("Workspace %1", "workspace switch OSD, %1 is workspace number").arg(num);
            }
        } else if (name !== "") {
            root.workspaceLabel = name;
        } else {
            root.workspaceLabel = I18n.tr("Workspace", "fallback label when workspace has no number or name");
        }
    }

    onActiveWorkspaceChanged: root.handleWorkspaceChange()

    Component.onCompleted: root.handleWorkspaceChange()

    TextMetrics {
        id: textMetrics
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        font.family: Theme.fontFamily
        text: root.workspaceLabel
    }

    TextMetrics {
        id: digitMetrics
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        font.family: Theme.fontFamily
        text: "0"
    }

    content: Item {
        anchors.fill: parent

        RowLayout {
            anchors {
                fill: parent
                leftMargin: root.horizontalPadding
                rightMargin: root.horizontalPadding
            }
            spacing: root.itemSpacing

            DankIcon {
                Layout.alignment: Qt.AlignVCenter
                name: "view_module"
                size: Theme.iconSize
                color: Theme.primary
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: root.workspaceLabel
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }
        }
    }
}
