return function (loader)

  local Configuration = loader.load "cosy.configuration"
  local I18n          = loader.load "cosy.i18n"
  local Scheduler     = loader.load "cosy.scheduler"
  local Token         = loader.load "cosy.token"
  local Default       = loader.load "cosy.configuration.layers".default
  local Layer         = loader.require "layeredata"
  local Lfs           = loader.require "lfs"
  local Mime          = loader.require "mime"
  local this          = Layer.reference (false)

  Configuration.load "cosy.methods"

  local i18n   = I18n.load "cosy.parameters"
  i18n._locale = Configuration.locale

  do
    Default.data = {
      checks = {}
    }
  end

  do
    Default.data.boolean = {
      __refines__ = {
        this.data,
      }
    }
    local checks = Default.data.boolean.checks
    checks [1] = function (t)
      local value = t.request [t.key]
      return  type (value) == "boolean"
          or  nil, {
                _ = i18n ["check:is-boolean"],
              }
    end
  end

  do
    Default.data.is_private = {
      __refines__ = {
        this.data.boolean,
      }
    }
  end

  do
    Default.data.position = {
      __refines__ = {
        this.data,
      },
    }
    local checks = Default.data.position.checks
    checks [1] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      return  type (value) == "table"
          or  nil, {
                _   = i18n ["check:is-table"],
              }
    end
    checks [2] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      return  value.country
         and  value.city
         and  value.latitude
         and  value.longitude
          or  nil, {
                _   = i18n ["check:is-position"],
              }
    end
  end

  -- String
  -- ------

  do
    Default.data.string = {
      __refines__ = {
        this.data,
      },
      min_size = 0,
      max_size = math.huge,
    }
    local checks = Default.data.string.checks
    checks [1] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      return  type (value) == "string"
          or  nil, {
                _   = i18n ["check:is-string"],
              }
    end
    checks [2] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      local size    = t.parameter.min_size
      return  #value >= size
          or  nil, {
                _     = i18n ["check:min-size"],
                count = size,
              }
    end
    checks [3] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      local size    = t.parameter.max_size
      return  #value <= size
          or  nil, {
                _     = i18n ["check:max-size"],
                count = size,
              }
    end
  end

  -- Avatar
  -- ------

  do
    Default.data.avatar = {
      width  = 400,
      height = 400,
      __refines__ = {
        this.data.string,
      },
    }
    local checks = Default.data.avatar.checks
    checks [#checks+1] = function (t)
      local request    = t.request
      local key        = t.key
      local value      = request [key]
      local filename   = Configuration.http.uploads .. "/" .. value
      local attributes = Lfs.attributes (filename)
      if attributes.mode ~= "file"
      or os.difftime (os.time (), attributes.modification) > Configuration.upload.timeout then
        return nil, {
              _ = i18n ["check:avatar:expired"],
            }
      end
      Scheduler.execute ([[
        convert {{{filename}}} -resize {{{width}}}x{{{height}}} png:{{{filename}}}
      ]] % {
        filename = filename,
        height   = Configuration.data.avatar.height,
        width    = Configuration.data.avatar.width ,
      })
      local file    = io.open (filename, "r")
      request [key] = Mime.b64 (file:read "*all")
      file:close ()
      os.remove (filename)
      return true
    end
  end

  do
    Default.data.string.trimmed = {
      __refines__ = {
        this.data.string,
      }
    }
    local checks = Default.data.string.trimmed.checks
    checks [2] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      request [key] = value:trim ()
      return true
    end
    checks [3] = Default.data.string.checks [2]
    checks [4] = Default.data.string.checks [3]
  end

  do
    Default.data.ip = {
      __refines__ = {
        this.data.string.trimmed,
      }
    }
    local checks = Default.data.ip.checks
    -- http://stackoverflow.com/questions/10975935
    local function check_ip (ip)
      do
        local chunks = { ip:match "(%d+)%.(%d+)%.(%d+)%.(%d+)" }
        if #chunks == 4 then
          for _, v in pairs (chunks) do
            if tonumber(v) > 255 then
              return false
            end
          end
          return true
        end
      end
      do
        local chunks = { ip:match (("([a-fA-F0-9]*):"):rep (8):gsub (":$","$")) }
        if #chunks == 8 then
          for _, v in pairs (chunks) do
            if #v > 0 and tonumber (v, 16) > 65535 then
              return false
            end
          end
          return true
        end
      end
    end
    checks [Layer.size (checks)+1] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      return  check_ip (value)
          or  nil, {
                _  = i18n ["check:ip:pattern"],
                ip = value,
              }
    end
  end

  do
    Default.data.captcha = {
      __refines__ = {
        this.data.string.trimmed,
      }
    }
  end

  do
    Default.data.locale = {
      __refines__ = {
        this.data.string.trimmed,
      }
    }
    local checks = Default.data.locale.checks
    checks [Layer.size (checks)+1] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      return  value:find "^%a%a$"
          or  value:find "^%a%a%-%a%a$"
          or  value:find "^%a%a%_%a%a$"
          or  nil, {
                _      = i18n ["check:locale:pattern"],
                locale = value,
              }
    end
  end

  -- Function
  -- --------

  do
    Default.data.iterator = {
      __refines__ = {
        this.data.string,
      },
    }
    local checks = Default.data.iterator.checks
    checks [Layer.size (checks)+1] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      -- http://lua-users.org/wiki/SandBoxes
      local environment = {
        assert    = assert,
        coroutine = coroutine,
        error     = error,
        ipairs    = ipairs,
        math      = math,
        next      = next,
        pairs     = pairs,
        pcall     = pcall,
        select    = select,
        string    = string,
        table     = table,
        tonumber  = tonumber,
        tostring  = tostring,
        type      = type,
        unpack    = unpack,
        xpcall    = xpcall,
      }
      -- FIXME: insecure, we should not load bytecode functions!
      if load then
        local f, err = load (value, nil, 'bt', environment)
        if not f then
          return nil, {
            _      = i18n ["check:iterator:function"],
            reason = err,
          }
        end
        request [key] = f
      else
        local f, err = loadstring (value)
        if not f then
          return nil, {
            _      = i18n ["check:iterator:function"],
            reason = err,
          }
        end
        _G.setfenv (f, environment) -- Lua 5.1 specific
        request [key] = f
      end
      if value:byte (1) ~= 27 then
        local _, result = pcall (request [key])
        request [key] = result
      end
      return  type (request [key]) == "function"
          or  nil, {
                _      = i18n ["check:iterator:function"],
                reason = request [key],
              }
    end
  end

  -- Resource
  -- ----
  do
    Default.data.resource = {
      min_size = 1,
      max_size = math.huge,
      __refines__ = {
        this.data.string.trimmed,
      },
      identifier = {
        min_size = 1,
        max_size = 32,
        __refines__ = {
          this.data.string.trimmed,
        }
      }
    }
    local checks = Default.data.resource.identifier.checks
    checks [Layer.size (checks)+1] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      return  value:find "^%w[%w%-_]*$"
          or  nil, {
                _   = i18n ["check:alphanumeric"],
                key = key,
              }
    end
  end

  do
    local checks = Default.data.resource.checks
    checks [Layer.size (checks)+1] = function (t)
      local store   = t.store
      local request = t.request
      local key     = t.key
      local value   = request [key]
      local data    = store / "data"
      for v in value:gmatch "[^/]+" do
        if not v:match "^%w[%w%-_]*$" then
          return  nil, {
            _    = i18n ["check:resource:format"],
            name = v,
          }
        end
        data = data / v
        if not data then
          return  nil, {
            _    = i18n ["check:resource:miss"],
            name = value,
          }
        end
      end
      request [key] = data
      return true
    end
  end

  do
    Default.data.user = {
      __refines__ = {
        this.data.resource,
      },
    }
    local checks = Default.data.user.checks
    checks [Layer.size (checks)+1] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      return request [key].type == "user"
          or  nil, {
                _    = i18n ["check:resource:not-user"],
                name = value,
              }
    end
  end

  do
    Default.data.user.active = {
      __refines__ = {
        this.data.user,
      },
    }
    local checks = Default.data.user.active.checks
    checks [Layer.size (checks)+1] = function (t)
      local request = t.request
      local key     = t.key
      local user    = request [key]
      return  user.status == "active"
          or  nil, {
                _    = i18n ["check:user:not-active"],
                name = user.identifier,
              }
    end
  end

  do
    Default.data.user.suspended = {
      __refines__ = {
        this.data.user,
      },
    }
    local checks = Default.data.user.suspended.checks
    checks [Layer.size (checks)+1] = function (t)
      local request = t.request
      local key     = t.key
      local user    = request [key]
      return  user.status == "suspended"
          or  nil, {
                _    = i18n ["check:user:not-suspended"],
                name = user.identifier,
              }
    end
  end

  do
    Default.data.project = {
      __refines__ = {
        this.data.resource,
      },
    }
    local checks = Default.data.project.checks
    checks [Layer.size (checks)+1] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      return  request [key].type == "project"
          or  nil, {
                _    = i18n ["check:resource:not-type"],
                name = value,
                type = "project",
              }
    end
  end

  for i = 1, Layer.size (Configuration.resource.project ["/"]) do
    local data = Configuration.resource.project ["/"] [i]
    local id   = data.__keys [#data.__keys]

    Default.data [id] = {
      __refines__ = {
        this.data.resource,
      },
    }
    local checks = Default.data [id].checks
    checks [Layer.size (checks)+1] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      return  request [key].type == id
          or  nil, {
                _    = i18n ["check:resource:not-type"],
                name = value,
                type = id,
              }
    end
  end

  -- Password
  -- --------
  do
    Default.data.password = {
      min_size = 1,
      max_size = 128,
      __refines__ = {
        this.data.string.trimmed,
      }
    }
  end

  do
    Default.data.password.checked = {
      __refines__ = {
        this.data.password,
      }
    }
  end

  -- Email
  -- -----
  do
    Default.data.email = {
      max_size = 128,
      __refines__ = {
        this.data.string.trimmed,
      }
    }
    local checks = Default.data.email.checks
    checks [Layer.size (checks)+1] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      local pattern = "^.*@[%w%.%%%+%-]+%.%w%w%w?%w?$"
      return  value:find (pattern)
          or  nil, {
                _     = i18n ["check:email:pattern"],
                email = value,
              }
    end
  end

  -- Name
  -- ----
  do
    Default.data.name = {
      min_size = 1,
      max_size = 128,
      __refines__ = {
        this.data.string.trimmed,
      }
    }
  end

  -- Organization
  -- ------------
  do
    Default.data.organization = {
      min_size = 1,
      max_size = 128,
      __refines__ = {
        this.data.string.trimmed,
      }
    }
  end

  -- Homepage
  -- ------------
  do
    Default.data.homepage = {
      min_size = 1,
      max_size = 128,
      __refines__ = {
        this.data.string.trimmed,
      }
    }
  end

  -- Description
  -- -----------
  do
    Default.data.description = {
      min_size = 1,
      max_size = 4096,
      __refines__ = {
        this.data.string.trimmed,
      }
    }
  end

  -- Terms of Services Digest
  -- ------------------------
  do
    Default.data.tos = {
      __refines__ = {
        this.data.string.trimmed,
      },
    }
    Default.data.tos.digest = {
      __refines__ = {
        this.data.string.trimmed,
      },
      min_size = 64,
      max_size = 64,
    }
    local checks = Default.data.tos.digest.checks
    checks [Layer.size (checks)+1] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      request [key] = value:lower ()
      return  true
    end
    checks [Layer.size (checks)+1] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      local pattern = "^%x+$"
      return  value:find (pattern)
          or  nil, {
                _          = i18n ["check:tos_digest:pattern"],
                tos_digest = value,
              }
    end
    checks [Layer.size (checks)+1] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      local Methods = loader.load "cosy.methods"
      local tos     = Methods.server.tos { locale = request.locale }
      return  tos.tos_digest == value
          or  nil, {
                _          = i18n ["check:tos_digest:incorrect"],
                tos_digest = value,
              }
    end
  end

  -- Token
  -- -----
  do
    Default.data.token = {
      __refines__ = {
        this.data.string.trimmed,
      },
    }
    local checks = Default.data.token.checks
    checks [Layer.size (checks)+1] = function (t)
      local request    = t.request
      local key        = t.key
      local value      = request [key]
      local ok, result = pcall (Token.decode, value)
      if not ok then
        return nil, {
          _ = i18n ["check:token:invalid"],
        }
      end
      request [key] = result.contents
      return  true
    end
  end

  -- Administration token
  -- --------------------
  do
    Default.data.token.administration = {
      __refines__ = {
        this.data.token,
      },
    }
    local checks = Default.data.token.administration.checks
    checks [Layer.size (checks)+1] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      return  value.type == "administration"
          or  nil, {
                _ = i18n ["check:token:invalid"],
              }
    end
    checks [Layer.size (checks)+1] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      return  value.passphrase == Configuration.server.passphrase
          or  nil, {
                _ = i18n ["check:token:invalid"],
              }
    end
  end

  -- Validation token
  -- ----------------
  do
    Default.data.token.validation = {
      __refines__ = {
        this.data.token,
      },
    }
    local checks = Default.data.token.validation.checks
    checks [Layer.size (checks)+1] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      return  value.type == "validation"
          or  nil, {
                _ = i18n ["check:token:invalid"],
              }
    end
    checks [Layer.size (checks)+1] = function (t)
      local store      = t.store
      local request    = t.request
      local key        = t.key
      local identifier = request [key].identifier
      local user       = store / "data" / identifier
      request [key].user = user
      return  nil
         and  user.type == "user"
          or  nil, {
                _ = i18n ["check:token:invalid"],
              }
    end
  end

  -- Authentication Token
  -- --------------------
  do
    Default.data.token.authentication = {
      __refines__ = {
        this.data.token,
      },
    }
    local checks = Default.data.token.authentication.checks
    checks [Layer.size (checks)+1] = function (t)
      local request = t.request
      local key     = t.key
      local value   = request [key]
      return  value.type == "authentication"
          or  nil, {
                _ = i18n ["check:token:invalid"],
              }
    end
    checks [Layer.size (checks)+1] = function (t)
      local store      = t.store
      local request    = t.request
      local key        = t.key
      local identifier = request [key].identifier
      local user       = store / "data" / identifier
      request [key].user = user
      return  user
         and  user.type   == "user"
         and  user.status == "active"
          or  nil, {
                _ = i18n ["check:token:invalid"],
              }
    end
  end

end
