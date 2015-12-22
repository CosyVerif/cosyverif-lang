local loader        = require "cosy.loader.lua" {
  logto = false,
}
local Configuration = loader.load "cosy.configuration"
local File          = loader.load "cosy.file"
local I18n          = loader.load "cosy.i18n"
local Library       = loader.load "cosy.library"
local Arguments     = loader.require "argparse"
local Colors        = loader.require "ansicolors"

Configuration.load {
  "cosy.nginx", -- TODO: check
  "cosy.server",
}

local i18n   = I18n.load {
  "cosy.cli",
  "cosy.server",
}
i18n._locale = Configuration.server.locale

local name = os.getenv "COSY_PREFIX" .. "/bin/cosy-server"
name = name:gsub (os.getenv "HOME", "~")
local parser = Arguments () {
  name        = name,
  description = i18n ["server:command"] % {},
}
local start = parser:command "start" {
  description = i18n ["server:start"] % {},
}
start:flag "-f" "--force" {
  description = i18n ["flag:force"] % {},
}
start:flag "-c" "--clean" {
  description = i18n ["flag:clean"] % {},
}
local stop = parser:command "stop" {
  description = i18n ["server:stop"] % {},
}
stop:flag "-f" "--force" {
  description = i18n ["flag:force"] % {},
}
local arguments = parser:parse ()

local data = File.decode (Configuration.server.data)

if arguments.start then
  local url = "http://{{{host}}}:{{{port}}}/" % {
    host = "localhost",
    port = Configuration.http.port,
  }
  local client = Library.connect (url)
  if client then
    if arguments.force and data then
      local result = client.server.stop {
        administration = data.token,
      }
      if not result then
        os.execute ([[ kill -s KILL {{{pid}}} 2> /dev/null ]] % {
          pid = data.pid,
        })
      end
    else
      print (Colors ("%{black redbg}" .. i18n ["failure"] % {}),
             Colors ("%{red blackbg}" .. i18n ["server:already-running"] % {}))
      os.exit (1)
    end
  end

  if arguments.clean then
    Configuration.load "cosy.redis"
    local Redis     = loader.require "redis"
    local host      = Configuration.redis.interface
    local port      = Configuration.redis.port
    local database  = Configuration.redis.database
    local redis     = Redis.connect (host, port)
    redis:select (database)
    redis:flushdb ()
    package.loaded ["redis"] = nil
  end

  os.remove (Configuration.server.log )
  os.remove (Configuration.server.data)
  os.execute [[ luajit -e 'require "cosy.server".start ()' & ]]
  local tries = 0
  local serverdata, nginxdata
  repeat
    os.execute ([[sleep {{{time}}}]] % { time = 0.5 })
    serverdata = File.decode (Configuration.server.data)
    nginxdata  = File.decode (Configuration.http  .pid)
    tries      = tries + 1
  until (serverdata and nginxdata) or tries == 5
  if serverdata and nginxdata then
    print (Colors ("%{black greenbg}" .. i18n ["success"] % {}))
    os.exit (0)
  else
    print (Colors ("%{black redbg}" .. i18n ["failure"] % {}),
           Colors ("%{red blackbg}" .. i18n ["server:unreachable"] % {}))
    os.exit (1)
  end

elseif arguments.stop then

  local url = "http://{{{host}}}:{{{port}}}/" % {
    host = "localhost",
    port = Configuration.http.port,
  }
  local client = Library.connect (url)
  if client and data then
    local result = client.server.stop {
      administration = data.token,
    }
    if result then
      print (Colors ("%{black greenbg}" .. i18n ["success"] % {}))
      os.exit (0)
    end
  end
  if not client then
    if arguments.force and data then
      os.execute ([[ kill -s KILL {{{pid}}} 2> /dev/null ]] % {
        pid = data.pid,
      })
      print (Colors ("%{black greenbg}" .. i18n ["success"] % {}))
      os.exit (0)
    elseif arguments.force then
      print (Colors ("%{black greenbg}" .. i18n ["success"] % {}))
      os.exit (0)
    else
      print (Colors ("%{black redbg}" .. i18n ["failure"] % {}),
             Colors ("%{red blackbg}" .. i18n ["server:unreachable"] % {}))
      os.exit (1)
    end
  end

end
