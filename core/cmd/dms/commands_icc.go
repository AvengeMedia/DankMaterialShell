package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/icc"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/wayland"
	"github.com/AvengeMedia/dankgo/ipc"
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

var iccSetTempCmd = &cobra.Command{
	Use:     "set-temp <output> <kelvin>",
	Aliases: []string{"setTemp"},
	Short:   "Set the color temperature for a specific output",
	Long: "Set the color temperature for a specific output, independently of the\n" +
		"night light schedule: every display keeps its own value, which also makes\n" +
		"the range wider than the night light's.\n\n" +
		"For an output with an ICC profile the temperature is composed on top of\n" +
		"it, treating the profile as measured at 6500K.\n\n" +
		"Accepts 1000-10000K; 0 removes the override, so the output follows the\n" +
		"night light schedule again (6500K while it is disabled).",
	Args: cobra.ExactArgs(2),
	Run:  runICCSetTemp,
}

func init() {
	iccCmd.AddCommand(iccListCmd, iccInfoCmd, iccApplyCmd, iccRemoveCmd, iccStatusCmd, iccSetTempCmd)
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
	req := ipc.Request{
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
			// A profile without a vcgt table has no video card gamma ramp, so the
			// daemon refuses to apply it: say so here instead of letting the user
			// find out from a rejected `dms icc apply`.
			note := ""
			if !profile.HasVCGT {
				note = "  (no vcgt table: cannot be applied)"
			}
			fmt.Printf("  %-40s %s%s\n", filepath.Base(path), profile.Description, note)
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

	if x, y, ok := profile.WhitePointXY(); ok {
		cct := profile.WhitePointCCT()
		name := profile.WhitePointName()
		switch {
		case name != "" && cct > 0:
			fmt.Printf("White Point: %s (%.4f, %.4f, %dK)\n", name, x, y, cct)
		case cct > 0:
			fmt.Printf("White Point: (%.4f, %.4f, %dK)\n", x, y, cct)
		default:
			fmt.Printf("White Point: (%.4f, %.4f)\n", x, y)
		}
	} else {
		fmt.Printf("White Point: %.4f %.4f %.4f\n",
			profile.WhitePoint[0], profile.WhitePoint[1], profile.WhitePoint[2])
	}
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

	// Validate file exists and is a valid ICC profile. The rules the daemon
	// enforces are checked here too: a profile it would refuse must not be copied
	// into the profile directory first, or `dms icc list` keeps offering a file
	// that can never be applied.
	profile, err := icc.ParseFile(filePath)
	if err != nil {
		log.Fatalf("Invalid ICC profile: %v", err)
	}
	if profile.ColorSpace != "RGB" {
		log.Fatalf("Unsupported color space %q, only RGB profiles can be applied", profile.ColorSpace)
	}
	if !profile.HasVCGT {
		log.Fatalf("%s has no vcgt table, so it has no gamma ramp to apply", filepath.Base(filePath))
	}

	// Copy the ICC file to config dir for persistence
	configDir := getICCConfigDir()
	if err := os.MkdirAll(configDir, 0755); err != nil {
		log.Fatalf("Failed to create config directory: %v", err)
	}

	destPath, copied, err := stageProfile(configDir, filePath)
	if err != nil {
		log.Fatalf("Failed to copy ICC file: %v", err)
	}

	// Send IPC request to running server
	req := ipc.Request{
		Method: "wayland.icc.apply",
		Params: map[string]any{
			"output": outputName,
			"path":   destPath,
		},
	}
	resp, err := sendServerRequest(req)
	if err != nil {
		dropCopiedProfile(destPath, copied)
		log.Fatalf("Failed to apply ICC profile: %v", err)
	}
	if resp.Error != "" {
		dropCopiedProfile(destPath, copied)
		log.Fatalf("Server error: %s", resp.Error)
	}

	fmt.Printf("Applied ICC profile '%s' to output '%s'\n", profile.Description, outputName)
}

// stageProfile places filePath in configDir and reports the path the daemon
// should load and whether a new file was written. A file already in configDir
// is used as it is. An existing file with the same name keeps its content: an
// identical copy is reused, a different one gets a numbered sibling, so two
// displays never end up sharing one file by name.
func stageProfile(configDir, filePath string) (string, bool, error) {
	if filepath.Dir(filepath.Clean(filePath)) == filepath.Clean(configDir) {
		return filePath, false, nil
	}
	data, err := os.ReadFile(filePath)
	if err != nil {
		return "", false, err
	}

	base := filepath.Base(filePath)
	ext := filepath.Ext(base)
	stem := strings.TrimSuffix(base, ext)
	for n := 0; ; n++ {
		name := base
		if n > 0 {
			name = fmt.Sprintf("%s-%d%s", stem, n, ext)
		}
		destPath := filepath.Join(configDir, name)
		existing, err := os.ReadFile(destPath)
		switch {
		case os.IsNotExist(err):
			if err := os.WriteFile(destPath, data, 0644); err != nil {
				return "", false, err
			}
			return destPath, true, nil
		case err != nil:
			return "", false, err
		case bytes.Equal(existing, data):
			return destPath, false, nil
		}
	}
}

// dropCopiedProfile removes the copy this command just made, so a rejected apply
// does not leave a profile in the config directory that was never applied (a
// file that was already there is left alone).
func dropCopiedProfile(path string, copied bool) {
	if !copied {
		return
	}
	if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
		log.Errorf("Failed to remove %s: %v", path, err)
	}
}

