return {
	{
		"RRethy/base16-nvim",
		priority = 1000,
		config = function()
			require('base16-colorscheme').setup({
				base00 = '{{colors.background.default.hex}}',

				base01 = '{{colors.surface_container.default.hex}}',
				base02 = '{{colors.surface_container_high.default.hex}}',
				base03 = '{{colors.outline_variant.default.hex}}',

				base04 = '{{colors.on_surface_variant.default.hex}}',
				base05 = '{{colors.on_surface.default.hex}}',
				base06 = '{{colors.inverse_on_surface.default.hex}}',
				base07 = '{{colors.inverse_surface.default.hex}}',

				base08 = '{{colors.error.default.hex}}',
				base09 = '{{colors.tertiary_fixed_dim.default.hex}}',
				base0A = '{{colors.secondary_fixed.default.hex}}',
				base0B = '{{colors.primary_fixed.default.hex}}',
				base0C = '{{colors.tertiary.default.hex}}',
				base0D = '{{colors.primary.default.hex}}',
				base0E = '{{colors.secondary.default.hex}}',
				base0F = '{{colors.outline.default.hex}}',
			})

			local current_file_path = vim.fn.stdpath("config") .. "/lua/plugins/dankcolors.lua"
			if not _G._matugen_theme_watcher then
				local uv = vim.uv or vim.loop
				_G._matugen_theme_watcher = uv.new_fs_event()
				_G._matugen_theme_watcher:start(current_file_path, {}, vim.schedule_wrap(function()
					local new_spec = dofile(current_file_path)
					if new_spec and new_spec[1] and new_spec[1].config then
						new_spec[1].config()
						print("Theme reload")
					end
				end))
			end
		end
	}
}
