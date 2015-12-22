return function (loader)

  local Configuration = loader.load "cosy.configuration"
  local I18n          = loader.load "cosy.i18n"
  local Scheduler     = loader.load "cosy.scheduler"
  local Value         = loader.load "cosy.value"
  local Colors        = loader.require "ansicolors"
  local Websocket     = loader.require "websocket"
  local Http          = loader.require "socket.http"
  local Ltn12         = loader.require "ltn12"

  Configuration.load {
    "cosy.cli",
  }

  local i18n   = I18n.load {
    "cosy.cli",
  }
  i18n._locale = Configuration.cli.locale

  -- http://lua.2524044.n2.nabble.com/Reading-passwords-in-a-console-application-td6641037.html
  local function getpassword ()
    local stty_ret = os.execute ("stty -echo 2>/dev/null")
    if stty_ret ~= 0 then
      io.write("\027[08m") -- ANSI 'hidden' text attribute
    end
    local ok, pass = pcall (io.read, "*l")
    if stty_ret == 0 then
      os.execute("stty sane")
    else
      io.write("\027[00m")
    end
    io.write("\n")
    os.execute("stty sane")
    if ok then
      return pass
    end
  end

  local function show_status (result, err)
    if result then
      if type (result) ~= "table" then
        result = { message = tostring (result) }
      end
      print (Colors ("%{black greenbg}" .. i18n ["success"] % {}),
             Colors ("%{green blackbg}" .. (result.message ~= nil and tostring (result.message) or "")))
    end
    if err then
      if type (err) ~= "table" then
        err = { message = tostring (err) }
      end
      print (Colors ("%{black redbg}" .. i18n ["failure"] % {}),
             Colors ("%{red blackbg}" .. (err.message ~= nil and tostring (err.message) or "")))
      if err._ == "check:error" then
        local max = 0
        for i = 1, #err.reasons do
          local reason = err.reasons [i]
          max = math.max (max, #reason.key)
        end
        for i = 1, #err.reasons do
          local reason    = err.reasons [i]
          local parameter = reason.key
          local message   = reason.message
          local space = ""
          for _ = #parameter, max+3 do
            space = space .. " "
          end
          space = space .. " => "
          print (Colors ("%{black redbg}" .. tostring (parameter)) ..
                 Colors ("%{reset}" .. space) ..
                 Colors ("%{red blackbg}" .. tostring (message)))
        end
      end
    end
    return result
  end

  local Commands = {}
  local Prepares = {}
  local Options  = {}
  local Results  = {}

  function Options.set (parser, part, name, oftype, description)
    if name == "locale" then
      if not oftype then
        parser:option "-l" "--locale" {
          description = i18n ["option:locale"] % {},
          default     = Configuration.cli.locale,
        }
      end
    elseif part == "optional" and name == "debug" then
      parser:flag "-d" "--debug" {
        description = i18n ["flag:debug"] % {},
      }
    elseif part == "optional" and name == "force" then
      parser:flag "-f" "--force" {
        description = i18n ["flag:force"] % {},
      }
    elseif oftype == "password:checked" then
      parser:flag ("--{{{name}}}" % { name = name }) {
        description = i18n ["flag:password"] % {},
        default     = part == "required" and "" or nil,
      }
    elseif oftype == "password" then
      parser:flag ("--{{{name}}}" % { name = name }) {
        description = i18n ["flag:password"] % {},
        default     = part == "required" and "" or nil,
      }
    elseif oftype == "token:administration" then
      parser:option ("--{{{name}}}" % { name = name }) {
        description = description,
      }
    elseif oftype == "token:authentication" then
      parser:option ("--{{{name}}}" % { name = name }) {
        description = description,
      }
    elseif oftype == "tos:digest" then
      local _ = false
    elseif oftype == "position" then
      parser:option ("--{{{name}}}" % { name = name }) {
        description = description,
      }
    elseif oftype == "ip" then
      local _ = false
    elseif oftype == "captcha" then
      parser:flag ("--{{{name}}}" % { name = name }) {
        description = i18n ["flag:captcha"] % {},
        default     = part == "required" and "" or nil,
      }
    elseif oftype == "boolean" then
      parser:flag ("--{{{name}}}" % { name = name }) {
        description = description,
      }
    elseif part == "required" then
      parser:argument ("{{{name}}}" % { name = name }) {
        description = description,
      }
    elseif part == "optional" then
      parser:option ("--{{{name}}}" % { name = name }) {
        description = description,
      }
    else
      print (part, name, oftype)
      assert (false)
    end
  end

  function Commands.new (t)
    local commands   = setmetatable (t, Commands)
    commands.methods = commands.client.server.list_methods {
      locale = Configuration.locale.default,
    }
    local method_names = {}
    for name in pairs (commands.methods) do
      method_names [#method_names+1] = name
    end
    table.sort (method_names)
    for _, name in ipairs (method_names) do
      local info = commands.methods [name]
      local command = commands.parser:command (name) {
        description = info.description,
      }
      local optname  = {}
      local optinfos = {}
      for part, subt in pairs (info.parameters) do
        for parameter, x in pairs (subt) do
          x.part = part -- store field   optional / required
          optname  [#optname+1] = parameter
          optinfos [parameter] = x
        end
      end
      table.sort (optname)
      for _, parameter in ipairs (optname) do
         local x = optinfos [parameter]
         Options.set (command, x.part, parameter, x.type, x.description)
       end
    end
    return commands
  end

  function Commands.parse (commands)
    local args = commands.parser:parse ()
    local key
    for method in pairs (commands.methods) do
      if args [method] then
        key = method
        break
      end
    end
    assert (key)
    if Prepares [key] then
      Prepares [key] (commands, args)
    end
    local parameters = {
      authentication = commands.data.authentication,
    }
    for _, x in pairs (commands.methods [key].parameters) do
      for name, t in pairs (x) do
        if t.type == "password" and args [name] then
          io.write (i18n ["argument:password1"] % {} .. " ")
          parameters [name] = getpassword ()
        elseif t.type == "password:checked" and args [name] then
          local passwords = {}
          repeat
            io.write (i18n ["argument:password1"] % {} .. " ")
            passwords [1] = getpassword ()
            io.write (i18n ["argument:password2"] % {} .. " ")
            passwords [2] = getpassword ()
            if passwords [1] ~= passwords [2] then
              print (i18n ["argument:password:nomatch"] % {})
            end
          until passwords [1] == passwords [2]
          parameters [name] = passwords [1]
        elseif t.type == "position" and args [name] then
          if args [name] == "auto" then
            parameters [name] = true
          else
            parameters [name] = args [name] / "{{{Country}}}/{{{City}}}"
          end
        elseif t.type == "captcha" and args [name] then
          Commands.captcha (args, parameters)
        elseif args [name] then
          if t.type == "token:authentication" then
            local _ = false
          elseif t.type == "avatar" then
            local avatar = args [name]
            local filename = avatar
            local errresult
            if avatar:match "^https?://" then
              filename   = os.tmpname ()
              local file = io.open (filename, "w")
              local _, status = Http.request {
                method = "GET",
                url    = avatar,
                sink   = Ltn12.sink.file (file),
              }
              if status ~= 200 then
                errresult = i18n {
                  _      = i18n ["url:not-found"],
                  url    = avatar,
                  reason = status,
                }
              end
              file:close ()
            elseif avatar:match "^~" then
              filename = os.getenv "HOME" .. avatar:sub (2)
            end
            local file, err = io.open (filename, "r")
            if not file then
              errresult = i18n {
                _        = i18n ["file:not-found"],
                filename = filename,
                reason   = err,
              }
            end
            local body = file:read "*all"
            file:close ()
            local _, status, headers = Http.request (args.server .. "/upload", body)
            if status == 200 then
              parameters [name] = headers ["cosy-avatar"]
            else
              errresult = i18n {
                _      = i18n ["upload:failure"],
                status = status,
              }
            end
            if errresult then
              show_status (nil, errresult)
              os.exit (1)
            end
          else
            parameters [name] = args [name]
          end
        end
      end
    end
    local result, err = commands.client [key] (parameters)
    if Results [key]
    and (  type (result) == "function"
        or type (result) == "table") then
      result, err = pcall (Results [key], commands, result)
    end
    show_status (result, err)
    return result
  end

  function Commands.captcha (args, parameters)
    local info      = {}
    local addserver = Scheduler.addserver
    Scheduler.addserver = function (s, f)
      info.socket = s
      local ok, port = s:getsockname ()
      if ok then
        info.port = port
      end
      addserver (s, f)
    end
    Websocket.server.copas.listen {
      port      = 0,
      protocols = {
        cosycli = function (ws)
          while true do
            local message = ws:receive ()
            if message then
              message = Value.decode (message)
              parameters.captcha = message.response
              Scheduler.removeserver (info.socket)
            else
              ws:close()
              return
            end
          end
        end
      },
    }
    Scheduler.addserver = addserver
    os.execute ([[
      xdg-open {{{url}}} 2> /dev/null || open {{{url}}} /dev/null &
    ]] % {
      url = "{{{server}}}/html/captchacli.html?port={{{port}}}" % {
        server = args.server,
        port   = info.port,
      },
    })
    Scheduler.loop()
  end

  Results ["server:information"] = function (_, response)
    local max  = 0
    local keys = {}
    for key in pairs (response) do
      keys [#keys+1] = key
      max = math.max (max, #key)
    end
    for i = 1, #keys do
      local key   = keys [i]
      local value = response [key]
      local space = ""
      for _ = #key, max+3 do
        space = space .. " "
      end
      space = space .. " => "
      print (Colors ("%{black yellowbg}" .. tostring (key)) ..
             Colors ("%{reset}" .. space) ..
             Colors ("%{yellow blackbg}" .. tostring (value)))
    end
  end

  Results ["server:tos"] = function (_, response)
    print (response.tos)
    print (Colors ("%{black yellowbg}" .. "digest") ..
           Colors ("%{reset}" .. " => ") ..
           Colors ("%{yellow blackbg}" .. response.tos_digest))
  end

  Results ["server:filter"] = function (_, result)
    local i = 0
    for value in result do
      i = i + 1
      if type (value) ~= "table" then
        print (Colors ("%{black yellowbg} " .. tostring (i)) ..
               Colors ("%{reset}" .. " => ") ..
               Colors ("%{yellow blackbg}" .. Value.expression (value)))
      else
        print (Colors ("%{black cyanbg} " .. tostring (i) .. " ") ..
               Colors ("%{reset}" .. " => "))
        local max  = 0
        local keys = {}
        for k in pairs (value) do
          keys [#keys+1] = k
          max = math.max (max, #tostring (k))
        end
        for j = 1, #keys do
          local jkey   = keys [j]
          local jvalue = value [jkey]
          local jspace = ""
          for _ = #tostring (jkey), max+3 do
            jspace = jspace .. " "
          end
          jspace = jspace .. " => "
          print (Colors ("%{black yellowbg}  " .. tostring (jkey)) ..
                 Colors ("%{reset}" .. jspace) ..
                 Colors ("%{yellow blackbg}" .. Value.expression (jvalue)))
        end
      end
    end
  end

  Prepares ["user:create"] = function (commands, args)
    if not args.tos_digest then
      local tos = commands.client.server.tos {
        locale = args.locale,
      }
      print (tos.tos)
      args.tos_digest = tos.tos_digest
    end
  end

  Results ["user:authentified-as"] = function (_, response)
    print (Value.expression (response))
    print (Colors ("%{black yellowbg}" .. "username") ..
           Colors ("%{reset}" .. " => ") ..
           Colors ("%{yellow blackbg}" .. response.username))
  end

  Results ["user:information"] = function (_, response)
    if response.avatar then
      local avatar     = response.avatar
      local inputname  = os.tmpname ()
      local file = io.open (inputname, "w")
      assert (file)
      file:write (avatar)
      file:close ()
      os.execute ([[
        img2txt -W 40 -H 20 {{{input}}} 2> /dev/null
      ]] % {
        input  = inputname,
      })
      os.remove (inputname)
      response.avatar  = nil
    end
    if response.position then
      response.position = "{{{country}}}/{{{city}}}" % response.position
    end
    if response.lastseen then
      response.lastseen = os.date ("%x, %X", response.lastseen)
    end
    if response.authentication then
      response.authentication = nil
    end
    local max  = 0
    local keys = {}
    for key in pairs (response) do
      keys [#keys+1] = key
      max = math.max (max, #key)
    end
    max = max + 3
    table.sort (keys)
    for i = 1, #keys do
      local key   = keys [i]
      local value = response [key]
      local space = ""
      for _ = #key, max do
        space = space .. " "
      end
      space = space .. " => "
      print (Colors ("%{black yellowbg}" .. tostring (key)) ..
             Colors ("%{reset}" .. space) ..
             Colors ("%{yellow blackbg}" .. tostring (value)))
    end
  end

  Results ["user:update"] = Results ["user:information"]

  return Commands

end
