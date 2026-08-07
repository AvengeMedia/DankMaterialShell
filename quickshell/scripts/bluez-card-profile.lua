#!/usr/bin/wpexec
cutils = require("common-utils")

local args = (...):parse()
local mode = args.mode or "list"
local dev_name = args.device or ""
local target = args.target or ""

local function fail(msg)
  print("ERROR: " .. msg)
  Core.quit()
end

if dev_name == "" then
  fail("missing device")
  return
end

local om = ObjectManager {
  Interest {
    type = "device",
    Constraint { "media.class", "=", "Audio/Device", type = "pw-global" },
  }
}

local handled = false

local function profile_available(profile)
  return profile and profile.available ~= "no"
end

local codec_profile_prefixes = {
  "^a2dp%-sink%-(.+)$",
  "^a2dp%-source%-(.+)$",
  "^headset%-head%-unit%-(.+)$",
  "^headset%-audio%-gateway%-(.+)$",
}

local function codec_from_profile(profile)
  if not profile then
    return ""
  end
  local name = profile.name or ""
  for _, pattern in ipairs(codec_profile_prefixes) do
    local codec = name:match(pattern)
    if codec then
      return codec:gsub("%-", "_"):upper()
    end
  end
  local desc = profile.description or ""
  local codec = desc:match("[Cc]odec%s+([%w%+%-%._]+)")
  if not codec then
    return ""
  end
  return codec:gsub("%-", "_"):upper()
end

local function handle_device(device)
  if handled then
    return
  end
  local name = device.properties["device.name"] or ""
  if name ~= dev_name then
    return
  end
  handled = true

  if mode == "list" then
    local active_index = nil
    for p in device:iterate_params("Profile") do
      local active = cutils.parseParam(p, "Profile")
      if active then
        active_index = active.index
      end
    end

    for p in device:iterate_params("EnumProfile") do
      local profile = cutils.parseParam(p, "EnumProfile")
      if profile_available(profile) then
        local codec = codec_from_profile(profile)
        if codec ~= "" then
          local current = (active_index ~= nil and profile.index == active_index) and "1" or "0"
          print(string.format("CODEC\t%s\t%s\t%s\t%s", codec, profile.name, profile.description or "", current))
        end
      end
    end
    Core.quit()
    return
  end

  if mode == "set" then
    if target == "" then
      fail("missing target")
      return
    end

    local target_lower = tostring(target):lower()
    local match = nil
    for p in device:iterate_params("EnumProfile") do
      local profile = cutils.parseParam(p, "EnumProfile")
      if profile_available(profile) then
        local pname = profile.name or ""
        local codec = codec_from_profile(profile):lower()
        if pname == target or pname:lower() == target_lower or codec == target_lower
            or codec == target_lower:gsub("%-", "_") then
          match = profile
          break
        end
      end
    end

    if not match then
      fail("profile not found: " .. target)
      return
    end

    local param = Pod.Object {
      "Spa:Pod:Object:Param:Profile", "Profile",
      index = tonumber(match.index),
      save = true,
    }
    device:set_param("Profile", param)
    Core.sync(function()
      print("OK\t" .. (match.name or target))
      Core.quit()
    end)
    return
  end

  fail("unknown mode " .. mode)
end

om:connect("object-added", function(_, device)
  handle_device(device)
end)

om:connect("installed", function()
  if handled then
    return
  end
  for device in om:iterate() do
    handle_device(device)
    if handled then
      return
    end
  end
  fail("device not found: " .. dev_name)
end)

om:activate()
Core.timeout_add(3000, function()
  if not handled then
    fail("timed out waiting for device " .. dev_name)
  end
  return false
end)
