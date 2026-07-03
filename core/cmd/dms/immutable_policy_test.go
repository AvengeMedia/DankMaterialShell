package main

import (
	"encoding/json"
	"testing"
)

func TestDefaultImmutablePolicyAllowsSyncButBlocksEnable(t *testing.T) {
	var policyFile cliPolicyFile
	if err := json.Unmarshal(defaultCLIPolicyJSON, &policyFile); err != nil {
		t.Fatalf("failed to parse embedded CLI policy: %v", err)
	}
	if policyFile.BlockedCommands == nil {
		t.Fatal("embedded CLI policy has no blocked_commands")
	}

	blocked := normalizeBlockedCommands(*policyFile.BlockedCommands)
	if !commandBlockedByPolicy("greeter enable", blocked) {
		t.Fatal("expected greeter enable to remain blocked on immutable/image-based systems")
	}
	if commandBlockedByPolicy("greeter sync", blocked) {
		t.Fatal("expected greeter sync to remain available on immutable/image-based systems")
	}
}
