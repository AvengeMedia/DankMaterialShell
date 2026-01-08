package ipp

import (
	"io"
	"strings"
)

// CUPSClient implements a ipp client with specific cups operations
type CUPSClient struct {
	*IPPClient
}

// NewCUPSClient creates a new cups ipp client (used HttpAdapter internally)
func NewCUPSClient(host string, port int, username, password string, useTLS bool) *CUPSClient {
	ippClient := NewIPPClient(host, port, username, password, useTLS)
	return &CUPSClient{ippClient}
}

// NewCUPSClientWithAdapter creates a new cups ipp client with given Adapter
func NewCUPSClientWithAdapter(username string, adapter Adapter) *CUPSClient {
	ippClient := NewIPPClientWithAdapter(username, adapter)
	return &CUPSClient{ippClient}
}

// GetDevices returns a map of device uris and printer attributes
func (c *CUPSClient) GetDevices() (map[string]Attributes, error) {
	req := NewRequest(OperationCupsGetDevices, 1)

	resp, err := c.SendRequest(c.adapter.GetHttpUri("", nil), req, nil)
	if err != nil {
		return nil, err
	}

	printerNameMap := make(map[string]Attributes)

	for _, printerAttributes := range resp.PrinterAttributes {
		printerNameMap[printerAttributes[AttributeDeviceURI][0].Value.(string)] = printerAttributes
	}

	return printerNameMap, nil
}

// MoveJob moves a job to a other printer
func (c *CUPSClient) MoveJob(jobID int, destPrinter string) error {
	req := NewRequest(OperationCupsMoveJob, 1)
	req.OperationAttributes[AttributeJobURI] = c.getJobUri(jobID)
	req.PrinterAttributes[AttributeJobPrinterURI] = c.getPrinterUri(destPrinter)

	_, err := c.SendRequest(c.adapter.GetHttpUri("jobs", ""), req, nil)
	return err
}

// MoveAllJob moves all job from a printer to a other printer
func (c *CUPSClient) MoveAllJob(srcPrinter, destPrinter string) error {
	req := NewRequest(OperationCupsMoveJob, 1)
	req.OperationAttributes[AttributePrinterURI] = c.getPrinterUri(srcPrinter)
	req.PrinterAttributes[AttributeJobPrinterURI] = c.getPrinterUri(destPrinter)

	_, err := c.SendRequest(c.adapter.GetHttpUri("jobs", ""), req, nil)
	return err
}

// GetPPDs returns a map of ppd names and attributes
func (c *CUPSClient) GetPPDs() (map[string]Attributes, error) {
	req := NewRequest(OperationCupsGetPPDs, 1)

	resp, err := c.SendRequest(c.adapter.GetHttpUri("", nil), req, nil)
	if err != nil {
		return nil, err
	}

	ppdNameMap := make(map[string]Attributes)

	for _, printerAttributes := range resp.PrinterAttributes {
		ppdNameMap[printerAttributes[AttributePPDName][0].Value.(string)] = printerAttributes
	}

	return ppdNameMap, nil
}

// AcceptJobs lets a printer accept jobs again
func (c *CUPSClient) AcceptJobs(printer string) error {
	req := NewRequest(OperationCupsAcceptJobs, 1)
	req.OperationAttributes[AttributePrinterURI] = c.getPrinterUri(printer)

	_, err := c.SendRequest(c.adapter.GetHttpUri("admin", ""), req, nil)
	return err
}

// RejectJobs does not let a printer accept jobs
func (c *CUPSClient) RejectJobs(printer string) error {
	req := NewRequest(OperationCupsRejectJobs, 1)
	req.OperationAttributes[AttributePrinterURI] = c.getPrinterUri(printer)

	_, err := c.SendRequest(c.adapter.GetHttpUri("admin", ""), req, nil)
	return err
}

