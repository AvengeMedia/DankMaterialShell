package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/icc"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/wayland"
	"github.com/spf13/cobra"
)

var iccCmd = &cobra.Command{
	Use:   "icc",
	Short: "Manage ICC color profiles",
	Long:  "Manage ICC color profile assignments for displays",
}

var iccListCmd = &cobra.Command{
	Use:   "list",
	Short: "List available ICC profiles and current assignments",
	Args:  cobra.NoArgs,
	Run:   runICCList,
}

var iccInfoCmd = &cobra.Command{
	Use:   "info <file>",
	Short: "Show details of an ICC profile",
	Args:  cobra.ExactArgs(1),
	Run:   runICCInfo,
}

var iccApplyCmd = &cobra.Command{
	Use:   "apply <output> <file>",
	Short: "Apply ICC profile to a specific output",
	Args:  cobra.ExactArgs(2),
	Run:   runICCApply,
}

var iccRemoveCmd = &cobra.Command{
	Use:   "remove <output>",
	Short: "Remove ICC profile from a specific output",
	Args:  cobra.ExactArgs(1),
	Run:   runICCRemove,
}

var iccStatusCmd = &cobra.Command{
	Use:   "status",
	Short: "Show ICC profile status for all outputs",
	Args:  cobra.NoArgs,
	Run:   runICCStatus,
}

func init() {
	iccCmd.AddCommand(iccListCmd, iccInfoCmd, iccApplyCmd, iccRemoveCmd, iccStatusCmd)
}

func getICCConfigDir() string {
	return wayland.ICCProfilesDir()
}

func listAvailableProfiles() []string {
	dir := getICCConfigDir()
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}

	var profiles []string
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		ext := strings.ToLower(filepath.Ext(name))
		if ext == ".icc" || ext == ".icm" {
			profiles = append(profiles, filepath.Join(dir, name))
		}
	}
	return profiles
}

func runICCList(cmd *cobra.Command, args []string) {
	// Get current assignments from running server
	req := models.Request{
		Method: "wayland.icc.getStatus",
	}
	resp, err := sendServerRequest(req)
	if err != nil {
		log.Fatalf("Failed to get ICC status: %v", err)
	}

	statusMap := make(map[string]map[string]any)
	outputs := []string{}
	if resp.Result != nil {
		if resultBytes, err := json.Marshal(*resp.Result); err == nil {
			var result map[string]any
			if err := json.Unmarshal(resultBytes, &result); err == nil {
				if outputsRaw, ok := result["outputs"].([]any); ok {
					for _, o := range outputsRaw {
						if s, ok := o.(string); ok {
							outputs = append(outputs, s)
						}
					}
				}
				if profilesRaw, ok := result["profiles"].(map[string]any); ok {
					for k, v := range profilesRaw {
						if m, ok := v.(map[string]any); ok {
							statusMap[k] = m
						}
					}
				}
			}
		}
	}

	// Show existing assignments
	fmt.Println("Current ICC Assignments:")
	fmt.Println(strings.Repeat("─", 80))
	if len(outputs) == 0 && len(statusMap) == 0 {
		fmt.Println("  (no outputs found)")
	} else {
		shown := make(map[string]bool)
		for _, output := range outputs {
			shown[output] = true
			if status, ok := statusMap[output]; ok {
				desc := ""
				if d, ok := status["description"].(string); ok {
					desc = d
				}
				path := ""
				if p, ok := status["path"].(string); ok {
					path = p
				}
				fmt.Printf("  %-20s %-30s %s\n", output, desc, path)
			} else {
				fmt.Printf("  %-20s %-30s %s\n", output, "(none)", "")
			}
		}
		// Show any outputs that are in statusMap but not in outputs list
		for output, status := range statusMap {
			if shown[output] {
				continue
			}
			desc := ""
			if d, ok := status["description"].(string); ok {
				desc = d
			}
			path := ""
			if p, ok := status["path"].(string); ok {
				path = p
			}
			fmt.Printf("  %-20s %-30s %s\n", output, desc, path)
		}
	}

	// Show available profiles in config dir
	fmt.Println()
	fmt.Println("Available Profiles in", getICCConfigDir()+":")
	fmt.Println(strings.Repeat("─", 80))

	profiles := listAvailableProfiles()
	if len(profiles) == 0 {
		fmt.Println("  (no .icc/.icm files found)")
	} else {
		for _, path := range profiles {
			profile, err := icc.ParseFile(path)
			if err != nil {
				fmt.Printf("  %-40s (parse error: %v)\n", filepath.Base(path), err)
				continue
			}
			fmt.Printf("  %-40s %s\n", filepath.Base(path), profile.Description)
		}
	}
}

