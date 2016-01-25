local Arguments = require "argparse"

local Cli = {}

Cli.__index = Cli

function Cli.new ()
  return setmetatable ({}, Cli)
end

local function printerr (...)
  local t = { ... }
  for i = 1, #t do
    t [i] = tostring (t [i])
  end
  io.stderr:write (table.concat (t, "\t") .. "\n")
end

-----------------------------
--  While not found Cli tries to determine what server it will connect to
--    by scanning in that order :
--  1. --server=xxx   cmd line option
--  2. ~/.cosy/cli.data config file (ie last server used)
--  3. configuration

Cli.default_locale = (os.getenv "LANG" or "en"):match "[^%.]+":gsub ("_", "-")
Cli.default_server = "http://public.cosyverif.lsv.fr"

function Cli.configure (cli, arguments)
  assert (getmetatable (cli) == Cli)

  local alias  = nil
  local locale = Cli.default_locale
  local server = Cli.default_server

  for iteration = 1, 2 do

    local loader = require "cosy.loader.lua" {
      logto = false,
      alias = alias,
    }
    local Configuration = loader.load "cosy.configuration"
    local File          = loader.load "cosy.file"

    Configuration.load {
      "cosy.client",
    }

    if iteration == 2 then
      local data = File.decode (Configuration.cli.data) or {}
      server = data.server or server
      locale = data.locale or locale
    end

    local parser = Arguments () {
      name        = "cosy",
      description = "cosy command-line interface",
      add_help    = {
        action = function () end
      },
    }
    parser:require_command (false)
    parser:option "-a" "--alias" {
      description = "server alias",
      default     = loader.alias,
    }
    parser:option "-s" "--server" {
      description = "server URL",
      default     = server,
    }
    parser:option "-l" "--locale" {
      description = "locale for messages",
      default     = locale,
    }
    parser:argument "command" {
      args = "*",
      description = "command to run and its options and arguments",
    }
    -- Warning: UGLY hack.
    -- `argparse` stops execution when `pparse` is used with a `--help` option.
    -- But we want to continue to get the full help message from `Cli.start`.
    -- Thus, we redefine temporarily `os.exit` to do nothing.
    local _exit = _G.os.exit
    _G.os.exit  = function () end
    local carguments = { (table.unpack or unpack) (arguments) }
    repeat
      local ok, args = parser:pparse (carguments)
      if ok then
        alias  = args.alias
        locale = args.locale
        server = args.server
      elseif args:match "^unknown option" then
        local option = args:match "^unknown option '(.*)'$"
        for i = 1, # carguments do
          if carguments [i]:find (option) == 1 then
            table.remove (carguments, i)
            break
          end
        end
      else
        break
      end
    until ok
    -- End of UGLY hack.
    _G.os.exit = _exit
    cli.parser = parser
  end
  assert (server)

  local loader = require "cosy.loader.lua" {
    logto = false,
    alias = alias,
  }
  local Colors        = loader.require "ansicolors"
  local Lfs           = loader.require "lfs"    -- C module : won't be reloaded from server
  local Json          = loader.require "cjson"  -- lua tables are transcoded into json for server  (pkg comes with lua socket)
  local Ltn12         = loader.require "ltn12"  -- to store the content of the requests ( pkgcomes with lua socket)
  local Mime          = loader.require "mime"
  local Request       = loader.require "socket.http".request
  local Hotswap       = loader.require "hotswap.http"
  local Configuration = loader.load "cosy.configuration"
  local File          = loader.load "cosy.file"
  local I18n          = loader.load "cosy.i18n"

  Configuration.load {
    "cosy.client",
  }
  local i18n = I18n.load {
    "cosy.client",
  }

  local _error = error
  local function error (err)
    if type (err) == "table" and err._ then
      printerr (Colors ("%{red blackbg}" .. i18n ["failure"] % {}))
      printerr (Colors ("%{white redbg}" .. err._ % err))
    else
      printerr ("An error happened. Maybe the client was unable to download sources from " .. (server or "no server") .. ".")
      local errorfile = os.tmpname ()
      local file      = io.open (errorfile, "w")
      file:write (tostring (err) .. "\n")
      file:write (debug.traceback () .. "\n")
      file:close ()
      printerr ("See error file " .. Colors ("%{white redbg}" .. errorfile) .. " for more information.")
    end
    _error (err)
  end

  -- trim eventual trailing /:
  server = server:gsub ("/+$","")
  if not server:match "^https?://" then
    error {
      _      = i18n ["server:not-url"],
      server = server,
    }
  end

  -- test if server is valid:
  local _, code = Request (server .. "/lua/cosy.loader.lua")
  if code ~= 200 then
    error {
      _      = i18n ["server:not-cosy"],
      server = server,
    }
  end

  local data = File.decode (Configuration.cli.data) or {}
  data.alias  = alias
  data.server = server
  data.locale = locale
  File.encode (Configuration.cli.data, data)

  --  every dowloaded lua package will be saved in ~/.cosy/lua/base64(server_name)
  local server_dir = Configuration.cli.lua .. "/" .. Mime.b64 (server)
  Lfs.mkdir (Configuration.cli.lua)
  Lfs.mkdir (server_dir)

  local hotswap = Hotswap {
    storage = server_dir, -- where to save the lua files
    encode = function (t)
      local s = Json.encode (t)
      return {
        url     = server .. "/luaset",
        method  = "POST",
        headers = {
          ["Content-Length"] = #s,
        },
        source  = Ltn12.source.string (s),
      }
    end,
    decode = function (t)
      if t.code == 200 then
        return Json.decode (t.body)
      end
    end,
  }

