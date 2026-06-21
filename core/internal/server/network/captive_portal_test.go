package network

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestPortalProbeCheck(t *testing.T) {
	tests := []struct {
		name     string
		handler  http.HandlerFunc
		wantConn Connectivity
		wantURL  func(srv string) string
	}{
		{
			name: "online when expected body returned",
			handler: func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(http.StatusOK)
				w.Write([]byte(portalProbeExpect + "\n"))
			},
			wantConn: ConnectivityFull,
			wantURL:  func(string) string { return "" },
		},
		{
			name: "portal on redirect, url from location",
			handler: func(w http.ResponseWriter, r *http.Request) {
				http.Redirect(w, r, "http://portal.example/login", http.StatusFound)
			},
			wantConn: ConnectivityPortal,
			wantURL:  func(string) string { return "http://portal.example/login" },
		},
		{
			name: "portal on unexpected 200 body",
			handler: func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(http.StatusOK)
				w.Write([]byte("<html>please sign in</html>"))
			},
			wantConn: ConnectivityPortal,
			wantURL:  func(srv string) string { return srv },
		},
		{
			name: "relative redirect location resolved to absolute",
			handler: func(w http.ResponseWriter, r *http.Request) {
				w.Header().Set("Location", "/login")
				w.WriteHeader(http.StatusFound)
			},
			wantConn: ConnectivityPortal,
			wantURL:  func(srv string) string { return srv + "/login" },
		},
		{
			name: "204 no content means online",
			handler: func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(http.StatusNoContent)
			},
			wantConn: ConnectivityFull,
			wantURL:  func(string) string { return "" },
		},
		{
			name: "server error is not a portal",
			handler: func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(http.StatusServiceUnavailable)
			},
			wantConn: ConnectivityUnknown,
			wantURL:  func(string) string { return "" },
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			srv := httptest.NewServer(tt.handler)
			defer srv.Close()

			p := newPortalProbe(nil)
			p.url = srv.URL

			conn, url := p.check()
			if conn != tt.wantConn {
				t.Errorf("connectivity = %q, want %q", conn, tt.wantConn)
			}
			if want := tt.wantURL(srv.URL); url != want {
				t.Errorf("url = %q, want %q", url, want)
			}
		})
	}
}

func TestPortalProbeCheckUnreachable(t *testing.T) {
	p := newPortalProbe(nil)
	p.url = "http://127.0.0.1:1"

	conn, url := p.check()
	if conn != ConnectivityNone {
		t.Errorf("connectivity = %q, want %q", conn, ConnectivityNone)
	}
	if url != "" {
		t.Errorf("url = %q, want empty", url)
	}
}
