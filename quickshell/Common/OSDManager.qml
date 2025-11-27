pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

Singleton {
    id: osdManager

    property var currentOSDsByScreen: ({})

    function showOSD(osd) {
        if (!osd || !osd.screen)
            return;
        const screenName = osd.screen.name;
        const currentOSD = currentOSDsByScreen[screenName];

        if (currentOSD && currentOSD !== osd) {
            currentOSD.hide();
        }

        currentOSDsByScreen[screenName] = osd;
    }
}