-- In order to download lua modules (required by the client) from the server
-- we replace the Lua require function
--      by the hotswap.require which will also save lua packages into "server_dir"
  cli.loader = hotswap.require "cosy.loader.lua" {
    alias   = alias,
    hotswap = hotswap,
    logto   = Configuration.cli.log,
  }

  -- For tests:
  cli.alias  = alias
  cli.server = server
  cli.locale = locale
end

function Cli.start (cli)
  assert (getmetatable (cli) == Cli)

  if not pcall (cli.configure, cli, _G.arg) then
    print (cli.parser:get_help ())
    return false
  else
    cli.parser = nil
  end
  local loader        = cli.loader
  local Configuration = loader.load "cosy.configuration"
  local File          = loader.load "cosy.file"
  local I18n          = loader.load "cosy.i18n"
  local Library       = loader.load "cosy.library"
  local Colors        = loader.require "ansicolors"

  Configuration.load {
    "cosy.client",
  }

  local data = File.decode (Configuration.cli.data) or {}

  local i18n = I18n.load {
    "cosy.client",
  }
  i18n._locale = data.locale or Configuration.cli.locale

  local parser = Arguments () {
    name        = "cosy",
    description = i18n ["client:command"] % {},
  }
  parser:option "-a" "--alias" {
    description = "configuration name",
    default     = data.alias,
  }
  parser:option "-s" "--server" {
    description = i18n ["option:server"] % {},
    default     = data.server,
  }
  parser:option "-l" "--locale" {
    description = i18n ["option:locale"] % {},
    default     = data.locale,
  }

  print (Colors ("%{green blackbg}" .. i18n ["client:server"] % {
    server = data.server,
  }))

  local client = Library.connect (data.server, data)
  if not client then
    printerr (Colors ("%{white redbg}" .. i18n ["failure"] % {}),
              Colors ("%{white redbg}" .. i18n ["server:unreachable"] % {}))
    return false
  end

  local who  = client.user.authentified_as {}
  if who.identifier then
    print (Colors ("%{green blackbg}" .. i18n ["client:identified"] % {
      user = who.identifier,
    }))
  end

  local Commands = loader.load "cosy.client.commands"
  local commands = Commands.new {
    parser = parser,
    client = client,
    data   = data,
  }
  local ok, result = xpcall (function ()
      Commands.parse (commands)
      File.encode (Configuration.cli.data % { config = cli.config }, data)
    end, function (err)
      printerr (Colors ("%{white redbg}" .. i18n ["error:unexpected"] % {}))
      printerr (err)
      printerr (debug.traceback ())
    end)
  if not ok and result then
    printerr (Colors ("%{red blackbg}" .. i18n ["failure"] % {}))
    printerr (Colors ("%{white redbg}" .. i18n (result.error).message))
  end
  return ok
end

function Cli.stop (cli)
  assert (getmetatable (cli) == Cli)
end

if not _G._TEST then
  local cli = Cli.new ()
  if cli:start () then
    os.exit (0)
  else
    os.exit (1)
  end
end

return Cli
