#!/usr/bin/env python3
"""Skeleton DMS chat provider bridge.

Replace the marked sections with calls into your messaging service. Everything
outside them -- the framing, the reply plumbing, the logging discipline -- is
the part you should keep.

The contract is docs/CHAT-PLUGINS.md. A complete working example lives in
quickshell/PLUGINS/EchoChatExample/.

Point your manifest at this file:

    "bridge": ["python3", "bridge.py"]
"""

import json
import sys
import threading
import time

PROTOCOL_VERSION = 1

# Declare only what you actually support. The UI hides affordances a provider
# has not claimed, so an unsupported action is never offered.
CAPABILITIES = ["send", "markRead"]

_write_lock = threading.Lock()


def emit(obj):
    """Write one protocol frame.

    Compact and on a single line, always. A pretty-printed object embeds
    newlines, which splits it across lines and desyncs the reader for the rest
    of the session -- the most common bridge bug there is.
    """
    with _write_lock:
        sys.stdout.write(json.dumps(obj, separators=(",", ":")) + "\n")
        sys.stdout.flush()


def event(name, **fields):
    emit({"event": name, **fields})


def log(level, message):
    """Diagnostics. Never bare text on stdout -- that stream is protocol."""
    print(message, file=sys.stderr, flush=True)
    event("log", level=level, text=message)


def now_ms():
    return int(time.time() * 1000)


class Bridge:
    def __init__(self):
        self.settings = {}
        self.media_dir = ""
        self.connected = False

    # ---------------------------------------------------------------- calls

    def dispatch(self, call):
        call_id = call.get("id")
        method = call.get("method")
        params = call.get("params") or {}

        handler = getattr(self, "do_" + str(method), None)
        if handler is None:
            # Answer rather than ignore: this is what keeps an old bridge
            # working against a newer DMS.
            emit({
                "id": call_id,
                "ok": False,
                "error": {"code": "unknown_method",
                          "message": f"not implemented: {method}"},
            })
            return

        try:
            result = handler(params)
        except Exception as exc:  # noqa: BLE001 - a bridge must never die
            log("error", f"{method} failed: {exc}")
            emit({"id": call_id, "ok": False,
                  "error": {"code": "internal", "message": str(exc)}})
            return

        emit({"id": call_id, "ok": True, "result": result} if result
             else {"id": call_id, "ok": True})

    def do_configure(self, params):
        self.settings = params.get("settings") or {}
        self.media_dir = params.get("mediaDir") or ""

        if not self.connected:
            threading.Thread(target=self.connect, daemon=True).start()
        return None

    def do_send(self, params):
        chat_id = params["chatId"]
        text = params.get("text", "")

        # >>> hand the message to your service here, and return the id it
        # >>> assigned so DMS can match the delivery receipt that follows
        message_id = f"local-{now_ms()}"
        log("debug", f"send to {chat_id}: {text!r}")

        return {"messageId": message_id}

    def do_markRead(self, params):
        # >>> post a read receipt upstream
        return None

    def do_shutdown(self, params):
        event("state", state="disconnected")
        # >>> disconnect cleanly
        sys.exit(0)

    # ---------------------------------------------------------------- service

    def connect(self):
        event("state", state="connecting")

        # >>> establish your session here. On failure, report disconnected and
        # >>> return -- never exit; DMS will keep the process alive and you can
        # >>> retry.
        try:
            pass
        except Exception as exc:  # noqa: BLE001
            log("error", f"could not connect: {exc}")
            event("state", state="disconnected")
            return

        self.connected = True
        event("state", state="connected")

        # >>> push the conversation list. Use the batch form for anything large:
        # >>> DMS stores a batch in one transaction and coalesces the redraws.
        event("chats", chats=[
            {"id": "example", "name": "Example", "lastTs": now_ms(),
             "lastText": "…"},
        ])

    def on_incoming_message(self, chat_id, message_id, text, sender=None):
        """Call this from your service's event loop when a message arrives."""
        event("message", message={
            "id": message_id,
            "chatId": chat_id,
            "ts": now_ms(),
            "fromMe": False,
            "senderName": sender or "",
            "kind": "text",
            "text": text,
        })


def main():
    bridge = Bridge()

    # Announce before anything else. DMS refuses a protocol version it does not
    # know rather than parsing it on a guess.
    event("ready", protocol=PROTOCOL_VERSION, capabilities=CAPABILITIES)

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            call = json.loads(line)
        except json.JSONDecodeError as exc:
            log("warn", f"unparseable call: {exc}")
            continue
        bridge.dispatch(call)


if __name__ == "__main__":
    main()
