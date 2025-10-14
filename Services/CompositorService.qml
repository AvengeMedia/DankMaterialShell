pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common

Singleton {
    id: root

    property bool isHyprland: false
    property bool isNiri: false
    property string compositor: "unknown"

    readonly property string hyprlandSignature: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property string niriSocket: Quickshell.env("NIRI_SOCKET")

    property bool useNiriSorting: isNiri && NiriService

    property var sortedToplevels: {
        if (!ToplevelManager.toplevels || !ToplevelManager.toplevels.values) {
            return []
        }

        if (useNiriSorting) {
            return NiriService.sortToplevels(ToplevelManager.toplevels.values)
        }

        if (isHyprland) {
            const hyprlandToplevels = Array.from(Hyprland.toplevels.values)

            const sortedHyprland = hyprlandToplevels.sort((a, b) => {
                                                              if (a.monitor && b.monitor) {
                                                                  const monitorCompare = a.monitor.name.localeCompare(b.monitor.name)
                                                                  if (monitorCompare !== 0) {
                                                                      return monitorCompare
                                                                  }
                                                              }

                                                              if (a.workspace && b.workspace) {
                                                                  const workspaceCompare = a.workspace.id - b.workspace.id
                                                                  if (workspaceCompare !== 0) {
                                                                      return workspaceCompare
                                                                  }
                                                              }

                                                              if (a.lastIpcObject && b.lastIpcObject && a.lastIpcObject.at && b.lastIpcObject.at) {
                                                                  const aX = a.lastIpcObject.at[0]
                                                                  const bX = b.lastIpcObject.at[0]
                                                                  const aY = a.lastIpcObject.at[1]
                                                                  const bY = b.lastIpcObject.at[1]

                                                                  const xCompare = aX - bX
                                                                  if (Math.abs(xCompare) > 10) {
                                                                      return xCompare
                                                                  }
                                                                  return aY - bY
                                                              }

                                                              if (a.lastIpcObject && !b.lastIpcObject) {
                                                                  return -1
                                                              }
                                                              if (!a.lastIpcObject && b.lastIpcObject) {
                                                                  return 1
                                                              }

                                                              if (a.title && b.title) {
                                                                  return a.title.localeCompare(b.title)
                                                              }

                                                              return 0
                                                          })

            return sortedHyprland.map(hyprToplevel => hyprToplevel.wayland).filter(wayland => wayland !== null)
        }

        return ToplevelManager.toplevels.values
    }

    Timer {
        id: compositorInitTimer
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            detectCompositor()
            Qt.callLater(() => NiriService.generateNiriLayoutConfig())
        }
    }

    function filterCurrentWorkspace(toplevels, screen) {
        if (useNiriSorting) {
            return NiriService.filterCurrentWorkspace(toplevels, screen)
        }
        if (isHyprland) {
            return filterHyprlandCurrentWorkspace(toplevels, screen)
        }
        return toplevels
    }

    function filterHyprlandCurrentWorkspace(toplevels, screenName) {
        if (!toplevels || toplevels.length === 0 || !Hyprland.toplevels) {
            return toplevels
        }

        let currentWorkspaceId = null
        const hyprlandToplevels = Array.from(Hyprland.toplevels.values)

        for (const hyprToplevel of hyprlandToplevels) {
            if (hyprToplevel.monitor && hyprToplevel.monitor.name === screenName && hyprToplevel.workspace) {
                if (hyprToplevel.activated) {
                    currentWorkspaceId = hyprToplevel.workspace.id
                    break
                }
                if (currentWorkspaceId === null) {
                    currentWorkspaceId = hyprToplevel.workspace.id
                }
            }
        }

        if (currentWorkspaceId === null && Hyprland.workspaces) {
            const workspaces = Array.from(Hyprland.workspaces.values)
            for (const workspace of workspaces) {
                if (workspace.monitor && workspace.monitor === screenName) {
                    if (Hyprland.focusedWorkspace && workspace.id === Hyprland.focusedWorkspace.id) {
                        currentWorkspaceId = workspace.id
                        break
                    }
                    if (currentWorkspaceId === null) {
                        currentWorkspaceId = workspace.id
                    }
                }
            }
        }

        if (currentWorkspaceId === null) {
            return toplevels
        }

        return toplevels.filter(toplevel => {
                                    for (const hyprToplevel of hyprlandToplevels) {
                                        if (hyprToplevel.wayland === toplevel) {
                                            return hyprToplevel.workspace && hyprToplevel.workspace.id === currentWorkspaceId
                                        }
                                    }
                                    return false
                                })
    }

    function detectCompositor() {
        if (hyprlandSignature && hyprlandSignature.length > 0) {
            isHyprland = true
            isNiri = false
            compositor = "hyprland"
            console.log("CompositorService: Detected Hyprland")
            return
        }

        if (niriSocket && niriSocket.length > 0) {
            Proc.runCommand("niriSocketCheck", ["test", "-S", root.niriSocket], (output, exitCode) => {
                if (exitCode === 0) {
                    root.isNiri = true
                    root.isHyprland = false
                    root.compositor = "niri"
                    console.log("CompositorService: Detected Niri with socket:", root.niriSocket)
                    NiriService.generateNiriBinds()
                } else {
                    root.isHyprland = false
                    root.isNiri = true
                    root.compositor = "niri"
                    console.warn("CompositorService: Niri socket check failed, defaulting to Niri anyway")
                }
            }, 0)
        } else {
            isHyprland = false
            isNiri = false
            compositor = "unknown"
            console.warn("CompositorService: No compositor detected")
        }
    }

    function powerOffMonitors() {
        if (isNiri) {
            return NiriService.powerOffMonitors()
        }
        if (isHyprland) {
            return Hyprland.dispatch("dpms off")
        }
        console.warn("CompositorService: Cannot power off monitors, unknown compositor")
    }

    function powerOnMonitors() {
        if (isNiri) {
            return NiriService.powerOnMonitors()
        }
        if (isHyprland) {
            return Hyprland.dispatch("dpms on")
        }
        console.warn("CompositorService: Cannot power on monitors, unknown compositor")
    }
}