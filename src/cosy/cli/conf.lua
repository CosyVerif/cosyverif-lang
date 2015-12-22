return function (loader)

  local Default = loader.load "cosy.configuration.layers".default

  Default.cli = {
    directory = os.getenv "HOME" .. "/.cosy",
    lua       = os.getenv "HOME" .. "/.cosy/lua",
    log       = os.getenv "HOME" .. "/.cosy/client.log",
    data      = os.getenv "HOME" .. "/.cosy/client.data",
    locale    = (os.getenv "LANG" or "en"):match "[^%.]+":gsub ("_", "-"),
  }

end
