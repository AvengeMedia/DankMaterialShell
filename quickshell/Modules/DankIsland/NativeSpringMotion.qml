pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    property bool enabled: true
    property bool animationsEnabled: true

    property real spring: 5
    property real damping: 0.32
    property real mass: 1
    property real epsilon: 0.04

    property real currentWidth: 176
    property real currentHeight: 42
    property real currentOffsetX: 0
    property real currentOffsetY: 8
    property real currentTopLeftRadius: 21
    property real currentTopRightRadius: 21
    property real currentBottomLeftRadius: 21
    property real currentBottomRightRadius: 21

    property real targetWidth: currentWidth
    property real targetHeight: currentHeight
    property real targetOffsetX: currentOffsetX
    property real targetOffsetY: currentOffsetY
    property real targetTopLeftRadius: currentTopLeftRadius
    property real targetTopRightRadius: currentTopRightRadius
    property real targetBottomLeftRadius: currentBottomLeftRadius
    property real targetBottomRightRadius: currentBottomRightRadius

    readonly property bool running: widthSpring.running || heightSpring.running || offsetXSpring.running || offsetYSpring.running || topLeftRadiusSpring.running || topRightRadiusSpring.running
        || bottomLeftRadiusSpring.running || bottomRightRadiusSpring.running

    function setTarget(target) {
        targetWidth = target.width;
        targetHeight = target.height;
        targetOffsetX = target.offsetX;
        targetOffsetY = target.offsetY;
        targetTopLeftRadius = target.topLeftRadius;
        targetTopRightRadius = target.topRightRadius;
        targetBottomLeftRadius = target.bottomLeftRadius;
        targetBottomRightRadius = target.bottomRightRadius;

        currentWidth = targetWidth;
        currentHeight = targetHeight;
        currentOffsetX = targetOffsetX;
        currentOffsetY = targetOffsetY;
        currentTopLeftRadius = targetTopLeftRadius;
        currentTopRightRadius = targetTopRightRadius;
        currentBottomLeftRadius = targetBottomLeftRadius;
        currentBottomRightRadius = targetBottomRightRadius;
    }

    function snapTo(target) {
        animationsEnabled = false;

        targetWidth = target.width;
        targetHeight = target.height;
        targetOffsetX = target.offsetX;
        targetOffsetY = target.offsetY;
        targetTopLeftRadius = target.topLeftRadius;
        targetTopRightRadius = target.topRightRadius;
        targetBottomLeftRadius = target.bottomLeftRadius;
        targetBottomRightRadius = target.bottomRightRadius;

        currentWidth = target.width;
        currentHeight = target.height;
        currentOffsetX = target.offsetX;
        currentOffsetY = target.offsetY;
        currentTopLeftRadius = target.topLeftRadius;
        currentTopRightRadius = target.topRightRadius;
        currentBottomLeftRadius = target.bottomLeftRadius;
        currentBottomRightRadius = target.bottomRightRadius;

        animationsEnabled = true;
    }

    Behavior on currentWidth {
        enabled: root.enabled && root.animationsEnabled

        SpringAnimation {
            id: widthSpring
            spring: root.spring
            damping: root.damping
            mass: root.mass
            epsilon: root.epsilon
        }
    }

    Behavior on currentHeight {
        enabled: root.enabled && root.animationsEnabled

        SpringAnimation {
            id: heightSpring
            spring: root.spring
            damping: root.damping
            mass: root.mass
            epsilon: root.epsilon
        }
    }

    Behavior on currentOffsetX {
        enabled: root.enabled && root.animationsEnabled

        SpringAnimation {
            id: offsetXSpring
            spring: root.spring
            damping: root.damping
            mass: root.mass
            epsilon: root.epsilon
        }
    }

    Behavior on currentOffsetY {
        enabled: root.enabled && root.animationsEnabled

        SpringAnimation {
            id: offsetYSpring
            spring: root.spring
            damping: root.damping
            mass: root.mass
            epsilon: root.epsilon
        }
    }

    Behavior on currentTopLeftRadius {
        enabled: root.enabled && root.animationsEnabled

        SpringAnimation {
            id: topLeftRadiusSpring
            spring: root.spring
            damping: root.damping
            mass: root.mass
            epsilon: root.epsilon
        }
    }

    Behavior on currentTopRightRadius {
        enabled: root.enabled && root.animationsEnabled

        SpringAnimation {
            id: topRightRadiusSpring
            spring: root.spring
            damping: root.damping
            mass: root.mass
            epsilon: root.epsilon
        }
    }

    Behavior on currentBottomLeftRadius {
        enabled: root.enabled && root.animationsEnabled

        SpringAnimation {
            id: bottomLeftRadiusSpring
            spring: root.spring
            damping: root.damping
            mass: root.mass
            epsilon: root.epsilon
        }
    }

    Behavior on currentBottomRightRadius {
        enabled: root.enabled && root.animationsEnabled

        SpringAnimation {
            id: bottomRightRadiusSpring
            spring: root.spring
            damping: root.damping
            mass: root.mass
            epsilon: root.epsilon
        }
    }
}
