import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.DankBar
import qs.Modules.DankBar.Widgets
import qs.Modules.OSD
import qs.DankCommon.Common as DC
import "Common/WorkspaceModel.js" as WorkspaceModel

ShellRoot {
    id: root

    property var switcher: null
    property var osd: null
    property var content: null
    property string output: ""
    property var workspaceIds: []

    function check(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    function pills() {
        const found = [];
        function visit(item) {
            if (item.isPlaceholder !== undefined && item.isActive !== undefined)
                found.push(item);
            for (const child of item.children || [])
                visit(child);
        }
        visit(root.switcher);
        return found;
    }

    function texts(item) {
        if (!item.visible)
            return [];
        if (typeof item.text === "string")
            return [item.text];
        return (item.children || []).reduce((result, child) => result.concat(texts(child)), []);
    }

    function hyprlandRaw(id, name) {
        return {
            "id": id,
            "name": name,
            "monitor": {
                "name": root.output
            }
        };
    }

    function activeIdx() {
        return NiriService.allWorkspaces.find(ws => ws.output === root.output && ws.is_active)?.idx ?? -1;
    }

    Component {
        id: switcherComponent
        WorkspaceSwitcher {}
    }

    Component {
        id: osdComponent
        WorkspaceOSD {}
    }

    Component {
        id: contentComponent
        DankBarContent {}
    }

    QtObject {
        id: barAxis
        property bool isVertical: false
        property string edge: "top"
    }

    QtObject {
        id: barWindow
        property string screenName: root.output
        property var screen: Quickshell.screens[0] ?? null
        property var axis: barAxis
        property bool isVertical: false
        property real widgetThickness: 30
        property bool usesFrameBarChrome: false
        property bool hasAdjacentTopBar: false
        property bool hasAdjacentBottomBar: false
        property bool hasAdjacentLeftBar: false
        property bool hasAdjacentRightBar: false
    }

    FloatingWindow {
        visible: true
        implicitWidth: 600
        implicitHeight: 200

        Item {
            id: stage
            anchors.fill: parent
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }

    Timer {
        id: checks
        interval: 25
        repeat: true
        running: SettingsData._hasLoaded && SessionData._hasLoaded
        property int step: 0
        property int waited: 0

        function advance() {
            step++;
            waited = 0;
        }

        onTriggered: {
            try {
                if (++waited > 200)
                    throw new Error("timed out in step " + step);
                switch (step) {
                case 0:
                    if (!CompositorService.isNiri || NiriService.allWorkspaces.length === 0 || Quickshell.screens.length === 0)
                        return;
                    root.output = Quickshell.screens[0].name;
                    NiriService.send({
                        "Action": {
                            "SetWorkspaceName": {
                                "name": "alpha",
                                "workspace": null
                            }
                        }
                    });
                    advance();
                    return;
                case 1:
                    if (NiriService.allWorkspaces.filter(ws => ws.output === root.output).length < 2)
                        return;
                    SettingsData.osdWorkspaceEnabled = true;
                    root.switcher = switcherComponent.createObject(stage, {
                        "axis": {
                            "isVertical": false,
                            "edge": "top"
                        },
                        "screenName": root.output,
                        "parentScreen": Quickshell.screens[0],
                        "widgetThickness": 30,
                        "barThickness": 40,
                        "barConfig": {
                            "id": "fixture",
                            "widgetStyle": "pills"
                        },
                        "widgetData": {
                            "id": "workspaceSwitcher",
                            "showWorkspaceIndex": true,
                            "showWorkspaceName": true,
                            "showWorkspacePadding": true
                        }
                    });
                    root.osd = osdComponent.createObject(root, {
                        "screen": Quickshell.screens[0],
                        "modelData": Quickshell.screens[0]
                    });
                    root.content = contentComponent.createObject(stage, {
                        "barWindow": barWindow,
                        "rootWindow": null,
                        "barConfig": {
                            "id": "fixture"
                        }
                    });
                    root.check(root.switcher && root.osd && root.content, "components instantiate");
                    advance();
                    return;
                case 2:
                    if (root.pills().length !== 3 || !root.texts(root.pills()[0]).join("|").includes(":"))
                        return;
                    root.workspaceIds = NiriService.allWorkspaces.filter(ws => ws.output === root.output).map(ws => ws.id);
                    root.check(root.switcher.workspaceList.length === 3, "two workspaces plus one padding placeholder, got " + root.switcher.workspaceList.length);
                    root.check(root.switcher.currentWorkspace === 1, "current workspace is idx 1, got " + root.switcher.currentWorkspace);
                    root.check(root.pills().map(pill => pill.isActive).join() === "true,false,false", "first pill active");
                    root.check(root.pills().map(pill => pill.isPlaceholder).join() === "false,false,true", "padding pill is a placeholder");
                    root.check(root.texts(root.pills()[0]).join("|") === "1: alpha" && root.texts(root.pills()[1]).join("|") === "2" && root.texts(root.pills()[2]).join("|") === "3", "pill labels, got " + root.pills().map(pill => root.texts(pill).join("|")).join(","));
                    root.check(root.osd.activeWorkspace?.id === root.workspaceIds[0] && root.osd.activeWorkspace?.name === "alpha" && root.osd.activeWorkspace?.idx === 1, "osd active workspace " + JSON.stringify(root.osd.activeWorkspace));
                    root.switcher.switchWorkspace(1);
                    advance();
                    return;
                case 3:
                    if (root.activeIdx() !== 2 || root.switcher.currentWorkspace !== 2)
                        return;
                    root.check(root.pills().map(pill => pill.isActive).join() === "false,true,false", "second pill active after scroll");
                    root.check(root.osd.activeWorkspace?.id === root.workspaceIds[1] && root.osd.workspaceLabel === "Workspace 2", "osd follows the switch, label " + root.osd.workspaceLabel);
                    root.content.switchWorkspace(-1);
                    advance();
                    return;
                case 4:
                    if (root.activeIdx() !== 1 || root.switcher.currentWorkspace !== 1)
                        return;
                    root.check(root.osd.workspaceLabel === "Workspace 1: alpha", "osd label with name, got " + root.osd.workspaceLabel);
                    root.content.switchWorkspace(-1);
                    root.switcher.switchToWorkspaceByModelData(root.switcher.workspaceList[2]);
                    advance();
                    return;
                case 5:
                    if (waited < 12)
                        return;
                    root.check(root.activeIdx() === 1, "scrolling past the first workspace and pressing a placeholder do nothing");
                    NiriService.send({
                        "Action": {
                            "UnsetWorkspaceName": {
                                "reference": {
                                    "Name": "alpha"
                                }
                            }
                        }
                    });
                    root.switcher.widgetData = {
                        "id": "workspaceSwitcher",
                        "showWorkspaceName": true,
                        "showWorkspacePadding": true
                    };
                    root.switcher.workspaceList = root.switcher.hyprlandSlotList(WorkspaceModel.hyprlandWorkspacesForScreen({
                        "workspaces": [root.hyprlandRaw(1, "web"), root.hyprlandRaw(3, "")],
                        "monitors": [],
                        "focusedWorkspace": null,
                        "toplevels": []
                    }, root.output, false, false, 3));
                    advance();
                    return;
                case 6:
                    if (root.pills().length !== 3 || waited < 4)
                        return;
                    root.check(root.pills().map(pill => root.texts(pill).join("|")).join() === "web,2,3", "hyprland slot pills label from their record, got " + root.pills().map(pill => root.texts(pill).join("|")).join());
                    root.check(root.pills().every(pill => !pill.isPlaceholder), "hyprland padding slots are real workspaces");
                    console.log("FIXTURE_PASS");
                    stop();
                    Qt.quit();
                    return;
                }
            } catch (error) {
                console.error("FIXTURE_FAIL", error.message);
                stop();
                Qt.quit();
            }
        }
    }
}
