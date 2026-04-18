package main

import (
	"bufio"
	_ "embed"
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"sync"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/privesc"
	"github.com/spf13/cobra"
)

const (
	cliPolicyPackagedPath = "/usr/share/dms/cli-policy.json"
	cliPolicyAdminPath    = "/etc/dms/cli-policy.json"
)

var (
	immutablePolicyOnce sync.Once
	immutablePolicy     immutableCommandPolicy
	immutablePolicyErr  error
)

//go:embed assets/cli-policy.default.json
var defaultCLIPolicyJSON []byte

type immutableCommandPolicy struct {
	ImmutableSystem bool
	ImmutableReason string
	BlockedCommands []string
	Message         string
}

type cliPolicyFile struct {
	PolicyVersion   int       `json:"policy_version"`
	ImmutableSystem *bool     `json:"immutable_system"`
	BlockedCommands *[]string `json:"blocked_commands"`
	Message         *string   `json:"message"`
}

func normalizeCommandSpec(raw string) string {
	normalized := strings.ToLower(strings.TrimSpace(raw))
	normalized = strings.TrimPrefix(normalized, "dms ")
	return strings.Join(strings.Fields(normalized), " ")
}

func normalizeBlockedCommands(raw []string) []string {
	normalized := make([]string, 0, len(raw))
	seen := make(map[string]bool)

	for _, cmd := range raw {
		spec := normalizeCommandSpec(cmd)
		if spec == "" || seen[spec] {
			continue
		}
		seen[spec] = true
		normalized = append(normalized, spec)
	}

	return normalized
}

func commandBlockedByPolicy(commandPath string, blocked []string) bool {
	normalizedPath := normalizeCommandSpec(commandPath)
	if normalizedPath == "" {
		return false
	}

	for _, entry := range blocked {
		spec := normalizeCommandSpec(entry)
		if spec == "" {
			continue
		}
		if normalizedPath == spec || strings.HasPrefix(normalizedPath, spec+" ") {
			return true
		}
	}

	return false
}

func loadPolicyFile(path string) (*cliPolicyFile, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to read %s: %w", path, err)
	}

	var policy cliPolicyFile
	if err := json.Unmarshal(data, &policy); err != nil {
		return nil, fmt.Errorf("failed to parse %s: %w", path, err)
	}

	return &policy, nil
}

func mergePolicyFile(base *immutableCommandPolicy, path string) error {
	policyFile, err := loadPolicyFile(path)
	if err != nil {
		return err
	}
	if policyFile == nil {
		return nil
	}

	if policyFile.ImmutableSystem != nil {
		base.ImmutableSystem = *policyFile.ImmutableSystem
	}
	if policyFile.BlockedCommands != nil {
		base.BlockedCommands = normalizeBlockedCommands(*policyFile.BlockedCommands)
	}
	if policyFile.Message != nil {
		msg := strings.TrimSpace(*policyFile.Message)
		if msg != "" {
			base.Message = msg
		}
	}

	return nil
}

func readOSReleaseMap(path string) map[string]string {
	values := make(map[string]string)

	file, err := os.Open(path)
	if err != nil {
		return values
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.ToUpper(strings.TrimSpace(parts[0]))
		value := strings.Trim(strings.TrimSpace(parts[1]), "\"")
		values[key] = strings.ToLower(value)
	}

	return values
}

func hasAnyToken(text string, tokens ...string) bool {
	if text == "" {
		return false
	}
	for _, token := range tokens {
		if strings.Contains(text, token) {
			return true
		}
	}
	return false
}

