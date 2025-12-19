package dank16

import (
	"encoding/json"
	"fmt"
	"strings"
)

func GenerateJSON(p Palette) string {
	marshalled, _ := json.Marshal(p)
	return string(marshalled)
}

func GenerateVariantJSON(p VariantPalette) string {
	marshalled, _ := json.Marshal(p)
	return string(marshalled)
}

func GenerateKittyTheme(p Palette) string {
	var result strings.Builder
	fmt.Fprintf(&result, "color0   %s\n", p.Color0.Hex)
	fmt.Fprintf(&result, "color1   %s\n", p.Color1.Hex)
	fmt.Fprintf(&result, "color2   %s\n", p.Color2.Hex)
	fmt.Fprintf(&result, "color3   %s\n", p.Color3.Hex)
	fmt.Fprintf(&result, "color4   %s\n", p.Color4.Hex)
	fmt.Fprintf(&result, "color5   %s\n", p.Color5.Hex)
	fmt.Fprintf(&result, "color6   %s\n", p.Color6.Hex)
	fmt.Fprintf(&result, "color7   %s\n", p.Color7.Hex)
	fmt.Fprintf(&result, "color8   %s\n", p.Color8.Hex)
	fmt.Fprintf(&result, "color9   %s\n", p.Color9.Hex)
	fmt.Fprintf(&result, "color10   %s\n", p.Color10.Hex)
	fmt.Fprintf(&result, "color11   %s\n", p.Color11.Hex)
	fmt.Fprintf(&result, "color12   %s\n", p.Color12.Hex)
	fmt.Fprintf(&result, "color13   %s\n", p.Color13.Hex)
	fmt.Fprintf(&result, "color14   %s\n", p.Color14.Hex)
	fmt.Fprintf(&result, "color15   %s\n", p.Color15.Hex)
	return result.String()
}

func GenerateFootTheme(p Palette) string {
	var result strings.Builder
	fmt.Fprintf(&result, "regular0=%s\n", p.Color0.HexStripped)
	fmt.Fprintf(&result, "regular1=%s\n", p.Color1.HexStripped)
	fmt.Fprintf(&result, "regular2=%s\n", p.Color2.HexStripped)
	fmt.Fprintf(&result, "regular3=%s\n", p.Color3.HexStripped)
	fmt.Fprintf(&result, "regular4=%s\n", p.Color4.HexStripped)
	fmt.Fprintf(&result, "regular5=%s\n", p.Color5.HexStripped)
	fmt.Fprintf(&result, "regular6=%s\n", p.Color6.HexStripped)
	fmt.Fprintf(&result, "regular7=%s\n", p.Color7.HexStripped)
	fmt.Fprintf(&result, "bright0=%s\n", p.Color8.HexStripped)
	fmt.Fprintf(&result, "bright1=%s\n", p.Color9.HexStripped)
	fmt.Fprintf(&result, "bright2=%s\n", p.Color10.HexStripped)
	fmt.Fprintf(&result, "bright3=%s\n", p.Color11.HexStripped)
	fmt.Fprintf(&result, "bright4=%s\n", p.Color12.HexStripped)
	fmt.Fprintf(&result, "bright5=%s\n", p.Color13.HexStripped)
	fmt.Fprintf(&result, "bright6=%s\n", p.Color14.HexStripped)
	fmt.Fprintf(&result, "bright7=%s\n", p.Color15.HexStripped)
	return result.String()
}

func GenerateAlacrittyTheme(p Palette) string {
	var result strings.Builder
	result.WriteString("[colors.normal]\n")
	fmt.Fprintf(&result, "black   = '%s'\n", p.Color0.Hex)
	fmt.Fprintf(&result, "red     = '%s'\n", p.Color1.Hex)
	fmt.Fprintf(&result, "green   = '%s'\n", p.Color2.Hex)
	fmt.Fprintf(&result, "yellow  = '%s'\n", p.Color3.Hex)
	fmt.Fprintf(&result, "blue    = '%s'\n", p.Color4.Hex)
	fmt.Fprintf(&result, "magenta = '%s'\n", p.Color5.Hex)
	fmt.Fprintf(&result, "cyan    = '%s'\n", p.Color6.Hex)
	fmt.Fprintf(&result, "white   = '%s'\n", p.Color7.Hex)
	result.WriteString("\n[colors.bright]\n")
	fmt.Fprintf(&result, "black   = '%s'\n", p.Color8.Hex)
	fmt.Fprintf(&result, "red     = '%s'\n", p.Color9.Hex)
	fmt.Fprintf(&result, "green   = '%s'\n", p.Color10.Hex)
	fmt.Fprintf(&result, "yellow  = '%s'\n", p.Color11.Hex)
	fmt.Fprintf(&result, "blue    = '%s'\n", p.Color12.Hex)
	fmt.Fprintf(&result, "magenta = '%s'\n", p.Color13.Hex)
	fmt.Fprintf(&result, "cyan    = '%s'\n", p.Color14.Hex)
	fmt.Fprintf(&result, "white   = '%s'\n", p.Color15.Hex)
	return result.String()
}

