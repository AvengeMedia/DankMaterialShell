#!/usr/bin/env bash

CONFIG_DIR="$1"
DATA_DIR="$2"

if [ -z "$CONFIG_DIR" ]; then
	echo "Usage: $0 <config_dir>" >&2
	exit 1
fi

if [ -z "$DATA_DIR" ]; then
	echo "Usage: $0 <data_dir>" >&2
	exit 1
fi

apply_gtk3_colors() {
	local config_dir="$1"
	local data_dir="$2"

	# Make sure there's no global override
	local gtk3_dir_cfg="$config_dir/gtk-3.0"
	local dank_colors_cfg="$gtk3_dir_cfg/dank-colors.css"
	local gtk_css_cfg="$gtk3_dir_cfg/gtk.css"
	for file in "$dank_colors_cfg" "$gtk_css_cfg"; do
		if [ -f "$file" ]; then
			mv "$file" "$file.backup"
		fi
	done

	for variant in light dark; do
		[ "$variant" = "light" ] && name="" || name="-$variant"
		local gtk3_dir_main="$data_dir/themes/adw-gtk3${name}/gtk-3.0"
		local dank_colors_main="$gtk3_dir_main/dank-colors.css"
		local gtk_css_main="$gtk3_dir_main/gtk.css"
		local gtk_import="@import url('dank-colors.css');"

		if [ ! -d "$data_dir/themes/adw-gtk3${name}" ]; then
			echo "Error: No user version of adw-gtk3 found at '$data_dir/themes'" >&2
			exit 1
		fi

		if [ ! -f "$dank_colors_main" ]; then
			echo "Error: GTK3 dank-colors.css not found at '$dank_colors_main'" >&2
			echo "Run matugen first to generate theme files" >&2
			exit 1
		fi

		if [ -f "$gtk_css_main" ] && grep -q '^@import url.*dank-colors\.css.*);$' "$gtk_css_main"; then
			echo "GTK3 $variant import already exists" >&2
			return
		fi
		echo "$gtk_import" >>"$gtk_css_main"
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

mkdir -p "$CONFIG_DIR/gtk-4.0"
apply_gtk3_colors "$CONFIG_DIR" "$DATA_DIR"
apply_gtk4_colors "$CONFIG_DIR"

echo "GTK colors applied successfully"
