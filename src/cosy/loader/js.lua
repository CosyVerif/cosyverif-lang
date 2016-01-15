if #setmetatable ({}, { __len = function () return 1 end }) ~= 1
then
  error "Cosy requires Lua >= 5.2 or Luajit with 5.2 compatibility to run."
end

local loader   = {}
local modules  = setmetatable ({}, { __mode = "kv" })

loader.request   = function (url)
  local request = _G.js.new (_G.window.XMLHttpRequest)
  request:open ("GET", url, false)
  request:send (nil)
  if request.status == 200 then
    return request.responseText, request.status
  else
    return nil , request.status
  end
end
table.insert (package.searchers, 2, function (name)
  local url = "/lua/" .. name
  local result, err
  result, err = loader.request (url)
  if not result then
    error (err)
  end
  return load (result, url)
end)
loader.require = require
loader.load    = function (name)
  if modules [name] then
    return modules [name]
  end
  local module   = loader.require (name) (loader) or true
  modules [name] = module
  return module
end

loader.hotswap   = loader.require "hotswap".new {}
loader.coroutine = loader.require "coroutine.make" ()
_G.coroutine     = loader.coroutine

loader.scheduler = {
  waiting   = {},
  ready     = {},
  coroutine = loader.require "coroutine.make" (),
}
function loader.scheduler.running ()
  return loader.scheduler.coroutine.running ()
end
function loader.scheduler.sleep (time)
  time = time or -math.huge
  local co = loader.scheduler.running ()
  if time > 0 then
    _G.window:setTimeout (function ()
      loader.scheduler.waiting [co] = nil
      loader.scheduler.ready   [co] = true
    end, time * 1000)
  end
  if time ~= 0 then
    loader.scheduler.waiting [co] = true
    loader.scheduler.ready   [co] = nil
    loader.scheduler.coroutine.yield ()
  end
end
function loader.scheduler.wakeup (co)
  loader.scheduler.waiting [co] = nil
  loader.scheduler.ready   [co] = true
  if coroutine.status (loader.scheduler.co) ~= "running" then
    coroutine.resume (loader.scheduler.co)
  end
end
function loader.scheduler.addthread (f, ...)
  local co = loader.scheduler.coroutine.create (f)
  loader.scheduler.ready [co] = {
    parameters = { ... },
  }
end
local unpack = table.unpack or unpack
function loader.scheduler.loop ()
  loader.scheduler.co = coroutine.running ()
  while true do
    local to_run, t = next (loader.scheduler.ready)
    if to_run then
      local ok, err = loader.scheduler.coroutine.resume (to_run, type (t) == "table" and unpack (t.parameters))
      if not ok then
        _G.window.console:log (err)
      end
      if loader.scheduler.coroutine.status (to_run) == "dead" then
        loader.scheduler.waiting [to_run] = nil
        loader.scheduler.ready   [to_run] = nil
      end
    end
    if  not next (loader.scheduler.ready  )
    and not next (loader.scheduler.waiting) then
      break
    elseif not next (loader.scheduler.ready) then
      coroutine.yield ()
    end
  end
end

loader.load "cosy.string"
return loader
