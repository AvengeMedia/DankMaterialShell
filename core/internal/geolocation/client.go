package geolocation

import "github.com/AvengeMedia/DankMaterialShell/core/internal/log"

func NewClient() Client {
	geoclueClient, err := newGeoClueClient()
	if err != nil {
		log.Warnf("Failed to initialize GeoClue2 client: %v", err)
		log.Info("Falling back to IP location")
		return newIpClient()
	}

	loc, _ := geoclueClient.GetLocation()
	if loc.Latitude != 0 || loc.Longitude != 0 {
		return geoclueClient
	}

	log.Info("GeoClue2 has no fix yet, seeding with IP location")
	ipClient := newIpClient()
	if ipLoc, err := ipClient.GetLocation(); err == nil {
		geoclueClient.SeedLocation(ipLoc)
	}

	return geoclueClient
}
