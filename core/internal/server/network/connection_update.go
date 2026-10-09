package network

import (
	"fmt"
	"maps"
	"slices"

	"github.com/godbus/dbus/v5"
)

type nmSettings = map[string]map[string]dbus.Variant

const (
	nmConnGetSettings = dbusNMSettingsConnectionInterface + ".GetSettings"
	nmConnGetSecrets  = dbusNMSettingsConnectionInterface + ".GetSecrets"
	nmConnUpdate2     = dbusNMSettingsConnectionInterface + ".Update2"

	nmUpdate2FlagToDisk uint32 = 0x1
)

var nmSecretSettings = []string{
	"802-11-wireless-security", "802-1x", "vpn", "wireguard",
	"gsm", "cdma", "pppoe", "adsl", "macsec",
}

// legacyIPKeys maps each legacy ipv4/ipv6 key to its modern twin. NM ignores
// the modern key when the legacy one is sent.
var legacyIPKeys = map[string]string{
	"addresses": "address-data",
	"routes":    "route-data",
	"dns":       "dns-data",
}

func readConnectionSettings(obj dbus.BusObject, withSecrets bool) (nmSettings, error) {
	var settings nmSettings
	if err := obj.Call(nmConnGetSettings, 0).Store(&settings); err != nil {
		return nil, fmt.Errorf("failed to get connection settings: %w", err)
	}
	if withSecrets {
		if err := mergeConnectionSecrets(obj, settings); err != nil {
			return nil, err
		}
	}
	return settings, nil
}

// nestedSecrets are containers holding several secrets. A mutation that
// replaces one wholesale would drop the stored entries it doesn't mention.
var nestedSecrets = [][2]string{{"vpn", "secrets"}, {"wireguard", "peers"}}

// secretRemovals lists stored nested secrets a patch deletes with an explicit
// null: vpn.secrets keys, and public keys of peers losing their preshared-key.
type secretRemovals struct {
	vpnSecrets, peerPSKs []string
}

func secretRemovalsFromPatch(patch SettingsPatch) secretRemovals {
	var r secretRemovals
	if secrets, ok := patch["vpn"]["secrets"].(map[string]any); ok {
		for k, v := range secrets {
			if v == nil {
				r.vpnSecrets = append(r.vpnSecrets, k)
			}
		}
	}
	peers, _ := patch["wireguard"]["peers"].([]any)
	for _, p := range peers {
		peer, _ := p.(map[string]any)
		key, ok := peer["public-key"].(string)
		if psk, has := peer["preshared-key"]; ok && has && psk == nil {
			r.peerPSKs = append(r.peerPSKs, key)
		}
	}
	return r
}

// updateConnectionSettings is the single write path for NM profiles. Stored
// secrets are merged in first because NM drops every secret an update omits,
// so a failed secrets read aborts the write. Entries of nested secret
// containers that mutate omits are merged back afterwards.
// persist=false keeps the profile in whatever storage it already lives in.
func updateConnectionSettings(obj dbus.BusObject, persist bool, mutate func(nmSettings) error) error {
	return updateConnectionSettingsRemoving(obj, persist, secretRemovals{}, mutate)
}

// updateConnectionSettingsRemoving is updateConnectionSettings, except the
// nested secrets in removed are not merged back, so they are deleted.
func updateConnectionSettingsRemoving(obj dbus.BusObject, persist bool, removed secretRemovals, mutate func(nmSettings) error) error {
	if obj == nil {
		return fmt.Errorf("D-Bus connection unavailable")
	}
	settings, err := readConnectionSettings(obj, true)
	if err != nil {
		return err
	}
	stored := map[[2]string]dbus.Variant{}
	for _, k := range nestedSecrets {
		if v, ok := settings[k[0]][k[1]]; ok {
			stored[k] = v
		}
	}
	if err := mutate(settings); err != nil {
		return err
	}
	for k, v := range stored {
		if cur, ok := settings[k[0]][k[1]]; ok {
			settings[k[0]][k[1]] = mergeNestedSecret(k[0], k[1], dropRemovedSecrets(k[0], v, removed), cur)
		}
	}
	dropLegacyIPKeys(settings)

	var flags uint32
	if persist {
		flags = nmUpdate2FlagToDisk
	}
	if err := obj.Call(nmConnUpdate2, 0, settings, flags, map[string]dbus.Variant{}).Err; err != nil {
		return fmt.Errorf("failed to update connection: %w", err)
	}
	return nil
}

