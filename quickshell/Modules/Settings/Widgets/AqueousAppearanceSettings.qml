pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

SettingsCard {
    id: root
    property bool cursor: false
    property var snapshot: null
    property var changes: ({})
    property bool busy: false
    property string error: ""
    readonly property var report: cursor ? snapshot?.desktop_cursor : snapshot?.desktop_typography
    readonly property bool partial: (report?.failed_count || 0) > 0
    readonly property bool supported: snapshot?.capabilities?.includes(cursor ? "cursor_sync" : "typography_sync") || false
    title: cursor ? I18n.tr("Aqueous cursor", "Aqueous compositor cursor synchronization settings") : I18n.tr("Aqueous typography", "Aqueous compositor font synchronization settings")
    iconName: cursor ? "mouse" : "text_fields"
    tab: cursor ? "theme" : "typography"
    tags: ["aqueous", "appearance"]

    function reload() {
        if (busy || AqueousConfigService.busy)
            return;
        busy = true;
        AqueousConfigService.load((data, message) => {
            busy = false;
            error = message ? AqueousService.errorMessage(message) : "";
            if (!data)
                return;
            snapshot = data;
            changes = ({});
            if (!supported)
                error = I18n.tr("Unavailable");
        });
    }

    function targetStatus(target) {
        switch (target.state) {
        case "synced":
            return I18n.tr("Synchronized", "Aqueous appearance settings match this application or toolkit");
        case "drifted":
            return I18n.tr("Not synchronized", "Aqueous appearance settings differ from this application or toolkit");
        case "partial":
            return I18n.tr("Partially synchronized", "The application or toolkit cannot represent every Aqueous font setting");
        case "failed":
            return I18n.tr("Sync failed", "Applying Aqueous appearance settings to this application or toolkit failed");
        case "unavailable":
            return I18n.tr("Unavailable");
        case "unmanaged":
            return I18n.tr("Disabled");
        default:
            return I18n.tr("Unknown");
        }
    }

    function value(id) {
        if (Object.prototype.hasOwnProperty.call(changes, id))
            return changes[id];
        return snapshot?.fields?.find(f => f.id === id)?.value;
    }

    function stage(id, value) {
        const updated = Object.assign({}, changes);
        updated[id] = value;
        changes = updated;
    }

    function apply(retry) {
        if (busy || !snapshot || AqueousConfigService.busy)
            return;
        const capability = cursor ? "cursor_sync" : "typography_sync";
        if (!snapshot.capabilities?.includes(capability))
            return;
        const draft = {
            expected_generation: snapshot.generation,
            create_user_override: true,
            changes: retry ? [] : Object.keys(changes).map(id => ({
                        id: id,
                        value: changes[id]
                    }))
        };
        draft[cursor ? "sync_cursor" : "sync_typography"] = true;
        busy = true;
        AqueousConfigService.apply(draft, (data, message) => {
            busy = false;
            error = message ? AqueousService.errorMessage(message) : "";
            if (!data)
                return;
            snapshot = data;
            if (!retry)
                changes = ({});
            if (cursor)
                return;
            const typography = data.desktop_typography;
            if (!typography || typeof typography.family !== "string" || !Number.isFinite(typography.weight) || !Number.isFinite(typography.size_pt) || typography.size_pt <= 0)
                return;
            SettingsData.set("fontFamily", typography.family);
            SettingsData.set("fontWeight", typography.weight);
            SettingsData.set("fontScale", typography.size_pt * 96 / 72 / 14);
        });
    }

    Component.onCompleted: reload()

    Column {
        width: parent.width
        spacing: Theme.spacingM

        SettingsDropdownRow {
            width: parent.width
            visible: root.cursor
            enabled: root.supported && !root.busy
            text: I18n.tr("Cursor Theme")
            options: root.snapshot?.desktop_cursor?.themes || []
            currentValue: root.value("desktop.cursor.theme") || "default"
            onValueChanged: value => {
                root.stage("desktop.cursor.theme", value);
                root.stage("desktop.cursor.managed", true);
            }
        }

        SettingsDropdownRow {
            width: parent.width
            visible: !root.cursor
            enabled: root.supported && !root.busy
            text: I18n.tr("Normal Font")
            options: root.snapshot?.desktop_typography?.families || []
            currentValue: root.value("desktop.font.family") || "sans-serif"
            onValueChanged: value => {
                root.stage("desktop.font.family", value);
                root.stage("desktop.font.style", "");
            }
        }

        SettingsSliderRow {
            width: parent.width
            enabled: root.supported && !root.busy
            text: root.cursor ? I18n.tr("Cursor Size") : I18n.tr("Font Size")
            minimum: root.cursor ? 12 : 6
            maximum: root.cursor ? 128 : 30
            value: root.value(root.cursor ? "desktop.cursor.size" : "desktop.font.size_pt") || (root.cursor ? 24 : 12)
            unit: root.cursor ? I18n.tr("px", "Cursor size unit, pixels") : I18n.tr("pt", "Font size unit, points")
            onSliderValueChanged: value => {
                root.stage(root.cursor ? "desktop.cursor.size" : "desktop.font.size_pt", value);
                if (root.cursor)
                    root.stage("desktop.cursor.managed", true);
            }
        }

        StyledText {
            width: parent.width
            visible: root.error !== "" || root.partial
            text: root.error || I18n.tr("Error")
            color: Theme.error
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.report?.targets || []
            StyledText {
                required property var modelData
                width: parent.width
                text: I18n.tr("%1: %2", "Aqueous appearance sync target and its status").arg(modelData.id).arg(root.targetStatus(modelData))
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }
        }

        StyledText {
            width: parent.width
            visible: !root.cursor
            text: I18n.tr("DMS uses the font family, weight and scale. Exact face, slant, width and separately scaled bars may differ.", "Aqueous font synchronization, describing which font settings DMS can represent")
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        Flow {
            width: parent.width
            spacing: Theme.spacingS
            DankButton {
                text: I18n.tr("Apply Changes")
                enabled: root.supported && !root.busy && !AqueousConfigService.busy && Object.keys(root.changes).length > 0
                onClicked: root.apply(false)
            }
            DankButton {
                text: I18n.tr("Retry")
                enabled: root.supported && !root.busy && !AqueousConfigService.busy && root.partial
                onClicked: root.apply(true)
            }
            DankButton {
                text: I18n.tr("Refresh")
                enabled: !root.busy && !AqueousConfigService.busy
                onClicked: root.reload()
            }
        }
    }
}
