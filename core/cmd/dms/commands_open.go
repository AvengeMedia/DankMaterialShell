package main

import (
	"encoding/json"
	"fmt"
	"mime"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/spf13/cobra"
)

var (
	openMimeType    string
	openCategories  []string
	openRequestType string
)

var openCmd = &cobra.Command{
	Use:   "open [target]",
	Short: "Open a file, URL, or resource with an application picker",
	Long: `Open a target (URL, file, or other resource) using the DMS application picker.
By default, this opens URLs with the browser picker. You can customize the behavior
with flags to handle different MIME types or application categories.

Examples:
  dms open https://example.com                    # Open URL with browser picker
  dms open file.pdf --mime application/pdf        # Open PDF with compatible apps
  dms open document.odt --category Office         # Open with office applications
  dms open --mime image/png image.png             # Open image with image viewers`,
	Args: cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		runOpen(args[0])
	},
}

func init() {
	rootCmd.AddCommand(openCmd)
	openCmd.Flags().StringVar(&openMimeType, "mime", "", "MIME type for filtering applications")
	openCmd.Flags().StringSliceVar(&openCategories, "category", []string{}, "Application categories to filter (e.g., WebBrowser, Office, Graphics)")
	openCmd.Flags().StringVar(&openRequestType, "type", "url", "Request type (url, file, or custom)")
}

// mimeTypeToCategories maps MIME types to desktop file categories
func mimeTypeToCategories(mimeType string) []string {
	// Split MIME type to get the main type
	parts := strings.Split(mimeType, "/")
	if len(parts) < 1 {
		return nil
	}

	mainType := parts[0]

	switch mainType {
	case "image":
		return []string{"Graphics", "Viewer"}
	case "video":
		return []string{"Video", "AudioVideo"}
	case "audio":
		return []string{"Audio", "AudioVideo"}
	case "text":
		if strings.Contains(mimeType, "html") {
			return []string{"WebBrowser"}
		}
		return []string{"TextEditor", "Office"}
	case "application":
		if strings.Contains(mimeType, "pdf") {
			return []string{"Office", "Viewer"}
		}
		if strings.Contains(mimeType, "document") || strings.Contains(mimeType, "spreadsheet") ||
			strings.Contains(mimeType, "presentation") || strings.Contains(mimeType, "msword") ||
			strings.Contains(mimeType, "ms-excel") || strings.Contains(mimeType, "ms-powerpoint") ||
			strings.Contains(mimeType, "opendocument") {
			return []string{"Office"}
		}
		if strings.Contains(mimeType, "zip") || strings.Contains(mimeType, "tar") ||
			strings.Contains(mimeType, "gzip") || strings.Contains(mimeType, "compress") {
			return []string{"Archiving", "Utility"}
		}
		return []string{"Office", "Viewer"}
	}

	return nil
}

func runOpen(target string) {
	socketPath, err := server.FindSocket()
	if err != nil {
		log.Warnf("DMS socket not found: %v", err)
		fmt.Println("DMS is not running. Please start DMS first.")
		os.Exit(1)
	}

	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		log.Warnf("DMS socket connection failed: %v", err)
		fmt.Println("DMS is not running. Please start DMS first.")
		os.Exit(1)
	}
	defer conn.Close()

	buf := make([]byte, 1)
	for {
		_, err := conn.Read(buf)
		if err != nil {
			return
		}
		if buf[0] == '\n' {
			break
		}
	}

	// Parse file:// URIs to extract the actual file path
	actualTarget := target
	detectedMimeType := openMimeType
	detectedCategories := openCategories
	detectedRequestType := openRequestType

	log.Infof("Processing target: %s", target)

	if parsedURL, err := url.Parse(target); err == nil && parsedURL.Scheme == "file" {
		// Extract file path from file:// URI and convert to absolute path
		actualTarget = parsedURL.Path
		if absPath, err := filepath.Abs(actualTarget); err == nil {
			actualTarget = absPath
		}

		if detectedRequestType == "url" || detectedRequestType == "" {
			detectedRequestType = "file"
		}

		log.Infof("Detected file:// URI, extracted absolute path: %s", actualTarget)

		// Auto-detect MIME type if not provided
		if detectedMimeType == "" {
			ext := filepath.Ext(actualTarget)
			if ext != "" {
				detectedMimeType = mime.TypeByExtension(ext)
				log.Infof("Detected MIME type from extension %s: %s", ext, detectedMimeType)
			}
		}

		// Auto-detect categories based on MIME type if not provided
		if len(detectedCategories) == 0 && detectedMimeType != "" {
			detectedCategories = mimeTypeToCategories(detectedMimeType)
			log.Infof("Detected categories from MIME type: %v", detectedCategories)
		}
	} else if strings.HasPrefix(target, "http://") || strings.HasPrefix(target, "https://") {
		// Handle HTTP(S) URLs
		if detectedRequestType == "" {
			detectedRequestType = "url"
		}
		log.Infof("Detected HTTP(S) URL")
	} else if _, err := os.Stat(target); err == nil {
		// Handle local file paths directly (not file:// URIs)
		// Convert to absolute path
		if absPath, err := filepath.Abs(target); err == nil {
			actualTarget = absPath
		}

		if detectedRequestType == "url" || detectedRequestType == "" {
			detectedRequestType = "file"
		}

		log.Infof("Detected local file path, converted to absolute: %s", actualTarget)

		// Auto-detect MIME type if not provided
		if detectedMimeType == "" {
			ext := filepath.Ext(actualTarget)
			if ext != "" {
				detectedMimeType = mime.TypeByExtension(ext)
				log.Infof("Detected MIME type from extension %s: %s", ext, detectedMimeType)
			}
		}

		// Auto-detect categories based on MIME type if not provided
		if len(detectedCategories) == 0 && detectedMimeType != "" {
			detectedCategories = mimeTypeToCategories(detectedMimeType)
			log.Infof("Detected categories from MIME type: %v", detectedCategories)
		}
	}

	params := map[string]interface{}{
		"target": actualTarget,
	}

	if detectedMimeType != "" {
		params["mimeType"] = detectedMimeType
	}

	if len(detectedCategories) > 0 {
		params["categories"] = detectedCategories
	}

	if detectedRequestType != "" {
		params["requestType"] = detectedRequestType
	}

	method := "apppicker.open"
	if detectedMimeType == "" && len(detectedCategories) == 0 && (strings.HasPrefix(target, "http://") || strings.HasPrefix(target, "https://")) {
		method = "browser.open"
		params["url"] = target
	}

	req := models.Request{
		ID:     1,
		Method: method,
		Params: params,
	}

	log.Infof("Sending request - Method: %s, Params: %+v", method, params)

	if err := json.NewEncoder(conn).Encode(req); err != nil {
		log.Fatalf("Failed to send request: %v", err)
	}

	log.Infof("Request sent successfully")
}
