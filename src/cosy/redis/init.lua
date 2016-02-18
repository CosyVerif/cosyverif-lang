if _G.js then
  error "Not available"
end

return function (loader)

  local Configuration = loader.load "cosy.configuration"
  local File          = loader.load "cosy.file"
  local Socket        = loader.load "cosy.socket"
  local Rawsocket     = loader.require "socket"
  local Redis_Client  = loader.require "redis"
  local Posix         = loader.require "posix"

  Configuration.load {
    "cosy.redis",
  }

  local Redis = {}

  local configuration_template = [[
  ################################ GENERAL  #####################################
  daemonize       yes
  pidfile         {{{pid}}}
  bind            {{{interface}}}
  port            {{{port}}}
  timeout         0
  tcp-keepalive   60
  loglevel        notice
  logfile         "{{{log}}}"
  databases       1

  ################################ SNAPSHOTTING  ################################
  save            3600  1
  rdbcompression  yes
  rdbchecksum     yes
  dbfilename      "{{{db}}}"
  dir             "{{{home}}}"

  ############################## APPEND ONLY MODE ###############################
  appendonly      yes
  appendfilename  "{{{append}}}"
  appendfsync     everysec
  ]]

  function Redis.configure ()
    if Configuration.redis.port == 0 then
      local server  = Rawsocket.bind (Configuration.redis.interface, 0)
      server:setoption ("reuseaddr"  , true)
      server:setoption ("tcp-nodelay", true)
      local _, port = server:getsockname ()
      server:close ()
      Configuration.redis.port = port
    end
    local configuration = configuration_template % {
      home      = loader.home,
      pid       = Configuration.redis.pid,
      interface = Configuration.redis.interface,
      port      = Configuration.redis.port,
      log       = Configuration.redis.log,
      db        = Configuration.redis.db,
      append    = Configuration.redis.append,
    }
    local file = assert (io.open (Configuration.redis.configuration, "w"))
    file:write (configuration)
    file:close ()
  end

  function Redis.start ()
    Redis.stop      ()
    Redis.configure ()
    if Posix.fork () == 0 then
      assert (Posix.execp ("redis-server", {
        Configuration.redis.configuration,
      }))
    end
    File.encode (Configuration.redis.data, {
      interface = Configuration.redis.interface,
      port      = Configuration.redis.port,
    })
    Posix.chmod (Configuration.redis.data, "0600")
    repeat
      Posix.nanosleep (0, 100000) -- sleep 100ms
      local socket = Rawsocket.tcp ()
      socket:connect (Configuration.redis.interface, Configuration.redis.port)
      local client = Redis_Client.connect {
        socket = socket,
      }
      local ok = pcall (client.ping, client)
    until ok
  end

  local function getpid ()
    local pid_file = io.open (Configuration.redis.pid, "r")
    if pid_file then
      local pid = pid_file:read "*a"
      pid_file:close ()
      return pid:match "%S+"
    end
  end

  function Redis.stop ()
    local pid = getpid ()
    if pid then
      Posix.kill (pid, 15) -- term
      Posix.wait (pid)
    end
    os.remove (Configuration.redis.configuration)
    os.remove (Configuration.redis.data)
  end

  function Redis.client ()
    local coroutine = require "coroutine.make" ()
    local host      = Configuration.redis.interface
    local port      = Configuration.redis.port
    local database  = Configuration.redis.database
    local socket    = Socket ()
    socket:connect (host, port)
    local client = Redis_Client.connect {
      socket    = socket,
      coroutine = coroutine,
    }
    client:select (database)
    return client
  end

  return Redis

end
