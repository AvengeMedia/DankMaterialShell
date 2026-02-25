return {
	{
		"RRethy/base16-nvim",
		priority = 1000,
		config = function()
			require('base16-colorscheme').setup({

				base00 = '{{colors.background.dark.hex}}',
				base01 = '{{colors.surface_container_low.dark.hex}}',
				base02 = '{{colors.surface_container.dark.hex}}',
				base03 = '{{dank16.color8.dark.hex}}',
				base0B = '{{dank16.color3.dark.hex}}',
				base04 = '{{dank16.color7.default.hex}}',
				base05 = '{{dank16.color15.default.hex}}',
				base06 = '{{dank16.color15.default.hex}}',
				base07 = '{{dank16.color15.default.hex}}',
				base08 = '{{dank16.color9.default.hex}}',
				base09 = '{{dank16.color9.default.hex}}',
				base0A = '{{dank16.color12.default.hex}}',
				base0C = '{{dank16.color14.default.hex}}',
				base0D = '{{dank16.color12.default.hex}}',
				base0E = '{{dank16.color13.default.hex}}',
				base0F = '{{dank16.color13.default.hex}}',
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
