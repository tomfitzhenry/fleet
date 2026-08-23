// Command btrfs-health checks btrfs filesystems and emails a report when there
// are problems. Filesystems are discovered from the kernel mount table and
// deduplicated by device.
package main

import (
	"flag"
	"fmt"
	"os"
)

func main() {
	mailer := flag.String("mailer", "/run/wrappers/bin/sendmail", "sendmail-compatible binary used to email the report")
	flag.Parse()

	h := &health{}
	problems := h.check(flag.Args())

	if len(problems) == 0 {
		fmt.Printf("btrfs-health: OK (%d btrfs filesystem(s) checked)\n", h.checked)
		return
	}

	hostname, _ := os.Hostname()
	if err := sendMail(*mailer, fmt.Sprintf("btrfs health problems on %s", hostname), problems); err != nil {
		fmt.Fprintf(os.Stderr, "btrfs-health: failed to email the report: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("btrfs-health: %d problem(s) found; report emailed\n", len(problems))
}
