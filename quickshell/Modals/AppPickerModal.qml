import QtQuick
import qs.Common
import qs.Modals.Common
import qs.Widgets
import qs.Services

DankModal {
    id: root
    readonly property var log: Log.scoped("AppPickerModal")

    property string title: I18n.tr("Select Application")
    property string targetData: ""
    property string targetDataLabel: ""
    property string searchQuery: ""
    property int selectedIndex: 0
    property int gridColumns: SettingsData.appLauncherGridColumns
    property bool keyboardNavigationActive: false
    property string viewMode: "grid"
    property var categoryFilter: []
    property var usageHistoryKey: ""
    property bool showTargetData: true
    property string mimeType: ""
    property var rememberMimeTypes: []
    property bool rememberChoice: false
    property var mimeMatchedAppIds: []

    signal applicationSelected(var app, string targetData)

    function _normAppId(id) {
        if (!id)
            return "";
        return id.replace(/\.desktop$/, "").toLowerCase();
    }

    shouldBeVisible: false
    allowStacking: true
    modalWidth: 520
    modalHeight: 500

    onBackgroundClicked: close()

    onDialogClosed: {
        searchQuery = "";
        selectedIndex = 0;
        keyboardNavigationActive = false;
    }

    onOpened: {
        searchQuery = "";
        rememberChoice = false;
        fetchMimeMatches();
        updateApplicationList();
        selectedIndex = 0;
        Qt.callLater(() => {
            if (contentLoader.item && contentLoader.item.searchField) {
                contentLoader.item.searchField.text = "";
                contentLoader.item.searchField.forceActiveFocus();
            }
        });
    }

    function fetchMimeMatches() {
        mimeMatchedAppIds = [];
        const queriedMime = mimeType;
        if (queriedMime.length === 0)
            return;
        DMSService.sendRequest("mime.appsForMime", {
            "mimeType": queriedMime
        }, response => {
            if (queriedMime !== root.mimeType)
                return;
            if (response.error) {
                log.warn("mime.appsForMime failed:", response.error);
                return;
            }
            const ids = (response.result && response.result.desktopIds) || [];
            mimeMatchedAppIds = ids.map(_normAppId);
            updateApplicationList();
        });
    }

    function _appMatchesMime(app, mime) {
        const list = app && (app.mimeTypes || app.mimeType);
        return !!list && !!list.includes && list.includes(mime);
    }

    function updateApplicationList() {
        applicationsModel.clear();
        const apps = AppSearchService.applications;
        const usageHistory = usageHistoryKey && SettingsData[usageHistoryKey] ? SettingsData[usageHistoryKey] : {};
        const hasCategoryFilter = categoryFilter.length > 0;
        const hasMime = mimeType.length > 0;
        const hasMimeMatches = mimeMatchedAppIds.length > 0;
        const lowerQuery = searchQuery.toLowerCase();
        let filteredApps = [];

        for (const app of apps) {
            if (!app)
                continue;
            const appId = _normAppId(app.id || app.execString || app.exec || "");
            const mimeIdMatch = hasMimeMatches && mimeMatchedAppIds.includes(appId);
            const mimeFieldMatch = hasMime && _appMatchesMime(app, mimeType);
            const mimeMatch = mimeIdMatch || mimeFieldMatch;

            let categoryMatch = false;
            if (hasCategoryFilter && app.categories) {
                try {
                    for (const cat of app.categories) {
                        if (categoryFilter.includes(cat)) {
                            categoryMatch = true;
                            break;
                        }
                    }
                } catch (e) {
                    log.warn("AppPicker: Error iterating categories for", app.name, ":", e);
                    continue;
                }
            }

            const include = (!hasCategoryFilter && !hasMime) || mimeMatch || categoryMatch;
            if (!include)
                continue;

            const name = app.name || "";
            if (searchQuery !== "" && !name.toLowerCase().includes(lowerQuery))
                continue;

            filteredApps.push({
                name: name,
                icon: app.icon || "application-x-executable",
                exec: app.exec || app.execString || "",
                startupClass: app.startupWMClass || "",
                appData: app,
                mimeMatch: mimeMatch
            });
        }

        filteredApps.sort((a, b) => {
            if (a.mimeMatch !== b.mimeMatch) {
                return a.mimeMatch ? -1 : 1;
            }
            const aId = a.appData.id || a.appData.execString || a.appData.exec || "";
            const bId = b.appData.id || b.appData.execString || b.appData.exec || "";
            const aUsage = usageHistory[aId] ? usageHistory[aId].count : 0;
            const bUsage = usageHistory[bId] ? usageHistory[bId].count : 0;
            if (aUsage !== bUsage) {
                return bUsage - aUsage;
            }
            return (a.name || "").localeCompare(b.name || "");
        });

        filteredApps.forEach(app => {
            applicationsModel.append({
                name: app.name,
                icon: app.icon,
                exec: app.exec,
                startupClass: app.startupClass,
                appId: app.appData.id || app.appData.execString || app.appData.exec || ""
            });
        });

        log.debug("AppPicker: Found " + filteredApps.length + " applications");
    }

    onSearchQueryChanged: updateApplicationList()

    ListModel {
        id: applicationsModel
    }

    content: Component {
        FocusScope {
            id: appContent

            property alias searchField: searchField

            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: event => {
                root.close();
                event.accepted = true;
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Tab && root.mimeType.length > 0) {
                    root.rememberChoice = !root.rememberChoice;
                    event.accepted = true;
                    return;
                }

                if (applicationsModel.count === 0)
                    return;

                if (root.viewMode === "grid") {
                    if (event.key === Qt.Key_Left) {
                        root.keyboardNavigationActive = true;
                        root.selectedIndex = Math.max(0, root.selectedIndex - 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right) {
                        root.keyboardNavigationActive = true;
                        root.selectedIndex = Math.min(applicationsModel.count - 1, root.selectedIndex + 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        root.keyboardNavigationActive = true;
                        root.selectedIndex = Math.max(0, root.selectedIndex - root.gridColumns);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down) {
                        root.keyboardNavigationActive = true;
                        root.selectedIndex = Math.min(applicationsModel.count - 1, root.selectedIndex + root.gridColumns);
                        event.accepted = true;
                    }
                } else {
                    if (event.key === Qt.Key_Up) {
                        root.keyboardNavigationActive = true;
                        root.selectedIndex = Math.max(0, root.selectedIndex - 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down) {
                        root.keyboardNavigationActive = true;
                        root.selectedIndex = Math.min(applicationsModel.count - 1, root.selectedIndex + 1);
                        event.accepted = true;
                    }
                }

                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.selectedIndex >= 0 && root.selectedIndex < applicationsModel.count) {
                        const app = applicationsModel.get(root.selectedIndex);
                        launchApplication(app);
                    }
                    event.accepted = true;
                }
            }

            Column {
                width: parent.width - Theme.spacingS * 2
                height: parent.height - Theme.spacingS * 2
                x: Theme.spacingS
                y: Theme.spacingS
                spacing: Theme.spacingS

                Item {
                    width: parent.width
                    height: 40

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.title
                        font.pixelSize: Theme.fontSizeLarge + 4
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }

                    Row {
                        spacing: 4
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter

                        DankActionButton {
                            buttonSize: 36
                            circular: false
                            iconName: "view_list"
                            iconSize: 20
                            iconColor: root.viewMode === "list" ? Theme.primary : Theme.surfaceText
                            backgroundColor: root.viewMode === "list" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                            onClicked: {
                                root.viewMode = "list";
                            }
                        }

                        DankActionButton {
                            buttonSize: 36
                            circular: false
                            iconName: "grid_view"
                            iconSize: 20
                            iconColor: root.viewMode === "grid" ? Theme.primary : Theme.surfaceText
                            backgroundColor: root.viewMode === "grid" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                            onClicked: {
                                root.viewMode = "grid";
                            }
                        }
                    }
                }

                DankTextField {
                    id: searchField

                    width: parent.width - Theme.spacingS * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 52
                    cornerRadius: Theme.cornerRadius
                    backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    normalBorderColor: Theme.outlineMedium
                    focusedBorderColor: Theme.primary
                    leftIconName: "search"
                    leftIconSize: Theme.iconSize
                    leftIconColor: Theme.surfaceVariantText
                    leftIconFocusedColor: Theme.primary
                    showClearButton: true
                    font.pixelSize: Theme.fontSizeLarge
                    enabled: root.shouldBeVisible
                    ignoreLeftRightKeys: root.viewMode !== "list"
                    ignoreTabKeys: true
                    keyForwardTargets: [appContent]

                    onTextEdited: {
                        root.searchQuery = text;
                    }

                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_Escape) {
                            root.close();
                            event.accepted = true;
                            return;
                        }

                        const isEnterKey = [Qt.Key_Return, Qt.Key_Enter].includes(event.key);
                        const hasText = text.length > 0;

                        if (isEnterKey && hasText) {
                            if (root.keyboardNavigationActive && applicationsModel.count > 0) {
                                const app = applicationsModel.get(root.selectedIndex);
                                launchApplication(app);
                            } else if (applicationsModel.count > 0) {
                                const app = applicationsModel.get(0);
                                launchApplication(app);
                            }
                            event.accepted = true;
                            return;
                        }

                        const navigationKeys = [Qt.Key_Down, Qt.Key_Up, Qt.Key_Left, Qt.Key_Right, Qt.Key_Tab, Qt.Key_Backtab];
                        const isNavigationKey = navigationKeys.includes(event.key);
                        const isEmptyEnter = isEnterKey && !hasText;

                        event.accepted = !(isNavigationKey || isEmptyEnter);
                    }

                    Connections {
                        function onShouldBeVisibleChanged() {
                            if (!root.shouldBeVisible) {
                                searchField.focus = false;
                            }
                        }

                        target: root
                    }
                }

                Rectangle {
                    width: parent.width
                    height: {
                        let usedHeight = 40 + Theme.spacingS;
                        usedHeight += 52 + Theme.spacingS;
                        if (root.showTargetData) {
                            usedHeight += 36 + Theme.spacingS;
                        }
                        if (root.mimeType && root.mimeType.length > 0) {
                            usedHeight += 36 + Theme.spacingS;
                        }
                        return parent.height - usedHeight;
                    }
                    radius: Theme.cornerRadius
                    color: "transparent"

                    DankListView {
                        id: appList

                        property int itemHeight: 60
                        property int itemSpacing: Theme.spacingS

                        function ensureVisible(index) {
                            if (index < 0 || index >= count)
                                return;
                            const itemY = index * (itemHeight + itemSpacing);
                            const itemBottom = itemY + itemHeight;
                            if (itemY < contentY) {
                                contentY = itemY;
                            } else if (itemBottom > contentY + height) {
                                contentY = itemBottom - height;
                            }
                        }

                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingS
                        anchors.rightMargin: Theme.spacingS
                        anchors.bottomMargin: Theme.spacingS

                        visible: root.viewMode === "list"
                        model: applicationsModel
                        currentIndex: root.selectedIndex
                        clip: true
                        spacing: itemSpacing

                        onCurrentIndexChanged: {
                            root.selectedIndex = currentIndex;
                            if (root.keyboardNavigationActive) {
                                ensureVisible(currentIndex);
                            }
                        }

                        delegate: AppLauncherListDelegate {
                            listView: appList
                            itemHeight: 60
                            iconSize: 40
                            showDescription: false

                            isCurrentItem: index === root.selectedIndex
                            keyboardNavigationActive: root.keyboardNavigationActive
                            hoverUpdatesSelection: true

                            onItemClicked: (idx, modelData) => {
                                launchApplication(modelData);
                            }

                            onKeyboardNavigationReset: {
                                root.keyboardNavigationActive = false;
                            }
                        }
                    }

                    DankGridView {
                        id: appGrid

                        function ensureVisible(index) {
                            if (index < 0 || index >= count)
                                return;
                            const itemY = Math.floor(index / root.gridColumns) * cellHeight;
                            const itemBottom = itemY + cellHeight;
                            if (itemY < contentY) {
                                contentY = itemY;
                            } else if (itemBottom > contentY + height) {
                                contentY = itemBottom - height;
                            }
                        }

                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingS
                        anchors.rightMargin: Theme.spacingS
                        anchors.bottomMargin: Theme.spacingS

                        visible: root.viewMode === "grid"
                        model: applicationsModel
                        cellWidth: width / root.gridColumns
                        cellHeight: 120
                        clip: true
                        currentIndex: root.selectedIndex

                        onCurrentIndexChanged: {
                            root.selectedIndex = currentIndex;
                            if (root.keyboardNavigationActive) {
                                ensureVisible(currentIndex);
                            }
                        }

                        delegate: AppLauncherGridDelegate {
                            gridView: appGrid
                            cellWidth: appGrid.cellWidth
                            cellHeight: appGrid.cellHeight

                            currentIndex: root.selectedIndex
                            keyboardNavigationActive: root.keyboardNavigationActive
                            hoverUpdatesSelection: true

                            onItemClicked: (idx, modelData) => {
                                launchApplication(modelData);
                            }

                            onKeyboardNavigationReset: {
                                root.keyboardNavigationActive = false;
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 36
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.color: Theme.outlineMedium
                    border.width: 1
                    visible: root.showTargetData && root.targetData.length > 0

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.targetDataLabel.length > 0 ? root.targetDataLabel + ": " + root.targetData : root.targetData
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                        elide: Text.ElideMiddle
                        wrapMode: Text.NoWrap
                        maximumLineCount: 1
                    }
                }

                Item {
                    width: parent.width
                    height: 36
                    visible: root.mimeType.length > 0

                    DankToggle {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        checked: root.rememberChoice
                        text: I18n.tr("Always use this app for %1").arg(root.mimeType)
                        onToggled: checked => {
                            root.rememberChoice = checked;
                        }
                    }
                }
            }

            function launchApplication(app) {
                if (!app)
                    return;

                if (root.rememberChoice && app.appId) {
                    const targets = (root.rememberMimeTypes && root.rememberMimeTypes.length > 0) ? root.rememberMimeTypes : (root.mimeType ? [root.mimeType] : []);
                    if (targets.length > 0) {
                        DesktopService.setDefaultAppForMimes(targets, app.appId);
                    }
                }

                root.applicationSelected(app, root.targetData);

                if (usageHistoryKey && app.appId) {
                    const usageHistory = SettingsData[usageHistoryKey] || {};
                    const currentCount = usageHistory[app.appId] ? usageHistory[app.appId].count : 0;
                    usageHistory[app.appId] = {
                        count: currentCount + 1,
                        lastUsed: Date.now(),
                        name: app.name
                    };
                    SettingsData.set(usageHistoryKey, usageHistory);
                }

                root.close();
            }
        }
    }
}
