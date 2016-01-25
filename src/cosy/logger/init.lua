return function (loader)

  local I18n   = loader.load "cosy.i18n"
  local Logger = {}

  local i18n = I18n.load {}

  function Logger.update ()
    if _G.js then
      local logger = _G.window.console
      function Logger.debug (t)
        logger:log ("DEBUG: "   .. i18n (t).message)
      end
      function Logger.info (t)
        logger:log ("INFO: "    .. i18n (t).message)
      end
      function Logger.warning (t)
        logger:log ("WARNING: " .. i18n (t).message)
      end
      function Logger.error (t)
        logger:log ("ERROR: "   .. i18n (t).message)
      end
    elseif loader.logto == false then
      function Logger.debug   () end
      function Logger.info    () end
      function Logger.warning () end
      function Logger.error   () end
    elseif loader.logto then
      local logging = loader.require "logging"
      logging.file  = loader.require "logging.file"
      local logger  = logging.file (loader.logto, "%Y-%m-%d")
      function Logger.debug (t)
        logger:debug (i18n (t).message)
      end
      function Logger.info (t)
        logger:info  (i18n (t).message)
      end
      function Logger.warning (t)
        logger:warn  (i18n (t).message)
      end
      function Logger.error (t)
        logger:error (i18n (t).message)
      end
    else
      local logging   = loader.require "logging"
      logging.console = loader.require "logging.console"
      local logger    = logging.console "%message\n"
      local colors    = loader.require "ansicolors"
      function Logger.debug (t)
        logger:debug (colors ("%{dim cyan}"    .. i18n (t).message))
      end
      function Logger.info (t)
        logger:info (colors ("%{green}"        .. i18n (t).message))
      end
      function Logger.warning (t)
        logger:warn (colors ("%{yellow}"       .. i18n (t).message))
      end
      function Logger.error (t)
        logger:error (colors ("%{white redbg}" .. i18n (t).message))
      end
    end
  end

  Logger.update ()

  return Logger

end
