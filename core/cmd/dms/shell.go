package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server"
)

type ipcTargets map[string][]string

var isSessionManaged bool

func execDetachedRestart(targetPID int) {
	selfPath, err := os.Executable()
	if err != nil {
		return
	}

	cmd := exec.Command(selfPath, "restart-detached", strconv.Itoa(targetPID))
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Setsid: true,
	}
	cmd.Start()
}

func runDetachedRestart(targetPIDStr string) {
	targetPID, err := strconv.Atoi(targetPIDStr)
	if err != nil {
		return
	}

	time.Sleep(200 * time.Millisecond)

	proc, err := os.FindProcess(targetPID)
	if err == nil {
		proc.Signal(syscall.SIGTERM)
	}

	time.Sleep(500 * time.Millisecond)

	killShell()
	runShellDaemon(false)
}

func getRuntimeDir() string {
	if runtime := os.Getenv("XDG_RUNTIME_DIR"); runtime != "" {
		return runtime
	}
	return os.TempDir()
}

func hasSystemdRun() bool {
	_, err := exec.LookPath("systemd-run")
	return err == nil
}

func getPIDFilePath() string {
	return filepath.Join(getRuntimeDir(), fmt.Sprintf("danklinux-%d.pid", os.Getpid()))
}

func writePIDFile(childPID int) error {
	pidFile := getPIDFilePath()
	return os.WriteFile(pidFile, []byte(strconv.Itoa(childPID)), 0o644)
}

func removePIDFile() {
	pidFile := getPIDFilePath()
	os.Remove(pidFile)
}

func getAllDMSPIDs() []int {
	dir := getRuntimeDir()
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}

	var pids []int

	for _, entry := range entries {
		if !strings.HasPrefix(entry.Name(), "danklinux-") || !strings.HasSuffix(entry.Name(), ".pid") {
			continue
		}

		pidFile := filepath.Join(dir, entry.Name())
		data, err := os.ReadFile(pidFile)
		if err != nil {
			continue
		}

		childPID, err := strconv.Atoi(strings.TrimSpace(string(data)))
		if err != nil {
			os.Remove(pidFile)
			continue
		}

		// Check if the child process is still alive
		proc, err := os.FindProcess(childPID)
		if err != nil {
			os.Remove(pidFile)
			continue
		}

		if err := proc.Signal(syscall.Signal(0)); err != nil {
			// Process is dead, remove stale PID file
			os.Remove(pidFile)
			continue
		}

		pids = append(pids, childPID)

		// Also get the parent PID from the filename
		parentPIDStr := strings.TrimPrefix(entry.Name(), "danklinux-")
		parentPIDStr = strings.TrimSuffix(parentPIDStr, ".pid")
		if parentPID, err := strconv.Atoi(parentPIDStr); err == nil {
			// Check if parent is still alive
			if parentProc, err := os.FindProcess(parentPID); err == nil {
				if err := parentProc.Signal(syscall.Signal(0)); err == nil {
					pids = append(pids, parentPID)
				}
			}
		}
	}

	return pids
}

func runShellInteractive(session bool) {
	isSessionManaged = session
	go printASCII()
	fmt.Fprintf(os.Stderr, "dms %s\n", Version)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	socketPath := server.GetSocketPath()

	configStateFile := filepath.Join(getRuntimeDir(), "danklinux.path")
	if err := os.WriteFile(configStateFile, []byte(configPath), 0o644); err != nil {
		log.Warnf("Failed to write config state file: %v", err)
	}
	defer os.Remove(configStateFile)

	errChan := make(chan error, 2)

	go func() {
		defer func() {
			if r := recover(); r != nil {
				errChan <- fmt.Errorf("server panic: %v", r)
			}
		}()
		if err := server.Start(false); err != nil {
			errChan <- fmt.Errorf("server error: %w", err)
		}
	}()

	log.Infof("Spawning quickshell with -p %s", configPath)

	cmd := exec.CommandContext(ctx, "qs", "-p", configPath)
	cmd.Env = append(os.Environ(), "DMS_SOCKET="+socketPath)
	if qtRules := log.GetQtLoggingRules(); qtRules != "" {
		cmd.Env = append(cmd.Env, "QT_LOGGING_RULES="+qtRules)
	}

	if isSessionManaged && hasSystemdRun() {
		cmd.Env = append(cmd.Env, "DMS_DEFAULT_LAUNCH_PREFIX=systemd-run --user --scope")
	}

	homeDir, err := os.UserHomeDir()
	if err == nil && os.Getenv("DMS_DISABLE_HOT_RELOAD") == "" {
		if !strings.HasPrefix(configPath, homeDir) {
			cmd.Env = append(cmd.Env, "DMS_DISABLE_HOT_RELOAD=1")
		}
	}

	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Start(); err != nil {
		log.Fatalf("Error starting quickshell: %v", err)
	}

	// Write PID file for the quickshell child process
	if err := writePIDFile(cmd.Process.Pid); err != nil {
		log.Warnf("Failed to write PID file: %v", err)
	}
	defer removePIDFile()

	defer func() {
		if cmd.Process != nil {
			cmd.Process.Signal(syscall.SIGTERM)
		}
	}()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM, syscall.SIGUSR1)

	go func() {
		if err := cmd.Wait(); err != nil {
			errChan <- fmt.Errorf("quickshell exited: %w", err)
		} else {
			errChan <- fmt.Errorf("quickshell exited")
		}
	}()

	for {
		select {
		case sig := <-sigChan:
			// Handle SIGUSR1 restart for non-session managed processes
			if sig == syscall.SIGUSR1 && !isSessionManaged {
				log.Infof("Received SIGUSR1, spawning detached restart process...")
				execDetachedRestart(os.Getpid())
				// Exit immediately to avoid race conditions with detached restart
				return
			}

			// All other signals: clean shutdown
			log.Infof("\nReceived signal %v, shutting down...", sig)
			cancel()
			cmd.Process.Signal(syscall.SIGTERM)
			os.Remove(socketPath)
			return

		case err := <-errChan:
			log.Error(err)
			cancel()
			if cmd.Process != nil {
				cmd.Process.Signal(syscall.SIGTERM)
			}
			os.Remove(socketPath)
			os.Exit(1)
		}
	}
}

