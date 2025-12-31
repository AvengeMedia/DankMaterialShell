package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/clipboard"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/spf13/cobra"
)

var clipboardCmd = &cobra.Command{
	Use:     "clipboard",
	Aliases: []string{"cl"},
	Short:   "Manage clipboard",
	Long:    "Interact with the clipboard manager",
}

var clipCopyCmd = &cobra.Command{
	Use:   "copy [text]",
	Short: "Copy text to clipboard",
	Long:  "Copy text to clipboard. If no text provided, reads from stdin. Works without server.",
	Run:   runClipCopy,
}

var (
	clipCopyForeground bool
	clipCopyPasteOnce  bool
	clipCopyType       string
	clipJSONOutput     bool
)

var clipPasteCmd = &cobra.Command{
	Use:   "paste",
	Short: "Paste text from clipboard",
	Long:  "Paste text from clipboard to stdout. Works without server.",
	Run:   runClipPaste,
}

var clipWatchCmd = &cobra.Command{
	Use:   "watch [command]",
	Short: "Watch clipboard for changes",
	Long: `Watch clipboard for changes and optionally execute a command.
Works like wl-paste --watch. Does not require server.

If a command is provided, it will be executed each time the clipboard changes,
with the clipboard content piped to its stdin.

Examples:
  dms cl watch              # Print clipboard changes to stdout
  dms cl watch cat          # Same as above
  dms cl watch notify-send  # Send notification on clipboard change`,
	Run: runClipWatch,
}

var clipHistoryCmd = &cobra.Command{
	Use:   "history",
	Short: "Show clipboard history",
	Long:  "Show clipboard history with previews (requires server)",
	Run:   runClipHistory,
}

var clipGetCmd = &cobra.Command{
	Use:   "get <id>",
	Short: "Get clipboard entry by ID",
	Long:  "Get full clipboard entry data by ID (requires server). Use --copy to copy it to clipboard.",
	Args:  cobra.ExactArgs(1),
	Run:   runClipGet,
}

var clipGetCopy bool

var clipDeleteCmd = &cobra.Command{
	Use:   "delete <id>",
	Short: "Delete clipboard entry",
	Long:  "Delete a clipboard history entry by ID (requires server)",
	Args:  cobra.ExactArgs(1),
	Run:   runClipDelete,
}

var clipClearCmd = &cobra.Command{
	Use:   "clear",
	Short: "Clear clipboard history",
	Long:  "Clear all clipboard history (requires server)",
	Run:   runClipClear,
}

var clipWatchStore bool

var clipSearchCmd = &cobra.Command{
	Use:   "search [query]",
	Short: "Search clipboard history",
	Long:  "Search clipboard history with filters (requires server)",
	Run:   runClipSearch,
}

var (
	clipSearchLimit    int
	clipSearchOffset   int
	clipSearchMimeType string
	clipSearchImages   bool
	clipSearchText     bool
)

var clipConfigCmd = &cobra.Command{
	Use:   "config",
	Short: "Manage clipboard config",
	Long:  "Get or set clipboard configuration (requires server)",
}

var clipConfigGetCmd = &cobra.Command{
	Use:   "get",
	Short: "Get clipboard config",
	Run:   runClipConfigGet,
}

var clipConfigSetCmd = &cobra.Command{
	Use:   "set",
	Short: "Set clipboard config",
	Long: `Set clipboard configuration options.

Examples:
  dms cl config set --max-history 200
  dms cl config set --auto-clear-days 7
  dms cl config set --clear-at-startup`,
	Run: runClipConfigSet,
}

var (
	clipConfigMaxHistory     int
	clipConfigAutoClearDays  int
	clipConfigClearAtStartup bool
	clipConfigNoClearStartup bool
	clipConfigDisabled       bool
	clipConfigEnabled        bool
)

