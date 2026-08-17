package chat

import (
	"context"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func newStore(t *testing.T) *HistoryStore {
	t.Helper()
	store, err := OpenHistory(filepath.Join(t.TempDir(), "h.db"))
	require.NoError(t, err)
	t.Cleanup(func() { store.Close() })
	return store
}

const prov = "test"

// MyLastTS drives the Super+Tab rotation: it separates conversations the user
// takes part in from feeds they only receive. History sync flags protocol rows
// as from_me, so counting those would pull every noisy group back in.
func TestMyLastTSIgnoresProtocolRows(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()

	const feed = "feed@g.us"
	const convo = "friend@s.whatsapp.net"

	require.NoError(t, store.TouchChat(ctx, prov, feed, "Noisy Group", "hi", 3000, true, false))
	require.NoError(t, store.TouchChat(ctx, prov, convo, "Friend", "hi", 2000, false, false))

	// A group we only receive from, whose stub events were stored as ours.
	for _, kind := range []string{KindUnsupported, KindSystem, KindDeleted} {
		require.NoError(t, store.PutMessage(ctx, Message{
			Provider: prov, ID: "stub-" + kind, ChatID: feed, TS: 2500, FromMe: true, Kind: kind,
		}))
	}
	// A conversation we actually wrote in.
	require.NoError(t, store.PutMessage(ctx, Message{
		Provider: prov, ID: "mine-1", ChatID: convo, Text: "hey", TS: 1900, FromMe: true, Kind: KindText,
	}))

	chats, err := store.Chats(ctx, 50)
	require.NoError(t, err)

	byID := map[string]Chat{}
	for _, c := range chats {
		byID[c.ID] = c
	}

	assert.Zero(t, byID[feed].MyLastTS,
		"protocol rows must not count as the user having written in the group")
	assert.Equal(t, int64(1900), byID[convo].MyLastTS,
		"a real outgoing message sets MyLastTS")
}

// A chat we have never written in reports zero, which is what keeps
// receive-only feeds out of the rotation.
func TestMyLastTSZeroWhenNeverReplied(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()

	require.NoError(t, store.TouchChat(ctx, prov, "channel@g.us", "Feed", "post", 1000, true, false))
	require.NoError(t, store.PutMessage(ctx, Message{
		Provider: prov, ID: "theirs", ChatID: "channel@g.us", Text: "post", TS: 1000, Kind: KindText,
	}))

	chats, err := store.Chats(ctx, 10)
	require.NoError(t, err)
	require.Len(t, chats, 1)
	assert.Zero(t, chats[0].MyLastTS)
}

// Delivery status only ever moves forward. A service redelivering an older copy
// of a message must not un-read something the user has already seen.
func TestStatusNeverRegresses(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()

	put := func(status string) {
		require.NoError(t, store.PutMessage(ctx, Message{
			Provider: prov, ID: "m1", ChatID: "c1", TS: 100, FromMe: true,
			Kind: KindText, Text: "hi", Status: status,
		}))
	}

	put(StatusSent)
	put(StatusDelivered)
	put(StatusSent) // a redelivery arriving late

	m, err := store.MessageByID(ctx, prov, "c1", "m1")
	require.NoError(t, err)
	assert.Equal(t, StatusDelivered, m.Status)

	require.NoError(t, store.SetMessageStatus(ctx, prov, "m1", StatusRead))
	require.NoError(t, store.SetMessageStatus(ctx, prov, "m1", StatusDelivered))

	m, err = store.MessageByID(ctx, prov, "c1", "m1")
	require.NoError(t, err)
	assert.Equal(t, StatusRead, m.Status, "read is terminal")
}

// A redelivered message without media must not erase media we already fetched.
func TestUpsertKeepsFetchedMedia(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()

	require.NoError(t, store.PutMessage(ctx, Message{
		Provider: prov, ID: "m1", ChatID: "c1", TS: 100, Kind: KindImage,
		MediaPath: "/cache/m1.jpg", MediaMime: "image/jpeg", MediaW: 800, MediaH: 600,
	}))
	require.NoError(t, store.PutMessage(ctx, Message{
		Provider: prov, ID: "m1", ChatID: "c1", TS: 100, Kind: KindImage, Text: "caption",
	}))

	m, err := store.MessageByID(ctx, prov, "c1", "m1")
	require.NoError(t, err)
	assert.Equal(t, "/cache/m1.jpg", m.MediaPath)
	assert.Equal(t, 800, m.MediaW)
	assert.Equal(t, "caption", m.Text)
}

// Paging is keyset and chronological, and reports whether older messages remain.
func TestPageKeysetPagination(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()

	var msgs []Message
	for i := 1; i <= 10; i++ {
		msgs = append(msgs, Message{
			Provider: prov, ID: string(rune('a' + i - 1)), ChatID: "c1",
			TS: int64(i * 100), Kind: KindText, Text: "m",
		})
	}
	require.NoError(t, store.PutMessages(ctx, msgs))

	newest, hasMore, err := store.Page(ctx, prov, "c1", 0, 4)
	require.NoError(t, err)
	require.Len(t, newest, 4)
	assert.True(t, hasMore)
	assert.Equal(t, int64(700), newest[0].TS, "oldest of the page comes first")
	assert.Equal(t, int64(1000), newest[3].TS)

	older, hasMore, err := store.Page(ctx, prov, "c1", newest[0].TS, 4)
	require.NoError(t, err)
	require.Len(t, older, 4)
	assert.True(t, hasMore)
	assert.Equal(t, int64(600), older[3].TS, "picks up exactly where the last page ended")

	oldest, hasMore, err := store.Page(ctx, prov, "c1", older[0].TS, 4)
	require.NoError(t, err)
	require.Len(t, oldest, 2)
	assert.False(t, hasMore, "no more once the chat is exhausted")
}

// Unread is recomputed from the messages rather than zeroed, so a message
// arriving as the chat is opened is not silently swallowed.
func TestSetReadUpToRecomputesUnread(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()

	for _, ts := range []int64{100, 200, 300} {
		require.NoError(t, store.TouchChat(ctx, prov, "c1", "Chat", "hi", ts, false, true))
		require.NoError(t, store.PutMessage(ctx, Message{
			Provider: prov, ID: string(rune('a' + ts/100)), ChatID: "c1", TS: ts, Kind: KindText, Text: "hi",
		}))
	}

	c, err := store.ChatByID(ctx, prov, "c1")
	require.NoError(t, err)
	assert.Equal(t, 3, c.Unread)

	require.NoError(t, store.SetReadUpTo(ctx, prov, "c1", 200))

	c, err = store.ChatByID(ctx, prov, "c1")
	require.NoError(t, err)
	assert.Equal(t, 1, c.Unread, "only the message newer than the read mark remains unread")
}

// Protocol rows are not unread messages; a channel full of join events should
// not wear a badge.
func TestUnreadIgnoresProtocolKinds(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()

	require.NoError(t, store.TouchChat(ctx, prov, "c1", "Chat", "", 100, true, false))
	require.NoError(t, store.PutMessage(ctx, Message{
		Provider: prov, ID: "sys", ChatID: "c1", TS: 100, Kind: KindSystem,
	}))
	require.NoError(t, store.PutMessage(ctx, Message{
		Provider: prov, ID: "real", ChatID: "c1", TS: 200, Kind: KindText, Text: "hi",
	}))

	require.NoError(t, store.SetReadUpTo(ctx, prov, "c1", 0))

	c, err := store.ChatByID(ctx, prov, "c1")
	require.NoError(t, err)
	assert.Equal(t, 1, c.Unread)
}

// A partial chat update must not blank fields an earlier event established.
func TestUpsertChatMergesPartialUpdates(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()

	require.NoError(t, store.UpsertChat(ctx, Chat{
		Provider: prov, ID: "c1", Name: "Ada", LastTS: 500, LastText: "hello",
		AvatarPath: "/cache/ada.png", IsGroup: false,
	}))
	// A later event that only carries a newer timestamp.
	require.NoError(t, store.UpsertChat(ctx, Chat{
		Provider: prov, ID: "c1", LastTS: 900, LastText: "later",
	}))

	c, err := store.ChatByID(ctx, prov, "c1")
	require.NoError(t, err)
	assert.Equal(t, "Ada", c.Name)
	assert.Equal(t, "/cache/ada.png", c.AvatarPath)
	assert.Equal(t, int64(900), c.LastTS)
	assert.Equal(t, "later", c.LastText)

	// Archiving is not settable through an upsert; it has its own method, so a
	// partial update can never flip it by omission.
	require.NoError(t, store.SetArchived(ctx, prov, "c1", true))
	c, err = store.ChatByID(ctx, prov, "c1")
	require.NoError(t, err)
	assert.True(t, c.Archived)
}

// A partial update must not undo the user's own choices. This is what a
// handles-only backfill looks like, and it used to unarchive everything.
func TestUpsertChatPreservesArchivedAndMuted(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()

	require.NoError(t, store.TouchChat(ctx, prov, "c1", "Team", "hi", 500, true, false))
	require.NoError(t, store.SetArchived(ctx, prov, "c1", true))
	require.NoError(t, store.SetMuted(ctx, prov, "c1", true))

	// A later update that only knows a handle.
	require.NoError(t, store.UpsertChat(ctx, Chat{
		Provider: prov, ID: "c1", Handles: []string{"+905551234567"},
	}))

	c, err := store.ChatByID(ctx, prov, "c1")
	require.NoError(t, err)
	assert.True(t, c.Archived, "a partial update must not unarchive")
	assert.True(t, c.Muted, "a partial update must not unmute")
	assert.Equal(t, "Team", c.Name)
	assert.Equal(t, []string{"+905551234567"}, c.Handles)
}

// Handles survive an update that does not mention them.
func TestUpsertChatPreservesHandles(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()

	require.NoError(t, store.UpsertChat(ctx, Chat{
		Provider: prov, ID: "c1", Name: "Ada", Handles: []string{"+905551234567"}}))
	require.NoError(t, store.UpsertChat(ctx, Chat{
		Provider: prov, ID: "c1", LastTS: 900, LastText: "hi"}))

	c, err := store.ChatByID(ctx, prov, "c1")
	require.NoError(t, err)
	assert.Equal(t, []string{"+905551234567"}, c.Handles)
	assert.Equal(t, int64(900), c.LastTS)
}

// AllChats sees conversations with no messages; Chats deliberately does not.
func TestAllChatsIncludesInactive(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()

	require.NoError(t, store.TouchChat(ctx, prov, "active", "Active", "hi", 500, false, false))
	require.NoError(t, store.UpsertChat(ctx, Chat{
		Provider: prov, ID: "known", Name: "Never Messaged"}))

	active, err := store.Chats(ctx, 50)
	require.NoError(t, err)
	require.Len(t, active, 1, "the conversation list shows only chats with activity")

	all, err := store.AllChats(ctx, 50)
	require.NoError(t, err)
	require.Len(t, all, 2, "search and pickers see everything known")
	assert.Equal(t, "active", all[0].ID, "active conversations come first")
}

// Chats interleave across providers by recency -- this is what lets one list
// and one rotation span every service.
func TestChatsSpanProviders(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()

	require.NoError(t, store.TouchChat(ctx, "alpha", "a1", "A", "hi", 100, false, false))
	require.NoError(t, store.TouchChat(ctx, "beta", "b1", "B", "hi", 300, false, false))
	require.NoError(t, store.TouchChat(ctx, "alpha", "a2", "C", "hi", 200, false, false))

	chats, err := store.Chats(ctx, 10)
	require.NoError(t, err)
	require.Len(t, chats, 3)
	assert.Equal(t, "beta", chats[0].Provider)
	assert.Equal(t, "alpha", chats[1].Provider)
	assert.Equal(t, int64(100), chats[2].LastTS)
}

// Two providers may legitimately use the same chat id; they must not collide.
func TestProviderScopingIsolatesIdenticalIDs(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()

	require.NoError(t, store.TouchChat(ctx, "alpha", "shared", "Alpha chat", "a", 100, false, false))
	require.NoError(t, store.TouchChat(ctx, "beta", "shared", "Beta chat", "b", 200, false, false))
	require.NoError(t, store.PutMessage(ctx, Message{
		Provider: "alpha", ID: "m1", ChatID: "shared", TS: 100, Kind: KindText, Text: "from alpha",
	}))
	require.NoError(t, store.PutMessage(ctx, Message{
		Provider: "beta", ID: "m1", ChatID: "shared", TS: 200, Kind: KindText, Text: "from beta",
	}))

	a, err := store.MessageByID(ctx, "alpha", "shared", "m1")
	require.NoError(t, err)
	assert.Equal(t, "from alpha", a.Text)

	b, err := store.MessageByID(ctx, "beta", "shared", "m1")
	require.NoError(t, err)
	assert.Equal(t, "from beta", b.Text)
}

func TestSearchMessages(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()

	require.NoError(t, store.TouchChat(ctx, prov, "c1", "Work", "", 100, false, false))
	require.NoError(t, store.PutMessages(ctx, []Message{
		{Provider: prov, ID: "m1", ChatID: "c1", TS: 100, Kind: KindText, Text: "the invoice is attached"},
		{Provider: prov, ID: "m2", ChatID: "c1", TS: 200, Kind: KindText, Text: "lunch tomorrow?"},
	}))

	hits, err := store.SearchMessages(ctx, "invoice", 10)
	require.NoError(t, err)
	require.Len(t, hits, 1)
	assert.Equal(t, "m1", hits[0].ID)
	assert.Equal(t, "Work", hits[0].ChatName, "hits carry chat context for the result row")
}

// A search for a literal wildcard must not match everything.
func TestSearchChatsEscapesWildcards(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()

	require.NoError(t, store.TouchChat(ctx, prov, "c1", "100% club", "", 100, false, false))
	require.NoError(t, store.TouchChat(ctx, prov, "c2", "Anything", "", 200, false, false))

	hits, err := store.SearchChats(ctx, "100%", 10)
	require.NoError(t, err)
	require.Len(t, hits, 1)
	assert.Equal(t, "c1", hits[0].ID)
}

// Deleting keeps the row so the conversation retains its shape and replies
// still resolve to something.
func TestMarkDeletedKeepsRow(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()

	require.NoError(t, store.PutMessage(ctx, Message{
		Provider: prov, ID: "m1", ChatID: "c1", TS: 100, Kind: KindText,
		Text: "oops", MediaPath: "/cache/m1.jpg",
	}))
	require.NoError(t, store.MarkDeleted(ctx, prov, "c1", "m1"))

	m, err := store.MessageByID(ctx, prov, "c1", "m1")
	require.NoError(t, err)
	assert.Equal(t, KindDeleted, m.Kind)
	assert.Empty(t, m.Text)
	assert.Empty(t, m.MediaPath)
}

func TestPurgeProvider(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()

	require.NoError(t, store.TouchChat(ctx, "alpha", "a1", "A", "hi", 100, false, false))
	require.NoError(t, store.TouchChat(ctx, "beta", "b1", "B", "hi", 200, false, false))
	require.NoError(t, store.PutMessage(ctx, Message{
		Provider: "alpha", ID: "m1", ChatID: "a1", TS: 100, Kind: KindText,
	}))
	require.NoError(t, store.SetMeta(ctx, "alpha", "cursor", "abc"))

	require.NoError(t, store.PurgeProvider(ctx, "alpha"))

	chats, err := store.Chats(ctx, 10)
	require.NoError(t, err)
	require.Len(t, chats, 1)
	assert.Equal(t, "beta", chats[0].Provider)

	v, err := store.GetMeta(ctx, "alpha", "cursor")
	require.NoError(t, err)
	assert.Empty(t, v)
}

// Volatile per-provider state lives in the store, not the shell's settings file.
func TestMeta(t *testing.T) {
	store := newStore(t)
	ctx := context.Background()

	v, err := store.GetMeta(ctx, prov, "missing")
	require.NoError(t, err)
	assert.Empty(t, v, "an unset key reads as empty rather than erroring")

	require.NoError(t, store.SetMeta(ctx, prov, "lastOpen", "c1"))
	require.NoError(t, store.SetMeta(ctx, prov, "lastOpen", "c2"))

	v, err = store.GetMeta(ctx, prov, "lastOpen")
	require.NoError(t, err)
	assert.Equal(t, "c2", v)
}

// Reopening must not lose data or fail on the already-current schema.
func TestReopenIsIdempotent(t *testing.T) {
	path := filepath.Join(t.TempDir(), "h.db")
	ctx := context.Background()

	store, err := OpenHistory(path)
	require.NoError(t, err)
	require.NoError(t, store.TouchChat(ctx, prov, "c1", "Chat", "hi", 100, false, false))
	require.NoError(t, store.Close())

	store, err = OpenHistory(path)
	require.NoError(t, err)
	defer store.Close()

	chats, err := store.Chats(ctx, 10)
	require.NoError(t, err)
	require.Len(t, chats, 1)
}
