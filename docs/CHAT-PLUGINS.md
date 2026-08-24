# Chat plugins

A chat plugin teaches DMS to talk to one messaging service — WhatsApp, Signal, a mail account, Matrix,
IRC, anything with a concept of conversations and messages.

You do **not** write a chat client. You write a *translator*: a small program that turns your service's
protocol into JSON lines on stdout, and turns JSON lines on stdin back into protocol calls. That program
is called a **bridge**.

Everything else — storing messages, counting unread, caching images, raising notifications, searching,
the chat window, the settings page — is done once by DMS and shared by every provider. A bridge never
opens the database, never writes to the media cache, and never decides what to notify about.

```
   your service  ◀──▶  bridge  ◀── NDJSON on stdin/stdout ──▶  dms  ──▶  the shell UI
   (protocol)          (yours)                                 (ours)
```

For using chats rather than writing a provider — commands, keybinds, filters, where data
lives — see [CHATS.md](CHATS.md).

---

## What a plugin looks like

```
MyChatPlugin/
  plugin.json          manifest, type "chat"
  bin/mychat           your bridge executable
  Settings.qml         optional — provider settings shown in Settings → Chats
  icon.svg             optional
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
  "warning": "Optional. A caveat shown prominently in settings.",
  "settings": "./Settings.qml",
  "permissions": ["settings_read", "settings_write"]
}
```

`warning` is optional. If your provider carries a real caveat — that the service does not sanction
third-party clients, say — put it here and DMS shows it prominently in settings before the user
turns the plugin on. It exists so the shell never has to hardcode anything provider-specific.

`bridge` is an argv array, resolved relative to the plugin directory. It can be any executable — a
compiled binary, or a script with a shebang. Use whatever language you like; the protocol is just JSON
lines.

DMS starts your bridge when the user enables the plugin and stops it when they disable it. You do not
write a daemon, a socket, a lockfile, or a service unit.

---

## The protocol

One JSON object per line, in both directions. Two kinds of traffic share the stream:

- **calls** — DMS sends `{"id":…,"method":…}`, you reply `{"id":…,"ok":…}` with the same id
- **events** — you push `{"event":…}` whenever you like, unprompted, with no id

### Rules

1. **One compact JSON object per line on stdout.** Never pretty-print. An embedded newline splits your
   object across two lines and desynchronises the reader for the rest of the session.
2. **stdout is protocol only.** Log to stderr — DMS captures it and shows it in `dms chat tail`.
3. **Never exit on error.** If you lose your connection, emit `{"event":"state","state":"disconnected"}`
   and keep running. DMS restarts a bridge that exits, with backoff, but a bridge that stays up and
   reports its state gives a much better experience.
4. **Answer every call**, even ones you do not implement, with
   `{"id":N,"ok":false,"error":{"code":"unknown_method"}}`. This is what keeps old bridges working
   against newer versions of DMS.
5. **Ids are yours to echo, not to generate.** Only DMS assigns call ids.

### Handshake

The first thing DMS sends is `configure`. The first thing you send must be `ready`:

```json
← {"id":1,"method":"configure","params":{"settings":{"accountName":"me@example.com"},"mediaDir":"/home/you/.cache/DankMaterialShell/chat/media/myChat"}}
→ {"event":"ready","protocol":1,"capabilities":["send","markRead","media","reply"]}
→ {"id":1,"ok":true}
→ {"event":"state","state":"connecting"}
→ {"event":"state","state":"connected"}
```

`protocol` is the contract version this document describes: **1**. DMS refuses a bridge whose protocol
version it does not recognise rather than risk mis-parsing it.

`capabilities` is how the UI knows what to show. Declare only what you actually support:

| Capability | Enables |
|---|---|
| `send` | the message composer |
| `markRead` | read receipts, unread clearing on open |
| `media` | the attach button, image bubbles |
| `reply` | reply-to-message affordance |
| `revoke` | delete-for-everyone affordance |
| `search` | server-side message search (local search always works) |
| `threads` | subject lines and threaded conversations — mail-shaped providers |
| `richText` | HTML message bodies |
| `presence` | typing indicators and online status |
| `groups` | group conversations |

Anything you do not declare is hidden from the UI rather than failing at runtime.

---

## Calls DMS makes (stdin)

