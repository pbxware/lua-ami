--------------------------------------------------------------------------------
-- io.lua: simple blocking IO
-- This file is a part of Lua-AMI library
-- Copyright (c) Lua-AMI authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

local message = require "lua-ami.message"
local parse_line = message.parse_line

--------------------------------------------------------------------------------

local read = function(socket)
  local t = { }
  while true do
    -- read one line
    local line, err_msg = socket:receive()
    if not line then
      return nil, err_msg
    end
    if #line == 0 then
      return t
    end
    local k, v = parse_line(line)
    if k then
      --print(line)
      print(k, v)
      if t[k] then
        if type(t[k]) ~= "table" then
          t[k] = { t[k] }
        end
        t[k][#t + 1] = v
      else
        t[k] = v
      end
    end
  end
end

local write = function(socket, data)
  print(data)
  local sent, err_msg = socket:send(data)
  --TODO handle partial send
  assert(sent == #data)
  return sent, err_msg
end

return
{
  read = read;
  write = write;
}
