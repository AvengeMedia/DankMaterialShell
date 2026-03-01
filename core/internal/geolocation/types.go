package geolocation

type Location struct {
	Latitude  float64
	Longitude float64
}

type Client interface {
	GetLocation() (Location, error)

	Subscribe(id string) chan Location
	Unsubscribe(id string)

	Close()
}
