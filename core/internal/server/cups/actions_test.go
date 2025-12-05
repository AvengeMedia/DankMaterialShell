package cups

import (
	"errors"
	"testing"
	"time"

	mocks_cups "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/cups"
	"github.com/AvengeMedia/DankMaterialShell/core/pkg/ipp"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

func TestManager_GetPrinters(t *testing.T) {
	tests := []struct {
		name    string
		mockRet map[string]ipp.Attributes
		mockErr error
		want    int
		wantErr bool
	}{
		{
			name: "success",
			mockRet: map[string]ipp.Attributes{
				"printer1": {
					ipp.AttributePrinterName:            []ipp.Attribute{{Value: "printer1"}},
					ipp.AttributePrinterUriSupported:    []ipp.Attribute{{Value: "ipp://localhost/printers/printer1"}},
					ipp.AttributePrinterState:           []ipp.Attribute{{Value: 3}},
					ipp.AttributePrinterStateReasons:    []ipp.Attribute{{Value: "none"}},
					ipp.AttributePrinterLocation:        []ipp.Attribute{{Value: "Office"}},
					ipp.AttributePrinterInfo:            []ipp.Attribute{{Value: "Test Printer"}},
					ipp.AttributePrinterMakeAndModel:    []ipp.Attribute{{Value: "Generic"}},
					ipp.AttributePrinterIsAcceptingJobs: []ipp.Attribute{{Value: true}},
				},
			},
			mockErr: nil,
			want:    1,
			wantErr: false,
		},
		{
			name:    "error",
			mockRet: nil,
			mockErr: errors.New("test error"),
			want:    0,
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockClient := mocks_cups.NewMockCUPSClientInterface(t)
			mockClient.EXPECT().GetPrinters(mock.Anything).Return(tt.mockRet, tt.mockErr)

			m := &Manager{
				client: mockClient,
			}

			got, err := m.GetPrinters()
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
				assert.Equal(t, tt.want, len(got))
				if len(got) > 0 {
					assert.Equal(t, "printer1", got[0].Name)
					assert.Equal(t, "idle", got[0].State)
					assert.Equal(t, "Office", got[0].Location)
					assert.True(t, got[0].Accepting)
				}
			}
		})
	}
}

func TestManager_GetJobs(t *testing.T) {
	tests := []struct {
		name    string
		mockRet map[int]ipp.Attributes
		mockErr error
		want    int
		wantErr bool
	}{
		{
			name: "success",
			mockRet: map[int]ipp.Attributes{
				1: {
					ipp.AttributeJobID:                  []ipp.Attribute{{Value: 1}},
					ipp.AttributeJobName:                []ipp.Attribute{{Value: "test-job"}},
					ipp.AttributeJobState:               []ipp.Attribute{{Value: 5}},
					ipp.AttributeJobPrinterURI:          []ipp.Attribute{{Value: "ipp://localhost/printers/printer1"}},
					ipp.AttributeJobOriginatingUserName: []ipp.Attribute{{Value: "testuser"}},
					ipp.AttributeJobKilobyteOctets:      []ipp.Attribute{{Value: 10}},
					"time-at-creation":                  []ipp.Attribute{{Value: 1609459200}},
				},
			},
			mockErr: nil,
			want:    1,
			wantErr: false,
		},
		{
			name:    "error",
			mockRet: nil,
			mockErr: errors.New("test error"),
			want:    0,
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockClient := mocks_cups.NewMockCUPSClientInterface(t)
			mockClient.EXPECT().GetJobs("printer1", "", "not-completed", false, 0, 0, mock.Anything).
				Return(tt.mockRet, tt.mockErr)

			m := &Manager{
				client: mockClient,
			}

			got, err := m.GetJobs("printer1", "not-completed")
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
				assert.Equal(t, tt.want, len(got))
				if len(got) > 0 {
					assert.Equal(t, 1, got[0].ID)
					assert.Equal(t, "test-job", got[0].Name)
					assert.Equal(t, "processing", got[0].State)
					assert.Equal(t, "testuser", got[0].User)
					assert.Equal(t, "printer1", got[0].Printer)
					assert.Equal(t, 10240, got[0].Size)
					assert.Equal(t, time.Unix(1609459200, 0), got[0].TimeCreated)
				}
			}
		})
	}
}

func TestManager_CancelJob(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().CancelJob(1, false).Return(nil)
	mockClient.EXPECT().GetPrinters(mock.Anything).Return(map[string]ipp.Attributes{}, nil)

	m := NewTestManager(mockClient, nil)
	assert.NoError(t, m.CancelJob(1))
}

func TestManager_PausePrinter(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().PausePrinter("printer1").Return(nil)
	mockClient.EXPECT().GetPrinters(mock.Anything).Return(map[string]ipp.Attributes{}, nil)

	m := NewTestManager(mockClient, nil)
	assert.NoError(t, m.PausePrinter("printer1"))
}

