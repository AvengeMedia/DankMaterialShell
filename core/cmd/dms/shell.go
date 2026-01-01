package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server"
)

type ipcTargets map[string]map[string][]string

// getProcessExitCode returns the exit code from a ProcessState.
// For normal exits, returns the exit code directly.
// For signal termination, returns 128 + signal number (Unix convention).
func getProcessExitCode(state *os.ProcessState) int {
	if state == nil {
		return 1
	}
	if code := state.ExitCode(); code != -1 {
		return code
	}
	// Process was killed by signal - extract signal number
	if status, ok := state.Sys().(syscall.WaitStatus); ok {
		if status.Signaled() {
			return 128 + int(status.Signal())
		}
	}
	return 1
}

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

		proc, err := os.FindProcess(childPID)
		if err != nil {
			os.Remove(pidFile)
			continue
		}

		if err := proc.Signal(syscall.Signal(0)); err != nil {
			os.Remove(pidFile)
			continue
		}

		pids = append(pids, childPID)

		parentPIDStr := strings.TrimPrefix(entry.Name(), "danklinux-")
		parentPIDStr = strings.TrimSuffix(parentPIDStr, ".pid")
		if parentPID, err := strconv.Atoi(parentPIDStr); err == nil {
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

	if os.Getenv("QT_QPA_PLATFORMTHEME") == "" {
		cmd.Env = append(cmd.Env, "QT_QPA_PLATFORMTHEME=gtk3")
	}
	if os.Getenv("QT_QPA_PLATFORMTHEME_QT6") == "" {
		cmd.Env = append(cmd.Env, "QT_QPA_PLATFORMTHEME_QT6=gtk3")
	}
	if os.Getenv("QT_QPA_PLATFORM") == "" {
		cmd.Env = append(cmd.Env, "QT_QPA_PLATFORM=wayland")
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
			if sig == syscall.SIGUSR1 {
				if isSessionManaged {
					log.Infof("Received SIGUSR1, exiting for systemd restart...")
					cancel()
					cmd.Process.Signal(syscall.SIGTERM)
					os.Remove(socketPath)
					os.Exit(1)
				}
				log.Infof("Received SIGUSR1, spawning detached restart process...")
				execDetachedRestart(os.Getpid())
				return
			}

			// Check if qs already crashed before we got SIGTERM (systemd sends SIGTERM when D-Bus name is released)
			select {
			case <-errChan:
				cancel()
				os.Remove(socketPath)
				os.Exit(getProcessExitCode(cmd.ProcessState))
			case <-time.After(500 * time.Millisecond):
			}

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
			os.Exit(getProcessExitCode(cmd.ProcessState))
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
	pids := getAllDMSPIDs()

	if len(pids) == 0 {
		log.Info("No running DMS shell instances found.")
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

		if err := proc.Kill(); err != nil {
			log.Errorf("Error killing process %d: %v", pid, err)
		} else {
			log.Infof("Killed DMS process with PID %d", pid)
		}
	}

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
	isDaemonChild := slices.Contains(os.Args, "--daemon-child")

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

	if os.Getenv("QT_QPA_PLATFORMTHEME") == "" {
		cmd.Env = append(cmd.Env, "QT_QPA_PLATFORMTHEME=gtk3")
	}
	if os.Getenv("QT_QPA_PLATFORMTHEME_QT6") == "" {
		cmd.Env = append(cmd.Env, "QT_QPA_PLATFORMTHEME_QT6=gtk3")
	}
	if os.Getenv("QT_QPA_PLATFORM") == "" {
		cmd.Env = append(cmd.Env, "QT_QPA_PLATFORM=wayland")
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
			if sig == syscall.SIGUSR1 {
				if isSessionManaged {
					log.Infof("Received SIGUSR1, exiting for systemd restart...")
					cancel()
					cmd.Process.Signal(syscall.SIGTERM)
					os.Remove(socketPath)
					os.Exit(1)
				}
				log.Infof("Received SIGUSR1, spawning detached restart process...")
				execDetachedRestart(os.Getpid())
				return
			}

			// Check if qs already crashed before we got SIGTERM (systemd sends SIGTERM when D-Bus name is released)
			select {
			case <-errChan:
				cancel()
				os.Remove(socketPath)
				os.Exit(getProcessExitCode(cmd.ProcessState))
			case <-time.After(500 * time.Millisecond):
			}

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
			os.Exit(getProcessExitCode(cmd.ProcessState))
		}
	}
}

var qsHasAnyDisplay = sync.OnceValue(func() bool {
	out, err := exec.Command("qs", "ipc", "--help").Output()
	if err != nil {
		return false
	}
	return strings.Contains(string(out), "--any-display")
})

func parseTargetsFromIPCShowOutput(output string) ipcTargets {
	targets := make(ipcTargets)
	var currentTarget string
	for line := range strings.SplitSeq(output, "\n") {
		if after, ok := strings.CutPrefix(line, "target "); ok {
			currentTarget = strings.TrimSpace(after)
			targets[currentTarget] = make(map[string][]string)
		}
		if strings.HasPrefix(line, "  function") && currentTarget != "" {
			argsList := []string{}
			currentFunc := strings.TrimPrefix(line, "  function ")
			funcDef := strings.SplitN(currentFunc, "(", 2)
			argList := strings.SplitN(funcDef[1], ")", 2)[0]
			args := strings.Split(argList, ",")
			if len(args) > 0 && strings.TrimSpace(args[0]) != "" {
				argsList = append(argsList, funcDef[0])
				for _, arg := range args {
					argName := strings.SplitN(strings.TrimSpace(arg), ":", 2)[0]
					argsList = append(argsList, argName)
				}
				targets[currentTarget][funcDef[0]] = argsList
			} else {
				targets[currentTarget][funcDef[0]] = make([]string, 0)
			}
		}
	}
	return targets
}

func getShellIPCCompletions(args []string, _ string) []string {
	cmdArgs := []string{"ipc"}
	if qsHasAnyDisplay() {
		cmdArgs = append(cmdArgs, "--any-display")
	}
	cmdArgs = append(cmdArgs, "-p", configPath, "show")
	cmd := exec.Command("qs", cmdArgs...)
	var targets ipcTargets

	if output, err := cmd.Output(); err == nil {
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
	if len(args) == 1 {
		if targetFuncs, ok := targets[args[0]]; ok {
			funcNames := make([]string, 0)
			for k := range targetFuncs {
				funcNames = append(funcNames, k)
			}
			return funcNames
		}
		return nil
	}
	if len(args) <= len(targets[args[0]]) {
		funcArgs := targets[args[0]][args[1]]
		if len(funcArgs) >= len(args) {
			return []string{fmt.Sprintf("[%s]", funcArgs[len(args)-1])}
		}
	}

	return nil
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

	cmdArgs := []string{"ipc"}
	if qsHasAnyDisplay() {
		cmdArgs = append(cmdArgs, "--any-display")
	}
	cmdArgs = append(cmdArgs, "-p", configPath)
	cmdArgs = append(cmdArgs, args...)
	cmd := exec.Command("qs", cmdArgs...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		log.Fatalf("Error running IPC command: %v", err)
	}
}
