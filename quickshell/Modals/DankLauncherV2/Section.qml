pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

Item {
    id: root

    property var section: null
    property var controller: null
    property string viewMode: "list"
    property int gridColumns: 4
    property int startIndex: 0

    signal itemClicked(int flatIndex)
    signal itemRightClicked(int flatIndex, var item, real mouseX, real mouseY)

    height: headerItem.height + (section?.collapsed ? 0 : contentLoader.height + Theme.spacingXS)
    width: parent?.width ?? 200

    SectionHeader {
        id: headerItem
        width: parent.width
        section: root.section
        controller: root.controller
        viewMode: root.viewMode
        canChangeViewMode: root.controller?.canChangeSectionViewMode(root.section?.id) ?? true

        onViewModeToggled: {
            if (root.controller && root.section) {
                var newMode = root.viewMode === "list" ? "grid" : "list";
                root.controller.setSectionViewMode(root.section.id, newMode);
            }
        }
    }

    Loader {
        id: contentLoader
        anchors.top: headerItem.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Theme.spacingXS
        active: !root.section?.collapsed
        visible: active

        sourceComponent: root.viewMode === "grid" ? gridComponent : listComponent

        Component {
            id: listComponent

            Column {
                spacing: 4
                width: contentLoader.width

                Repeater {
                    model: ScriptModel {
                        values: root.section?.items ?? []
                        objectProp: "id"
                    }

                    ResultItem {
                        required property var modelData
                        required property int index

                        width: parent?.width ?? 200
                        item: modelData
                        isSelected: (root.startIndex + index) === root.controller?.selectedFlatIndex
                        controller: root.controller
                        flatIndex: root.startIndex + index

                        onClicked: root.itemClicked(root.startIndex + index)
                        onRightClicked: (mouseX, mouseY) => {
                            root.itemRightClicked(root.startIndex + index, modelData, mouseX, mouseY);
                        }
                    }
                }
            }
        }

        Component {
            id: gridComponent

            Flow {
                width: contentLoader.width
                spacing: 4

                Repeater {
                    model: ScriptModel {
                        values: root.section?.items ?? []
                        objectProp: "id"
                    }

                    GridItem {
                        required property var modelData
                        required property int index

                        width: Math.floor(contentLoader.width / root.gridColumns)
                        height: width + 24
                        item: modelData
                        isSelected: (root.startIndex + index) === root.controller?.selectedFlatIndex
                        controller: root.controller
                        flatIndex: root.startIndex + index

                        onClicked: root.itemClicked(root.startIndex + index)
                        onRightClicked: (mouseX, mouseY) => {
                            root.itemRightClicked(root.startIndex + index, modelData, mouseX, mouseY);
                        }
                    }
                }
            }
        }
    }
}
