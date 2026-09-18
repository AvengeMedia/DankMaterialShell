package configfrag

import "testing"

var hyprlandBinds = Messages{
	Missing:     "dms/binds.lua (or legacy binds.conf) does not exist",
	NotIncluded: "dms binds are not loaded from Hyprland config (require / source)",
	Overridden:  "Some DMS binds may be overridden by config binds",
	Active:      "DMS binds are active",
}

var niriBinds = Messages{
	Missing:     "dms/binds.kdl does not exist",
	NotIncluded: "dms/binds.kdl is not included in config.kdl",
	Overridden:  "Some DMS binds may be overridden by config binds",
	Active:      "DMS binds are active",
}

var mangoBinds = Messages{
	Missing:     "dms/binds.conf does not exist",
	NotIncluded: "dms/binds.conf is not sourced in config",
	Overridden:  "Some DMS binds may be overridden by config binds",
	Active:      "DMS binds are active",
}

var hyprlandRules = Messages{
	Missing:     "dms window rules fragment (windowrules.lua / windowrules.conf) does not exist",
	NotIncluded: "dms window rules are not loaded (missing require/source for dms/windowrules)",
	Overridden:  "Some DMS rules may be overridden by config rules",
	Active:      "DMS window rules are active",
}

var niriRules = Messages{
	Missing:     "dms/windowrules.kdl does not exist",
	NotIncluded: "dms/windowrules.kdl is not included in config.kdl",
	Overridden:  "Some DMS rules may be overridden by config rules",
	Active:      "DMS window rules are active",
}

var allDomains = map[string]Messages{
	"hyprland binds": hyprlandBinds,
	"niri binds":     niriBinds,
	"mango binds":    mangoBinds,
	"hyprland rules": hyprlandRules,
	"niri rules":     niriRules,
}

func TestMissingFragmentIsNotEffective(t *testing.T) {
	for domain, msgs := range allDomains {
		status := BuildStatus(NewScan(), false, 0, "", false, msgs)
		if status.Effective {
			t.Errorf("%s: a missing fragment must not be effective", domain)
		}
		if status.StatusMessage != msgs.Missing {
			t.Errorf("%s: message = %q, want %q", domain, status.StatusMessage, msgs.Missing)
		}
		if status.OverriddenBy != 0 {
			t.Errorf("%s: overriddenBy = %d, want 0", domain, status.OverriddenBy)
		}
	}
}

func TestExistingButNotIncludedIsNotEffective(t *testing.T) {
	for domain, msgs := range allDomains {
		scan := NewScan()
		scan.Count = 2
		status := BuildStatus(scan, true, 0, "", false, msgs)
		if status.Effective {
			t.Errorf("%s: an unincluded fragment must not be effective", domain)
		}
		if status.StatusMessage != msgs.NotIncluded {
			t.Errorf("%s: message = %q, want %q", domain, status.StatusMessage, msgs.NotIncluded)
		}
	}
}

func TestIncludedWithEntriesAfterReportsOverride(t *testing.T) {
	for domain, msgs := range allDomains {
		scan := IncludeScan{Count: 3, DMSPosition: 2, DMSSeen: true}
		status := BuildStatus(scan, true, 5, "", false, msgs)
		if !status.Effective {
			t.Errorf("%s: an overridden fragment is still effective", domain)
		}
		if status.OverriddenBy != 5 {
			t.Errorf("%s: overriddenBy = %d, want 5", domain, status.OverriddenBy)
		}
		if status.StatusMessage != msgs.Overridden {
			t.Errorf("%s: message = %q, want %q", domain, status.StatusMessage, msgs.Overridden)
		}
	}
}

func TestIncludedWithNothingAfterIsActive(t *testing.T) {
	for domain, msgs := range allDomains {
		scan := IncludeScan{Count: 1, DMSPosition: 1, DMSSeen: true}
		status := BuildStatus(scan, true, 0, "", false, msgs)
		if !status.Effective {
			t.Errorf("%s: an included fragment with nothing after it is effective", domain)
		}
		if status.OverriddenBy != 0 {
			t.Errorf("%s: overriddenBy = %d, want 0", domain, status.OverriddenBy)
		}
		if status.StatusMessage != msgs.Active {
			t.Errorf("%s: message = %q, want %q", domain, status.StatusMessage, msgs.Active)
		}
	}
}

func TestTheBoundaryBetweenZeroAndOneEntryAfter(t *testing.T) {
	scan := IncludeScan{Count: 1, DMSPosition: 1, DMSSeen: true}

	none := BuildStatus(scan, true, 0, "", false, hyprlandBinds)
	if none.StatusMessage != hyprlandBinds.Active || none.OverriddenBy != 0 {
		t.Errorf("zero entries after: message = %q, overriddenBy = %d", none.StatusMessage, none.OverriddenBy)
	}

	one := BuildStatus(scan, true, 1, "", false, hyprlandBinds)
	if one.StatusMessage != hyprlandBinds.Overridden || one.OverriddenBy != 1 {
		t.Errorf("one entry after: message = %q, overriddenBy = %d", one.StatusMessage, one.OverriddenBy)
	}
}

func TestScanAndFormatCarryThrough(t *testing.T) {
	scan := IncludeScan{Count: 4, DMSPosition: 3, DMSSeen: true}
	status := BuildStatus(scan, true, 0, "lua", true, hyprlandRules)

	if status.TotalIncludes != 4 || status.IncludePosition != 3 {
		t.Errorf("includes = %d/%d, want 3/4", status.IncludePosition, status.TotalIncludes)
	}
	if !status.Included {
		t.Error("DMSSeen must land on Included")
	}
	if status.ConfigFormat != "lua" || !status.ReadOnly {
		t.Errorf("format/readOnly = %q/%v, want lua/true", status.ConfigFormat, status.ReadOnly)
	}
}

func TestAnUnseenFragmentKeepsPositionMinusOne(t *testing.T) {
	status := BuildStatus(NewScan(), true, 0, "", false, niriBinds)
	if status.IncludePosition != -1 {
		t.Errorf("includePosition = %d, want -1", status.IncludePosition)
	}
}
