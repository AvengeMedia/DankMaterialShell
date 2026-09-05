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
    title: cursor ? I18n.tr("Cursor Theme") + " · Aqueous" : I18n.tr("Typography") + " · Aqueous"
    iconName: cursor ? "mouse" : "text_fields"
    tab: cursor ? "theme" : "typography"
    tags: ["aqueous", "appearance"]

    function reload() {
        if (busy)
            return;
        busy = true;
        AqueousConfigService.load((data, message) => {
            busy = false;
            error = message;
            if (!data)
                return;
            snapshot = data;
            changes = ({});
            if (!supported)
                error = I18n.tr("Unavailable");
        });
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
        if (busy || !snapshot)
            return;
        const capability = cursor ? "cursor_sync" : "typography_sync";
        if (!snapshot.capabilities?.includes(capability))
            return;
        const draft = {expected_generation: snapshot.generation, create_user_override: true,
            changes: Object.keys(changes).map(id => ({id: id, value: changes[id]}))};
        if (retry)
            draft[cursor ? "sync_cursor" : "sync_typography"] = true;
        busy = true;
        AqueousConfigService.apply(draft, (data, message) => {
            busy = false;
            error = message;
            if (!data)
                return;
            snapshot = data;
            changes = ({});
            if (!cursor) {
                const typography = data.desktop_typography;
                SettingsData.set("fontFamily", typography.family);
                SettingsData.set("fontWeight", typography.weight);
                SettingsData.set("fontScale", typography.size_pt * 96 / 72 / 14);
            }
        });
    }

    Component.onCompleted: reload()

    Column {
        width: parent.width
        spacing: Theme.spacingM

        SettingsDropdownRow {
            width: parent.width
            visible: root.cursor
            enabled: !!root.snapshot && !root.busy
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
            enabled: !!root.snapshot && !root.busy
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
            enabled: !!root.snapshot && !root.busy
            text: root.cursor ? I18n.tr("Cursor Size") : I18n.tr("Font Size")
            minimum: root.cursor ? 12 : 6
            maximum: root.cursor ? 128 : 30
            value: root.value(root.cursor ? "desktop.cursor.size" : "desktop.font.size_pt") || (root.cursor ? 24 : 12)
            unit: root.cursor ? "px" : "pt"
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
                text: modelData.id + ": " + I18n.tr(modelData.state)
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }
        }

        StyledText {
            width: parent.width
            visible: !root.cursor
            text: I18n.tr("DMS uses the font family, weight and scale. Exact face, slant, width and separately scaled bars may differ.")
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        Row {
            spacing: Theme.spacingS
            DankButton {
                text: I18n.tr("Apply")
                enabled: root.supported && !root.busy && Object.keys(root.changes).length > 0
                onClicked: root.apply(false)
            }
            DankButton {
                text: I18n.tr("Retry")
                enabled: root.supported && !root.busy && root.partial
                onClicked: root.apply(true)
            }
            DankButton {
                text: I18n.tr("Reload")
                enabled: !root.busy
                onClicked: root.reload()
            }
        }
    }
}
