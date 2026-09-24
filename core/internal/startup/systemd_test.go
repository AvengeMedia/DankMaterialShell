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

type systemdCall struct {
	name    string
	enabled bool
}

type fakeSystemd struct {
	units []SystemdUnit
	err   error
	calls []systemdCall
}

func (f *fakeSystemd) List(context.Context) ([]SystemdUnit, error) {
	return f.units, f.err
}

func (f *fakeSystemd) SetEnabled(_ context.Context, name string, enabled bool) error {
	f.calls = append(f.calls, systemdCall{name: name, enabled: enabled})
	return f.err
}

func applicationUnit(name, description, execStart string) SystemdUnit {
	return SystemdUnit{
		Name: name, Description: description, ExecStart: execStart,
		LoadState: "loaded", UnitFileState: "enabled",
		FragmentPath:        "/usr/lib/systemd/user/" + name,
		InstallTargets:      []string{"graphical-session.target"},
		DefaultDependencies: true,
	}
}

func TestParseSystemdShowRecords(t *testing.T) {
	data := []byte("ExecStart={ path=/usr/bin/first ; argv[]=/usr/bin/first ; }\n" +
		"Description=First application\n" +
		"Id=first.service\n" +
		"LoadState=loaded\n" +
		"UnitFileState=enabled\n" +
		"FragmentPath=/usr/lib/systemd/user/first.service\n" +
		"SourcePath=/home/user/.config/systemd/user/first.service\n" +
		"Before=shutdown.target graphical-session.target\n" +
		"Requires=basic.target\n" +
		"Requisite=session.target\n" +
		"BindsTo=desktop.target\n" +
		"PartOf=graphical-session.target\n" +
		"RequiredBy=app.target\n" +
		"Transient=yes\n" +
		"DefaultDependencies=no\n\n" +
		"\n" +
		"ExecStart={ path=/usr/bin/incomplete ; }\n" +
		"Description=Missing ID\n\n" +
		"ExecStart={ path=/usr/bin/second ; argv[]=/usr/bin/second ; }\n" +
		"Id=second.service\n" +
		"Description=Second application\n\n" +
		"ExecStart={ path=/usr/bin/last ; argv[]=/usr/bin/last ; }\n" +
		"Description=Last application\n" +
		"Id=last.service")

	units := parseSystemdShow(data)
	require.Len(t, units, 3)
	assert.Equal(t, SystemdUnit{
		Name: "first.service", Description: "First application", LoadState: "loaded", UnitFileState: "enabled",
		FragmentPath: "/usr/lib/systemd/user/first.service", SourcePath: "/home/user/.config/systemd/user/first.service",
		ExecStart: "{ path=/usr/bin/first ; argv[]=/usr/bin/first ; }",
		Before:    []string{"shutdown.target", "graphical-session.target"}, Requires: []string{"basic.target"},
		Requisite: []string{"session.target"}, BindsTo: []string{"desktop.target"},
		PartOf: []string{"graphical-session.target"}, RequiredBy: []string{"app.target"},
		Transient: true, DefaultDependencies: false,
	}, units[0])
	assert.Equal(t, "{ path=/usr/bin/second ; argv[]=/usr/bin/second ; }", units[1].ExecStart)
	assert.True(t, units[1].DefaultDependencies)
	assert.Equal(t, "last.service", units[2].Name)
	assert.Equal(t, "Last application", units[2].Description)
	assert.Equal(t, "{ path=/usr/bin/last ; argv[]=/usr/bin/last ; }", units[2].ExecStart)
}

func TestSystemdApplicationClassifierAllowsIdentifiableApps(t *testing.T) {
	applications := []Application{
		{ID: "com.docker.DockerDesktop.desktop", Name: "Docker Desktop", Exec: "/opt/docker-desktop/bin/docker-desktop", Icon: "docker-desktop"},
		{ID: "md.obsidian.Obsidian.desktop", Name: "Obsidian", Exec: "obsidian", Icon: "obsidian"},
	}
	units := []SystemdUnit{
		applicationUnit("docker-desktop.service", "Docker Desktop", "{ path=/opt/docker-desktop/bin/com.docker.backend ; argv[]=/opt/docker-desktop/bin/com.docker.backend ; }"),
		applicationUnit("brain-obsidian.service", "Brain OS Obsidian supervisor", "{ path=/home/user/obsidian-supervisor.sh ; argv[]=/home/user/obsidian-supervisor.sh ; }"),
	}

	for _, unit := range units {
		entry, category := classifySystemdUnit(unit, applications)
		assert.Equal(t, CategoryApplication, category, unit.Name)
		assert.True(t, entry.Mutable, unit.Name)
		assert.Equal(t, SourceSystemd, entry.Source, unit.Name)
	}
}

