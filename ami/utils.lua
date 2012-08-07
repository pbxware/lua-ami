--------------------------------------------------------------------------------
--- utility functions
-- @module ami.utils
-- @license MIT/X11
-- @copyright Lua-AMI authors (see file `COPYRIGHT`)
--------------------------------------------------------------------------------
-- This module is part of implementation, not API
--------------------------------------------------------------------------------

local assert, type, tostring = assert, type, tostring

--- Dumb simple checker for protocol return value
--
--  @param response reply from manager
--  @param field optional field in response (default "Message")
--  @return value from field
--  @return "Error" field from structure, if reply type is "Error"
local check_reply = function(response, field)
  assert(type(response)=="table", "response is not a table")
  if field then
    assert(type(field)=="string", "field is not a string or nil")
  end

  field = field or "Message"
  if response and response.Response == "Success" then
    if response[field] then
      return tostring(response[field])
    else
      return nil, "Reply structure miss required field: " .. field
    end
  end

  if response and response.Response == "Error" then
    return nil, tostring(response.Message) or "unknown AMI failure"
  end

  return nil, "malformed reply"
end

return
{
  check_reply = check_reply;
}
