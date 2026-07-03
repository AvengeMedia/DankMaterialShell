package plugins

import (
	"encoding/json"
	"net/http"
	"time"
)

const feedbackURL = "https://api.danklinux.com/plugins"

type Feedback struct {
	Upvotes  int
	Status   []string
	IssueURL string
	Similar  []string
}

// FetchFeedback retrieves community upvotes and moderator status from the directory API.
// Best-effort: any failure returns a nil map.
func FetchFeedback() map[string]Feedback {
	client := &http.Client{Timeout: 5 * time.Second}

	resp, err := client.Get(feedbackURL)
	if err != nil {
		return nil
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil
	}

	var payload struct {
		Plugins []struct {
			ID       string   `json:"id"`
			Upvotes  int      `json:"upvotes"`
			Status   []string `json:"status"`
			IssueURL string   `json:"issueUrl"`
			Similar  []string `json:"similar"`
		} `json:"plugins"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return nil
	}

	feedback := make(map[string]Feedback, len(payload.Plugins))
	for _, p := range payload.Plugins {
		feedback[p.ID] = Feedback{Upvotes: p.Upvotes, Status: p.Status, IssueURL: p.IssueURL, Similar: p.Similar}
	}
	return feedback
}
