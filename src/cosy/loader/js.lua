if #setmetatable ({}, { __len = function () return 1 end }) ~= 1
then
  error "Cosy requires Lua >= 5.2 or Luajit with 5.2 compatibility to run."
end

local Loader = {}

package.preload ["cosy.loader"] = function ()
  return Loader
end

Loader.loadhttp = function (url)
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
  result, err = Loader.loadhttp (url)
  if not result then
    error (err)
  end
  return load (result, url)
end)

Loader.hotswap = require "hotswap" .new {}

                 require "cosy.string"
local Coromake = require "coroutine.make"
_G.coroutine   = Coromake ()

return Loader
