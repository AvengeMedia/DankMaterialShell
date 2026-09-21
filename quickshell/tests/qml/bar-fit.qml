import QtQuick
import Quickshell
import qs.Common
import qs.Modules.DankBar
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    readonly property var steps: [
        {
            position: 0,
            mode: "fit",
            goth: true
        },
        {
            position: 0,
            mode: "fit",
            goth: false
        },
        {
            position: 2,
            mode: "fit",
            goth: true
        },
        {
            position: 1,
            mode: "fit",
            goth: true
        },
        {
            position: 3,
            mode: "fit",
            goth: true
        },
        {
            position: 0,
            mode: "fit",
            goth: true,
            center: false
        },
        {
            position: 0,
            mode: "percent",
            goth: true
        },
        {
            position: 2,
            mode: "percent",
            goth: true
        },
        {
            position: 0,
            mode: "fit",
            goth: true,
            wide: true
        },
        {
            position: 0,
            mode: "percent",
            goth: false,
            wide: true,
            percent: 100
        },
        {
            position: 0,
            mode: "full",
            goth: true
        }
    ]
    property int step: 0
    readonly property var current: steps[step]
    readonly property bool vertical: current.position === SettingsData.Position.Left || current.position === SettingsData.Position.Right
    readonly property int wingRadius: 16
    property var barConfig: ({
            id: "fixture",
            enabled: true,
            screenPreferences: ["all"],
            position: current.position,
            spacing: 0,
            innerPadding: 4,
            barLengthMode: current.mode,
            wide: current.wide === true,
            barLengthPercent: current.percent ?? 80,
            gothCornersEnabled: current.goth,
            gothCornerRadiusOverride: true,
            gothCornerRadiusValue: wingRadius
        })
    property var hyprlandOverviewLoader: null
    property bool systemTrayMenuOpen: false

    ScriptModel {
        id: widgets
        values: [
            {
                widgetId: "clock",
                id: "clock_0"
            }
        ]
    }
    ScriptModel {
        id: pairedWidgets
        values: [
            {
                widgetId: "clock",
                id: "clock_1"
            },
            {
                widgetId: "clock",
                id: "clock_2"
            }
        ]
    }
    ScriptModel {
        id: noWidgets
        values: []
    }
    ScriptModel {
        id: wideWidgets
        values: [
            {
                widgetId: "clock",
                id: "clock_3"
            },
            {
                widgetId: "clock",
                id: "clock_4"
            },
            {
                widgetId: "clock",
                id: "clock_5"
            }
        ]
    }

    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 800
        implicitHeight: 600

        Item {
            width: root.vertical ? body.surfaceImplicitWidth : 800
            height: root.vertical ? 600 : body.surfaceImplicitHeight

            DankBarBody {
                id: body
                anchors.fill: parent
                rootWindow: root
                hostWindow: window
                modelData: Quickshell.screens[0]
                barConfig: root.barConfig
                leftWidgetsModel: root.current.wide ? wideWidgets : widgets
                centerWidgetsModel: root.current.center === false ? noWidgets : widgets
                rightWidgetsModel: pairedWidgets
            }
        }
    }

    function check(condition, message) {
        if (!condition)
            throw new Error(`step ${step}: ${message}`);
    }

    function find(item, predicate, out) {
        if (predicate(item))
            out.push(item);
        for (const child of item.children || [])
            find(child, predicate, out);
        return out;
    }

    function rectOf(item) {
        const point = item.mapToItem(body, 0, 0);
        return {
            x: point.x,
            y: point.y,
            width: item.width,
            height: item.height,
            right: point.x + item.width,
            bottom: point.y + item.height,
            discX: item.discRect ? point.x + item.discRect.x + item.discRect.width / 2 : 0,
            discY: item.discRect ? point.y + item.discRect.y + item.discRect.height / 2 : 0
        };
    }

    function near(a, b) {
        return Math.abs(a - b) <= 1.5;
    }

    function checkStep() {
        const content = body._leftSection.barContent;
        const mask = rectOf(body.inputMaskItem);
        const surface = rectOf(find(body, item => item.motion !== undefined && item.topLeftRadius !== undefined, [])[0]);
        const wings = find(body, item => typeof item.corner === "string" && item.discRect !== undefined && item.visible && item.radius > 0, []).map(rectOf);
        const along = item => root.vertical ? item.height : item.width;
        const length = root.vertical ? 600 : 800;
        const instance = ShellLayout.forScreen(Quickshell.screens[0]).instances.find(instance => instance.barId === "fixture");
        const thickness = body.effectiveBarThickness + body.effectiveSpacing;
        const sections = [body._leftSection, body._centerSection, body._rightSection].map(rectOf);
        const startEdge = rect => root.vertical ? rect.y : rect.x;
        const endEdge = rect => root.vertical ? rect.bottom : rect.right;

        if (current.mode === "full") {
            check(near(along(mask), length), `full mask spans the edge, got ${along(mask)}`);
            check(near(instance.rowThickness, thickness + root.wingRadius), `full bar row includes the cross wing, got ${instance.rowThickness}`);
            check(wings.length === 2 && wings.every(wing => near(wing.y, surface.bottom)), "full bar wings hang below the surface");
            return;
        }

        check(near(along(surface), along(mask)) && near(startEdge(surface), startEdge(mask)), "surface matches the mask");
        check(near(root.vertical ? surface.width : surface.height, thickness), `no cross wing thickens the shortened surface, got ${root.vertical ? surface.width : surface.height}`);
        check(near(instance.rowThickness, thickness), `shortened row excludes the wing, got ${instance.rowThickness}`);
        check([sections[0], sections[2]].every(section => section.x >= surface.x - 1 && section.right <= surface.right + 1 && section.y >= surface.y - 1 && section.bottom <= surface.bottom + 1), "side sections stay inside the surface");
        check(near(startEdge(mask), startEdge(sections[0]) - content.fittedStartMargin) && near(endEdge(mask), endEdge(sections[2]) + content.fittedEndMargin), `mask hugs the outer sections plus the inset, got ${JSON.stringify(mask)}`);

        if (current.mode === "percent") {
            const share = (current.percent ?? 80) / 100;
            check(near(along(mask), length * share), `percent mask spans ${share} of the edge, got ${along(mask)}`);
            check(near(startEdge(mask), length * (1 - share) / 2), `percent mask is centered, got ${startEdge(mask)}`);
            const center = body._centerSection;
            const coreStart = startEdge(sections[1]) + center.contentStart;
            const coreMid = coreStart + center.contentSize / 2;
            if (current.wide) {
                check(coreMid > length / 2 + 5 && near(coreStart - endEdge(sections[0]), content.sectionGap), `wide left pushes the center right by one widget spacing, got ${coreMid} and ${coreStart - endEdge(sections[0])}`);
                check(endEdge(sections[0]) + content.sectionGap <= coreStart + 0.5 && coreStart + center.contentSize + content.sectionGap <= startEdge(sections[2]) + 0.5, "no section overlaps the center");
            } else {
                check(near(coreMid, length / 2), `percent keeps the center on the screen center, got ${coreMid}`);
            }
        } else {
            const center = body._centerSection;
            const coreStart = startEdge(sections[1]) + center.contentStart;
            const coreEnd = coreStart + center.contentSize;
            if (current.center === false) {
                check(center.contentSize === 0, "empty center has no extent");
                const groupMid = (startEdge(sections[0]) + endEdge(sections[2])) / 2;
                check(near(groupMid, length / 2), `side sections center on the edge without center widgets, got ${groupMid}`);
            } else if (current.wide) {
                check((coreStart + coreEnd) / 2 > length / 2 + 5 && near(startEdge(mask), 0), `wide left pushes the center right and the body hugs the edge, got ${(coreStart + coreEnd) / 2} and ${startEdge(mask)}`);
                check(near(coreStart - endEdge(sections[0]), content.sectionGap) && near(startEdge(sections[2]) - coreEnd, content.sectionGap), `sides keep the widget spacing around the pushed center, got ${coreStart - endEdge(sections[0])} and ${startEdge(sections[2]) - coreEnd}`);
            } else {
                check(center.contentSize > 0 && near((coreStart + coreEnd) / 2, length / 2), `center widgets stay on the screen center, got ${(coreStart + coreEnd) / 2}`);
                check(near(coreStart - endEdge(sections[0]), content.sectionGap) && near(startEdge(sections[2]) - coreEnd, content.sectionGap), `side sections hug the center content by the widget spacing, got ${coreStart - endEdge(sections[0])} and ${startEdge(sections[2]) - coreEnd}`);
                check(near(content.sectionGap, body._leftSection.widgetSpacing), "section gap equals the widget spacing");
            }
            check(current.wide || along(sections[0]) < along(sections[2]), "asymmetric sides in the fixture");
            check(current.wide || along(mask) < length - 100, `fitted mask is shorter than the edge, got ${along(mask)}`);
        }

        if (!current.goth) {
            check(wings.length === 0, "no wings without goth corners");
            return;
        }
        check(wings.length === 2, `two along wings, got ${wings.length}`);
        const attached = wing => {
            switch (current.position) {
            case SettingsData.Position.Bottom:
                return near(wing.bottom, surface.bottom);
            case SettingsData.Position.Left:
                return near(wing.x, surface.x);
            case SettingsData.Position.Right:
                return near(wing.right, surface.right);
            default:
                return near(wing.y, surface.y);
            }
        };
        check(wings.every(attached), "wings sit on the attached edge");
        const leading = root.vertical ? near(wings[0].bottom, surface.y) : near(wings[0].right, surface.x);
        const trailing = root.vertical ? near(wings[1].y, surface.bottom) : near(wings[1].x, surface.right);
        check(leading && trailing, `wings flank the surface ends, got ${JSON.stringify(wings)} around ${JSON.stringify(surface)}`);
        const cutAway = wing => {
            switch (current.position) {
            case SettingsData.Position.Bottom:
                return near(wing.discY, wing.y);
            case SettingsData.Position.Left:
                return near(wing.discX, wing.right);
            case SettingsData.Position.Right:
                return near(wing.discX, wing.x);
            default:
                return near(wing.discY, wing.bottom);
            }
        };
        const cutOutward = root.vertical ? near(wings[0].discY, wings[0].y) && near(wings[1].discY, wings[1].bottom) : near(wings[0].discX, wings[0].x) && near(wings[1].discX, wings[1].right);
        check(wings.every(cutAway) && cutOutward, `wing discs are cut away from the edge and the surface, got ${JSON.stringify(wings)}`);
    }

    Timer {
        id: ticker
        interval: 200
        repeat: true
        running: SettingsData._hasLoaded
        onTriggered: {
            try {
                if (SettingsData.barConfigs.length !== 1 || SettingsData.barConfigs[0].barLengthMode !== root.current.mode || SettingsData.barConfigs[0].wide !== (root.current.wide === true) || SettingsData.barConfigs[0].barLengthPercent !== (root.current.percent ?? 80) || SettingsData.barConfigs[0].position !== root.current.position || SettingsData.barConfigs[0].gothCornersEnabled !== root.current.goth) {
                    SettingsData.barConfigs = [root.barConfig];
                    return;
                }
                root.checkStep();
                if (root.step === root.steps.length - 1) {
                    stop();
                    console.log("FIXTURE_PASS");
                    Qt.quit();
                    return;
                }
                root.step++;
            } catch (error) {
                stop();
                console.error("FIXTURE_FAIL", error.message);
                Qt.quit();
            }
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        SettingsData.reduceMotion = true;
    }
}
