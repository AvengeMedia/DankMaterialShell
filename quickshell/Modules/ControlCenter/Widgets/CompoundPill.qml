import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string iconName: ""
    property color iconColor: Theme.surfaceText
    property string primaryText: ""
    property string secondaryText: ""
    property bool expanded: false
    property bool isActive: false
    property bool showExpandArea: true

    signal toggled
    signal expandClicked
    signal wheelEvent(var wheelEvent)

    width: parent ? parent.width : 220
    height: 60
    radius: Theme.cornerRadius

    function hoverTint(base) {
        const factor = 1.2;
        return Theme.isLightMode ? Qt.darker(base, factor) : Qt.lighter(base, factor);
    }

    readonly property color _containerBg: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

    color: {
        const baseColor = bodyMouse.containsMouse ? Theme.primaryPressed : _containerBg;
        return baseColor;
    }
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)
    border.width: 0
    antialiasing: true

    readonly property color _labelPrimary: Theme.surfaceText
    readonly property color _labelSecondary: Theme.surfaceVariantText
    readonly property color _tileBgActive: Theme.ccTileActiveBg
    readonly property color _tileBgInactive: {
        const transparency = Theme.popupTransparency;
        const surface = Theme.surfaceContainer || Qt.rgba(0.1, 0.1, 0.1, 1);
        return Qt.rgba(surface.r, surface.g, surface.b, transparency);
    }
    readonly property color _tileRingActive: Theme.ccTileRing
    readonly property color _tileRingInactive: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
    readonly property color _tileIconActive: Theme.ccTileActiveText
    readonly property color _tileIconInactive: Theme.ccTileInactiveIcon

    property int _padH: Theme.spacingS
    property int _tileSize: 48
    property int _tileRadius: Theme.cornerRadius

    Rectangle {
        id: rightHoverOverlay
        anchors.fill: parent
        radius: root.radius
        z: 0
        visible: false
        color: hoverTint(_containerBg)
        opacity: 0.08
        antialiasing: true
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
            }
        }
    }

    DankRipple {
        id: bodyRipple
        cornerRadius: root.radius
    }

    Row {
        id: row
        anchors.fill: parent
        anchors.leftMargin: _padH
        anchors.rightMargin: Theme.spacingM
        spacing: Theme.spacingM

        Rectangle {
            id: iconTile
            z: 1
            width: _tileSize
            height: _tileSize
            anchors.verticalCenter: parent.verticalCenter
            radius: _tileRadius
            color: isActive ? _tileBgActive : _tileBgInactive
            border.color: isActive ? _tileRingActive : "transparent"
            border.width: isActive ? 1 : 0
            antialiasing: true

            Rectangle {
                anchors.fill: parent
                radius: _tileRadius
                color: hoverTint(iconTile.color)
                opacity: tileMouse.pressed ? 0.3 : (tileMouse.containsMouse ? 0.2 : 0.0)
                visible: opacity > 0
                antialiasing: true
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shortDuration
                    }
                }
            }

            DankIcon {
                anchors.centerIn: parent
                name: iconName
                size: Theme.iconSize
                color: isActive ? _tileIconActive : _tileIconInactive
            }

            DankRipple {
                id: tileRipple
                cornerRadius: _tileRadius
            }

            MouseArea {
                id: tileMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => tileRipple.trigger(mouse.x, mouse.y)
                onClicked: root.toggled()
            }
        }

        Item {
            id: body
            width: row.width - iconTile.width - row.spacing
            height: row.height

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                StyledText {
                    width: parent.width
                    text: root.primaryText
                    color: _labelPrimary
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    horizontalAlignment: Text.AlignLeft
                }
                StyledText {
                    width: parent.width
                    text: root.secondaryText
                    color: _labelSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    visible: text.length > 0
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    horizontalAlignment: Text.AlignLeft
                }
            }

            MouseArea {
                id: bodyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    rightHoverOverlay.visible = true;
                    rightHoverOverlay.opacity = 0.08;
                }
                onExited: {
                    rightHoverOverlay.opacity = 0.0;
                    rightHoverOverlay.visible = false;
                }
                onPressed: mouse => {
                    const pos = mapToItem(root, mouse.x, mouse.y);
                    bodyRipple.trigger(pos.x, pos.y);
                    rightHoverOverlay.opacity = 0.16;
                }
                onReleased: rightHoverOverlay.opacity = containsMouse ? 0.08 : 0.0
                onClicked: root.expandClicked()
                onWheel: function (ev) {
                    root.wheelEvent(ev);
                }
            }
        }
    }

    focus: true
    Keys.onPressed: function (ev) {
        if (ev.key === Qt.Key_Space || ev.key === Qt.Key_Return) {
            root.toggled();
            ev.accepted = true;
        } else if (ev.key === Qt.Key_Right) {
            root.expandClicked();
            ev.accepted = true;
        }
    }
}
