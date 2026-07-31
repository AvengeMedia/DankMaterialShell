package network

import (
	"context"
	"fmt"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/godbus/dbus/v5"
)

const (
	secretServiceBusName    = "org.freedesktop.secrets"
	secretServicePath       = "/org/freedesktop/secrets"
	secretServiceIface      = "org.freedesktop.Secret.Service"
	secretItemIface         = "org.freedesktop.Secret.Item"
	secretCollectionIface   = "org.freedesktop.Secret.Collection"
	secretPromptIface       = "org.freedesktop.Secret.Prompt"
	secretDefaultCollection = "/org/freedesktop/secrets/aliases/default"
)

type nmSecret struct {
	Session     dbus.ObjectPath
	Parameters  []byte
	Value       []byte
	ContentType string
}

type secretServiceSession struct {
	conn        *dbus.Conn
	svc         dbus.BusObject
	sessionPath dbus.ObjectPath
}

func openSecretService() (*secretServiceSession, error) {
	c, err := dbus.ConnectSessionBus()
	if err != nil {
		return nil, err
	}

	svc := c.Object(secretServiceBusName, dbus.ObjectPath(secretServicePath))

	var sessionPath dbus.ObjectPath
	call := svc.Call(secretServiceIface+".OpenSession", 0, "plain", dbus.MakeVariant(""))
	if call.Err != nil {
		c.Close()
		return nil, call.Err
	}
	if err := call.Store(new(dbus.Variant), &sessionPath); err != nil {
		c.Close()
		return nil, err
	}

	return &secretServiceSession{
		conn:        c,
		svc:         svc,
		sessionPath: sessionPath,
	}, nil
}

func (s *secretServiceSession) close() {
	s.conn.Close()
}

func (s *secretServiceSession) searchItems(attrs map[string]string) ([]dbus.ObjectPath, error) {
	var unlocked []dbus.ObjectPath
	var locked []dbus.ObjectPath
	call := s.svc.Call(secretServiceIface+".SearchItems", 0, attrs)
	if call.Err != nil {
		return nil, fmt.Errorf("SearchItems failed: %w", call.Err)
	}
	if err := call.Store(&unlocked, &locked); err != nil {
		return nil, fmt.Errorf("failed to store SearchItems result: %w", err)
	}

	if len(locked) > 0 {
		if err := s.unlock(locked); err != nil {
			log.Debugf("[SecretAgent] Failed to unlock items: %v", err)
			return nil, err
		}
		unlocked = append(unlocked, locked...)
	}

	return unlocked, nil
}

func (s *secretServiceSession) unlock(items []dbus.ObjectPath) error {
	var prompt dbus.ObjectPath
	var unlocked []dbus.ObjectPath
	call := s.svc.Call(secretServiceIface+".Unlock", 0, items)
	if call.Err != nil {
		return call.Err
	}
	if err := call.Store(&unlocked, &prompt); err != nil {
		return err
	}
	if prompt == "/" {
		return nil
	}

	if err := s.conn.AddMatchSignal(
		dbus.WithMatchInterface(secretPromptIface),
		dbus.WithMatchObjectPath(prompt),
	); err != nil {
		return err
	}
	defer s.conn.RemoveMatchSignal(
		dbus.WithMatchInterface(secretPromptIface),
		dbus.WithMatchObjectPath(prompt),
	)

	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	ch := make(chan *dbus.Signal, 10)
	s.conn.Signal(ch)

	go func() {
		defer s.conn.RemoveSignal(ch)
		for {
			select {
			case v := <-ch:
				if v.Path == prompt && v.Name == secretPromptIface+".Completed" {
					if len(v.Body) < 2 {
						log.Debugf("[SecretAgent] Unlock prompt Completed signal has %d body element(s), expected >= 2", len(v.Body))
					} else {
						if dismissed, ok := v.Body[0].(bool); ok && dismissed {
							log.Debugf("[SecretAgent] Unlock prompt dismissed by user")
						}
					}
					cancel()
					return
				}
			case <-ctx.Done():
				return
			}
		}
	}()

	promptObj := s.conn.Object(secretServiceBusName, prompt)
	if err := promptObj.Call(secretPromptIface+".Prompt", 0, "").Store(); err != nil {
		cancel()
		return err
	}

	<-ctx.Done()
	if ctx.Err() == context.DeadlineExceeded {
		promptObj.Call(secretPromptIface+".Dismiss", 0)
		return fmt.Errorf("timed out waiting for unlock prompt")
	}
	return nil
}

func (s *secretServiceSession) ensureUnlocked() error {
	collection := s.conn.Object(secretServiceBusName, dbus.ObjectPath(secretDefaultCollection))
	var locked bool
	call := collection.Call("org.freedesktop.DBus.Properties.Get", 0, secretCollectionIface, "Locked")
	if call.Err != nil {
		log.Debugf("[SecretAgent] Could not read collection Locked property (may not exist yet): %v", call.Err)
		return nil
	}
	var variant dbus.Variant
	if err := call.Store(&variant); err != nil {
		log.Debugf("[SecretAgent] Could not store collection Locked property: %v", err)
		return nil
	}
	if v, ok := variant.Value().(bool); ok {
		locked = v
	}
	if !locked {
		return nil
	}

	log.Debugf("[SecretAgent] Default collection is locked, unlocking...")
	return s.unlock([]dbus.ObjectPath{dbus.ObjectPath(secretDefaultCollection)})
}