func detectImmutableSystem() (bool, string) {
	if _, err := os.Stat("/run/ostree-booted"); err == nil {
		return true, "/run/ostree-booted is present"
	}

	osRelease := readOSReleaseMap("/etc/os-release")
	if len(osRelease) == 0 {
		return false, ""
	}

	id := osRelease["ID"]
	idLike := osRelease["ID_LIKE"]
	variantID := osRelease["VARIANT_ID"]
	name := osRelease["NAME"]
	prettyName := osRelease["PRETTY_NAME"]

	immutableIDs := map[string]bool{
		"bluefin":       true,
		"bazzite":       true,
		"silverblue":    true,
		"kinoite":       true,
		"sericea":       true,
		"onyx":          true,
		"aurora":        true,
		"fedora-iot":    true,
		"fedora-coreos": true,
	}
	if immutableIDs[id] {
		return true, "os-release ID=" + id
	}

	markers := []string{"silverblue", "kinoite", "sericea", "onyx", "bazzite", "bluefin", "aurora", "ostree", "atomic"}
	if hasAnyToken(variantID, markers...) {
		return true, "os-release VARIANT_ID=" + variantID
	}
	if hasAnyToken(idLike, "ostree", "rpm-ostree") {
		return true, "os-release ID_LIKE=" + idLike
	}
	if hasAnyToken(name, markers...) || hasAnyToken(prettyName, markers...) {
		return true, "os-release identifies an atomic/ostree variant"
	}

	return false, ""
}

func getImmutablePolicy() (*immutableCommandPolicy, error) {
	immutablePolicyOnce.Do(func() {
		detectedImmutable, reason := detectImmutableSystem()
		immutablePolicy = immutableCommandPolicy{
			ImmutableSystem: detectedImmutable,
			ImmutableReason: reason,
			BlockedCommands: []string{"greeter install", "greeter enable", "setup"},
			Message:         "This command is disabled on immutable/image-based systems. Use your distro-native workflow for system-level changes.",
		}

		var defaultPolicy cliPolicyFile
		if err := json.Unmarshal(defaultCLIPolicyJSON, &defaultPolicy); err != nil {
			immutablePolicyErr = fmt.Errorf("failed to parse embedded default CLI policy: %w", err)
			return
		}
		if defaultPolicy.BlockedCommands != nil {
			immutablePolicy.BlockedCommands = normalizeBlockedCommands(*defaultPolicy.BlockedCommands)
		}
		if defaultPolicy.Message != nil {
			msg := strings.TrimSpace(*defaultPolicy.Message)
			if msg != "" {
				immutablePolicy.Message = msg
			}
		}

		if err := mergePolicyFile(&immutablePolicy, cliPolicyPackagedPath); err != nil {
			immutablePolicyErr = err
			return
		}
		if err := mergePolicyFile(&immutablePolicy, cliPolicyAdminPath); err != nil {
			immutablePolicyErr = err
			return
		}
	})

	if immutablePolicyErr != nil {
		return nil, immutablePolicyErr
	}
	return &immutablePolicy, nil
}

func requireMutableSystemCommand(cmd *cobra.Command, _ []string) error {
	policy, err := getImmutablePolicy()
	if err != nil {
		return err
	}
	if !policy.ImmutableSystem {
		return nil
	}

	commandPath := normalizeCommandSpec(cmd.CommandPath())
	if !commandBlockedByPolicy(commandPath, policy.BlockedCommands) {
		return nil
	}

	reason := ""
	if policy.ImmutableReason != "" {
		reason = "Detected immutable system: " + policy.ImmutableReason + "\n"
	}

	return fmt.Errorf("%s%s\nCommand: dms %s\nPolicy files:\n  %s\n  %s", reason, policy.Message, commandPath, cliPolicyPackagedPath, cliPolicyAdminPath)
}

// preRunPrivileged combines the immutable-system check with a privesc tool
// selection prompt (shown only when multiple tools are available and the
// $DMS_PRIVESC env var isn't set).
func preRunPrivileged(cmd *cobra.Command, args []string) error {
	if err := requireMutableSystemCommand(cmd, args); err != nil {
		return err
	}
	if _, err := privesc.PromptCLI(os.Stdout, os.Stdin); err != nil {
		return err
	}
	return nil
}
