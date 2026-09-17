package startup

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func testManager(t *testing.T) (*Manager, string, string, string) {
	t.Helper()
	root := t.TempDir()
	user := filepath.Join(root, "user")
	systemOne := filepath.Join(root, "system-one")
	systemTwo := filepath.Join(root, "system-two")
	return &Manager{
		userConfigDir:    user,
		systemConfigDirs: []string{systemOne, systemTwo},
		currentDesktops:  []string{"dms"},
		applications:     nil,
		systemd:          &fakeSystemd{},
	}, user, systemOne, systemTwo
}

func writeDesktop(t *testing.T, configDir, id, content string) string {
	t.Helper()
	dir := filepath.Join(configDir, "autostart")
	require.NoError(t, os.MkdirAll(dir, 0o755))
	path := filepath.Join(dir, id)
	require.NoError(t, os.WriteFile(path, []byte(content), 0o644))
	return path
}

func desktopContent(name, comment, execLine string) string {
	return "[Desktop Entry]\nType=Application\nName=" + name + "\nComment=" + comment + "\nExec=" + execLine + "\n"
}

func TestListXDGUserAndSystemEntries(t *testing.T) {
	manager, user, system, _ := testManager(t)
	writeDesktop(t, user, "user.desktop", desktopContent("User App", "User comment", "/usr/bin/user-app"))
	writeDesktop(t, system, "system.desktop", desktopContent("System App", "System comment", "/usr/bin/system-app"))

	entries, err := manager.List(context.Background())
	require.NoError(t, err)
	require.Len(t, entries, 2)
	assert.Equal(t, "System App", entries[0].Name)
	assert.Equal(t, SourceXDG, entries[0].Source)
	assert.Equal(t, "User App", entries[1].Name)
	assert.False(t, entries[1].Removable)
}

func TestOnlyDMSCreatedXDGEntriesAreRemovable(t *testing.T) {
	manager, user, _, _ := testManager(t)
	writeDesktop(t, user, "manual.desktop", desktopContent("Manual App", "", "/usr/bin/manual-app"))
	created, err := manager.Add("Managed App", "/usr/bin/managed-app", "")
	require.NoError(t, err)

	entries, err := manager.List(context.Background())
	require.NoError(t, err)
	require.Len(t, entries, 2)
	byID := make(map[string]Entry, len(entries))
	for _, entry := range entries {
		byID[entry.ID] = entry
	}
	assert.False(t, byID["xdg:manual.desktop"].Removable)
	assert.True(t, byID[created.ID].Removable)
	assert.ErrorIs(t, manager.Remove("xdg:manual.desktop"), ErrProtected)
}

func TestListXDGUserOverrideTakesPrecedence(t *testing.T) {
	manager, user, system, _ := testManager(t)
	writeDesktop(t, system, "shared.desktop", desktopContent("System Name", "System comment", "/usr/bin/system-app"))
	writeDesktop(t, user, "shared.desktop", desktopContent("User Name", "User comment", "/usr/bin/user-app"))

	entries, err := manager.List(context.Background())
	require.NoError(t, err)
	require.Len(t, entries, 1)
	assert.Equal(t, "User Name", entries[0].Name)
	assert.Equal(t, "User comment", entries[0].Description)
	assert.False(t, entries[0].Removable)
}

func TestListXDGHiddenOverrideUsesSystemMetadata(t *testing.T) {
	manager, user, system, _ := testManager(t)
	writeDesktop(t, system, "shared.desktop", desktopContent("System Name", "System comment", "/usr/bin/system-app"))
	writeDesktop(t, user, "shared.desktop", "[Desktop Entry]\nType=Application\nHidden=true\n")

	entries, err := manager.List(context.Background())
	require.NoError(t, err)
	require.Len(t, entries, 1)
	assert.Equal(t, "System Name", entries[0].Name)
	assert.False(t, entries[0].Enabled)
}

func TestSetXDGEnabledForUserEntry(t *testing.T) {
	manager, user, _, _ := testManager(t)
	path := writeDesktop(t, user, "user.desktop", desktopContent("User App", "", "/usr/bin/user-app")+"Hidden=true\n")

	require.NoError(t, manager.SetEnabled(context.Background(), "xdg:user.desktop", true))
	data, err := os.ReadFile(path)
	require.NoError(t, err)
	assert.Contains(t, string(data), "Hidden=false")
	assert.Contains(t, string(data), "X-GNOME-Autostart-enabled=true")

	entries, err := manager.List(context.Background())
	require.NoError(t, err)
	require.Len(t, entries, 1)
	assert.True(t, entries[0].Enabled)
}

func TestDisableAndEnableSystemXDGEntry(t *testing.T) {
	manager, user, system, _ := testManager(t)
	systemPath := writeDesktop(t, system, "system.desktop", desktopContent("System App", "", "/usr/bin/system-app"))
	userPath := filepath.Join(user, "autostart", "system.desktop")

	require.NoError(t, manager.SetEnabled(context.Background(), "xdg:system.desktop", false))
	override, err := os.ReadFile(userPath)
	require.NoError(t, err)
	assert.Contains(t, string(override), "Hidden=true")
	assert.Contains(t, string(override), managedOverrideKey+"=true")
	systemData, err := os.ReadFile(systemPath)
	require.NoError(t, err)
	assert.NotContains(t, string(systemData), "Hidden=true")

	entries, err := manager.List(context.Background())
	require.NoError(t, err)
	require.Len(t, entries, 1)
	assert.False(t, entries[0].Enabled)

	require.NoError(t, manager.SetEnabled(context.Background(), "xdg:system.desktop", true))
	_, err = os.Stat(userPath)
	assert.ErrorIs(t, err, os.ErrNotExist)
}

