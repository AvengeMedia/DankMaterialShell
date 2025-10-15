import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Common
import qs.Modals.Common
import qs.Modules.AppDrawer
import qs.Services
import qs.Widgets

DankModal {
    id: spotlightModal

    property bool spotlightOpen: false
    property alias spotlightContent: spotlightContentInstance

    function show() {
        spotlightOpen = true
        open()

        Qt.callLater(() => {
            if (spotlightContent && spotlightContent.searchField) {
                spotlightContent.searchField.forceActiveFocus()
            }
        })
    }

    function showWithQuery(query) {
        if (spotlightContent) {
            if (spotlightContent.appLauncher) {
                spotlightContent.appLauncher.searchQuery = query
            }
            if (spotlightContent.searchField) {
                spotlightContent.searchField.text = query
            }
        }

        spotlightOpen = true
        open()

        Qt.callLater(() => {
            if (spotlightContent && spotlightContent.searchField) {
                spotlightContent.searchField.forceActiveFocus()
            }
        })
    }

    function hide() {
        spotlightOpen = false
        close()
    }

    onDialogClosed: {
        if (spotlightContent) {
            if (spotlightContent.appLauncher) {
                spotlightContent.appLauncher.searchQuery = ""
                spotlightContent.appLauncher.selectedIndex = 0
                spotlightContent.appLauncher.setCategory(I18n.tr("All"))
            }
            if (spotlightContent.resetScroll) {
                spotlightContent.resetScroll()
            }
            if (spotlightContent.searchField) {
                spotlightContent.searchField.text = ""
            }
        }
    }

    function toggle() {
        if (spotlightOpen) {
            hide()
        } else {
            show()
        }
    }

    shouldBeVisible: spotlightOpen
    width: 550
    height: 700
    backgroundColor: Theme.popupBackground()
    cornerRadius: Theme.cornerRadius
    borderColor: Theme.outlineMedium
    borderWidth: 1
    enableShadow: true
    keepContentLoaded: true
    onVisibleChanged: () => {
                          if (visible && !spotlightOpen) {
                              show()
                          }
                          if (visible && spotlightContent) {
                              Qt.callLater(() => {
                                               if (spotlightContent.searchField) {
                                                   spotlightContent.searchField.forceActiveFocus()
                                               }
                                           })
                          }
                      }
    onBackgroundClicked: () => {
                             return hide()
                         }

    Connections {
        function onCloseAllModalsExcept(excludedModal) {
            if (excludedModal !== spotlightModal && !allowStacking && spotlightOpen) {
                spotlightOpen = false
            }
        }

        target: ModalManager
    }

    IpcHandler {
        function open(): string  {
            spotlightModal.show()
            return "SPOTLIGHT_OPEN_SUCCESS"
        }

        function close(): string  {
            spotlightModal.hide()
            return "SPOTLIGHT_CLOSE_SUCCESS"
        }

        function toggle(): string  {
            spotlightModal.toggle()
            return "SPOTLIGHT_TOGGLE_SUCCESS"
        }

        function openQuery(query: string): string {
            spotlightModal.showWithQuery(query)
            return "SPOTLIGHT_OPEN_QUERY_SUCCESS"
        }

        function toggleQuery(query: string): string {
            if (spotlightModal.spotlightOpen) {
                spotlightModal.hide()
            } else {
                spotlightModal.showWithQuery(query)
            }
            return "SPOTLIGHT_TOGGLE_QUERY_SUCCESS"
        }

        target: "spotlight"
    }

    SpotlightContent {
        id: spotlightContentInstance

        parentModal: spotlightModal
    }

    directContent: spotlightContentInstance
}
