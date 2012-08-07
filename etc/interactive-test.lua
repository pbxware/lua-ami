--------------------------------------------------------------------------------
-- interactive-test.lua: interactive test
-- This file is a part of Lua-AMI library
-- Copyright (c) Lua-AMI authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------
-- Little tool, to accsess "live" asterisk: send originate command
-- @script interactive-test.lua
--------------------------------------------------------------------------------

local make_ami_manager = require "ami".make_ami_manager

local config =
{
  host = "127.0.0.1";
  user_name = "lua-ami";
  secret = "test-secret";
  channel = "SIP/702";
  context = "lua-ami-test";
  priority = 1;
  timeout = 30000;
  secure = true;
  logger = print;
}

config["host"] = assert(select(1, ...), "hostname required")

local ami_manager = make_ami_manager(config)
response, err = ami_manager:originate("701")
if response then
  print "OK"
else
  print("ERROR", err)
end
