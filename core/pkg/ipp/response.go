package ipp

import (
	"bytes"
	"encoding/binary"
	"io"
)

// Attributes is a wrapper for a set of attributes
type Attributes map[string][]Attribute

// Response defines a ipp response
type Response struct {
	ProtocolVersionMajor int8
	ProtocolVersionMinor int8

	StatusCode int16
	RequestId  int32

	OperationAttributes    Attributes
	PrinterAttributes      []Attributes
	JobAttributes          []Attributes
	SubscriptionAttributes []Attributes // Added for subscription responses
}

// CheckForErrors checks the status code and returns a error if it is not zero. it also returns the status message if provided by the server
func (r *Response) CheckForErrors() error {
	if r.StatusCode != StatusOk {
		err := IPPError{
			Status:  r.StatusCode,
			Message: "no status message returned",
		}

		if len(r.OperationAttributes["status-message"]) > 0 {
			err.Message = r.OperationAttributes["status-message"][0].Value.(string)
		}

		return err
	}

	return nil
}

// NewResponse creates a new ipp response
func NewResponse(statusCode int16, reqID int32) *Response {
	return &Response{
		ProtocolVersionMajor: ProtocolVersionMajor,
		ProtocolVersionMinor: ProtocolVersionMinor,
		StatusCode:           statusCode,
		RequestId:            reqID,
		OperationAttributes:  make(Attributes),
		PrinterAttributes:    make([]Attributes, 0),
		JobAttributes:        make([]Attributes, 0),
	}
}

// Encode encodes the response to a byte slice
func (r *Response) Encode() ([]byte, error) {
	buf := new(bytes.Buffer)
	enc := NewAttributeEncoder(buf)

	if err := binary.Write(buf, binary.BigEndian, r.ProtocolVersionMajor); err != nil {
		return nil, err
	}

	if err := binary.Write(buf, binary.BigEndian, r.ProtocolVersionMinor); err != nil {
		return nil, err
	}

	if err := binary.Write(buf, binary.BigEndian, r.StatusCode); err != nil {
		return nil, err
	}

	if err := binary.Write(buf, binary.BigEndian, r.RequestId); err != nil {
		return nil, err
	}

	if err := binary.Write(buf, binary.BigEndian, TagOperation); err != nil {
		return nil, err
	}

	if r.OperationAttributes == nil {
		r.OperationAttributes = make(Attributes, 0)
	}

	if _, found := r.OperationAttributes[AttributeCharset]; !found {
		r.OperationAttributes[AttributeCharset] = []Attribute{
			{
				Value: Charset,
			},
		}
	}

	if _, found := r.OperationAttributes[AttributeNaturalLanguage]; !found {
		r.OperationAttributes[AttributeNaturalLanguage] = []Attribute{
			{
				Value: CharsetLanguage,
			},
		}
	}

	if err := r.encodeOperationAttributes(enc); err != nil {
		return nil, err
	}

	if len(r.PrinterAttributes) > 0 {
		for _, printerAttr := range r.PrinterAttributes {
			if err := binary.Write(buf, binary.BigEndian, TagPrinter); err != nil {
				return nil, err
			}

			for name, attr := range printerAttr {
				if len(attr) == 0 {
					continue
				}

				values := make([]any, len(attr))
				for i, v := range attr {
					values[i] = v.Value
				}

				if len(values) == 1 {
					if err := enc.Encode(name, values[0]); err != nil {
						return nil, err
					}
				} else {
					if err := enc.Encode(name, values); err != nil {
						return nil, err
					}
				}
			}
		}
	}

	if len(r.JobAttributes) > 0 {
		for _, jobAttr := range r.JobAttributes {
			if err := binary.Write(buf, binary.BigEndian, TagJob); err != nil {
				return nil, err
			}

			for name, attr := range jobAttr {
				if len(attr) == 0 {
					continue
				}

				values := make([]any, len(attr))
				for i, v := range attr {
					values[i] = v.Value
				}

				if len(values) == 1 {
					if err := enc.Encode(name, values[0]); err != nil {
						return nil, err
					}
				} else {
					if err := enc.Encode(name, values); err != nil {
						return nil, err
					}
				}
			}
		}
	}

	if err := binary.Write(buf, binary.BigEndian, TagEnd); err != nil {
		return nil, err
	}

	return buf.Bytes(), nil
}

func (r *Response) encodeOperationAttributes(enc *AttributeEncoder) error {
	ordered := []string{
		AttributeCharset,
		AttributeNaturalLanguage,
		AttributePrinterURI,
		AttributeJobID,
	}

	for _, name := range ordered {
		if attr, ok := r.OperationAttributes[name]; ok {
			delete(r.OperationAttributes, name)
			if err := encodeOperationAttribute(enc, name, attr); err != nil {
				return err
			}
		}
	}

	for name, attr := range r.OperationAttributes {
		if err := encodeOperationAttribute(enc, name, attr); err != nil {
			return err
		}
	}

	return nil
}

