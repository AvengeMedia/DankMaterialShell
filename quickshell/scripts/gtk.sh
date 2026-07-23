#!/usr/bin/env bash

CONFIG_DIR="$1"
# apply: setup symlinks and config dirs
# patch: refresh overrides in adw-gtk3
# remove: remove all overrides
MODE="${2:-apply}"
IS_LIGHT="${3:-light}"

if [ -z "$CONFIG_DIR" ]; then
	echo "Usage: $0 <config_dir> [apply|patch|remove] [is_light] [shell_dir]" >&2
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

remove_gtk3_patch() {
	local theme_dir="$1"
	local css_variant="$2"
	[ "$css_variant" != "-dark" ] && css_variant=""
	sed -i '/\/\* BEGIN DMS OVERRIDE \*\//,/\/\* END DMS OVERRIDE \*\//d' "${theme_dir}/gtk${css_variant}.css"
	return $?
}

remove_gtk3_colors() {
	local config_dir="$1"

	local gtk3_dir="$config_dir/gtk-3.0"

	# remove global override
	if [ ! -f "${gtk3_dir}/dank-colors.css" ]; then
		echo "Nothing to remove at '${gtk3_dir}'"
	else
		if rm "${gtk3_dir}/dank-colors.css"; then
			echo "Removed GTK3 override form '${gtk3_dir}'"
		else
			echo "Failed to removed GTK3 override from '${gtk3_dir}'"
		fi
	fi

	# remove adw-gtk3 inclusions
	for variant in light dark; do
		local adw_gtk3_dir && adw_gtk3_dir=$(get_adw_gtk3_dir "$variant")

		if [ -z "$adw_gtk3_dir" ]; then
			echo "Error: No version of adw-gtk3 ${variant} was found" >&2
			exit 1
		fi

		for css_variant in light dark; do
			if remove_gtk3_patch "$adw_gtk3_dir" "$css_variant"; then
				echo "Removed GTK colors patch from '${adw_gtk3_dir}' in '$css_variant' stylesheet"
			else
				echo "Failed to remove GTK colors patch from '${adw_gtk3_dir}' in '$css_variant' stylesheet" >&2
			fi
		done
	done
}

do_patch() {
	local theme_dir="$1"
	local variant="$2"
	local css_variant=""
	[ "$variant" = "dark" ] && css_variant="-${variant}"
	if {
		remove_gtk3_patch "$theme_dir" "$css_variant"
		cat "${gtk3_dir}/dank-colors.css" >>"${theme_dir}/gtk${css_variant}.css"
	}; then
		echo "Successfully patched '$theme_dir/gtk${css_variant}.css' with GTK '$variant' colors"
	else
		echo "Error: failed to patch '$theme_dir/gtk${css_variant}.css' with GTK '$variant' colors" >&2
		exit 1
	fi
}

patch_gtk3_colors() {
	local config_dir="$1"
	local is_light="$2"

	# Include generated colors for current variant
	local gtk3_dir="$config_dir/gtk-3.0"
	local variant="light"
	[ "$is_light" = "false" ] && variant="dark"
	local adw_gtk3_dir && adw_gtk3_dir=$(get_adw_gtk3_dir "$variant")

	if [ -z "$adw_gtk3_dir" ]; then
		echo "Warning: No version of adw-gtk3 ${variant} was found" >&2
		exit 1
	fi

	if [[ "$adw_gtk3_dir" =~ ^/usr ]]; then
		echo "Warning: No user version of adw-gtk3 ${variant} was found." >&2
		exit 1
	fi

	if [ ! -f "${gtk3_dir}/dank-colors.css" ]; then
		echo "Error: GTK3 dank-colors.css not found at '${gtk3_dir}'" >&2
		echo "Run matugen first to generate theme files" >&2
		exit 1
	fi

	# NOTE : for adw-gtk3-dark gtk.css and gtk-dark.css are the same file
	if [ "$variant" = "dark" ]; then
		do_patch "$adw_gtk3_dir" "dark"
		do_patch "$adw_gtk3_dir" "light"
		do_patch "$(get_adw_gtk3_dir "light")" "dark"
	else
		do_patch "$adw_gtk3_dir" "light"
	fi
}

