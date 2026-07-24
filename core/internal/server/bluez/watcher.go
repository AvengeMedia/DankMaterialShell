package bluez

import (
	"errors"
	"fmt"

	"github.com/godbus/dbus/v5"
)

var ErrNoAdapter = errors.New("no bluetooth adapter found")

func WaitForAdapter() error {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		return err
	}
	defer conn.Close()

	if err := conn.AddMatchSignal(
		dbus.WithMatchInterface(objectMgrIface),
		dbus.WithMatchMember("InterfacesAdded"),
	); err != nil {
		return err
	}

	signals := make(chan *dbus.Signal, 64)
	conn.Signal(signals)

	if _, err := findAdapter(conn); err == nil {
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
