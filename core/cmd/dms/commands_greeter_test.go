package main

import (
	"errors"
	"reflect"
	"strings"
	"testing"

	sharedpam "github.com/AvengeMedia/DankMaterialShell/core/internal/pam"
	"github.com/spf13/cobra"
)

func TestSyncGreeterConfigsAndAuthDelegatesSharedAuth(t *testing.T) {
	origGreeterConfigSyncFn := greeterConfigSyncFn
	origSharedAuthSyncFn := sharedAuthSyncFn
	t.Cleanup(func() {
		greeterConfigSyncFn = origGreeterConfigSyncFn
		sharedAuthSyncFn = origSharedAuthSyncFn
	})

	var calls []string
	greeterConfigSyncFn = func(dmsPath, compositor string, logFunc func(string), sudoPassword string) error {
		if dmsPath != "/tmp/dms" {
			t.Fatalf("unexpected dmsPath %q", dmsPath)
		}
		if compositor != "niri" {
			t.Fatalf("unexpected compositor %q", compositor)
		}
		if sudoPassword != "" {
			t.Fatalf("expected empty sudoPassword, got %q", sudoPassword)
		}
		calls = append(calls, "configs")
		return nil
	}

	var gotOptions sharedpam.SyncAuthOptions
	sharedAuthSyncFn = func(logFunc func(string), sudoPassword string, options sharedpam.SyncAuthOptions) error {
		if sudoPassword != "" {
			t.Fatalf("expected empty sudoPassword, got %q", sudoPassword)
		}
		gotOptions = options
		calls = append(calls, "auth")
		return nil
	}

	err := syncGreeterConfigsAndAuth("/tmp/dms", "niri", func(string) {}, sharedpam.SyncAuthOptions{
		ForceGreeterAuth: true,
	}, func() {
		calls = append(calls, "before-auth")
	})
	if err != nil {
		t.Fatalf("syncGreeterConfigsAndAuth returned error: %v", err)
	}

	wantCalls := []string{"configs", "before-auth", "auth"}
	if !reflect.DeepEqual(calls, wantCalls) {
		t.Fatalf("call order = %v, want %v", calls, wantCalls)
	}
	if !gotOptions.ForceGreeterAuth {
		t.Fatalf("expected ForceGreeterAuth to be true, got %+v", gotOptions)
	}
}

func TestSyncGreeterConfigsAndAuthStopsOnConfigError(t *testing.T) {
	origGreeterConfigSyncFn := greeterConfigSyncFn
	origSharedAuthSyncFn := sharedAuthSyncFn
	t.Cleanup(func() {
		greeterConfigSyncFn = origGreeterConfigSyncFn
		sharedAuthSyncFn = origSharedAuthSyncFn
	})

	greeterConfigSyncFn = func(string, string, func(string), string) error {
		return errors.New("config sync failed")
	}

	authCalled := false
	sharedAuthSyncFn = func(func(string), string, sharedpam.SyncAuthOptions) error {
		authCalled = true
		return nil
	}

	err := syncGreeterConfigsAndAuth("/tmp/dms", "niri", func(string) {}, sharedpam.SyncAuthOptions{}, nil)
	if err == nil || err.Error() != "config sync failed" {
		t.Fatalf("expected config sync error, got %v", err)
	}
	if authCalled {
		t.Fatal("expected auth sync not to run after config sync failure")
	}
}

func TestGreeterStatusStateDirUsesNixOSDefault(t *testing.T) {
	if got := greeterStatusStateDir("", true); got != nixOSGreeterStateDir {
		t.Fatalf("greeterStatusStateDir() = %q, want %q", got, nixOSGreeterStateDir)
	}
}

func TestGreeterStatusStateDirHonorsExplicitOverrideOnNixOS(t *testing.T) {
	command := "dms-greeter --cache-dir /srv/dms-greeter --command niri"
	if got := greeterStatusStateDir(command, true); got != "/srv/dms-greeter" {
		t.Fatalf("greeterStatusStateDir() = %q, want %q", got, "/srv/dms-greeter")
	}
}

func TestRejectNixOSGreeterMutationBlocksImperativeCommands(t *testing.T) {
	origGreeterIsNixOSFn := greeterIsNixOSFn
	greeterIsNixOSFn = func() bool { return true }
	t.Cleanup(func() {
		greeterIsNixOSFn = origGreeterIsNixOSFn
	})

	for _, commandName := range []string{"install", "enable", "sync", "uninstall"} {
		t.Run(commandName, func(t *testing.T) {
			root := &cobra.Command{Use: "dms"}
			greeterCommand := &cobra.Command{Use: "greeter"}
			mutationCommand := &cobra.Command{Use: commandName}
			root.AddCommand(greeterCommand)
			greeterCommand.AddCommand(mutationCommand)

			err := rejectNixOSGreeterMutation(mutationCommand)
			if err == nil {
				t.Fatalf("expected NixOS greeter %s to be rejected", commandName)
			}
			if !strings.Contains(err.Error(), "dms greeter "+commandName+" is disabled on NixOS") {
				t.Fatalf("unexpected error: %v", err)
			}
			if strings.Contains(err.Error(), "/var/cache/dms-greeter") {
				t.Fatalf("NixOS remediation should not recommend the non-NixOS cache path: %v", err)
			}
		})
	}
}

func TestRejectNixOSGreeterMutationAllowsOtherDistros(t *testing.T) {
	origGreeterIsNixOSFn := greeterIsNixOSFn
	greeterIsNixOSFn = func() bool { return false }
	t.Cleanup(func() {
		greeterIsNixOSFn = origGreeterIsNixOSFn
	})

	if err := rejectNixOSGreeterMutation(&cobra.Command{Use: "sync"}); err != nil {
		t.Fatalf("expected non-NixOS greeter command to be allowed, got %v", err)
	}
}
