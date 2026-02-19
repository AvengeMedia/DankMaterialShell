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
        Qt.callLater(() => {
            modalFocusScope.forceActiveFocus();
            if (contentLoader.item?.searchField)
                contentLoader.item.searchField.forceActiveFocus();
        });
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
            property alias searchField: searchField

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
                        keyForwardTargets: [root.modalFocusScope]
                        onTextEdited: searchDebounce.restart()
                        Keys.onEscapePressed: event => {
                            root.close();
                            event.accepted = true;
                        }
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
                        const lowerQuery = query ? query.toLowerCase().trim() : "";
                        const lowerQueryWords = query.split(/\s+/);
                        const processed = {};

                        for (const cat in rawBinds) {
                            const binds = rawBinds[cat];
                            const catLower = cat.toLowerCase();
                            const subcats = {};
                            let hasSubcats = false;
                            for (let i = 0; i < binds.length; i++) {
                                const bind = binds[i];
                                const keyLower = bind.key.toLowerCase();
                                const descLower = bind.desc.toLowerCase();
                                const actionLower = bind.action.toLowerCase();

                                if (bind.hideOnOverlay)
                                    continue;
                                let shouldContinue = false;
                                for (let j = 0; j < lowerQueryWords.length; j++) {
                                    const word = lowerQueryWords[j];
                                    if (!(
                                        word.length === 0 ||
                                        keyLower.includes(word) ||
                                        descLower.includes(word) ||
                                        catLower.includes(word) ||
                                        actionLower.includes(word)
                                    )) {
                                        shouldContinue = true;
                                        break;
                                    }
                                }
                                if (shouldContinue)
                                    continue;

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

                            if (Object.keys(subcats).length === 0)
                                continue;

                            processed[cat] = {
                                hasSubcats: hasSubcats,
                                subcats: subcats,
                                subcatKeys: Object.keys(subcats)
                            };
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

                    property var categoryKeys: Object.keys(categories);

                    function distributeCategories(cols) {
                        const columns = [];
                        const heights = [];
                        for (let i = 0; i < cols; i++) {
                            columns.push([]);
                            heights.push(0);
                        }
                        const sorted = [...categoryKeys].sort((a, b) => estimateCategoryHeight(b) - estimateCategoryHeight(a));
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
