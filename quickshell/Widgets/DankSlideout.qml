import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
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
    signal aboutToHide

    function show() {
        visible = true
        isVisible = true
    }

    function hide() {
        aboutToHide()
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

    // Expandable: fixed max surface width; strip width is slideContainer only (keeps blur/mask aligned).
    implicitWidth: expandable ? expandedWidthValue : slideoutWidth
    implicitHeight: modelData ? modelData.height : 800

    color: "transparent"

    readonly property bool slideoutBlurActive: root.visible && BlurService.enabled

    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: isVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property real dpr: CompositorService.getScreenScale(root.screen)
    readonly property real alignedWidth: Theme.px(expandable && expandedWidth ? expandedWidthValue : slideoutWidth, dpr)
    readonly property real alignedHeight: Theme.px(modelData ? modelData.height : 800, dpr)
    readonly property real slideoutSlideSnapX: Theme.snap(slideContainer.slideOffset, dpr)

    mask: Region {
        item: Rectangle {
            x: root.width - slideContainer.width
            y: 0
            width: slideContainer.width
            height: root.height
        }
    }

    Item {
        id: slideContainer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: alignedWidth
        height: alignedHeight

        property real slideOffset: alignedWidth

        Connections {
            target: root
            function onIsVisibleChanged() {
                slideContainer.slideOffset = root.isVisible ? 0 : slideContainer.width
            }
        }

        Behavior on slideOffset {
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

        // Expandable only; mask/blur bind to slideContainer geometry so they track this animation.
        Behavior on width {
            enabled: root.expandable
            NumberAnimation {
                duration: Theme.popoutAnimationDuration
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: contentRect
            layer.enabled: Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1"
            layer.smooth: false
            layer.textureSize: Qt.size(width * root.dpr, height * root.dpr)
            opacity: 1

            readonly property real effectiveTransparency: customTransparency >= 0 ? customTransparency : SettingsData.popupTransparency

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width
            x: root.slideoutSlideSnapX

            Rectangle {
                anchors.fill: parent
                color: Theme.transparentBlurLayers ? "transparent" : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, contentRect.effectiveTransparency)
                radius: Theme.cornerRadius
                border.color: BlurService.enabled ? BlurService.borderColor : Theme.outlineMedium
                border.width: BlurService.borderWidth
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

    // Blur region from slideContainer (not layered contentRect); position uses x + slideoutSlideSnapX, not mapToItem(root).
    WindowBlur {
        targetWindow: root
        blurX: root.slideoutBlurActive ? slideContainer.x + root.slideoutSlideSnapX : 0
        blurY: root.slideoutBlurActive ? slideContainer.y : 0
        blurWidth: root.slideoutBlurActive ? slideContainer.width : 0
        blurHeight: root.slideoutBlurActive ? slideContainer.height : 0
        blurRadius: Theme.cornerRadius
    }
}
