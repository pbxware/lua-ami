--------------------------------------------------------------------------------
--- Low-level connection object
-- @module ami.connection
-- @license MIT/X11
-- @copyright Lua-AMI authors (see file `COPYRIGHT`)
--------------------------------------------------------------------------------

local socket = require "socket"
local ltn12 = require "ltn12"

local assert, type, pairs = assert, type, pairs
local table_concat = table.concat

--------------------------------------------------------------------------------

-- @local
local ASTERISK_BANNER = "^Asterisk Call Manager/(%d.%d)"

--------------------------------------------------------------------------------

---Private:  Parse key/value pair from protocol
-- @param line line to parse
-- @return key/value pair, or  nil/error pair if line malformed
local parse_line = function(line)
  local k, v = line:match("^(.-):%s*(.+)$")
  if not k then
    return nil, "parse error, malformed line"
  end
  return k, v
end

--- Private: establish tcp connection
local establish_connection = function(self)
  assert(type(self) == "table", "self not a table")

  local sock, err = socket.tcp()
  if not sock then
    return nil, err
  end

  sock:settimeout(self.timeout_)
  local result, err = sock:connect(self.host_, self.port_)
  if not result then
    return nil, err
  end

  -- Handshake with AMI
  local banner, err = sock:receive()
  if err then
    return nil, err
  end

  local protocol_version = banner:match(ASTERISK_BANNER)
  if not protocol_version then
    sock:close()
    return nil, "bad signature: " .. banner
  end

  self.socket_ = sock
  self.protocol_version_ = protocol_version
end

--- Connect to AMI socket (if not connected)
local get_connection = function(self)
  assert(type(self) == "table", "self not a table")

  if not self.socket_ then
    establish_connection(self)
  end
  return self.socket_
end

--- Private: read a packet from socket
local get_reply = function(self)
  assert(type(self) == "table")

  local sock = self.socket_
  if not sock then
    -- we can escalate error, w/o attempting to connect, because we reading
    -- reply from server. Connecting w/o sending request is meaningless
    return nil, "not connected"
  end

  local t = { }
  while true do
    -- read one line
    local line, err_msg = sock:receive()
    if self.logger_ then
      self.logger_("AMI IN:", line)
    end
    if not line then
      return nil, err_msg
    end
    if #line == 0 then
      return t
    end
    local k, v = parse_line(line)
    if k then
      if t[k] then
        if type(t[k]) ~= "table" then
          t[k] = { t[k] }
        end
        t[k][#t + 1] = v
      else
        t[k] = v
      end
    else
      local err = v
      return nil, err
    end
  end
end

--- Private: connection:send_packet() send packet to AMI
-- @param self connection object
-- @param keyword command to send to protocol (Action, Response, or Event)
-- @param action asterisk command
-- @param data a table of parameters
local send_packet = function(self, keyword, action, data)
  assert(type(self) == "table")
  assert(type(keyword) == "string")
  assert(type(action) == "string")
  assert(type(data) == "table")

  local sock, err = get_connection(self)
  if not sock then
    return nil, err
  end

  local packet = keyword .. ": " .. action
  packet = { packet }
  for k, v in pairs(data) do
    packet[#packet + 1] =  k .. ": " .. v
  end
  packet = table_concat(packet, "\n")
  packet = packet .. "\n\n"

  if self.logger_ then
    self.logger_("AMI OUT:", "<<<" .. packet .. ">>>")
  end

  return ltn12.pump.all(
      ltn12.source.string(packet),
      socket.sink("keep-open", sock)
    )
end

--- connection:command() send "action" packet to AMI
-- @param self connection object
-- @param action asterisk command
-- @param data a table of parameters
local command = function(self, action, data)
  assert(type(self) == "table", "self is not a connection object")
  assert(type(action) == "string", "action is not a string")
  assert(type(data) == "table", "data is not a table")

  return send_packet(self, "Action", action, data)
end

--- close connection
local close = function(self)
  assert(type(self) == "table", "self is not a connection object")

  self.socket_:close()
end

--- Return version of protocol
-- @param self connection object
-- @return protocol version or nil, if error occured
-- @return nil or error string, if error occured
local get_protocol_version = function(self)
  assert(type(self) == "table", "self is not a connection object")

  local sock, err = get_connection(self)
  if not sock then
    return nil, err
  end

  return self.protocol_version_
end

--- Create a low-level connection object
-- @param host host
-- @param port port
-- @param timeout optional connection timeout
-- @param logger  optional logger (function with print semantic)
-- @return a connection object
local make_connection = function(host, port, timeout, logger)
  assert(type(host) == "string", "host is not a string")
  assert(type(port) == "number", "port is not a number")

  if timeout ~= nil then
    assert(type(timeout) == "number", "timeout is not a number or nil")
  end
  if logger ~= nil then
    assert(type(logger) == "function", "logger is not a function or nil")
  end

  return
  {
    -- methods
    get_protocol_version = get_protocol_version;
    command = command;
    get_reply = get_reply;
    close = close;

    -- Private fields
    socket_ = nil;
    protocol_version_ = nil;
    host_ = host;
    port_ = port;
    timeout_ = timeout;
    logger_ = logger;
  }
end

return
{
  make_connection = make_connection;
}
