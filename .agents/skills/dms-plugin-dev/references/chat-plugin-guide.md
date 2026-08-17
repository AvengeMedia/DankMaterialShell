# Chat Plugin Guide

A chat plugin connects DMS to one messaging service — WhatsApp, Signal, a mail account, Matrix,
IRC. It is the only plugin type that does not run in the shell process.

The canonical contract is [`docs/CHAT-PLUGINS.md`](../../../../docs/CHAT-PLUGINS.md) in the
repository. This guide is the orientation; that document is the specification.

## Why chat plugins are different

Every other plugin type is QML loaded into the shell. That works for a clock. It does not work
for a messaging service, which needs a long-lived protocol session, a credential store, and a
library that almost certainly is not written in QML — and which must not be able to take the
whole shell down when it crashes.

So a chat plugin ships an executable instead: a **bridge**. DMS runs it as a supervised child
process and talks to it over newline-delimited JSON on stdin and stdout.

```
   your service  <-->  bridge  <-- NDJSON -->  dms backend  -->  shell UI
   (protocol)          (yours)                 (ours)
```

## What the backend does for you

This is the part worth internalising, because it is most of a chat client:

| Concern | Who |
|---|---|
| Protocol session, auth, credentials | **you** |
| Notification policy, per provider | backend |
| Message store, pagination, dedup | backend |
| Unread counts and read marks | backend |
| Delivery status ratcheting | backend |
| Attachment cache and eviction | backend |
| Desktop notifications and their suppression rules | backend |
| Message search | backend |
| The chat window and settings page | backend |

A bridge never opens the database, never writes to the media cache, and never calls
`notify-send`. If you find yourself doing any of those, you have misread the contract.

## Anatomy

```
MyChatPlugin/
  plugin.json          type "chat", points at the bridge
  bin/mychat           your executable
  Settings.qml         optional PluginSettings component
```

```json
{
    "id": "myChat",
    "name": "My Chat",
    "description": "Connects DMS to My Chat",
    "version": "1.0.0",
    "author": "you",
    "type": "chat",
    "capabilities": ["chat"],
    "icon": "chat",
    "bridge": ["./bin/mychat"],
    "warning": "Optional caveat shown prominently in settings",
    "settings": "./Settings.qml",
    "permissions": ["settings_read", "settings_write"]
}
```

`bridge` is argv, resolved relative to the plugin directory. A bare first element (`"python3"`)
is resolved on PATH; anything path-shaped must stay inside the plugin directory.

## The shape of a bridge

```
stdin   {"id":1,"method":"configure","params":{"settings":{…},"mediaDir":"…"}}
stdout  {"event":"ready","protocol":1,"capabilities":["send","markRead","media"]}
stdout  {"id":1,"ok":true}
stdout  {"event":"state","state":"connected"}
stdout  {"event":"message","message":{"id":"m1","chatId":"c1","ts":…,"text":"hi"}}

stdin   {"id":2,"method":"send","params":{"chatId":"c1","text":"hey"}}
stdout  {"id":2,"ok":true,"result":{"messageId":"m2"}}
```

Two kinds of traffic share the stream: **calls** (DMS sends an `id`, you reply with the same
`id`) and **events** (you push, unprompted, no `id`).

## Capabilities

Declare only what you support. The UI hides affordances a provider has not claimed, so an
unsupported action is never offered rather than failing when used.

`send` `markRead` `media` `reply` `revoke` `search` `threads` `richText` `presence` `groups`

## Four rules that will bite you

1. **One compact JSON object per line on stdout.** Pretty-printing embeds newlines, which splits
   your object across lines and desyncs the reader for the rest of the session. This is the
   single most common bridge bug.
2. **stdout is protocol only.** Log to stderr, or emit
   `{"event":"log","level":"warn","text":"…"}`. A stray `print()` corrupts the stream.
3. **Never exit on error.** Emit `{"event":"state","state":"disconnected"}` and keep running.
   DMS restarts a bridge that exits, with backoff, but staying up and reporting state is far
   better behaviour.
4. **Answer unknown methods** with `{"id":N,"ok":false,"error":{"code":"unknown_method"}}`.
   This is what keeps your bridge working against a newer DMS.

## Attachments

Binary never travels as a message payload. Three ways to hand media over, best first:

1. Write the file into the `mediaDir` you were given, set `mediaPath` to its absolute path.
2. Inline a small thumbnail as base64 in `mediaBytes` — previews only, never full images.
3. Set `mediaRef` to an opaque handle and let DMS call `fetchMedia` when the user opens it.

Use the third during history sync. Downloading full media for every message in a backfill means
thousands of round trips before the user sees anything.

## Settings

`Settings.qml` is a normal `PluginSettings` component, exactly like any other plugin's — see
[settings-components-reference.md](settings-components-reference.md).

Whatever it saves is delivered to your bridge as the `settings` object in `configure`, and again
whenever the user changes it. **Your bridge never reads the shell's settings files.** That is
what lets you develop and test it entirely outside DMS.

Credentials are your own business and belong wherever your service's tooling expects them.
Never put them in plugin settings, which are stored in plain text.

## Developing

Drive the bridge by hand — it is just a program reading stdin:

```bash
printf '%s\n' \
  '{"id":1,"method":"configure","params":{"settings":{},"mediaDir":"/tmp"}}' \
  '{"id":2,"method":"send","params":{"chatId":"c1","text":"hi"}}' \
  | ./bin/mychat
```

Once installed, watch it inside DMS:

```bash
dms chat providers          # what was discovered, and each one's state
dms chat status myChat      # connection state, capabilities, restart count, recent stderr
dms chat tail myChat        # live NDJSON in both directions
```

`dms chat tail` is the important one: a bridge is a child of the daemon, so without it your
program's output is invisible to you.

## Start from the worked example

`quickshell/PLUGINS/EchoChatExample/` is a complete bridge in about 300 lines of Go. It invents
two conversations, echoes what you send, fakes a QR sign-in, and serves a generated image on
`fetchMedia`. It declares a deliberately partial capability set so you can watch the UI adapt.

Copy it rather than starting from this document.
