local Data = require "cosy.data"
local _    = require "cosy.util.string"

local Protocol = {}

Protocol.__index = Protocol

function Protocol.new (metam)
  local protocol = setmetatable ({
    meta = metam
  }, Protocol)
  local model = metam.model
  Data.on_write [protocol] = function (target, value, reverse)
    if target / 2 ~= model then
      return
    end
    protocol:on_patch {
      code    = [[${target} = ${value}]] % {
        target = tostring (target),
--        value  = dump (value),
      },
      status  = "applied",
      target  = target,
      value   = value,
      reverse = reverse,
    }
  end
  return protocol
end

function Protocol:on_open ()
  local platform = self.meta.platform
  local resource = self.meta.resource
  local server   = self.meta.server or {}
  platform:log ("Connection to ${resource} opened." % {
    resource = resource
  })
  platform:send {
    action   = "connect",
    resource = resource,
    username = server.username,
    password = server.password,
  }
  local patches  = self.meta.patches
  for _, patch in ipairs (patches) do
    if patch.status == "applied" then
      if platform:send {
        action   = "patch",
        resource = resource,
        username = server.username,
        password = server.password,
        data     = patch.code,
        request  = patch.id,
      } then
        patch.status = "sent"
      end
    end
  end
end

function Protocol:on_close ()
  local platform = self.meta.platform
  local resource = self.meta.resource
  platform:log ("Connection to ${resource} closed." % {
    resource = resource
  })
  self.meta.disconnect ()
end

function Protocol:on_patch (patch)
  local platform = self.meta.platform
  local resource = self.meta.resource
  local server   = self.meta.server or {}
  local patches  = self.meta.patches
  patches:push (patch)
  if platform:send {
    action   = "patch",
    resource = resource,
    username = server.username,
    password = server.password,
    data     = patch.code,
    request  = patch.id,
  } then
    patch.status = "sent"
  end
end

function Protocol:on_message (message)
  local platform = self.meta.platform
  local function disabled_load (x)
    local ow = Data.on_write [self]
    Data.on_write [self] = nil
    if type (x) == "function" then
      local ok, err = pcall (x)
      if not ok then
        platform:error (err)
      end
    elseif type (x) == "string" then
      local ok, err = pcall (loadstring (x))
      if not ok then
        platform:error (err)
      end
    else
      assert (false)
    end
    Data.on_write [self] = ow
  end
  local resource = self.meta.resource
  local patches  = self.meta.patches
  if message.action == "connect" then
    if message.accepted then
      platform:log ("Connected to ${resource}." % {
        resource = resource
      })
      disabled_load (message.data)
    else
      platform:error ("Unable to connect to ${resource}, because ${reason}." % {
        resource = resource,
        reason   = message.reason,
      })
      platform:close ()
    end
  elseif message.action == "patch" then
    local patch = patches [1]
    assert (message.answer == patch.id)
    if message.accepted then
      platform:log ("Patch ${id} on resource ${resource} has been accepted." % {
        id       = patch.id,
        resource = resource,
      })
      if patch.status == "unapplied" then
        platform:log "Patch has been unapplied, reapplying it."
        local ok, err = pcall (loadstring (patch.code))
        if not ok then
          platform:error ("Unable to reapply patch, because ${reason}." % {
            reason = err,
          })
        end
      end
      patches:pop ()
    else
      platform:log (("Patch ${id} on resource ${resource} has been rejected," ..
                     " because ${reason}.") % {
        id       = patch.id,
        resource = resource,
        reason   = message.reason,
      })
      platform:log (message.data)
      for i = #patches, 1, -1 do
        local patch2 = patches [i]
        if patch2.status == "applied" or patch2.status == "sent" then
          platform:log (("Unapply patch ${id} on ${resource}," ..
                         " as a previous one has been rejected.") % {
            id       = patch.id,
            resource = resource,
          })
          disabled_load (patch2.reverse)
          patch2.status = "unapplied"
        end
      end
      patches:pop ()
    end
  elseif message.action == "update" then
    for i = #patches, 1, -1 do
      local patch = patches [i]
      if patch.status == "applied" or patch.status == "sent" then
        platform:log (("Unapply patch ${id} on resource ${resource}," ..
                       " because of interleaved updates.") % {
          id       = patch.id,
          resource = resource,
        })
        disabled_load (patch.reverse)
        patch.status = "unapplied"
      end
    end
    platform:log ("Patch received.")
    disabled_load (message.data)
  else
    platform:error ("Unexpected message: " .. tostring (message.action))
  end
end

return Protocol
