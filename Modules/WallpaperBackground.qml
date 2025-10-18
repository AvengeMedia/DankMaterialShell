import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wlr
import qs.Common
import qs.Services
import qs.Widgets
import ".."

LazyLoader {
    active: true

    Variants {
        model: SettingsData.getFilteredScreens("wallpaper")

        PanelWindow {
            id: wallpaperWindow

            required property var modelData

            screen: modelData

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            color: "black"

            Item {
                id: root
                anchors.fill: parent

                property string source: SessionData.getMonitorWallpaper(modelData.name) || ""
                property bool isColorSource: source.startsWith("#")
                property Image current: one

                WallpaperEngineProc {
                    id: weProc
                    monitor: modelData.name
                }

                Component.onDestruction: {
                    weProc.stop()
                    GslapperService.stopVideo(modelData.name)
                }

                onSourceChanged: {
                    const isWE = source.startsWith("we:")
                    const isGS = source.startsWith("gs:")
                    if (isWE) {
                        current = null
                        one.source = ""
                        two.source = ""
                        GslapperService.stopVideo(modelData.name)
                        weProc.start(source.substring(3)) // strip "we:"
                    } else if (isGS) {
                        current = null
                        one.source = ""
                        two.source = ""
                        weProc.stop()
                        const videoPath = source.substring(3) // strip "gs:"

                        if (!SessionData.perMonitorWallpaper) {
                            // Global mode: Only start from the first monitor to avoid duplicates
                            // Use comma-separated monitor list for gSlapper dual output
                            const allScreens = Quickshell.screens
                            const firstScreenName = allScreens.length > 0 ? allScreens[0].name : ""

                            if (modelData.name === firstScreenName) {
                                const outputNames = allScreens.map(screen => screen.name).join(",")
                                console.log("WallpaperBackground: Starting global video with monitors:", outputNames)
                                GslapperService.startVideo(outputNames, videoPath)
                            } else {
                                console.log("WallpaperBackground: Skipping duplicate global video start for monitor:", modelData.name, "(first screen is", firstScreenName + ")")
                            }
                        } else if (SessionData.perMonitorWallpaper) {
                            // Per-monitor mode: start individual process for this specific monitor
                            console.log("WallpaperBackground: Starting per-monitor video for:", modelData.name)
                            GslapperService.startVideo(modelData.name, videoPath)
                        }
                    } else {
                        weProc.stop()
                        GslapperService.stopVideo(modelData.name)
                        if (!source) {
                            current = null
                            one.source = ""
                            two.source = ""
                        } else if (isColorSource) {
                            current = null
                            one.source = ""
                            two.source = ""
                        } else {
                            if (current === one)
                                two.update()
                            else
                                one.update()
                        }
                    }
                }

                onIsColorSourceChanged: {
                    if (isColorSource) {
                        current = null
                        one.source = ""
                        two.source = ""
                    } else if (source) {
                        if (current === one)
                            two.update()
                        else
                            one.update()
                    }
                }

                Loader {
                    active: !root.source || root.isColorSource
                    asynchronous: true

                    sourceComponent: DankBackdrop {
                        screenName: modelData.name
                    }
                }

                Img {
                    id: one
                }

                Img {
                    id: two
                }

                component Img: Image {
                    id: img

                    function update(): void {
                        source = ""
                        source = root.source
                    }

                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                    cache: false

                    opacity: 0

                    onStatusChanged: {
                        if (status === Image.Ready) {
                            root.current = this
                            if (root.current === one && two.source) {
                                two.source = ""
                            } else if (root.current === two && one.source) {
                                one.source = ""
                            }
                        }
                    }

                    states: State {
                        name: "visible"
                        when: root.current === img

                        PropertyChanges {
                            img.opacity: 1
                        }
                    }

                    transitions: Transition {
                        NumberAnimation {
                            target: img
                            properties: "opacity"
                            duration: Theme.mediumDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }
}