package log

import (
	"bufio"
	"fmt"
	"os"
	"regexp"
	"sync"
	"time"
)

type FileLogger struct {
	file       *os.File
	writer     *bufio.Writer
	logPath    string
	mu         sync.Mutex
	stopChan   chan struct{}
	doneChan   chan struct{}
	passwordRe *regexp.Regexp
}

func NewFileLogger() (*FileLogger, error) {
	timestamp := time.Now().Unix()
	logPath := fmt.Sprintf("/tmp/dankinstall-%d.log", timestamp)

	file, err := os.Create(logPath)
	if err != nil {
		return nil, fmt.Errorf("failed to create log file: %w", err)
	}

	passwordRe := regexp.MustCompile(`(?i)(password[:\s=]+)[^\s]+`)

	logger := &FileLogger{
		file:       file,
		writer:     bufio.NewWriter(file),
		logPath:    logPath,
		stopChan:   make(chan struct{}),
		doneChan:   make(chan struct{}),
		passwordRe: passwordRe,
	}

	header := fmt.Sprintf("=== DankInstall Log ===\nStarted: %s\n\n", time.Now().Format(time.RFC3339))
	logger.writeToFile(header)

	return logger, nil
}

func (l *FileLogger) GetLogPath() string {
	return l.logPath
}

func (l *FileLogger) redactPassword(message string) string {
	redacted := l.passwordRe.ReplaceAllString(message, "${1}[REDACTED]")

	redacted = regexp.MustCompile(`echo\s+'[^']+'`).ReplaceAllString(redacted, "echo '[REDACTED]'")

	return redacted
}

func (l *FileLogger) writeToFile(message string) {
	l.mu.Lock()
	defer l.mu.Unlock()

	redacted := l.redactPassword(message)
	timestamp := time.Now().Format("15:04:05.000")

	l.writer.WriteString(fmt.Sprintf("[%s] %s\n", timestamp, redacted))
	l.writer.Flush()
}

func (l *FileLogger) StartListening(logChan <-chan string) {
	go func() {
		defer close(l.doneChan)
		for {
			select {
			case msg, ok := <-logChan:
				if !ok {
					return
				}
				l.writeToFile(msg)
			case <-l.stopChan:
				return
			}
		}
	}()
}

func (l *FileLogger) Close() error {
	close(l.stopChan)
	<-l.doneChan

	l.mu.Lock()
	defer l.mu.Unlock()

	footer := fmt.Sprintf("\n=== DankInstall Log End ===\nCompleted: %s\n", time.Now().Format(time.RFC3339))
	l.writer.WriteString(footer)
	l.writer.Flush()

	if err := l.file.Sync(); err != nil {
		return err
	}

	return l.file.Close()
}
