pragma Singleton

import QtQuick
import qs.Common

QtObject {
    readonly property var presets: [
        {
            value: "dank",
            label: I18n.tr("Dank", "Material wallpaper preset")
        },
        {
            value: "bloom",
            label: I18n.tr("Bloom", "Material wallpaper preset")
        },
        {
            value: "orbit",
            label: I18n.tr("Orbit", "Material wallpaper preset")
        },
        {
            value: "garden",
            label: I18n.tr("Garden", "Material wallpaper preset")
        },
        {
            value: "petal",
            label: I18n.tr("Petal", "Material wallpaper preset")
        },
        {
            value: "dune",
            label: I18n.tr("Dune", "Material wallpaper preset")
        }
    ]
    readonly property var seedHues: [
        {
            value: "red",
            label: I18n.tr("Red", "seed color hue")
        },
        {
            value: "orange",
            label: I18n.tr("Orange", "seed color hue")
        },
        {
            value: "yellow",
            label: I18n.tr("Yellow", "seed color hue")
        },
        {
            value: "green",
            label: I18n.tr("Green", "seed color hue")
        },
        {
            value: "teal",
            label: I18n.tr("Teal", "seed color hue")
        },
        {
            value: "blue",
            label: I18n.tr("Blue", "seed color hue")
        },
        {
            value: "purple",
            label: I18n.tr("Purple", "seed color hue")
        },
        {
            value: "pink",
            label: I18n.tr("Pink", "seed color hue")
        }
    ]
    function label(options, value) {
        return options.find(option => option.value === value)?.label ?? "";
    }
}
