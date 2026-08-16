package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"os/signal"
	"syscall"
	"text/tabwriter"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/spf13/cobra"
)

// The chat commands exist for people writing chat provider bridges. A bridge is
// a subprocess of the daemon, so without these its output is invisible: `tail`
// in particular is the difference between debugging a bridge and guessing at it.
var chatCmd = &cobra.Command{
	Use:   "chat",
	Short: "Inspect chat providers",
	Long:  "Inspect and debug chat provider bridges. See docs/CHAT-PLUGINS.md.",
}

var chatProvidersCmd = &cobra.Command{
	Use:     "providers",
	Aliases: []string{"list", "ls"},
	Short:   "List installed chat providers",
	Run: func(cmd *cobra.Command, args []string) {
		providers, err := fetchProviders()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}

		if len(providers) == 0 {
			fmt.Println("No chat providers installed.")
			fmt.Println("A chat provider is a plugin with \"type\": \"chat\" in its plugin.json.")
			return
		}

		w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
		fmt.Fprintln(w, "ID\tNAME\tENABLED\tSTATE\tUNREAD\tRESTARTS")
		for _, p := range providers {
			fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%d\t%d\n",
				p.ID, p.Name, yesNo(p.Enabled), p.State, p.Unread, p.Restarts)
		}
		w.Flush()
	},
}

var chatStatusCmd = &cobra.Command{
	Use:   "status <provider>",
	Short: "Show one provider's connection state and recent errors",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		providers, err := fetchProviders()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}

		for _, p := range providers {
			if p.ID != args[0] {
				continue
			}

			fmt.Printf("%s (%s)\n", p.Name, p.ID)
			if p.Description != "" {
				fmt.Printf("  %s\n", p.Description)
			}
			fmt.Printf("\n  enabled:      %s\n", yesNo(p.Enabled))
			fmt.Printf("  running:      %s\n", yesNo(p.Running))
			fmt.Printf("  state:        %s\n", p.State)
			if p.PID > 0 {
				fmt.Printf("  pid:          %d\n", p.PID)
			}
			if p.Protocol > 0 {
				fmt.Printf("  protocol:     %d\n", p.Protocol)
			}
			fmt.Printf("  capabilities: %v\n", p.Capabilities)
			fmt.Printf("  unread:       %d\n", p.Unread)
			fmt.Printf("  restarts:     %d\n", p.Restarts)

			if p.LastError != "" {
				fmt.Printf("\n  last error:   %s\n", p.LastError)
			}
			if len(p.StderrTail) > 0 {
				fmt.Printf("\n  recent stderr:\n")
				for _, line := range p.StderrTail {
					fmt.Printf("    %s\n", line)
				}
			}
			return
		}

		fmt.Fprintf(os.Stderr, "No chat provider with id %q. Try: dms chat providers\n", args[0])
		os.Exit(1)
	},
}

var chatTailCmd = &cobra.Command{
	Use:   "tail [provider]",
	Short: "Stream a bridge's protocol traffic live",
	Long: "Stream every JSON line exchanged with a bridge, in both directions, plus its stderr.\n" +
		"Omit the provider to watch all of them. Press Ctrl-C to stop.",
	Args: cobra.MaximumNArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		provider := ""
		if len(args) > 0 {
			provider = args[0]
		}
		if err := tailBridge(provider); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
	},
}

var chatRescanCmd = &cobra.Command{
	Use:   "rescan",
	Short: "Re-read the plugin directories for new chat providers",
	Run: func(cmd *cobra.Command, args []string) {
		resp, err := sendServerRequest(models.Request{ID: 1, Method: "chat.rescan"})
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		if resp.Error != "" {
			fmt.Fprintf(os.Stderr, "Error: %s\n", resp.Error)
			os.Exit(1)
		}
		fmt.Println("Rescanned.")
	},
}

