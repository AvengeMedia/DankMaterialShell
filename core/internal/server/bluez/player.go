package bluez

import (
	"crypto/sha256"
	"errors"
	"fmt"
	"maps"
	"reflect"
	"slices"
	"sync"

	"github.com/godbus/dbus/v5"
	"github.com/godbus/dbus/v5/introspect"
)

const (
	media1Iface         = "org.bluez.Media1"
	mprisPlayerIface    = "org.mpris.MediaPlayer2.Player"
	introspectableIface = "org.freedesktop.DBus.Introspectable"
	mprisPlayerPath     = dbus.ObjectPath("/com/danklinux/bluez/player")
)

const mprisPlayerIntrospection = `
<node>
	<interface name="org.mpris.MediaPlayer2.Player">
		<method name="Next"/>
		<method name="Previous"/>
		<method name="Pause"/>
		<method name="PlayPause"/>
		<method name="Stop"/>
		<method name="Play"/>
		<method name="Seek"><arg direction="in" type="x" name="Offset"/></method>
		<method name="SetPosition"><arg direction="in" type="o" name="TrackId"/><arg direction="in" type="x" name="Position"/></method>
		<method name="OpenUri"><arg direction="in" type="s" name="Uri"/></method>
		<signal name="Seeked"><arg type="x" name="Position"/></signal>
		<property name="PlaybackStatus" type="s" access="read"/>
		<property name="LoopStatus" type="s" access="readwrite"/>
		<property name="Rate" type="d" access="readwrite"/>
		<property name="Shuffle" type="b" access="readwrite"/>
		<property name="Metadata" type="a{sv}" access="read"/>
		<property name="Volume" type="d" access="readwrite"/>
		<property name="Position" type="x" access="read"/>
		<property name="MinimumRate" type="d" access="read"/>
		<property name="MaximumRate" type="d" access="read"/>
		<property name="Identity" type="s" access="read"/>
		<property name="CanGoNext" type="b" access="read"/>
		<property name="CanGoPrevious" type="b" access="read"/>
		<property name="CanPlay" type="b" access="read"/>
		<property name="CanPause" type="b" access="read"/>
		<property name="CanSeek" type="b" access="read"/>
		<property name="CanControl" type="b" access="read"/>
	</interface>
	<interface name="org.freedesktop.DBus.Properties">
		<method name="Get"><arg direction="in" type="s" name="interface_name"/><arg direction="in" type="s" name="property_name"/><arg direction="out" type="v" name="value"/></method>
		<method name="GetAll"><arg direction="in" type="s" name="interface_name"/><arg direction="out" type="a{sv}" name="properties"/></method>
		<method name="Set"><arg direction="in" type="s" name="interface_name"/><arg direction="in" type="s" name="property_name"/><arg direction="in" type="v" name="value"/></method>
		<signal name="PropertiesChanged"><arg type="s" name="interface_name"/><arg type="a{sv}" name="changed_properties"/><arg type="as" name="invalidated_properties"/></signal>
	</interface>
	<interface name="org.freedesktop.DBus.Introspectable">
		<method name="Introspect"><arg direction="out" type="s" name="data"/></method>
	</interface>
</node>`

type PlayerSnapshot struct {
	Enabled        bool   `json:"enabled"`
	Identity       string `json:"identity"`
	PlaybackStatus string `json:"playbackStatus"`
	Title          string `json:"title"`
	Artist         string `json:"artist"`
	Album          string `json:"album"`
	Length         int64  `json:"length"`
	Position       int64  `json:"position"`
	CanControl     bool   `json:"canControl"`
	CanPlay        bool   `json:"canPlay"`
	CanPause       bool   `json:"canPause"`
	CanGoNext      bool   `json:"canGoNext"`
	CanGoPrevious  bool   `json:"canGoPrevious"`
}

type PlayerCommand struct {
	Command string `json:"command,omitempty"`
	Lease   string `json:"lease,omitempty"`
}

type mprisPlayer struct {
	conn       *dbus.Conn
	dispatch   func(PlayerCommand) *dbus.Error
	stateMu    sync.RWMutex
	snapshot   PlayerSnapshot
	closed     bool
	publishMu  sync.Mutex
	registerMu sync.Mutex
	registered map[dbus.ObjectPath]struct{}
}

type mprisPlayerMethods struct{ player *mprisPlayer }
type mprisProperties struct{ player *mprisPlayer }

func newMPRISPlayer(conn *dbus.Conn, dispatch func(PlayerCommand) *dbus.Error) *mprisPlayer {
	return &mprisPlayer{
		conn:       conn,
		dispatch:   dispatch,
		snapshot:   disabledPlayerSnapshot(),
		registered: make(map[dbus.ObjectPath]struct{}),
	}
}

