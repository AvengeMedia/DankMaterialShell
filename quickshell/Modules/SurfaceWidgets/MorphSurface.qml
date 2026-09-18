pragma ComponentBehavior: Bound
import QtQuick

Rectangle {
    required property var motion
    width: Math.max(0, motion.currentWidth)
    height: Math.max(0, motion.currentHeight)
    topLeftRadius: Math.max(0, motion.currentTopLeftRadius)
    topRightRadius: Math.max(0, motion.currentTopRightRadius)
    bottomLeftRadius: Math.max(0, motion.currentBottomLeftRadius)
    bottomRightRadius: Math.max(0, motion.currentBottomRightRadius)
}
