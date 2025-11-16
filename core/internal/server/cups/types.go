package cups

import (
	"io"
	"sync"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/pkg/ipp"
	"github.com/AvengeMedia/DankMaterialShell/core/pkg/syncmap"
)

type CUPSState struct {
	Printers map[string]*Printer `json:"printers"`
}

type Printer struct {
	Name        string `json:"name"`
	URI         string `json:"uri"`
	State       string `json:"state"`
	StateReason string `json:"stateReason"`
	Location    string `json:"location"`
	Info        string `json:"info"`
	MakeModel   string `json:"makeModel"`
	Accepting   bool   `json:"accepting"`
	Jobs        []Job  `json:"jobs"`
}

type Job struct {
	ID          int       `json:"id"`
	Name        string    `json:"name"`
	State       string    `json:"state"`
	Printer     string    `json:"printer"`
	User        string    `json:"user"`
	Size        int       `json:"size"`
	TimeCreated time.Time `json:"timeCreated"`
}

type Manager struct {
	state             *CUPSState
	client            CUPSClientInterface
	subscription      SubscriptionManagerInterface
	stateMutex        sync.RWMutex
	subscribers       syncmap.Map[string, chan CUPSState]
	stopChan          chan struct{}
	eventWG           sync.WaitGroup
	dirty             chan struct{}
	notifierWg        sync.WaitGroup
	lastNotifiedState *CUPSState
	baseURL           string
}

type SubscriptionManagerInterface interface {
	Start() error
	Stop()
	Events() <-chan SubscriptionEvent
}

type CUPSClientInterface interface {
	GetPrinters(attributes []string) (map[string]ipp.Attributes, error)
	GetJobs(printer, class string, whichJobs string, myJobs bool, firstJobId, limit int, attributes []string) (map[int]ipp.Attributes, error)
	CancelJob(jobID int, purge bool) error
	PausePrinter(printer string) error
	ResumePrinter(printer string) error
	CancelAllJob(printer string, purge bool) error
	SendRequest(url string, req *ipp.Request, additionalResponseData io.Writer) (*ipp.Response, error)
}

type SubscriptionEvent struct {
	EventName    string
	PrinterName  string
	JobID        int
	SubscribedAt time.Time
}
