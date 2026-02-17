import "../Common/fzf.js" as Fzf
import QtQml
import QtQuick
import QtQuick.Layouts
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
    onOpened: {
        Qt.callLater(() => modalFocusScope.forceActiveFocus());
        if (!Object.keys(KeybindsService.cheatsheet).length && KeybindsService.cheatsheetAvailable)
            KeybindsService.loadCheatsheet();
    }

    HyprlandFocusGrab {
        windows: [root.contentWindow]
        active: root.useHyprlandFocusGrab && root.shouldHaveFocus
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

                RowLayout {
                    width: parent.width

                    StyledText {
                        Layout.alignment: Qt.AlignLeft
                        text: KeybindsService.cheatsheet.title || "Keybinds"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Bold
                        color: Theme.primary
                    }

                    DankTextField {
                        id: searchField
                        Layout.alignment: Qt.AlignRight
                        leftIconName: "search"
                        onTextEdited: searchDebounce.restart()
                    }
                }

                Timer {
                    id: searchDebounce
                    interval: 50
                    repeat: false
                    onTriggered: {
                        mainFlickable.categories = mainFlickable.generateCategories(searchField.text);
                    }
                }

                DankFlickable {
                    id: mainFlickable
                    width: parent.width
                    height: parent.height - parent.spacing - 40
                    contentWidth: rowLayout.implicitWidth
                    contentHeight: rowLayout.implicitHeight
                    clip: true

                    Component.onCompleted: root.activeFlickable = mainFlickable

                    property var rawBinds: KeybindsService.cheatsheet.binds || {}

                    function generateCategories(query) {
                        // flatten all keybinds in an array for use by fuzzy finder
                        const allBinds = [];
                        for (const cat in rawBinds) {
                            const binds = rawBinds[cat];
                            for (let i = 0; i < binds.length; i++) {
                                const bind = binds[i];
                                if (bind.hideOnOverlay)
                                    continue;
                                allBinds.push({
                                    cat: cat,
                                    theBind: bind
                                });
                            }
                        }

                        // NOTE: This is a very blunt selector that could certainly be improved.
                        // In my tests, selecting by key does not work well which is problematic (even
                        // when other elements are removed from the selector, see note below). Selecting
                        // by querying the action works fine.
                        const selector = bind => `${bind.theBind.key || ""}:${bind.theBind.action || ""}:${bind.theBind.desc || ""}:${bind.cat || ""}:${bind.theBind.subcat || ""}`;
                        const fzfFinder = new Fzf.Finder(allBinds, {
                            selector: selector,
                            casing: "case-insensitive"
                        });

                        // NOTE: for some reason, I do not get the same results here
                        // and using fzf separately in a node shell with the same inputs.
                        // In particular, a query like "Mod+C" will not give priority to "Mod+C" or
                        // "Mod+Comma" in my config, but rather to "Mod+B". I do not know the reason...
                        const filteredBinds = fzfFinder.find(query).map(r => r.item);

                        const processed = {};
                        for (let i = 0; i < filteredBinds.length; i++) {
                            const bind = filteredBinds[i].theBind;
                            const cat = filteredBinds[i].cat;
                            if (!processed[cat]) {
                                processed[cat] = {
                                    hasSubcats: false,
                                    subcats: {},
                                    subcatKeys: [],
                                };
                            }
                            const subcat = bind.subcat || "_root";
                            if (bind.subcat) {
                                processed[cat].hasSubcats = true;
                            }
                            if (!processed[cat].subcats[subcat]) {
                                processed[cat].subcats[subcat] = [];
                                processed[cat].subcatKeys.push(subcat);
                            }
                            processed[cat].subcats[subcat].push(bind);
                        }

                        return processed;
                    }

                    property var categories: generateCategories("");

                    function estimateCategoryHeight(catName) {
                        const catData = categories[catName];
                        if (!catData)
                            return 0;
                        let bindCount = 0;
                        for (const key of catData.subcatKeys) {
                            bindCount += catData.subcats[key]?.length || 0;
                            if (key !== "_root")
                                bindCount += 1;
                        }
                        return 40 + bindCount * 28;
                    }

                    function distributeCategories(cols) {
                        const columns = [];
                        const heights = [];
                        for (let i = 0; i < cols; i++) {
                            columns.push([]);
                            heights.push(0);
                        }
                        const sorted = [...Object.keys(categories)].sort((a, b) => estimateCategoryHeight(b) - estimateCategoryHeight(a));
                        for (const cat of sorted) {
                            let minIdx = 0;
                            for (let i = 1; i < cols; i++) {
                                if (heights[i] < heights[minIdx])
                                    minIdx = i;
                            }
                            columns[minIdx].push(cat);
                            heights[minIdx] += estimateCategoryHeight(cat);
                        }
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
                                spacing: Theme.spacingXL

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

                                                            Item {
                                                                width: parent.width
                                                                height: 24

                                                                StyledRect {
                                                                    id: keyBadge
                                                                    width: Math.min(keyText.implicitWidth + 12, 160)
                                                                    height: 22
                                                                    radius: 4
                                                                    anchors.verticalCenter: parent.verticalCenter

                                                                    StyledText {
                                                                        id: keyText
                                                                        anchors.centerIn: parent
                                                                        color: Theme.secondary
                                                                        text: modelData.key || ""
                                                                        font.pixelSize: Theme.fontSizeSmall
                                                                        font.weight: Font.Medium
                                                                        isMonospace: true
                                                                    }
                                                                }

                                                                StyledText {
                                                                    anchors.left: parent.left
                                                                    anchors.leftMargin: 170
                                                                    anchors.right: parent.right
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    text: modelData.desc || modelData.action || ""
                                                                    font.pixelSize: Theme.fontSizeSmall
                                                                    opacity: 0.9
                                                                    elide: Text.ElideRight
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