// cliProvider mirrors the server's ProviderStatus. Declared here rather than
// imported so the CLI keeps working against a daemon whose struct has grown.
type cliProvider struct {
	ID           string   `json:"id"`
	Name         string   `json:"name"`
	Description  string   `json:"description"`
	Enabled      bool     `json:"enabled"`
	Running      bool     `json:"running"`
	State        string   `json:"state"`
	Capabilities []string `json:"capabilities"`
	Protocol     int      `json:"protocol"`
	Restarts     int      `json:"restarts"`
	LastError    string   `json:"lastError"`
	PID          int      `json:"pid"`
	Unread       int      `json:"unread"`
	StderrTail   []string `json:"stderrTail"`
}

func fetchProviders() ([]cliProvider, error) {
	resp, err := sendServerRequest(models.Request{ID: 1, Method: "chat.providers"})
	if err != nil {
		return nil, err
	}
	if resp.Error != "" {
		return nil, fmt.Errorf("%s", resp.Error)
	}

	raw, err := json.Marshal(resp.Result)
	if err != nil {
		return nil, err
	}

	var result struct {
		Providers []cliProvider `json:"providers"`
	}
	if err := json.Unmarshal(raw, &result); err != nil {
		return nil, err
	}
	return result.Providers, nil
}

// tailBridge holds the connection open and prints frames as they stream in.
//
// Unlike every other CLI command this is not request/response: chat.tap keeps
// writing to the same connection until it is closed, the way subscribe does.
func tailBridge(provider string) error {
	conn, err := net.Dial("unix", getServerSocketPath())
	if err != nil {
		return fmt.Errorf("failed to connect to server (is it running?): %w", err)
	}
	defer conn.Close()

	scanner := bufio.NewScanner(conn)
	scanner.Buffer(make([]byte, bufio.MaxScanTokenSize), maxIPCMessageSize)
	scanner.Scan() // discard the capabilities handshake

	req := models.Request{ID: 1, Method: "chat.tap"}
	if provider != "" {
		req.Params = map[string]any{"provider": provider}
	}

	payload, err := json.Marshal(req)
	if err != nil {
		return err
	}
	if _, err := conn.Write(append(payload, '\n')); err != nil {
		return err
	}

	// Ctrl-C closes the socket, which unblocks the scanner below.
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-sigChan
		conn.Close()
	}()

	if provider != "" {
		fmt.Fprintf(os.Stderr, "Tailing %s. Ctrl-C to stop.\n", provider)
	} else {
		fmt.Fprintln(os.Stderr, "Tailing all chat bridges. Ctrl-C to stop.")
	}

	for scanner.Scan() {
		var resp struct {
			Result *struct {
				Provider  string `json:"provider"`
				Direction string `json:"direction"`
				Line      string `json:"line"`
				At        int64  `json:"at"`
			} `json:"result"`
			Error string `json:"error"`
		}
		if err := json.Unmarshal(scanner.Bytes(), &resp); err != nil {
			continue
		}
		if resp.Error != "" {
			return fmt.Errorf("%s", resp.Error)
		}
		if resp.Result == nil {
			continue
		}

		// Arrows read at a glance: what the host sent, what the bridge said.
		marker := "  ?"
		switch resp.Result.Direction {
		case "in":
			marker = "-->"
		case "out":
			marker = "<--"
		case "stderr":
			marker = " ! "
		}

		stamp := time.UnixMilli(resp.Result.At).Format("15:04:05.000")
		if provider == "" {
			fmt.Printf("%s %s %s %s\n", stamp, resp.Result.Provider, marker, resp.Result.Line)
		} else {
			fmt.Printf("%s %s %s\n", stamp, marker, resp.Result.Line)
		}
	}
	return nil
}

func yesNo(b bool) string {
	if b {
		return "yes"
	}
	return "no"
}

func init() {
	chatCmd.AddCommand(chatProvidersCmd)
	chatCmd.AddCommand(chatStatusCmd)
	chatCmd.AddCommand(chatTailCmd)
	chatCmd.AddCommand(chatRescanCmd)
}
