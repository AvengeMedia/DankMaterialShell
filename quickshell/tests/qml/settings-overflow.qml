import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Settings
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    function check(condition, label) {
        if (!condition)
            throw new Error(label);
    }
    function find(item, predicate) {
        if (predicate(item))
            return item;
        for (const child of item.children || []) {
            const found = find(child, predicate);
            if (found)
                return found;
        }
        return null;
    }

    FloatingWindow {
        visible: true
        implicitWidth: 800
        implicitHeight: 700

        WidgetsTabSection {
            id: section
            width: parent.width
            title: "fixture section"
            sectionId: "left"
            barId: "overflow-settings-fixture"
            overflowSettingsExpanded: true
            items: [
                { id: "weather", text: "weather fixture", icon: "partly_cloudy_day", enabled: true },
                { id: "futureWidget", text: "future fixture", icon: "extension", enabled: true }
            ]
        }
        BarWidgetTab {
            id: page
            y: section.height
            width: parent.width
            height: parent.height - y
        }
    }
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
            SettingsData.barConfigs = [{
                id: "overflow-settings-fixture", enabled: true, visible: true,
                leftWidgets: ["weather", "futureWidget"], centerWidgets: [], rightWidgets: []
            }];
            SettingsUiState.selectedBarId = "overflow-settings-fixture";
            SettingsUiState.selectedDockId = "";
            SettingsUiState.selectedWidgetSection = "left";
            SettingsUiState.selectedWidgetIndex = 0;
            checks.start();
        }
    }
    Timer {
        id: checks
        interval: 16
        repeat: true
        property int step: 0
        property real started: 0
        onTriggered: {
            if (!started)
                started = Date.now();
            try {
                const config = SettingsData.getBarConfig(section.barId);
                switch (step) {
                case 0:
                    root.check(page.entry && section.autoOverflow && section.overflowPosition === 2, "sections default to auto overflow");
                    const weather = root.find(section, item => item.title === "weather fixture" && item.configurable !== undefined);
                    const future = root.find(section, item => item.title === "future fixture" && item.configurable !== undefined);
                    root.check(weather?.configurable && future?.configurable, "general options are accessible without a widget-specific options file");
                    root.check(page.value("overflowMode") === "section" && page.isDefault(["overflowMode"]), "new widgets inherit the section without an override");
                    const position = root.find(section, item => item.positionLabels !== undefined);
                    root.check(position.positionLabels.length === 3 && position.currentValue === position.positionLabels[2], "position dropdown lists the start and every entry, defaulting to the end");
                    root.check(section.overflowStore.isDefault(["leftOverflowMode", "leftOverflowPosition"]), "omitted section keys read as default");
                    section.setOverflowOption("Mode", "bar");
                    position.valueChanged(position.positionLabels[1]);
                    break;
                case 1:
                    root.check(!section.autoOverflow && section.overflowPosition === 1, "section controls save and update their bindings");
                    root.check(!section.overflowStore.isDefault(["leftOverflowMode"]) && !section.overflowStore.isDefault(["leftOverflowPosition"]), "changed section keys are no longer default");
                    section.setOverflowOption("Mode", "auto");
                    section.overflowStore.resetToDefault(["leftOverflowPosition"]);
                    root.check(config.leftWidgets.every(entry => typeof entry === "string"), "section-wide overflow does not rewrite each widget");
                    page.set("overflowMode", "bar");
                    break;
                case 2:
                    root.check(page.value("overflowMode") === "bar" && config.leftOverflowMode === "auto", "a widget override preserves the section default");
                    root.check(config.leftOverflowPosition === undefined && section.overflowPosition === 2, "resetting the position clears the key so it follows the widget count");
                    page.resetToDefault(["overflowMode"]);
                    break;
                case 3:
                    root.check(page.value("overflowMode") === "section" && config.leftWidgets[1] === "futureWidget", "reset restores inheritance without changing another widget");
                    console.log("FIXTURE_PASS");
                    stop();
                    Qt.quit();
                    return;
                }
                step++;
                started = Date.now();
            } catch (error) {
                if (Date.now() - started < 10000)
                    return;
                console.error("FIXTURE_FAIL", "step " + step + ": " + error.message);
                stop();
                Qt.quit();
            }
        }
    }
}