func (s *secretServiceSession) lookup(connUuid, settingName, settingKey string) string {
	if err := s.ensureUnlocked(); err != nil {
		log.Debugf("[SecretAgent] lookup: failed to unlock collection: %v", err)
		return ""
	}

	attrs := map[string]string{
		"connection-uuid": connUuid,
		"setting-name":    settingName,
		"setting-key":     settingKey,
	}

	paths, err := s.searchItems(attrs)
	if err != nil {
		log.Debugf("[SecretAgent] searchItems failed for %s: %v", connUuid, err)
		return ""
	}

	if len(paths) == 0 {
		log.Debugf("[SecretAgent] No secret service items found for %s", connUuid)
		return ""
	}

	item := s.conn.Object(secretServiceBusName, paths[0])
	var secret nmSecret
	call := item.Call(secretItemIface+".GetSecret", 0, s.sessionPath)
	if call.Err != nil {
		log.Debugf("[SecretAgent] Secret service GetSecret failed: %v", call.Err)
		return ""
	}
	if err := call.Store(&secret); err != nil {
		log.Debugf("[SecretAgent] Failed to store GetSecret result: %v", err)
		return ""
	}

	secretValue := string(secret.Value)
	if secretValue == "" {
		log.Debugf("[SecretAgent] Secret service returned empty value for %s/%s", connUuid, settingKey)
		return ""
	}

	log.Infof("[SecretAgent] Retrieved secret from secret service for %s/%s", connUuid, settingKey)
	return secretValue
}

func (s *secretServiceSession) store(connUuid, settingName, settingKey, value, label string) error {
	if err := s.ensureUnlocked(); err != nil {
		return fmt.Errorf("failed to unlock collection: %w", err)
	}

	attrs := map[string]string{
		"connection-uuid": connUuid,
		"setting-name":    settingName,
		"setting-key":     settingKey,
	}

	secret := nmSecret{
		Session:     s.sessionPath,
		Value:       []byte(value),
		ContentType: "text/plain",
	}

	props := map[string]dbus.Variant{
		"org.freedesktop.Secret.Item.Label":      dbus.MakeVariant(label),
		"org.freedesktop.Secret.Item.Attributes": dbus.MakeVariant(attrs),
	}

	collection := s.conn.Object(secretServiceBusName, dbus.ObjectPath(secretDefaultCollection))
	call := collection.Call(secretCollectionIface+".CreateItem", 0, props, secret, true)
	if call.Err != nil {
		return fmt.Errorf("CreateItem failed: %w", call.Err)
	}

	var itemPath dbus.ObjectPath
	var promptPath dbus.ObjectPath
	if err := call.Store(&itemPath, &promptPath); err != nil {
		return fmt.Errorf("CreateItem returned invalid response: %w", err)
	}

	if promptPath != "/" && promptPath != "" {
		return fmt.Errorf("CreateItem requires prompt %s — secret not persisted for %s/%s", promptPath, connUuid, settingKey)
	}

	log.Debugf("[SecretAgent] Stored secret for %s/%s (item=%s)", connUuid, settingKey, itemPath)
	return nil
}

func (s *secretServiceSession) deleteByUuid(connUuid string) error {
	if err := s.ensureUnlocked(); err != nil {
		return fmt.Errorf("failed to unlock collection: %w", err)
	}

	attrs := map[string]string{
		"connection-uuid": connUuid,
	}

	paths, err := s.searchItems(attrs)
	if err != nil {
		return err
	}

	if len(paths) == 0 {
		return nil
	}

	for _, p := range paths {
		item := s.conn.Object(secretServiceBusName, p)
		if call := item.Call(secretItemIface+".Delete", 0); call.Err != nil {
			log.Debugf("[SecretAgent] Failed to delete %s: %v", p, call.Err)
		}
	}

	log.Debugf("[SecretAgent] Deleted %d secret item(s) for %s", len(paths), connUuid)
	return nil
}

func (a *SecretAgent) withSecretService(fn func(*secretServiceSession) error) error {
	sess, err := openSecretService()
	if err != nil {
		log.Debugf("[SecretAgent] Failed to open secret service session: %v", err)
		return err
	}
	defer sess.close()
	return fn(sess)
}

func (a *SecretAgent) trySecretService(
	connUuid string,
	settingName string,
	fields []string,
) map[string]string {
	if connUuid == "" {
		log.Debugf("[SecretAgent] trySecretService: connUuid is empty, skipping keyring lookup")
		return nil
	}
	if len(fields) == 0 {
		log.Debugf("[SecretAgent] trySecretService: no fields requested, skipping keyring lookup")
		return nil
	}

	var out map[string]string
	err := a.withSecretService(func(sess *secretServiceSession) error {
		found := make(map[string]string)
		for _, field := range fields {
			val := sess.lookup(connUuid, settingName, field)
			if val == "" {
				log.Debugf("[SecretAgent] Secret service missing field '%s' for %s", field, connUuid)
				return fmt.Errorf("missing field %s", field)
			}
			found[field] = val
		}

		out = found
		return nil
	})
	if err != nil {
		return nil
	}
	return out
}

func (a *SecretAgent) deleteSecretsByConn(connUuid string) {
	if connUuid == "" {
		return
	}

	_ = a.withSecretService(func(sess *secretServiceSession) error {
		return sess.deleteByUuid(connUuid)
	})
}
