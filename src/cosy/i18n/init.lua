return function (loader)

  local Layer     = loader.require "layeredata"
  local Lustache  = loader.require "lustache"
  local Plural    = loader.require "i18n.plural"

  local I18n      = {}
  local Metatable = {}
  local Message   = {}

  setmetatable (I18n, Metatable)

  -- FIXME: remove
  function I18n.new (locale)
    return setmetatable ({
      _store  = {},
      _locale = locale,
    }, I18n)
  end

  function I18n.load (t)
    if type (t) ~= "table" then
      t = { t }
    end
    local depends = {}
    for _, name in ipairs (t) do
      local layer = Layer.new {
        name = name,
        data = loader.load (name .. ".i18n")
      }
      depends [#depends+1] = layer
    end
    local all = Layer.new { name = "i18n", data = {
        __refines__ = depends,
      }
    }
    local store = setmetatable ({}, {
      __index = function (_, key)
        local path = all [key]
        if path then
          local result = {}
          for k, p in Layer.pairs (path) do
            result [k] = p
          end
          return result
        end
      end,
    })
    return setmetatable ({
      _store  = store,
      _locale = false,
    }, I18n)
  end

  function I18n.__index (i18n, key)
    local entry = i18n._store [key]
    if not entry then
      error ("i18n key " .. tostring (key) .. " not found")
    end
    return setmetatable ({
      _key    = key,
      _entry  = entry,
      _locale = i18n._locale,
    }, Message)
  end

  function I18n.__call (i18n, data)
    if type (data) ~= "table" then
      return data
    end
    local function translate (locale, t)
      locale = t.locale or locale
      if type (t) ~= "table" then
        return t
      end
      for _, v in pairs (t) do
        if type (v) == "table" and not getmetatable (v) then
          translate (locale, v)
        end
      end
      if t._ then
        t.locale  = t.locale or locale
        t.message = t._ % t
        t._       = t._._key
        t.locale  = nil
      end
      return t
    end
    local locale = data.locale
                or data._locale
                or i18n._locale
                or "en"
    return translate (locale, data)
  end

  Metatable.__call = I18n.__call

  function Message.__mod (message, context)
    local locale = context.locale or message._locale or "en"
    locale = locale:lower ()
    locale = locale:gsub ("_", "-")
    locale = locale:match "^(%w%w-%w%w)" or locale:match "^(%w%w)"
    if not message._entry [locale] then
      locale = locale:match "^(%w%w)"
    end
    if not message._entry [locale] then
      locale = message._locale
    end
    if not message._entry [locale] then
      locale = locale:match "^(%w%w)"
    end
    if not message._entry [locale] then
      locale = "en"
    end
    if not message._entry [locale] then
      local Value = loader.load "cosy.value"
      return Value.expression (message._key) .. ":" .. Value.expression (context)
    end
    local result = message._entry [locale]
    local t      = {}
    for k, v in pairs (context) do
      t [k] = v
      if type (v) == "number" then
        assert (context ["~" .. k] == nil)
        t ["~" .. k] = Plural.get (locale, v)
      end
    end
    return Lustache:render (result, context)
  end

  return I18n

end
