package providers

import "github.com/duxlabs-dev/dux-shell/core/internal/windowrules"

func newTestWindowRule(id, name, appID string) windowrules.WindowRule {
	return windowrules.WindowRule{
		ID:      id,
		Name:    name,
		Enabled: true,
		MatchCriteria: windowrules.MatchCriteria{
			AppID: appID,
		},
	}
}
