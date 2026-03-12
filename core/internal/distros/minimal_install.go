package distros

type minimalInstallGroup struct {
	packages []string
	minimal  bool
}

func shouldPreferMinimalInstall(pkg string) bool {
	switch pkg {
	case "niri", "niri-git":
		return true
	default:
		return false
	}
}

func splitMinimalInstallPackages(packages []string) (normal []string, minimal []string) {
	for _, pkg := range packages {
		if shouldPreferMinimalInstall(pkg) {
			minimal = append(minimal, pkg)
			continue
		}
		normal = append(normal, pkg)
	}
	return normal, minimal
}

func orderedMinimalInstallGroups(packages []string) []minimalInstallGroup {
	normal, minimal := splitMinimalInstallPackages(packages)
	groups := make([]minimalInstallGroup, 0, 2)
	if len(minimal) > 0 {
		groups = append(groups, minimalInstallGroup{
			packages: minimal,
			minimal:  true,
		})
	}
	if len(normal) > 0 {
		groups = append(groups, minimalInstallGroup{
			packages: normal,
			minimal:  false,
		})
	}
	return groups
}
