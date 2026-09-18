import QtQuick
import qs.Common

Rectangle {
    width: parent?.width ?? 0
    height: Theme.dividerWidth
    color: Theme.outlineVariant
    visible: !(parent?.isSettingsGroupHost ?? false)
}
