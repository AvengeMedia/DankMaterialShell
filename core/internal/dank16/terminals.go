package dank16

import (
	"encoding/json"
	"fmt"
	"strings"
)

func GenerateJSON(colors []string) string {
	colorMap := make(map[string]string)

	for i, color := range colors {
		colorMap[fmt.Sprintf("color%d", i)] = color
	}

	marshalled, _ := json.Marshal(colorMap)

	return string(marshalled)
}

func GenerateKittyTheme(colors []string) string {
	kittyColors := []struct {
		name  string
		index int
	}{
		{"color0", 0},
		{"color1", 1},
		{"color2", 2},
		{"color3", 3},
		{"color4", 4},
		{"color5", 5},
		{"color6", 6},
		{"color7", 7},
		{"color8", 8},
		{"color9", 9},
		{"color10", 10},
		{"color11", 11},
		{"color12", 12},
		{"color13", 13},
		{"color14", 14},
		{"color15", 15},
	}

	var result strings.Builder
	for _, kc := range kittyColors {
		fmt.Fprintf(&result, "%s   %s\n", kc.name, colors[kc.index])
	}
	return result.String()
}

func GenerateFootTheme(colors []string) string {
	footColors := []struct {
		name  string
		index int
	}{
		{"regular0", 0},
		{"regular1", 1},
		{"regular2", 2},
		{"regular3", 3},
		{"regular4", 4},
		{"regular5", 5},
		{"regular6", 6},
		{"regular7", 7},
		{"bright0", 8},
		{"bright1", 9},
		{"bright2", 10},
		{"bright3", 11},
		{"bright4", 12},
		{"bright5", 13},
		{"bright6", 14},
		{"bright7", 15},
	}

	var result strings.Builder
	for _, fc := range footColors {
		fmt.Fprintf(&result, "%s=%s\n", fc.name, strings.TrimPrefix(colors[fc.index], "#"))
	}
	return result.String()
}

func GenerateAlacrittyTheme(colors []string) string {
	alacrittyColors := []struct {
		section string
		name    string
		index   int
	}{
		{"normal", "black", 0},
		{"normal", "red", 1},
		{"normal", "green", 2},
		{"normal", "yellow", 3},
		{"normal", "blue", 4},
		{"normal", "magenta", 5},
		{"normal", "cyan", 6},
		{"normal", "white", 7},
		{"bright", "black", 8},
		{"bright", "red", 9},
		{"bright", "green", 10},
		{"bright", "yellow", 11},
		{"bright", "blue", 12},
		{"bright", "magenta", 13},
		{"bright", "cyan", 14},
		{"bright", "white", 15},
	}

	var result strings.Builder
	currentSection := ""
	for _, ac := range alacrittyColors {
		if ac.section != currentSection {
			if currentSection != "" {
				result.WriteString("\n")
			}
			fmt.Fprintf(&result, "[colors.%s]\n", ac.section)
			currentSection = ac.section
		}
		fmt.Fprintf(&result, "%-7s = '%s'\n", ac.name, colors[ac.index])
	}
	return result.String()
}

func GenerateGhosttyTheme(colors []string) string {
	var result strings.Builder
	for i, color := range colors {
		fmt.Fprintf(&result, "palette = %d=%s\n", i, color)
	}
	return result.String()
}

func GenerateWeztermTheme(colors []string) string {
	var result strings.Builder
	labels := []string{"ansi", "brights"}
	for j, label := range labels {
		start := j * 8
		colorSlice := make([]string, 8)
		for i, color := range colors[start : start+8] {
			colorSlice[i] = fmt.Sprintf("'%s'", color)
		}
		fmt.Fprintf(&result, "%s = [%s]\n", label, strings.Join(colorSlice, ", "))
	}
	return result.String()
}
