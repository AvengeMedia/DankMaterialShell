package network

import (
	"fmt"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/errdefs"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
)

// Event strings per WPA_EVENT_* in contrib/wpa/src/common/wpa_ctrl.h
// (freebsd-src).
const (
	wpaEventConnected    = "CTRL-EVENT-CONNECTED"
	wpaEventDisconnected = "CTRL-EVENT-DISCONNECTED"
	wpaEventScanResults  = "CTRL-EVENT-SCAN-RESULTS"
	wpaEventTempDisabled = "CTRL-EVENT-SSID-TEMP-DISABLED"
)

const (
	wpaMonitorReadTimeout    = 5 * time.Second
	wpaMonitorPingInterval   = 30 * time.Second
	wpaMonitorReconnectDelay = 2 * time.Second
)

type wpaEvent struct {
	priority int
	name     string
	args     string
}

func parseWpaEventLine(line string) (wpaEvent, bool) {
	if len(line) < 3 || line[0] != '<' {
		return wpaEvent{}, false
	}

	end := strings.IndexByte(line, '>')
	if end < 0 {
		return wpaEvent{}, false
	}

	priority, err := strconv.Atoi(line[1:end])
	if err != nil {
		return wpaEvent{}, false
	}

	rest := line[end+1:]
	name, args, _ := strings.Cut(rest, " ")
	if name == "" {
		return wpaEvent{}, false
	}

	return wpaEvent{priority: priority, name: name, args: args}, true
}

// Args format: id=%d ssid="%s" auth_failures=%u duration=%d reason=%s, per
// wpas_auth_failed in contrib/wpa/wpa_supplicant/wpa_supplicant.c
// (freebsd-src); the SSID is printf_encoded inside the quotes.
func parseWpaTempDisabled(args string) (ssid string, reason string) {
	if _, after, ok := strings.Cut(args, `ssid="`); ok {
		raw := after
		if end := indexUnescapedQuote(raw); end >= 0 {
			ssid = decodeWpaSSIDText(raw[:end])
		}
	}

	for field := range strings.FieldsSeq(args) {
		if value, ok := strings.CutPrefix(field, "reason="); ok {
			reason = value
			break
		}
	}

	return ssid, reason
}

func indexUnescapedQuote(s string) int {
	for i := 0; i < len(s); i++ {
		switch s[i] {
		case '\\':
			i++
		case '"':
			return i
		}
	}
	return -1
}

func (b *WpaSupplicantBackend) StartMonitoring(onStateChange func()) error {
	b.onStateChange = onStateChange

	monitor, err := newWpaCtrlConn(filepath.Join(b.ctrlDir, b.ifname))
	if err != nil {
		return fmt.Errorf("failed to open wpa_ctrl monitor socket: %w", err)
	}
	if err := monitor.attach(); err != nil {
		monitor.close()
		return fmt.Errorf("failed to attach wpa_ctrl monitor: %w", err)
	}
	b.monitor = monitor

	b.sigWG.Add(1)
	go b.monitorLoop()

	return nil
}

func (b *WpaSupplicantBackend) monitorLoop() {
	defer b.sigWG.Done()

	lastActivity := time.Now()
	pingOutstanding := false
	var pingSent time.Time

	for {
		select {
		case <-b.stopChan:
			return
		default:
		}

		msg, err := b.monitor.readDatagram(wpaMonitorReadTimeout)
		switch {
		case err == nil:
			lastActivity = time.Now()
			if strings.HasPrefix(msg, "<") {
				b.handleEvent(msg)
				continue
			}
			if msg == "PONG" {
				pingOutstanding = false
			}

		case isWpaCtrlTimeout(err):
			if pingOutstanding && time.Since(pingSent) > wpaCtrlRequestTimeout {
				b.reattachMonitor()
				pingOutstanding = false
				lastActivity = time.Now()
				continue
			}
			if !pingOutstanding && time.Since(lastActivity) > wpaMonitorPingInterval {
				if b.monitor.send("PING") != nil {
					b.reattachMonitor()
					lastActivity = time.Now()
					continue
				}
				pingOutstanding = true
				pingSent = time.Now()
			}

		default:
			b.reattachMonitor()
			pingOutstanding = false
			lastActivity = time.Now()
		}
	}
}

