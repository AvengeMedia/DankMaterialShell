# Niri generated configuration

DMS writes generated Niri configuration fragments to `~/.config/niri/dms` by
default.

To keep those fragments in another directory, set `DMS_NIRI_CONFIG_DIR` before
starting DMS:

```sh
export DMS_NIRI_CONFIG_DIR="$HOME/.config/nix/niri/dms"
```

The override applies to generated layout, input, cursor, output, blur, colors,
bindings, window rules, and Alt-Tab fragments. Your Niri configuration must
include the files from the selected directory instead of the default path.

Leaving the variable unset preserves the default behavior.
