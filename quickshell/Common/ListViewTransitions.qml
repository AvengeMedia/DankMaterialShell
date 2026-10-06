pragma Singleton

import QtQuick
import Quickshell
import qs.DCommon.Common as DCommon

Singleton {
    readonly property bool enabled: DCommon.ListViewTransitions.enabled
    readonly property Transition add: DCommon.ListViewTransitions.add
    readonly property Transition remove: DCommon.ListViewTransitions.remove
    readonly property Transition displaced: DCommon.ListViewTransitions.displaced
    readonly property Transition move: DCommon.ListViewTransitions.move
}