func GenerateGhosttyTheme(p Palette) string {
	var result strings.Builder
	fmt.Fprintf(&result, "palette = 0=%s\n", p.Color0.Hex)
	fmt.Fprintf(&result, "palette = 1=%s\n", p.Color1.Hex)
	fmt.Fprintf(&result, "palette = 2=%s\n", p.Color2.Hex)
	fmt.Fprintf(&result, "palette = 3=%s\n", p.Color3.Hex)
	fmt.Fprintf(&result, "palette = 4=%s\n", p.Color4.Hex)
	fmt.Fprintf(&result, "palette = 5=%s\n", p.Color5.Hex)
	fmt.Fprintf(&result, "palette = 6=%s\n", p.Color6.Hex)
	fmt.Fprintf(&result, "palette = 7=%s\n", p.Color7.Hex)
	fmt.Fprintf(&result, "palette = 8=%s\n", p.Color8.Hex)
	fmt.Fprintf(&result, "palette = 9=%s\n", p.Color9.Hex)
	fmt.Fprintf(&result, "palette = 10=%s\n", p.Color10.Hex)
	fmt.Fprintf(&result, "palette = 11=%s\n", p.Color11.Hex)
	fmt.Fprintf(&result, "palette = 12=%s\n", p.Color12.Hex)
	fmt.Fprintf(&result, "palette = 13=%s\n", p.Color13.Hex)
	fmt.Fprintf(&result, "palette = 14=%s\n", p.Color14.Hex)
	fmt.Fprintf(&result, "palette = 15=%s\n", p.Color15.Hex)
	return result.String()
}

func GenerateWeztermTheme(p Palette) string {
	var result strings.Builder
	fmt.Fprintf(&result, "ansi = ['%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s']\n",
		p.Color0.Hex, p.Color1.Hex, p.Color2.Hex, p.Color3.Hex,
		p.Color4.Hex, p.Color5.Hex, p.Color6.Hex, p.Color7.Hex)
	fmt.Fprintf(&result, "brights = ['%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s']\n",
		p.Color8.Hex, p.Color9.Hex, p.Color10.Hex, p.Color11.Hex,
		p.Color12.Hex, p.Color13.Hex, p.Color14.Hex, p.Color15.Hex)
	return result.String()
}

func GenerateNeovimTheme(p Palette) string {
	var result strings.Builder
	fmt.Fprintf(&result, "vim.g.terminal_color_0 = \"%s\"\n", p.Color0.Hex)
	fmt.Fprintf(&result, "vim.g.terminal_color_1 = \"%s\"\n", p.Color1.Hex)
	fmt.Fprintf(&result, "vim.g.terminal_color_2 = \"%s\"\n", p.Color2.Hex)
	fmt.Fprintf(&result, "vim.g.terminal_color_3 = \"%s\"\n", p.Color3.Hex)
	fmt.Fprintf(&result, "vim.g.terminal_color_4 = \"%s\"\n", p.Color4.Hex)
	fmt.Fprintf(&result, "vim.g.terminal_color_5 = \"%s\"\n", p.Color5.Hex)
	fmt.Fprintf(&result, "vim.g.terminal_color_6 = \"%s\"\n", p.Color6.Hex)
	fmt.Fprintf(&result, "vim.g.terminal_color_7 = \"%s\"\n", p.Color7.Hex)
	fmt.Fprintf(&result, "vim.g.terminal_color_8 = \"%s\"\n", p.Color8.Hex)
	fmt.Fprintf(&result, "vim.g.terminal_color_9 = \"%s\"\n", p.Color9.Hex)
	fmt.Fprintf(&result, "vim.g.terminal_color_10 = \"%s\"\n", p.Color10.Hex)
	fmt.Fprintf(&result, "vim.g.terminal_color_11 = \"%s\"\n", p.Color11.Hex)
	fmt.Fprintf(&result, "vim.g.terminal_color_12 = \"%s\"\n", p.Color12.Hex)
	fmt.Fprintf(&result, "vim.g.terminal_color_13 = \"%s\"\n", p.Color13.Hex)
	fmt.Fprintf(&result, "vim.g.terminal_color_14 = \"%s\"\n", p.Color14.Hex)
	fmt.Fprintf(&result, "vim.g.terminal_color_15 = \"%s\"\n", p.Color15.Hex)
	return result.String()
}