func init() {
	clipCopyCmd.Flags().BoolVarP(&clipCopyForeground, "foreground", "f", false, "Stay in foreground instead of forking")
	clipCopyCmd.Flags().BoolVarP(&clipCopyPasteOnce, "paste-once", "o", false, "Exit after first paste")
	clipCopyCmd.Flags().StringVarP(&clipCopyType, "type", "t", "text/plain;charset=utf-8", "MIME type")

	clipWatchCmd.Flags().BoolVar(&clipJSONOutput, "json", false, "Output as JSON")
	clipHistoryCmd.Flags().BoolVar(&clipJSONOutput, "json", false, "Output as JSON")
	clipGetCmd.Flags().BoolVar(&clipJSONOutput, "json", false, "Output as JSON")
	clipGetCmd.Flags().BoolVarP(&clipGetCopy, "copy", "c", false, "Copy entry to clipboard")

	clipSearchCmd.Flags().IntVarP(&clipSearchLimit, "limit", "l", 50, "Max results")
	clipSearchCmd.Flags().IntVarP(&clipSearchOffset, "offset", "o", 0, "Result offset")
	clipSearchCmd.Flags().StringVarP(&clipSearchMimeType, "mime", "m", "", "Filter by MIME type")
	clipSearchCmd.Flags().BoolVar(&clipSearchImages, "images", false, "Only images")
	clipSearchCmd.Flags().BoolVar(&clipSearchText, "text", false, "Only text")
	clipSearchCmd.Flags().BoolVar(&clipJSONOutput, "json", false, "Output as JSON")

	clipConfigSetCmd.Flags().IntVar(&clipConfigMaxHistory, "max-history", 0, "Max history entries")
	clipConfigSetCmd.Flags().IntVar(&clipConfigAutoClearDays, "auto-clear-days", -1, "Auto-clear entries older than N days (0 to disable)")
	clipConfigSetCmd.Flags().BoolVar(&clipConfigClearAtStartup, "clear-at-startup", false, "Clear history on startup")
	clipConfigSetCmd.Flags().BoolVar(&clipConfigNoClearStartup, "no-clear-at-startup", false, "Don't clear history on startup")
	clipConfigSetCmd.Flags().BoolVar(&clipConfigDisabled, "disable", false, "Disable clipboard tracking")
	clipConfigSetCmd.Flags().BoolVar(&clipConfigEnabled, "enable", false, "Enable clipboard tracking")

	clipWatchCmd.Flags().BoolVarP(&clipWatchStore, "store", "s", false, "Store clipboard changes to history (no server required)")

	clipConfigCmd.AddCommand(clipConfigGetCmd, clipConfigSetCmd)
	clipboardCmd.AddCommand(clipCopyCmd, clipPasteCmd, clipWatchCmd, clipHistoryCmd, clipGetCmd, clipDeleteCmd, clipClearCmd, clipSearchCmd, clipConfigCmd)
}

func runClipCopy(cmd *cobra.Command, args []string) {
	var data []byte

	if len(args) > 0 {
		data = []byte(args[0])
	} else {
		var err error
		data, err = io.ReadAll(os.Stdin)
		if err != nil {
			log.Fatalf("read stdin: %v", err)
		}
	}

	if err := clipboard.CopyOpts(data, clipCopyType, clipCopyForeground, clipCopyPasteOnce); err != nil {
		log.Fatalf("copy: %v", err)
	}
}

func runClipPaste(cmd *cobra.Command, args []string) {
	data, _, err := clipboard.Paste()
	if err != nil {
		log.Fatalf("paste: %v", err)
	}
	os.Stdout.Write(data)
}

func runClipWatch(cmd *cobra.Command, args []string) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigCh
		cancel()
	}()

	switch {
	case len(args) > 0:
		if err := clipboard.Watch(ctx, func(data []byte, mimeType string) {
			runCommand(args, data)
		}); err != nil && err != context.Canceled {
			log.Fatalf("Watch error: %v", err)
		}
	case clipWatchStore:
		if err := clipboard.Watch(ctx, func(data []byte, mimeType string) {
			if err := clipboard.Store(data, mimeType); err != nil {
				log.Errorf("store: %v", err)
			}
		}); err != nil && err != context.Canceled {
			log.Fatalf("Watch error: %v", err)
		}
	case clipJSONOutput:
		if err := clipboard.Watch(ctx, func(data []byte, mimeType string) {
			out := map[string]any{
				"data":      string(data),
				"mimeType":  mimeType,
				"timestamp": time.Now().Format(time.RFC3339),
				"size":      len(data),
			}
			j, _ := json.Marshal(out)
			fmt.Println(string(j))
		}); err != nil && err != context.Canceled {
			log.Fatalf("Watch error: %v", err)
		}
	default:
		if err := clipboard.Watch(ctx, func(data []byte, mimeType string) {
			os.Stdout.Write(data)
			os.Stdout.WriteString("\n")
		}); err != nil && err != context.Canceled {
			log.Fatalf("Watch error: %v", err)
		}
	}
}

