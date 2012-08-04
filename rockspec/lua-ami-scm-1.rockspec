package = "lua-ami"
version = "scm-1"
source =
{
  url = "http://github.com/pbxware/lua-ami",
  branch = "master"
}
description =
{
  summary = "Library to access Asterisk Management Interface",
  homepage = "http://github.com/pbxware/lua-ami",
  license = "MIT/X11"
}
dependencies =
{
  "lua >= 5.1",
  "luasocket >= 2.0.2",
  "luuid >= 20100303"
}
build =
{
  type = "none",
  install =
  {
    lua =
    {
      ["ami"] = "ami.lua";
      ["ami.connection"] = "ami/connection.lua";
      ["ami.login"] = "ami/login.lua";
      ["ami.utils"] = "ami/utils.lua";
    }
  }
}
