package main

import (
	"fmt"
	"math"
	"os"
	"sort"
	"strings"
	"syscall"

	"github.com/dennwc/btrfs"
)

const (
	minFreePct    = 10
	minUnallocPct = 5
)

type health struct {
	checked int
}

type mountEntry struct {
	device string
	point  string
	ro     bool
}

// discovered returns btrfs mounts deduplicated by device (a filesystem with
// subvolume mounts is checked once), plus the set of all btrfs mountpoints.
func discovered() (byDevice map[string]mountEntry, allPoints map[string]bool, err error) {
	byDevice = map[string]mountEntry{}
	allPoints = map[string]bool{}
	data, err := os.ReadFile("/proc/self/mounts")
	if err != nil {
		return
	}
	for _, line := range strings.Split(string(data), "\n") {
		f := strings.Fields(line)
		if len(f) < 4 || f[2] != "btrfs" {
			continue
		}
		e := mountEntry{device: f[0], point: f[1], ro: hasOption(f[3], "ro")}
		allPoints[f[1]] = true
		if _, ok := byDevice[f[0]]; !ok {
			byDevice[f[0]] = e
		}
	}
	return
}

func hasOption(opts, want string) bool {
	for _, o := range strings.Split(opts, ",") {
		if o == want {
			return true
		}
	}
	return false
}

func (h *health) check(declared []string) []string {
	byDevice, allPoints, err := discovered()
	if err != nil {
		return []string{fmt.Sprintf("cannot read mount table: %v", err)}
	}
	var problems []string

	// A declared filesystem that is not mounted would otherwise be silently
	// unmonitored.
	for _, p := range declared {
		if !allPoints[p] {
			problems = append(problems, fmt.Sprintf("declared btrfs filesystem %s is not mounted", p))
		}
	}

	entries := make([]mountEntry, 0, len(byDevice))
	for _, e := range byDevice {
		entries = append(entries, e)
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].point < entries[j].point })

	for _, e := range entries {
		h.checked++
		problems = append(problems, h.checkFilesystem(e)...)
	}
	return problems
}

func (h *health) checkFilesystem(m mountEntry) []string {
	var problems []string
	mnt := m.point

	if m.ro {
		problems = append(problems, fmt.Sprintf("%s: mounted read-only", mnt))
	}

	fs, err := btrfs.Open(mnt, true)
	if err != nil {
		return append(problems, fmt.Sprintf("%s: cannot open btrfs filesystem: %v", mnt, err))
	}
	defer fs.Close()

	// Space: btrfs hits ENOSPC not when free space runs out but when no new
	// chunks can be allocated, so watch unallocated space too.
	if u, err := fs.Usage(); err != nil {
		problems = append(problems, fmt.Sprintf("%s: btrfs usage failed: %v", mnt, err))
	} else {
		problems = append(problems, usageProblems(mnt, u)...)
	}

	// Scrub recency comes from the age of the btrfs-progs status file.
	problems = append(problems, checkScrub(mnt, fs)...)

	devs, derrs := devices(fs)
	for _, e := range derrs {
		problems = append(problems, fmt.Sprintf("%s: btrfs device info/stats failed: %v", mnt, e))
	}
	problems = append(problems, devStatsProblems(mnt, devs)...)
	problems = append(problems, missingDeviceProblems(mnt, devs)...)
	return problems
}

func usageProblems(mnt string, u btrfs.UsageInfo) []string {
	if u.Total == 0 {
		return nil
	}
	// Free space usable for data = free space inside data chunks plus the
	// unallocated space that could still become data chunks.
	ratio := u.DataRatio
	if math.IsNaN(ratio) || ratio <= 0 {
		ratio = 1
	}
	free := u.FreeEstimated + uint64(float64(u.TotalUnused)/ratio)

	var problems []string
	if pct := 100 * free / u.Total; pct < minFreePct {
		problems = append(problems, fmt.Sprintf("%s: only %d%% free space left", mnt, pct))
	}
	if pct := 100 * u.TotalUnused / u.Total; pct < minUnallocPct {
		problems = append(problems, fmt.Sprintf("%s: only %d%% unallocated (ENOSPC risk)", mnt, pct))
	}
	return problems
}

type devHealth struct {
	path  string
	stats btrfs.DevStats
}

// devices returns per-device info and stats, tolerating a bad device so that a
// single failing device does not hide the others.
func devices(fs *btrfs.FS) (devs []devHealth, errs []error) {
	info, err := fs.Info()
	if err != nil {
		return nil, []error{err}
	}
	for id := uint64(0); id <= info.MaxID; id++ {
		dev, err := fs.GetDevInfo(id)
		if err == syscall.ENODEV {
			continue
		} else if err != nil {
			errs = append(errs, fmt.Errorf("device %d: %v", id, err))
			continue
		}
		stats, err := fs.GetDevStats(id)
		if err != nil {
			errs = append(errs, fmt.Errorf("device %d (%s): %v", id, dev.Path, err))
			continue
		}
		devs = append(devs, devHealth{path: dev.Path, stats: stats})
	}
	return devs, errs
}

func devStatsProblems(mnt string, devs []devHealth) []string {
	var lines []string
	for _, d := range devs {
		s := d.stats
		if s.WriteErrs+s.ReadErrs+s.FlushErrs+s.CorruptionErrs+s.GenerationErrs == 0 {
			continue
		}
		lines = append(lines, fmt.Sprintf("  %s: write=%d read=%d flush=%d corruption=%d generation=%d",
			d.path, s.WriteErrs, s.ReadErrs, s.FlushErrs, s.CorruptionErrs, s.GenerationErrs))
	}
	if len(lines) == 0 {
		return nil
	}
	problems := []string{fmt.Sprintf("%s: non-zero device error counters:", mnt)}
	problems = append(problems, lines...)
	problems = append(problems, fmt.Sprintf("  reset after investigating with: btrfs device stats -z %s", mnt))
	return problems
}

func missingDeviceProblems(mnt string, devs []devHealth) []string {
	var missing []string
	for _, d := range devs {
		if _, err := os.Stat(d.path); err != nil {
			missing = append(missing, "  "+d.path)
		}
	}
	if len(missing) == 0 {
		return nil
	}
	problems := []string{fmt.Sprintf("%s: filesystem is missing a device:", mnt)}
	problems = append(problems, missing...)
	return problems
}
