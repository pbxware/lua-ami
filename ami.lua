--------------------------------------------------------------------------------
--- Lua module to talk with Asterisk by AMI protocol.
-- @module ami
-- @license MIT/X11
-- @copyright Lua-AMI authors (see file `COPYRIGHT`)
--------------------------------------------------------------------------------

local uuid = require "uuid"

local make_connection = require "ami.connection".make_connection
local simple_login = require "ami.login".simple_login
local challenge_login = require "ami.login".challenge_login
local check_reply = require "ami.utils".check_reply

local type, assert = type, assert

--------------------------------------------------------------------------------

-- @field DEFAULT_AMI_PORT  default TCP port number for AMI
local DEFAULT_AMI_PORT = 5038

--------------------------------------------------------------------------------

local make_ami_manager
do
  local generate_action_id = function()
    return uuid.new()
  end

  --- Wait for specified reply
  --   all other events ignored
  -- @param self AMI manager object
  -- @param action_id ID of reply
  -- @return response structure from AMI or nil, if error occured
  -- @return error string, if error occured, otherwise nil
  local wait_for_reply = function(self, action_id)
    assert(type(self) == "table", "self is not a table (AMI object)")
    assert(type(action_id) == "string", "action_id is not string")

    local conn, err = self:get_connection()
    if not conn then
      return nil, err
    end

    local response, err = conn:get_reply()
    while response ~= nil and  action_id ~= response.ActionID do
      response, err = conn:get_reply()
    end
    if err then
      return nil, err
    end
    return response
  end

  --- Logoff from AMI interface
  -- @param self AMO object
  -- @return
  local logoff = function(self)
    assert(type(self) == "table", "self is not a table")

    local conn = self.conn_

    -- don't connect/login specially to log out.
    if not conn then
      return nil, "closed"
    end

    local response, err = conn:command("Logoff", { })
    if not err then
      response, err = conn:get_reply()
      conn:close()
      self.conn_ = nil
      if response then
        return check_reply(response)
      end
      -- escalate error, if any
      return response, err
    end
    return nil, err
  end

  --- Originate call from asterisk
  -- @param self AMI object
  -- @param phone_number
  -- @return result message from asterisk, or nil if error occured
  -- @return error message if error occured, nil otherwise
  local originate
  do
    originate = function(self, phone_number)
      assert(type(self) == "table", "self is not a table (AMI object)")
      assert(type(phone_number) == "string", "phone_nuper is not a string")

      local conn, err = self:get_connection()
      if not conn then
        return nil, err
      end

      local config = self.config_
      local action_id = generate_action_id(self)
      local response
      response, err = conn:command(
          "Originate",
          {
            Channel = config.channel;
            Context = config.context;
            Exten = phone_number;
            Timeout = config.timeout;
            Async = "False";
            CallerID = config.caller_id;
            ActionID = action_id;
          }
        )

      if response then
        local response, err = self:wait_for_reply(action_id)
        if response then
          return check_reply(response)
        end
      end

      return nil, err
    end
  end

  --- Private: connect and authorize on demand
  -- @param self AMI manager object
  -- @return AMI connection object
  local establish_connection = function(self)
    local config = self.config_
    local conn, err = make_connection(
        config.host,
        config.port or DEFAULT_AMI_PORT,
        config.timeout,
        config.logger
      )
    if not conn then
      return nil, err
    end

    local result
    if config.secure then
      result, err = challenge_login(conn, config.user_name, config.secret)
    else
      result, err = simple_login(conn, config.user_name, config.secret)
    end

    if result == nil then
      return nil, "AMI login failed: " .. err
    end

    self.conn_ = conn
    return conn
  end

  --- connect and authorize on demand
  -- @param self AMI manager object
  -- @return AMI connection object
  local get_connection = function(self)
    if not self.conn_ then
      return establish_connection(self)
    end
    return self.conn_
  end

  --- Make AMI manager object
  --  @param config -- table with configuration values
  --  @field host  host to connect
  --  @field port  port to connect
  --  @return AMI manager object
  make_ami_manager = function(config)
    assert(type(config) == "table", "config is not a table")
    assert(type(config.host) == "string", "config.host is not a string")
    if config.port ~= nil  then
      assert(type(config.port) == "number", "config.port is not a string")
    end
    if config.timeout then
      assert(type(config.timeout) == "number", "config.port is not a string")
    end
    assert(
        type(config.user_name) == "string",
        "config.user_name is not a string"
      )
    assert(type(config.secret) == "string", "config.secret is not a string")
    assert(type(config.secure) == "boolean", "config.secure is not a boolean")
    assert(type(config.channel) == "string", "config.channel is not a string")
    assert(type(config.priority) == "number", "config.priority is not a string")
    if config.logger ~= nil then
      assert(
          type(config.logger) == "function",
          "config.logger is not a function"
        )
    end

    return
    {
      -- Public methods
      originate = originate;
      logoff = logoff;

      -- internal method
      get_connection = get_connection;
      wait_for_reply = wait_for_reply;

      --
      config_ =
      {
        host = config.host;
        port = config.port;
        timeout = config.timeout;
        user_name = config.user_name;
        secret = config.secret;
        secure = config.secure;
        context = config.context;
        channel = config.channel;
        priority = config.priority;
        logger = config.logger;
      }
    }
  end
end

return
{
  make_ami_manager = make_ami_manager;
}
