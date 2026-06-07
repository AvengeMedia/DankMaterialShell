pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property int subTabIndex: 0

    readonly property var workspaceSections: ({
            "workspaceSettings": true,
            "showWorkspaceIndex": true,
            "showWorkspaceName": true,
            "showWorkspacePadding": true,
            "showWorkspaceApps": true,
            "groupWorkspaceApps": true,
            "groupActiveWorkspaceApps": true,
            "workspaceActiveAppHighlightEnabled": true,
            "workspaceFollowFocus": true,
            "showOccupiedWorkspacesOnly": true,
            "reverseScrolling": true,
            "workspaceDragReorder": true,
            "dwlShowAllTags": true,
            "workspaceIcons": true
        })
    readonly property var layoutSections: ({
            "niriLayout": true,
            "niriLayoutGapsOverrideEnabled": true,
            "niriLayoutGapsOverride": true,
            "niriLayoutRadiusOverrideEnabled": true,
            "niriLayoutRadiusOverride": true,
            "niriLayoutBorderSizeEnabled": true,
            "niriLayoutBorderSize": true,
            "hyprlandLayout": true,
            "hyprlandLayoutGapsOverrideEnabled": true,
            "hyprlandLayoutGapsOverride": true,
            "hyprlandLayoutRadiusOverrideEnabled": true,
            "hyprlandLayoutRadiusOverride": true,
            "hyprlandLayoutBorderSizeEnabled": true,
            "hyprlandLayoutBorderSize": true,
            "hyprlandResizeOnBorder": true,
            "mangoLayout": true,
            "mangoLayoutGapsOverrideEnabled": true,
            "mangoLayoutGapsOverride": true,
            "mangoLayoutRadiusOverrideEnabled": true,
            "mangoLayoutRadiusOverride": true,
            "mangoLayoutBorderSizeEnabled": true,
            "mangoLayoutBorderSize": true
        })

    function routeSearchTarget(target) {
        if (!target)
            return;
        if (workspaceSections[target]) {
            subTabIndex = 0;
        } else if (layoutSections[target]) {
            subTabIndex = 1;
        } else if (target === "windowRules" || target.startsWith("windowRule")) {
            subTabIndex = 2;
        }
    }

    Component.onCompleted: routeSearchTarget(SettingsSearchService.targetSection)

    Connections {
        target: SettingsSearchService

        function onTargetSectionChanged() {
            root.routeSearchTarget(SettingsSearchService.targetSection);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "transparent"

            DankTabBar {
                id: compositorTabBar

                width: Math.min(500, parent.width - Theme.spacingL * 2)
                height: 45
                anchors.centerIn: parent
                model: [
                    {
                        "text": I18n.tr("Workspaces"),
                        "icon": "view_module"
                    },
                    {
                        "text": I18n.tr("Window Layout"),
                        "icon": "crop_square"
                    },
                    {
                        "text": I18n.tr("Window Rules"),
                        "icon": "select_window"
                    }
                ]
                currentIndex: root.subTabIndex
                onTabClicked: index => root.subTabIndex = index
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: compositorTabBar.y + compositorTabBar.height + 10
                width: compositorTabBar.width
                height: 1
                color: Theme.surface
                opacity: 0.56
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Loader {
                anchors.fill: parent
                active: root.subTabIndex === 0
                visible: active
                sourceComponent: WorkspacesTab {}
            }

            Loader {
                anchors.fill: parent
                active: root.subTabIndex === 1
                visible: active
                sourceComponent: CompositorLayoutTab {}
            }

            Loader {
                id: windowRulesLoader

                property bool loadedOnce: false

                anchors.fill: parent
                active: root.subTabIndex === 2 || loadedOnce
                visible: root.subTabIndex === 2 && status === Loader.Ready
                asynchronous: true
                sourceComponent: WindowRulesTab {
                    pageActive: root.subTabIndex === 2
                }

                onLoaded: loadedOnce = true
            }

            StyledText {
                anchors.centerIn: parent
                visible: root.subTabIndex === 2 && windowRulesLoader.status === Loader.Loading
                text: I18n.tr("Loading...", "loading indicator")
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeMedium
            }
        }
    }
}
