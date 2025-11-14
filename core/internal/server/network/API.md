# NetworkManager API Documentation

## Overview

The network manager API provides methods for managing WiFi connections, monitoring network state, and handling credential prompts through NetworkManager or iwd (and systemd-networkd for ethernet only). Communication occurs over a message-based protocol (websocket, IPC, etc.) with event subscriptions for state updates.

## API Methods

### network.wifi.connect

Initiate a WiFi connection.

**Request:**
```json
{
  "method": "network.wifi.connect",
  "params": {
    "ssid": "NetworkName",
    "password": "optional-password",
    "interactive": true
  }
}
```

**Parameters:**
- `ssid` (string, required): Network SSID
- `password` (string, optional): Pre-shared key for WPA/WPA2/WPA3 networks
- `interactive` (boolean, optional): Enable credential prompting if authentication fails or password is missing. Automatically set to `true` when connecting to secured networks without providing a password.

**Response:**
```json
{
  "success": true,
  "message": "connecting"
}
```

**Behavior:**
- Returns immediately; connection happens asynchronously
- State updates delivered via `network` service subscription
- Credential prompts delivered via `network.credentials` service subscription

### network.credentials.submit

Submit credentials in response to a prompt.

**Request:**
```json
{
  "method": "network.credentials.submit",
  "params": {
    "token": "correlation-token",
    "secrets": {
      "psk": "password"
    },
    "save": true
  }
}
```

**Parameters:**
- `token` (string, required): Token from credential prompt
- `secrets` (object, required): Key-value map of credential fields
- `save` (boolean, optional): Whether to persist credentials (default: false)

**Common secret fields:**
- `psk`: Pre-shared key for WPA2/WPA3 personal networks
- `identity`: Username for 802.1X enterprise networks
- `password`: Password for 802.1X enterprise networks

### network.credentials.cancel

Cancel a credential prompt.

**Request:**
```json
{
  "method": "network.credentials.cancel",
  "params": {
    "token": "correlation-token"
  }
}
```

## Event Subscriptions

### Subscribing to Events

Subscribe to receive network state updates and credential prompts:

```json
{
  "method": "subscribe",
  "params": {
    "services": ["network", "network.credentials"]
  }
}
```

Both services are required for full connection handling. Missing `network.credentials` means credential prompts won't be received.

### network Service Events

State updates are sent whenever network configuration changes:

```json
{
  "service": "network",
  "data": {
    "networkStatus": "wifi",
    "isConnecting": false,
    "connectingSSID": "",
    "wifiConnected": true,
    "wifiSSID": "MyNetwork",
    "wifiIP": "192.168.1.100",
    "lastError": ""
  }
}
```

**State fields:**
- `networkStatus`: Current connection type (`wifi`, `ethernet`, `disconnected`)
- `isConnecting`: Whether a connection attempt is in progress
- `connectingSSID`: SSID being connected to (empty when idle)
- `wifiConnected`: Whether associated with an access point
- `wifiSSID`: Currently connected network name
- `wifiIP`: Assigned IP address (empty until DHCP completes)
- `lastError`: Error message from last failed connection attempt

### network.credentials Service Events

Credential prompts are sent when authentication is required:

```json
{
  "service": "network.credentials",
  "data": {
    "token": "unique-prompt-id",
    "ssid": "NetworkName",
    "setting": "802-11-wireless-security",
    "fields": ["psk"],
    "hints": ["wpa3", "sae"],
    "reason": "Credentials required"
  }
}
```

**Prompt fields:**
- `token`: Unique identifier for this prompt (use in submit/cancel)
- `ssid`: Network requesting credentials
- `setting`: Authentication type (`802-11-wireless-security` for personal WiFi, `802-1x` for enterprise)
- `fields`: Array of required credential field names
- `hints`: Additional context about the network type
- `reason`: Human-readable explanation (e.g., "Previous password was incorrect")

## Connection Flow

### Typical Timeline

```
T+0ms     Call network.wifi.connect
T+10ms    Receive {"success": true, "message": "connecting"}
T+100ms   State update: isConnecting=true, connectingSSID="Network"
T+500ms   Credential prompt (if needed)
T+1000ms  Submit credentials
T+3000ms  State update: wifiConnected=true, wifiIP="192.168.x.x"
```

### State Machine

