import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    Ref {
        service: DMSNetworkService
    }

    ccWidgetIcon: DMSNetworkService.isBusy ? "sync" : (DMSNetworkService.connected ? "vpn_lock" : "vpn_key_off")
    ccWidgetPrimaryText: "VPN"
    ccWidgetSecondaryText: {
        if (!DMSNetworkService.connected)
            return I18n.tr("Disconnected");
        const names = DMSNetworkService.activeNames || [];
        if (names.length <= 1)
            return names[0] || I18n.tr("Connected");
        return names[0] + " +" + (names.length - 1);
    }
    ccWidgetIsActive: DMSNetworkService.connected

    onCcWidgetToggled: DMSNetworkService.toggleVpn()

    ccDetailContent: Component {
        VpnDetailContent {
            listHeight: 180
        }
    }
}
