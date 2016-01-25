local function printerr (...)
  local t = { ... }
  for i = 1, #t do
    t [i] = tostring (t [i])
  end
  io.stderr:write (table.concat (t, "\t") .. "\n")
end

local arguments
do
  local loader        = require "cosy.loader.lua" {
    logto = false,
  }
  local Configuration = loader.load "cosy.configuration"
  local I18n          = loader.load "cosy.i18n"
  local Arguments     = loader.require "argparse"

  Configuration.load {
    "cosy.nginx", -- TODO: check
    "cosy.server",
  }

  local i18n   = I18n.load {
    "cosy.client",
    "cosy.server",
  }
  i18n._locale = Configuration.server.locale

  local parser = Arguments () {
    name        = "cosy-server",
    description = i18n ["server:command"] % {},
  }
  local start = parser:command "start" {
    description = i18n ["server:start"] % {},
  }
  start:option "-a" "--alias" {
    description = "configuration name",
    default     = "default",
  }
  start:option "-p" "--port" {
    description = "network port",
    default     = tostring (Configuration.http.port),
    defmode     = "arg",
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
  stop:option "-a" "--alias" {
    description = "configuration name",
    default     = "default",
  }
  stop:flag "-f" "--force" {
    description = i18n ["flag:force"] % {},
  }
  local _ = parser:command "version" {
    description = i18n ["server:version"] % {},
  }
  arguments = parser:parse ()
end

local loader        = require "cosy.loader.lua" {
  logto = false,
  alias = arguments.alias,
}
local Configuration = loader.load "cosy.configuration"
local File          = loader.load "cosy.file"
local I18n          = loader.load "cosy.i18n"
local Library       = loader.load "cosy.library"
local Colors        = loader.require "ansicolors"
local Posix         = loader.require "posix"

Configuration.load {
  "cosy.nginx", -- TODO: check
  "cosy.server",
}

local i18n   = I18n.load {
  "cosy.client",
  "cosy.server",
}
i18n._locale = Configuration.server.locale

if arguments.start then

  local data = File.decode (Configuration.server.data) or {}
  local url = "http://{{{host}}}:{{{port}}}/" % {
    host = "localhost",
    port = data.port or Configuration.http.port,
  }
  local client = Library.connect (url)
  if client then
    if arguments.force and data then
      local result = client.server.stop {
        administration = data.token,
      }
      if not result then
        Posix.kill (data.pid, 9) -- kill
      end
    else
      printerr (Colors ("%{black redbg}" .. i18n ["failure"] % {}),
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

  if Posix.fork () == 0 then
    package.loaded ["copas"     ] = nil
    package.loaded ["copas.ev"  ] = nil
    package.loaded ["ev"        ] = nil
    package.loaded ["hotswap.ev"] = nil
    package.loaded ["hotswap"   ] = nil
    File.encode (Configuration.server.data, {
      alias     = arguments.alias,
      http_port = tonumber (arguments.port) or data.port or Configuration.http.port,
    })
    _G.cosy_server_alias = arguments.alias
    local Server = loader.require "cosy.server"
    Server.start ()
    os.exit (0)
  end
  local tries = 0
  local serverdata, nginxdata
  repeat
    Posix.sleep (1)
    serverdata = File.decode (Configuration.server.data)
    nginxdata  = File.decode (Configuration.http  .pid)
    tries      = tries + 1
  until (serverdata and nginxdata) or tries == 5
  if serverdata and nginxdata then
    print (Colors ("%{black greenbg}" .. i18n ["success"] % {}))
    os.exit (0)
  else
    printerr (Colors ("%{black redbg}" .. i18n ["failure"] % {}),
              Colors ("%{red blackbg}" .. i18n ["server:unreachable"] % {}))
    os.exit (1)
  end

elseif arguments.stop then

  local data = File.decode (Configuration.server.data) or {}
  local url = "http://{{{host}}}:{{{port}}}/" % {
    host = "localhost",
    port = data.port or Configuration.http.port,
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
    if arguments.force and data.pid then
      Posix.kill (data.pid, 9) -- kill
      local nginx_file = io.open (Configuration.http.pid, "r")
      if nginx_file then
        local nginx_pid  = nginx_file:read "*a"
        nginx_file:close ()
        Posix.kill (nginx_pid:match "%S+", 15) -- term
        print (Colors ("%{black greenbg}" .. i18n ["success"] % {}))
        os.exit (0)
      else
        printerr (Colors ("%{black redbg}" .. i18n ["failure"] % {}))
        os.exit (1)
      end
    elseif arguments.force then
      printerr (Colors ("%{black redbg}" .. i18n ["failure"] % {}))
      os.exit (1)
    else
      printerr (Colors ("%{black redbg}" .. i18n ["failure"] % {}),
                Colors ("%{red blackbg}" .. i18n ["server:unreachable"] % {}))
      os.exit (1)
    end

  end

elseif arguments.version then

  local path  = package.searchpath ("cosy.server.cli", package.path)
  local parts = {}
  for part in path:gmatch "[^/]+" do
    parts [#parts+1] = part
  end
  parts [#parts] = nil
  parts [#parts] = nil
  path = (path:find "^/" and "/" or "") .. table.concat (parts, "/")
  local handler = assert (io.popen ([[
    . "{{{prefix}}}/bin/realpath.sh"
    cd $(realpath "{{{path}}}")
    git describe
  ]] % {
    prefix = loader.prefix,
    path   = path,
  }, "r"))
  local result, err = assert (handler:read "*a")
  handler:close ()
  if result then
    print (result:match "%S+")
    print (Colors ("%{black greenbg}" .. i18n ["success"] % {}))
    os.exit (0)
  else
    printerr (Colors ("%{black redbg}" .. i18n ["failure"] % {}),
              Colors ("%{red blackbg}" .. err))
    os.exit (1)
  end

else

  assert (false)

end