```
IDLE
  |
  | network.wifi.connect
  v
CONNECTING (isConnecting=true, connectingSSID set)
  |
  +-- Needs credentials
  |     |
  |     v
  |   PROMPTING (credential prompt event)
  |     |
  |     | network.credentials.submit
  |     v
  |   back to CONNECTING
  |
  +-- Success
  |     |
  |     v
  |   CONNECTED (wifiConnected=true, wifiIP set, isConnecting=false)
  |
  +-- Failure
        |
        v
      ERROR (isConnecting=false, !wifiConnected, lastError set)
```

## Connection Success Detection

A connection is successful when all of the following are true:

1. `wifiConnected` is `true`
2. `wifiIP` is set and non-empty
3. `wifiSSID` matches the target network
4. `isConnecting` is `false`

Do not rely on `wifiConnected` alone - the device may be associated with an access point but not have an IP address yet.

**Example:**
```javascript
function isConnectionComplete(state, targetSSID) {
    return state.wifiConnected &&
           state.wifiIP &&
           state.wifiIP !== "" &&
           state.wifiSSID === targetSSID &&
           !state.isConnecting;
}
```

## Error Handling

### Error Detection

Errors occur when a connection attempt stops without success:

```javascript
function checkForFailure(state, wasConnecting, targetSSID) {
    // Was connecting, now idle, but not connected
    if (wasConnecting &&
        !state.isConnecting &&
        state.connectingSSID === "" &&
        !state.wifiConnected) {
        return state.lastError || "Connection failed";
    }
    return null;
}
```

### Common Error Scenarios

#### Wrong Password

**Detection methods:**

1. Quick failure (< 3 seconds from start)
2. `lastError` contains "password", "auth", or "secrets"
3. Second credential prompt with `reason: "Previous password was incorrect"`

**Handling:**
```javascript
if (prompt.reason === "Previous password was incorrect") {
    // Show error, clear password field, re-focus input
}
```

#### Network Out of Range

**Detection:**
- `lastError` contains "not-found" or "connection-attempt-failed"

#### Connection Timeout

**Detection:**
- `isConnecting` remains true for > 30 seconds

**Implementation:**
```javascript
let timeout = setTimeout(() => {
    if (currentState.isConnecting) {
        handleTimeout();
    }
}, 30000);
```

#### DHCP Failure

**Detection:**
- `wifiConnected` is true
- `wifiIP` is empty after 15+ seconds

### Error Message Translation

Map technical errors to user-friendly messages:

| lastError value | Meaning | User message |
|----------------|---------|--------------|
| `secrets-required` | Password needed | "Please enter password" |
| `authentication-failed` | Wrong password | "Incorrect password" |
| `connection-removed` | Profile deleted | "Network configuration removed" |
| `connection-attempt-failed` | Generic failure | "Failed to connect" |
| `network-not-found` | Out of range | "Network not found" |
| `(timeout)` | Timeout | "Connection timed out" |

## Credential Handling

### Secret Agent Architecture

The credential system uses a broker pattern:

```
NetworkManager -> SecretAgent -> PromptBroker -> UI -> User
                                       ^
                                       |
                                  User Response
                                       |
NetworkManager <- SecretAgent <- PromptBroker <- UI
```

### Implementing a Broker

```go
type CustomBroker struct {
    ui       UIInterface
    pending  map[string]chan network.PromptReply
}

func (b *CustomBroker) Ask(ctx context.Context, req network.PromptRequest) (string, error) {
    token := generateToken()
    b.pending[token] = make(chan network.PromptReply, 1)

    // Send to UI
    b.ui.ShowCredentialPrompt(token, req)

    return token, nil
}

func (b *CustomBroker) Wait(ctx context.Context, token string) (network.PromptReply, error) {
    select {
    case <-ctx.Done():
        return network.PromptReply{}, errors.New("timeout")
    case reply := <-b.pending[token]:
        return reply, nil
    }
}

func (b *CustomBroker) Resolve(token string, reply network.PromptReply) error {
    if ch, ok := b.pending[token]; ok {
        ch <- reply
        close(ch)
        delete(b.pending, token)
    }
    return nil
}
```

### Credential Field Types

**Personal WiFi (802-11-wireless-security):**
- Fields: `["psk"]`
- UI: Single password input

**Enterprise WiFi (802-1x):**
- Fields: `["identity", "password"]`
- UI: Username and password inputs

### Building Secrets Object

