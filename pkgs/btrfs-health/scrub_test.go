package main

import (
	"encoding/hex"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/dennwc/btrfs"
)

const testFSIDStr = "2bbcf5df-332e-45fd-a903-c8139db3519b"

func testFSID(t *testing.T) btrfs.FSID {
	t.Helper()
	b, err := hex.DecodeString(strings.ReplaceAll(testFSIDStr, "-", ""))
	if err != nil {
		t.Fatal(err)
	}
	var fsid btrfs.FSID
	copy(fsid[:], b)
	return fsid
}

func TestUUIDString(t *testing.T) {
	if got := uuidString(testFSID(t)); got != testFSIDStr {
		t.Fatalf("uuidString = %q, want %q", got, testFSIDStr)
	}
}

func TestCheckScrubFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "scrub.status.test")

	// No status file yet: never scrubbed.
	if problems := checkScrubFile("/srv/share", path); len(problems) != 1 || !strings.Contains(problems[0], "no scrub recorded") {
		t.Fatalf("expected no-scrub warning, got %v", problems)
	}

	// A freshly written status file means a recent scrub.
	if err := os.WriteFile(path, nil, 0600); err != nil {
		t.Fatal(err)
	}
	if problems := checkScrubFile("/srv/share", path); len(problems) != 0 {
		t.Fatalf("fresh status file should be silent, got %v", problems)
	}

	// An old status file means the last scrub is stale.
	old := time.Now().Add(-60 * 24 * time.Hour)
	if err := os.Chtimes(path, old, old); err != nil {
		t.Fatal(err)
	}
	problems := checkScrubFile("/srv/share", path)
	if len(problems) != 1 || !strings.Contains(problems[0], "too old") {
		t.Fatalf("expected stale warning, got %v", problems)
	}
}
