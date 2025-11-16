pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: modalManager

    signal closeAllModalsExcept(var excludedModal)

    function openModal(modal) {
        if (!modal.allowStacking) {
            closeAllModalsExcept(modal)
        }
        if (!modal.keepPopoutsOpen) {
            PopoutManager.closeAllPopouts()
        }
        TrayMenuManager.closeAllMenus()
    }
}
