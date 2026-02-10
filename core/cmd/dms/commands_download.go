package main

import (
	"context"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/spf13/cobra"
)

var dlOutput string
var dlUserAgent string
var dlTimeout int
var dlIPv4Only bool

var dlCmd = &cobra.Command{
	Use:   "dl <url>",
	Short: "Download a URL to stdout or file",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if err := runDownload(args[0]); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	},
}

func init() {
	dlCmd.Flags().StringVarP(&dlOutput, "output", "o", "", "Output file path (default: stdout)")
	dlCmd.Flags().StringVar(&dlUserAgent, "user-agent", "", "Custom User-Agent header")
	dlCmd.Flags().IntVar(&dlTimeout, "timeout", 10, "Request timeout in seconds")
	dlCmd.Flags().BoolVarP(&dlIPv4Only, "ipv4", "4", false, "Force IPv4 only")
}

func runDownload(url string) error {
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(dlTimeout)*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return fmt.Errorf("invalid request: %w", err)
	}

	switch {
	case dlUserAgent != "":
		req.Header.Set("User-Agent", dlUserAgent)
	default:
		req.Header.Set("User-Agent", "DankMaterialShell/1.0 (Linux)")
	}

	dialer := &net.Dialer{Timeout: 5 * time.Second}
	transport := &http.Transport{DialContext: dialer.DialContext}
	if dlIPv4Only {
		transport.DialContext = func(ctx context.Context, network, addr string) (net.Conn, error) {
			return dialer.DialContext(ctx, "tcp4", addr)
		}
	}
	client := &http.Client{Transport: transport}

	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("download failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("HTTP %d", resp.StatusCode)
	}

	if dlOutput == "" {
		_, err = io.Copy(os.Stdout, resp.Body)
		return err
	}

	if dir := filepath.Dir(dlOutput); dir != "." {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return fmt.Errorf("mkdir failed: %w", err)
		}
	}

	f, err := os.Create(dlOutput)
	if err != nil {
		return fmt.Errorf("create failed: %w", err)
	}
	defer f.Close()

	if _, err := io.Copy(f, resp.Body); err != nil {
		os.Remove(dlOutput)
		return fmt.Errorf("write failed: %w", err)
	}

	fmt.Println(dlOutput)
	return nil
}
