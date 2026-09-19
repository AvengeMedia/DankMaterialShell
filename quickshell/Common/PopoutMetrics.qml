pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property real contentPadding: Theme.spacingL
    readonly property real contentGap: Theme.spacingM
    readonly property real chromeButtonSize: Theme.iconSizeLarge
    readonly property real chromeIconSize: Theme.iconSizeSmall
    readonly property real panelChromeInset: Theme.spacingS
    readonly property real editOverflow: Math.max(Theme.minimumTouchTargetSize, chromeButtonSize) / 2
}
