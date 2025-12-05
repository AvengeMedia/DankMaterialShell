package apppicker

type OpenEvent struct {
	Target      string   `json:"target"`
	MimeType    string   `json:"mimeType,omitempty"`
	Categories  []string `json:"categories,omitempty"`
	RequestType string   `json:"requestType"`
}
