import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets

pragma ComponentBehavior: Bound

PanelWindow {
    id: root

    property string layerNamespace: "dms:slideout"
    WlrLayershell.namespace: layerNamespace

    property bool isVisible: false
    property var targetScreen: null
    property var modelData: null
    property real slideoutWidth: 480
    property bool expandable: false
    property bool expandedWidth: false
    property real expandedWidthValue: 960
    property Component content: null
    property string title: ""
    property alias container: contentContainer
    property real customTransparency: -1

    function show() {
        visible = true
        isVisible = true
    }

    function hide() {
        isVisible = false
    }

    function toggle() {
        if (isVisible) {
            hide()
        } else {
            show()
        }
    }

    visible: isVisible
    screen: modelData

    anchors.top: true
    anchors.bottom: true
    anchors.right: true

    implicitWidth: expandable ? expandedWidthValue : slideoutWidth
    implicitHeight: modelData ? modelData.height : 800

    color: "transparent"

    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: isVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        item: Rectangle {
            x: root.width - contentRect.width
            y: 0
            width: contentRect.width
            height: root.height
        }
    }

    StyledRect {
        id: contentRect
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(width * Math.max(2, root.modelData?.devicePixelRatio || 1), height * Math.max(2, root.modelData?.devicePixelRatio || 1))
        layer.samples: 4

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: expandable && expandedWidth ? expandedWidthValue : slideoutWidth
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b,
                       customTransparency >= 0 ? customTransparency : SettingsData.popupTransparency)
        border.color: Theme.outlineMedium
        border.width: 1
        radius: Theme.cornerRadius
        visible: isVisible || slideAnimation.running

        transform: Translate {
            id: slideTransform
            x: isVisible ? 0 : contentRect.width

            Behavior on x {
                NumberAnimation {
                    id: slideAnimation
                    duration: 450
                    easing.type: Easing.OutCubic

                    onRunningChanged: {
                        if (!running && !isVisible) {
                            root.visible = false
                        }
                    }
                }
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }

        Column {
            id: headerColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM
            visible: root.title !== ""

            Row {
                width: parent.width
                height: 32

                Column {
                    width: parent.width - buttonRow.width
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        text: root.title
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }
                }

                Row {
                    id: buttonRow
                    spacing: Theme.spacingXS

                    DankActionButton {
                        id: expandButton
                        iconName: root.expandedWidth ? "unfold_less" : "unfold_more"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        visible: root.expandable
                        onClicked: root.expandedWidth = !root.expandedWidth

                        transform: Rotation {
                            angle: 90
                            origin.x: expandButton.width / 2
                            origin.y: expandButton.height / 2
                        }
                    }

                    DankActionButton {
                        id: closeButton
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: root.hide()
                    }
                }
            }
        }

        Item {
            id: contentContainer
            anchors.top: root.title !== "" ? headerColumn.bottom : parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.topMargin: root.title !== "" ? 0 : Theme.spacingL
            anchors.leftMargin: Theme.spacingL
            anchors.rightMargin: Theme.spacingL
            anchors.bottomMargin: Theme.spacingL

            Loader {
                anchors.fill: parent
                sourceComponent: root.content
            }
        }
    }
}