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
    readonly property Transition remove: null
    readonly property Transition displaced: enabled ? _displaced : null
    readonly property Transition move: enabled ? _move : null

    readonly property int _staggerMs: Math.round(Theme.currentAnimationBaseDuration * 0.03)
    readonly property int _staggerCap: 8

    readonly property Transition _add: Transition {
        id: addTransition

        SequentialAnimation {
            PropertyAction {
                property: "opacity"
                value: 0
            }
            PauseAnimation {
                duration: Math.max(0, Math.min(addTransition.ViewTransition.index - (addTransition.ViewTransition.targetIndexes[0] ?? 0), root._staggerCap)) * root._staggerMs
            }
            DankAnim {
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.expressiveDurations.fast
                easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
            }
        }
    }

    readonly property Transition _displaced: Transition {
        DankAnim {
            property: "y"
            duration: Theme.expressiveDurations.fast
            easing.bezierCurve: Theme.expressiveCurves.standard
        }
        DankAnim {
            property: "opacity"
            to: 1
            duration: Theme.expressiveDurations.fast
            easing.bezierCurve: Theme.expressiveCurves.standard
        }
    }

    readonly property Transition _move: Transition {
        DankAnim {
            property: "y"
            duration: Theme.expressiveDurations.fast
            easing.bezierCurve: Theme.expressiveCurves.standard
        }
        DankAnim {
            property: "opacity"
            to: 1
            duration: Theme.expressiveDurations.fast
            easing.bezierCurve: Theme.expressiveCurves.standard
        }
    }
}
