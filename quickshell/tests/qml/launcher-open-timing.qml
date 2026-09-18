import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modals.DankLauncherV2
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    readonly property string style: Quickshell.env("DMS_FIXTURE_LAUNCHER_STYLE") || "standalone"
    readonly property string query: Quickshell.env("DMS_FIXTURE_LAUNCHER_QUERY") || ""
    readonly property int rounds: 8
    property var launcher: null
    property int round: 0
    property real tShow: 0
    property real tSearch: 0
    property real tResults: 0
    property real tHide: 0
    property var results: []
    property var resultsList: null
    property bool waitingResults: false
    property bool waitingClose: false
    property bool typingDone: false
    property int typeIndex: 0
    readonly property string typeWord: Quickshell.env("DMS_FIXTURE_LAUNCHER_TYPE") || "terminal"
    property var typing: []
    property real tType: 0
    property int typeSearchMs: -1
    property int typeFrames: 0
    property bool typeWaiting: false

    property int typeCompletions: 0
    property int typeModelChanges: 0
    property int typeLastMs: 0

    Connections {
        target: root.launcher?.spotlightContent?.controller ?? null
        ignoreUnknownSignals: true
        function onSearchCompleted() {
            if (root.tType === 0)
                return;
            root.typeCompletions++;
            root.typeLastMs = Date.now() - root.tType;
            if (root.typeWaiting && root.typeSearchMs < 0)
                root.typeSearchMs = root.typeLastMs;
        }
        function onFlatModelChanged() {
            if (root.tType !== 0)
                root.typeModelChanges++;
        }
    }

    property int typeFirstFrameMs: -1

    FrameAnimation {
        running: root.typeWaiting
        onTriggered: {
            root.typeFrames++;
            if (root.typeFirstFrameMs < 0)
                root.typeFirstFrameMs = Date.now() - root.tType;
            if (root.typeSearchMs < 0)
                return;
            root.typing.push({
                q: root.typeWord.slice(0, root.typeIndex),
                search: root.typeSearchMs,
                firstFrame: root.typeFirstFrameMs,
                framesAfter: root.typeFrames,
                wall: Date.now() - root.tType,
                results: root.launcher.spotlightContent.controller.flatModel.length
            });
            root.typeWaiting = false;
        }
    }

    Timer {
        id: typeTimer
        interval: 250
        repeat: true
        onTriggered: {
            if (root.typeIndex >= root.typeWord.length) {
                stop();
                const last = root.typing[root.typing.length - 1];
                last.completions = root.typeCompletions;
                last.modelChanges = root.typeModelChanges;
                last.lastSearchMs = root.typeLastMs;
                root.launcher.hide();
                const med = key => {
                    const v = root.typing.map(r => r[key]).sort((a, b) => a - b);
                    return v[Math.floor(v.length / 2)];
                };
                console.log("TYPING " + JSON.stringify({
                    style: root.style,
                    medianSearch: med("search"),
                    maxSearch: Math.max(...root.typing.map(r => r.search)),
                    medianWall: med("wall"),
                    steps: root.typing
                }));
                finishTimer.start();
                return;
            }
            if (root.typeIndex > 0) {
                const last = root.typing[root.typing.length - 1];
                last.completions = root.typeCompletions;
                last.modelChanges = root.typeModelChanges;
                last.lastSearchMs = root.typeLastMs;
            }
            root.typeCompletions = 0;
            root.typeModelChanges = 0;
            root.typeIndex++;
            root.tType = Date.now();
            root.typeSearchMs = -1;
            root.typeFirstFrameMs = -1;
            root.typeFrames = 0;
            root.typeWaiting = true;
            root.launcher.spotlightContent.searchField.text = root.typeWord.slice(0, root.typeIndex);
        }
    }

    Timer {
        id: finishTimer
        interval: 500
        onTriggered: next.restart()
    }

    function typeName(item) {
        return String(item).split("(")[0].replace(/_QMLTYPE_\d+/, "").replace(/_QML_\d+/, "");
    }

    function backend() {
        return root.launcher.children[0]?.item ?? null;
    }

    function resultCount() {
        return root.launcher?.spotlightContent?.controller?.flatModel?.length ?? -1;
    }

    Component {
        id: modalComp
        DankLauncherV2Modal {}
    }

    Connections {
        target: root.launcher?.spotlightContent?.controller ?? null
        ignoreUnknownSignals: true
        function onSearchCompleted() {
            if (root.tSearch === 0 && root.tShow > 0)
                root.tSearch = Date.now();
        }
    }

    Connections {
        target: root.launcher
        ignoreUnknownSignals: true
        function onDialogClosed() {
            if (root.waitingClose) {
                root.waitingClose = false;
                root.results.push({
                    round: root.round,
                    search: root.tSearch - root.tShow,
                    results: root.tResults - root.tShow,
                    close: Date.now() - root.tHide
                });
                root.round++;
                next.restart();
            }
        }
    }

    FrameAnimation {
        id: frames
        running: root.waitingResults
        onTriggered: {
            const b = backend();
            if (!b || !b.contentVisible)
                return;
            if (resultCount() <= 0)
                return;
            root.tResults = Date.now();
            root.waitingResults = false;
            hideTimer.restart();
        }
    }

    Timer {
        id: watchdog
        interval: 8000
        running: root.waitingResults || root.waitingClose
        onTriggered: {
            const b = backend();
            console.log("FIXTURE_FAIL round " + root.round + " stuck: backend=" + (b ? root.typeName(b) : "none") + " contentVisible=" + (b?.contentVisible ?? "?") + " open=" + (b?.spotlightOpen ?? "?") + " results=" + resultCount() + " waitingResults=" + root.waitingResults + " waitingClose=" + root.waitingClose);
            Qt.quit();
        }
    }

    Timer {
        id: hideTimer
        interval: 250
        onTriggered: {
            root.tHide = Date.now();
            root.waitingClose = true;
            root.launcher.hide();
        }
    }

    Timer {
        id: next
        interval: 400
        onTriggered: {
            if (root.round >= root.rounds && !root.typingDone) {
                root.typingDone = true;
                root.launcher.show();
                typeTimer.start();
                return;
            }
            if (root.round >= root.rounds) {
                const warm = root.results.slice(1);
                const med = key => {
                    const v = warm.map(r => r[key]).sort((a, b) => a - b);
                    return v[Math.floor(v.length / 2)];
                };
                console.log("TIMING " + JSON.stringify({
                    style: root.style,
                    query: root.query,
                    cold: root.results[0],
                    medianSearch: med("search"),
                    medianResults: med("results"),
                    medianClose: med("close"),
                    all: root.results
                }));
                console.log("FIXTURE_PASS");
                Qt.quit();
                return;
            }
            root.tShow = Date.now();
            root.tSearch = 0;
            root.tResults = 0;
            root.waitingResults = true;
            if (root.query)
                root.launcher.showWithQuery(root.query);
            else
                root.launcher.show();
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        SettingsData.launcherStyle = root.style;
        SettingsData.rememberLastQuery = false;
        SettingsData.dankLauncherV2UnloadOnClose = false;
        root.launcher = modalComp.createObject(root);
        startup.start();
    }

    Timer {
        id: startup
        interval: 2500
        onTriggered: next.restart()
    }
}
