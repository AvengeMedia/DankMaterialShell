return {
	{
		"RRethy/base16-nvim",
		priority = 1000,
		config = function()
			require('base16-colorscheme').setup({
				base00 = '{{dank16.color0.default.hex}}',
				base01 = '{{dank16.color0.default.hex}}',
				base02 = '{{dank16.color8.default.hex}}',
				base03 = '{{dank16.color8.default.hex}}',
				base04 = '{{dank16.color7.default.hex}}',
				base05 = '{{dank16.color15.default.hex}}',
				base06 = '{{dank16.color15.default.hex}}',
				base07 = '{{dank16.color15.default.hex}}',
				base08 = '{{dank16.color9.default.hex}}',
				base09 = '{{dank16.color9.default.hex}}',
				base0A = '{{dank16.color12.default.hex}}',
				base0B = '{{dank16.color10.default.hex}}',
				base0C = '{{dank16.color14.default.hex}}',
				base0D = '{{dank16.color12.default.hex}}',
				base0E = '{{dank16.color13.default.hex}}',
				base0F = '{{dank16.color13.default.hex}}',
			})

			vim.api.nvim_set_hl(0, 'Visual', {
				bg = '{{dank16.color8.default.hex}}',
				fg = '{{dank16.color15.default.hex}}',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Statusline', {
				bg = '{{dank16.color12.default.hex}}',
				fg = '{{dank16.color0.default.hex}}',
			})
			vim.api.nvim_set_hl(0, 'LineNr', { fg = '{{dank16.color8.default.hex}}' })
			vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = '{{dank16.color14.default.hex}}', bold = true })

			vim.api.nvim_set_hl(0, 'Statement', {
				fg = '{{dank16.color13.default.hex}}',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Keyword', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Repeat', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Conditional', { link = 'Statement' })

			vim.api.nvim_set_hl(0, 'Function', {
				fg = '{{dank16.color12.default.hex}}',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Macro', {
				fg = '{{dank16.color12.default.hex}}',
				italic = true
			})
			vim.api.nvim_set_hl(0, '@function.macro', { link = 'Macro' })

			vim.api.nvim_set_hl(0, 'Type', {
				fg = '{{dank16.color14.default.hex}}',
				bold = true,
				italic = true
			})
			vim.api.nvim_set_hl(0, 'Structure', { link = 'Type' })

			vim.api.nvim_set_hl(0, 'String', {
				fg = '{{dank16.color10.default.hex}}',
				italic = true
			})

			vim.api.nvim_set_hl(0, 'Operator', { fg = '{{dank16.color7.default.hex}}' })
			vim.api.nvim_set_hl(0, 'Delimiter', { fg = '{{dank16.color7.default.hex}}' })
			vim.api.nvim_set_hl(0, '@punctuation.bracket', { link = 'Delimiter' })
			vim.api.nvim_set_hl(0, '@punctuation.delimiter', { link = 'Delimiter' })

			vim.api.nvim_set_hl(0, 'Comment', {
				fg = '{{dank16.color8.default.hex}}',
				italic = true
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
