pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.Common
import qs.Widgets
import qs.Modules.DankDash

Item {
    id: root

    property var paths: []
    property int currentIndex: 0
    property string currentWallpaper: ""
    property bool animate: true

    signal indexRequested(int index)
    signal activated(string path)

    readonly property real itemWidth: Math.round(width * DashMetrics.carouselItemRatio)

    function syncList() {
        if (list.currentIndex !== root.currentIndex)
            list.currentIndex = root.currentIndex;
    }

    onCurrentIndexChanged: syncList()
    onPathsChanged: Qt.callLater(syncList)

    Loader {
        anchors.fill: parent
        active: root.paths.length > 0
        sourceComponent: ClippingRectangle {
            radius: DashMetrics.surfaceRadius
            color: "transparent"

            CachingImage {
                anchors.fill: parent
                imagePath: root.paths[root.currentIndex] ?? ""
                maxCacheSize: DashMetrics.wallpaperThumbCache * 2
                animate: false
                opacity: DashMetrics.carouselBackdropAlpha
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Theme.hostSurface
                    }
                    GradientStop {
                        position: 0.5
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1
                        color: Theme.hostSurface
                    }
                }
            }
        }
    }

    // Dank* wrappers reset contentY on model change and take the wheel; the carousel needs center snapping.
    ListView {
        id: list

        anchors.fill: parent
        orientation: ListView.Horizontal
        model: root.paths
        spacing: -root.itemWidth * DashMetrics.carouselOverlap
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width - root.itemWidth) / 2
        preferredHighlightEnd: preferredHighlightBegin + root.itemWidth
        highlightMoveDuration: root.animate && DashMetrics.animationsEnabled ? DashMetrics.transitionDuration : 0
        clip: true
        keyNavigationEnabled: false
        activeFocusOnTab: false
        cacheBuffer: (root.itemWidth + spacing) * 2
        currentIndex: root.currentIndex

        onCurrentIndexChanged: {
            if (!moving)
                return;
            if (currentIndex >= 0 && currentIndex !== root.currentIndex)
                root.indexRequested(currentIndex);
        }

        delegate: Item {
            id: slide

            required property int index
            required property string modelData

            readonly property real offset: (x - list.contentX + width / 2 - list.width / 2) / Math.max(1, width + list.spacing)
            readonly property real distance: Math.min(1, Math.abs(offset))
            readonly property bool selected: modelData === root.currentWallpaper

            width: root.itemWidth
            height: list.height
            scale: 1 - (1 - DashMetrics.carouselSideScale) * distance
            opacity: 1 - (1 - DashMetrics.carouselSideAlpha) * distance
            z: -Math.abs(offset)
            transform: Rotation {
                origin.x: slide.width / 2
                origin.y: slide.height / 2
                axis {
                    x: 0
                    y: 1
                    z: 0
                }
                angle: -Math.max(-1, Math.min(1, slide.offset)) * DashMetrics.carouselAngle
            }

            Rectangle {
                id: frame

                anchors.centerIn: parent
                width: parent.width
                height: Math.min(parent.height - Theme.spacingS * 2, parent.width * DashMetrics.carouselAspect)
                radius: DashMetrics.surfaceRadius
                color: DashMetrics.chipColor

                ClippingRectangle {
                    anchors.fill: parent
                    radius: frame.radius
                    color: "transparent"

                    CachingImage {
                        anchors.fill: parent
                        imagePath: slide.modelData
                        maxCacheSize: DashMetrics.wallpaperThumbCache * 2
                        animate: false
                        opacity: status === Image.Ready ? 1 : 0

                        Behavior on opacity {
                            enabled: DashMetrics.animationsEnabled
                            NumberAnimation {
                                duration: DashMetrics.fadeDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: slide.selected ? Theme.outlineWidthFocused : 0
                    border.color: Theme.primary
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingS
                    width: Theme.iconSize
                    height: Theme.iconSize
                    radius: Theme.fullRadius(width, height)
                    color: Theme.primary
                    visible: slide.selected

                    DankIcon {
                        anchors.centerIn: parent
                        name: "check"
                        size: Theme.iconSizeSmall
                        color: Theme.onPrimary
                    }
                }

                StateLayer {
                    cornerRadius: frame.radius
                    stateColor: Theme.primary
                    onClicked: {
                        root.indexRequested(slide.index);
                        root.activated(slide.modelData);
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
            if (delta === 0)
                return;
            const next = Math.max(0, Math.min(root.paths.length - 1, root.currentIndex - Math.sign(delta)));
            if (next !== root.currentIndex)
                root.indexRequested(next);
            wheel.accepted = true;
        }
    }
}
