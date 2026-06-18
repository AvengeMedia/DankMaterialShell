pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    // Exit the labwc session. Used by SessionService when the user
    // triggers logout and no custom logout command is configured.
    function quit() {
        Quickshell.execDetached(["labwc", "--exit"]);
    }
}
