import asyncio
import sys

from dbus_next.constants import PropertyAccess
from dbus_next.aio import MessageBus
from dbus_next.service import ServiceInterface, dbus_property, method, signal


class StatusNotifierItem(ServiceInterface):
    def __init__(self, item_id, title, icon_name, only_menu):
        super().__init__("org.kde.StatusNotifierItem")
        self._id = item_id
        self._title = title
        self._icon_name = icon_name
        self._only_menu = only_menu

    @dbus_property(access=PropertyAccess.READ)
    def Category(self) -> "s":
        return "ApplicationStatus"

    @dbus_property(access=PropertyAccess.READ)
    def Id(self) -> "s":
        return self._id

    @dbus_property(access=PropertyAccess.READ)
    def Title(self) -> "s":
        return self._title

    @dbus_property(access=PropertyAccess.READ)
    def Status(self) -> "s":
        return "Active"

    @dbus_property(access=PropertyAccess.READ)
    def IconName(self) -> "s":
        return self._icon_name

    @dbus_property(access=PropertyAccess.READ)
    def IconThemePath(self) -> "s":
        return ""

    @dbus_property(access=PropertyAccess.READ)
    def ItemIsMenu(self) -> "b":
        return self._only_menu

    @dbus_property(access=PropertyAccess.READ)
    def Menu(self) -> "o":
        return "/NO_DBUSMENU"

    @dbus_property(access=PropertyAccess.READ)
    def ToolTip(self) -> "(sa(iiay)ss)":
        return ["", [], self._title, ""]

    @method()
    def Activate(self, x: "i", y: "i"):
        print("ACTIVATE " + self._id, flush=True)

    @method()
    def SecondaryActivate(self, x: "i", y: "i"):
        pass

    @method()
    def ContextMenu(self, x: "i", y: "i"):
        print("CONTEXT " + self._id, flush=True)

    @method()
    def Scroll(self, delta: "i", orientation: "s"):
        pass

    @signal()
    def NewIcon(self):
        pass


async def main():
    bus = await MessageBus().connect()
    for spec in sys.argv[1:]:
        item_id, title, icon_name, only_menu = spec.split(":")
        bus.export("/StatusNotifierItem", StatusNotifierItem(item_id, title, icon_name, only_menu == "1"))
        name = "org.kde.StatusNotifierItem-" + str(id(bus)) + "-" + item_id
        await bus.request_name(name)
        introspection = None
        for attempt in range(150):
            try:
                introspection = await bus.introspect("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher")
                break
            except Exception:
                await asyncio.sleep(0.2)
        if introspection is None:
            raise RuntimeError("no StatusNotifierWatcher on the bus")
        watcher = bus.get_proxy_object("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher", introspection).get_interface("org.kde.StatusNotifierWatcher")
        await watcher.call_register_status_notifier_item(name)
        print("REGISTERED " + name, flush=True)
        bus = await MessageBus().connect()
    await asyncio.get_event_loop().create_future()


asyncio.run(main())
