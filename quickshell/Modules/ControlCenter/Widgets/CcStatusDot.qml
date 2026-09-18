import QtQuick
import qs.Common
import qs.Modules.ControlCenter

Rectangle {
    property real size: CcMetrics.statusDotSize

    width: size
    height: size
    radius: size / 2
    color: Theme.primary
}
