package main

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

const (
	employeeVault       = "Employee"
	secretLookupTimeout = 30 * time.Second
)

type credentialTarget struct {
	item        string
	dockerField string
}

var targets = map[string]credentialTarget{
	"artifactory.devhub-cloud.cisco.com": {item: "Cisco Artifactory - DevHub Cloud - ticarlso"},
	"devhub-docker.cisco.com":            {item: "Cisco Artifactory - DevHub Legacy - ticarlso"},
	"devhub.cisco.com":                   {item: "Cisco Artifactory - DevHub Legacy - ticarlso"},
	"dockerhub.cisco.com":                {item: "Cisco Artifactory - BMS RTP - ticarlso", dockerField: "container_credential"},
	"engci-maven-master.cisco.com":       {item: "Cisco Artifactory - BMS Master - ticarlso"},
	"engci-maven.cisco.com":              {item: "Cisco Artifactory - BMS RTP - ticarlso", dockerField: "container_credential"},
	"gitlfs.cisco.com":                   {item: "Cisco Artifactory - Git LFS - ticarlso"},
}

func main() {
	name := filepath.Base(os.Args[0])
	var err error

	switch name {
	case "docker-credential-op-artifactory":
		err = runDocker(os.Args[1:])
	case "git-credential-op-artifactory":
		err = runGit(os.Args[1:])
	default:
		err = runDirect(os.Args[1:])
	}

	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func runDirect(args []string) error {
	return errors.New("this binary is invoked as docker-credential-op-artifactory or git-credential-op-artifactory")
}

func runDocker(args []string) error {
	if len(args) != 1 {
		return errors.New("docker credential helper requires one operation")
	}

	switch args[0] {
	case "get":
		server, err := readAllStdin()
		if err != nil {
			return err
		}
		host, target, err := resolve(server)
		if err != nil {
			return err
		}
		field := target.dockerField
		if field == "" {
			field = "credential"
		}
		secret, err := readSecret(target, field)
		if err != nil {
			return fmt.Errorf("read credential for %s: %w", host, err)
		}
		return json.NewEncoder(os.Stdout).Encode(struct {
			ServerURL string
			Username  string
			Secret    string
		}{ServerURL: server, Username: "ticarlso", Secret: secret})
	case "list":
		listed := make(map[string]string, len(targets))
		for host := range targets {
			listed[host] = "ticarlso"
		}
		return json.NewEncoder(os.Stdout).Encode(listed)
	case "store", "erase":
		// Docker calls store after a successful login and erase during logout.
		// 1Password remains the source of truth, so consume the protocol payload
		// without creating or deleting a second credential copy.
		_, err := readAllStdin()
		return err
	default:
		return fmt.Errorf("unsupported Docker credential operation %q", args[0])
	}
}

func runGit(args []string) error {
	if len(args) != 1 {
		return errors.New("git credential helper requires one operation")
	}

	switch args[0] {
	case "get":
		fields, err := readGitFields()
		if err != nil {
			return err
		}
		server := fields["host"]
		if server == "" {
			server = fields["url"]
		}
		host, target, err := resolve(server)
		if err != nil {
			fmt.Fprint(os.Stdout, "quit=true\n\n")
			return nil
		}
		secret, err := readSecret(target, "credential")
		if err != nil {
			return fmt.Errorf("read credential for %s: %w", host, err)
		}
		fmt.Fprintln(os.Stdout, "username=ticarlso")
		fmt.Fprintf(os.Stdout, "password=%s\n\n", secret)
		return nil
	case "store", "erase":
		// 1Password remains the source of truth. Git may call these after an
		// authentication attempt; acknowledging them keeps normal Git/LFS flows
		// transparent without persisting a second copy.
		return nil
	default:
		return fmt.Errorf("unsupported Git credential operation %q", args[0])
	}
}

func resolve(server string) (string, credentialTarget, error) {
	host, err := normalizeHost(server)
	if err != nil {
		return "", credentialTarget{}, err
	}
	target, ok := targets[host]
	if !ok {
		return "", credentialTarget{}, fmt.Errorf("registry host %q is not in the Cisco Artifactory allowlist", host)
	}
	return host, target, nil
}

func normalizeHost(server string) (string, error) {
	value := strings.TrimSpace(server)
	if value == "" {
		return "", errors.New("empty registry host")
	}

	if !strings.Contains(value, "://") {
		value = "https://" + strings.TrimPrefix(value, "//")
	}
	parsed, err := url.Parse(value)
	if err != nil {
		return "", fmt.Errorf("parse registry host: %w", err)
	}
	if parsed.Scheme != "https" {
		return "", fmt.Errorf("registry host %q must use HTTPS", server)
	}
	host := strings.ToLower(strings.TrimSuffix(parsed.Hostname(), "."))
	if host == "" {
		return "", fmt.Errorf("registry value %q has no host", server)
	}
	if port := parsed.Port(); port != "" {
		if _, _, err := net.SplitHostPort(parsed.Host); err != nil {
			return "", fmt.Errorf("parse registry port: %w", err)
		}
		if port != "443" {
			return "", fmt.Errorf("registry host %q uses disallowed port %s", host, port)
		}
	}
	return host, nil
}

func readSecret(target credentialTarget, field string) (string, error) {
	reference := fmt.Sprintf("op://%s/%s/%s", employeeVault, target.item, field)
	ctx, cancel := context.WithTimeout(context.Background(), secretLookupTimeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, "op", "read", "--no-newline", reference)
	cmd.Stderr = os.Stderr
	value, err := cmd.Output()
	if errors.Is(ctx.Err(), context.DeadlineExceeded) {
		return "", fmt.Errorf("1Password credential lookup timed out after %s", secretLookupTimeout)
	}
	if err != nil {
		return "", err
	}
	secret := strings.TrimSpace(string(value))
	if secret == "" {
		return "", errors.New("1Password returned an empty credential")
	}
	return secret, nil
}

func readAllStdin() (string, error) {
	var value strings.Builder
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		value.WriteString(scanner.Text())
	}
	if err := scanner.Err(); err != nil {
		return "", err
	}
	return strings.TrimSpace(value.String()), nil
}

func readGitFields() (map[string]string, error) {
	fields := map[string]string{}
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			break
		}
		key, value, ok := strings.Cut(line, "=")
		if ok {
			fields[key] = value
		}
	}
	return fields, scanner.Err()
}
