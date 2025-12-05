//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_MEDIA_BACKEND=ffmpeg
//@ pragma Env QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi
//@ pragma Env QT_FFMPEG_ENCODING_HW_DEVICE_TYPES=vaapi
//@ pragma Env QT_WAYLAND_DISABLE_WINDOWDECORATION=1
//@ pragma UseQApplication

import QtQuick
import Quickshell

ShellRoot {
    id: entrypoint

    readonly property bool runGreeter: Quickshell.env("DMS_RUN_GREETER") === "1" || Quickshell.env("DMS_RUN_GREETER") === "true"
    readonly property bool disableHotReload: Quickshell.env("DMS_DISABLE_HOT_RELOAD") === "1" || Quickshell.env("DMS_DISABLE_HOT_RELOAD") === "true"

    Component.onCompleted: {
        Quickshell.watchFiles = !disableHotReload;
    }

    Loader {
        id: dmsShellLoader
        asynchronous: false
        sourceComponent: DMSShell {}
        active: !entrypoint.runGreeter
    }

    Loader {
        id: dmsGreeterLoader
        asynchronous: false
        sourceComponent: DMSGreeter {}
        active: entrypoint.runGreeter
    }
}