```json
{"id":1,"method":"configure","params":{"settings":{…},"mediaDir":"…"}}
```
Sent at startup and again whenever the user changes your settings. `settings` is whatever your
`Settings.qml` saved. `mediaDir` is a directory you may write attachment files into.

```json
{"id":2,"method":"send","params":{"chatId":"c1","text":"hey","replyTo":"m4","attachments":["/tmp/a.png"]}}
→ {"id":2,"ok":true,"result":{"messageId":"m10"}}
```
`replyTo` and `attachments` are optional. Return the id your service assigned, so DMS can match the
delivery receipt that arrives later. DMS has already written a `pending` row; your reply flips it to
`sent`, or to `failed` if you answer `ok:false`.

```json
{"id":3,"method":"markRead","params":{"chatId":"c1","upTo":1755300000000}}
{"id":4,"method":"fetchMedia","params":{"chatId":"c1","messageId":"m9","ref":"…"}}
→ {"id":4,"ok":true,"result":{"path":"/…/mediaDir/m9.jpg"}}
{"id":5,"method":"history","params":{"chatId":"c1","before":1755200000000,"limit":50}}
{"id":6,"method":"search","params":{"query":"invoice","chatId":"c1","limit":50}}
{"id":7,"method":"login"}
{"id":8,"method":"logout"}
{"id":9,"method":"shutdown"}
```

`history` asks you to backfill older messages — answer `ok:true` and emit them as `message` events;
you do not return them inline. `shutdown` means disconnect cleanly and exit; DMS sends SIGTERM if you
are still alive shortly after, then SIGKILL.

---

## Events you push (stdout)

```json
{"event":"ready","protocol":1,"capabilities":[…]}
{"event":"state","state":"connected"}
{"event":"auth","method":"qr","qr":"2@abc…"}
{"event":"chat","chat":{…}}
{"event":"chats","chats":[{…},{…}]}
{"event":"message","message":{…}}
{"event":"messages","messages":[{…},{…}]}
{"event":"status","messageId":"m10","status":"delivered"}
{"event":"deleted","chatId":"c1","messageId":"m9"}
{"event":"sync","done":120,"total":5000}
{"event":"log","level":"warn","text":"reconnecting"}
```

`state` is one of `connecting`, `connected`, `disconnected`, `needsLogin`.

`auth` drives the sign-in panel: `method` is `qr` (with `qr`, a string DMS renders as a QR code),
`code` (with `code`, shown as text to type elsewhere), or `url` (with `url`, opened in a browser).

`chat` and `message` are **upserts** — send the same object again with new fields and it merges. Use
the batch forms (`chats`, `messages`) for history sync; DMS writes a batch in one transaction and
coalesces the UI updates, so a five-thousand-message backfill costs a handful of redraws rather than
five thousand.

`sync` drives the progress indicator during backfill. `deleted` marks a message as deleted for
everyone rather than removing the row.

---

## Object shapes

### Chat

| Field | Type | Notes |
|---|---|---|
| `id` | string | **required**, stable, unique within your provider |
| `name` | string | display name |
| `isGroup` | bool | |
| `lastTs` | int64 | milliseconds since epoch |
| `lastText` | string | preview line; omit and DMS derives it from the last message |
| `unread` | int | omit and DMS counts it from `readUpTo` |
| `archived` | bool | archived chats are hidden and never notify |
| `muted` | bool | muted chats appear but never notify |
| `avatarPath` | string | absolute path to an image file |
| `subject` | string | mail-shaped providers — the thread subject |
| `participants` | string[] | mail-shaped providers — addresses on the thread |
| `folder` | string | mail-shaped providers — `INBOX`, a label, etc. |
| `handles` | string[] | other identifiers this conversation answers to — a phone number, an email address, a username |

**Handles matter more than they look.** DMS lets a user open a conversation by
typing a phone number, an address or a username, and it finds them by matching
`handles` — it never parses your `id`, because an id is yours to shape. WhatsApp
is the cautionary example: it addresses contacts by LID now, so there is no
phone number anywhere in the id, and anything that dug through ids for one would
silently find nothing. If your service has a reachable identifier, publish it
here.

### Message

