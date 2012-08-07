--------------------------------------------------------------------------------
--- implementation of AMI protocol authorization sequence
-- @module ami.login
-- @license MIT/X11
-- @copyright Lua-AMI authors (see file `COPYRIGHT`)
--------------------------------------------------------------------------------

local md5 = require "md5"
local check_reply = require "ami.utils".check_reply

local assert, type = assert, type

--------------------------------------------------------------------------------

--- Internal: proceed with challenge/response login sequence
-- @param conn connection object
-- @param user user name
-- @param secret password
-- @return text message (a string) from AMI response about sucessful login,
--         otherwise -- nil
-- @return error message if error occured
local challenge_login = function(conn, user, secret)
  assert(type(conn)=="table", "conn is not a table (connection object)")
  assert(type(user)=="string", "user is not a string")
  assert(type(secret)=="string", "secret is not a string")

  local result, err = conn:command("Challenge", { AuthType = "md5" })
  if not result then
    return nil, "AMI: Can't get challenge:" .. err
  end
  result, err  = conn:get_reply()
  if not result then
    return nil, err
  end
  local challenge, err = check_reply(result, "Challenge")
  if result and result.Challenge then
    result, err = conn:command(
        "Login",
        {
          AuthType = "md5";
          Username = user;
          Key = md5.sumhexa(result.Challenge .. secret)
        }
      )
    if result then
      result, err  = conn:get_reply()
      if result then
        return check_reply(result)
      end
    end
  end
  return nil, err
end

--- Internal: proceed with simple login sequence
-- @param conn connection object
-- @param user user name
-- @param secret password
-- @return text message (a string) from AMI response about sucessful login,
--         otherwise -- nil
-- @return error message if error occured
local simple_login = function(conn, user, secret)
  assert(type(conn)=="table", "conn is not a table (connection object)")
  assert(type(user)=="string", "user is not a string")
  assert(type(secret)=="string", "secret is not a string")

  local result, err = conn:command(
      "Login",
      {
        Username = user;
        Secret = secret;
      }
    )
  if not result then
    return nil, err
  end
  result, err = conn:get_reply()
  if not result then
    return nil, err
  end
  return check_reply(result)
end

return
{
  simple_login = simple_login;
  challenge_login = challenge_login;
}