func TestSystemdApplicationClassifierProtectsInfrastructure(t *testing.T) {
	applications := []Application{{ID: "org.example.Foo.desktop", Name: "Foo", Exec: "/usr/bin/foo", Icon: "foo"}}
	protected := []SystemdUnit{
		applicationUnit("dms.service", "DMS", "{ path=/usr/bin/dms ; }"),
		applicationUnit("pipewire.service", "PipeWire", "{ path=/usr/bin/pipewire ; }"),
		applicationUnit("wireplumber.service", "WirePlumber", "{ path=/usr/bin/wireplumber ; }"),
		applicationUnit("dbus-broker.service", "D-Bus Broker", "{ path=/usr/bin/dbus-broker-launch ; }"),
		applicationUnit("xdg-user-dirs.service", "User directories", "{ path=/usr/bin/xdg-user-dirs-update ; }"),
		applicationUnit("systemd-tmpfiles-setup.service", "Systemd tmpfiles", "{ path=/usr/lib/systemd/systemd-tmpfiles ; }"),
		applicationUnit("hyprland-session.service", "Hyprland session", "{ path=/usr/bin/Hyprland ; }"),
		applicationUnit("foo.socket", "Foo", "{ path=/usr/bin/foo ; }"),
		applicationUnit("foo.timer", "Foo", "{ path=/usr/bin/foo ; }"),
		applicationUnit("foo.target", "Foo", "{ path=/usr/bin/foo ; }"),
	}
	generated := applicationUnit("foo.service", "Foo", "{ path=/usr/bin/foo ; }")
	generated.FragmentPath = "/run/user/1000/systemd/generator/foo.service"
	protected = append(protected, generated)
	transient := applicationUnit("foo.service", "Foo", "{ path=/usr/bin/foo ; }")
	transient.Transient = true
	protected = append(protected, transient)
	critical := applicationUnit("foo.service", "Foo", "{ path=/usr/bin/foo ; }")
	critical.RequiredBy = []string{"graphical-session.target"}
	protected = append(protected, critical)
	masked := applicationUnit("foo.service", "Foo", "{ path=/usr/bin/foo ; }")
	masked.UnitFileState = "masked"
	protected = append(protected, masked)

	for _, unit := range protected {
		_, category := classifySystemdUnit(unit, applications)
		assert.Equal(t, CategoryProtected, category, unit.Name)
	}
}

func TestSystemdClassifierRequiresApplicationEvidence(t *testing.T) {
	unit := applicationUnit("unknown-background.service", "Unknown background task", "{ path=/usr/bin/unknown-background ; }")
	_, category := classifySystemdUnit(unit, nil)
	assert.Equal(t, CategoryProtected, category)
}

func TestSystemdClassifierRejectsWeakSharedWord(t *testing.T) {
	unit := applicationUnit("media-indexer.service", "Media indexer", "{ path=/usr/bin/media-indexer ; }")
	applications := []Application{{ID: "org.example.MediaPlayer.desktop", Name: "Media Player", Exec: "/usr/bin/media-player"}}

	_, category := classifySystemdUnit(unit, applications)
	assert.Equal(t, CategoryProtected, category)
}

func TestProtectedSystemdUnitCannotBeDisabledDirectly(t *testing.T) {
	backend := &fakeSystemd{units: []SystemdUnit{applicationUnit("dms.service", "Dank Material Shell", "{ path=/usr/bin/dms ; }")}}
	manager := &Manager{
		userConfigDir: t.TempDir(), systemd: backend,
		applications: []Application{{ID: "dms.desktop", Name: "Dank Material Shell", Exec: "/usr/bin/dms"}},
	}

	err := manager.SetEnabled(context.Background(), "systemd:dms.service", false)
	assert.True(t, errors.Is(err, ErrProtected))
	assert.Empty(t, backend.calls)
}

func TestApplicationSystemdUnitCanBeDisabled(t *testing.T) {
	backend := &fakeSystemd{units: []SystemdUnit{applicationUnit("docker-desktop.service", "Docker Desktop", "{ path=/opt/docker-desktop/bin/com.docker.backend ; }")}}
	manager := &Manager{
		userConfigDir: t.TempDir(), systemd: backend,
		applications: []Application{{ID: "com.docker.DockerDesktop.desktop", Name: "Docker Desktop", Exec: "/opt/docker-desktop/bin/docker-desktop"}},
	}

	require.NoError(t, manager.SetEnabled(context.Background(), "systemd:docker-desktop.service", false))
	assert.Equal(t, []systemdCall{{name: "docker-desktop.service", enabled: false}}, backend.calls)
}

func TestCommandSystemdDoesNotChangeRuntimeState(t *testing.T) {
	binDir := t.TempDir()
	argsPath := filepath.Join(t.TempDir(), "args")
	script := "#!/bin/sh\nprintf '%s\\n' \"$@\" > \"$DMS_STARTUP_TEST_ARGS\"\n"
	require.NoError(t, os.WriteFile(filepath.Join(binDir, "systemctl"), []byte(script), 0o755))
	t.Setenv("PATH", binDir+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("DMS_STARTUP_TEST_ARGS", argsPath)

	require.NoError(t, (commandSystemd{}).SetEnabled(context.Background(), "example.service", false))
	data, err := os.ReadFile(argsPath)
	require.NoError(t, err)
	assert.Equal(t, "--user\ndisable\n--\nexample.service\n", string(data))
	assert.NotContains(t, string(data), "--now")
}
