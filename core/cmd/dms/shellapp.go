package main

import (
	"context"
	"fmt"
	"os"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/config"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/gpu"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/shellembed"
	"github.com/AvengeMedia/dankgo/shellapp"
)

var shellApp = shellapp.New(shellapp.Config{
	ID:                     "danklinux",
	EnvPrefix:              "DMS",
	QSAppID:                "com.danklinux.dms",
	Version:                Version,
	Embedded:               embeddedShell{},
	Boot:                   bootBackend,
	PreLaunch:              preLaunch,
	ExtraEnv:               dmsExtraEnv,
	OnUIExit:               logStartupFailure,
	SessionRestartExitCode: dmsSessionRestartExitCode,
	TryManagedRestart:      trySystemdRestart,
})

type embeddedShell struct{}

func (embeddedShell) Available() bool { return shellembed.Available() }

func (embeddedShell) Extract(baseDir string) (string, error) { return shellembed.Extract(baseDir) }

func (embeddedShell) Prune(baseDir, keep string) { shellembed.Prune(baseDir, keep) }

type dmsBackend struct {
	srv  *server.Server
	done chan error
}

func (b *dmsBackend) SocketPath() string { return b.srv.SocketPath() }

func (b *dmsBackend) Close() { b.srv.Close() }

func (b *dmsBackend) Done() <-chan error { return b.done }

func bootBackend(ctx context.Context) (shellapp.Backend, error) {
	config.CleanupStrayHyprlandConfFile(log.Infof)
	server.CLIVersion = Version

	srv := server.New()
	if err := srv.Listen(); err != nil {
		return nil, err
	}

	backend := &dmsBackend{srv: srv, done: make(chan error, 1)}
	go func() {
		defer func() {
			if r := recover(); r != nil {
				backend.done <- fmt.Errorf("server panic: %v", r)
			}
		}()
		backend.done <- srv.Serve(false)
	}()

	return backend, nil
}

func preLaunch() {
	go printASCII()
	ensureFontCache()
}

func dmsExtraEnv(string) []string {
	var env []string
	if selfPath, err := os.Executable(); err == nil {
		env = append(env, "DMS_EXECUTABLE="+selfPath)
	}
	if os.Getenv("QSG_USE_SIMPLE_ANIMATION_DRIVER") == "" {
		env = append(env, "QSG_USE_SIMPLE_ANIMATION_DRIVER=1")
	}
	if _, set := os.LookupEnv("MALLOC_CONF"); !set {
		env = append(env, "MALLOC_CONF=thp:never,narenas:4,dirty_decay_ms:3000")
	}
	env = append(env, gpu.EGLVendorEnv()...)
	return env
}
