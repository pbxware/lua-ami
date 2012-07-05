--------------------------------------------------------------------------------
-- originate.lua: interactive test
-- This file is a part of Lua-AMI library
-- Copyright (c) Lua-AMI authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

local make_ami_manager = require "lua-ami".make_ami_manager

local config =
{
  host = "127.0.0.1",
  user_name = "lua-ami",
  password = "test-secret",
  channel = "SIP/702",
  context = "lua-ami-test",
  priority = 1,
  timeout = 30000
}

local ami_manager = make_ami_manager(config)

local ok, response = ami_manager:login()

local ok, response = ami_manager:originate("701")

ami_manager:logoff()

ami_manager:close()