func (b *WpaSupplicantBackend) reattachMonitor() {
	for {
		select {
		case <-b.stopChan:
			return
		default:
		}

		if err := b.monitor.reconnect(); err == nil {
			if err := b.monitor.attach(); err == nil {
				break
			}
		}

		select {
		case <-b.stopChan:
			return
		case <-time.After(wpaMonitorReconnectDelay):
		}
	}

	log.Infof("wpa_supplicant monitor reattached on %s", b.ifname)

	if err := b.updateSavedWiFiNetworks(); err != nil {
		log.Warnf("failed to refresh saved networks after wpa reattach: %v", err)
	}
	if err := b.updateState(); err != nil {
		log.Warnf("failed to refresh state after wpa reattach: %v", err)
	}
	if b.onStateChange != nil {
		b.onStateChange()
	}
}

func (b *WpaSupplicantBackend) handleEvent(raw string) {
	event, ok := parseWpaEventLine(raw)
	if !ok {
		return
	}

	switch event.name {
	case wpaEventScanResults:
		b.handleScanResults()
	case wpaEventConnected:
		b.handleConnected()
	case wpaEventDisconnected:
		b.handleDisconnected()
	case wpaEventTempDisabled:
		b.handleTempDisabled(event.args)
	}
}

func (b *WpaSupplicantBackend) handleScanResults() {
	if _, err := b.updateWiFiNetworks(); err != nil {
		log.Warnf("failed to update WiFi networks after scan: %v", err)
		return
	}

	if b.onStateChange != nil {
		b.onStateChange()
	}
}

func (b *WpaSupplicantBackend) handleConnected() {
	if err := b.updateState(); err != nil {
		log.Warnf("failed to update wpa state after connect event: %v", err)
	}

	b.attemptMutex.RLock()
	att := b.curAttempt
	b.attemptMutex.RUnlock()

	b.stateMutex.RLock()
	currentSSID := b.state.WiFiSSID
	b.stateMutex.RUnlock()

	if att != nil && att.ssid == currentSSID {
		b.finalizeAttempt(att, "")
		b.attemptMutex.Lock()
		if b.curAttempt == att {
			b.curAttempt = nil
		}
		b.attemptMutex.Unlock()
		return
	}

	if err := b.updateSavedWiFiNetworks(); err != nil {
		log.Warnf("failed to refresh saved networks after connect event: %v", err)
	}
	if b.onStateChange != nil {
		b.onStateChange()
	}
}

func (b *WpaSupplicantBackend) handleDisconnected() {
	if err := b.updateState(); err != nil {
		log.Warnf("failed to update wpa state after disconnect event: %v", err)
	}
	if err := b.updateSavedWiFiNetworks(); err != nil {
		log.Warnf("failed to refresh saved networks after disconnect event: %v", err)
	}

	if b.onStateChange != nil {
		b.onStateChange()
	}
}

func (b *WpaSupplicantBackend) handleTempDisabled(args string) {
	ssid, reason := parseWpaTempDisabled(args)

	b.attemptMutex.RLock()
	att := b.curAttempt
	b.attemptMutex.RUnlock()

	if att == nil || att.ssid != ssid {
		return
	}

	att.mu.Lock()
	att.sawTempDisabled = true
	att.mu.Unlock()

	code := errdefs.ErrConnectionFailed
	// WRONG_KEY is the reason wpas_auth_failed reports for a PSK mismatch
	// (could_be_psk_mismatch path in contrib/wpa/wpa_supplicant/events.c).
	if reason == "WRONG_KEY" {
		code = errdefs.ErrBadCredentials
	}

	b.finalizeAttempt(att, code)

	b.attemptMutex.Lock()
	if b.curAttempt == att {
		b.curAttempt = nil
	}
	b.attemptMutex.Unlock()
}
