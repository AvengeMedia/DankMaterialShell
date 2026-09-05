package utils

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os/exec"
	"time"
	"unicode/utf8"
)

const maxJSONProcessBytes = 4 * 1024 * 1024

type boundedWriter struct {
	bytes.Buffer
	limit int
}

func (w *boundedWriter) Write(p []byte) (int, error) {
	if len(p) > w.limit-w.Len() {
		return 0, errors.New("process output exceeds size bound")
	}
	return w.Buffer.Write(p)
}

func RunJSON(ctx context.Context, executable string, args []string, input []byte, result any) error {
	if len(input) > maxJSONProcessBytes {
		return errors.New("request exceeds size bound")
	}
	ctx, cancel := context.WithTimeout(ctx, 8*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, executable, args...)
	cmd.WaitDelay = time.Second
	stdout := &boundedWriter{limit: maxJSONProcessBytes + 1}
	stderr := &boundedWriter{limit: 16 * 1024}
	cmd.Stdout, cmd.Stderr = stdout, stderr
	if input != nil {
		cmd.Stdin = bytes.NewReader(input)
	}
	err := cmd.Run()
	if ctx.Err() != nil {
		return fmt.Errorf("unavailable: command completion uncertain: %w", ctx.Err())
	}
	if stdout.Len() != 0 {
		if decodeErr := DecodeJSON(bytes.TrimSuffix(stdout.Bytes(), []byte{'\n'}), result); decodeErr != nil {
			return errors.Join(err, fmt.Errorf("invalid process JSON: %w", decodeErr))
		}
	}
	if err != nil {
		return fmt.Errorf("%s: %w", executable, err)
	}
	if stdout.Len() == 0 {
		return errors.New("missing command acknowledgement")
	}
	return nil
}

func DecodeJSON(data []byte, target any) error {
	if len(data) > maxJSONProcessBytes || !utf8.Valid(data) {
		return errors.New("invalid UTF-8 or oversized JSON record")
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.UseNumber()
	if err := decoder.Decode(target); err != nil {
		return err
	}
	if err := decoder.Decode(new(any)); err != io.EOF {
		return errors.New("trailing JSON data")
	}
	return nil
}
