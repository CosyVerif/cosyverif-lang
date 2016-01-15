return function (loader)

  local Methods  = {}

  local Configuration = loader.load "cosy.configuration"
  local Digest        = loader.load "cosy.digest"
  local Email         = loader.load "cosy.email"
  local I18n          = loader.load "cosy.i18n"
  local Json          = loader.load "cosy.json"
  local Logger        = loader.load "cosy.logger"
  local Parameters    = loader.load "cosy.parameters"
  local Password      = loader.load "cosy.password"
  local Scheduler     = loader.load "cosy.scheduler"
  local Time          = loader.load "cosy.time"
  local Token         = loader.load "cosy.token"
  local Value         = loader.load "cosy.value"
  local Layer         = loader.require "layeredata"
  local Posix         = loader.require "posix"
  local Websocket     = loader.require "websocket"

  Configuration.load {
    "cosy.nginx",
    "cosy.methods",
    "cosy.nginx",
    "cosy.parameters",
    "cosy.server",
    "cosy.token",
  }

  local i18n   = I18n.load {
    "cosy.methods",
    "cosy.server",
  }
  i18n._locale = Configuration.locale

  -- Server
  -- ------

  Methods.server = {}

  function Methods.server.list_methods (request, store)
    Parameters.check (store, request, {
      optional = {
        locale = Parameters.locale,
      },
    })
    local locale = Configuration.locale
    if request.locale then
      locale = request.locale or locale
    end
    local result = {}
    local function f (current, prefix)
      for k, v in pairs (current) do
        if type (v) == "function" then
          local name = (prefix or "") .. k:gsub ("_", "-")
          local ok, description = pcall (function ()
            return i18n [name] % { locale = locale }
          end)
          if not ok then
            Logger.warning {
              _      = i18n ["translation:failure"],
              reason = description,
            }
            description = name
          end
          local _, parameters = pcall (v, {
            __DESCRIBE = true,
          })
          result [name] = {
            description = description,
            parameters  = parameters,
          }
        elseif type (v) == "table" then
          f (v, (prefix or "") .. k:gsub ("_", "-") .. ":")
        end
      end
    end
    f (Methods, nil)
    return result
  end

  function Methods.server.stop (request, store)
    Parameters.check (store, request, {
      required = {
        administration = Parameters.token.administration,
      },
    })
    return true
  end

  function Methods.server.information (request, store)
    Parameters.check (store, request, {})
    return {
      name    = Configuration.http.hostname,
      captcha = Configuration.recaptcha.public_key,
    }
  end

  function Methods.server.tos (request, store)
    Parameters.check (store, request, {
      optional = {
        authentication = Parameters.token.authentication,
        locale         = Parameters.locale,
      },
    })
    local locale = Configuration.locale
    if request.locale then
      locale = request.locale or locale
    end
    if request.authentication then
      locale = request.authentication.user.locale or locale
    end
    local tos = i18n ["terms-of-service"] % {
      locale = locale,
    }
    return {
      tos        = tos,
      tos_digest = Digest (tos),
    }
  end

  function Methods.server.filter (request, store)
    local back_request = {}
    for k, v in pairs (request) do
      back_request [k] = v
    end
    Parameters.check (store, request, {
      required = {
        iterator = Parameters.iterator,
      },
      optional = {
        authentication = Parameters.token.authentication,
      }
    })
    local server_socket
    local running       = Scheduler.running ()
    local results       = {}
    local addserver     = Scheduler.addserver
    Scheduler.addserver = function (s, f)
      server_socket = s
      addserver (s, f)
    end
    Websocket.server.copas.listen {
      interface = Configuration.server.interface,
      port      = 0,
      protocols = {
        ["cosy:filter"] = function (ws)
          ws:send (Value.expression (back_request))
          while ws.state == "OPEN" do
            local message = ws:receive ()
            if message then
              local value = Value.decode (message)
              results [#results+1] = value
              Scheduler.wakeup (running)
            end
          end
          Scheduler.removeserver (server_socket)
        end
      }
    }
    Scheduler.addserver = addserver
    if Posix.fork () == 0 then
      package.loaded ["copas"     ] = nil
      package.loaded ["copas.ev"  ] = nil
      package.loaded ["ev"        ] = nil
      package.loaded ["hotswap.ev"] = nil
      package.loaded ["hotswap"   ] = nil
      local Filter = loader.require "cosy.methods.filter"
      local _, port = server_socket:getsockname ()
      Filter.new ("ws://{{{interface}}}:{{{port}}}" % {
        interface = Configuration.server.interface,
        port      = port,
      })
      os.exit (0)
    end
    return function ()
      repeat
        local result = results [1]
        if result then
          table.remove (results, 1)
          if result.success then
            return result.response
          else
            return nil, {
              _      = i18n ["server:filter:error"],
              reason = result.error,
            }
          end
        else
          Scheduler.sleep (Configuration.filter.timeout)
        end
      until result and result.finished
    end
  end

  -- User
  -- ----

  Methods.user = {}

  function Methods.user.create (request, store, try_only)
    Parameters.check (store, request, {
      required = {
        identifier = Parameters.resource.identifier,
        password   = Parameters.password.checked,
        email      = Parameters.email,
        tos_digest = Parameters.tos.digest,
        locale     = Parameters.locale,
      },
      optional = {
        captcha        = Parameters.captcha,
        ip             = Parameters.ip,
        administration = Parameters.token.administration,
      },
    })
    if store / "email" / request.email then
      error {
        _     = i18n ["email:exist"],
        email = request.email,
      }
    end
    if store / "data" / request.identifier then
      error {
        _        = i18n ["identifier:exist"],
        identifier = request.identifier,
      }
    end
    if request.captcha then
      local url  = "https://www.google.com/recaptcha/api/siteverify"
      local body = "secret="    .. Configuration.recaptcha.private_key
                .. "&response=" .. request.captcha
                .. "&remoteip=" .. request.ip
      local response, status = loader.request (url, body)
      assert (status == 200)
      response = Json.decode (response)
      assert (response)
      if not response.success then
        error {
          _          = i18n ["captcha:failure"],
          identifier = request.identifier,
        }
      end
    elseif not request.administration then
      error {
        _          = i18n ["method:administration-only"],
        identifier = request.identifier,
      }
    end
    local email = store / "email" + request.email
    email.identifier = request.identifier
    if request.locale == nil then
      request.locale = Configuration.locale
    end
    local user = store / "data" + request.identifier
    user.checked     = false
    user.email       = request.email
    user.identifier  = request.identifier
    user.lastseen    = Time ()
    user.locale      = request.locale
    user.password    = Password.hash (request.password)
    user.tos_digest  = request.tos_digest
    user.reputation  = Configuration.reputation.initial
    user.status      = "active"
    user.type        = "user"
    if try_only then
      return true
    end
    Email.send {
      locale  = user.locale,
      from    = {
        _     = i18n ["user:create:from"],
        name  = Configuration.http.hostname,
        email = Configuration.server.email,
      },
      to      = {
        _     = i18n ["user:create:to"],
        name  = user.identifier,
        email = user.email,
      },
      subject = {
        _          = i18n ["user:create:subject"],
        servername = Configuration.http.hostname,
        identifier = user.identifier,
      },
      body    = {
        _          = i18n ["user:create:body"],
        identifier = user.identifier,
        token      = Token.validation (user),
      },
    }
    return {
      authentication = Token.authentication (user),
    }
  end

  function Methods.user.send_validation (request, store, try_only)
    Parameters.check (store, request, {
      required = {
        authentication = Parameters.token.authentication,
      },
    })
    local user = request.authentication.user
    if try_only then
      return true
    end
    Email.send {
      locale  = user.locale,
      from    = {
        _     = i18n ["user:update:from"],
        name  = Configuration.http.hostname,
        email = Configuration.server.email,
      },
      to      = {
        _     = i18n ["user:update:to"],
        name  = user.identifier,
        email = user.email,
      },
      subject = {
        _          = i18n ["user:update:subject"],
        servername = Configuration.http.hostname,
        identifier = user.identifier,
      },
      body    = {
        _          = i18n ["user:update:body"],
        host       = Configuration.http.hostname,
        identifier = user.identifier,
        token      = Token.validation (user),
      },
    }
  end

  function Methods.user.validate (request, store)
    Parameters.check (store, request, {
      required = {
        authentication = Parameters.token.authentication,
      },
    })
    request.authentication.user.checked = true
  end

  function Methods.user.authenticate (request, store)
    local ok, err = pcall (function ()
      Parameters.check (store, request, {
        required = {
          user     = Parameters.user.active,
          password = Parameters.password,
        },
      })
    end)
    if not ok then
      if request.__DESCRIBE then
        error (err)
      else
        error {
          _ = i18n ["user:authenticate:failure"],
        }
      end
    end
    local user     = request.user
    local verified = Password.verify (request.password, user.password)
    if not verified then
      error {
        _ = i18n ["user:authenticate:failure"],
      }
    end
    if type (verified) == "string" then
      user.password = verified
    end
    user.lastseen = Time ()
    return {
      authentication = Token.authentication (user),
    }
  end

  function Methods.user.authentified_as (request, store)
    Parameters.check (store, request, {
      optional = {
        authentication = Parameters.token.authentication,
      },
    })
    return {
      identifier = request.authentication
               and request.authentication.user.identifier
                or nil,
    }
  end

  function Methods.user.update (request, store, try_only)
    Parameters.check (store, request, {
      required = {
        authentication = Parameters.token.authentication,
      },
      optional = {
        avatar       = Parameters.avatar,
        email        = Parameters.email,
        homepage     = Parameters.homepage,
        locale       = Parameters.locale,
        name         = Parameters.name,
        organization = Parameters.organization,
        password     = Parameters.password.checked,
        position     = Parameters.position,
      },
    })
    local user = request.authentication.user
    if request.email and user.email ~= request.email then
      if store / "email" / request.email then
        error {
          _     = i18n ["email:exist"],
          email = request.email,
        }
      end
      local oldemail      = store / "email" / user.email
      local newemail      = store / "email" + request.email
      newemail.identifier = oldemail.identifier
      local _             = store / "email" - user.email
      user.email          = request.email
      user.checked        = false
      Methods.user.send_validation ({
        authentication = Token.authentication (user),
        try_only       = try_only,
      }, store)
    end
    if request.password then
      user.password = Password.hash (request.password)
    end
    if request.position then
      user.position = {
        country        = request.position.country,
        city           = request.position.city,
        latitude       = request.position.latitude,
        longitude      = request.position.longitude,
        continent_code = request.position.continent_code,
        country_code   = request.position.country_code,
        timezone       = request.position.timezone,
      }
    end
    if request.avatar then
      user.avatar = request.avatar
    end
    for _, key in ipairs { "name", "homepage", "organization", "locale" } do
      if request [key] then
        user [key] = request [key]
      end
    end
    return {
      avatar         = user.avatar,
      checked        = user.checked,
      email          = user.email,
      homepage       = user.homepage,
      lastseen       = user.lastseen,
      locale         = user.locale,
      name           = user.name,
      organization   = user.organization,
      position       = user.position,
      identifier     = user.identifier,
      authentication = Token.authentication (user)
    }
  end

  function Methods.user.information (request, store)
    Parameters.check (store, request, {
      required = {
        user = Parameters.user,
      },
    })
    local user = request.user
    return {
      avatar       = user.avatar,
      homepage     = user.homepage,
      name         = user.name,
      organization = user.organization,
      position     = user.position,
      identifier   = user.identifier,
    }
  end

  function Methods.user.recover (request, store, try_only)
    Parameters.check (store, request, {
      required = {
        validation = Parameters.token.validation,
        password   = Parameters.password.checked,
      },
    })
    local user  = request.validation.user
    local token = Token.authentication (user)
    Methods.user.update ({
      user     = token,
      password = request.password,
      try_only = try_only,
    }, store)
    return {
      authentication = token,
    }
  end

  function Methods.user.reset (request, store, try_only)
    Parameters.check (store, request, {
      required = {
        email = Parameters.email,
      },
    })
    local email = store / "email" / request.email
    if email then
      return
    end
    local user = store / "data" / email.identifier
    if not user or user.type ~= "user" then
      return
    end
    user.password = ""
    if try_only then
      return
    end
    Email.send {
      locale  = user.locale,
      from    = {
        _     = i18n ["user:reset:from"],
        name  = Configuration.http.hostname,
        email = Configuration.server.email,
      },
      to      = {
        _     = i18n ["user:reset:to"],
        name  = user.identifier,
        email = user.email,
      },
      subject = {
        _          = i18n ["user:reset:subject"],
        servername = Configuration.http.hostname,
        identifier = user.identifier,
      },
      body    = {
        _          = i18n ["user:reset:body"],
        identifier = user.identifier,
        validation = Token.validation (user),
      },
    }
  end

  function Methods.user.suspend (request, store)
    Parameters.check (store, request, {
      required = {
        authentication = Parameters.token.authentication,
        user           = Parameters.user.active,
      },
    })
    local origin = request.authentication.user
    local user   = request.user
    if origin.identifier == user.identifier then
      error {
        _ = i18n ["user:suspend:self"],
      }
    end
    local reputation = Configuration.reputation.suspend
    if origin.reputation < reputation then
      error {
        _        = i18n ["user:suspend:not-enough"],
        owned    = origin.reputation,
        required = reputation
      }
    end
    origin.reputation = origin.reputation - reputation
    user.status       = "suspended"
  end

  function Methods.user.release (request, store)
    Parameters.check (store, request, {
      required = {
        authentication = Parameters.token.authentication,
        user           = Parameters.user.suspended,
      },
    })
    local origin = request.authentication.user
    local user   = request.user
    if origin.identifier == user.identifier then
      error {
        _ = i18n ["user:release:self"],
      }
    end
    local reputation = Configuration.reputation.release
    if origin.reputation < reputation then
      error {
        _        = i18n ["user:suspend:not-enough"],
        owned    = origin.reputation,
        required = reputation
      }
    end
    origin.reputation = origin.reputation - reputation
    user.status       = "active"
  end

  function Methods.user.delete (request, store)
    Parameters.check (store, request, {
      required = {
        authentication = Parameters.token.authentication,
      },
    })
    local user = request.authentication.user
    local _ = store / "email" - user.email
    local _ = store / "data"  - user.identifier
  end

  -- Project
  -- -------

  Methods.project = {}

  function Methods.project.create (request, store)
    Parameters.check (store, request, {
      required = {
        authentication = Parameters.token.authentication,
        identifier     = Parameters.resource.identifier,
      },
      optional = {
        is_private = Parameters.is_private,
      },
    })
    local user    = request.authentication.user
    local project = user / request.identifier
    if project then
      error {
        _    = i18n ["resource:exist"],
        name = request.identifier,
      }
    end
    project             = user + request.identifier
    project.permissions = {}
    project.identifier  = request.identifier
    project.type        = "project"
  end

  function Methods.project.delete (request, store)
    Parameters.check (store, request, {
      required = {
        authentication = Parameters.token.authentication,
        project        = Parameters.project,
      },
    })
    local project = request.project
    if not project then
      error {
        _    = i18n ["resource:miss"],
        name = request.project.rawname,
      }
    end
    local user = request.authentication.user
    if not (user < project) then
      error {
        _    = i18n ["resource:forbidden"],
        name = tostring (project),
      }
    end
    local _ = - project
  end

  for id in Layer.pairs (Configuration.resource.project ["/"]) do

    Methods [id] = {}
    local methods = Methods [id]

    function methods.create (request, store)
      Parameters.check (store, request, {
        required = {
          authentication = Parameters.token.authentication,
          project        = Parameters.project,
          name           = Parameters.resource.identifier,
        },
      })
      local user    = request.authentication.user
      local project = request.project
      if project.username ~= user.username then
        error {
          _    = i18n ["resource:forbidden"],
          name = request.name,
        }
      end
      local resource = project / request.name
      if resource then
        error {
          _    = i18n ["resource:exist"],
          name = request.name,
        }
      end
      resource             = request.project + request.name
      resource.id          = request.name
      resource.type        = id
      resource.username    = user.username
      resource.projectname = project.projectname
    end

    function methods.copy (request, store)
      Parameters.check (store, request, {
        required = {
          authentication = Parameters.token.authentication,
          [id]           = Parameters.resource [id],
          project        = Parameters.project,
          name           = Parameters.resource.identifier,
        },
      })
      local user     = request.authentication.user
      local project  = request.project
      if project.username ~= user.username then
        error {
          _    = i18n ["resource:forbidden"],
          name = request.name,
        }
      end
      local resource = project / request.name
      if resource then
        error {
          _    = i18n ["resource:exist"],
          name = request.name,
        }
      end
      resource             = request.project + request.name
      resource.id          = request.name
      resource.type        = id
      resource.username    = user.username
      resource.projectname = project.projectname
    end

    function methods.delete (request, store)
      Parameters.check (store, request, {
        required = {
          authentication = Parameters.token.authentication,
          resource       = Parameters [id],
        },
      })
      local resource = request.resource
      if not resource then
        error {
          _    = i18n ["resource:miss"],
          name = resource.id,
        }
      end
      local user = request.authentication.user
      if resource.username ~= user.username then
        error {
          _    = i18n ["resource:forbidden"],
          name = resource.id,
        }
      end
      local _ = user - resource.id
    end
  end

  return Methods

end