```javascript
function buildSecrets(setting, fields, formData) {
    let secrets = {};

    if (setting === "802-11-wireless-security") {
        secrets.psk = formData.password;
    } else if (setting === "802-1x") {
        secrets.identity = formData.username;
        secrets.password = formData.password;
    }

    return secrets;
}
```

## Best Practices

### Track Target Network

Always store which network you're connecting to:

```javascript
let targetSSID = null;

function connect(ssid) {
    targetSSID = ssid;
    // send request
}

function onStateUpdate(state) {
    if (!targetSSID) return;

    if (state.wifiSSID === targetSSID && state.wifiConnected && state.wifiIP) {
        // Success for the network we care about
        targetSSID = null;
    }
}
```

### Implement Timeouts

Never wait indefinitely for a connection:

```javascript
const CONNECTION_TIMEOUT = 30000; // 30 seconds
const DHCP_TIMEOUT = 15000;       // 15 seconds

let timer = setTimeout(() => {
    if (stillConnecting) {
        handleTimeout();
    }
}, CONNECTION_TIMEOUT);
```

### Handle Credential Re-prompts

Wrong passwords trigger a second prompt:

```javascript
function onCredentialPrompt(prompt) {
    if (prompt.reason.includes("incorrect")) {
        // Show error, but keep dialog open
        showError("Wrong password");
        clearPasswordField();
    } else {
        // First time prompt
        showDialog(prompt);
    }
}
```

### Clean Up State

Reset tracking variables on success, failure, or cancellation:

```javascript
function cleanup() {
    clearTimeout(timer);
    targetSSID = null;
    closeDialogs();
}
```

### Subscribe to Both Services

Missing `network.credentials` means prompts won't arrive:

```javascript
// Correct
services: ["network", "network.credentials"]

// Wrong - will miss credential prompts
services: ["network"]
```

## Testing

### Connection Test Checklist

- [ ] Connect to open network
- [ ] Connect to WPA2 network with password provided
- [ ] Connect to WPA2 network without password (triggers prompt)
- [ ] Enter wrong password (verify error and re-prompt)
- [ ] Cancel credential prompt
- [ ] Connection timeout after 30 seconds
- [ ] DHCP timeout detection
- [ ] Network out of range
- [ ] Reconnect to already-configured network

### Verifying Secret Agent Setup

Check connection profile flags:
```bash
nmcli connection show "NetworkName" | grep flags
# Should show: 802-11-wireless-security.psk-flags: 1 (agent-owned)
```

Check agent registration in logs:
```
INFO: Registered with NetworkManager as secret agent
```

## Security

- Never log credential values (passwords, PSKs)
- Clear password fields when dialogs close
- Implement prompt timeouts (default: 2 minutes)
- Validate user input before submission
- Use secure channels for credential transmission

## Troubleshooting

### Credential prompt doesn't appear

**Check:**
- Subscribed to both `network` and `network.credentials`
- Connection has `interactive: true`
- Secret flags set to AGENT_OWNED (value: 1)
- Broker registered successfully

### Connection succeeds without prompting

**Cause:** NetworkManager found saved credentials

**Solution:** Delete existing connection first, or use different credentials

### State updates seem delayed

**Expected behavior:** State changes occur in rapid succession during connection

**Solution:** Debounce UI updates; only act on final state

### Multiple rapid credential prompts

**Cause:** Connection profile has incorrect flags or conflicting agents

**Solution:**
- Check only one agent is running
- Verify psk-flags value
- Check NetworkManager logs for agent conflicts

## Data Structures Reference

### PromptRequest
```go
type PromptRequest struct {
    SSID        string   `json:"ssid"`
    SettingName string   `json:"setting"`
    Fields      []string `json:"fields"`
    Hints       []string `json:"hints"`
    Reason      string   `json:"reason"`
}
```

### PromptReply
```go
type PromptReply struct {
    Secrets map[string]string `json:"secrets"`
    Save    bool              `json:"save"`
    Cancel  bool              `json:"cancel"`
}
```

### NetworkState
```go
type NetworkState struct {
    NetworkStatus  string `json:"networkStatus"`
    IsConnecting   bool   `json:"isConnecting"`
    ConnectingSSID string `json:"connectingSSID"`
    WifiConnected  bool   `json:"wifiConnected"`
    WifiSSID       string `json:"wifiSSID"`
    WifiIP         string `json:"wifiIP"`
    LastError      string `json:"lastError"`
}
```
