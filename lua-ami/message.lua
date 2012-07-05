--------------------------------------------------------------------------------
-- message.lua: low level builder/parser AMI messages
-- This file is a part of Lua-AMI library
-- Copyright (c) Lua-AMI authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

require"md5"

local concat = table.concat
local find, sub, match = string.find, string.sub, string.match

--------------------------------------------------------------------------------

local add_line = function(t, key, value)
  if value then
    t[#t + 1] = key .. ": " .. value
  end
end

local finalize = function(t)
  t[#t + 1] = "\n"
  return concat(t, "\n")
end

local build_challenge = function()
  return "Action: Challenge\nAuthType: md5\n\n"
end

local build_login_simple = function(
    user_name,
    password
  )
  local t = { }
  add_line(t, "Action", "Login")
  add_line(t, "Username", user_name)
  add_line(t, "Secret", password)
  return finalize(t)
end

local build_login = function(
    user_name,
    challenge,
    password
  )
  local t = { }
  add_line(t, "Action", "Login")
  add_line(t, "AuthType", "md5")
  add_line(t, "Username", user_name)
  add_line(t, "Key", md5.sumhexa(challenge .. password))
  return finalize(t)
end

local build_logoff = function()
  return "Action: Logoff\n\n"
end

local build_event = function(event_mask)
  local t = { }
  add_line(t, "Action", "Events")
  add_line(t, "Eventmask", event_mask)
  return finalize(t)
end

local build_originate = function(
    channel,
    context,
    exten,
    priority,
    async,
    timeout,
    caller_id,
    action_id,
    variable
  )
  local t = { }
  add_line(t, "Action", "Originate")
  add_line(t, "Channel", channel)
  add_line(t, "Context", context)
  add_line(t, "Exten", exten)
  add_line(t, "Priority", priority)
  add_line(t, "Timeout", timeout)
  add_line(t, "CallerID", caller_id)
  add_line(t, "ActionID", action_id)
  add_line(t, "Variable", variable)
  add_line(t, "Async", async)
  return finalize(t)
end

--------------------------------------------------------------------------------

local parse_line = function(line)
  local pos = find(line, ":", 1, true)
  if not pos then
    -- bad formatted line, ignore
    return
  end
  local k = sub(line, 1, pos - 1)
  local v = match( sub(line, pos + 1), "^%s*(.+)$")
  return k, v
end

--------------------------------------------------------------------------------

return
{
  build_challenge = build_challenge;
  build_login_simple = build_login_simple;
  build_login = build_login;
  build_logoff = build_logoff;
  build_originate = build_originate;
  --
  parse_line = parse_line;
}
