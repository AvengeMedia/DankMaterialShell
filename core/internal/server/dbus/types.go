package dbus

import (
	"github.com/AvengeMedia/dankgo/syncmap"
	"github.com/godbus/dbus/v5"
)

type Manager struct {
	systemConn     *dbus.Conn
	sessionConn    *dbus.Conn
	systemSignals  chan *dbus.Signal
	sessionSignals chan *dbus.Signal

	subscriptions     syncmap.Map[string, *signalSubscription]
	signalSubscribers syncmap.Map[string, chan SignalEvent]
}

type signalSubscription struct {
	Bus       string
	Sender    string
	Path      string
	Interface string
	Member    string
	ClientID  string
}

type SignalEvent struct {
	SubscriptionID string `json:"subscriptionId"`
	Sender         string `json:"sender"`
	Path           string `json:"path"`
	Interface      string `json:"interface"`
	Member         string `json:"member"`
	Body           []any  `json:"body"`
}

type CallResult struct {
	Values []any `json:"values"`
}

type PropertyResult struct {
	Value any `json:"value"`
}

type IntrospectResult struct {
	XML string `json:"xml"`
}

type ListNamesResult struct {
	Names []string `json:"names"`
}

type SubscribeResult struct {
	SubscriptionID string `json:"subscriptionId"`
}
