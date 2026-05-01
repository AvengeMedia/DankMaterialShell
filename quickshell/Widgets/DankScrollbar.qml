import QtQuick
import QtQuick.Controls
import qs.Common

ScrollBar {
    id: scrollbar

    property var targetFlickable: null
    readonly property var _target: targetFlickable ?? parent

    property bool _scrollBarActive: false
    property alias hideTimer: hideScrollBarTimer
    property bool _isParentMoving: _target && (_target.moving || _target.flicking || _target.isMomentumActive)
    property bool _shouldShow: pressed || hovered || active || _isParentMoving || _scrollBarActive

    policy: (_target && _target.contentHeight > _target.height) ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
    minimumSize: 0.08
    implicitWidth: 10
    interactive: true
    hoverEnabled: true
    z: 1000
    opacity: (policy !== ScrollBar.AlwaysOff && _shouldShow) ? 1.0 : 0.0
    visible: policy !== ScrollBar.AlwaysOff

    Behavior on opacity {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutQuad
        }
    }

    contentItem: Rectangle {
        implicitWidth: 6
        radius: width / 2
        color: scrollbar.pressed ? Theme.primary : scrollbar._shouldShow ? Theme.outline : Theme.outlineMedium
        opacity: scrollbar.pressed ? 1.0 : scrollbar._shouldShow ? 1.0 : 0.6
    }

    background: Item {}

    Timer {
        id: hideScrollBarTimer
        interval: 1200
        onTriggered: scrollbar._scrollBarActive = false
    }
}