func runCommand(args []string, stdin []byte) {
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if len(stdin) == 0 {
		cmd.Run()
		return
	}

	r, w, err := os.Pipe()
	if err != nil {
		cmd.Run()
		return
	}

	cmd.Stdin = r
	go func() {
		w.Write(stdin)
		w.Close()
	}()
	cmd.Run()
}

func runClipHistory(cmd *cobra.Command, args []string) {
	req := models.Request{
		ID:     1,
		Method: "clipboard.getHistory",
	}

	resp, err := sendServerRequest(req)
	if err != nil {
		log.Fatalf("Failed to get clipboard history: %v", err)
	}

	if resp.Error != "" {
		log.Fatalf("Error: %s", resp.Error)
	}

	if resp.Result == nil {
		if clipJSONOutput {
			fmt.Println("[]")
		} else {
			fmt.Println("No clipboard history")
		}
		return
	}

	historyList, ok := (*resp.Result).([]any)
	if !ok {
		log.Fatal("Invalid response format")
	}

	if clipJSONOutput {
		out, _ := json.MarshalIndent(historyList, "", "  ")
		fmt.Println(string(out))
		return
	}

	if len(historyList) == 0 {
		fmt.Println("No clipboard history")
		return
	}

	fmt.Println("Clipboard History:")
	fmt.Println()

	for _, item := range historyList {
		entry, ok := item.(map[string]any)
		if !ok {
			continue
		}

		id := uint64(entry["id"].(float64))
		preview := entry["preview"].(string)
		timestamp := entry["timestamp"].(string)
		isImage := entry["isImage"].(bool)

		typeStr := "text"
		if isImage {
			typeStr = "image"
		}

		fmt.Printf("ID: %d | %s | %s\n", id, typeStr, timestamp)
		fmt.Printf("  %s\n", preview)
		fmt.Println()
	}
}

func runClipGet(cmd *cobra.Command, args []string) {
	id, err := strconv.ParseUint(args[0], 10, 64)
	if err != nil {
		log.Fatalf("Invalid ID: %v", err)
	}

	if clipGetCopy {
		req := models.Request{
			ID:     1,
			Method: "clipboard.copyEntry",
			Params: map[string]any{
				"id": id,
			},
		}

		resp, err := sendServerRequest(req)
		if err != nil {
			log.Fatalf("Failed to copy clipboard entry: %v", err)
		}

		if resp.Error != "" {
			log.Fatalf("Error: %s", resp.Error)
		}

		fmt.Printf("Copied entry %d to clipboard\n", id)
		return
	}

	req := models.Request{
		ID:     1,
		Method: "clipboard.getEntry",
		Params: map[string]any{
			"id": id,
		},
	}

	resp, err := sendServerRequest(req)
	if err != nil {
		log.Fatalf("Failed to get clipboard entry: %v", err)
	}

	if resp.Error != "" {
		log.Fatalf("Error: %s", resp.Error)
	}

	if resp.Result == nil {
		log.Fatal("Entry not found")
	}

	entry, ok := (*resp.Result).(map[string]any)
	if !ok {
		log.Fatal("Invalid response format")
	}

	switch {
	case clipJSONOutput:
		output, _ := json.MarshalIndent(entry, "", "  ")
		fmt.Println(string(output))
	default:
		if data, ok := entry["data"].(string); ok {
			fmt.Print(data)
		} else {
			output, _ := json.MarshalIndent(entry, "", "  ")
			fmt.Println(string(output))
		}
	}
}

func runClipDelete(cmd *cobra.Command, args []string) {
	id, err := strconv.ParseUint(args[0], 10, 64)
	if err != nil {
		log.Fatalf("Invalid ID: %v", err)
	}

	req := models.Request{
		ID:     1,
		Method: "clipboard.deleteEntry",
		Params: map[string]any{
			"id": id,
		},
	}

	resp, err := sendServerRequest(req)
	if err != nil {
		log.Fatalf("Failed to delete clipboard entry: %v", err)
	}

	if resp.Error != "" {
		log.Fatalf("Error: %s", resp.Error)
	}

	fmt.Printf("Deleted entry %d\n", id)
}

