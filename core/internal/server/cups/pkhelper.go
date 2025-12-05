package cups

import (
	"fmt"
	"strings"

	"github.com/godbus/dbus/v5"
)

const (
	pkHelperDest      = "org.opensuse.CupsPkHelper.Mechanism"
	pkHelperPath      = "/"
	pkHelperInterface = "org.opensuse.CupsPkHelper.Mechanism"
)

type PkHelper interface {
	DevicesGet(timeout, limit int, includeSchemes, excludeSchemes []string) ([]Device, error)
	PrinterAdd(name, uri, ppd, info, location string) error
	PrinterDelete(name string) error
	PrinterSetEnabled(name string, enabled bool) error
	PrinterSetAcceptJobs(name string, enabled bool, reason string) error
	PrinterSetInfo(name, info string) error
	PrinterSetLocation(name, location string) error
	PrinterSetShared(name string, shared bool) error
	ClassAddPrinter(className, printerName string) error
	ClassDeletePrinter(className, printerName string) error
	ClassDelete(className string) error
	JobCancelPurge(jobID int, purge bool) error
	JobRestart(jobID int) error
	JobSetHoldUntil(jobID int, holdUntil string) error
}

type DBusPkHelper struct {
	conn *dbus.Conn
	obj  dbus.BusObject
}

func NewPkHelper() (*DBusPkHelper, error) {
	conn, err := dbus.SystemBus()
	if err != nil {
		return nil, fmt.Errorf("failed to connect to system bus: %w", err)
	}

	return &DBusPkHelper{
		conn: conn,
		obj:  conn.Object(pkHelperDest, pkHelperPath),
	}, nil
}

func (p *DBusPkHelper) DevicesGet(timeout, limit int, includeSchemes, excludeSchemes []string) ([]Device, error) {
	if includeSchemes == nil {
		includeSchemes = []string{}
	}
	if excludeSchemes == nil {
		excludeSchemes = []string{}
	}

	var errStr string
	var devicesMap map[string]string

	call := p.obj.Call(pkHelperInterface+".DevicesGet", 0, int32(timeout), int32(limit), includeSchemes, excludeSchemes)
	if call.Err != nil {
		return nil, call.Err
	}
	if err := call.Store(&errStr, &devicesMap); err != nil {
		return nil, err
	}
	if errStr != "" {
		return nil, fmt.Errorf("%s", errStr)
	}

	return parseDevicesMap(devicesMap), nil
}

func parseDevicesMap(devicesMap map[string]string) []Device {
	devicesByIndex := make(map[string]*Device)

	for key, value := range devicesMap {
		idx := strings.LastIndex(key, ":")
		if idx == -1 {
			continue
		}

		attr := key[:idx]
		index := key[idx+1:]

		dev, ok := devicesByIndex[index]
		if !ok {
			dev = &Device{}
			devicesByIndex[index] = dev
		}

		switch attr {
		case "device-uri":
			dev.URI = value
		case "device-class":
			dev.Class = value
		case "device-info":
			dev.Info = value
		case "device-make-and-model":
			dev.MakeModel = value
		case "device-id":
			dev.ID = value
		case "device-location":
			dev.Location = value
		}
	}

	devices := make([]Device, 0, len(devicesByIndex))
	for _, dev := range devicesByIndex {
		if dev.URI != "" {
			devices = append(devices, *dev)
		}
	}
	return devices
}

func (p *DBusPkHelper) PrinterAdd(name, uri, ppd, info, location string) error {
	return p.callSimple("PrinterAdd", name, uri, ppd, info, location)
}

func (p *DBusPkHelper) PrinterDelete(name string) error {
	return p.callSimple("PrinterDelete", name)
}

func (p *DBusPkHelper) PrinterSetEnabled(name string, enabled bool) error {
	return p.callSimple("PrinterSetEnabled", name, enabled)
}

func (p *DBusPkHelper) PrinterSetAcceptJobs(name string, enabled bool, reason string) error {
	return p.callSimple("PrinterSetAcceptJobs", name, enabled, reason)
}

func (p *DBusPkHelper) PrinterSetInfo(name, info string) error {
	return p.callSimple("PrinterSetInfo", name, info)
}

func (p *DBusPkHelper) PrinterSetLocation(name, location string) error {
	return p.callSimple("PrinterSetLocation", name, location)
}

func (p *DBusPkHelper) PrinterSetShared(name string, shared bool) error {
	return p.callSimple("PrinterSetShared", name, shared)
}

func (p *DBusPkHelper) ClassAddPrinter(className, printerName string) error {
	return p.callSimple("ClassAddPrinter", className, printerName)
}

func (p *DBusPkHelper) ClassDeletePrinter(className, printerName string) error {
	return p.callSimple("ClassDeletePrinter", className, printerName)
}

func (p *DBusPkHelper) ClassDelete(className string) error {
	return p.callSimple("ClassDelete", className)
}

func (p *DBusPkHelper) JobCancelPurge(jobID int, purge bool) error {
	return p.callSimple("JobCancelPurge", int32(jobID), purge)
}

func (p *DBusPkHelper) JobRestart(jobID int) error {
	return p.callSimple("JobRestart", int32(jobID))
}

func (p *DBusPkHelper) JobSetHoldUntil(jobID int, holdUntil string) error {
	return p.callSimple("JobSetHoldUntil", int32(jobID), holdUntil)
}

func (p *DBusPkHelper) callSimple(method string, args ...any) error {
	var errStr string

	call := p.obj.Call(pkHelperInterface+"."+method, 0, args...)
	if call.Err != nil {
		return call.Err
	}
	if err := call.Store(&errStr); err != nil {
		return err
	}
	if errStr != "" {
		return fmt.Errorf("%s", errStr)
	}
	return nil
}
