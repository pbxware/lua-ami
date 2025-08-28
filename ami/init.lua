--------------------------------------------------------------------------------
--- Lua module to talk with Asterisk by AMI protocol.
-- @module ami
-- @license MIT/X11
-- @copyright Lua-AMI authors (see file `COPYRIGHT`)
--------------------------------------------------------------------------------

local random = math.random

local make_connection = require "ami.connection".make_connection
local simple_login = require "ami.login".simple_login
local challenge_login = require "ami.login".challenge_login
local check_reply = require "ami.utils".check_reply

local type, assert = type, assert

--------------------------------------------------------------------------------

-- @field DEFAULT_AMI_PORT  default TCP port number for AMI
local DEFAULT_AMI_PORT = 5038

local function uuid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

local noop = function()
end 

--------------------------------------------------------------------------------

local AMI = {} 

--- Wait for specified reply
--   all other events ignored
-- @param self AMI manager object
-- @param action_id ID of reply
-- @return response structure from AMI or nil, if error occured
-- @return error string, if error occured, otherwise nil
function AMI:wait_for_reply(action_id)
    assert(type(self) == "table", "self is not a table (AMI object)")
    --assert(type(action_id) == "string", "action_id is not string")

    local conn, err = self:connect()
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

--- Execute custom command
--   
function AMI:execute(command, params)
    assert(type(self) == "table", "self is not a table (AMI object)")
    assert(type(command) == "string", "command is not string")

    local conn, err = self:connect()
    if not conn then
      return nil, err
    end

    local action_id 
    action_id = uuid()
    params = params or {} 
    params.ActionID = action_id
    local response, err
    response, err = conn:command(
        command,
        params
    )

    local results = {} 
    if response then
      while response and not err do 
        response, err = self:wait_for_reply(action_id)
        
        if response and response.EventList == 'start' then  -- start of events 
          noop() 
        elseif response and response.EventList == 'Complete' then  -- end of events 
          return results, action_id 
        elseif response and response.Event and command == 'PJSIPShowEndpoints' then  -- events ongoing [PJSIPShowEndpoints]
          table.insert(results, response) 
        elseif response and response.Event then  -- events ongoing 
          results[response.Event] = response 
        elseif response and response.Response == 'Success' and not response.EventList then  -- no events will came, return output 
          return response.Output[1], action_id
        end 
        
      end
    end

    return nil, err
end

--- Disconnect from AMI interface
-- @param self AMO object
-- @return
function AMI:disconnect()
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

--- Event loop
-- @param self AMI object
-- @param mask Event mask
-- @return nil 
-- @return error message if error occured, nil otherwise
function AMI:events(mask)
  assert(type(self) == "table", "self is not a table (AMI object)")

  local conn, err = self:connect()
  if not conn then
    return nil, err
  end
  
  local action_id = uuid()
  local response, err
  response, err = conn:command(
      "Events",
      {
        EventMask = mask or 'on';
        ActionID = action_id;
      }
    )

  while response and not err do 
    response, err = self:wait_for_reply()
    if response and check_reply(response, 'Event') then 
      local thread = coroutine.create(self.event_handlers[response.Event] or self.event_handlers["*"]) 
      coroutine.resume(thread, response)
    end 
  end 

  return response, err, action_id
end

--- Private: connect and authorize on demand
-- @param self AMI manager object
-- @return AMI connection object
function AMI:connect()
    if self.conn_ then return self.conn_ end -- already connected
    local conn, err = make_connection(
        self.config.host,
        self.config.port,
        self.config.timeout,
        self.config.tls,
        self.config.logger
      )
    if not conn then
      return nil, err
    end

    local result
    if self.config.auth == 'md5' then
      result, err = challenge_login(conn, self.config.username, self.config.secret)
    else
      result, err = simple_login(conn, self.config.username, self.config.secret)
    end

    if result == nil then
      return nil, "AMI login failed: " .. err
    end

    self.conn_ = conn
    return conn
end

-- Subscribe for events
-- @param event Event name
-- @param callback Callback function
function AMI:subscribe(event, callback)
    assert(type(event) == 'string', 'event is not a string')
    assert(type(callback) == 'function', 'callback is not a function')
    self.event_handlers[event] = callback
end 

--- Make AMI manager object
--  @param config -- table with configuration values
--  @field host  host to connect
--  @field port  port to connect
--  @return AMI manager object
new = function(config)
    assert(type(config) == "table", "config is not a table")
    config.host = config.host or '127.0.0.1'
    config.port = config.port or DEFAULT_AMI_PORT
    config.timeout = config.timeout or 60*1000
    config.logger = config.logger or nil 
    config.auth = config.auth or 'plain' 
    config.tls = config.tls or false 

    assert(type(config.host) == "string", "config.host is not a string")
    assert(type(config.port) == "number", "config.port is not a number")
    assert(type(config.timeout) == "number", "config.port is not a number")
    assert(type(config.username) == "string", "config.username is not a string")
    assert(type(config.secret) == "string", "config.secret is not a string")
    assert(type(config.auth) == "string", "config.auth is not a string")
    assert(type(config.tls) == "boolean", "config.tls is not a boolean")
    assert(config.logger == nil or type(config.logger) == "function", "config.logger is not a function")
    
    local obj = { 
      config = config, 
      event_handlers = { 
        ['*'] = noop
      },
    }
    
    return setmetatable(obj, {__index=AMI})
end

return
{
  new = new 
}
