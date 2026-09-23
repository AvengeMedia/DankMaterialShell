import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Settings.Widgets
import qs.DankCommon.Common as DC

ShellRoot {
    id: root
    property bool finished: false

    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 600
        implicitHeight: 600

        Column {
            width: 400
            SettingsGroup {
                id: outer
                SettingsRow {
                    id: bodyRow
                    body: Column {
                        width: parent.width
                        StyledText {
                            text: "Heading"
                        }
                        SettingsGroup {
                            id: nested
                            SettingsNavRow {
                                title: "First"
                                hint: "Description"
                            }
                            SettingsNavRow {
                                title: "Second"
                                hint: "Description"
                            }
                        }
                    }
                }
            }
            SettingsGroup {
                id: following
                SettingsNavRow {
                    title: "Following"
                }
            }
        }
    }

    Connections {
        target: window.contentItem.Window.window
        function onFrameSwapped() {
            if (root.finished)
                return;
            root.finished = true;
            const required = bodyRow.implicitHeight;
            const passed = outer.height === required && following.y === outer.height && required > nested.height;
            console.log((passed ? "FIXTURE_PASS" : "FIXTURE_FAIL") + " first painted group bounds " + JSON.stringify({
                outer: outer.height,
                required: required,
                following: following.y,
                nested: nested.height
            }));
            Qt.quit();
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }
}