func encodeOperationAttribute(enc *AttributeEncoder, name string, attr []Attribute) error {
	if len(attr) == 0 {
		return nil
	}

	values := make([]any, len(attr))
	for i, v := range attr {
		values[i] = v.Value
	}

	if len(values) == 1 {
		return enc.Encode(name, values[0])
	}

	return enc.Encode(name, values)
}

// ResponseDecoder reads and decodes a response from a stream
type ResponseDecoder struct {
	reader io.Reader
}

// NewResponseDecoder returns a new decoder that reads from r
func NewResponseDecoder(r io.Reader) *ResponseDecoder {
	return &ResponseDecoder{
		reader: r,
	}
}

// Decode decodes a ipp response into a response struct. additional data will be written to an io.Writer if data is not nil
func (d *ResponseDecoder) Decode(data io.Writer) (*Response, error) {
	/*
	   1 byte: Protocol Major Version - b
	   1 byte: Protocol Minor Version - b
	   2 byte: Status ID - h
	   4 byte: Request ID - i
	   1 byte: Operation Attribute Byte (\0x01)
	   N times: Attributes
	   1 byte: Attribute End Byte (\0x03)
	*/

	resp := new(Response)

	// wrap the reader so we have more functionality
	// reader := bufio.NewReader(d.reader)

	if err := binary.Read(d.reader, binary.BigEndian, &resp.ProtocolVersionMajor); err != nil {
		return nil, err
	}

	if err := binary.Read(d.reader, binary.BigEndian, &resp.ProtocolVersionMinor); err != nil {
		return nil, err
	}

	if err := binary.Read(d.reader, binary.BigEndian, &resp.StatusCode); err != nil {
		return nil, err
	}

	if err := binary.Read(d.reader, binary.BigEndian, &resp.RequestId); err != nil {
		return nil, err
	}

	startByteSlice := make([]byte, 1)

	tag := TagCupsInvalid
	previousAttributeName := ""
	tempAttributes := make(Attributes)
	tagSet := false

	attribDecoder := NewAttributeDecoder(d.reader)

	// decode attribute buffer
	for {
		if _, err := d.reader.Read(startByteSlice); err != nil {
			// when we read from a stream, we may get an EOF if we want to read the end tag
			// all data should be read and we can ignore the error
			if err == io.EOF {
				break
			}
			return nil, err
		}

		startByte := int8(startByteSlice[0])

		// check if attributes are completed
		if startByte == TagEnd {
			break
		}

		if startByte == TagOperation {
			if len(tempAttributes) > 0 && tag != TagCupsInvalid {
				appendAttributeToResponse(resp, tag, tempAttributes)
				tempAttributes = make(Attributes)
			}

			tag = TagOperation
			tagSet = true
		}

		if startByte == TagJob {
			if len(tempAttributes) > 0 && tag != TagCupsInvalid {
				appendAttributeToResponse(resp, tag, tempAttributes)
				tempAttributes = make(Attributes)
			}

			tag = TagJob
			tagSet = true
		}

		if startByte == TagPrinter {
			if len(tempAttributes) > 0 && tag != TagCupsInvalid {
				appendAttributeToResponse(resp, tag, tempAttributes)
				tempAttributes = make(Attributes)
			}

			tag = TagPrinter
			tagSet = true
		}

		if startByte == TagSubscription {
			if len(tempAttributes) > 0 && tag != TagCupsInvalid {
				appendAttributeToResponse(resp, tag, tempAttributes)
				tempAttributes = make(Attributes)
			}

			tag = TagSubscription
			tagSet = true
		}

		if startByte == TagEventNotification {
			if len(tempAttributes) > 0 && tag != TagCupsInvalid {
				appendAttributeToResponse(resp, tag, tempAttributes)
				tempAttributes = make(Attributes)
			}

			tag = TagEventNotification
			tagSet = true
		}

		if tagSet {
			if _, err := d.reader.Read(startByteSlice); err != nil {
				return nil, err
			}
			startByte = int8(startByteSlice[0])
		}

		attrib, err := attribDecoder.Decode(startByte)
		if err != nil {
			return nil, err
		}

		if attrib.Name != "" {
			tempAttributes[attrib.Name] = append(tempAttributes[attrib.Name], *attrib)
			previousAttributeName = attrib.Name
		} else {
			tempAttributes[previousAttributeName] = append(tempAttributes[previousAttributeName], *attrib)
		}

		tagSet = false
	}

	if len(tempAttributes) > 0 && tag != TagCupsInvalid {
		appendAttributeToResponse(resp, tag, tempAttributes)
	}

	if data != nil {
		if _, err := io.Copy(data, d.reader); err != nil {
			return nil, err
		}
	}

	return resp, nil
}

func appendAttributeToResponse(resp *Response, tag int8, attr map[string][]Attribute) {
	switch tag {
	case TagOperation:
		resp.OperationAttributes = attr
	case TagPrinter:
		resp.PrinterAttributes = append(resp.PrinterAttributes, attr)
	case TagJob:
		resp.JobAttributes = append(resp.JobAttributes, attr)
	case TagSubscription, TagEventNotification:
		// Both subscription and event notification attributes go to SubscriptionAttributes
		resp.SubscriptionAttributes = append(resp.SubscriptionAttributes, attr)
	}
}
