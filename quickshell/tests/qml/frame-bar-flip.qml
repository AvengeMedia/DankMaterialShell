import QtQuick
import Quickshell
import qs.Common
import qs.Modules.DankBar
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    readonly property var positions: [0, 2, 0, 3, 0, 2, 1, 3, 1, 0]
    property int step: 0
    readonly property int position: positions[step]
    readonly property bool vertical: position === SettingsData.Position.Left || position === SettingsData.Position.Right
    property var barConfig: ({ id: "fixture", position, spacing: 0, innerPadding: 4 })
    property var hyprlandOverviewLoader: null
    property bool systemTrayMenuOpen: false

    ScriptModel {
        id: widgets
        values: [{ widgetId: "clock", id: "clock_0" }]
    }

    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 800
        implicitHeight: 600

        Item {
            width: root.vertical ? Theme.px(body.effectiveBarThickness + body.effectiveSpacing, body._dpr) : 800
            height: root.vertical ? 600 : Theme.px(body.effectiveBarThickness + body.effectiveSpacing, body._dpr)

            // FrameBarHost retains the body while its slot changes orientation.
            DankBarBody {
                id: body
                anchors.fill: parent
                rootWindow: root
                hostWindow: window
                modelData: Quickshell.screens[0]
                barConfig: root.barConfig
                leftWidgetsModel: widgets
                centerWidgetsModel: widgets
                rightWidgetsModel: widgets
            }
        }
    }

    function checkSections() {
        for (const section of [body._leftSection, body._centerSection, body._rightSection]) {
            section.widgetLayoutLoader?.item?.forceLayout();
            const point = section.mapToItem(body, 0, 0);
            const crossCenter = root.vertical ? point.x + section.width / 2 : point.y + section.height / 2;
            const expectedCenter = (root.vertical ? body.width : body.height) / 2;
            if (Math.abs(crossCenter - expectedCenter) > 1)
                throw new Error(`step ${step}, edge ${body.axis.edge}, ${section.section}: center ${crossCenter}, expected ${expectedCenter}`);
            if (point.x < -1 || point.y < -1 || point.x + section.width > body.width + 1 || point.y + section.height > body.height + 1)
                throw new Error(`step ${step}, edge ${body.axis.edge}, ${section.section}: section outside bar`);
        }
    }

    function advance() {
        try {
            checkSections();
            if (step === positions.length - 1) {
                console.log("FIXTURE_PASS");
                Qt.quit();
                return;
            }
            step++;
            Qt.callLater(advance);
        } catch (error) {
            console.error("FIXTURE_FAIL", error.message);
            Qt.quit();
        }
    }

    Component.onCompleted: {
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        Qt.callLater(advance);
    }
}
