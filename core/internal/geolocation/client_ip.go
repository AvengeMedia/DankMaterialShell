package geolocation

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

type IpClient struct {
	currLocation *Location
}

type ipLocationResult struct {
	Location
	City string
}

type ipAPIResponse struct {
	Status string  `json:"status"`
	Lat    float64 `json:"lat"`
	Lon    float64 `json:"lon"`
	City   string  `json:"city"`
}

func newIpClient() *IpClient {
	return &IpClient{
		currLocation: &Location{},
	}
}

func (c *IpClient) Subscribe(id string) chan Location {
	ch := make(chan Location, 1)
	if location, err := c.GetLocation(); err == nil {
		ch <- location
	}
	return ch
}

func (c *IpClient) Unsubscribe(id string) {}

func (c *IpClient) Close() {}

func (c *IpClient) GetLocation() (Location, error) {
	if c.currLocation.Latitude != 0 || c.currLocation.Longitude != 0 {
		return *c.currLocation, nil
	}

	result, err := fetchIPLocation()
	if err != nil {
		return Location{}, err
	}

	c.currLocation.Latitude = result.Latitude
	c.currLocation.Longitude = result.Longitude
	return *c.currLocation, nil
}

func fetchIPLocation() (ipLocationResult, error) {
	client := &http.Client{Timeout: 10 * time.Second}

	resp, err := client.Get("http://ip-api.com/json/")
	if err != nil {
		return ipLocationResult{}, fmt.Errorf("failed to fetch IP location: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return ipLocationResult{}, fmt.Errorf("ip-api.com returned status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return ipLocationResult{}, fmt.Errorf("failed to read response: %w", err)
	}

	var data ipAPIResponse
	if err := json.Unmarshal(body, &data); err != nil {
		return ipLocationResult{}, fmt.Errorf("failed to parse response: %w", err)
	}

	if data.Status == "fail" || (data.Lat == 0 && data.Lon == 0) {
		return ipLocationResult{}, fmt.Errorf("ip-api.com returned no location data")
	}

	return ipLocationResult{
		Location: Location{Latitude: data.Lat, Longitude: data.Lon},
		City:     data.City,
	}, nil
}
