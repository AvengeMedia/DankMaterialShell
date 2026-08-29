-- Minimal Hyprland (Lua) session for greetd — replace _DMS_PATH_ with your DMS checkout.
-- Copy to `/etc/greetd/dms-hypr.lua` alongside `greet-hyprland.sh`.

hl.env("DMS_RUN_GREETER", "1")

hl.on("hyprland.start", function()
	hl.exec_cmd('sh -c "qs -p _DMS_PATH_; hyprctl dispatch exit"')
end)
