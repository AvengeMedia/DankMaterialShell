pragma Singleton

import Quickshell
import qs.DankCommon.Common as DankCommon

Singleton {
    readonly property var rounding: DankCommon.Appearance.rounding
    readonly property var spacing: DankCommon.Appearance.spacing
    readonly property var fontSize: DankCommon.Appearance.fontSize
    readonly property var anim: DankCommon.Appearance.anim
}
