import QtQuick
import qs.Common
import qs.Widgets

DankFilterChips {
    multiSelect: true
    model: [
        {
            label: I18n.tr("User", "noun, process filter and fallback display name"),
            value: "user"
        },
        {
            label: I18n.tr("System"),
            value: "system"
        }
    ]
    selectedValues: CacheData.processFilterTypes
    chipPadding: Theme.spacingM
    onSelectionToggled: (index, selected) => {
        const value = model[index].value;
        const values = selectedValues.filter(entry => entry !== value);
        if (selected)
            values.push(value);
        CacheData.set("processFilterTypes", values);
    }
}
