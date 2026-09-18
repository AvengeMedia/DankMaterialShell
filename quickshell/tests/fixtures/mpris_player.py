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
        self.art_url = ""
        self.art_revision = 0
        self.art_directory = None
        if "--artwork" in sys.argv:
            self.art_directory = tempfile.TemporaryDirectory(prefix="dms-mpris-art-")
            self.art_url = self.write_artwork(1)

    def write_artwork(self, track, suffix=""):
        width = height = 64
        path = Path(self.art_directory.name) / (str(track) + suffix + ".png")
        color = [(204, 40, 40), (40, 40, 204), (40, 204, 40)][(track - 1) % 3]
        rows = (b"\x00" + bytes(color) * width) * height
        path.write_bytes(b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) + png_chunk(b"IDAT", zlib.compress(rows)) + png_chunk(b"IEND", b""))
        return path.as_uri()

    async def change_artwork(self, delta):
        self.art_revision += 1
        revision = self.art_revision
        self.track = max(1, self.track + delta)
        track = self.track
        self.emit_properties_changed({"Metadata": self.Metadata})
        await asyncio.sleep(0.5 if track in (2, 6) else 0.08)
        if revision != self.art_revision:
            return
        if track == 4:
            self.art_url = (Path(self.art_directory.name) / "4.ppm").as_uri()
            self.emit_properties_changed({"Metadata": self.Metadata})
            await asyncio.sleep(0.3)
            self.write_artwork(track)
            if revision != self.art_revision:
                return
        else:
            self.art_url = self.write_artwork(track)
            self.emit_properties_changed({"Metadata": self.Metadata})
        await asyncio.sleep(0.16)
        if revision != self.art_revision:
            return
        self.art_url = self.write_artwork(track, "-copy")
        self.emit_properties_changed({"Metadata": self.Metadata})

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
        if self.art_url:
            metadata["mpris:artUrl"] = Variant("s", self.art_url)
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

    @method()
    async def Next(self):
        if self.art_directory:
            await self.change_artwork(1)
            return
        state = self.state
        if state == "Playing":
            self.set_state("Stopped")
            await asyncio.sleep(0.08)
        self.track += 1
        self.emit_properties_changed({"Metadata": self.Metadata})
        self.set_state(state)

    @method()
    async def Previous(self):
        if self.art_directory:
            await self.change_artwork(-1)



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