func disabledPlayerSnapshot() PlayerSnapshot {
	return PlayerSnapshot{PlaybackStatus: "Stopped"}
}

func stalePlayerSnapshot(snapshot PlayerSnapshot) PlayerSnapshot {
	return PlayerSnapshot{
		Enabled:        snapshot.Enabled,
		Identity:       snapshot.Identity,
		PlaybackStatus: "Stopped",
	}
}

func normalizePlayerSnapshot(snapshot PlayerSnapshot) PlayerSnapshot {
	if !snapshot.CanControl {
		snapshot.CanPlay = false
		snapshot.CanPause = false
		snapshot.CanGoNext = false
		snapshot.CanGoPrevious = false
	}
	return snapshot
}

func validatePlayerSnapshot(snapshot PlayerSnapshot) error {
	switch snapshot.PlaybackStatus {
	case "Playing", "Paused", "Stopped":
	default:
		return fmt.Errorf("invalid playbackStatus: %q", snapshot.PlaybackStatus)
	}
	if snapshot.Length < 0 {
		return fmt.Errorf("length must be nonnegative")
	}
	if snapshot.Position < 0 {
		return fmt.Errorf("position must be nonnegative")
	}
	return nil
}

func playerProperties(snapshot PlayerSnapshot) map[string]dbus.Variant {
	if !snapshot.Enabled {
		snapshot = disabledPlayerSnapshot()
	}

	metadata := map[string]dbus.Variant{
		"mpris:trackid": dbus.MakeVariant(playerTrackID(snapshot)),
	}
	if hasPlayerTrack(snapshot) {
		metadata["xesam:title"] = dbus.MakeVariant(snapshot.Title)
		metadata["xesam:artist"] = dbus.MakeVariant([]string{snapshot.Artist})
		metadata["xesam:album"] = dbus.MakeVariant(snapshot.Album)
		metadata["mpris:length"] = dbus.MakeVariant(snapshot.Length)
	}

	return map[string]dbus.Variant{
		"PlaybackStatus": dbus.MakeVariant(snapshot.PlaybackStatus),
		"LoopStatus":     dbus.MakeVariant("None"),
		"Rate":           dbus.MakeVariant(1.0),
		"Shuffle":        dbus.MakeVariant(false),
		"Metadata":       dbus.MakeVariant(metadata),
		"Volume":         dbus.MakeVariant(1.0),
		"Position":       dbus.MakeVariant(snapshot.Position),
		"MinimumRate":    dbus.MakeVariant(1.0),
		"MaximumRate":    dbus.MakeVariant(1.0),
		"Identity":       dbus.MakeVariant(snapshot.Identity),
		"CanGoNext":      dbus.MakeVariant(snapshot.CanGoNext),
		"CanGoPrevious":  dbus.MakeVariant(snapshot.CanGoPrevious),
		"CanPlay":        dbus.MakeVariant(snapshot.CanPlay),
		"CanPause":       dbus.MakeVariant(snapshot.CanPause),
		"CanSeek":        dbus.MakeVariant(false),
		"CanControl":     dbus.MakeVariant(snapshot.CanControl),
	}
}

func hasPlayerTrack(snapshot PlayerSnapshot) bool {
	return snapshot.Enabled && (snapshot.Title != "" || snapshot.Artist != "" || snapshot.Album != "" || snapshot.Length > 0)
}

func playerTrackID(snapshot PlayerSnapshot) dbus.ObjectPath {
	if !hasPlayerTrack(snapshot) {
		return dbus.ObjectPath("/org/mpris/MediaPlayer2/TrackList/NoTrack")
	}
	metadata := fmt.Sprintf("%q\x00%q\x00%q\x00%d", snapshot.Title, snapshot.Artist, snapshot.Album, snapshot.Length)
	hash := sha256.Sum256([]byte(metadata))
	return dbus.ObjectPath(fmt.Sprintf("/com/danklinux/bluez/player/track/%x", hash[:12]))
}

func changedPlayerProperties(old, current PlayerSnapshot) map[string]dbus.Variant {
	oldProperties := playerProperties(old)
	currentProperties := playerProperties(current)
	changed := make(map[string]dbus.Variant)
	for name, value := range currentProperties {
		if name == "Position" || reflect.DeepEqual(oldProperties[name], value) {
			continue
		}
		changed[name] = value
	}
	return changed
}

