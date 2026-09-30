import asyncio
import struct
import sys
import zlib
from pathlib import Path
import tempfile
import time
from dbus_next import Variant
from dbus_next.aio import MessageBus
from dbus_next.constants import PropertyAccess
from dbus_next.service import ServiceInterface, dbus_property, method, signal


def png_chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


class Player(ServiceInterface):
    def __init__(self):
        super().__init__("org.mpris.MediaPlayer2.Player")
        self.state = "Playing"
        self.position = 0
        self.position_time = time.monotonic()
        self.loop = "None"
        self.shuffle = False
        self.track = 1
        self.art_directory = tempfile.TemporaryDirectory(prefix="dms-mpris-art-") if "--artwork" in sys.argv else None

    def art_url(self):
        if not self.art_directory:
            return ""
        path = Path(self.art_directory.name) / (str(self.track) + ".png")
        if not path.exists():
            width = height = 64
            color = [(204, 40, 40), (40, 40, 204), (40, 204, 40)][(self.track - 1) % 3]
            rows = (b"\x00" + bytes(color) * width) * height
            path.write_bytes(b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) + png_chunk(b"IDAT", zlib.compress(rows)) + png_chunk(b"IEND", b""))
        return path.as_uri()

    @dbus_property(access=PropertyAccess.READ)
    def Position(self) -> "x":
        elapsed = time.monotonic() - self.position_time if self.state == "Playing" else 0
        return self.position + int(elapsed * 1000000)

    @dbus_property(access=PropertyAccess.READ)
    def CanSeek(self) -> "b":
        return True

    @method()
    def SetPosition(self, track_id: "o", position: "x"):
        self.position = position
        self.position_time = time.monotonic()
        self.Seeked(position)

    @signal()
    def Seeked(self, position) -> "x":
        return position

    @dbus_property(access=PropertyAccess.READ)
    def PlaybackStatus(self) -> "s":
        return self.state

    @dbus_property(access=PropertyAccess.READ)
    def Metadata(self) -> "a{sv}":
        metadata = {"xesam:title": Variant("s", "Track " + str(self.track)), "xesam:artist": Variant("as", ["Fixture"]), "mpris:trackid": Variant("o", "/track/" + str(self.track))}
        if self.art_directory:
            metadata["mpris:artUrl"] = Variant("s", self.art_url())
        return metadata

    @dbus_property(access=PropertyAccess.READ)
    def CanControl(self) -> "b":
        return True

    @dbus_property(access=PropertyAccess.READ)
    def CanPlay(self) -> "b":
        return True

    @dbus_property(access=PropertyAccess.READ)
    def CanPause(self) -> "b":
        return True

    @dbus_property(access=PropertyAccess.READ)
    def CanGoNext(self) -> "b":
        return True

    @dbus_property(access=PropertyAccess.READ)
    def CanGoPrevious(self) -> "b":
        return True

    @dbus_property()
    def LoopStatus(self) -> "s":
        return self.loop

    @LoopStatus.setter
    def LoopStatus(self, value: "s"):
        self.loop = value
        self.emit_properties_changed({"LoopStatus": value})

    @dbus_property()
    def Shuffle(self) -> "b":
        return self.shuffle

    @Shuffle.setter
    def Shuffle(self, value: "b"):
        self.shuffle = value
        self.emit_properties_changed({"Shuffle": value})

    def set_state(self, state):
        self.position = self.Position
        self.position_time = time.monotonic()
        self.state = state
        self.emit_properties_changed({"PlaybackStatus": state})

    @method()
    def Play(self):
        self.set_state("Playing")

    @method()
    def Pause(self):
        self.set_state("Paused")

    @method()
    def PlayPause(self):
        self.set_state("Paused" if self.state == "Playing" else "Playing")

    @method()
    def Stop(self):
        self.set_state("Stopped")

    # Chromium reports Stopped between tracks
    async def skip(self, delta):
        state = self.state
        if state == "Playing":
            self.set_state("Stopped")
            await asyncio.sleep(0.08)
        self.track = max(1, self.track + delta)
        self.emit_properties_changed({"Metadata": self.Metadata})
        self.set_state(state)

    @method()
    async def Next(self):
        await self.skip(1)

    @method()
    async def Previous(self):
        await self.skip(-1)


class Application(ServiceInterface):
    def __init__(self):
        super().__init__("org.mpris.MediaPlayer2")

    @dbus_property(access=PropertyAccess.READ)
    def Identity(self) -> "s":
        return "DMS MPRIS fixture"


async def main():
    bus = await MessageBus().connect()
    bus.export("/org/mpris/MediaPlayer2", Application())
    bus.export("/org/mpris/MediaPlayer2", Player())
    await bus.request_name("org.mpris.MediaPlayer2.dms_fixture")
    await asyncio.Future()


asyncio.run(main())
