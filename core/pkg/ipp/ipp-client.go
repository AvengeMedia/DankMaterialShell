package ipp

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path"
)

// Document wraps an io.Reader with more information, needed for encoding
type Document struct {
	Document io.Reader
	Size     int
	Name     string
	MimeType string
}

// IPPClient implements a generic ipp client
type IPPClient struct {
	username string
	adapter  Adapter
}

// NewIPPClient creates a new generic ipp client (used HttpAdapter internally)
func NewIPPClient(host string, port int, username, password string, useTLS bool) *IPPClient {
	adapter := NewHttpAdapter(host, port, username, password, useTLS)

	return &IPPClient{
		username: username,
		adapter:  adapter,
	}
}

// NewIPPClientWithAdapter creates a new generic ipp client with given Adapter
func NewIPPClientWithAdapter(username string, adapter Adapter) *IPPClient {
	return &IPPClient{
		username: username,
		adapter:  adapter,
	}
}

func (c *IPPClient) getPrinterUri(printer string) string {
	return fmt.Sprintf("ipp://localhost/printers/%s", printer)
}

func (c *IPPClient) getJobUri(jobID int) string {
	return fmt.Sprintf("ipp://localhost/jobs/%d", jobID)
}

func (c *IPPClient) getClassUri(printer string) string {
	return fmt.Sprintf("ipp://localhost/classes/%s", printer)
}

// SendRequest sends a request to a remote uri end returns the response
func (c *IPPClient) SendRequest(url string, req *Request, additionalResponseData io.Writer) (*Response, error) {
	if _, ok := req.OperationAttributes[AttributeRequestingUserName]; !ok {
		req.OperationAttributes[AttributeRequestingUserName] = c.username
	}

	return c.adapter.SendRequest(url, req, additionalResponseData)
}

// PrintDocuments prints one or more documents using a Create-Job operation followed by one or more Send-Document operation(s). custom job settings can be specified via the jobAttributes parameter
func (c *IPPClient) PrintDocuments(docs []Document, printer string, jobAttributes map[string]any) (int, error) {
	printerURI := c.getPrinterUri(printer)

	req := NewRequest(OperationCreateJob, 1)
	req.OperationAttributes[AttributePrinterURI] = printerURI
	req.OperationAttributes[AttributeRequestingUserName] = c.username

	// set defaults for some attributes, may get overwritten
	req.OperationAttributes[AttributeJobName] = docs[0].Name
	req.OperationAttributes[AttributeCopies] = 1
	req.OperationAttributes[AttributeJobPriority] = DefaultJobPriority

	for key, value := range jobAttributes {
		req.JobAttributes[key] = value
	}

	resp, err := c.SendRequest(c.adapter.GetHttpUri("printers", printer), req, nil)
	if err != nil {
		return -1, err
	}

	if len(resp.JobAttributes) == 0 {
		return 0, errors.New("server doesn't returned a job id")
	}

	jobID := resp.JobAttributes[0][AttributeJobID][0].Value.(int)

	documentCount := len(docs) - 1

	for docID, doc := range docs {
		req = NewRequest(OperationSendDocument, 2)
		req.OperationAttributes[AttributePrinterURI] = printerURI
		req.OperationAttributes[AttributeRequestingUserName] = c.username
		req.OperationAttributes[AttributeJobID] = jobID
		req.OperationAttributes[AttributeDocumentName] = doc.Name
		req.OperationAttributes[AttributeDocumentFormat] = doc.MimeType
		req.OperationAttributes[AttributeLastDocument] = docID == documentCount
		req.File = doc.Document
		req.FileSize = doc.Size

		_, err = c.SendRequest(c.adapter.GetHttpUri("printers", printer), req, nil)
		if err != nil {
			return -1, err
		}
	}

	return jobID, nil
}

