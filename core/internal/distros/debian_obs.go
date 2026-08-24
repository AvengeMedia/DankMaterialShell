package distros

import (
	"os"
	"path/filepath"
	"strings"
)

const (
	obsRepoDebian13       = "Debian_13"
	obsRepoDebianTesting  = "Debian_Testing"
	obsRepoDebianUnstable = "Debian_Unstable"
)

func debianOBSRepoVersion(info *OSInfo, aptSuites []string) string {
	hasSuite := make(map[string]bool, len(aptSuites))
	for _, suite := range aptSuites {
		hasSuite[normalizeDebianSuite(suite)] = true
	}

	// APT suites distinguish testing from sid. os-release cannot: both currently
	// report VERSION_CODENAME=forky and PRETTY_NAME="Debian GNU/Linux forky/sid"
	if hasSuite["sid"] || hasSuite["unstable"] {
		return obsRepoDebianUnstable
	}
	if hasSuite["testing"] || hasSuite["forky"] {
		return obsRepoDebianTesting
	}
	if hasSuite["trixie"] || hasSuite["stable"] {
		return obsRepoDebian13
	}

	if info == nil {
		return obsRepoDebian13
	}

	id := strings.ToLower(strings.TrimSpace(info.VersionID))
	code := strings.ToLower(strings.TrimSpace(info.VersionCodename))

	if code == "sid" || id == "sid" {
		return obsRepoDebianUnstable
	}
	if id == "13" || code == "trixie" {
		return obsRepoDebian13
	}
	if id != "" && id != "testing" {
		return obsRepoDebian13
	}
	// Prefer Testing when os-release is the shared forky/sid string. Unstable
	// OBS packages can require a newer glibc than Testing ships.
	return obsRepoDebianTesting
}

func debianOBSListFileMatches(path, debianVersion string) bool {
	data, err := os.ReadFile(path)
	if err != nil {
		return false
	}
	return debianOBSListPointsAt(string(data), debianVersion)
}

func debianOBSListPointsAt(contents, debianVersion string) bool {
	return strings.Contains(contents, "/"+debianVersion+"/")
}

func readDebianAPTSuites() []string {
	var chunks []string
	if data, err := os.ReadFile("/etc/apt/sources.list"); err == nil {
		chunks = append(chunks, string(data))
	}
	matches, _ := filepath.Glob("/etc/apt/sources.list.d/*")
	for _, path := range matches {
		if !strings.HasSuffix(path, ".list") && !strings.HasSuffix(path, ".sources") {
			continue
		}
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		chunks = append(chunks, string(data))
	}
	return debianAPTSuites(strings.Join(chunks, "\n"))
}

func debianAPTSuites(sources string) []string {
	seen := make(map[string]bool)
	var suites []string
	add := func(raw string) {
		suite := normalizeDebianSuite(raw)
		if suite == "" || seen[suite] {
			return
		}
		seen[suite] = true
		suites = append(suites, suite)
	}

	var stanza []string
	flushStanza := func() {
		if len(stanza) == 0 {
			return
		}
		enabled := true
		var stanzaSuites []string
		for _, line := range stanza {
			key, val, ok := strings.Cut(line, ":")
			if !ok {
				continue
			}
			switch strings.ToLower(strings.TrimSpace(key)) {
			case "enabled":
				switch strings.ToLower(strings.TrimSpace(val)) {
				case "no", "false", "0":
					enabled = false
				}
			case "suites":
				stanzaSuites = strings.Fields(val)
			}
		}
		if enabled {
			for _, suite := range stanzaSuites {
				add(suite)
			}
		}
		stanza = nil
	}

	for raw := range strings.SplitSeq(sources, "\n") {
		line := strings.TrimSpace(raw)
		if line == "" {
			flushStanza()
			continue
		}
		if strings.HasPrefix(line, "#") {
			continue
		}
		lower := strings.ToLower(line)
		if strings.HasPrefix(lower, "deb ") || strings.HasPrefix(lower, "deb-src ") {
			flushStanza()
			if suite := suiteFromDebLine(line); suite != "" {
				add(suite)
			}
			continue
		}
		stanza = append(stanza, line)
	}
	flushStanza()
	return suites
}

func suiteFromDebLine(line string) string {
	if i := strings.Index(line, "["); i != -1 {
		if j := strings.Index(line, "]"); j > i {
			line = strings.TrimSpace(line[:i] + " " + line[j+1:])
		}
	}
	fields := strings.Fields(line)
	if len(fields) < 3 {
		return ""
	}
	return fields[2]
}

func normalizeDebianSuite(suite string) string {
	suite = strings.ToLower(strings.TrimSpace(suite))
	suite = strings.Trim(suite, "/")
	for _, suffix := range []string{"-security", "-updates", "-backports", "-proposed-updates"} {
		if before, ok := strings.CutSuffix(suite, suffix); ok {
			return before
		}
	}
	return suite
}