| Field | Type | Notes |
|---|---|---|
| `id` | string | **required**, stable, unique within the chat |
| `chatId` | string | **required** |
| `ts` | int64 | **required**, milliseconds since epoch |
| `fromMe` | bool | |
| `senderId` / `senderName` | string | who wrote it, for group chats |
| `kind` | string | see below, defaults to `text` |
| `text` | string | plain-text body |
| `bodyHtml` | string | only with the `richText` capability |
| `status` | string | `pending` `sent` `delivered` `read` `failed` |
| `replyTo` | string | id of the message being replied to |
| `cc` / `bcc` | string[] | mail-shaped providers |
| `mediaPath` | string | absolute path to a file you already wrote |
| `mediaBytes` | string | base64 — **thumbnails only**, keep under 64 KB |
| `mediaRef` | string | an opaque handle DMS passes back to `fetchMedia` later |
| `mediaMime` | string | |
| `mediaW` / `mediaH` | int | pixel dimensions, so bubbles size before the image loads |
| `fileName` / `fileSize` | string / int64 | |
| `duration` | int | seconds, for audio and video |

**`kind`** is one of `text` `image` `video` `audio` `document` `sticker` `location` `contact`
`system` `deleted` `unsupported`.

The last three are *protocol kinds*. They are stored and shown but deliberately excluded from
"conversations you take part in", so a channel whose join/leave events happen to be flagged as yours
does not get treated as a conversation you participate in.

**`status` only ever moves forward.** If you re-send a message that DMS already has marked `read`, it
stays `read`. You cannot accidentally un-deliver something by re-emitting an older copy of it.

---

## Attachments and images

Binary data never travels as a message payload. There are three ways to hand over media, in order of
preference:

1. **Write the file yourself** into the `mediaDir` you were given at `configure`, and set `mediaPath`
   to its absolute path. Best for anything you already have on disk.
2. **Inline a thumbnail** as base64 in `mediaBytes`. Only for small previews — a full-resolution photo
   inline will stall the line reader for every other message behind it.
3. **Defer it** with `mediaRef`. Set a thumbnail via one of the above, and put an opaque handle in
   `mediaRef`. DMS calls `fetchMedia` with that handle only when the user actually opens the image.

The third is what you want during history sync. Downloading full media for every message in a backfill
means thousands of round trips before the user sees anything.

DMS owns the cache directory and evicts from it when it exceeds the user's configured cap. Do not keep
your own copy of anything you have already handed over.

---

## Settings

`Settings.qml` is a standard DMS plugin settings component — a `PluginSettings` root containing
`ToggleSetting`, `StringSetting`, `SelectionSetting` and friends:

```qml
import qs.Modules.Plugins

PluginSettings {
    pluginId: "myChat"

    StringSetting {
        settingKey: "accountName"
        label: "Account"
        defaultValue: ""
    }

    ToggleSetting {
        settingKey: "syncHistory"
        label: "Sync message history on first login"
        defaultValue: true
    }
}
```

Whatever these save is delivered to your bridge as the `settings` object in `configure`, and again
whenever the user changes it. **Your bridge never reads the shell's settings files.** It receives its
configuration down the pipe, which is what lets you develop and test it entirely outside DMS.

Credentials are your own business. Store them wherever your service's tooling expects — they must never
be put into plugin settings, which are stored in plain text.

---

## Developing a bridge

Your bridge is a normal program reading stdin and writing stdout, so you can drive it by hand:

```bash
printf '%s\n' \
  '{"id":1,"method":"configure","params":{"settings":{},"mediaDir":"/tmp/media"}}' \
  '{"id":2,"method":"send","params":{"chatId":"c1","text":"hi"}}' \
  | ./bin/mychat
```

Once it is installed, watch it run inside DMS:

```bash
dms chat providers          # what DMS discovered, and each one's state
dms chat status myChat      # connection state, unread totals, restart count
dms chat tail myChat        # live NDJSON in both directions, plus stderr
```

`quickshell/PLUGINS/EchoChatExample/` is a complete working bridge in about 150 lines. It invents two
conversations, echoes whatever you send it, fakes a QR sign-in, and deliberately declares only some
capabilities so you can see how the UI adapts. Copy it as a starting point.

---

## A note on trust

A bridge is an ordinary program running as your user, with your permissions. So are all other DMS
plugins — there is no sandbox. Installing a chat plugin means running its author's code on your machine,
and that code will hold your messaging credentials.

Install bridges you have reason to trust, the same way you would any other software.
