package main

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/dennwc/btrfs"
)

const scrubStaleAge = 45 * 24 * time.Hour

// uuidString formats a btrfs fsid as the dashed UUID that btrfs-progs uses in
// its scrub status file names.
func uuidString(fsid btrfs.FSID) string {
	b := fsid[:]
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:16])
}

// checkScrub checks that a scrub has run recently. btrfs-progs writes
// /var/lib/btrfs/scrub.status.<fsid> as scrub runs, so the file's age tells us
// whether a scrub has happened recently.
func checkScrub(mnt string, fs *btrfs.FS) []string {
	info, err := fs.Info()
	if err != nil {
		return []string{fmt.Sprintf("%s: btrfs info failed: %v", mnt, err)}
	}
	return checkScrubFile(mnt, filepath.Join("/var/lib/btrfs", "scrub.status."+uuidString(info.FSID)))
}

func checkScrubFile(mnt, path string) []string {
	st, err := os.Stat(path)
	if err != nil {
		if os.IsNotExist(err) {
			return []string{fmt.Sprintf("%s: no scrub recorded yet", mnt)}
		}
		return []string{fmt.Sprintf("%s: cannot stat scrub status: %v", mnt, err)}
	}
	if time.Since(st.ModTime()) > scrubStaleAge {
		return []string{fmt.Sprintf("%s: last scrub too old (status file modified %s)", mnt, st.ModTime().Format("Mon Jan 2 15:04:05 2006"))}
	}
	return nil
}