func runICCRemove(cmd *cobra.Command, args []string) {
	outputName := args[0]

	req := ipc.Request{
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

func runICCSetTemp(cmd *cobra.Command, args []string) {
	outputName := args[0]

	temp, err := strconv.Atoi(args[1])
	if err != nil {
		log.Fatalf("Invalid temperature %q: expected a number in kelvin", args[1])
	}
	if temp != 0 && (temp < 1000 || temp > 10000) {
		log.Fatalf("Temperature %d out of range (1000-10000, or 0 to follow the schedule)", temp)
	}

	req := ipc.Request{
		Method: "wayland.icc.setTemp",
		Params: map[string]any{
			"output": outputName,
			"temp":   temp,
		},
	}
	resp, err := sendServerRequest(req)
	if err != nil {
		log.Fatalf("Failed to set output temperature: %v", err)
	}
	if resp.Error != "" {
		log.Fatalf("Server error: %s", resp.Error)
	}

	if temp == 0 {
		fmt.Printf("Output '%s' follows the night light schedule again\n", outputName)
		return
	}
	fmt.Printf("Set output '%s' color temperature to %dK\n", outputName, temp)
}

// fetchICCOutputTemps asks the running server for the per-output overrides.
// Outputs without an override report 0.
func fetchICCOutputTemps() map[string]int {
	temps := make(map[string]int)

	resp, err := sendServerRequest(ipc.Request{Method: "wayland.icc.getTemps"})
	if err != nil || resp.Result == nil {
		return temps
	}
	resultBytes, err := json.Marshal(*resp.Result)
	if err != nil {
		return temps
	}
	var raw map[string]any
	if err := json.Unmarshal(resultBytes, &raw); err != nil {
		return temps
	}
	for output, value := range raw {
		if f, ok := value.(float64); ok {
			temps[output] = int(f)
		}
	}
	return temps
}

// formatOutputTemp renders a per-output override, or the schedule marker.
func formatOutputTemp(temps map[string]int, output string) string {
	temp, ok := temps[output]
	if !ok || temp == 0 {
		return "schedule"
	}
	return strconv.Itoa(temp) + "K"
}

func runICCStatus(cmd *cobra.Command, args []string) {
	req := ipc.Request{
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

	temps := fetchICCOutputTemps()

	fmt.Println("ICC Profile Status:")
	fmt.Println(strings.Repeat("─", 100))
	fmt.Printf("  %-20s %-20s %-10s %-10s %-7s %-9s\n", "Output", "Profile", "Version", "ColorSpace", "Active", "Temp")
	fmt.Println("  " + strings.Repeat("─", 96))

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
			fmt.Printf("  %-20s %-20s %-10s %-10s %-7s %-9s\n", output, desc, version, colorSpace, activeStr, formatOutputTemp(temps, output))
		} else {
			fmt.Printf("  %-20s %-20s %-10s %-10s %-7s %-9s\n", output, "(none)", "", "", "no", formatOutputTemp(temps, output))
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
		fmt.Printf("  %-20s %-20s %-10s %-10s %-7s %-9s\n", output, desc, version, colorSpace, activeStr, formatOutputTemp(temps, output))
	}
}
