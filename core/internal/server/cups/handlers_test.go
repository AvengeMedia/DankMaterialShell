package cups

import (
	"bytes"
	"encoding/json"
	"errors"
	"net"
	"testing"
	"time"

	mocks_cups "github.com/AvengeMedia/DankMaterialShell/core/internal/mocks/cups"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/DankMaterialShell/core/pkg/ipp"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

type mockConn struct {
	*bytes.Buffer
}

func (m *mockConn) Close() error                       { return nil }
func (m *mockConn) LocalAddr() net.Addr                { return nil }
func (m *mockConn) RemoteAddr() net.Addr               { return nil }
func (m *mockConn) SetDeadline(t time.Time) error      { return nil }
func (m *mockConn) SetReadDeadline(t time.Time) error  { return nil }
func (m *mockConn) SetWriteDeadline(t time.Time) error { return nil }

func TestHandleGetPrinters(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().GetPrinters(mock.Anything).Return(map[string]ipp.Attributes{
		"printer1": {
			ipp.AttributePrinterName:         []ipp.Attribute{{Value: "printer1"}},
			ipp.AttributePrinterState:        []ipp.Attribute{{Value: 3}},
			ipp.AttributePrinterUriSupported: []ipp.Attribute{{Value: "ipp://localhost/printers/printer1"}},
		},
	}, nil)

	m := &Manager{
		client: mockClient,
	}

	buf := &bytes.Buffer{}
	conn := &mockConn{Buffer: buf}

	req := Request{
		ID:     1,
		Method: "cups.getPrinters",
	}

	handleGetPrinters(conn, req, m)

	var resp models.Response[[]Printer]
	err := json.NewDecoder(buf).Decode(&resp)
	assert.NoError(t, err)
	assert.NotNil(t, resp.Result)
	assert.Equal(t, 1, len(*resp.Result))
}

func TestHandleGetPrinters_Error(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().GetPrinters(mock.Anything).Return(nil, errors.New("test error"))

	m := &Manager{
		client: mockClient,
	}

	buf := &bytes.Buffer{}
	conn := &mockConn{Buffer: buf}

	req := Request{
		ID:     1,
		Method: "cups.getPrinters",
	}

	handleGetPrinters(conn, req, m)

	var resp models.Response[any]
	err := json.NewDecoder(buf).Decode(&resp)
	assert.NoError(t, err)
	assert.Nil(t, resp.Result)
	assert.NotNil(t, resp.Error)
}

func TestHandleGetJobs(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().GetJobs("printer1", "", "not-completed", false, 0, 0, mock.Anything).
		Return(map[int]ipp.Attributes{
			1: {
				ipp.AttributeJobID:    []ipp.Attribute{{Value: 1}},
				ipp.AttributeJobName:  []ipp.Attribute{{Value: "job1"}},
				ipp.AttributeJobState: []ipp.Attribute{{Value: 5}},
			},
		}, nil)

	m := &Manager{
		client: mockClient,
	}

	buf := &bytes.Buffer{}
	conn := &mockConn{Buffer: buf}

	req := Request{
		ID:     1,
		Method: "cups.getJobs",
		Params: map[string]any{
			"printerName": "printer1",
		},
	}

	handleGetJobs(conn, req, m)

	var resp models.Response[[]Job]
	err := json.NewDecoder(buf).Decode(&resp)
	assert.NoError(t, err)
	assert.NotNil(t, resp.Result)
	assert.Equal(t, 1, len(*resp.Result))
}

func TestHandleGetJobs_MissingParam(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)

	m := &Manager{
		client: mockClient,
	}

	buf := &bytes.Buffer{}
	conn := &mockConn{Buffer: buf}

	req := Request{
		ID:     1,
		Method: "cups.getJobs",
		Params: map[string]any{},
	}

	handleGetJobs(conn, req, m)

	var resp models.Response[any]
	err := json.NewDecoder(buf).Decode(&resp)
	assert.NoError(t, err)
	assert.Nil(t, resp.Result)
	assert.NotNil(t, resp.Error)
}

func TestHandlePausePrinter(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().PausePrinter("printer1").Return(nil)

	m := &Manager{
		client: mockClient,
	}

	buf := &bytes.Buffer{}
	conn := &mockConn{Buffer: buf}

	req := Request{
		ID:     1,
		Method: "cups.pausePrinter",
		Params: map[string]any{
			"printerName": "printer1",
		},
	}

	handlePausePrinter(conn, req, m)

	var resp models.Response[SuccessResult]
	err := json.NewDecoder(buf).Decode(&resp)
	assert.NoError(t, err)
	assert.NotNil(t, resp.Result)
	assert.True(t, resp.Result.Success)
}

func TestHandleResumePrinter(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().ResumePrinter("printer1").Return(nil)

	m := &Manager{
		client: mockClient,
	}

	buf := &bytes.Buffer{}
	conn := &mockConn{Buffer: buf}

	req := Request{
		ID:     1,
		Method: "cups.resumePrinter",
		Params: map[string]any{
			"printerName": "printer1",
		},
	}

	handleResumePrinter(conn, req, m)

	var resp models.Response[SuccessResult]
	err := json.NewDecoder(buf).Decode(&resp)
	assert.NoError(t, err)
	assert.NotNil(t, resp.Result)
	assert.True(t, resp.Result.Success)
}

func TestHandleCancelJob(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().CancelJob(1, false).Return(nil)

	m := &Manager{
		client: mockClient,
	}

	buf := &bytes.Buffer{}
	conn := &mockConn{Buffer: buf}

	req := Request{
		ID:     1,
		Method: "cups.cancelJob",
		Params: map[string]any{
			"jobID": float64(1),
		},
	}

	handleCancelJob(conn, req, m)

	var resp models.Response[SuccessResult]
	err := json.NewDecoder(buf).Decode(&resp)
	assert.NoError(t, err)
	assert.NotNil(t, resp.Result)
	assert.True(t, resp.Result.Success)
}

func TestHandlePurgeJobs(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)
	mockClient.EXPECT().CancelAllJob("printer1", true).Return(nil)

	m := &Manager{
		client: mockClient,
	}

	buf := &bytes.Buffer{}
	conn := &mockConn{Buffer: buf}

	req := Request{
		ID:     1,
		Method: "cups.purgeJobs",
		Params: map[string]any{
			"printerName": "printer1",
		},
	}

	handlePurgeJobs(conn, req, m)

	var resp models.Response[SuccessResult]
	err := json.NewDecoder(buf).Decode(&resp)
	assert.NoError(t, err)
	assert.NotNil(t, resp.Result)
	assert.True(t, resp.Result.Success)
}

func TestHandleRequest_UnknownMethod(t *testing.T) {
	mockClient := mocks_cups.NewMockCUPSClientInterface(t)

	m := &Manager{
		client: mockClient,
	}

	buf := &bytes.Buffer{}
	conn := &mockConn{Buffer: buf}

	req := Request{
		ID:     1,
		Method: "cups.unknownMethod",
	}

	HandleRequest(conn, req, m)

	var resp models.Response[any]
	err := json.NewDecoder(buf).Decode(&resp)
	assert.NoError(t, err)
	assert.Nil(t, resp.Result)
	assert.NotNil(t, resp.Error)
}
