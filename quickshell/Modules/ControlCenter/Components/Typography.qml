import QtQuick
import qs.Common
import qs.Widgets

StyledText {
    id: root

    enum Style {
        Title,
        Subtitle,
        Body,
        Caption,
        Button
    }

    property int style: Typography.Style.Body

    font.pixelSize: {
        switch (style) {
        case Typography.Style.Title: return Theme.fontSizeXLarge
        case Typography.Style.Subtitle: return Theme.fontSizeLarge
        case Typography.Style.Body: return Theme.fontSizeMedium
        case Typography.Style.Caption: return Theme.fontSizeSmall
        case Typography.Style.Button: return Theme.fontSizeSmall
        default: return Theme.fontSizeMedium
        }
    }

    font.weight: {
        switch (style) {
        case Typography.Style.Title: return Font.Bold
        case Typography.Style.Subtitle: return Font.Medium
        case Typography.Style.Body: return Font.Normal
        case Typography.Style.Caption: return Font.Normal
        case Typography.Style.Button: return Font.Medium
        default: return Font.Normal
        }
    }

    color: {
        switch (style) {
        case Typography.Style.Caption: return Theme.surfaceVariantText
        default: return Theme.surfaceText
        }
    }
}
