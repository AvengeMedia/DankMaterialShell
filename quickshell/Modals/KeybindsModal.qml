import QtQuick
import Quickshell.Hyprland
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankModal {
    id: root

    layerNamespace: "dms:keybinds"
    useOverlayLayer: true
    property real scrollStep: 60
    property var activeFlickable: null
    property real _maxW: Math.min(Screen.width * 0.92, 1200)
    property real _maxH: Math.min(Screen.height * 0.92, 900)
    modalWidth: _maxW
    modalHeight: _maxH
    onBackgroundClicked: close()
    onOpened: () => Qt.callLater(() => modalFocusScope.forceActiveFocus())

    HyprlandFocusGrab {
        windows: [root.contentWindow]
        active: CompositorService.isHyprland && root.shouldHaveFocus
    }

    function scrollDown() {
        if (!root.activeFlickable)
            return;
        let newY = root.activeFlickable.contentY + scrollStep;
        newY = Math.min(newY, root.activeFlickable.contentHeight - root.activeFlickable.height);
        root.activeFlickable.contentY = newY;
    }

    function scrollUp() {
        if (!root.activeFlickable)
            return;
        let newY = root.activeFlickable.contentY - root.scrollStep;
        newY = Math.max(0, newY);
        root.activeFlickable.contentY = newY;
    }

    modalFocusScope.Keys.onPressed: event => {
        if (event.key === Qt.Key_J && event.modifiers & Qt.ControlModifier) {
            scrollDown();
            event.accepted = true;
        } else if (event.key === Qt.Key_K && event.modifiers & Qt.ControlModifier) {
            scrollUp();
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            scrollDown();
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            scrollUp();
            event.accepted = true;
        }
    }

    content: Component {
        Item {
            anchors.fill: parent

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingL

                StyledText {
                    text: KeybindsService.keybinds.title || "Keybinds"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    color: Theme.primary
                }

                DankFlickable {
                    id: mainFlickable
                    width: parent.width
                    height: parent.height - parent.spacing - 40
                    contentWidth: rowLayout.implicitWidth
                    contentHeight: rowLayout.implicitHeight
                    clip: true

                    Component.onCompleted: root.activeFlickable = mainFlickable

                    property var rawBinds: KeybindsService.keybinds.binds || {}
                    property var categories: {
                        const processed = {};
                        for (const cat in rawBinds) {
                            const binds = rawBinds[cat];
                            const subcats = {};
                            let hasSubcats = false;

                            for (let i = 0; i < binds.length; i++) {
                                const bind = binds[i];
                                if (bind.subcat) {
                                    hasSubcats = true;
                                    if (!subcats[bind.subcat])
                                        subcats[bind.subcat] = [];
                                    subcats[bind.subcat].push(bind);
                                } else {
                                    if (!subcats["_root"])
                                        subcats["_root"] = [];
                                    subcats["_root"].push(bind);
                                }
                            }

                            processed[cat] = {
                                hasSubcats: hasSubcats,
                                subcats: subcats,
                                subcatKeys: Object.keys(subcats)
                            };
                        }
                        return processed;
                    }
                    property var categoryKeys: Object.keys(categories)

                    function distributeCategories(cols) {
                        const columns = [];
                        for (let i = 0; i < cols; i++)
                            columns.push([]);
                        for (let i = 0; i < categoryKeys.length; i++)
                            columns[i % cols].push(categoryKeys[i]);
                        return columns;
                    }

                    Row {
                        id: rowLayout
                        width: mainFlickable.width
                        spacing: Theme.spacingM

                        property int numColumns: Math.max(1, Math.min(3, Math.floor(width / 350)))
                        property var columnCategories: mainFlickable.distributeCategories(numColumns)

                        Repeater {
                            model: rowLayout.numColumns

                            Column {
                                id: masonryColumn
                                width: (rowLayout.width - rowLayout.spacing * (rowLayout.numColumns - 1)) / rowLayout.numColumns
                                spacing: Theme.spacingM

                                Repeater {
                                    model: rowLayout.columnCategories[index] || []

                                    Column {
                                        id: categoryColumn
                                        width: parent.width
                                        spacing: Theme.spacingXS

                                        property string catName: modelData
                                        property var catData: mainFlickable.categories[catName]

                                        StyledText {
                                            text: categoryColumn.catName
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Bold
                                            color: Theme.primary
                                        }

                                        Rectangle {
                                            width: parent.width
                                            height: 1
                                            color: Theme.primary
                                            opacity: 0.3
                                        }

                                        Item {
                                            width: 1
                                            height: Theme.spacingXS
                                        }

                                        Column {
                                            width: parent.width
                                            spacing: Theme.spacingM

                                            Repeater {
                                                model: categoryColumn.catData?.subcatKeys || []

                                                Column {
                                                    width: parent.width
                                                    spacing: Theme.spacingXS

                                                    property string subcatName: modelData
                                                    property var subcatBinds: categoryColumn.catData?.subcats?.[subcatName] || []

                                                    StyledText {
                                                        visible: parent.subcatName !== "_root"
                                                        text: parent.subcatName
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        font.weight: Font.DemiBold
                                                        color: Theme.primary
                                                        opacity: 0.7
                                                    }

                                                    Column {
                                                        width: parent.width
                                                        spacing: Theme.spacingXS

                                                        Repeater {
                                                            model: parent.parent.subcatBinds

                                                            Row {
                                                                width: parent.width
                                                                spacing: Theme.spacingS

                                                                StyledRect {
                                                                    width: Math.min(140, parent.width * 0.42)
                                                                    height: 22
                                                                    radius: 4
                                                                    opacity: 0.9

                                                                    StyledText {
                                                                        anchors.centerIn: parent
                                                                        anchors.margins: 2
                                                                        width: parent.width - 4
                                                                        color: Theme.secondary
                                                                        text: modelData.key || ""
                                                                        font.pixelSize: Theme.fontSizeSmall
                                                                        font.weight: Font.Medium
                                                                        isMonospace: true
                                                                        elide: Text.ElideRight
                                                                        horizontalAlignment: Text.AlignHCenter
                                                                    }
                                                                }

                                                                StyledText {
                                                                    width: parent.width - 150
                                                                    text: modelData.desc || ""
                                                                    font.pixelSize: Theme.fontSizeSmall
                                                                    opacity: 0.9
                                                                    elide: Text.ElideRight
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