func (p *mprisPlayer) export() error {
	if p.conn == nil {
		return fmt.Errorf("system bus connection not initialized")
	}
	if err := p.conn.ExportWithMap(&mprisPlayerMethods{player: p}, map[string]string{"SeekCommand": "Seek"}, mprisPlayerPath, mprisPlayerIface); err != nil {
		return fmt.Errorf("MPRIS player export failed: %w", err)
	}
	if err := p.conn.Export(&mprisProperties{player: p}, mprisPlayerPath, propertiesIface); err != nil {
		p.unexport()
		return fmt.Errorf("MPRIS properties export failed: %w", err)
	}
	if err := p.conn.Export(introspect.Introspectable(mprisPlayerIntrospection), mprisPlayerPath, introspectableIface); err != nil {
		p.unexport()
		return fmt.Errorf("MPRIS introspection export failed: %w", err)
	}
	return nil
}

func (p *mprisPlayer) unexport() {
	if p.conn == nil {
		return
	}
	_ = p.conn.Export(nil, mprisPlayerPath, mprisPlayerIface)
	_ = p.conn.Export(nil, mprisPlayerPath, propertiesIface)
	_ = p.conn.Export(nil, mprisPlayerPath, introspectableIface)
}

func (p *mprisPlayer) publish(snapshot PlayerSnapshot, adapters []dbus.ObjectPath) error {
	snapshot = normalizePlayerSnapshot(snapshot)
	p.publishMu.Lock()
	defer p.publishMu.Unlock()

	old, err := p.updateSnapshot(snapshot)
	if err != nil {
		return err
	}
	return p.publishSnapshotChange(old, snapshot, adapters)
}

func (p *mprisPlayer) updateSnapshot(snapshot PlayerSnapshot) (PlayerSnapshot, error) {
	snapshot = normalizePlayerSnapshot(snapshot)
	if err := validatePlayerSnapshot(snapshot); err != nil {
		return PlayerSnapshot{}, err
	}

	p.stateMu.Lock()
	defer p.stateMu.Unlock()
	if p.closed {
		return PlayerSnapshot{}, fmt.Errorf("MPRIS player is closed")
	}
	old := p.snapshot
	p.snapshot = snapshot
	return old, nil
}

func (p *mprisPlayer) publishSnapshotChange(old, snapshot PlayerSnapshot, adapters []dbus.ObjectPath) error {
	var propertiesErr error
	if changed := changedPlayerProperties(old, snapshot); len(changed) > 0 && p.conn != nil {
		propertiesErr = p.conn.Emit(mprisPlayerPath, propertiesIface+".PropertiesChanged", mprisPlayerIface, changed, []string{})
	}
	return errors.Join(propertiesErr, p.reconcile(adapters))
}

func (p *mprisPlayer) currentSnapshot() PlayerSnapshot {
	p.stateMu.RLock()
	defer p.stateMu.RUnlock()
	return p.snapshot
}

func registrationChanges(registered map[dbus.ObjectPath]struct{}, adapters []dbus.ObjectPath, enabled bool) (add, remove []dbus.ObjectPath) {
	desired := make(map[dbus.ObjectPath]struct{}, len(adapters))
	if enabled {
		for _, path := range adapters {
			desired[path] = struct{}{}
		}
	}
	for path := range registered {
		if _, ok := desired[path]; !ok {
			remove = append(remove, path)
		}
	}
	for path := range desired {
		if _, ok := registered[path]; !ok {
			add = append(add, path)
		}
	}
	slices.Sort(add)
	slices.Sort(remove)
	return add, remove
}

func (p *mprisPlayer) reconcile(adapters []dbus.ObjectPath) error {
	if p.conn == nil {
		return nil
	}

	p.registerMu.Lock()
	defer p.registerMu.Unlock()

	snapshot := p.currentSnapshot()
	add, remove := registrationChanges(p.registered, adapters, snapshot.Enabled)
	var errs []error
	for _, adapter := range remove {
		obj := p.conn.Object(bluezService, adapter)
		err := obj.Call(media1Iface+".UnregisterPlayer", 0, mprisPlayerPath).Err
		if err != nil {
			errs = append(errs, fmt.Errorf("unregister MPRIS player from %s: %w", adapter, err))
		}
		if err == nil || !slices.Contains(adapters, adapter) {
			delete(p.registered, adapter)
		}
	}
	for _, adapter := range add {
		obj := p.conn.Object(bluezService, adapter)
		if err := obj.Call(media1Iface+".RegisterPlayer", 0, mprisPlayerPath, playerProperties(snapshot)).Err; err != nil {
			errs = append(errs, fmt.Errorf("register MPRIS player on %s: %w", adapter, err))
			continue
		}
		p.registered[adapter] = struct{}{}
	}
	return errors.Join(errs...)
}

func (p *mprisPlayer) clearRegistrations() {
	p.registerMu.Lock()
	clear(p.registered)
	p.registerMu.Unlock()
}