// PrintJob prints a document using a Print-Job operation. custom job settings can be specified via the jobAttributes parameter
func (c *IPPClient) PrintJob(doc Document, printer string, jobAttributes map[string]any) (int, error) {
	printerURI := c.getPrinterUri(printer)

	req := NewRequest(OperationPrintJob, 1)
	req.OperationAttributes[AttributePrinterURI] = printerURI
	req.OperationAttributes[AttributeRequestingUserName] = c.username
	req.OperationAttributes[AttributeJobName] = doc.Name
	req.OperationAttributes[AttributeDocumentFormat] = doc.MimeType

	// set defaults for some attributes, may get overwritten
	req.OperationAttributes[AttributeCopies] = 1
	req.OperationAttributes[AttributeJobPriority] = DefaultJobPriority

	for key, value := range jobAttributes {
		req.JobAttributes[key] = value
	}

	req.File = doc.Document
	req.FileSize = doc.Size

	resp, err := c.SendRequest(c.adapter.GetHttpUri("printers", printer), req, nil)
	if err != nil {
		return -1, err
	}

	if len(resp.JobAttributes) == 0 {
		return 0, errors.New("server doesn't returned a job id")
	}

	jobID := resp.JobAttributes[0][AttributeJobID][0].Value.(int)

	return jobID, nil
}

// PrintFile prints a local file on the file system. custom job settings can be specified via the jobAttributes parameter
func (c *IPPClient) PrintFile(filePath, printer string, jobAttributes map[string]any) (int, error) {
	fileStats, err := os.Stat(filePath)
	if os.IsNotExist(err) {
		return -1, err
	}

	fileName := path.Base(filePath)

	document, err := os.Open(filePath)
	if err != nil {
		return 0, err
	}
	defer document.Close()

	jobAttributes[AttributeJobName] = fileName

	return c.PrintDocuments([]Document{
		{
			Document: document,
			Name:     fileName,
			Size:     int(fileStats.Size()),
			MimeType: MimeTypeOctetStream,
		},
	}, printer, jobAttributes)
}

// GetPrinterAttributes returns the requested attributes for the specified printer, if attributes is nil the default attributes will be used
func (c *IPPClient) GetPrinterAttributes(printer string, attributes []string) (Attributes, error) {
	req := NewRequest(OperationGetPrinterAttributes, 1)
	req.OperationAttributes[AttributePrinterURI] = c.getPrinterUri(printer)
	req.OperationAttributes[AttributeRequestingUserName] = c.username

	if attributes == nil {
		req.OperationAttributes[AttributeRequestedAttributes] = DefaultPrinterAttributes
	} else {
		req.OperationAttributes[AttributeRequestedAttributes] = attributes
	}

	resp, err := c.SendRequest(c.adapter.GetHttpUri("printers", printer), req, nil)
	if err != nil {
		return nil, err
	}

	if len(resp.PrinterAttributes) == 0 {
		return nil, errors.New("server doesn't return any printer attributes")
	}

	return resp.PrinterAttributes[0], nil
}

// ResumePrinter resumes a printer
func (c *IPPClient) ResumePrinter(printer string) error {
	req := NewRequest(OperationResumePrinter, 1)
	req.OperationAttributes[AttributePrinterURI] = c.getPrinterUri(printer)

	_, err := c.SendRequest(c.adapter.GetHttpUri("admin", ""), req, nil)
	return err
}

// PausePrinter pauses a printer
func (c *IPPClient) PausePrinter(printer string) error {
	req := NewRequest(OperationPausePrinter, 1)
	req.OperationAttributes[AttributePrinterURI] = c.getPrinterUri(printer)

	_, err := c.SendRequest(c.adapter.GetHttpUri("admin", ""), req, nil)
	return err
}

// GetJobAttributes returns the requested attributes for the specified job, if attributes is nil the default job will be used
func (c *IPPClient) GetJobAttributes(jobID int, attributes []string) (Attributes, error) {
	req := NewRequest(OperationGetJobAttributes, 1)
	req.OperationAttributes[AttributeJobURI] = c.getJobUri(jobID)

	if attributes == nil {
		req.OperationAttributes[AttributeRequestedAttributes] = DefaultJobAttributes
	} else {
		req.OperationAttributes[AttributeRequestedAttributes] = attributes
	}

	resp, err := c.SendRequest(c.adapter.GetHttpUri("jobs", jobID), req, nil)
	if err != nil {
		return nil, err
	}

	if len(resp.JobAttributes) == 0 {
		return nil, errors.New("server doesn't return any job attributes")
	}

	return resp.JobAttributes[0], nil
}

