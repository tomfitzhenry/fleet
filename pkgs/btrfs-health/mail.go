package main

import (
	"bytes"
	"fmt"
	"io"
	"os/exec"
	"strings"
)

func sendMail(mailer, subject string, problems []string) error {
	var body bytes.Buffer
	fmt.Fprintf(&body, "Subject: %s\nTo: root\n\n", subject)
	for _, p := range problems {
		fmt.Fprintln(&body, p)
	}

	cmd := exec.Command(mailer, "-i", "root")
	cmd.Stdin = &body
	cmd.Stdout = io.Discard
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("%v: %s", err, strings.TrimSpace(stderr.String()))
	}
	return nil
}
