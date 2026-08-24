# Chats

DMS can show your conversations — WhatsApp, and whatever else grows a bridge — in a chat
window, a single-conversation popout, and the launcher.

The shell itself knows nothing about any messaging service. Providers arrive as **plugins**,
each shipping a small program called a bridge. Everything else — storing messages, counting
unread, caching attachments, notifications, search — is done once in the DMS backend and
shared by every provider.

This document is for **using** chats. If you want to write a provider, see
[CHAT-PLUGINS.md](CHAT-PLUGINS.md).

---

## Getting started

Chats does nothing until a provider is installed — on its own it is an empty list.

1. Install a chat plugin into `~/.config/DankMaterialShell/plugins/`. Existing ones live in
   [DMS-Plugins](https://github.com/by-architect/DMS-Plugins): `whatsappChat` is a real
   provider, `chatRunner` adds conversations to the launcher.
2. Enable it under **Settings → Chats**. Each installed provider gets its own card there.
3. Sign in. If the provider uses QR pairing, the code appears in its card.

Confirm your DMS build has chat support:

```sh
dms chat providers
```

An unknown-command error means your DMS predates the chat system.

## Opening a conversation

```sh
dms ipc call chats toggle              # the full window, with the chat list
dms ipc call chats open                # open it
dms ipc call chats close               # close it
dms ipc call chats cycle               # walk unread conversations, across all providers
dms ipc call chats cyclePrev           # the same, backwards
dms ipc call chats status              # is it open, and what is focused
```

A single conversation on its own, without the list:

```sh
dms ipc call chats popout "Ada"                # by name
dms ipc call chats popout "+905551234567"      # by number, or any handle
dms ipc call chats popout "whatsappChat:1234@s.whatsapp.net"   # by provider:chatId
dms ipc call chats closePopout
```

`popout` takes whatever identifier you have. Nothing parses it: providers declare their own
**handles** — phone numbers, addresses, usernames — and the best match wins, preferring an
exact id over an exact handle over an exact name. If two people share a name, qualify it with
`provider:chatId`.

Opening a conversation you already know the id of, skipping resolution entirely:

```sh
dms ipc call chats openChat whatsappChat 1234@s.whatsapp.net
```

These are worth binding under **Settings → Keyboard Shortcuts**; `chats toggle` and
`chats cycle` are the two that earn a key.

## In the conversation

The text field always holds focus, so typing always goes there and `Enter` always sends. The
message keybinds use `Alt` so they never collide with what you are writing.

| Key | Does |
|---|---|
| `Enter` | Send |
| `Alt+K` / `Alt+J` | Select the previous / next message |
| `Shift+Enter` | Open the selected message's attachment or link |
| `Ctrl+Shift+C` | Copy the selected message, or its attachment as a file |
| `Alt+R` | Reply, where the provider supports it |
| `Alt+F` | Forward to another conversation |
| `Delete` | Delete from this device, after confirming |
| `Shift+Delete` | Delete for everyone, after confirming |
| `Ctrl+V` | Attach an image or file from the clipboard |
| `Esc` | Clear the selection, then close |

The help icon in the conversation header lists the same set.

Typing in the search box filters conversations, and searches message text once you have typed
two characters.

### Attachments

There is no file browser. Copy a file in a file manager, or an image from a screenshot tool,
and paste with `Ctrl+V`. A path typed or pasted into the composer followed by a space is
attached too. Everything staged appears as a thumbnail above the text field, so you can drop
one before sending.

Sending several files produces several messages — one row each — because that is what
actually goes out.

## What the UI shows is what the provider supports

Each bridge declares its capabilities when it connects, and the interface is assembled from
that. A provider without attachment support has no attach button; one without replies has no
reply affordance. There are no dead controls.

So two providers can look meaningfully different in the same window, and neither required a
change to the shell.

## Keeping the list manageable

An account is often mostly *not* conversations — statuses, channels, broadcast lists and
archived chats crowd out the people.

Providers declare **tags** describing what each conversation is, and DMS adds its own
(`archived`, `muted`, `unread`, `group`, `direct`). Filters are per provider and live in that
provider's own settings, since only the provider knows what its categories mean — for
WhatsApp, that is **Settings → Chats → WhatsApp → Chat filters**.

Hiding is only hiding. Search still finds them, and nothing is deleted.

## Notifications

Per provider, under its card in **Settings → Chats**: on or off, message previews, group
conversations, archived conversations, do not disturb, and one toggle per provider-declared
category — so a service's statuses can be silent without silencing the service.

Some suppression is not configurable, because it is never what you want: your own messages,
the conversation currently on screen, and the history backfill that arrives when you first
sign in. Without that last one, linking a device would fire several hundred notifications.

## Storage

**Settings → Chats → Storage** holds the two global settings: how long to keep message
history, and the attachment cache limit. Cached attachments are evicted least-recently-used
and re-downloaded on demand, so the cap costs you nothing but a little latency.

| What | Where |
|---|---|
| Messages and conversations | `~/.local/share/DankMaterialShell/chat/history.db` |
| Cached attachments | `~/.cache/DankMaterialShell/chat/media/` |
| Provider settings | `~/.config/DankMaterialShell/plugin_settings.json` |
| Provider credentials | the provider's own directory — never in shell config |

A bridge holds its own session for its service. For WhatsApp that file *is* the linked
device: anyone who can read it can read your messages. Keep it out of dotfile repos and
shared backups.

## When something is wrong

```sh
dms chat providers            # what DMS found, and each one's state
dms chat status <provider>    # connection state, capabilities, restarts, recent stderr
dms chat tail <provider>      # live protocol traffic, both directions
dms chat rescan               # re-read the plugin directories now
```

`tail` is the one that matters. A bridge runs as a child of the daemon, so without it its
output is invisible.

| Symptom | Usually |
|---|---|
| Plugin will not enable | Its bridge is not built — see the plugin's README |
| Stuck at "disconnected" | `dms chat status <provider>` names the error |
| Nothing in the launcher | No provider enabled, or everything is filtered out |
| Searching a number finds nothing | Handles arrive when the bridge connects; reconnect once |
| No Chats section in Settings | This DMS was built without chat support |

A bridge that dies is restarted with backoff, and repeated restarts show in
`dms chat status`. If a provider is flapping, that count is the first thing to look at.

## A note on trust

Chat plugins run as your user, with your permissions, and hold your session for whatever
service they connect to. This is true of every DMS plugin — there is no sandbox. Install ones
you are willing to trust with the account.