// AddPrinterToClass adds a printer to a class, if the class does not exists it will be created
func (c *CUPSClient) AddPrinterToClass(class, printer string) error {
	attributes, err := c.GetPrinterAttributes(class, []string{AttributeMemberURIs})
	if err != nil && !IsNotExistsError(err) {
		return err
	}

	memberURIList := make([]string, 0)

	if !IsNotExistsError(err) {
		for _, member := range attributes[AttributeMemberURIs] {
			memberString := strings.Split(member.Value.(string), "/")
			printerName := memberString[len(memberString)-1]

			if printerName == printer {
				return nil
			}

			memberURIList = append(memberURIList, member.Value.(string))
		}
	}

	memberURIList = append(memberURIList, c.getPrinterUri(printer))

	req := NewRequest(OperationCupsAddModifyClass, 1)
	req.OperationAttributes[AttributePrinterURI] = c.getClassUri(class)
	req.PrinterAttributes[AttributeMemberURIs] = memberURIList

	_, err = c.SendRequest(c.adapter.GetHttpUri("admin", ""), req, nil)
	return err
}

// DeletePrinterFromClass removes a printer from a class, if a class has no more printer it will be deleted
func (c *CUPSClient) DeletePrinterFromClass(class, printer string) error {
	attributes, err := c.GetPrinterAttributes(class, []string{AttributeMemberURIs})
	if err != nil {
		return err
	}

	memberURIList := make([]string, 0)

	for _, member := range attributes[AttributeMemberURIs] {
		memberString := strings.Split(member.Value.(string), "/")
		printerName := memberString[len(memberString)-1]

		if printerName != printer {
			memberURIList = append(memberURIList, member.Value.(string))
		}
	}

	if len(memberURIList) == 0 {
		return c.DeleteClass(class)
	}

	req := NewRequest(OperationCupsAddModifyClass, 1)
	req.OperationAttributes[AttributePrinterURI] = c.getClassUri(class)
	req.PrinterAttributes[AttributeMemberURIs] = memberURIList

	_, err = c.SendRequest(c.adapter.GetHttpUri("admin", ""), req, nil)
	return err
}

// DeleteClass deletes a class
func (c *CUPSClient) DeleteClass(class string) error {
	req := NewRequest(OperationCupsDeleteClass, 1)
	req.OperationAttributes[AttributePrinterURI] = c.getClassUri(class)

	_, err := c.SendRequest(c.adapter.GetHttpUri("admin", ""), req, nil)
	return err
}

// CreatePrinter creates a new printer
func (c *CUPSClient) CreatePrinter(name, deviceURI, ppd string, shared bool, errorPolicy string, information, location string) error {
	req := NewRequest(OperationCupsAddModifyPrinter, 1)
	req.OperationAttributes[AttributePrinterURI] = c.getPrinterUri(name)
	req.OperationAttributes[AttributePPDName] = ppd
	req.OperationAttributes[AttributePrinterIsShared] = shared
	req.PrinterAttributes[AttributePrinterStateReasons] = "none"
	req.PrinterAttributes[AttributeDeviceURI] = deviceURI
	req.PrinterAttributes[AttributePrinterInfo] = information
	req.PrinterAttributes[AttributePrinterLocation] = location
	req.PrinterAttributes[AttributePrinterErrorPolicy] = errorPolicy

	_, err := c.SendRequest(c.adapter.GetHttpUri("admin", ""), req, nil)
	return err
}

// SetPrinterPPD sets the ppd for a printer
func (c *CUPSClient) SetPrinterPPD(printer, ppd string) error {
	req := NewRequest(OperationCupsAddModifyPrinter, 1)
	req.OperationAttributes[AttributePrinterURI] = c.getPrinterUri(printer)
	req.OperationAttributes[AttributePPDName] = ppd

	_, err := c.SendRequest(c.adapter.GetHttpUri("admin", ""), req, nil)
	return err
}

// SetPrinterDeviceURI sets the device uri for a printer
func (c *CUPSClient) SetPrinterDeviceURI(printer, deviceURI string) error {
	req := NewRequest(OperationCupsAddModifyPrinter, 1)
	req.OperationAttributes[AttributePrinterURI] = c.getPrinterUri(printer)
	req.PrinterAttributes[AttributeDeviceURI] = deviceURI

	_, err := c.SendRequest(c.adapter.GetHttpUri("admin", ""), req, nil)
	return err
}

