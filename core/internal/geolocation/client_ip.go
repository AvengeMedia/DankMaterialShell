package geolocation

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
)

type IpClient struct {
	currLocation *Location
}

type ipAPIResponse struct {
	Lat  float64 `json:"lat"`
	Lon  float64 `json:"lon"`
	City string  `json:"city"`
}

func newIpClient() *IpClient {
	return &IpClient{
		currLocation: &Location{
			Latitude:  0.0,
			Longitude: 0.0,
		},
	}
}

func (c *IpClient) Subscribe(id string) chan Location {
	ch := make(chan Location, 1)
	if location, err := c.GetLocation(); err == nil {
		ch <- location
	}

	return ch
}

func (c *IpClient) Unsubscribe(id string) {
	// Stub
}

func (c *IpClient) Close() {
	// Stub
}

func (c *IpClient) GetLocation() (Location, error) {
	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	result := Location{
		Latitude:  0.0,
		Longitude: 0.0,
	}

	resp, err := client.Get("http://ip-api.com/json/")
	if err != nil {
		return result, fmt.Errorf("failed to fetch IP location: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return result, fmt.Errorf("ip-api.com returned status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return result, fmt.Errorf("failed to read response: %w", err)
	}

	var data ipAPIResponse
	if err := json.Unmarshal(body, &data); err != nil {
		return result, fmt.Errorf("failed to parse response: %w", err)
	}

	if data.Lat == 0 && data.Lon == 0 {
		return result, fmt.Errorf("missing location data in response")
	}

	log.Infof("Fetched IP-based location: %s (%.4f, %.4f)", data.City, data.Lat, data.Lon)
	result.Latitude = data.Lat
	result.Longitude = data.Lon

	return result, nil
}
