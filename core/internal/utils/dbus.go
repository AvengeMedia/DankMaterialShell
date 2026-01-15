package utils

import (
	"github.com/godbus/dbus/v5"
)

func IsDBusServiceAvailable(busName string) bool {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		return false
	}
	defer conn.Close()

	obj := conn.Object("org.freedesktop.DBus", "/org/freedesktop/DBus")
	var owned bool
	if err := obj.Call("org.freedesktop.DBus.NameHasOwner", 0, busName).Store(&owned); err != nil {
		return false
	}
	return owned
}
