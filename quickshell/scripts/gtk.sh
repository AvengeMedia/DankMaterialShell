#!/usr/bin/env bash

CONFIG_DIR="$1"
# apply: setup overrides and config dirs
# patch: refresh overrides in adw-gtk3
# remove: remove all overrides
# assets: relink adw-gtk3 assets if DMS already manages gtk.css
MODE="${2:-apply}"
IS_LIGHT="${3:-light}"
SHELL_DIR="$4"

if [ -z "$CONFIG_DIR" ]; then
	echo "Usage: $0 <config_dir> [apply|patch|remove|assets] [is_light] [shell_dir]" >&2
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

# The light template references adw-gtk3 image assets relative to gtk.css
# (check/radio glyphs, slider knobs); without them checked boxes render as
# solid blocks.
link_gtk3_assets() {
	local gtk3_dir="$1"
	local assets_link="$gtk3_dir/assets"

	if [ -e "$assets_link" ] && [ ! -L "$assets_link" ]; then
		echo "Leaving user-managed $assets_link in place"
		return
	fi

	local candidates=(
		"$HOME/.local/share/themes/adw-gtk3/gtk-3.0/assets"
		"$HOME/.themes/adw-gtk3/gtk-3.0/assets"
		"/usr/share/themes/adw-gtk3/gtk-3.0/assets"
		"/usr/local/share/themes/adw-gtk3/gtk-3.0/assets"
	)
	local target=""
	for c in "${candidates[@]}"; do
		if [ -d "$c" ]; then
			target="$c"
			break
		fi
	done
	if [ -z "$target" ] && [ -n "$SHELL_DIR" ] && [ -d "$SHELL_DIR/matugen/gtk3-assets" ]; then
		target="$SHELL_DIR/matugen/gtk3-assets"
	fi
	if [ -z "$target" ]; then
		return
	fi

	ln -sfn "$target" "$assets_link"
	echo "Linked GTK3 assets: $assets_link -> $target"
}

DANK_IMPORT='@import url("dank-colors.css");'
DANK_IMPORT_RE='^@import url.*dank-colors\.css.*);$'

# gtk.css is DMS-managed if it is our symlink or carries our import line.
# User-managed symlinks (e.g. home-manager) are never touched.
dms_managed_css() {
	local gtk_css="$1"
	if [ -L "$gtk_css" ]; then
		case "$(readlink "$gtk_css")" in
			*dank-colors.css*) return 0 ;;
			*) return 1 ;;
		esac
	fi
	[ -f "$gtk_css" ] && grep -q "$DANK_IMPORT_RE" "$gtk_css"
}

inject_dank_import() {
	local gtk_css="$1"

	if [ -L "$gtk_css" ]; then
		if ! dms_managed_css "$gtk_css"; then
			echo "Warning: '$gtk_css' is a user-managed symlink; leaving it untouched" >&2
			echo "Import dank-colors.css from your own stylesheet to use DMS colors" >&2
			return 1
		fi
		rm "$gtk_css"
	fi

	if [ -f "$gtk_css" ] && grep -q "$DANK_IMPORT_RE" "$gtk_css"; then
		echo "Dank import already present in '$gtk_css'"
		return 0
	fi

	if [ -f "$gtk_css" ] && [ -s "$gtk_css" ]; then
		sed -i "1i\\$DANK_IMPORT" "$gtk_css"
	else
		echo "$DANK_IMPORT" >"$gtk_css"
	fi
	echo "Added dank-colors import to '$gtk_css'"
}

