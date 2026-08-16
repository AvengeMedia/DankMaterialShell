# Echo Chat — reference chat provider

A complete DMS chat plugin that talks to nothing. It invents two conversations,
echoes anything you send back at you, fakes a QR sign-in, and serves a generated
image when you open its attachment.

It exists for two reasons: so the chat stack can be run and tested end to end
without a real messaging account, and so anyone writing a real provider has a
working file to copy rather than a specification to interpret.

The full contract is in [`docs/CHAT-PLUGINS.md`](../../../docs/CHAT-PLUGINS.md).

## Building

```bash
cd src && go build -o ../bin/echo-chat-bridge .
```

The manifest points at `./bin/echo-chat-bridge`, so the binary must exist before
the plugin can be enabled.

## Trying it without DMS

The bridge is an ordinary program reading stdin and writing stdout, so you can
drive it by hand:

```bash
printf '%s\n' \
  '{"id":1,"method":"configure","params":{"settings":{},"mediaDir":"/tmp"}}' \
  '{"id":2,"method":"send","params":{"chatId":"echo-dm","text":"hello"}}' \
  | ./bin/echo-chat-bridge
```

You will see the `ready` and `state` events, the seeded chats, the reply to your
`send`, and then the echo arriving a second later.

## Trying it inside DMS

```bash
ln -s "$PWD" ~/.config/DankMaterialShell/plugins/echoChat
dms chat providers            # it should appear, stopped
```

Enable it under **Settings → Chats**, then:

```bash
dms chat status echoChat      # state, capabilities, restart count
dms chat tail echoChat        # live protocol in both directions
```

## What to look at

| Concern | Where |
|---|---|
| The handshake and capability declaration | `main()` |
| Answering unknown methods instead of ignoring them | `dispatch` default arm |
| Settings arriving down the pipe | `handleConfigure` |
| Send, and walking a message up the delivery ladder | `handleSend` / `echoBack` |
| Deferred media — a ref now, bytes only when opened | the `echo-photo` seed, `handleFetchMedia` |
| Batch delivery for backfill | the `messages` event in `connect` |
| Logging without corrupting the protocol stream | `logf` |

The declared capabilities are deliberately incomplete — no `revoke`, no
`richText` — so you can see the UI hide the affordances a provider has not
claimed. Add them to the `ready` event and the buttons appear.