func runICCInfo(cmd *cobra.Command, args []string) {
	path := args[0]

	profile, err := icc.ParseFile(path)
	if err != nil {
		log.Fatalf("Failed to parse ICC profile: %v", err)
	}

	fmt.Printf("ICC Profile: %s\n", filepath.Base(path))
	fmt.Println(strings.Repeat("─", 60))
	fmt.Printf("  Description:  %s\n", profile.Description)
	fmt.Printf("  Version:      %s\n", profile.Version)
	fmt.Printf("  Class:        %s\n", profile.Class)
	fmt.Printf("  Color Space:  %s\n", profile.ColorSpace)
	fmt.Println()

	if profile.HasMatrix {
		fmt.Println("Matrix:")
		for i := 0; i < 3; i++ {
			fmt.Printf("  %8.4f  %8.4f  %8.4f\n",
				profile.Matrix[i][0], profile.Matrix[i][1], profile.Matrix[i][2])
		}
		fmt.Println()
	}

	if profile.HasTRC {
		fmt.Println("TRC (Tone Reproduction Curves):")
		trcNames := []string{"  Red", "  Green", "  Blue"}
		for i, name := range trcNames {
			curve := profile.TRC[i]
			switch curve.Type {
			case icc.CurveIdentity:
				fmt.Printf("%-8s identity\n", name)
			case icc.CurveParametric:
				fmt.Printf("%-8s gamma=%.2f\n", name, curve.Gamma)
			case icc.CurveTable:
				fmt.Printf("%-8s table (%d entries)\n", name, len(curve.Entries))
			}
		}
		fmt.Println()
	}

	if profile.HasVCGT && profile.VCGT != nil {
		fmt.Printf("VCGT: %d channels, %d entries per channel\n", profile.VCGT.Channels, profile.VCGT.Entries)
		fmt.Println()
	}

	fmt.Printf("White Point: %.4f %.4f %.4f\n",
		profile.WhitePoint[0], profile.WhitePoint[1], profile.WhitePoint[2])
}

func runICCApply(cmd *cobra.Command, args []string) {
	outputName := args[0]
	filePath := args[1]

	// Resolve to absolute path
	if !filepath.IsAbs(filePath) {
		abs, err := filepath.Abs(filePath)
		if err != nil {
			log.Fatalf("Failed to resolve path: %v", err)
		}
		filePath = abs
	}

	// Validate file exists and is a valid ICC profile
	profile, err := icc.ParseFile(filePath)
	if err != nil {
		log.Fatalf("Invalid ICC profile: %v", err)
	}

	// Copy the ICC file to config dir for persistence
	configDir := getICCConfigDir()
	if err := os.MkdirAll(configDir, 0755); err != nil {
		log.Fatalf("Failed to create config directory: %v", err)
	}

	destPath := filepath.Join(configDir, filepath.Base(filePath))
	if filepath.Clean(filePath) != filepath.Clean(destPath) {
		data, err := os.ReadFile(filePath)
		if err != nil {
			log.Fatalf("Failed to read ICC file: %v", err)
		}
		if err := os.WriteFile(destPath, data, 0644); err != nil {
			log.Fatalf("Failed to copy ICC file: %v", err)
		}
	}

	// Send IPC request to running server
	req := models.Request{
		Method: "wayland.icc.apply",
		Params: map[string]any{
			"output": outputName,
			"path":   destPath,
		},
	}

	resp, err := sendServerRequest(req)
	if err != nil {
		log.Fatalf("Failed to apply ICC profile: %v", err)
	}

	if resp.Error != "" {
		log.Fatalf("Server error: %s", resp.Error)
	}

	fmt.Printf("Applied ICC profile '%s' to output '%s'\n", profile.Description, outputName)
}

