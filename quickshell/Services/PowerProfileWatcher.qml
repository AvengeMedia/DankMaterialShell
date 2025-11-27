pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    property int currentProfile: -1
    property int previousProfile: -1

    signal profileChanged(int profile)

    Connections {
        target: typeof PowerProfiles !== "undefined" ? PowerProfiles : null

        function onProfileChanged() {
            if (typeof PowerProfiles !== "undefined") {
                root.previousProfile = root.currentProfile;
                root.currentProfile = PowerProfiles.profile;
                if (root.previousProfile !== -1) {
                    root.profileChanged(root.currentProfile);
                }
            }
        }
    }

    Component.onCompleted: {
        if (typeof PowerProfiles !== "undefined") {
            root.currentProfile = PowerProfiles.profile;
            root.previousProfile = PowerProfiles.profile;
        }
    }
}
