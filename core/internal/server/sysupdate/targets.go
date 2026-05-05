package sysupdate

func BackendHasTargets(b Backend, targets []Package, includeAUR, includeFlatpak bool) bool {
	if b == nil || len(targets) == 0 {
		return false
	}
	id := b.ID()
	repo := b.Repo()
	for _, p := range targets {
		switch p.Repo {
		case RepoFlatpak:
			if !includeFlatpak {
				continue
			}
		case RepoAUR:
			if !includeAUR {
				continue
			}
		}

		switch repo {
		case RepoFlatpak:
			if p.Repo == RepoFlatpak || p.Backend == id {
				return true
			}
		case RepoOSTree:
			if p.Repo == RepoOSTree || p.Backend == id {
				return true
			}
		default:
			if p.Backend == id {
				return true
			}
		}
	}
	return false
}

func UpgradeNeedsPrivilege(backends []Backend, targets []Package, opts UpgradeOptions) bool {
	if opts.DryRun {
		return false
	}
	for _, b := range backends {
		if b == nil {
			continue
		}
		if b.NeedsAuth() && BackendHasTargets(b, targets, opts.IncludeAUR, opts.IncludeFlatpak) {
			return true
		}
	}
	return false
}

func privilegedArgv(opts UpgradeOptions, argv ...string) []string {
	privesc := privescBin(opts.UseSudo)
	out := make([]string, 0, len(argv)+1)
	out = append(out, privesc)
	out = append(out, argv...)
	return out
}
