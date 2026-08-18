package chat

import (
	"context"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/chat"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
)

// ingestLoop is the single writer into the store.
//
// Everything a bridge reports funnels through here, which is what lets the
// bridges themselves stay stateless: they never open the database, so they
// cannot race each other or corrupt it.
func (m *Manager) ingestLoop() {
	defer m.wg.Done()

	for {
		select {
		case <-m.stopChan:
			return
		case ev := <-m.events:
			m.ingest(ev)
		}
	}
}

func (m *Manager) ingest(ev ingestEvent) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	switch ev.frame.Event {
	case EventChat:
		if ev.frame.Chat != nil {
			m.ingestChats(ctx, ev.provider, []wireChat{*ev.frame.Chat})
		}

	case EventChats:
		m.ingestChats(ctx, ev.provider, ev.frame.Chats)

	case EventMessage:
		if ev.frame.Message != nil {
			m.ingestMessages(ctx, ev.provider, []wireMessage{*ev.frame.Message}, true)
		}

	case EventMessages:
		// A batch is backfill: store it, but do not notify for each entry.
		m.ingestMessages(ctx, ev.provider, ev.frame.Messages, false)

	case EventStatus:
		if ev.frame.MessageID == "" || ev.frame.Status == "" {
			return
		}
		if err := m.store.SetMessageStatus(ctx, ev.provider, ev.frame.MessageID, ev.frame.Status); err != nil {
			log.Warnf("chat: status update failed for %s/%s: %v", ev.provider, ev.frame.MessageID, err)
			return
		}

	case EventDeleted:
		if ev.frame.MessageID == "" {
			return
		}
		if err := m.store.MarkDeleted(ctx, ev.provider, ev.frame.ChatID, ev.frame.MessageID); err != nil {
			log.Warnf("chat: delete failed for %s/%s: %v", ev.provider, ev.frame.MessageID, err)
			return
		}

	case EventSync:
		m.mu.Lock()
		if ev.frame.Total > 0 && ev.frame.Done < ev.frame.Total {
			m.sync[ev.provider] = SyncProgress{Done: ev.frame.Done, Total: ev.frame.Total}
		} else {
			delete(m.sync, ev.provider)
		}
		m.mu.Unlock()

	case EventState, EventReady, EventAuth:
		// State and capabilities live on the bridge; a broadcast is all that
		// is needed so the UI re-reads them.

	default:
		return
	}

	m.markDirty()
}

func (m *Manager) ingestChats(ctx context.Context, provider string, chats []wireChat) {
	for _, wc := range chats {
		if wc.ID == "" {
			continue
		}

		c := chat.Chat{
			Provider:     provider,
			ID:           wc.ID,
			Name:         wc.Name,
			IsGroup:      wc.IsGroup,
			LastTS:       wc.LastTS,
			LastText:     wc.LastText,
			AvatarPath:   wc.AvatarPath,
			Subject:      wc.Subject,
			Participants: wc.Participants,
			Folder:       wc.Folder,
			Handles:      wc.Handles,
			Tags:         wc.Tags,
		}

		// A bridge that did not mention unread must not clear a count the host
		// derived from the messages themselves.
		c.Unread = -1
		if wc.Unread != nil {
			c.Unread = *wc.Unread
		}

		if err := m.store.UpsertChat(ctx, c); err != nil {
			log.Warnf("chat: failed to store chat %s/%s: %v", provider, wc.ID, err)
			continue
		}

		// Only when the bridge actually stated them, so a partial update does
		// not quietly undo what the user chose.
		if wc.Archived != nil {
			if err := m.store.SetArchived(ctx, provider, wc.ID, *wc.Archived); err != nil {
				log.Warnf("chat: failed to set archived on %s/%s: %v", provider, wc.ID, err)
			}
		}
		if wc.Muted != nil {
			if err := m.store.SetMuted(ctx, provider, wc.ID, *wc.Muted); err != nil {
				log.Warnf("chat: failed to set muted on %s/%s: %v", provider, wc.ID, err)
			}
		}
	}
}

