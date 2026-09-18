pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Scope {
    id: root

    required property var screen

    Variants {
        model: ["top", "bottom", "left", "right"].filter(edge => ShellLayout.edge(root.screen, edge)?.frameExclusionEnabled ?? false)

        delegate: EdgeExclusion {
            required property string modelData

            screen: root.screen
            edge: modelData
            layerNamespace: "dms:frame-exclusion"
            exclusionSize: {
                const layout = ShellLayout.forScreen(root.screen);
                const band = layout?.edges[modelData];
                const frameReservation = (layout?.manualPlacement ? band?.reservation : band?.frameReservation) ?? 0;
                const config = SettingsData.dockConfigForScreenEdge(root.screen, modelData);
                if (!CompositorService.frameHostsDockForConfig(root.screen, config))
                    return frameReservation;
                return frameReservation + SettingsData.dockReservationForEdge(root.screen, modelData);
            }
        }
    }
}
