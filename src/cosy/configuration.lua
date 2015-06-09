local Loader        = require "cosy.loader"
local I18n          = require "cosy.i18n"
local Logger        = require "cosy.logger"
local Repository    = require "cosy.repository"
local Scheduler     = require "cosy.scheduler"

local i18n       = I18n.load "cosy.configuration"
local repository = Repository.new ()

Repository.options (repository).create = function () return {} end
Repository.options (repository).import = function () return {} end

repository.whole = {
  [Repository.depends] = {
    repository.default,
    repository.etc,
    repository.home,
    repository.pwd,
  },
}

local Configuration = {
  ["cosy:configuration:layers"] = {
    default = repository.default,
    etc     = repository.etc,
    home    = repository.home,
    pwd     = repository.pwd,
    whole   = repository.whole,
  },
}

function Configuration.load (t)
  if type (t) ~= "table" then
    t = { t }
  end
  for _, name in ipairs (t) do
    require (name .. "-conf")
  end
end

local Metatable = {}

function Metatable.__index (configuration, key)
  return configuration ["cosy:configuration:layers"].whole [key]
end

function Metatable.__newindex (configuration, key, value)
  configuration ["cosy:configuration:layers"].whole [key] = value
end

function Metatable.__div (configuration, name)
  return configuration ["cosy:configuration:layers"] [name]
end

setmetatable (Configuration, Metatable)

local Internal  = Configuration / "default"
Internal.locale = "en"

local files = {
  etc  = "/etc/cosy.conf",
  home = os.getenv "HOME" .. "/.cosy/cosy.conf",
  pwd  = os.getenv "PWD" .. "/cosy.conf",
}

if not _G.js then
  local updater = Scheduler.addthread (function ()
    local Nginx         = require "cosy.nginx"
    local Redis         = require "cosy.redis"
    if not Nginx.directory then
      return
    end
    while true do
      local redis = Redis ()
      -- http://stackoverflow.com/questions/4006324
      local script = { [[
        local n    = 1000
        local keys = redis.call ("keys", ARGV[1])
        for i=1, #keys, n do
          redis.call ("del", unpack (keys, i, math.min (i+n-1, #keys)))
        end
      ]] }
      for name in pairs (Configuration.dependencies) do
        local source = Configuration.dependencies [name]
        local url    = tostring (source._)
        if url:match "^http" then
          script [#script+1] = ([[
            redis.call ("set", "foreign:{{{name}}}", "{{{source}}}")
          ]]) % {
            name   = name,
            source = url,
          }
        end
      end
      script [#script+1] = [[
        return true
      ]]
      script = table.concat (script)
      redis:eval (script, 1, "foreign:*")
      os.execute ([[
        find {{{root}}}/cache -type f -delete
      ]] % {
        root = Nginx.directory,
      })
      Logger.debug {
        _ = i18n ["updated"],
      }
      Nginx.update ()
      Scheduler.sleep (-math.huge)
    end
  end)

  package.searchers [#package.searchers+1] = function (name)
    local result, err = io.open (name, "r")
    if not result then
      return nil, err
    end
    result, err = loadfile (name)
    if not result then
      return nil, err
    end
    return result, name
  end

  for key, name in pairs (files) do
    local result = Loader.hotswap.try_require (name)
    if result then
      Loader.hotswap.on_change ["cosy:configuration"] = function ()
        Scheduler.wakeup (updater)
      end
      Logger.debug {
        _      = i18n ["use"],
        path   = name,
        locale = Configuration.locale._ or "en",
      }
      repository [key] = result
    else
      Logger.warning {
        _      = i18n ["skip"],
        path   = name,
        locale = Configuration.locale._ or "en",
      }
    end
  end
end

return Configuration
