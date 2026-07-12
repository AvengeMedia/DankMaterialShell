pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.Common
import qs.Services

Singleton {
    id: root

    readonly property bool hasAccent: true
    readonly property color accent: Theme.primary

    readonly property color onAccent: Theme.onPrimary

    readonly property color accentHover: Theme.withAlpha(accent, 0.12)
    readonly property color accentPressed: Theme.withAlpha(accent, Theme.transparentBlurLayers ? 0.24 : 0.16)

    readonly property color accentTrack: Theme.withAlpha(accent, 0.28)
    readonly property color accentSubtle: Theme.withAlpha(accent, 0.55)
}