func mergeConnectionSecrets(obj dbus.BusObject, settings nmSettings) error {
	for _, name := range nmSecretSettings {
		section, ok := settings[name]
		if !ok {
			continue
		}

		var stored nmSettings
		if err := obj.Call(nmConnGetSecrets, 0, name).Store(&stored); err != nil {
			return fmt.Errorf("failed to get secrets for %s: %w", name, err)
		}

		for k, v := range stored[name] {
			if cur, exists := section[k]; exists {
				section[k] = mergeNestedSecret(name, k, v, cur)
			} else {
				section[k] = v
			}
		}
	}
	return nil
}

// mergeNestedSecret fills entries missing from cur with stored ones; entries in cur win.
func mergeNestedSecret(section, key string, stored, cur dbus.Variant) dbus.Variant {
	switch {
	case section == "vpn" && key == "secrets":
		return mergeVPNSecrets(stored, cur)
	case section == "wireguard" && key == "peers":
		return mergeWireGuardPeers(stored, cur)
	}
	return cur
}

func dropRemovedSecrets(section string, stored dbus.Variant, r secretRemovals) dbus.Variant {
	switch val := stored.Value().(type) {
	case map[string]string:
		if section != "vpn" || len(r.vpnSecrets) == 0 {
			return stored
		}
		out := maps.Clone(val)
		for _, k := range r.vpnSecrets {
			delete(out, k)
		}
		return dbus.MakeVariant(out)
	case []map[string]dbus.Variant:
		if section != "wireguard" || len(r.peerPSKs) == 0 {
			return stored
		}
		out := make([]map[string]dbus.Variant, len(val))
		for i, p := range val {
			out[i] = p
			if key, ok := p["public-key"].Value().(string); ok && slices.Contains(r.peerPSKs, key) {
				out[i] = maps.Clone(p)
				delete(out[i], "preshared-key")
			}
		}
		return dbus.MakeVariant(out)
	}
	return stored
}

func mergeVPNSecrets(stored, cur dbus.Variant) dbus.Variant {
	s, ok1 := stored.Value().(map[string]string)
	c, ok2 := cur.Value().(map[string]string)
	if !ok1 || !ok2 {
		return cur
	}
	out := maps.Clone(s)
	maps.Copy(out, c)
	return dbus.MakeVariant(out)
}

func mergeWireGuardPeers(stored, cur dbus.Variant) dbus.Variant {
	s, ok1 := stored.Value().([]map[string]dbus.Variant)
	c, ok2 := cur.Value().([]map[string]dbus.Variant)
	if !ok1 || !ok2 {
		return cur
	}
	psk := make(map[string]dbus.Variant, len(s))
	for _, p := range s {
		if key, ok := p["public-key"].Value().(string); ok {
			if v, ok := p["preshared-key"]; ok {
				psk[key] = v
			}
		}
	}
	out := make([]map[string]dbus.Variant, len(c))
	for i, p := range c {
		out[i] = maps.Clone(p)
		if _, has := p["preshared-key"]; has {
			continue
		}
		if key, ok := p["public-key"].Value().(string); ok {
			if v, ok := psk[key]; ok {
				out[i]["preshared-key"] = v
			}
		}
	}
	return dbus.MakeVariant(out)
}

func dropLegacyIPKeys(s nmSettings) {
	for _, family := range []string{"ipv4", "ipv6"} {
		section := s[family]
		for legacy, modern := range legacyIPKeys {
			if _, ok := section[modern]; ok {
				delete(section, legacy)
			}
		}
	}
}

func setSettingValue(s nmSettings, section, key string, value any) {
	if s[section] == nil {
		s[section] = make(map[string]dbus.Variant)
	}
	v, ok := value.(dbus.Variant)
	if !ok {
		v = dbus.MakeVariant(value)
	}
	s[section][key] = v
}

func deleteSettingValue(s nmSettings, section, key string) {
	delete(s[section], key)
}