func restartShell() {
	pids := getAllDMSPIDs()

	if len(pids) == 0 {
		log.Info("No running DMS shell instances found. Starting daemon...")
		runShellDaemon(false)
		return
	}

	currentPid := os.Getpid()
	uniquePids := make(map[int]bool)

	for _, pid := range pids {
		if pid != currentPid {
			uniquePids[pid] = true
		}
	}

	for pid := range uniquePids {
		proc, err := os.FindProcess(pid)
		if err != nil {
			log.Errorf("Error finding process %d: %v", pid, err)
			continue
		}

		if err := proc.Signal(syscall.Signal(0)); err != nil {
			continue
		}

		if err := proc.Signal(syscall.SIGUSR1); err != nil {
			log.Errorf("Error sending SIGUSR1 to process %d: %v", pid, err)
		} else {
			log.Infof("Sent SIGUSR1 to DMS process with PID %d", pid)
		}
	}
}

func killShell() {
	// Get all tracked DMS PIDs from PID files
	pids := getAllDMSPIDs()

	if len(pids) == 0 {
		log.Info("No running DMS shell instances found.")
		return
	}

	currentPid := os.Getpid()
	uniquePids := make(map[int]bool)

	// Deduplicate and filter out current process
	for _, pid := range pids {
		if pid != currentPid {
			uniquePids[pid] = true
		}
	}

	// Kill all tracked processes
	for pid := range uniquePids {
		proc, err := os.FindProcess(pid)
		if err != nil {
			log.Errorf("Error finding process %d: %v", pid, err)
			continue
		}

		// Check if process is still alive before killing
		if err := proc.Signal(syscall.Signal(0)); err != nil {
			continue
		}

		if err := proc.Kill(); err != nil {
			log.Errorf("Error killing process %d: %v", pid, err)
		} else {
			log.Infof("Killed DMS process with PID %d", pid)
		}
	}

	// Clean up any remaining PID files
	dir := getRuntimeDir()
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}

	for _, entry := range entries {
		if strings.HasPrefix(entry.Name(), "danklinux-") && strings.HasSuffix(entry.Name(), ".pid") {
			pidFile := filepath.Join(dir, entry.Name())
			os.Remove(pidFile)
		}
	}
}

