pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

// Reusable ListView/GridView transitions
Singleton {
    id: root

    // 0ms ViewTransitions break ListView delegate cleanup, so null the set when the shortest
    // duration truncates to 0. Keep this gate - don't inline these back into add/remove/etc.
    readonly property bool enabled: Math.floor(Theme.currentAnimationBaseDuration * 0.4) >= 1

    readonly property Transition add: enabled ? _add : null
    readonly property Transition remove: enabled ? _remove : null
    readonly property Transition displaced: enabled ? _displaced : null
    readonly property Transition move: enabled ? _move : null

    readonly property Transition _add: Transition {
        DankAnim {
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.expressiveDurations.expressiveEffects
            easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
        }
    }

    readonly property Transition _remove: Transition {
        DankAnim {
            property: "opacity"
            to: 0
            duration: Theme.expressiveDurations.fast
            easing.bezierCurve: Theme.expressiveCurves.emphasizedAccel
        }
    }

    readonly property Transition _displaced: Transition {
        DankAnim {
            property: "y"
            duration: Theme.expressiveDurations.normal
            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
        }
    }

    readonly property Transition _move: Transition {
        DankAnim {
            property: "y"
            duration: Theme.expressiveDurations.normal
            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
        }
    }
}
