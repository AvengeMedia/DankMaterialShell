package chat

import (
	"context"
	"sort"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/chat"
)

// Opening a conversation from outside the UI means naming it, and there is no
// single identifier that works everywhere: a chat id is opaque and
// provider-specific, and a name is the only thing a person actually remembers.
//
// So callers pass whatever they have and this ranks the possibilities, rather
// than forcing them to know which kind of identifier a provider uses.
//
// Nothing here parses an id. A phone number, email or username is matched
// against the handles a bridge declared, because only the bridge knows what its
// service uses -- WhatsApp ids, for one, are now privacy identifiers with no
// phone number in them at all, so digging through the id finds nothing.

// Match scores, highest first. Ordered so an exact identifier always beats a
// name that happens to contain the same text.
const (
	scoreQualified    = 100 // provider:chatId
	scoreExactID      = 90  // the chat id itself
	scoreExactHandle  = 80  // a phone number, email or username the chat answers to
	scoreExactName    = 70
	scoreSuffixHandle = 60 // a national number typed without its country code
	scorePrefixName   = 40
	scoreContainsName = 20
)

// minPhoneSuffix is how much of a number must match when the country code is
// omitted. Shorter than this and unrelated conversations start matching.
const minPhoneSuffix = 7

// ResolveCandidate is one possible conversation for a query.
type ResolveCandidate struct {
	Provider     string   `json:"provider"`
	ChatID       string   `json:"chatId"`
	Name         string   `json:"name"`
	ProviderName string   `json:"providerName"`
	IsGroup      bool     `json:"isGroup"`
	Handles      []string `json:"handles,omitempty"`
	LastTS       int64    `json:"lastTs"`
	Unread       int      `json:"unread"`
	Score        int      `json:"score"`
}

// Resolve ranks the conversations a query could mean, best first.
//
// An empty result means nothing matched; more than one means the caller should
// ask rather than guess.
func (m *Manager) Resolve(ctx context.Context, query string, limit int) []ResolveCandidate {
	query = strings.TrimSpace(query)
	if query == "" {
		return nil
	}
	if limit <= 0 {
		limit = 10
	}

	// A qualified "provider:chatId" is unambiguous by construction, and is what
	// the UI itself passes around. Answer it without touching the rest.
	if provider, chatID, ok := splitQualified(query); ok {
		if c, err := m.Store().ChatByID(ctx, provider, chatID); err == nil {
			return []ResolveCandidate{m.candidate(c, scoreQualified)}
		}
	}

	// Everything known, not just conversations with activity: finding someone
	// you have never written to is exactly when resolving by name matters.
	chats, err := m.Store().AllChats(ctx, 5000)
	if err != nil {
		return nil
	}

	lowerQuery := strings.ToLower(query)
	queryDigits := digitsOf(query)

	var out []ResolveCandidate
	for _, c := range chats {
		if score := scoreChat(c, query, lowerQuery, queryDigits); score > 0 {
			out = append(out, m.candidate(c, score))
		}
	}

	// Best match first; among equals the most recently active conversation is
	// the one a person means.
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].Score != out[j].Score {
			return out[i].Score > out[j].Score
		}
		return out[i].LastTS > out[j].LastTS
	})

	if len(out) > limit {
		out = out[:limit]
	}
	return out
}

func scoreChat(c chat.Chat, query, lowerQuery, queryDigits string) int {
	if c.ID == query {
		return scoreExactID
	}

	name := strings.ToLower(c.Name)
	switch {
	case name != "" && name == lowerQuery:
		return scoreExactName
	}

	// Handles: whatever else the bridge said this conversation answers to.
	for _, handle := range c.Handles {
		if handle == "" {
			continue
		}
		if strings.EqualFold(handle, query) {
			return scoreExactHandle
		}

		// Numeric handles compare on digits alone, so "+90 555 123 45 67" and
		// "905551234567" are the same query.
		if queryDigits != "" {
			handleDigits := digitsOf(handle)
			if handleDigits == "" {
				continue
			}
			if handleDigits == queryDigits {
				return scoreExactHandle
			}
			if len(queryDigits) >= minPhoneSuffix && strings.HasSuffix(handleDigits, queryDigits) {
				return scoreSuffixHandle
			}
		}
	}

	if name != "" {
		if strings.HasPrefix(name, lowerQuery) {
			return scorePrefixName
		}
		if strings.Contains(name, lowerQuery) {
			return scoreContainsName
		}
	}

	// Subject matters for mail-shaped providers, where the "name" is a thread.
	if c.Subject != "" && strings.Contains(strings.ToLower(c.Subject), lowerQuery) {
		return scoreContainsName
	}

	return 0
}

func (m *Manager) candidate(c chat.Chat, score int) ResolveCandidate {
	return ResolveCandidate{
		Provider:     c.Provider,
		ChatID:       c.ID,
		Name:         c.Name,
		ProviderName: m.providerName(c.Provider),
		IsGroup:      c.IsGroup,
		Handles:      c.Handles,
		LastTS:       c.LastTS,
		Unread:       c.Unread,
		Score:        score,
	}
}

// splitQualified parses "provider:chatId".
//
// Split on the first colon only: chat ids contain colons on some providers, and
// provider ids never do.
func splitQualified(query string) (provider, chatID string, ok bool) {
	provider, chatID, found := strings.Cut(query, ":")
	if !found || provider == "" || chatID == "" {
		return "", "", false
	}
	return provider, chatID, true
}

// digitsOf strips formatting so "+90 555 123 45 67" and "905551234567" compare
// equal.
func digitsOf(s string) string {
	var b strings.Builder
	for _, r := range s {
		if r >= '0' && r <= '9' {
			b.WriteRune(r)
		}
	}
	return b.String()
}
