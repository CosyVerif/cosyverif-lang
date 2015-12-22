local loader        = require "cosy.loader.lua" {
  logto = false,
}
local Configuration = loader.load "cosy.configuration"
local Parameters    = loader.load "cosy.parameters"
local Scheduler     = loader.load "cosy.scheduler"
local Store         = loader.load "cosy.store"
local Value         = loader.load "cosy.value"
local Coromake      = loader.require "coroutine.make"
local Websocket     = loader.require "websocket"

Configuration.load {
  "cosy.parameters",
  "cosy.server",
}

Scheduler.addthread (function ()
  local client  = Websocket.client.sync { timeout = 5 }
  assert (client:connect ("ws://{{{interface}}}:{{{port}}}" % {
    interface = Configuration.server.interface,
    port      = _G.port,
  }, "cosy:filter"))
  local request = client:receive ()
  request       = Value.decode (request)
  local store   = Store.new ()
  local view    = Store.toview (store)
  if request.authentication then
    view = view % request.authentication
  end
  request.authentication = nil
  Parameters.check (view, request, {
    required = {
      iterator = Parameters.iterator,
    },
  })
  local coro     = Coromake ()
  local iterator = coro.create (request.iterator)
  local function sanitize (t)
    if type (t) ~= "table" then
      return t
    else
      local r = {}
      for k, v in pairs (t) do
        r [sanitize (k)] = sanitize (v)
      end
      return r
    end
  end
  repeat
    local ok, result = coro.resume (iterator, coro, view)
    if result ~= nil then
      result = sanitize (result)
      client:send (Value.expression {
        success  = ok,
        response = ok and result or nil,
        error    = not ok and result or nil,
        finished = coro.status (iterator) == "dead" or nil
      })
    end
  until coro.status (iterator) == "dead"
  client:send (Value.expression {
    success  = true,
    finished = true,
  })
end)

Scheduler.loop ()