// SetPrinterIsShared shares or unshares a printer in the network
func (c *CUPSClient) SetPrinterIsShared(printer string, shared bool) error {
	req := NewRequest(OperationCupsAddModifyPrinter, 1)
	req.OperationAttributes[AttributePrinterURI] = c.getPrinterUri(printer)
	req.OperationAttributes[AttributePrinterIsShared] = shared

	_, err := c.SendRequest(c.adapter.GetHttpUri("admin", ""), req, nil)
	return err
}

// SetPrinterErrorPolicy sets the error policy for a printer
func (c *CUPSClient) SetPrinterErrorPolicy(printer string, errorPolicy string) error {
	req := NewRequest(OperationCupsAddModifyPrinter, 1)
	req.OperationAttributes[AttributePrinterURI] = c.getPrinterUri(printer)
	req.PrinterAttributes[AttributePrinterErrorPolicy] = errorPolicy

	_, err := c.SendRequest(c.adapter.GetHttpUri("admin", ""), req, nil)
	return err
}

// SetPrinterInformation sets general printer information
func (c *CUPSClient) SetPrinterInformation(printer, information string) error {
	req := NewRequest(OperationCupsAddModifyPrinter, 1)
	req.OperationAttributes[AttributePrinterURI] = c.getPrinterUri(printer)
	req.PrinterAttributes[AttributePrinterInfo] = information

	_, err := c.SendRequest(c.adapter.GetHttpUri("admin", ""), req, nil)
	return err
}

// SetPrinterLocation sets the printer location
func (c *CUPSClient) SetPrinterLocation(printer, location string) error {
	req := NewRequest(OperationCupsAddModifyPrinter, 1)
	req.OperationAttributes[AttributePrinterURI] = c.getPrinterUri(printer)
	req.PrinterAttributes[AttributePrinterLocation] = location

	_, err := c.SendRequest(c.adapter.GetHttpUri("admin", ""), req, nil)
	return err
}

// DeletePrinter deletes a printer
func (c *CUPSClient) DeletePrinter(printer string) error {
	req := NewRequest(OperationCupsDeletePrinter, 1)
	req.OperationAttributes[AttributePrinterURI] = c.getPrinterUri(printer)

	_, err := c.SendRequest(c.adapter.GetHttpUri("admin", ""), req, nil)
	return err
}

// GetPrinters returns a map of printer names and attributes
func (c *CUPSClient) GetPrinters(attributes []string) (map[string]Attributes, error) {
	req := NewRequest(OperationCupsGetPrinters, 1)

	if attributes == nil {
		req.OperationAttributes[AttributeRequestedAttributes] = DefaultPrinterAttributes
	} else {
		req.OperationAttributes[AttributeRequestedAttributes] = append(attributes, AttributePrinterName)
	}

	resp, err := c.SendRequest(c.adapter.GetHttpUri("", nil), req, nil)
	if err != nil {
		return nil, err
	}

	printerNameMap := make(map[string]Attributes)

	for _, printerAttributes := range resp.PrinterAttributes {
		printerNameMap[printerAttributes[AttributePrinterName][0].Value.(string)] = printerAttributes
	}

	return printerNameMap, nil
}

// GetClasses returns a map of class names and attributes
func (c *CUPSClient) GetClasses(attributes []string) (map[string]Attributes, error) {
	req := NewRequest(OperationCupsGetClasses, 1)

	if attributes == nil {
		req.OperationAttributes[AttributeRequestedAttributes] = DefaultClassAttributes
	} else {
		req.OperationAttributes[AttributeRequestedAttributes] = append(attributes, AttributePrinterName)
	}

	resp, err := c.SendRequest(c.adapter.GetHttpUri("", nil), req, nil)
	if err != nil {
		return nil, err
	}

	printerNameMap := make(map[string]Attributes)

	for _, printerAttributes := range resp.PrinterAttributes {
		printerNameMap[printerAttributes[AttributePrinterName][0].Value.(string)] = printerAttributes
	}

	return printerNameMap, nil
}

// PrintTestPage prints a test page using the provided PDF data
func (c *CUPSClient) PrintTestPage(printer string, testPageData io.Reader, size int) (int, error) {
	return c.PrintJob(Document{
		Document: testPageData,
		Name:     "Test Page",
		Size:     size,
		MimeType: MimeTypePDF,
	}, printer, map[string]any{
		AttributeJobName: "Test Page",
	})
}