func (p *mprisPlayer) close() error {
	p.stateMu.Lock()
	if p.closed {
		p.stateMu.Unlock()
		return nil
	}
	p.closed = true
	p.snapshot = disabledPlayerSnapshot()
	p.stateMu.Unlock()

	p.registerMu.Lock()
	registered := maps.Clone(p.registered)
	var errs []error
	if p.conn != nil {
		for adapter := range registered {
			obj := p.conn.Object(bluezService, adapter)
			if err := obj.Call(media1Iface+".UnregisterPlayer", 0, mprisPlayerPath).Err; err != nil {
				errs = append(errs, fmt.Errorf("unregister MPRIS player from %s: %w", adapter, err))
			}
		}
	}
	clear(p.registered)
	p.registerMu.Unlock()
	p.unexport()
	return errors.Join(errs...)
}

func (p *mprisPlayer) dispatchCommand(command string) *dbus.Error {
	if p.dispatch == nil {
		return commandDeliveryError("no active MPRIS command owner")
	}
	return p.dispatch(PlayerCommand{Command: command})
}

func supportsPlayerCommand(snapshot PlayerSnapshot, command string) bool {
	allowed := snapshot.Enabled && snapshot.CanControl
	switch command {
	case "play":
		return allowed && snapshot.CanPlay
	case "pause":
		return allowed && snapshot.CanPause
	case "playPause":
		if snapshot.PlaybackStatus == "Playing" {
			return allowed && snapshot.CanPause
		}
		return allowed && snapshot.CanPlay
	case "next":
		return allowed && snapshot.CanGoNext
	case "previous":
		return allowed && snapshot.CanGoPrevious
	case "stop":
		return allowed
	default:
		return false
	}
}

func notSupportedError(method string) *dbus.Error {
	return dbus.NewError("org.freedesktop.DBus.Error.NotSupported", []any{fmt.Sprintf("MPRIS command %s is not supported", method)})
}

func commandDeliveryError(message string) *dbus.Error {
	return dbus.NewError("org.freedesktop.DBus.Error.Failed", []any{message})
}

func (m *mprisPlayerMethods) Next() *dbus.Error     { return m.player.dispatchCommand("next") }
func (m *mprisPlayerMethods) Previous() *dbus.Error { return m.player.dispatchCommand("previous") }
func (m *mprisPlayerMethods) Pause() *dbus.Error    { return m.player.dispatchCommand("pause") }
func (m *mprisPlayerMethods) PlayPause() *dbus.Error {
	return m.player.dispatchCommand("playPause")
}
func (m *mprisPlayerMethods) Stop() *dbus.Error { return m.player.dispatchCommand("stop") }
func (m *mprisPlayerMethods) Play() *dbus.Error { return m.player.dispatchCommand("play") }
func (m *mprisPlayerMethods) SeekCommand(_ int64) *dbus.Error {
	return notSupportedError("seek")
}
func (m *mprisPlayerMethods) SetPosition(_ dbus.ObjectPath, _ int64) *dbus.Error {
	return notSupportedError("setPosition")
}
func (m *mprisPlayerMethods) OpenUri(_ string) *dbus.Error {
	return notSupportedError("openUri")
}

func (p *mprisProperties) Get(iface, property string) (dbus.Variant, *dbus.Error) {
	if iface != mprisPlayerIface {
		return dbus.Variant{}, dbus.NewError("org.freedesktop.DBus.Error.UnknownInterface", []any{iface})
	}
	value, ok := playerProperties(p.player.currentSnapshot())[property]
	if !ok {
		return dbus.Variant{}, dbus.NewError("org.freedesktop.DBus.Error.UnknownProperty", []any{property})
	}
	return value, nil
}

func (p *mprisProperties) GetAll(iface string) (map[string]dbus.Variant, *dbus.Error) {
	if iface != mprisPlayerIface {
		return nil, dbus.NewError("org.freedesktop.DBus.Error.UnknownInterface", []any{iface})
	}
	return playerProperties(p.player.currentSnapshot()), nil
}

func (p *mprisProperties) Set(iface, property string, _ dbus.Variant) *dbus.Error {
	if iface != mprisPlayerIface {
		return dbus.NewError("org.freedesktop.DBus.Error.UnknownInterface", []any{iface})
	}
	if _, ok := playerProperties(p.player.currentSnapshot())[property]; !ok {
		return dbus.NewError("org.freedesktop.DBus.Error.UnknownProperty", []any{property})
	}
	switch property {
	case "LoopStatus", "Rate", "Shuffle", "Volume":
		return dbus.NewError("org.freedesktop.DBus.Error.NotSupported", []any{fmt.Sprintf("setting MPRIS property %s is not supported", property)})
	default:
		return dbus.NewError("org.freedesktop.DBus.Error.PropertyReadOnly", []any{property})
	}
}
