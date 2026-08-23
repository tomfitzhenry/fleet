package main

import (
	"math"
	"strings"
	"testing"

	"github.com/dennwc/btrfs"
)

func TestUsageProblems(t *testing.T) {
	// 1GiB device: plenty of free and unallocated space.
	ok := btrfs.UsageInfo{Total: 1 << 30, FreeEstimated: 1 << 30, TotalUnused: 1 << 30, DataRatio: 1}
	if problems := usageProblems("/srv/share", ok); len(problems) != 0 {
		t.Fatalf("healthy usage should be silent, got %v", problems)
	}

	full := btrfs.UsageInfo{Total: 1 << 30, FreeEstimated: 1 << 26, TotalUnused: 0, DataRatio: 1}
	problems := usageProblems("/srv/share", full)
	if len(problems) != 2 {
		t.Fatalf("expected 2 problems, got %v", problems)
	}
	if !strings.Contains(problems[0], "free space") || !strings.Contains(problems[1], "ENOSPC") {
		t.Fatalf("unexpected messages: %v", problems)
	}
}

// A filesystem with no data chunks has a NaN data ratio; it must not produce
// garbage percentages.
func TestUsageProblemsNaNRatio(t *testing.T) {
	u := btrfs.UsageInfo{Total: 1 << 30, FreeEstimated: 1 << 30, TotalUnused: 1 << 30, DataRatio: math.NaN()}
	if problems := usageProblems("/srv/share", u); len(problems) != 0 {
		t.Fatalf("NaN ratio should be silent, got %v", problems)
	}
}

func TestDevStatsProblems(t *testing.T) {
	devs := []devHealth{
		{path: "/dev/vdb", stats: btrfs.DevStats{}},
	}
	if problems := devStatsProblems("/srv/share", devs); len(problems) != 0 {
		t.Fatalf("zero counters should be silent, got %v", problems)
	}

	devs[0].stats.CorruptionErrs = 2
	problems := devStatsProblems("/srv/share", devs)
	if len(problems) != 3 || !strings.Contains(problems[1], "corruption=2") {
		t.Fatalf("expected counter report, got %v", problems)
	}
	if !strings.Contains(problems[2], "btrfs device stats -z") {
		t.Fatalf("expected reset hint, got %v", problems)
	}
}

func TestMissingDeviceProblems(t *testing.T) {
	devs := []devHealth{
		{path: "/"},
	}
	if problems := missingDeviceProblems("/srv/share", devs); len(problems) != 0 {
		t.Fatalf("present device should be silent, got %v", problems)
	}

	devs[0].path = "/nonexistent-device-path"
	problems := missingDeviceProblems("/srv/share", devs)
	if len(problems) != 2 || !strings.Contains(problems[0], "missing a device") {
		t.Fatalf("expected missing-device report, got %v", problems)
	}
}