func TestManager_ResumePrinter(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().ResumePrinter("printer1").Return(nil)
	mockClient.EXPECT().GetPrinters(mock.Anything).Return(map[string]ipp.Attributes{}, nil)

	m := NewTestManager(mockClient, nil)
	assert.NoError(t, m.ResumePrinter("printer1"))
}

func TestManager_PurgeJobs(t *testing.T) {
	tests := []struct {
		name    string
		mockErr error
		wantErr bool
	}{
		{
			name:    "success",
			mockErr: nil,
			wantErr: false,
		},
		{
			name:    "error",
			mockErr: errors.New("test error"),
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockClient := mocks_cups.NewMockCUPSClientInterface(t)
			mockClient.EXPECT().CancelAllJob("printer1", true).Return(tt.mockErr)
			if !tt.wantErr {
				mockClient.EXPECT().GetPrinters(mock.Anything).Return(map[string]ipp.Attributes{}, nil)
			}

			m := NewTestManager(mockClient, nil)

			err := m.PurgeJobs("printer1")
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

func TestManager_GetDevices(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().GetDevices().Return(map[string]ipp.Attributes{
		"usb://HP/LaserJet": {
			"device-class":          []ipp.Attribute{{Value: "direct"}},
			"device-info":           []ipp.Attribute{{Value: "HP LaserJet"}},
			"device-make-and-model": []ipp.Attribute{{Value: "HP LaserJet 1020"}},
		},
	}, nil)

	m := &Manager{client: mockClient}
	got, err := m.GetDevices()
	assert.NoError(t, err)
	assert.Len(t, got, 1)
	assert.Equal(t, "usb://HP/LaserJet", got[0].URI)
	assert.Equal(t, "direct", got[0].Class)
}

func TestManager_GetPPDs(t *testing.T) {
	tests := []struct {
		name    string
		mockRet map[string]ipp.Attributes
		mockErr error
		want    int
		wantErr bool
	}{
		{
			name: "success",
			mockRet: map[string]ipp.Attributes{
				"drv:///sample.drv/generic.ppd": {
					"ppd-make-and-model": []ipp.Attribute{{Value: "Generic PostScript"}},
					"ppd-type":           []ipp.Attribute{{Value: "ppd"}},
				},
			},
			mockErr: nil,
			want:    1,
			wantErr: false,
		},
		{
			name:    "error",
			mockRet: nil,
			mockErr: errors.New("test error"),
			want:    0,
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockClient := mocks_cups.NewMockCUPSClientInterface(t)
			mockClient.EXPECT().GetPPDs().Return(tt.mockRet, tt.mockErr)

			m := &Manager{client: mockClient}

			got, err := m.GetPPDs()
			if tt.wantErr {
				assert.Error(t, err)
				return
			}
			assert.NoError(t, err)
			assert.Equal(t, tt.want, len(got))
		})
	}
}

func TestManager_GetClasses(t *testing.T) {
	tests := []struct {
		name    string
		mockRet map[string]ipp.Attributes
		mockErr error
		want    int
		wantErr bool
	}{
		{
			name: "success",
			mockRet: map[string]ipp.Attributes{
				"office": {
					ipp.AttributePrinterName:  []ipp.Attribute{{Value: "office"}},
					ipp.AttributePrinterState: []ipp.Attribute{{Value: 3}},
					ipp.AttributeMemberNames:  []ipp.Attribute{{Value: "printer1"}, {Value: "printer2"}},
				},
			},
			mockErr: nil,
			want:    1,
			wantErr: false,
		},
		{
			name:    "error",
			mockRet: nil,
			mockErr: errors.New("test error"),
			want:    0,
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockClient := mocks_cups.NewMockCUPSClientInterface(t)
			mockClient.EXPECT().GetClasses(mock.Anything).Return(tt.mockRet, tt.mockErr)

			m := &Manager{client: mockClient}

			got, err := m.GetClasses()
			if tt.wantErr {
				assert.Error(t, err)
				return
			}
			assert.NoError(t, err)
			assert.Equal(t, tt.want, len(got))
			if len(got) > 0 {
				assert.Equal(t, "office", got[0].Name)
				assert.Equal(t, 2, len(got[0].Members))
			}
		})
	}
}

func TestManager_CreatePrinter(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().CreatePrinter("newprinter", "usb://HP", "generic.ppd", true, "stop-printer", "info", "location").Return(nil)
	mockClient.EXPECT().ResumePrinter("newprinter").Return(nil)
	mockClient.EXPECT().AcceptJobs("newprinter").Return(nil)
	mockClient.EXPECT().GetPrinters(mock.Anything).Return(map[string]ipp.Attributes{}, nil)

	m := NewTestManager(mockClient, nil)
	assert.NoError(t, m.CreatePrinter("newprinter", "usb://HP", "generic.ppd", true, "stop-printer", "info", "location"))
}

func TestManager_DeletePrinter(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().DeletePrinter("printer1").Return(nil)
	mockClient.EXPECT().GetPrinters(mock.Anything).Return(map[string]ipp.Attributes{}, nil)

	m := NewTestManager(mockClient, nil)
	assert.NoError(t, m.DeletePrinter("printer1"))
}

func TestManager_AcceptJobs(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().AcceptJobs("printer1").Return(nil)
	mockClient.EXPECT().GetPrinters(mock.Anything).Return(map[string]ipp.Attributes{}, nil)

	m := NewTestManager(mockClient, nil)
	assert.NoError(t, m.AcceptJobs("printer1"))
}

func TestManager_RejectJobs(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().RejectJobs("printer1").Return(nil)
	mockClient.EXPECT().GetPrinters(mock.Anything).Return(map[string]ipp.Attributes{}, nil)

	m := NewTestManager(mockClient, nil)
	assert.NoError(t, m.RejectJobs("printer1"))
}

func TestManager_SetPrinterShared(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().SetPrinterIsShared("printer1", true).Return(nil)
	mockClient.EXPECT().GetPrinters(mock.Anything).Return(map[string]ipp.Attributes{}, nil)

	m := NewTestManager(mockClient, nil)
	assert.NoError(t, m.SetPrinterShared("printer1", true))
}

func TestManager_SetPrinterLocation(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().SetPrinterLocation("printer1", "Office").Return(nil)
	mockClient.EXPECT().GetPrinters(mock.Anything).Return(map[string]ipp.Attributes{}, nil)

	m := NewTestManager(mockClient, nil)
	assert.NoError(t, m.SetPrinterLocation("printer1", "Office"))
}

func TestManager_SetPrinterInfo(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().SetPrinterInformation("printer1", "Main Printer").Return(nil)
	mockClient.EXPECT().GetPrinters(mock.Anything).Return(map[string]ipp.Attributes{}, nil)

	m := NewTestManager(mockClient, nil)
	assert.NoError(t, m.SetPrinterInfo("printer1", "Main Printer"))
}

func TestManager_MoveJob(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().MoveJob(1, "printer2").Return(nil)
	mockClient.EXPECT().GetPrinters(mock.Anything).Return(map[string]ipp.Attributes{}, nil)

	m := NewTestManager(mockClient, nil)
	err := m.MoveJob(1, "printer2")
	assert.NoError(t, err)
}

func TestManager_PrintTestPage(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().PrintTestPage("printer1", mock.Anything, mock.Anything).Return(42, nil)
	mockClient.EXPECT().GetPrinters(mock.Anything).Return(map[string]ipp.Attributes{}, nil)

	m := NewTestManager(mockClient, nil)
	jobID, err := m.PrintTestPage("printer1")
	assert.NoError(t, err)
	assert.Equal(t, 42, jobID)
}

func TestManager_AddPrinterToClass(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().AddPrinterToClass("office", "printer1").Return(nil)
	mockClient.EXPECT().GetPrinters(mock.Anything).Return(map[string]ipp.Attributes{}, nil)

	m := NewTestManager(mockClient, nil)
	assert.NoError(t, m.AddPrinterToClass("office", "printer1"))
}

func TestManager_RemovePrinterFromClass(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().DeletePrinterFromClass("office", "printer1").Return(nil)
	mockClient.EXPECT().GetPrinters(mock.Anything).Return(map[string]ipp.Attributes{}, nil)

	m := NewTestManager(mockClient, nil)
	assert.NoError(t, m.RemovePrinterFromClass("office", "printer1"))
}

func TestManager_DeleteClass(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().DeleteClass("office").Return(nil)
	mockClient.EXPECT().GetPrinters(mock.Anything).Return(map[string]ipp.Attributes{}, nil)

	m := NewTestManager(mockClient, nil)
	assert.NoError(t, m.DeleteClass("office"))
}

func TestManager_RestartJob(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().RestartJob(1).Return(nil)
	mockClient.EXPECT().GetPrinters(mock.Anything).Return(map[string]ipp.Attributes{}, nil)

	m := NewTestManager(mockClient, nil)
	assert.NoError(t, m.RestartJob(1))
}

func TestManager_HoldJob(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().HoldJobUntil(1, "indefinite").Return(nil)
	mockClient.EXPECT().GetPrinters(mock.Anything).Return(map[string]ipp.Attributes{}, nil)

	m := NewTestManager(mockClient, nil)
	assert.NoError(t, m.HoldJob(1, "indefinite"))
}
