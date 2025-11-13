package main

import (
	"fmt"
	"os"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/dank16"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/spf13/cobra"
)

var dank16Cmd = &cobra.Command{
	Use:   "dank16 <hex_color>",
	Short: "Generate Base16 color palettes",
	Long:  "Generate Base16 color palettes from a color with support for various output formats",
	Args:  cobra.ExactArgs(1),
	Run:   runDank16,
}

func init() {
	dank16Cmd.Flags().Bool("light", false, "Generate light theme variant")
	dank16Cmd.Flags().Bool("json", false, "Output in JSON format")
	dank16Cmd.Flags().Bool("kitty", false, "Output in Kitty terminal format")
	dank16Cmd.Flags().Bool("foot", false, "Output in Foot terminal format")
	dank16Cmd.Flags().Bool("alacritty", false, "Output in Alacritty terminal format")
	dank16Cmd.Flags().Bool("ghostty", false, "Output in Ghostty terminal format")
	dank16Cmd.Flags().Bool("wezterm", false, "Output in Wezterm terminal format")
	dank16Cmd.Flags().String("vscode-enrich", "", "Enrich existing VSCode theme file with terminal colors")
	dank16Cmd.Flags().String("background", "", "Custom background color")
	dank16Cmd.Flags().String("contrast", "dps", "Contrast algorithm: dps (Delta Phi Star, default) or wcag")
}

func runDank16(cmd *cobra.Command, args []string) {
	primaryColor := args[0]
	if !strings.HasPrefix(primaryColor, "#") {
		primaryColor = "#" + primaryColor
	}

	isLight, _ := cmd.Flags().GetBool("light")
	isJson, _ := cmd.Flags().GetBool("json")
	isKitty, _ := cmd.Flags().GetBool("kitty")
	isFoot, _ := cmd.Flags().GetBool("foot")
	isAlacritty, _ := cmd.Flags().GetBool("alacritty")
	isGhostty, _ := cmd.Flags().GetBool("ghostty")
	isWezterm, _ := cmd.Flags().GetBool("wezterm")
	vscodeEnrich, _ := cmd.Flags().GetString("vscode-enrich")
	background, _ := cmd.Flags().GetString("background")
	contrastAlgo, _ := cmd.Flags().GetString("contrast")

	if background != "" && !strings.HasPrefix(background, "#") {
		background = "#" + background
	}

	contrastAlgo = strings.ToLower(contrastAlgo)
	if contrastAlgo != "dps" && contrastAlgo != "wcag" {
		log.Fatalf("Invalid contrast algorithm: %s (must be 'dps' or 'wcag')", contrastAlgo)
	}

	opts := dank16.PaletteOptions{
		IsLight:    isLight,
		Background: background,
		UseDPS:     contrastAlgo == "dps",
	}

	colors := dank16.GeneratePalette(primaryColor, opts)

	if vscodeEnrich != "" {
		data, err := os.ReadFile(vscodeEnrich)
		if err != nil {
			log.Fatalf("Error reading file: %v", err)
		}

		enriched, err := dank16.EnrichVSCodeTheme(data, colors)
		if err != nil {
			log.Fatalf("Error enriching theme: %v", err)
		}
		fmt.Println(string(enriched))
	} else if isJson {
		fmt.Print(dank16.GenerateJSON(colors))
	} else if isKitty {
		fmt.Print(dank16.GenerateKittyTheme(colors))
	} else if isFoot {
		fmt.Print(dank16.GenerateFootTheme(colors))
	} else if isAlacritty {
		fmt.Print(dank16.GenerateAlacrittyTheme(colors))
	} else if isGhostty {
		fmt.Print(dank16.GenerateGhosttyTheme(colors))
	} else if isWezterm {
		fmt.Print(dank16.GenerateWeztermTheme(colors))
	} else {
		fmt.Print(dank16.GenerateGhosttyTheme(colors))
	}
}