// GetJobs returns jobs from a printer or class
func (c *IPPClient) GetJobs(printer, class string, whichJobs string, myJobs bool, firstJobId, limit int, attributes []string) (map[int]Attributes, error) {
	req := NewRequest(OperationGetJobs, 1)
	req.OperationAttributes[AttributeWhichJobs] = whichJobs
	req.OperationAttributes[AttributeMyJobs] = myJobs

	if printer != "" {
		req.OperationAttributes[AttributePrinterURI] = c.getPrinterUri(printer)
	} else if class != "" {
		req.OperationAttributes[AttributePrinterURI] = c.getClassUri(printer)
	} else {
		req.OperationAttributes[AttributePrinterURI] = "ipp://localhost/"
	}

	if firstJobId > 0 {
		req.OperationAttributes[AttributeFirstJobID] = firstJobId
	}

	if limit > 0 {
		req.OperationAttributes[AttributeLimit] = limit
	}

	if myJobs {
		req.OperationAttributes[AttributeRequestingUserName] = c.username
	}

	if attributes == nil {
		req.OperationAttributes[AttributeRequestedAttributes] = DefaultJobAttributes
	} else {
		req.OperationAttributes[AttributeRequestedAttributes] = append(attributes, AttributeJobID)
	}

	resp, err := c.SendRequest(c.adapter.GetHttpUri("", nil), req, nil)
	if err != nil {
		return nil, err
	}

	jobIDMap := make(map[int]Attributes)

	for _, jobAttributes := range resp.JobAttributes {
		jobIDMap[jobAttributes[AttributeJobID][0].Value.(int)] = jobAttributes
	}

	return jobIDMap, nil
}

// CancelJob cancels a job. if purge is true, the job will also be removed
func (c *IPPClient) CancelJob(jobID int, purge bool) error {
	req := NewRequest(OperationCancelJob, 1)
	req.OperationAttributes[AttributeJobURI] = c.getJobUri(jobID)
	req.OperationAttributes[AttributePurgeJobs] = purge

	_, err := c.SendRequest(c.adapter.GetHttpUri("jobs", ""), req, nil)
	return err
}

// CancelAllJob cancels all jobs for a specified printer. if purge is true, the jobs will also be removed
func (c *IPPClient) CancelAllJob(printer string, purge bool) error {
	req := NewRequest(OperationCancelJobs, 1)
	req.OperationAttributes[AttributePrinterURI] = c.getPrinterUri(printer)
	req.OperationAttributes[AttributePurgeJobs] = purge

	_, err := c.SendRequest(c.adapter.GetHttpUri("admin", ""), req, nil)
	return err
}

// RestartJob restarts a job
func (c *IPPClient) RestartJob(jobID int) error {
	req := NewRequest(OperationRestartJob, 1)
	req.OperationAttributes[AttributeJobURI] = c.getJobUri(jobID)

	_, err := c.SendRequest(c.adapter.GetHttpUri("jobs", ""), req, nil)
	return err
}

// HoldJobUntil holds a job
func (c *IPPClient) HoldJobUntil(jobID int, holdUntil string) error {
	req := NewRequest(OperationRestartJob, 1)
	req.OperationAttributes[AttributeJobURI] = c.getJobUri(jobID)
	req.JobAttributes[AttributeHoldJobUntil] = holdUntil

	_, err := c.SendRequest(c.adapter.GetHttpUri("jobs", ""), req, nil)
	return err
}

// TestConnection tests if a tcp connection to the remote server is possible
func (c *IPPClient) TestConnection() error {
	return c.adapter.TestConnection()
}
