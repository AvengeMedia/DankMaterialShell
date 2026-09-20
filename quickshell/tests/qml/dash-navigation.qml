import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.DankDash
import qs.Modules.DankIsland
import qs.Modules.DankIsland.Activities
import qs.Modules.Settings as Settings
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property var dash: null
    property bool captured: false
    property int customActions: 0
    readonly property string captureDirectory: Quickshell.env("DMS_FIXTURE_CAPTURE_DIR")

    Component {
        id: dashComponent
        DankDashPopout {}
    }

    Component {
        id: settingsComponent
        Settings.DankDashTab {}
    }

    QtObject {
        id: deferredDashLoader
        property bool active: false
    }

    Component {
        id: pluginComponent
        Item {
            implicitHeight: DashMetrics.tabMinHeight
            property var menuActions: [
                {
                    label: "Test action",
                    iconName: "refresh",
                    action: () => root.customActions++
                },
                {
                    label: "Hidden action",
                    visible: false
                },
                {
                    label: "Disabled action",
                    enabled: false,
                    action: () => root.customActions++
                }
            ]
        }
    }

    IslandController {
        id: island
    }

    Component {
        id: islandHome
        HomeExpanded {
            controller: island
        }
    }

    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 1100
        implicitHeight: 800
        color: Theme.surface

        DankNavigationBar {
            id: navigation
            width: 800
            height: implicitHeight
            currentIndex: 0
            model: [
                {
                    icon: "dashboard",
                    text: "Overview"
                },
                {
                    icon: "music_note",
                    text: "Media"
                }
            ]
            onActivated: index => currentIndex = index
        }
    }

    TestCase {
        id: tester
        when: false

        function check(condition, message) {
            if (!condition)
                throw new Error(message);
        }

        function find(item, predicate) {
            if (!item)
                return null;
            if (predicate(item))
                return item;
            for (const child of item.children || []) {
                const found = find(child, predicate);
                if (found)
                    return found;
            }
            return null;
        }

        function settle() {
            wait(0);
            const window = root.dash?.contentLoader.item?.Window.window;
            if (window)
                check(!isPolishScheduled(window) || waitForPolish(window, 3000), "dashboard layout settled");
        }

        function open(tab) {
            root.dash.requestTab(tab);
            root.dash.dashVisible = true;
            tryVerify(() => root.dash.shouldBeVisible && root.dash.contentLoader.item?.ready, 3000);
            settle();
        }

        function pages() {
            return find(root.dash.contentLoader.item, item => item.currentHost !== undefined);
        }

        function bar() {
            return find(root.dash.contentLoader.item, item => typeof item.moveSelection === "function");
        }

        function actionBounds(...buttons) {
            return JSON.stringify(buttons.map(button => {
                const point = button.mapToItem(root.dash.contentLoader.item, 0, 0);
                return [point.x, point.y, button.width, button.height];
            }));
        }

        function capture(name) {
            if (!root.captureDirectory)
                return;
            tryVerify(() => Math.abs(root.dash.contentLoader.item.width - root.dash.popupWidth) < 1, 3000, "rendered panel width matches requested width");
            tryVerify(() => Math.abs(root.dash.contentLoader.item.height - root.dash.popupHeight) < 1, 3000, "rendered panel height matches requested height");
            root.captured = false;
            root.dash.contentLoader.item.grabToImage(result => {
                check(result.saveToFile(root.captureDirectory + "/" + name + ".png"), "saved " + name);
                root.captured = true;
            });
            tryCompare(root, "captured", true, 3000);
        }

        function run() {
            try {
                SettingsData.weatherEnabled = true;
                SettingsData.setDashTabEnabled("overview", false);
                check(!DashRegistry.visibleTabIds.includes("overview"), "Overview can be hidden");
                check(DashRegistry.hasTab("overview"), "hidden Overview remains available");
                check(DashRegistry.defaultTabId !== "overview", "default follows enabled destinations");
                root.dash = dashComponent.createObject(root);
                root.dash.triggerScreen = Quickshell.screens[0];
                root.dash.setTriggerPosition(640, 0, 40, "center", Quickshell.screens[0]);
                open(0);
                check(root.dash.activeTabId === DashRegistry.visibleTabIds[0], "numeric default uses first enabled destination");
                open("overview");
                check(root.dash.detailTabId === "overview" && root.dash.showBack, "hidden Overview has a return destination");
                root.dash.closeDetail();
                check(root.dash.activeTabId === DashRegistry.defaultTabId, "Back returns to enabled page");

                for (const id of DashRegistry.tabIds)
                    SettingsData.setDashTabEnabled(id, false);
                open(0);
                check(root.dash.activeTabId === "" && !root.dash.showTabs, "zero tabs opens empty dashboard");
                check(pages().currentItem === null && pages().focusTarget !== null, "empty state releases page and offers settings");
                check(Math.abs(root.dash.contentLoader.item.height - root.dash.popupHeight) < 1, "zero-motion empty state snaps rendered height");
                capture("empty");
                PopoutService.dankDashPopout = root.dash;
                const settingsPage = settingsComponent.createObject(window.contentItem, {
                    width: 800,
                    height: 600,
                    visible: false
                });
                for (const id of ["overview", "media", "weather"]) {
                    const row = find(settingsPage, item => item.modelData?.id === id && item.available !== undefined);
                    const editButton = find(row, item => item.iconName === "edit" && typeof item.clicked === "function");
                    check(!!editButton, "Settings exposes editing for hidden " + id);
                    editButton.clicked();
                    check(root.dash.editMode && root.dash.activeTabId === id && !root.dash.showTabs, "Settings edits hidden " + id + " with zero tabs");
                }
                settingsPage.destroy();
                root.dash.dashVisible = false;
                root.dash.instantClose();
                PopoutService.dankDashPopout = null;
                PopoutService.dankDashPopoutLoader = deferredDashLoader;
                PopoutService.openDankDashEditor("media", Quickshell.screens[0]);
                check(deferredDashLoader.active && PopoutService._dankDashWantsEdit, "cold editor request activates loader");
                PopoutService.dankDashPopout = root.dash;
                PopoutService._onDankDashPopoutLoaded();
                check(root.dash.editMode && root.dash.activeTabId === "media" && !PopoutService._dankDashWantsEdit, "cold editor request survives loading");
                root.dash.editMode = false;
                for (const id of ["overview", "media", "weather"]) {
                    open(id);
                    check(root.dash.activeTabId === id && !root.dash.showTabs && !root.dash.showBack, "standalone hidden " + id);
                }
                capture("standalone-weather");
                root.dash.closeDetail();
                check(!root.dash.dashVisible, "standalone Back/Escape closes instead of showing empty state");

                const home = islandHome.createObject(window.contentItem, {
                    width: 800,
                    height: 600
                });
                check(home.entryId === "overview", "Island home keeps Overview identity with no enabled tabs");
                tryVerify(() => !!home.tab, 3000);
                const islandActions = find(home, item => item.overlayParent !== undefined && item.entryId === "overview");
                check(!!islandActions && islandActions.hasWidgets, "Island uses shared page actions");
                parent = window.contentItem;
                island.expanded = true;
                home.focusHeader(false);
                home.editMode = true;
                settle();
                check(home.Window.window.activeFocusItem === home, "Island edit entry clears title focus");
                islandActions.optionsRequested();
                const islandOptions = find(home, item => typeof item.presentFor === "function" && item.entryId === "overview");
                check(islandOptions.shown, "Island Options opened before Tab");
                keyClick(Qt.Key_Tab);
                check(islandOptions.shown && !islandActions.focusTargets.some(item => item.activeFocus), "Island Options keeps Tab out of edit controls: shown=" + islandOptions.shown + ", focus=" + home.Window.window.activeFocusItem);
                islandOptions.dismiss();
                island.expanded = false;
                home.destroy();

                SettingsData.setDashTabEnabled("media", true);
                open(0);
                check(root.dash.activeTabId === "media" && !root.dash.showTabs, "one destination has no navigation");
                capture("single");
                SettingsData.setDashTabEnabled("overview", true);
                SettingsData.setDashTabOrder(["overview", "media"]);
                open(0);
                for (const edge of [0, 1, 2, 3, 4, 5, 6, 7]) {
                    SettingsData.animationDuration = edge % 2 === 0 ? 0 : 200;
                    root.dash.setBarContext(edge, 0);
                    settle();
                    const nav = bar();
                    const page = pages();
                    const vertical = edge % 4 >= 2;
                    check(root.dash.showTabs && root.dash.verticalNavigation === vertical, "orientation follows edge " + edge);
                    check(nav.orientation === (vertical ? Qt.Vertical : Qt.Horizontal), "navigation orientation " + edge);
                    check(Math.abs(root.dash.contentLoader.item.width - root.dash.popupWidth) < 1, "zero-motion navigation snaps rendered width " + edge);
                    const point = nav.mapToItem(root.dash.contentLoader.item, 0, 0);
                    const contentPoint = page.mapToItem(root.dash.contentLoader.item, 0, 0);
                    const expectedEdge = [0, 1, 3, 2][edge % 4];
                    check(root.dash.navigationEdge === expectedEdge, "side defaults face away from triggering bar " + edge);
                    switch (expectedEdge) {
                    case 0:
                        check(point.y + nav.height <= contentPoint.y, "top navigation before content");
                        break;
                    case 1:
                        check(point.y >= contentPoint.y + page.height, "bottom navigation after content");
                        break;
                    case 2:
                        check(point.x + nav.width <= contentPoint.x, "left rail before content");
                        break;
                    case 3:
                        check(point.x >= contentPoint.x + page.width, "right rail after content");
                        break;
                    }
                    const size = [root.dash.popupWidth, root.dash.popupHeight];
                    root.dash.editMode = true;
                    settle();
                    check(root.dash.popupWidth === size[0] && root.dash.popupHeight === size[1], "edit preserves panel dimensions " + edge);
                    root.dash.editMode = false;
                    check(Math.abs(page.width - (root.dash.popupWidth - root.dash.navigationWidth - DashMetrics.contentPadding * 2)) < 1, "content width excludes navigation " + edge);
                    if (edge < 4)
                        capture("edge-" + edge);
                }
                SettingsData.animationDuration = 0;
                for (const [position, expectedEdge] of [["left", 2], ["right", 3], ["bottom", 1], ["center", 0]]) {
                    SettingsData.set("dashTabPosition", position);
                    root.dash.setBarContext(0, 0);
                    settle();
                    check(root.dash.navigationEdge === expectedEdge && root.dash.verticalNavigation === (expectedEdge >= 2), "position override " + position);
                    root.dash.setBarContext(3, 0);
                    check(root.dash.navigationEdge === expectedEdge, "override ignores bar position " + position);
                }
                SettingsData.set("dashTabPosition", "auto");
                root.dash.setBarContext(0, 0);
                SettingsData.resetDashTabs();
                settle();
                capture("default-tabs");
                const embeddedEdit = find(bar(), item => item.revealed !== undefined && item.visible);
                mouseMove(embeddedEdit, embeddedEdit.width / 2, embeddedEdit.height / 2);
                tryVerify(() => embeddedEdit.revealed, 1000);
                capture("hover-edit");
                mouseClick(embeddedEdit, embeddedEdit.width / 2, embeddedEdit.height / 2);
                check(root.dash.editMode, "selected icon pencil opens editing");
                root.dash.editMode = false;
                SessionData.locale = "ar";
                root.dash.setBarContext(2, 0);
                settle();
                check(I18n.isRtl && root.dash.verticalNavigation, "RTL keeps physical right rail");
                capture("rtl-right");
                SessionData.locale = "en";
                settle();
                const verticalEdit = find(bar(), item => item.revealed !== undefined && item.visible);
                const selectedIcon = find(verticalEdit.parent, item => item.filled !== undefined && item.name === "dashboard");
                check(Math.abs(verticalEdit.x + verticalEdit.width / 2 - selectedIcon.x - selectedIcon.width / 2) < 1 && Math.abs(verticalEdit.y + verticalEdit.height / 2 - selectedIcon.y - selectedIcon.height / 2) < 1, "vertical pencil stays centered on destination icon");
                mouseMove(verticalEdit, verticalEdit.width / 2, verticalEdit.height / 2);
                tryVerify(() => verticalEdit.revealed, 1000);
                capture("hover-vertical");
                root.dash.setBarContext(0, 0);
                settle();
                root.dash.requestTab("overview");
                root.dash.editMode = true;
                settle();
                const clear = find(root.dash.contentLoader.item, item => item.actionId === "clear");
                const reset = find(root.dash.contentLoader.item, item => item.actionId === "reset");
                const savedCards = JSON.stringify(SettingsData.dashCards);
                const horizontalBounds = actionBounds(clear, reset);
                clear.clicked();
                settle();
                check(clear.armed && JSON.stringify(SettingsData.dashCards) === savedCards, "Clear needs confirmation");
                check(actionBounds(clear, reset) === horizontalBounds, "arming Clear does not move or resize either horizontal action");
                check(clear.Accessible.name === I18n.tr("Confirm") && clear.color === Theme.error, "armed Clear reads as an emphasized Confirm");
                capture("confirm-horizontal");
                reset.clicked();
                settle();
                check(actionBounds(clear, reset) === horizontalBounds && !clear.armed && reset.armed, "arming Reset disarms Clear without moving either action: " + horizontalBounds + " vs " + actionBounds(clear, reset));
                clear.clicked();
                clear.clicked();
                check(SettingsData.dashCards.length === 0, "confirmed Clear removes widgets");
                reset.clicked();
                check(SettingsData.dashCards.length === 0, "Reset needs confirmation");
                reset.clicked();
                check(SettingsData.dashCards.length > 0, "confirmed Reset restores widgets");
                clear.clicked();
                root.dash.editMode = false;
                root.dash.editMode = true;
                check(!clear.armed, "leaving editing cancels confirmation");
                settle();
                const editActions = find(root.dash.contentLoader.item, item => item.overlayParent !== undefined);
                check(editActions.focusTargets.every(item => !item.visualFocus), "programmatic edit entry has no persistent focus ring");
                check(root.dash.contentLoader.item.Window.window.activeFocusItem === root.dash.contentLoader.item, "edit entry keeps neutral focus");
                capture("edit-horizontal");
                const editViewport = find(editActions, item => item.contentX !== undefined && item.wheelEnabled !== undefined);
                editActions.width = 280;
                settle();
                editActions.focusTargets[editActions.focusTargets.length - 1].forceActiveFocus(Qt.TabFocusReason);
                check(editViewport.contentX > 0, "overflowed Finish is revealed on keyboard focus");
                editActions.width = Qt.binding(() => Math.min(editActions.parent.width, editActions.implicitWidth));
                root.dash.setBarContext(2, 0);
                settle();
                capture("edit-vertical");
                const verticalBounds = actionBounds(clear, reset);
                reset.clicked();
                settle();
                check(actionBounds(clear, reset) === verticalBounds && reset.armed, "arming Reset does not move or resize either vertical action");
                capture("confirm-vertical");
                root.dash.editMode = false;
                root.dash.setBarContext(0, 0);
                settle();
                const integratedNav = bar();
                integratedNav.forceActiveFocus(Qt.TabFocusReason);
                const start = root.dash.currentTabId;
                keyClick(Qt.Key_Right);
                check(integratedNav.activeFocus && root.dash.currentTabId !== start, "first arrow preserves navigation focus");
                const next = root.dash.currentTabId;
                keyClick(Qt.Key_Right);
                check(integratedNav.activeFocus && root.dash.currentTabId !== next, "second arrow continues navigation");
                root.dash.editMode = true;
                settle();
                check(root.dash.contentLoader.item.Window.window.activeFocusItem === root.dash.contentLoader.item, "edit entry releases hidden navigation focus");
                root.dash.requestTab("weather");
                root.dash.editMode = true;
                settle();
                const weatherActions = find(root.dash.contentLoader.item, item => item.overlayParent !== undefined);
                keyClick(Qt.Key_Tab);
                check(weatherActions.focusTargets[0].activeFocus, "Weather edit Tab enters first action");
                root.dash.contentLoader.item.focusInitial();
                keyClick(Qt.Key_Backtab);
                check(weatherActions.focusTargets[weatherActions.focusTargets.length - 1].activeFocus, "Weather edit Backtab enters last action");
                root.dash.editMode = false;

                PluginService.pluginDashComponents = {
                    navigation_test: pluginComponent
                };
                PluginService.loadedPlugins = {
                    navigation_test: {
                        name: "Test",
                        surfaces: ["dash"]
                    }
                };
                open("plugin_navigation_test");
                const actions = find(root.dash.contentLoader.item, item => item.overlayParent !== undefined);
                check(!actions.visible, "no separate action strip in normal navigation");
                const nav = bar();
                check(nav.editable, "selected destination supports embedded editing");
                nav.editRequested(nav.currentIndex);
                settle();
                check(root.dash.editMode && actions.visible, "embedded editing reveals page controls");
                check(actions.implicitWidth <= actions.parent.width, "edit controls fit the header without scrolling: " + actions.implicitWidth + " > " + actions.parent.width);
                check(actions.hasCustomActions, "plugin action menu is available");
                const menu = find(root.dash.contentLoader.item, item => item.visibleItems !== undefined && item.parent === root.dash.contentLoader.item);
                check(menu.visibleItems.length === 2, "hidden custom action omitted");
                menu._activate(1);
                check(root.customActions === 0, "disabled custom action cannot activate");
                menu._activate(0);
                check(root.customActions === 1, "custom callback preserved");
                const lastAction = actions.focusTargets[actions.focusTargets.length - 1];
                lastAction.forceActiveFocus(Qt.TabFocusReason);
                keyClick(Qt.Key_Tab);
                check(root.dash.editMode && root.dash.activeTabId === "plugin_navigation_test", "Tab from Finish stays in editing");
                const editFocusTargets = actions.focusTargets;
                root.dash.editMode = false;
                settle();
                check(editFocusTargets.every(item => !item.activeFocus), "leaving plugin editing releases hidden action focus");
                SettingsData.setDashTabEnabled("plugin_navigation_test", false);
                open("plugin_navigation_test");
                check(root.dash.detailTabId === "plugin_navigation_test", "hidden plugin opens as detail");
                PluginService.loadedPlugins = {};
                settle();
                check(root.dash.detailTabId === "" && root.dash.activeTabId === DashRegistry.defaultTabId, "removed plugin falls back cleanly");

                root.dash.dashVisible = false;
                root.dash.instantClose();
                settle();
                navigation.width = 800;
                navigation.orientation = Qt.Horizontal;
                settle();
                const first = find(navigation, item => item.index === 0 && item.selected !== undefined);
                check(Math.abs(first.width * navigation.count + navigation.spacing * (navigation.count - 1) - navigation.width) < 1, "horizontal destinations are evenly distributed");
                navigation.evenlySpaced = false;
                settle();
                navigation.revealCurrent();
                check(first.width === Theme.navigationItemMinWidth && first.parent.x > 0, "compact horizontal navigation stays centered");
                navigation.evenlySpaced = true;
                tester.parent = window.contentItem;
                navigation.forceActiveFocus(Qt.TabFocusReason);
                keyClick(Qt.Key_Right);
                check(navigation.currentIndex === 1, "horizontal arrow selects next destination");
                navigation.orientation = Qt.Vertical;
                navigation.width = Theme.navigationRailWidth;
                navigation.height = 300;
                settle();
                navigation.revealCurrent();
                check(first.height === navigation.destinationHeight && first.parent.y > 0, "vertical destinations stay a centered group");
                keyClick(Qt.Key_Up);
                check(navigation.currentIndex === 0, "vertical arrow selects previous destination");
                navigation.model = Array.from({
                    length: 10
                }, (_, i) => ({
                            icon: "extension",
                            text: "Destination " + i
                        }));
                navigation.currentIndex = 9;
                settle();
                const scroll = find(navigation, item => item.contentY !== undefined && item.flickableDirection !== undefined);
                check(scroll.contentY > 0, "overflow selection scrolls into view");
                navigation.model = [
                    {
                        icon: "extension",
                        text: "A long translated destination label"
                    }
                ];
                navigation.currentIndex = 0;
                settle();
                const longDestination = find(navigation, item => item.index === 0 && item.selected !== undefined);
                check(longDestination.width === Theme.navigationRailWidth && longDestination.height > Theme.navigationHeight, "rail wraps long labels without widening");
                navigation.orientation = Qt.Horizontal;
                navigation.width = 240;
                navigation.model = Array.from({
                    length: 10
                }, (_, i) => ({
                            icon: "extension",
                            text: "Destination " + i
                        }));
                navigation.currentIndex = 9;
                settle();
                check(scroll.contentX > 0, "horizontal overflow selection scrolls into view");
                SessionData.locale = "ar";
                navigation.currentIndex = 0;
                settle();
                navigation.forceActiveFocus(Qt.OtherFocusReason);
                keyClick(Qt.Key_Left);
                check(navigation.currentIndex === 1, "RTL Left selects the next logical destination");
                SessionData.locale = "en";
                navigation.orientation = Qt.Vertical;
                navigation.width = Theme.navigationRailWidth;
                settle();
                open("overview");
                for (const strength of [0, 50, 100]) {
                    SettingsData.set("radiusStrength", strength);
                    settle();
                    const indicator = find(navigation, item => item.width === Theme.navigationIndicatorWidth && item.height === Theme.navigationIndicatorHeight && item.radius !== undefined);
                    check(indicator && indicator.radius === (strength === 0 ? 0 : Theme.navigationIndicatorHeight / 2), "indicator radius at " + strength);
                    capture("radius-" + strength);
                }
                SettingsData.set("radiusMode", "fixed");
                SettingsData.set("fixedRadius", 7);
                settle();
                const indicator = find(navigation, item => item.width === Theme.navigationIndicatorWidth && item.height === Theme.navigationIndicatorHeight && item.radius !== undefined);
                check(indicator.radius === 7, "fixed radius applies to navigation");
                capture("fixed-radius");
                console.log("FIXTURE_PASS dashboard navigation and actions");
            } catch (error) {
                console.error("FIXTURE_FAIL " + error.message);
            }
            Qt.quit();
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        SettingsData.animationDuration = 0;
        SettingsData.reduceMotion = true;
        Qt.callLater(tester.run);
    }
}