func runClipClear(cmd *cobra.Command, args []string) {
	req := models.Request{
		ID:     1,
		Method: "clipboard.clearHistory",
	}

	resp, err := sendServerRequest(req)
	if err != nil {
		log.Fatalf("Failed to clear clipboard history: %v", err)
	}

	if resp.Error != "" {
		log.Fatalf("Error: %s", resp.Error)
	}

	fmt.Println("Clipboard history cleared")
}

func runClipSearch(cmd *cobra.Command, args []string) {
	params := map[string]any{
		"limit":  clipSearchLimit,
		"offset": clipSearchOffset,
	}

	if len(args) > 0 {
		params["query"] = args[0]
	}
	if clipSearchMimeType != "" {
		params["mimeType"] = clipSearchMimeType
	}
	if clipSearchImages {
		params["isImage"] = true
	} else if clipSearchText {
		params["isImage"] = false
	}

	req := models.Request{
		ID:     1,
		Method: "clipboard.search",
		Params: params,
	}

	resp, err := sendServerRequest(req)
	if err != nil {
		log.Fatalf("Failed to search clipboard: %v", err)
	}

	if resp.Error != "" {
		log.Fatalf("Error: %s", resp.Error)
	}

	if resp.Result == nil {
		log.Fatal("No results")
	}

	result, ok := (*resp.Result).(map[string]any)
	if !ok {
		log.Fatal("Invalid response format")
	}

	if clipJSONOutput {
		out, _ := json.MarshalIndent(result, "", "  ")
		fmt.Println(string(out))
		return
	}

	entries, _ := result["entries"].([]any)
	total := int(result["total"].(float64))
	hasMore := result["hasMore"].(bool)

	if len(entries) == 0 {
		fmt.Println("No results found")
		return
	}

	fmt.Printf("Results: %d of %d\n\n", len(entries), total)

	for _, item := range entries {
		entry, ok := item.(map[string]any)
		if !ok {
			continue
		}

		id := uint64(entry["id"].(float64))
		preview := entry["preview"].(string)
		timestamp := entry["timestamp"].(string)
		isImage := entry["isImage"].(bool)

		typeStr := "text"
		if isImage {
			typeStr = "image"
		}

		fmt.Printf("ID: %d | %s | %s\n", id, typeStr, timestamp)
		fmt.Printf("  %s\n\n", preview)
	}

	if hasMore {
		fmt.Printf("Use --offset %d to see more results\n", clipSearchOffset+clipSearchLimit)
	}
}

func runClipConfigGet(cmd *cobra.Command, args []string) {
	req := models.Request{
		ID:     1,
		Method: "clipboard.getConfig",
	}

	resp, err := sendServerRequest(req)
	if err != nil {
		log.Fatalf("Failed to get config: %v", err)
	}

	if resp.Error != "" {
		log.Fatalf("Error: %s", resp.Error)
	}

	if resp.Result == nil {
		log.Fatal("No config returned")
	}

	cfg, ok := (*resp.Result).(map[string]any)
	if !ok {
		log.Fatal("Invalid response format")
	}

	output, _ := json.MarshalIndent(cfg, "", "  ")
	fmt.Println(string(output))
}

func runClipConfigSet(cmd *cobra.Command, args []string) {
	params := map[string]any{}

	if cmd.Flags().Changed("max-history") {
		params["maxHistory"] = clipConfigMaxHistory
	}
	if cmd.Flags().Changed("auto-clear-days") {
		params["autoClearDays"] = clipConfigAutoClearDays
	}
	if clipConfigClearAtStartup {
		params["clearAtStartup"] = true
	}
	if clipConfigNoClearStartup {
		params["clearAtStartup"] = false
	}
	if clipConfigDisabled {
		params["disabled"] = true
	}
	if clipConfigEnabled {
		params["disabled"] = false
	}

	if len(params) == 0 {
		fmt.Println("No config options specified")
		return
	}

	req := models.Request{
		ID:     1,
		Method: "clipboard.setConfig",
		Params: params,
	}

	resp, err := sendServerRequest(req)
	if err != nil {
		log.Fatalf("Failed to set config: %v", err)
	}

	if resp.Error != "" {
		log.Fatalf("Error: %s", resp.Error)
	}

	fmt.Println("Config updated")
}
