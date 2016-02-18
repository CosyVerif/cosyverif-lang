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
    "cosy.library",
    "cosy.parameters",
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
    local result = {
      name    = Configuration.http.hostname,
      captcha = Configuration.recaptcha.public_key,
    }
    local info = store / "info"
    result ["#user"   ] = info ["#user"   ] or 0
    result ["#project"] = info ["#project"] or 0
    for id in pairs (Configuration.resource.project ["/"]) do
      result ["#" .. id] = info ["#" .. id] or 0
    end
    return result
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
      text   = tos,
      digest = Digest (tos),
    }
  end

  local filters = setmetatable ({}, { __mode = "v" })

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
    local pid = Posix.fork ()
    if pid == 0 then
      local ev = require "ev"
      ev.Loop.default:fork ()
      local Filter  = loader.load "cosy.methods.filter"
      local _, port = server_socket:getsockname ()
      Filter.start {
        url = "ws://{{{interface}}}:{{{port}}}" % {
          interface = Configuration.server.interface,
          port      = port,
        },
      }
      os.exit (0)
    end
    local token = Token.identification {
      pid = pid,
    }
    local iterator
    iterator = function ()
      if not filters [token] then
        filters [token] = iterator
        return token
      end
      local result = results [1]
      if not result then
        Scheduler.sleep (Configuration.filter.timeout)
        result = results [1]
      end
      if result then
        table.remove (results, 1)
      end
      if result and result.success then
        if result.finished then
          filters [token] = nil
        end
        return result.response
      else
        filters [token] = nil
        Posix.kill (pid, 9)
        return nil, {
          _      = i18n ["server:filter:error"],
          reason = result and result.error or i18n ["server:timeout"] % {},
        }
      end
    end
    return iterator
  end

  function Methods.server.cancel (request, store)
    local raw = request.filter
    Parameters.check (store, request, {
      required = {
        filter = Parameters.token.identification,
      },
    })
    if filters [raw] then
      Posix.kill (request.filter.pid, 9)
    end
  end

  -- User
  -- ----

  Methods.user = {}

  function Methods.user.create (request, store, try_only)
    Parameters.check (store, request, {
      required = {
        identifier = Parameters.user.new_identifier,
        password   = Parameters.password.checked,
        email      = Parameters.user.new_email,
        tos_digest = Parameters.tos.digest,
        locale     = Parameters.locale,
      },
      optional = {
        captcha        = Parameters.captcha,
        ip             = Parameters.ip,
        administration = Parameters.token.administration,
      },
    })
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
    local info = store / "info"
    info ["#user"] = (info ["#user"] or 0) + 1
    if  not Configuration.dev_mode
    and (request.captcha == nil or request.captcha == "")
    and not request.administration then
      error {
        _   = i18n ["captcha:missing"],
        key = "captcha"
      }
    end
    if try_only then
      return true
    end
    -- Captcha validation must be done only once,
    -- so it must be __after__ the `try_only`.`
    if request.captcha then
      if not Configuration.dev_mode then
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
            _ = i18n ["captcha:failure"],
          }
        end
      end
    elseif not request.administration then
      error {
        _ = i18n ["method:administration-only"],
      }
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
        email        = Parameters.user.new_email,
        homepage     = Parameters.homepage,
        locale       = Parameters.locale,
        name         = Parameters.name,
        organization = Parameters.organization,
        password     = Parameters.password.checked,
        position     = Parameters.position,
      },
    })
    local user = request.authentication.user
    if request.email then
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
        address   = request.position.address,
        latitude  = request.position.latitude,
        longitude = request.position.longitude,
      }
    end
    if request.avatar then
      user.avatar = {
        full  = request.avatar.normal,
        icon  = request.avatar.icon,
        ascii = request.avatar.ascii,
      }
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
    local info = store / "info"
    info ["#user"] = info ["#user"] - 1
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
    local info = store / "info"
    info ["#project"] = (info ["#project"] or 0) + 1
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
    local info = store / "info"
    info ["#project"] = info ["#project"] - 1
  end

  for id in pairs (Configuration.resource.project ["/"]) do

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
      local info = store / "info"
      info ["#" .. id] = (info ["#" .. id] or 0) + 1
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
      local info = store / "info"
      info ["#" .. id] = info ["#" .. id] + 1
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
      local info = store / "info"
      info ["#" .. id] = info ["#" .. id] - 1
    end
  end

  return Methods

end
