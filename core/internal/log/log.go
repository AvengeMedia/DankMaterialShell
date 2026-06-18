package log

import (
	"io"
	"os"
	"regexp"
	"strings"
	"sync"

	"github.com/charmbracelet/lipgloss"
	cblog "github.com/charmbracelet/log"
	"github.com/mattn/go-isatty"
	"github.com/muesli/termenv"
)

// Logger embeds the Charm Logger and adds Printf/Fatalf
type Logger struct{ *cblog.Logger }

// Printf routes goose/info-style logs through Infof.
func (l *Logger) Printf(format string, v ...any) { l.Infof(format, v...) }

// Fatalf keeps goose’s contract of exiting the program.
func (l *Logger) Fatalf(format string, v ...any) { l.Logger.Fatalf(format, v...) }

var (
	logger     *Logger
	initLogger sync.Once

	logMu     sync.Mutex
	logFile   *os.File
	logStderr io.Writer = os.Stderr

	ansiRe = regexp.MustCompile(`\x1b\[[0-9;]*[a-zA-Z]`)
)

// ansiStripWriter strips ANSI escape sequences before forwarding to w. Used
// for the file sink so colored stderr stays colored while the file stays plain.
type ansiStripWriter struct{ w io.Writer }

func (a *ansiStripWriter) Write(p []byte) (int, error) {
	stripped := ansiRe.ReplaceAll(p, nil)
	if _, err := a.w.Write(stripped); err != nil {
		return 0, err
	}
	return len(p), nil
}

func parseLogLevel(level string) cblog.Level {
	switch strings.ToLower(level) {
	case "debug":
		return cblog.DebugLevel
	case "info":
		return cblog.InfoLevel
	case "warn", "warning":
		return cblog.WarnLevel
	case "error":
		return cblog.ErrorLevel
	case "fatal":
		return cblog.FatalLevel
	default:
		return cblog.InfoLevel
	}
}

func GetQtLoggingRules() string {
	level := os.Getenv("DMS_LOG_LEVEL")
	if level == "" {
		level = "info"
	}

	var rules []string
	switch strings.ToLower(level) {
	case "fatal":
		rules = []string{"*.debug=false", "*.info=false", "*.warning=false", "*.critical=false"}
	case "error":
		rules = []string{"*.debug=false", "*.info=false", "*.warning=false"}
	case "warn", "warning":
		rules = []string{"*.debug=false", "*.info=false"}
	case "info":
		rules = []string{"*.debug=false"}
	case "debug":
		return ""
	default:
		rules = []string{"*.debug=false"}
	}

	return strings.Join(rules, ";")
}

// GetLogger returns a logger instance
func GetLogger() *Logger {
	initLogger.Do(func() {
		styles := cblog.DefaultStyles()
		// Attempt to match the colors used by qml/quickshell logs
		styles.Levels[cblog.FatalLevel] = lipgloss.NewStyle().
			SetString(" FATAL").
			Foreground(lipgloss.Color("1"))
		styles.Levels[cblog.ErrorLevel] = lipgloss.NewStyle().
			SetString(" ERROR").
			Foreground(lipgloss.Color("9"))
		styles.Levels[cblog.WarnLevel] = lipgloss.NewStyle().
			SetString("  WARN").
			Foreground(lipgloss.Color("3"))
		styles.Levels[cblog.InfoLevel] = lipgloss.NewStyle().
			SetString("  INFO").
			Foreground(lipgloss.Color("2"))
		styles.Levels[cblog.DebugLevel] = lipgloss.NewStyle().
			SetString(" DEBUG").
			Foreground(lipgloss.Color("4"))

		base := cblog.New(logStderr)
		base.SetStyles(styles)
		base.SetReportTimestamp(false)

		level := cblog.InfoLevel
		if envLevel := os.Getenv("DMS_LOG_LEVEL"); envLevel != "" {
			level = parseLogLevel(envLevel)
		}
		base.SetLevel(level)
		base.SetPrefix(" go")

		logger = &Logger{base}

		if path := os.Getenv("DMS_LOG_FILE"); path != "" {
			_ = SetLogFile(path)
		}
	})
	return logger
}

// SetLevel updates the active log level. Accepts the same strings as
// DMS_LOG_LEVEL. Unknown values default to info.
func SetLevel(level string) {
	GetLogger().SetLevel(parseLogLevel(level))
}

// SetLogFile makes the logger append to path in addition to stderr. Passing an
// empty string detaches the file sink. Atomic per-line writes (≤PIPE_BUF) on
// O_APPEND keep concurrent Go and QML writers from corrupting each other.
//
// Color handling: charmbracelet/log auto-detects color support from its
// io.Writer, and io.MultiWriter doesn't pass that through, so we force the ANSI
// profile when stderr is a TTY and route the file through ansiStripWriter so
// the file stays plain while stderr keeps its colors.
func SetLogFile(path string) error {
	logMu.Lock()
	defer logMu.Unlock()

	if logFile != nil {
		logFile.Close()
		logFile = nil
	}

	l := GetLogger()
	if path == "" {
		l.SetOutput(logStderr)
		applyColorProfile(l, logStderr)
		return nil
	}

	f, err := os.OpenFile(path, os.O_WRONLY|os.O_APPEND|os.O_CREATE, 0o644)
	if err != nil {
		return err
	}
	logFile = f
	out := io.MultiWriter(logStderr, &ansiStripWriter{w: f})
	l.SetOutput(out)
	applyColorProfile(l, logStderr)
	return nil
}

// applyColorProfile forces the renderer's color profile to match what stderr
// would produce on its own, undoing the auto-downgrade triggered by wrapping
// stderr in a non-TTY writer (e.g. io.MultiWriter).
func applyColorProfile(l *Logger, stderr io.Writer) {
	f, ok := stderr.(*os.File)
	if !ok {
		l.SetColorProfile(termenv.Ascii)
		return
	}
	if isatty.IsTerminal(f.Fd()) {
		l.SetColorProfile(termenv.ANSI)
		return
	}
	l.SetColorProfile(termenv.Ascii)
}

// ApplyEnvOverrides re-reads DMS_LOG_LEVEL and DMS_LOG_FILE and reconfigures
// the singleton. Safe to call after CLI flags have rewritten the environment.
func ApplyEnvOverrides() {
	GetLogger()
	if level := os.Getenv("DMS_LOG_LEVEL"); level != "" {
		SetLevel(level)
	}
	if path := os.Getenv("DMS_LOG_FILE"); path != "" {
		if err := SetLogFile(path); err != nil {
			Warnf("Failed to open log file %q: %v", path, err)
		}
	}
}

// * Convenience wrappers

func Debug(msg any, keyvals ...any)  { GetLogger().Debug(msg, keyvals...) }
func Debugf(format string, v ...any) { GetLogger().Debugf(format, v...) }
func Info(msg any, keyvals ...any)   { GetLogger().Info(msg, keyvals...) }
func Infof(format string, v ...any)  { GetLogger().Infof(format, v...) }
func Warn(msg any, keyvals ...any)   { GetLogger().Warn(msg, keyvals...) }
func Warnf(format string, v ...any)  { GetLogger().Warnf(format, v...) }
func Error(msg any, keyvals ...any)  { GetLogger().Error(msg, keyvals...) }
func Errorf(format string, v ...any) { GetLogger().Errorf(format, v...) }
func Fatal(msg any, keyvals ...any)  { GetLogger().Fatal(msg, keyvals...) }
func Fatalf(format string, v ...any) { GetLogger().Fatalf(format, v...) }
