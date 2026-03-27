package main

import (
	"errors"
	"reflect"
	"testing"

	sharedpam "github.com/AvengeMedia/DankMaterialShell/core/internal/pam"
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