func runShellDaemon(session bool) {
	isSessionManaged = session
	// Check if this is the daemon child process by looking for the hidden flag
	isDaemonChild := false
	for _, arg := range os.Args {
		if arg == "--daemon-child" {
			isDaemonChild = true
			break
		}
	}

	if !isDaemonChild {
		fmt.Fprintf(os.Stderr, "dms %s\n", Version)

		cmd := exec.Command(os.Args[0], "run", "-d", "--daemon-child")
		cmd.Env = os.Environ()

		cmd.SysProcAttr = &syscall.SysProcAttr{
			Setsid: true,
		}

		if err := cmd.Start(); err != nil {
			log.Fatalf("Error starting daemon: %v", err)
		}

		log.Infof("DMS shell daemon started (PID: %d)", cmd.Process.Pid)
		return
	}

	fmt.Fprintf(os.Stderr, "dms %s\n", Version)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	socketPath := server.GetSocketPath()

	configStateFile := filepath.Join(getRuntimeDir(), "danklinux.path")
	if err := os.WriteFile(configStateFile, []byte(configPath), 0o644); err != nil {
		log.Warnf("Failed to write config state file: %v", err)
	}
	defer os.Remove(configStateFile)

	errChan := make(chan error, 2)

	go func() {
		defer func() {
			if r := recover(); r != nil {
				errChan <- fmt.Errorf("server panic: %v", r)
			}
		}()
		server.CLIVersion = Version
		if err := server.Start(false); err != nil {
			errChan <- fmt.Errorf("server error: %w", err)
		}
	}()

	log.Infof("Spawning quickshell with -p %s", configPath)

	cmd := exec.CommandContext(ctx, "qs", "-p", configPath)
	cmd.Env = append(os.Environ(), "DMS_SOCKET="+socketPath)
	if qtRules := log.GetQtLoggingRules(); qtRules != "" {
		cmd.Env = append(cmd.Env, "QT_LOGGING_RULES="+qtRules)
	}

	if isSessionManaged && hasSystemdRun() {
		cmd.Env = append(cmd.Env, "DMS_DEFAULT_LAUNCH_PREFIX=systemd-run --user --scope")
	}

	homeDir, err := os.UserHomeDir()
	if err == nil && os.Getenv("DMS_DISABLE_HOT_RELOAD") == "" {
		if !strings.HasPrefix(configPath, homeDir) {
			cmd.Env = append(cmd.Env, "DMS_DISABLE_HOT_RELOAD=1")
		}
	}

	devNull, err := os.OpenFile("/dev/null", os.O_RDWR, 0)
	if err != nil {
		log.Fatalf("Error opening /dev/null: %v", err)
	}
	defer devNull.Close()

	cmd.Stdin = devNull
	cmd.Stdout = devNull
	cmd.Stderr = devNull

	if err := cmd.Start(); err != nil {
		log.Fatalf("Error starting daemon: %v", err)
	}

	// Write PID file for the quickshell child process
	if err := writePIDFile(cmd.Process.Pid); err != nil {
		log.Warnf("Failed to write PID file: %v", err)
	}
	defer removePIDFile()

	defer func() {
		if cmd.Process != nil {
			cmd.Process.Signal(syscall.SIGTERM)
		}
	}()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM, syscall.SIGUSR1)

	go func() {
		if err := cmd.Wait(); err != nil {
			errChan <- fmt.Errorf("quickshell exited: %w", err)
		} else {
			errChan <- fmt.Errorf("quickshell exited")
		}
	}()

	for {
		select {
		case sig := <-sigChan:
			// Handle SIGUSR1 restart for non-session managed processes
			if sig == syscall.SIGUSR1 && !isSessionManaged {
				log.Infof("Received SIGUSR1, spawning detached restart process...")
				execDetachedRestart(os.Getpid())
				// Exit immediately to avoid race conditions with detached restart
				return
			}

			// All other signals: clean shutdown
			cancel()
			cmd.Process.Signal(syscall.SIGTERM)
			os.Remove(socketPath)
			return

		case <-errChan:
			cancel()
			if cmd.Process != nil {
				cmd.Process.Signal(syscall.SIGTERM)
			}
			os.Remove(socketPath)
			os.Exit(1)
		}
	}
}

func parseTargetsFromIPCShowOutput(output string) ipcTargets {
	targets := map[string][]string{}
	var currentTarget string
	for _, line := range strings.Split(output, "\n") {
		if strings.HasPrefix(line, "target ") {
			currentTarget = strings.TrimSpace(strings.TrimPrefix(line, "target "))
		}
		if strings.HasPrefix(line, "  function") && currentTarget != "" {
			currentFunc := strings.TrimPrefix(line, "  function ")
			currentFunc = strings.SplitN(currentFunc, "(", 2)[0]
			targets[currentTarget] = append(targets[currentTarget], currentFunc)
		}
	}
	return targets
}

func getShellIPCCompletions(args []string, toComplete string) []string {
	cmdArgs := []string{"-p", configPath, "ipc", "show"}
	cmd := exec.Command("qs", cmdArgs...)
	var targets ipcTargets

	if output, err := cmd.Output(); err == nil {
		log.Debugf("IPC show output: %s", string(output))
		targets = parseTargetsFromIPCShowOutput(string(output))
	} else {
		log.Debugf("Error getting IPC show output for completions: %v", err)
		return nil
	}

	if len(args) > 0 && args[0] == "call" {
		args = args[1:]
	}

	if len(args) == 0 {
		targetNames := make([]string, 0)
		targetNames = append(targetNames, "call")
		for k := range targets {
			targetNames = append(targetNames, k)
		}
		return targetNames
	}

	return targets[args[0]]
}

func runShellIPCCommand(args []string) {
	if len(args) == 0 {
		log.Error("IPC command requires arguments")
		log.Info("Usage: dms ipc <command> [args...]")
		os.Exit(1)
	}

	if args[0] != "call" {
		args = append([]string{"call"}, args...)
	}

	cmdArgs := append([]string{"-p", configPath, "ipc"}, args...)
	cmd := exec.Command("qs", cmdArgs...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		log.Fatalf("Error running IPC command: %v", err)
	}
}
