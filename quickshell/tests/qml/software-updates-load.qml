import QtQuick
import Quickshell
import qs.Common
import qs.DankCommon.Common as DC

// The Software updates page and its Release notes leaf must instantiate.
ShellRoot {
    id: root

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }

    Timer {
        interval: 0
        running: SettingsData._hasLoaded && SessionData._hasLoaded
        onTriggered: {
            host.setSource("Modules/Settings/SoftwareUpdatesTab.qml");
            leaf.setSource("Modules/Settings/ChangelogTab.qml");
        }
    }

    Item {
        width: 720
        height: 900

        Loader {
            id: host
            width: parent.width
        }

        Loader {
            id: leaf
            width: parent.width
        }
    }

    Timer {
        interval: 25
        repeat: true
        running: host.status !== Loader.Null && leaf.status !== Loader.Null

        onTriggered: {
            if (host.status === Loader.Loading || leaf.status === Loader.Loading)
                return;
            if (host.status === Loader.Error || leaf.status === Loader.Error) {
                console.log("FIXTURE_FAIL " + host.sourceComponent?.errorString() + " " + leaf.sourceComponent?.errorString());
                Qt.exit(1);
                return;
            }
            console.log("FIXTURE_PASS");
            Qt.exit(0);
        }
    }
}
