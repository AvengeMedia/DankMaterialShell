package chat

import (
	"context"
	"testing"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/chat"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// seedResolvable lays down conversations shaped like the ones real providers
// actually produce: opaque ids everywhere, with reachable identifiers declared
// as handles.
//
// WhatsApp ids are LIDs -- privacy identifiers with no phone number in them --
// which is exactly why nothing may parse an id to find one.
func seedResolvable(t *testing.T, m *Manager) {
	t.Helper()
	ctx := context.Background()

	for _, c := range []chat.Chat{
		{Provider: "whatsappChat", ID: "184736251900@lid", Name: "Ada Lovelace", LastTS: 5000,
			Handles: []string{"+905551234567"}},
		{Provider: "whatsappChat", ID: "927461028300@lid", Name: "Grace Hopper", LastTS: 4000,
			Handles: []string{"+905559876543"}},
		{Provider: "whatsappChat", ID: "120363000@g.us", Name: "Team Chat", IsGroup: true, LastTS: 3000},
		{Provider: "mailChat", ID: "thread-8812", Name: "Ada Lovelace", LastTS: 2500,
			Handles: []string{"ada@example.com"}},
		{Provider: "echoChat", ID: "echo-dm", Name: "Ada", LastTS: 2000},
		{Provider: "echoChat", ID: "echo-group", Name: "Echo Group", IsGroup: true, LastTS: 1000},
	} {
		require.NoError(t, m.Store().UpsertChat(ctx, c))
	}
}

func TestResolveByQualifiedID(t *testing.T) {
	m := newTestManager(t, t.TempDir())
	seedResolvable(t, m)

	got := m.Resolve(context.Background(), "echoChat:echo-dm", 10)
	require.Len(t, got, 1, "a qualified id is unambiguous and should not offer alternatives")
	assert.Equal(t, "echoChat", got[0].Provider)
	assert.Equal(t, "echo-dm", got[0].ChatID)
}

func TestResolveByRawChatID(t *testing.T) {
	m := newTestManager(t, t.TempDir())
	seedResolvable(t, m)

	got := m.Resolve(context.Background(), "184736251900@lid", 10)
	require.NotEmpty(t, got)
	assert.Equal(t, "Ada Lovelace", got[0].Name)
}

// A phone number is matched against declared handles, never against the id.
func TestResolveByPhoneNumber(t *testing.T) {
	m := newTestManager(t, t.TempDir())
	seedResolvable(t, m)
	ctx := context.Background()

	// Formatting is noise; only the digits matter.
	for _, query := range []string{"905551234567", "+90 555 123 45 67", "+90-555-123-4567"} {
		got := m.Resolve(ctx, query, 10)
		require.NotEmpty(t, got, "query %q matched nothing", query)
		assert.Equal(t, "Ada Lovelace", got[0].Name, "query %q", query)
	}

	// Without the country code, matched as a suffix.
	got := m.Resolve(ctx, "5559876543", 10)
	require.NotEmpty(t, got)
	assert.Equal(t, "Grace Hopper", got[0].Name)
}

// Handles are not only phone numbers: a mail provider's is an address, and the
// same matching has to work for it.
func TestResolveByEmailHandle(t *testing.T) {
	m := newTestManager(t, t.TempDir())
	seedResolvable(t, m)

	got := m.Resolve(context.Background(), "ada@example.com", 10)
	require.NotEmpty(t, got)
	assert.Equal(t, "mailChat", got[0].Provider)
}

// Conversations a provider knows about but that have no messages yet must still
// be findable: writing to someone for the first time starts exactly there.
func TestResolveFindsChatsWithNoMessages(t *testing.T) {
	m := newTestManager(t, t.TempDir())
	ctx := context.Background()

	require.NoError(t, m.Store().UpsertChat(ctx, chat.Chat{
		Provider: "whatsappChat", ID: "553311220099@lid", Name: "Katherine Johnson",
		Handles: []string{"+905550001122"}}))

	byName := m.Resolve(ctx, "Katherine", 10)
	require.NotEmpty(t, byName, "a known contact with no history should still be findable")
	assert.Equal(t, "Katherine Johnson", byName[0].Name)

	byPhone := m.Resolve(ctx, "+90 555 000 11 22", 10)
	require.NotEmpty(t, byPhone)
	assert.Equal(t, "Katherine Johnson", byPhone[0].Name)
}

// A short number would otherwise match unrelated conversations by coincidence.
func TestResolveIgnoresShortNumbers(t *testing.T) {
	m := newTestManager(t, t.TempDir())
	seedResolvable(t, m)

	assert.Empty(t, m.Resolve(context.Background(), "4567", 10),
		"a four-digit suffix is not enough to name a conversation")
}

func TestResolveByName(t *testing.T) {
	m := newTestManager(t, t.TempDir())
	seedResolvable(t, m)
	ctx := context.Background()

	// Exact name wins over a longer name that merely starts with it.
	got := m.Resolve(ctx, "Ada", 10)
	require.NotEmpty(t, got)
	assert.Equal(t, "echoChat", got[0].Provider, "exact name should outrank a prefix match")
	assert.Equal(t, "Ada", got[0].Name)

	// Both are still offered, so an ambiguous query can be disambiguated.
	names := make([]string, 0, len(got))
	for _, c := range got {
		names = append(names, c.Name)
	}
	assert.Contains(t, names, "Ada Lovelace")

	// Case does not matter.
	lower := m.Resolve(ctx, "grace hopper", 10)
	require.NotEmpty(t, lower)
	assert.Equal(t, "Grace Hopper", lower[0].Name)
}

// Resolution spans providers, which is the point: the caller does not have to
// know which service a person is on.
func TestResolveSpansProviders(t *testing.T) {
	m := newTestManager(t, t.TempDir())
	seedResolvable(t, m)

	got := m.Resolve(context.Background(), "o", 10)
	providers := map[string]bool{}
	for _, c := range got {
		providers[c.Provider] = true
	}
	assert.GreaterOrEqual(t, len(providers), 2,
		"expected matches from more than one provider, got %v", providers)
}

func TestResolveEmptyAndUnknown(t *testing.T) {
	m := newTestManager(t, t.TempDir())
	seedResolvable(t, m)
	ctx := context.Background()

	assert.Empty(t, m.Resolve(ctx, "", 10))
	assert.Empty(t, m.Resolve(ctx, "   ", 10))
	assert.Empty(t, m.Resolve(ctx, "nobody by that name", 10))
}

// Among equally good matches the most recently active conversation is the one
// a person means.
func TestResolveOrdersEqualScoresByRecency(t *testing.T) {
	m := newTestManager(t, t.TempDir())
	ctx := context.Background()

	require.NoError(t, m.Store().UpsertChat(ctx, chat.Chat{
		Provider: "a", ID: "old", Name: "Project Falcon", LastTS: 1000}))
	require.NoError(t, m.Store().UpsertChat(ctx, chat.Chat{
		Provider: "a", ID: "new", Name: "Project Condor", LastTS: 9000}))

	got := m.Resolve(ctx, "project", 10)
	require.Len(t, got, 2)
	assert.Equal(t, "new", got[0].ChatID, "the more recent conversation comes first")
}
