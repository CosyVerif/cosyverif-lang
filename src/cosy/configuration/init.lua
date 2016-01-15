return function (loader)

  local I18n   = loader.load "cosy.i18n"
  local Logger = loader.load "cosy.logger"
  local layers = loader.load "cosy.configuration.layers"
  local Layer  = loader.require "layeredata"

  local i18n   = I18n.load "cosy.configuration"

  layers.default.locale    = "en"
  layers.default.__label__ = "configuration"

  local Configuration = {}

  function Configuration.load (t)
    if type (t) ~= "table" then
      t = { t }
    end
    for _, name in ipairs (t) do
      loader.load (name .. ".conf")
    end
  end

  local Metatable = {}

  function Metatable.__index (_, key)
    return layers.whole [key]
  end

  function Metatable.__newindex (_, key, value)
    layers.whole [key] = value
  end

  setmetatable (Configuration, Metatable)

  local files = {
    etc  = loader.prefix .. "/etc/cosy.conf",
    home = os.getenv "HOME" .. "/.cosy/cosy.conf",
    pwd  = os.getenv "PWD"  .. "/cosy.conf",
  }

  if not _G.js then
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
      local result = loadfile (name)
      if result then
        Logger.debug {
          _      = i18n ["use"],
          path   = name,
          locale = Configuration.locale or "en",
        }
        Layer.replacewith (layers [key], result ())
      else
        Logger.warning {
          _      = i18n ["skip"],
          path   = name,
          locale = Configuration.locale or "en",
        }
      end
    end
  end

  return Configuration

end
