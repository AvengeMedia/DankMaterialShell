package geolocation

import "github.com/AvengeMedia/DankMaterialShell/core/internal/log"

func NewClient() Client {
	geoclueClient, err := newGeoClueClient()
	if err != nil {
		log.Warnf("GeoClue2 unavailable: %v", err)
		return newIpClient()
	}
	return geoclueClient
}
