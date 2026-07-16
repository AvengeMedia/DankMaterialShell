pragma Singleton

import QtQuick
import Quickshell
import qs.DankCommon.Common as DankCommon

Singleton {
    readonly property bool enabled: DankCommon.ListViewTransitions.enabled
    readonly property Transition add: DankCommon.ListViewTransitions.add
    readonly property Transition remove: DankCommon.ListViewTransitions.remove
    readonly property Transition displaced: DankCommon.ListViewTransitions.displaced
    readonly property Transition move: DankCommon.ListViewTransitions.move
}
