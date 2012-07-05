--------------------------------------------------------------------------------
-- lua-ami.lua: Lua module to talk with Asterisk by AMI protocol
-- This file is a part of Lua-AMI library
-- Copyright (c) Lua-AMI authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

local socket = require "socket"

local ami_message = require "lua-ami.message"
local build_challenge,
  build_login_simple,
  build_login,
  build_logoff,
  build_originate =
  ami_message.build_challenge,
  ami_message.build_login_simple,
  ami_message.build_login,
  ami_message.build_logoff,
  ami_message.build_originate

local ami_io = require "lua-ami.io"
local ami_read, ami_write = ami_io.read, ami_io.write

local format = string.format

--------------------------------------------------------------------------------

local DEFAULT_AMI_PORT = 5038

--------------------------------------------------------------------------------

local make_ami_manager
do
  local login = function(self)
    local socket = self.socket_
    assert(ami_write(socket, build_challenge()))
    local response = assert(ami_read(socket))
    assert(response.Challenge)
    assert(ami_write(socket, build_login(
        self.config_.user_name,
        response.Challenge,
        self.config_.password
      )))
    response = assert(ami_read(socket))
    if response.Response == "Success" then
      return true, response
    end
    return false, response
  end

  local logoff = function(self)
    local socket = self.socket_
    assert(ami_write(socket, build_logoff()))
    -- TODO: shall we read response here?!
    local response = assert(ami_read(socket))
    if response.Response == "Success" then
      return true, response
    end
    return false, response
  end

  local originate
  do
    local function wait_for_originate_response(socket, action_id)
      local response = assert(ami_read(socket))
      if response.ActionID == action_id then
        if response.Event and response.Event == "OriginateResponse" then
          return response
        end
      end
      return wait_for_originate_response(s, action_id)
    end

    originate = function(self, phone_number)
      local socket = self.socket_
      local config = self.config_
      self.action_id_ = self.action_id_ + 1
      local action_id = format("%010d", self.action_id_)
      assert(ami_write(socket, build_originate(
          config.channel,
          config.context,
          phone_number,
          config.priority,
          "true", -- async
          config.timeout,
          config.caller_id,
          action_id
        )))
      local response = wait_for_originate_response(socket, action_id)
      if response.Response == "Success" then
        return true, response
      end
      return false, response
    end
  end

  local close = function(self)
    self.socket_:close()
  end

  make_ami_manager = function(config)
    assert(type(config) == "table")
    local socket = assert(socket.tcp())
    assert(socket:connect(config.host, config.port or DEFAULT_AMI_PORT))
    local greeting, err_msg = assert(socket:receive())
    --print(greeting)
    return
    {
      login = login;
      originate = originate;
      logoff = logoff;
      close = close;
      --
      config_ = config;
      socket_ = socket;
      action_id_ = 0;
    }
  end
end

return
{
  make_ami_manager = make_ami_manager;
}