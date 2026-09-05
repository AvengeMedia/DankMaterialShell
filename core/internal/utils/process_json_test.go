package utils

import (
	"context"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"
)

func TestJSONProcessFixture(t *testing.T) {
	mode := os.Getenv("DMS_JSON_PROCESS_FIXTURE")
	if mode == "" {
		return
	}
	switch mode {
	case "accepted":
		fmt.Print(`{"ok":true,"status":"accepted","sequence":"9007199254740993"}`)
	case "failure":
		fmt.Print(`{"ok":false,"status":"locked","sequence":"1"}`)
		os.Exit(1)
	case "malformed":
		fmt.Print("invalid JSON")
	case "timeout":
		time.Sleep(time.Minute)
	case "oversize":
		fmt.Print(strings.Repeat("x", maxJSONProcessBytes+2))
	}
	os.Exit(0)
}

func TestRunJSONResultsAndTimeout(t *testing.T) {
	for _, mode := range []string{"accepted", "failure", "malformed", "oversize", "timeout"} {
		t.Run(mode, func(t *testing.T) {
			t.Setenv("DMS_JSON_PROCESS_FIXTURE", mode)
			limit := 4 * time.Second
			if mode == "timeout" {
				limit = 100 * time.Millisecond
			}
			ctx, cancel := context.WithTimeout(context.Background(), limit)
			defer cancel()
			var result jsonProcessResult
			err := RunJSON(ctx, os.Args[0], []string{"-test.run=^TestJSONProcessFixture$"}, nil, &result)
			if mode == "accepted" {
				if err != nil || !result.OK || result.Status != "accepted" || result.Sequence != "9007199254740993" {
					t.Fatalf("lost acknowledgement: %v %#v", err, result)
				}
				return
			}
			if err == nil {
				t.Fatal("failure accepted")
			}
			if mode == "failure" && result.Status != "locked" {
				t.Fatal("operation failure lost")
			}
		})
	}
}

type jsonProcessResult struct {
	OK       bool   `json:"ok"`
	Status   string `json:"status"`
	Sequence string `json:"sequence"`
}
