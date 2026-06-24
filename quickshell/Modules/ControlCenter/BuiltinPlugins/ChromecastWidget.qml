import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // Keeps the subscription alive while the widget exists so the collapsed tile
    // can show connection/playback status. Discovery is driven separately by the
    // detail panel (only while it is open).
    Ref {
        service: ChromecastService
    }

    ccWidgetIcon: ChromecastService.connected ? "cast_connected" : "cast"
    ccWidgetPrimaryText: I18n.tr("Cast", "Chromecast widget title")
    ccWidgetSecondaryText: {
        if (!ChromecastService.available)
            return I18n.tr("Not available", "Chromecast service not available");
        if (ChromecastService.connected) {
            const dev = ChromecastService.activeDevice;
            const name = dev ? dev.name : I18n.tr("Connected", "Chromecast connected status");
            if (ChromecastService.screencasting)
                return I18n.tr("Mirroring · %1", "Chromecast mirroring a screen to a device").arg(name);
            const pb = ChromecastService.playback;
            if (pb && pb.title)
                return I18n.tr("%1 · %2", "Chromecast now-playing title on a device").arg(pb.title).arg(name);
            return name;
        }
        if (ChromecastService.discovering)
            return I18n.tr("Searching…", "Chromecast searching for devices");
        const count = ChromecastService.deviceCount;
        if (count > 0)
            return I18n.tr("%1 devices", "Number of Chromecast devices found").arg(count);
        return I18n.tr("No devices", "No Chromecast devices found");
    }
    ccWidgetIsActive: ChromecastService.connected

    // When connected, the tile toggle disconnects. When not connected, there is
    // no single target, so clicking expands the detail to pick a device.
    ccWidgetIsToggle: ChromecastService.connected
    onCcWidgetToggled: {
        if (ChromecastService.connected)
            ChromecastService.disconnect();
    }

    ccDetailContent: Component {
        ChromecastDetailContent {}
    }
}
