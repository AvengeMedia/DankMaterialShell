package configfrag

type Messages struct {
	Missing     string
	NotIncluded string
	Overridden  string
	Active      string
}

type Status struct {
	Exists          bool
	Included        bool
	IncludePosition int
	TotalIncludes   int
	EntriesAfterDMS int
	Effective       bool
	OverriddenBy    int
	StatusMessage   string
	ConfigFormat    string
	ReadOnly        bool
}

func BuildStatus(scan IncludeScan, exists bool, entriesAfter int, format string, readOnly bool, msgs Messages) Status {
	status := Status{
		Exists:          exists,
		Included:        scan.DMSSeen,
		IncludePosition: scan.DMSPosition,
		TotalIncludes:   scan.Count,
		EntriesAfterDMS: entriesAfter,
		ConfigFormat:    format,
		ReadOnly:        readOnly,
	}

	if !exists {
		status.StatusMessage = msgs.Missing
		return status
	}
	if !scan.DMSSeen {
		status.StatusMessage = msgs.NotIncluded
		return status
	}

	status.Effective = true
	if entriesAfter > 0 {
		status.OverriddenBy = entriesAfter
		status.StatusMessage = msgs.Overridden
		return status
	}

	status.StatusMessage = msgs.Active
	return status
}