// ingestMessages stores messages and, for live ones, decides whether to notify.
func (m *Manager) ingestMessages(ctx context.Context, provider string, msgs []wireMessage, live bool) {
	if len(msgs) == 0 {
		return
	}

	stored := make([]chat.Message, 0, len(msgs))
	for _, wm := range msgs {
		if wm.ID == "" || wm.ChatID == "" {
			log.Warnf("chat: %s sent a message with no id or chat id", provider)
			continue
		}
		stored = append(stored, m.materialize(provider, wm))
	}
	if len(stored) == 0 {
		return
	}

	// One transaction for the batch: a history sync arrives in thousands, and
	// a transaction per message turns a first login into minutes of fsync.
	if err := m.store.PutMessages(ctx, stored); err != nil {
		log.Warnf("chat: failed to store %d message(s) from %s: %v", len(stored), provider, err)
		return
	}

	for _, msg := range stored {
		// Keep the chat's activity line in step with its newest message, and
		// create the chat if the bridge never announced it.
		incrementUnread := !msg.FromMe && !isProtocol(msg.Kind)
		if err := m.store.TouchChat(ctx, provider, msg.ChatID, "", msg.Preview(), msg.TS, false, incrementUnread); err != nil {
			log.Warnf("chat: failed to touch chat %s/%s: %v", provider, msg.ChatID, err)
		}

		if live {
			m.notify.Notify(ctx, msg, m.providerName(provider), m.ProviderPrefs(provider))
		}
	}
}

// materialize turns a wire message into a stored one, resolving its media.
func (m *Manager) materialize(provider string, wm wireMessage) chat.Message {
	msg := chat.Message{
		Provider:         provider,
		ChatID:           wm.ChatID,
		ID:               wm.ID,
		TS:               wm.TS,
		FromMe:           wm.FromMe,
		SenderID:         wm.SenderID,
		SenderName:       wm.SenderName,
		SenderAvatarPath: wm.SenderAvatarPath,
		Kind:             wm.Kind,
		Text:             wm.Text,
		BodyHTML:         wm.BodyHTML,
		Status:           wm.Status,
		ReplyTo:          wm.ReplyTo,
		CC:               wm.CC,
		BCC:              wm.BCC,
		MediaRef:         wm.MediaRef,
		MediaMime:        wm.MediaMime,
		MediaW:           wm.MediaW,
		MediaH:           wm.MediaH,
		FileName:         wm.FileName,
		FileSize:         wm.FileSize,
		Duration:         wm.Duration,
	}

	if msg.TS == 0 {
		msg.TS = time.Now().UnixMilli()
	}

	// Media resolution is best-effort: a message with a broken attachment is
	// still worth storing, since its text and place in the conversation matter.
	switch {
	case wm.MediaPath != "":
		path, err := m.media.Adopt(provider, wm.ID, wm.MediaMime, wm.MediaPath)
		if err != nil {
			log.Warnf("chat: could not adopt media for %s/%s: %v", provider, wm.ID, err)
			break
		}
		msg.MediaPath = path

	case wm.MediaBytes != "":
		path, err := m.media.StoreBase64(provider, wm.ID, wm.MediaMime, wm.MediaBytes)
		if err != nil {
			log.Warnf("chat: could not store inline media for %s/%s: %v", provider, wm.ID, err)
			break
		}
		msg.MediaPath = path
	}

	return msg
}

func (m *Manager) providerName(providerID string) string {
	m.mu.RLock()
	defer m.mu.RUnlock()
	if p, ok := m.providers[providerID]; ok {
		return p.Name
	}
	return providerID
}

// isProtocol mirrors the store's notion of a bookkeeping row. Protocol rows are
// not unread messages, so a channel full of join events wears no badge.
func isProtocol(kind string) bool {
	switch kind {
	case chat.KindSystem, chat.KindDeleted, chat.KindUnsupported:
		return true
	}
	return false
}
