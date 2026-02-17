package network

import (
	"bufio"
	"context"
	"fmt"
	"os/exec"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
)

type gpSamlAuthResult struct {
	Cookie      string
	Host        string
	User        string
	Fingerprint string
}

// runGlobalProtectSAMLAuth handles GlobalProtect SAML/SSO authentication using gp-saml-gui.
// Only supports protocol=gp. Other protocols need their own implementations.
func (b *NetworkManagerBackend) runGlobalProtectSAMLAuth(ctx context.Context, gateway, protocol string) (*gpSamlAuthResult, error) {
	if gateway == "" {
		return nil, fmt.Errorf("GP SAML auth: gateway is empty")
	}
	if protocol != "gp" {
		return nil, fmt.Errorf("only GlobalProtect (protocol=gp) SAML is supported, got: %s", protocol)
	}

	log.Infof("[GP-SAML] Starting GlobalProtect SAML authentication with gp-saml-gui for gateway=%s", gateway)

	gpSamlPath, err := exec.LookPath("gp-saml-gui")
	if err != nil {
		return nil, fmt.Errorf("GlobalProtect SAML requires gp-saml-gui (install: pip install gp-saml-gui): %w", err)
	}

	args := []string{
		"--gateway",
		"--allow-insecure-crypto",
		gateway,
	}

	cmd := exec.CommandContext(ctx, gpSamlPath, args...)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, fmt.Errorf("GP SAML auth: failed to create stdout pipe: %w", err)
	}

	stderr, err := cmd.StderrPipe()
	if err != nil {
		return nil, fmt.Errorf("GP SAML auth: failed to create stderr pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("GP SAML auth: failed to start gp-saml-gui: %w", err)
	}

	go func() {
		scanner := bufio.NewScanner(stderr)
		for scanner.Scan() {
			log.Debugf("[GP-SAML] gp-saml-gui: %s", scanner.Text())
		}
	}()

	result := &gpSamlAuthResult{Host: gateway}
	var allOutput []string

	scanner := bufio.NewScanner(stdout)
	for scanner.Scan() {
		line := scanner.Text()
		allOutput = append(allOutput, line)
		log.Infof("[GP-SAML] stdout: %s", line)

		switch {
		case strings.HasPrefix(line, "COOKIE="):
			result.Cookie = unshellQuote(strings.TrimPrefix(line, "COOKIE="))
		case strings.HasPrefix(line, "HOST="):
			result.Host = unshellQuote(strings.TrimPrefix(line, "HOST="))
		case strings.HasPrefix(line, "USER="):
			result.User = unshellQuote(strings.TrimPrefix(line, "USER="))
		case strings.HasPrefix(line, "FINGERPRINT="):
			result.Fingerprint = unshellQuote(strings.TrimPrefix(line, "FINGERPRINT="))
		default:
			parseGPSamlFromCommandLine(line, result)
		}
	}

	if err := cmd.Wait(); err != nil {
		if ctx.Err() != nil {
			return nil, fmt.Errorf("GP SAML auth timed out or was cancelled: %w", ctx.Err())
		}
		if result.Cookie == "" {
			return nil, fmt.Errorf("GP SAML auth failed: %w (output: %s)", err, strings.Join(allOutput, "\n"))
		}
		log.Warnf("[GP-SAML] gp-saml-gui exited with error but cookie was captured: %v", err)
	}

	if result.Cookie == "" {
		return nil, fmt.Errorf("GP SAML auth: no cookie in gp-saml-gui output")
	}

	log.Infof("[GP-SAML] Got prelogin-cookie from gp-saml-gui, converting to openconnect cookie via --authenticate")

	// Convert prelogin-cookie to full openconnect cookie format
	ocResult, err := convertGPPreloginCookie(ctx, gateway, result.Cookie, result.User)
	if err != nil {
		return nil, fmt.Errorf("GP SAML auth: failed to convert prelogin-cookie: %w", err)
	}

	result.Cookie = ocResult.Cookie
	result.Host = ocResult.Host
	result.Fingerprint = ocResult.Fingerprint

	log.Infof("[GP-SAML] Authentication successful: user=%s, host=%s, cookie_len=%d, has_fingerprint=%v",
		result.User, result.Host, len(result.Cookie), result.Fingerprint != "")
	return result, nil
}

func convertGPPreloginCookie(ctx context.Context, gateway, preloginCookie, user string) (*gpSamlAuthResult, error) {
	ocPath, err := exec.LookPath("openconnect")
	if err != nil {
		return nil, fmt.Errorf("openconnect not found: %w", err)
	}

	args := []string{
		"--protocol=gp",
		"--usergroup=gateway:prelogin-cookie",
		"--user=" + user,
		"--passwd-on-stdin",
		"--allow-insecure-crypto",
		"--authenticate",
		gateway,
	}

	cmd := exec.CommandContext(ctx, ocPath, args...)
	cmd.Stdin = strings.NewReader(preloginCookie)

	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("openconnect --authenticate failed: %w\noutput: %s", err, string(output))
	}

	result := &gpSamlAuthResult{}
	for _, line := range strings.Split(string(output), "\n") {
		line = strings.TrimSpace(line)
		switch {
		case strings.HasPrefix(line, "COOKIE="):
			result.Cookie = unshellQuote(strings.TrimPrefix(line, "COOKIE="))
		case strings.HasPrefix(line, "HOST="):
			result.Host = unshellQuote(strings.TrimPrefix(line, "HOST="))
		case strings.HasPrefix(line, "FINGERPRINT="):
			result.Fingerprint = unshellQuote(strings.TrimPrefix(line, "FINGERPRINT="))
		case strings.HasPrefix(line, "CONNECT_URL="):
			connectURL := unshellQuote(strings.TrimPrefix(line, "CONNECT_URL="))
			if connectURL != "" && result.Host == "" {
				result.Host = connectURL
			}
		}
	}

	if result.Cookie == "" {
		return nil, fmt.Errorf("no COOKIE in openconnect --authenticate output: %s", string(output))
	}

	log.Infof("[GP-SAML] openconnect --authenticate: cookie_len=%d, host=%s, fingerprint=%s",
		len(result.Cookie), result.Host, result.Fingerprint)

	return result, nil
}

func unshellQuote(s string) string {
	if len(s) >= 2 {
		if (s[0] == '\'' && s[len(s)-1] == '\'') ||
			(s[0] == '"' && s[len(s)-1] == '"') {
			return s[1 : len(s)-1]
		}
	}
	return s
}

func parseGPSamlFromCommandLine(line string, result *gpSamlAuthResult) {
	if !strings.Contains(line, "openconnect") {
		return
	}

	for _, part := range strings.Fields(line) {
		switch {
		case strings.HasPrefix(part, "--cookie="):
			if result.Cookie == "" {
				result.Cookie = strings.TrimPrefix(part, "--cookie=")
			}
		case strings.HasPrefix(part, "--servercert="):
			if result.Fingerprint == "" {
				result.Fingerprint = strings.TrimPrefix(part, "--servercert=")
			}
		case strings.HasPrefix(part, "--user="):
			if result.User == "" {
				result.User = strings.TrimPrefix(part, "--user=")
			}
		}
	}
}
