package log

import (
	"os"
	"strings"
	"sync"

	"github.com/charmbracelet/lipgloss"
	cblog "github.com/charmbracelet/log"
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
)

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

		base := cblog.New(os.Stderr)
		base.SetStyles(styles)
		base.SetReportTimestamp(false)

		level := cblog.InfoLevel
		if envLevel := os.Getenv("DMS_LOG_LEVEL"); envLevel != "" {
			level = parseLogLevel(envLevel)
		}
		base.SetLevel(level)
		base.SetPrefix(" go")

		logger = &Logger{base}
	})
	return logger
}

// * Convenience wrappers

func Debug(msg any, keyvals ...any)  { GetLogger().Logger.Debug(msg, keyvals...) }
func Debugf(format string, v ...any) { GetLogger().Logger.Debugf(format, v...) }
func Info(msg any, keyvals ...any)   { GetLogger().Logger.Info(msg, keyvals...) }
func Infof(format string, v ...any)  { GetLogger().Logger.Infof(format, v...) }
func Warn(msg any, keyvals ...any)   { GetLogger().Logger.Warn(msg, keyvals...) }
func Warnf(format string, v ...any)  { GetLogger().Logger.Warnf(format, v...) }
func Error(msg any, keyvals ...any)  { GetLogger().Logger.Error(msg, keyvals...) }
func Errorf(format string, v ...any) { GetLogger().Logger.Errorf(format, v...) }
func Fatal(msg any, keyvals ...any)  { GetLogger().Logger.Fatal(msg, keyvals...) }
func Fatalf(format string, v ...any) { GetLogger().Logger.Fatalf(format, v...) }
