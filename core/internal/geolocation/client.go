package geolocation

import "github.com/AvengeMedia/DankMaterialShell/core/internal/log"

func NewClient() Client {
	geoclueClient, err := newGeoClueClient()
	if err != nil {
		log.Warnf("GeoClue2 unavailable: %v", err)
		return newSeededIpClient()
	}

	loc, _ := geoclueClient.GetLocation()
	if loc.Latitude != 0 || loc.Longitude != 0 {
		log.Info("Using GeoClue2 location")
		return geoclueClient
	}

	log.Info("GeoClue2 has no fix yet, seeding with IP location")
	ipLoc, err := fetchIPLocation()
	if err != nil {
		log.Warnf("IP location seed failed: %v", err)
		return geoclueClient
	}

	log.Info("Seeded GeoClue2 with IP location")
	geoclueClient.SeedLocation(Location{Latitude: ipLoc.Latitude, Longitude: ipLoc.Longitude})
	return geoclueClient
}

func newSeededIpClient() *IpClient {
	client := newIpClient()
	ipLoc, err := fetchIPLocation()
	if err != nil {
		log.Warnf("IP location also failed: %v", err)
		return client
	}

	log.Info("Using IP location")
	client.currLocation.Latitude = ipLoc.Latitude
	client.currLocation.Longitude = ipLoc.Longitude
	return client
}
