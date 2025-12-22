import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property real widgetWidth: 320
    property real widgetHeight: 480
    property real defaultWidth: 320
    property real defaultHeight: 480
    property real minWidth: {
        const tileCount = enabledTiles.length;
        if (tileCount === 0)
            return 80;
        if (tileCount === 1)
            return 100;
        return 160;
    }
    property real minHeight: {
        const tileCount = enabledTiles.length;
        if (tileCount === 0)
            return 60;
        if (tileCount === 1)
            return 80;
        if (tileCount <= 2)
            return 120;
        return 180;
    }

    property string instanceId: ""
    property var instanceData: null

    readonly property var cfg: instanceData?.config ?? null
    readonly property bool isInstance: instanceId !== "" && cfg !== null

    property bool enabled: isInstance ? (instanceData?.enabled ?? true) : SettingsData.systemMonitorEnabled
    property bool showHeader: isInstance ? (cfg.showHeader ?? true) : SettingsData.systemMonitorShowHeader
    property real transparency: isInstance ? (cfg.transparency ?? 0.8) : SettingsData.systemMonitorTransparency
    property string colorMode: isInstance ? (cfg.colorMode ?? "primary") : SettingsData.systemMonitorColorMode
    property color customColor: isInstance ? (cfg.customColor ?? "#ffffff") : SettingsData.systemMonitorCustomColor
    property bool showCpu: isInstance ? (cfg.showCpu ?? true) : SettingsData.systemMonitorShowCpu
    property bool showCpuGraph: isInstance ? (cfg.showCpuGraph ?? true) : SettingsData.systemMonitorShowCpuGraph
    property bool showCpuTemp: isInstance ? (cfg.showCpuTemp ?? true) : SettingsData.systemMonitorShowCpuTemp
    property bool showGpuTemp: isInstance ? (cfg.showGpuTemp ?? false) : SettingsData.systemMonitorShowGpuTemp
    property string selectedGpuPciId: isInstance ? (cfg.gpuPciId ?? "") : SettingsData.systemMonitorGpuPciId
    property bool showMemory: isInstance ? (cfg.showMemory ?? true) : SettingsData.systemMonitorShowMemory
    property bool showMemoryGraph: isInstance ? (cfg.showMemoryGraph ?? true) : SettingsData.systemMonitorShowMemoryGraph
    property bool showNetwork: isInstance ? (cfg.showNetwork ?? true) : SettingsData.systemMonitorShowNetwork
    property bool showNetworkGraph: isInstance ? (cfg.showNetworkGraph ?? true) : SettingsData.systemMonitorShowNetworkGraph
    property bool showDisk: isInstance ? (cfg.showDisk ?? true) : SettingsData.systemMonitorShowDisk
    property bool showTopProcesses: isInstance ? (cfg.showTopProcesses ?? false) : SettingsData.systemMonitorShowTopProcesses
    property int topProcessCount: isInstance ? (cfg.topProcessCount ?? 3) : SettingsData.systemMonitorTopProcessCount
    property string topProcessSortBy: isInstance ? (cfg.topProcessSortBy ?? "cpu") : SettingsData.systemMonitorTopProcessSortBy
    property string layoutMode: isInstance ? (cfg.layoutMode ?? "auto") : SettingsData.systemMonitorLayoutMode
    property int graphInterval: isInstance ? (cfg.graphInterval ?? 60) : SettingsData.systemMonitorGraphInterval

    readonly property color accentColor: {
        switch (colorMode) {
        case "secondary":
            return Theme.secondary;
        case "custom":
            return customColor;
        default:
            return Theme.primary;
        }
    }

    readonly property color bgColor: Theme.withAlpha(Theme.surface, root.transparency)
    readonly property color tileBg: Theme.withAlpha(Theme.surfaceContainerHigh, root.transparency)
    readonly property color textColor: Theme.surfaceText
    readonly property color dimColor: Theme.surfaceVariantText

    property string currentGpuPciIdRef: ""

    property var cpuHistory: []
    property var memHistory: []
    property var netRxHistory: []
    property var netTxHistory: []
    property var diskReadHistory: []
    property var diskWriteHistory: []
    readonly property int historySize: 60

    readonly property int sampleInterval: {
        switch (graphInterval) {
        case 60:
            return 1000;
        case 300:
            return 5000;
        case 600:
            return 10000;
        case 900:
            return 15000;
        case 1800:
            return 30000;
        default:
            return 1000;
        }
    }

    readonly property var enabledTiles: {
        var tiles = [];
        if (showCpu)
            tiles.push("cpu");
        if (showMemory)
            tiles.push("mem");
        if (showNetwork)
            tiles.push("net");
        if (showDisk)
            tiles.push("disk");
        if (showGpuTemp && selectedGpuPciId)
            tiles.push("gpu");
        return tiles;
    }

    readonly property var sortedProcesses: {
        if (!showTopProcesses || !DgopService.processes)
            return [];
        var procs = DgopService.processes.slice();
        if (topProcessSortBy === "memory") {
            procs.sort((a, b) => (b.memoryKB || 0) - (a.memoryKB || 0));
        } else {
            procs.sort((a, b) => (b.cpu || 0) - (a.cpu || 0));
        }
        return procs.slice(0, topProcessCount);
    }

    Component.onCompleted: {
        var modules = ["system"];
        if (showCpu || showCpuTemp || showCpuGraph)
            modules.push("cpu");
        if (showMemory || showMemoryGraph)
            modules.push("memory");
        if (showNetwork || showNetworkGraph)
            modules.push("network");
        if (showDisk)
            modules.push("disk", "diskmounts");
        if (showTopProcesses)
            modules.push("processes");
        DgopService.addRef(modules);
        updateGpuRef();
    }

    Component.onDestruction: {
        DgopService.removeRef();
        if (currentGpuPciIdRef)
            DgopService.removeGpuPciId(currentGpuPciIdRef);
    }

    onShowGpuTempChanged: updateGpuRef()
    onSelectedGpuPciIdChanged: updateGpuRef()
    onShowTopProcessesChanged: {
        if (showTopProcesses)
            DgopService.addRef(["processes"]);
    }

    function updateGpuRef() {
        if (currentGpuPciIdRef && currentGpuPciIdRef !== selectedGpuPciId) {
            DgopService.removeGpuPciId(currentGpuPciIdRef);
            currentGpuPciIdRef = "";
        }
        if (!showGpuTemp || !selectedGpuPciId) {
            if (currentGpuPciIdRef) {
                DgopService.removeGpuPciId(currentGpuPciIdRef);
                currentGpuPciIdRef = "";
            }
            return;
        }
        if (selectedGpuPciId && !currentGpuPciIdRef) {
            DgopService.addGpuPciId(selectedGpuPciId);
            currentGpuPciIdRef = selectedGpuPciId;
        }
    }

    function getGpuInfo() {
        if (!selectedGpuPciId || !DgopService.availableGpus)
            return null;
        return DgopService.availableGpus.find(g => g.pciId === selectedGpuPciId);
    }

    function formatBytes(bytes) {
        if (bytes < 1024)
            return bytes.toFixed(0) + "B";
        if (bytes < 1024 * 1024)
            return (bytes / 1024).toFixed(0) + "K";
        if (bytes < 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024)).toFixed(1) + "M";
        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + "G";
    }

    function formatMemKB(kb) {
        if (kb < 1024)
            return kb.toFixed(0) + "K";
        if (kb < 1024 * 1024)
            return (kb / 1024).toFixed(0) + "M";
        return (kb / (1024 * 1024)).toFixed(1) + "G";
    }

    function addToHistory(arr, val) {
        var newArr = arr.slice();
        newArr.push(val);
        if (newArr.length > historySize)
            newArr.shift();
        return newArr;
    }

    function sampleData() {
        if (showCpuGraph)
            cpuHistory = addToHistory(cpuHistory, DgopService.cpuUsage);
        if (showMemoryGraph)
            memHistory = addToHistory(memHistory, DgopService.memoryUsage);
        if (showNetworkGraph) {
            netRxHistory = addToHistory(netRxHistory, DgopService.networkRxRate);
            netTxHistory = addToHistory(netTxHistory, DgopService.networkTxRate);
        }
        if (showDisk) {
            diskReadHistory = addToHistory(diskReadHistory, DgopService.diskReadRate);
            diskWriteHistory = addToHistory(diskWriteHistory, DgopService.diskWriteRate);
        }
    }

    readonly property int sampleSeconds: sampleInterval / 1000

    SystemClock {
        id: sampleClock
        precision: SystemClock.Seconds
        onDateChanged: {
            var sec = date.getSeconds();
            if (sec % root.sampleSeconds === 0)
                root.sampleData();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: root.bgColor
        border.width: 0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: (root.enabledTiles.length === 1 && !root.showHeader) ? 0 : Theme.spacingS
            spacing: Theme.spacingS

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS
                visible: root.showHeader

                ColumnLayout {
                    spacing: 0

                    StyledText {
                        text: DgopService.cpuModel || DgopService.hostname || "System"
                        isMonospace: true
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.textColor
                        elide: Text.ElideRight
                        Layout.maximumWidth: root.width - Theme.spacingM * 2
                    }

                    StyledText {
                        visible: DgopService.shortUptime && DgopService.shortUptime.length > 0
                        text: DgopService.shortUptime
                        isMonospace: true
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.dimColor
                    }
                }
            }

            GridLayout {
                id: tileGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: {
                    if (root.layoutMode === "list")
                        return 1;
                    if (root.layoutMode === "grid")
                        return 2;
                    // auto
                    if (root.width < 280)
                        return 1;
                    if (root.width < 500)
                        return 2;
                    return 3;
                }
                rowSpacing: Theme.spacingXS
                columnSpacing: Theme.spacingXS

                Repeater {
                    model: root.enabledTiles

                    Rectangle {
                        id: tile
                        readonly property int span: Layout.columnSpan
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.columnSpan: {
                            if (root.layoutMode === "list")
                                return 1;

                            var cols = tileGrid.columns;
                            if (cols <= 1)
                                return 1;

                            var count = root.enabledTiles.length;
                            var idx = index;

                            if (idx !== count - 1)
                                return 1;

                            var remainder = count % cols;
                            if (remainder === 0)
                                return 1;

                            if (!tile.hasGraph)
                                return 1;

                            return cols - remainder + 1;
                        }
                        Layout.minimumHeight: 60
                        radius: Theme.cornerRadius - 2
                        color: root.tileBg
                        border.width: 0
                        clip: true

                        readonly property string tileType: modelData
                        readonly property bool hasGraph: {
                            switch (tileType) {
                            case "cpu":
                                return root.showCpuGraph;
                            case "mem":
                                return root.showMemoryGraph;
                            case "net":
                                return root.showNetworkGraph;
                            case "disk":
                                return true;
                            default:
                                return false;
                            }
                        }

                        Canvas {
                            id: tileGraph
                            anchors.fill: parent
                            visible: tile.hasGraph
                            renderStrategy: Canvas.Cooperative

                            property var hist: {
                                switch (tile.tileType) {
                                case "cpu":
                                    return root.cpuHistory;
                                case "mem":
                                    return root.memHistory;
                                case "net":
                                    return root.netRxHistory;
                                case "disk":
                                    return root.diskReadHistory;
                                default:
                                    return [];
                                }
                            }
                            property var hist2: {
                                switch (tile.tileType) {
                                case "net":
                                    return root.netTxHistory;
                                case "disk":
                                    return root.diskWriteHistory;
                                default:
                                    return null;
                                }
                            }

                            onHistChanged: requestPaint()
                            onHist2Changed: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                ctx.clearRect(0, 0, width, height);
                                if (!hist || hist.length < 2)
                                    return;
                                var maxVal = 100;
                                if (tile.tileType === "net" || tile.tileType === "disk") {
                                    maxVal = 1;
                                    for (var k = 0; k < hist.length; k++)
                                        maxVal = Math.max(maxVal, hist[k]);
                                    if (hist2)
                                        for (var l = 0; l < hist2.length; l++)
                                            maxVal = Math.max(maxVal, hist2[l]);
                                }

                                var c = root.accentColor;
                                var grad = ctx.createLinearGradient(0, 0, 0, height);
                                grad.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.3));
                                grad.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0.05));

                                ctx.fillStyle = grad;
                                ctx.beginPath();
                                ctx.moveTo(0, height);
                                for (var i = 0; i < hist.length; i++) {
                                    var x = (width / (root.historySize - 1)) * i;
                                    var y = height - (hist[i] / maxVal) * height * 0.85;
                                    ctx.lineTo(x, y);
                                }
                                ctx.lineTo((width / (root.historySize - 1)) * (hist.length - 1), height);
                                ctx.closePath();
                                ctx.fill();

                                ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.6);
                                ctx.lineWidth = 1.5;
                                ctx.beginPath();
                                for (var j = 0; j < hist.length; j++) {
                                    var px = (width / (root.historySize - 1)) * j;
                                    var py = height - (hist[j] / maxVal) * height * 0.85;
                                    j === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py);
                                }
                                ctx.stroke();

                                if (hist2 && hist2.length >= 2) {
                                    ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.3);
                                    ctx.lineWidth = 1;
                                    ctx.beginPath();
                                    for (var m = 0; m < hist2.length; m++) {
                                        var sx = (width / (root.historySize - 1)) * m;
                                        var sy = height - (hist2[m] / maxVal) * height * 0.85;
                                        m === 0 ? ctx.moveTo(sx, sy) : ctx.lineTo(sx, sy);
                                    }
                                    ctx.stroke();
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingXS

                                StyledText {
                                    text: tile.tileType.toUpperCase()
                                    isMonospace: true
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    color: root.accentColor
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    visible: tile.tileType === "cpu" && root.showCpuTemp && DgopService.cpuTemperature > 0
                                    text: DgopService.cpuTemperature.toFixed(0) + "°"
                                    isMonospace: true
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: DgopService.cpuTemperature > 80 ? Theme.error : (DgopService.cpuTemperature > 60 ? Theme.warning : root.dimColor)
                                }

                                StyledText {
                                    visible: tile.tileType === "mem"
                                    text: DgopService.formatSystemMemory(DgopService.usedMemoryKB)
                                    isMonospace: true
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: root.dimColor
                                }
                            }

                            Item {
                                Layout.fillHeight: true
                            }

                            StyledText {
                                visible: tile.tileType === "cpu"
                                text: DgopService.cpuUsage.toFixed(0) + "%"
                                isMonospace: true
                                font.pixelSize: Theme.fontSizeXLarge
                                font.weight: Font.Medium
                                color: root.textColor
                            }

                            StyledText {
                                visible: tile.tileType === "mem"
                                text: DgopService.memoryUsage.toFixed(0) + "%"
                                isMonospace: true
                                font.pixelSize: Theme.fontSizeXLarge
                                font.weight: Font.Medium
                                color: root.textColor
                            }

                            RowLayout {
                                visible: tile.tileType === "net"
                                spacing: Theme.spacingM
                                ColumnLayout {
                                    spacing: 0
                                    StyledText {
                                        text: "↓"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: root.accentColor
                                    }
                                    StyledText {
                                        text: root.formatBytes(DgopService.networkRxRate) + "/s"
                                        isMonospace: true
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: root.textColor
                                    }
                                }
                                ColumnLayout {
                                    spacing: 0
                                    StyledText {
                                        text: "↑"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: root.dimColor
                                    }
                                    StyledText {
                                        text: root.formatBytes(DgopService.networkTxRate) + "/s"
                                        isMonospace: true
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: root.textColor
                                    }
                                }
                            }

                            RowLayout {
                                visible: tile.tileType === "disk"
                                spacing: Theme.spacingM
                                ColumnLayout {
                                    spacing: 0
                                    StyledText {
                                        text: "R"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: root.accentColor
                                    }
                                    StyledText {
                                        text: root.formatBytes(DgopService.diskReadRate) + "/s"
                                        isMonospace: true
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: root.textColor
                                    }
                                }
                                ColumnLayout {
                                    spacing: 0
                                    StyledText {
                                        text: "W"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: root.dimColor
                                    }
                                    StyledText {
                                        text: root.formatBytes(DgopService.diskWriteRate) + "/s"
                                        isMonospace: true
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: root.textColor
                                    }
                                }
                            }

                            ColumnLayout {
                                visible: tile.tileType === "gpu"
                                spacing: 0
                                property var gpu: root.getGpuInfo()
                                Layout.alignment: tile.span > 1 ? Qt.AlignHCenter : Qt.AlignLeft

                                StyledText {
                                    property real temp: parent.gpu?.temperature ?? 0
                                    text: temp > 0 ? temp.toFixed(0) + "°C" : "--"
                                    isMonospace: true
                                    font.pixelSize: Theme.fontSizeXLarge
                                    font.weight: Font.Medium
                                    color: root.textColor
                                    Layout.alignment: tile.span > 1 ? Qt.AlignHCenter : Qt.AlignLeft
                                }
                                StyledText {
                                    text: parent.gpu?.displayName ?? ""
                                    isMonospace: true
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: root.dimColor
                                    Layout.fillWidth: true
                                    horizontalAlignment: tile.span > 1 ? Text.AlignHCenter : Text.AlignLeft
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                visible: tile.tileType === "cpu" || tile.tileType === "mem"
                                Layout.fillWidth: true
                                height: 4
                                radius: 2
                                color: Theme.withAlpha(Theme.outline, 0.2)

                                Rectangle {
                                    property real pct: tile.tileType === "cpu" ? DgopService.cpuUsage / 100 : DgopService.memoryUsage / 100
                                    width: parent.width * Math.min(1, pct)
                                    height: parent.height
                                    radius: 2
                                    color: pct > 0.8 ? Theme.error : (pct > 0.6 ? Theme.warning : root.accentColor)
                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 150
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXS
                visible: root.showTopProcesses && root.sortedProcesses.length > 0

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.withAlpha(Theme.outline, 0.15)
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingXS

                    StyledText {
                        text: "TOP BY " + root.topProcessSortBy.toUpperCase()
                        isMonospace: true
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: root.accentColor
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: root.topProcessSortBy === "cpu" ? "CPU" : "MEM"
                        isMonospace: true
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.dimColor
                        Layout.preferredWidth: 48
                        horizontalAlignment: Text.AlignRight
                    }
                }

                Repeater {
                    model: root.sortedProcesses

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXS

                        StyledText {
                            text: modelData.command || "unknown"
                            isMonospace: true
                            font.pixelSize: Theme.fontSizeSmall
                            color: root.textColor
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        StyledText {
                            text: root.topProcessSortBy === "cpu" ? (modelData.cpu || 0).toFixed(1) + "%" : root.formatMemKB(modelData.memoryKB || 0)
                            isMonospace: true
                            font.pixelSize: Theme.fontSizeSmall
                            color: root.dimColor
                            Layout.preferredWidth: 48
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXS
                visible: root.showDisk && DgopService.diskMounts.length > 0

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.withAlpha(Theme.outline, 0.15)
                }

                Repeater {
                    model: DgopService.diskMounts.filter(m => m.mountpoint === "/" || m.mountpoint === "/home")

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXS

                        StyledText {
                            text: modelData.mountpoint
                            isMonospace: true
                            font.pixelSize: Theme.fontSizeSmall
                            color: root.dimColor
                            Layout.preferredWidth: 48
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 4
                            radius: 2
                            color: Theme.withAlpha(Theme.outline, 0.2)

                            Rectangle {
                                property real pct: (modelData.used || 0) / Math.max(1, modelData.total || 1)
                                width: parent.width * pct
                                height: parent.height
                                radius: 2
                                color: pct > 0.9 ? Theme.error : (pct > 0.75 ? Theme.warning : root.accentColor)
                            }
                        }

                        StyledText {
                            text: ((modelData.used || 0) / (modelData.total || 1) * 100).toFixed(0) + "%"
                            isMonospace: true
                            font.pixelSize: Theme.fontSizeSmall
                            color: root.textColor
                            Layout.preferredWidth: 32
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }
        }
    }
}
