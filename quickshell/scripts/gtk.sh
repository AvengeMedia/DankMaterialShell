#!/usr/bin/env bash

CONFIG_DIR="$1"

if [ -z "$CONFIG_DIR" ]; then
    echo "Usage: $0 <config_dir> [is_light] [shell_dir]" >&2
    exit 1
fi

get_adw_gtk3_dir() {
	local variant="$1"
	local name=""
	[ "$variant" == "dark" ] && name="-$variant"

	local candidates=(
		"$HOME/.local/share/themes/adw-gtk3${name}/gtk-3.0"
		"$HOME/.themes/adw-gtk3${name}/gtk-3.0"
		"/usr/share/themes/adw-gtk3${name}/gtk-3.0"
		"/usr/local/share/themes/adw-gtk3${name}/gtk-3.0"
	)
	local target=""
	for c in "${candidates[@]}"; do
		if [ -d "$c" ]; then
			target="$c"
			break
		fi
	done
	echo "$target"
}

apply_gtk3_colors() {
	local config_dir="$1"

	# Make sure there's no global override
	local gtk3_dir_cfg="$config_dir/gtk-3.0"
	local gtk3_override="$gtk3_dir_cfg/gtk.css"
	if [ -L "$gtk3_override" ]; then
		rm "$gtk3_override"
	elif [ -f "$gtk3_override" ]; then
		mv "$gtk3_override" "$gtk3_override.backup"
		echo "Backed up and removed global theme override for gtk3."
	fi

	# Include generated colors for each variant
	# (fail on first miss)
	for variant in light dark; do
		local adw_gtk3_dir
		adw_gtk3_dir=$(get_adw_gtk3_dir "$variant")

		if [ -z "$adw_gtk3_dir" ]; then
			echo "Error: No version of adw-gtk3 ${variant} was found" >&2
			exit 1
		fi

		if [ ! -f "${gtk3_dir_cfg}/dank-${variant}-colors.css" ]; then
			echo "Error: GTK3 dank-${variant}-colors.css not found at '${gtk3_dir_cfg}'" >&2
			echo "Run matugen first to generate theme files" >&2
			exit 1
		fi

		if sed -i.backup '/\/\* BEGIN DMS OVERRIDE \*\//,/\/\* END DMS OVERRIDE \*\//d' "${adw_gtk3_dir}/gtk.css" && cat "${gtk3_dir_cfg}/dank-${variant}-colors.css" >>"${adw_gtk3_dir}/gtk.css"; then
			echo "GTK3 colors successfully applied to adw-gtk3 $variant in '$adw_gtk3_dir/gtk.css'"
		fi

	done
}

apply_gtk4_colors() {
	local config_dir="$1"

	local gtk4_dir="$config_dir/gtk-4.0"
	local dank_colors="$gtk4_dir/dank-colors.css"
	local gtk_css="$gtk4_dir/gtk.css"
	local gtk4_import="@import url(\"dank-colors.css\");"

	if [ ! -f "$dank_colors" ]; then
		echo "Error: GTK4 dank-colors.css not found at $dank_colors" >&2
		echo "Run matugen first to generate theme files" >&2
		exit 1
	fi

	if [ -f "$gtk_css" ] && grep -q '^@import url.*dank-colors\.css.*);$' "$gtk_css"; then
		echo "GTK4 import already exists"
		return
	fi

	if [ -f "$gtk_css" ] && [ -s "$gtk_css" ]; then
		sed -i "1i\\$gtk4_import" "$gtk_css"
	else
		echo "$gtk4_import" >"$gtk_css"
	fi
	echo "Updated GTK4 CSS import"
}

mkdir -p "$CONFIG_DIR/gtk-3.0" "$CONFIG_DIR/gtk-4.0"

apply_gtk3_colors "$CONFIG_DIR"
apply_gtk4_colors "$CONFIG_DIR"

echo "GTK colors applied successfully"
