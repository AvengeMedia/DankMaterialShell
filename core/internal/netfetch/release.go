package netfetch

import (
	"context"
	"encoding/json"
	"fmt"
	"time"
)

const latestReleaseURL = "https://api.github.com/repos/AvengeMedia/DankMaterialShell/releases/latest"

func LatestReleaseTag(ctx context.Context) (string, error) {
	body, err := Bytes(ctx, latestReleaseURL, Options{Timeout: 10 * time.Second})
	if err != nil {
		return "", err
	}

	var release struct {
		TagName string `json:"tag_name"`
	}
	if err := json.Unmarshal(body, &release); err != nil {
		return "", fmt.Errorf("failed to parse latest release: %w", err)
	}
	if release.TagName == "" {
		return "", fmt.Errorf("latest release has no tag")
	}
	return release.TagName, nil
}