remove_dank_import() {
	local gtk_css="$1"

	if [ -L "$gtk_css" ]; then
		if dms_managed_css "$gtk_css"; then
			rm "$gtk_css"
			echo "Removed DMS-managed symlink '$gtk_css'"
		fi
		return 0
	fi

	if [ -f "$gtk_css" ] && grep -q "$DANK_IMPORT_RE" "$gtk_css"; then
		sed -i "/$DANK_IMPORT_RE/d" "$gtk_css"
		echo "Removed dank-colors import from '$gtk_css'"
	fi
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
	remove_dank_import "$gtk3_dir/gtk.css"
	if [ ! -f "${gtk3_dir}/dank-colors.css" ]; then
		echo "Nothing to remove at '${gtk3_dir}'"
	else
		if rm "${gtk3_dir}/dank-colors.css"; then
			echo "Removed GTK3 override from '${gtk3_dir}'"
		else
			echo "Failed to remove GTK3 override from '${gtk3_dir}'"
		fi
	fi

	# remove adw-gtk3 inclusions
	for variant in light dark; do
		local adw_gtk3_dir && adw_gtk3_dir=$(get_adw_gtk3_dir "$variant")

		if [ -z "$adw_gtk3_dir" ] || [[ "$adw_gtk3_dir" =~ ^/usr ]]; then
			echo "No user version of adw-gtk3 ${variant} found, nothing to unpatch"
			continue
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
	if [ -z "$theme_dir" ] || [[ "$theme_dir" =~ ^/usr ]]; then
		echo "Skipping '$variant' patch: no user copy of adw-gtk3 for this variant"
		return 0
	fi
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

	if [ -z "$adw_gtk3_dir" ] || [[ "$adw_gtk3_dir" =~ ^/usr ]]; then
		echo "No user version of adw-gtk3 ${variant} was found, skipping patch"
		exit 2
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

		inject_dank_import "$gtk3_override" || exit 1
		link_gtk3_assets "$gtk3_dir"

		return
	fi

	# adw-gtk3 carries the colors; ensure there's no DMS global override
	remove_dank_import "$gtk3_override"

	# Backup pristine adw-gtk3 stylesheets once
	for variant in light dark; do
		local adw_gtk3_dir && adw_gtk3_dir="$(get_adw_gtk3_dir "$variant")"
		for css in gtk.css gtk-dark.css; do
			if [ -f "$adw_gtk3_dir/$css" ] && [ ! -f "$adw_gtk3_dir/$css.dms-backup" ]; then
				cp "$adw_gtk3_dir/$css" "$adw_gtk3_dir/$css.dms-backup"
			fi
		done
	done
}

remove_gtk4_colors() {
	local config_dir="$1"

	local gtk4_dir="$config_dir/gtk-4.0"
	local dank_colors="$gtk4_dir/dank-colors.css"
	local gtk_css="$gtk4_dir/gtk.css"

	remove_dank_import "$gtk_css"

	if [ ! -f "$dank_colors" ]; then
		echo "Nothing to remove in '$gtk4_dir'"
		return
	fi

	rm "$dank_colors"
	echo "Removed 'dank-colors.css' from '$gtk4_dir'"
}

apply_gtk4_colors() {
	local config_dir="$1"

	local gtk4_dir="$config_dir/gtk-4.0"
	local dank_colors="$gtk4_dir/dank-colors.css"
	local gtk_css="$gtk4_dir/gtk.css"

	if [ ! -f "$dank_colors" ]; then
		echo "Error: GTK4 dank-colors.css not found at $dank_colors" >&2
		echo "Run matugen first to generate theme files" >&2
		exit 1
	fi

	inject_dank_import "$gtk_css" || exit 1
}

case "$MODE" in
	patch)
		# Only refresh themes the user opted into via 'apply'
		if ! dms_managed_css "$CONFIG_DIR/gtk-4.0/gtk.css"; then
			echo "DMS GTK theming is not applied, skipping patch"
			exit 2
		fi
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
	assets)
		# Repair pass at startup; only acts when DMS already manages gtk.css
		if dms_managed_css "$CONFIG_DIR/gtk-3.0/gtk.css"; then
			link_gtk3_assets "$CONFIG_DIR/gtk-3.0"
		fi
		;;
	*)
		echo "Usage: $0 <config_dir> [apply|patch|remove|assets] [is_light] [shell_dir]" >&2
		exit 1
		;;
esac
