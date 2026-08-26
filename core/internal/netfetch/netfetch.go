package netfetch

import (
	"context"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

const DefaultUserAgent = "DankMaterialShell/1.0 (Linux)"

type Options struct {
	Headers        map[string]string
	UserAgent      string
	Timeout        time.Duration
	ConnectTimeout time.Duration
	IPv4Only       bool
}

func (o Options) client() *http.Client {
	connect := o.ConnectTimeout
	if connect <= 0 {
		connect = 5 * time.Second
	}

	dialer := &net.Dialer{Timeout: connect}
	transport := &http.Transport{DialContext: dialer.DialContext}
	if o.IPv4Only {
		transport.DialContext = func(ctx context.Context, network, addr string) (net.Conn, error) {
			return dialer.DialContext(ctx, "tcp4", addr)
		}
	}
	return &http.Client{Transport: transport}
}

func (o Options) request(ctx context.Context, url string) (*http.Request, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("invalid request: %w", err)
	}

	agent := o.UserAgent
	if agent == "" {
		agent = DefaultUserAgent
	}
	req.Header.Set("User-Agent", agent)

	for name, value := range o.Headers {
		req.Header.Set(name, value)
	}
	return req, nil
}

// Closing the body is what cancels the timeout context.
func Open(ctx context.Context, url string, opts Options) (io.ReadCloser, error) {
	if opts.Timeout <= 0 {
		return open(ctx, url, opts)
	}

	ctx, cancel := context.WithTimeout(ctx, opts.Timeout)
	body, err := open(ctx, url, opts)
	if err != nil {
		cancel()
		return nil, err
	}
	return &cancelOnClose{ReadCloser: body, cancel: cancel}, nil
}

type cancelOnClose struct {
	io.ReadCloser
	cancel context.CancelFunc
}

func (c *cancelOnClose) Close() error {
	err := c.ReadCloser.Close()
	c.cancel()
	return err
}

func open(ctx context.Context, url string, opts Options) (io.ReadCloser, error) {
	req, err := opts.request(ctx, url)
	if err != nil {
		return nil, err
	}

	resp, err := opts.client().Do(req)
	if err != nil {
		return nil, fmt.Errorf("download failed: %w", err)
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		resp.Body.Close()
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	return resp.Body, nil
}

func Bytes(ctx context.Context, url string, opts Options) ([]byte, error) {
	body, err := Open(ctx, url, opts)
	if err != nil {
		return nil, err
	}
	defer body.Close()
	return io.ReadAll(body)
}

func ToWriter(ctx context.Context, url string, opts Options, w io.Writer) error {
	body, err := Open(ctx, url, opts)
	if err != nil {
		return err
	}
	defer body.Close()

	_, err = io.Copy(w, body)
	return err
}

func ToFile(ctx context.Context, url string, opts Options, path string) error {
	if dir := filepath.Dir(path); dir != "." {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return fmt.Errorf("mkdir failed: %w", err)
		}
	}

	f, err := os.Create(path)
	if err != nil {
		return fmt.Errorf("create failed: %w", err)
	}
	defer f.Close()

	if err := ToWriter(ctx, url, opts, f); err != nil {
		os.Remove(path)
		return err
	}
	return nil
}
