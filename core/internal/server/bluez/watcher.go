package bluez

import (
	"errors"
	"fmt"

	"github.com/godbus/dbus/v5"
)

var ErrNoAdapter = errors.New("no bluetooth adapter found")

func WaitForAdapter() error {
	conn, err := dbus.SystemBus()
	if err != nil {
		return err
	}

	signals := make(chan *dbus.Signal, 64)
	conn.Signal(signals)
	defer conn.RemoveSignal(signals)

	adapterAdded := []dbus.MatchOption{dbus.WithMatchInterface(objectMgrIface), dbus.WithMatchMember("InterfacesAdded")}
	if err := conn.AddMatchSignal(adapterAdded...); err != nil {
		return err
	}
	defer conn.RemoveMatchSignal(adapterAdded...)

	if paths, err := scanAdapters(conn); err == nil && len(paths) > 0 {
		return nil
	}

	for sig := range signals {
		if sig == nil || sig.Name != objectMgrIface+".InterfacesAdded" || len(sig.Body) < 2 {
			continue
		}
		ifaces, ok := sig.Body[1].(map[string]map[string]dbus.Variant)
		if !ok {
			continue
		}
		if _, ok := ifaces[adapter1Iface]; ok {
			return nil
		}
	}
	return fmt.Errorf("dbus signal stream closed")
}