apply_gtk3_colors() {
	local config_dir="$1"

	local gtk3_dir="$config_dir/gtk-3.0"
	local gtk3_override="$gtk3_dir/gtk.css"
	# If no adw-gtk3 or only system wide, use global override
	local adw_gtk3 && adw_gtk3="$(get_adw_gtk3_dir)"
	if [[ "$adw_gtk3" =~ ^/usr ]] || [[ -z "$adw_gtk3" ]]; then
		echo "Warning: No user version of adw-gtk3 found" >&2
		echo "Falling back on global css override" >&2
		local dank_colors="$gtk3_dir/dank-colors.css"

		if [ ! -f "$dank_colors" ]; then
			echo "Error: dank-colors.css not found at $dank_colors" >&2
			echo "Run matugen first to generate theme files" >&2
			exit 1
		fi

		if [ -L "$gtk3_override" ]; then
			rm "$gtk3_override"
		elif [ -f "$gtk3_override" ]; then
			mv "$gtk3_override" "$gtk3_override.backup.$(date +%s)"
			echo "Backed up existing gtk.css"
		fi

		ln -s "dank-colors.css" "$gtk3_override"
		echo "Created symlink: $gtk3_override -> dank-colors.css"

		link_gtk3_assets "$gtk3_dir"

		return
	fi

	# Else ensure there's no global override
	if [ -L "$gtk3_override" ]; then
		rm "$gtk3_override"
	elif [ -f "$gtk3_override" ]; then
		mv "$gtk3_override" "$gtk3_override.backup.$(date +%s)"
		echo "Backed up and removed existing gtk.css"
	fi

	# Backup adw-gtk3 stylesheets
	for variant in light dark; do
		local adw_gtk3_dir && adw_gtk3_dir="$(get_adw_gtk3_dir "$variant")"
		cp "$adw_gtk3_dir/gtk-3.0/gtk.css" "$adw_gtk3_dir/gtk-3.0/gtk.css.backup.$(date +%s)"
		cp "$adw_gtk3_dir/gtk-3.0/gtk-dark.css" "$adw_gtk3_dir/gtk-3.0/gtk-dark.css.backup.$(date +%s)"
	done
}

remove_gtk4_colors() {
	local config_dir="$1"

	local gtk4_dir="$config_dir/gtk-4.0"
	local dank_colors="$gtk4_dir/dank-colors.css"
	local gtk_css="$gtk4_dir/gtk.css"

	if [ ! -f "$dank_colors" ]; then
		echo "Nothing to remove in '$gtk4_dir'"
		return
	fi

	rm "$dank_colors"
	echo "Removed 'dank-colors.css' from '$gtk4_dir'"

	local gtk4_import="@import url(\"dank-colors.css\");"
	if [ -f "$gtk_css" ] && grep -q '^@import url.*dank-colors\.css.*);$' "$gtk_css"; then
		sed -i "/$gtk4_import/d" "$gtk_css"
		echo "Removed gtk4 import in '$gtk_css'"
	fi

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

case "$MODE" in
	patch)
		patch_gtk3_colors "$CONFIG_DIR" "$IS_LIGHT"
		echo "GTK3 colors patched successfully"
		;;
	remove)
		remove_gtk3_colors "$CONFIG_DIR"
		remove_gtk4_colors "$CONFIG_DIR"
		;;
	apply)
		mkdir -p "$CONFIG_DIR/gtk-3.0" "$CONFIG_DIR/gtk-4.0"

		apply_gtk3_colors "$CONFIG_DIR"
		apply_gtk4_colors "$CONFIG_DIR"

		echo "GTK colors applied successfully"
		;;
	*)
		echo "Usage: $0 <config_dir> [apply|patch|remove] [is_light] [shell_dir]" >&2
		exit 1
		;;
esac
