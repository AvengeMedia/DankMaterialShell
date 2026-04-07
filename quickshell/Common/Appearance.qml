pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property AppearanceRounding rounding: AppearanceRounding {}
    readonly property AppearanceSpacing spacing: AppearanceSpacing {}
    readonly property AppearanceFontSize fontSize: AppearanceFontSize {}
    readonly property AppearanceAnim anim: AppearanceAnim {}
}
