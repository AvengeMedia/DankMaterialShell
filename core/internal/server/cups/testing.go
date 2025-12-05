package cups

func NewTestManager(client CUPSClientInterface, pkHelper PkHelper) *Manager {
	return &Manager{
		client:   client,
		pkHelper: pkHelper,
		state: &CUPSState{
			Printers: make(map[string]*Printer),
		},
		stopChan: make(chan struct{}),
		dirty:    make(chan struct{}, 1),
	}
}
