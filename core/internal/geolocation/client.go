package geolocation

import "github.com/AvengeMedia/DankMaterialShell/core/internal/log"

func NewClient() Client {
	if geoclueClient, err := newGeoClueClient(); err != nil {
		log.Warnf("Failed to initialize GeoClue2 client: %v", err)
	} else {
		return geoclueClient
	}

	log.Info("Falling back to IP location")
	return newIpClient()
}