func runICCRemove(cmd *cobra.Command, args []string) {
	outputName := args[0]

	req := models.Request{
		Method: "wayland.icc.remove",
		Params: map[string]any{
			"output": outputName,
		},
	}

	resp, err := sendServerRequest(req)
	if err != nil {
		log.Fatalf("Failed to remove ICC profile: %v", err)
	}

	if resp.Error != "" {
		log.Fatalf("Server error: %s", resp.Error)
	}

	fmt.Printf("Removed ICC profile from output '%s'\n", outputName)
}

func runICCStatus(cmd *cobra.Command, args []string) {
	req := models.Request{
		Method: "wayland.icc.getStatus",
	}

	resp, err := sendServerRequest(req)
	if err != nil {
		log.Fatalf("Failed to get ICC status: %v", err)
	}

	statusMap := make(map[string]map[string]any)
	outputs := []string{}
	if resp.Result != nil {
		if resultBytes, err := json.Marshal(*resp.Result); err == nil {
			var result map[string]any
			if err := json.Unmarshal(resultBytes, &result); err == nil {
				if outputsRaw, ok := result["outputs"].([]any); ok {
					for _, o := range outputsRaw {
						if s, ok := o.(string); ok {
							outputs = append(outputs, s)
						}
					}
				}
				if profilesRaw, ok := result["profiles"].(map[string]any); ok {
					for k, v := range profilesRaw {
						if m, ok := v.(map[string]any); ok {
							statusMap[k] = m
						}
					}
				}
			}
		}
	}

	fmt.Println("ICC Profile Status:")
	fmt.Println(strings.Repeat("─", 90))
	fmt.Printf("  %-20s %-20s %-10s %-10s %-7s\n", "Output", "Profile", "Version", "ColorSpace", "Active")
	fmt.Println("  " + strings.Repeat("─", 86))

	shown := make(map[string]bool)
	for _, output := range outputs {
		shown[output] = true
		if status, ok := statusMap[output]; ok {
			active := false
			if a, ok := status["active"].(bool); ok {
				active = a
			}
			desc := "(none)"
			if d, ok := status["description"].(string); ok && d != "" {
				desc = d
			}
			version := ""
			if v, ok := status["version"].(string); ok {
				version = v
			}
			colorSpace := ""
			if c, ok := status["colorSpace"].(string); ok {
				colorSpace = c
			}
			activeStr := "no"
			if active {
				activeStr = "yes"
			}
			fmt.Printf("  %-20s %-20s %-10s %-10s %-7s\n", output, desc, version, colorSpace, activeStr)
		} else {
			fmt.Printf("  %-20s %-20s %-10s %-10s %-7s\n", output, "(none)", "", "", "no")
		}
	}

	// Show any outputs that are in statusMap but not in outputs list
	for output, status := range statusMap {
		if shown[output] {
			continue
		}
		active := false
		if a, ok := status["active"].(bool); ok {
			active = a
		}
		desc := "(none)"
		if d, ok := status["description"].(string); ok && d != "" {
			desc = d
		}
		version := ""
		if v, ok := status["version"].(string); ok {
			version = v
		}
		colorSpace := ""
		if c, ok := status["colorSpace"].(string); ok {
			colorSpace = c
		}
		activeStr := "no"
		if active {
			activeStr = "yes"
		}
		fmt.Printf("  %-20s %-20s %-10s %-10s %-7s\n", output, desc, version, colorSpace, activeStr)
	}
}