func TestListXDGSkipsMalformedAndDeduplicates(t *testing.T) {
	manager, user, systemOne, systemTwo := testManager(t)
	writeDesktop(t, user, "broken.desktop", "this is not a desktop entry")
	writeDesktop(t, systemOne, "duplicate.desktop", desktopContent("First", "", "/usr/bin/first"))
	writeDesktop(t, systemTwo, "duplicate.desktop", desktopContent("Second", "", "/usr/bin/second"))

	entries, err := manager.List(context.Background())
	require.NoError(t, err)
	require.Len(t, entries, 1)
	assert.Equal(t, "First", entries[0].Name)
}

func TestMalformedUserEntryStillShadowsSystemEntry(t *testing.T) {
	manager, user, system, _ := testManager(t)
	writeDesktop(t, system, "shared.desktop", desktopContent("System App", "", "/usr/bin/system-app"))
	writeDesktop(t, user, "shared.desktop", "not a desktop entry")

	entries, err := manager.List(context.Background())
	require.NoError(t, err)
	assert.Empty(t, entries)
}

func TestXDGDesktopVisibility(t *testing.T) {
	manager, user, _, _ := testManager(t)
	writeDesktop(t, user, "only.desktop", desktopContent("Only", "", "/usr/bin/only")+"OnlyShowIn=GNOME;\n")
	writeDesktop(t, user, "not.desktop", desktopContent("Not", "", "/usr/bin/not")+"NotShowIn=DMS;\n")
	writeDesktop(t, user, "nodisplay.desktop", desktopContent("Hidden UI", "", "/usr/bin/hidden")+"NoDisplay=true\n")

	entries, err := manager.List(context.Background())
	require.NoError(t, err)
	assert.Empty(t, entries)
}

func TestListXDGProtectsSessionInfrastructure(t *testing.T) {
	manager, _, system, _ := testManager(t)
	writeDesktop(t, system, "vboxclient.desktop", desktopContent("vboxclient", "VirtualBox User Session Services", "/usr/bin/VBoxClient-all"))
	writeDesktop(t, system, "dms.desktop", desktopContent("DMS", "Desktop shell", "/usr/bin/dms"))

	entries, err := manager.List(context.Background())
	require.NoError(t, err)
	assert.Empty(t, entries)
}

func TestListXDGProtectsInfrastructureByDesktopID(t *testing.T) {
	manager, user, _, _ := testManager(t)
	writeDesktop(t, user, "dms.service.desktop", desktopContent("Shell Helper", "", "/usr/bin/helper"))

	entries, err := manager.List(context.Background())
	require.NoError(t, err)
	assert.Empty(t, entries)
}

func TestAddXDGEntryHandlesSpacesAndDuplicateNames(t *testing.T) {
	manager, user, _, _ := testManager(t)
	first, err := manager.Add("My Startup App", "/usr/bin/my-app --flag \"two words\"", "my-app")
	require.NoError(t, err)
	second, err := manager.Add("My Startup App", "/usr/bin/my-app --other", "")
	require.NoError(t, err)

	assert.Equal(t, "xdg:my-startup-app.desktop", first.ID)
	assert.Equal(t, "xdg:my-startup-app-2.desktop", second.ID)
	data, err := os.ReadFile(filepath.Join(user, "autostart", "my-startup-app.desktop"))
	require.NoError(t, err)
	assert.Contains(t, string(data), "Exec=/usr/bin/my-app --flag \"two words\"")
}

func TestXGNOMEAutostartEnabledFalse(t *testing.T) {
	manager, user, _, _ := testManager(t)
	writeDesktop(t, user, "gnome.desktop", desktopContent("GNOME App", "", "/usr/bin/gnome-app")+"X-GNOME-Autostart-enabled=false\n")

	entries, err := manager.List(context.Background())
	require.NoError(t, err)
	require.Len(t, entries, 1)
	assert.False(t, entries[0].Enabled)
}

func TestRemoveRejectsSystemXDGEntry(t *testing.T) {
	manager, _, system, _ := testManager(t)
	writeDesktop(t, system, "system.desktop", desktopContent("System", "", "/usr/bin/system"))
	assert.ErrorIs(t, manager.Remove("xdg:system.desktop"), ErrProtected)
}

func TestSetEnabledRejectsUnknownSource(t *testing.T) {
	manager, _, _, _ := testManager(t)
	assert.True(t, errors.Is(manager.SetEnabled(context.Background(), "service:dms.service", false), ErrProtected))
}

func TestListContinuesWhenSystemdIsUnavailable(t *testing.T) {
	manager, user, _, _ := testManager(t)
	writeDesktop(t, user, "user.desktop", desktopContent("User App", "", "/usr/bin/user-app"))
	manager.systemd = &fakeSystemd{err: errors.New("systemd unavailable")}

	entries, err := manager.List(context.Background())
	require.NoError(t, err)
	require.Len(t, entries, 1)
	assert.Equal(t, "User App", entries[0].Name)
}
