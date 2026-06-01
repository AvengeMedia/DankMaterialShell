pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property list<int> values: Array(6)
    property int refCount: 0
    property bool cavaAvailable: false
    readonly property string _confPath: `${Paths.strip(StandardPaths.writableLocation(StandardPaths.TempLocation))}/dms-cava-${Date.now()}-${Math.floor(Math.random() * 1000000)}.conf`

    Process {
        id: cavaCheck

        command: ["which", "cava"]
        running: false
        onExited: exitCode => {
            root.cavaAvailable = exitCode === 0 && Quickshell.env("DMS_DISABLE_CAVA") !== "1";
        }
    }

    Component.onCompleted: {
        cavaCheck.running = true;
    }

    Process {
        id: cavaProcess

        running: root.cavaAvailable && root.refCount > 0
        command: ["sh", "-c", `cat <<'CAVACONF' > ${root._confPath}
[general]
framerate=25
bars=6
autosens=0
sensitivity=30
lower_cutoff_freq=50
higher_cutoff_freq=12000

[output]
method=raw
raw_target=/dev/stdout
data_format=ascii
channels=mono
mono_option=average

[smoothing]
noise_reduction=35
integral=90
gravity=95
ignore=2
monstercat=1.5
CAVACONF
exec cava -p ${root._confPath} < /dev/null`]

        onRunningChanged: {
            if (!running) {
                root.values = Array(6).fill(0);
            }
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (root.refCount > 0 && data.length > 0) {
                    const parts = data.split(";");
                    if (parts.length >= 6) {
                        const points = [parseInt(parts[0], 10), parseInt(parts[1], 10), parseInt(parts[2], 10), parseInt(parts[3], 10), parseInt(parts[4], 10), parseInt(parts[5], 10)];
                        root.values = points;
                    }
                }
            }
        }
    }
}
