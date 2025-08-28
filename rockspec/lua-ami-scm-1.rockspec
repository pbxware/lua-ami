package = "lua-ami"
version = "scm-1"
source =
{
  url = "https://dev.narayana.im/narayana/lua-ami",
  branch = "master"
}
description =
{
  summary = "Library to access Asterisk Management Interface",
  homepage = "https://dev.narayana.im/narayana/lua-ami",
  license = "MIT/X11"
}
dependencies =
{
  "lua >= 5.1",
  "luasocket >= 2.0.2",
  "luasec >= 1.3.0",
}
build =
{
  type = "none",
  install =
  {
    lua =
    {
      ["ami.init"] = "ami/init.lua";
      ["ami.connection"] = "ami/connection.lua";
      ["ami.login"] = "ami/login.lua";
      ["ami.utils"] = "ami/utils.lua";
    }
  }
}
