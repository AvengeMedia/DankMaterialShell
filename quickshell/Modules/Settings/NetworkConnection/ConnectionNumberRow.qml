import QtQuick

// Integer setting in min..max; empty removes the key so NM applies its default.
ConnectionSyncedRow {
    id: root

    required property var editor
    required property string section
    required property string key
    property int min: 0
    property int max: 0

    stored: {
        root.editor.revision;
        const v = root.editor.draft?.[root.section]?.[root.key];
        return v === undefined || v === null ? "" : String(v);
    }
    check: t => t === "" || (/^\d+$/.test(t) && Number(t) >= root.min && Number(t) <= root.max)
    commit: t => root.editor.setValue(root.section, root.key, t === "" ? undefined : Number(t))
    maximumLength: String(max).length
}
