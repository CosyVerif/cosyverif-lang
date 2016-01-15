return function (loader)

  local Default = loader.load "cosy.configuration.layers".default

  Default.cli = {
    lua       = loader.home .. "/lua",
    log       = loader.home .. "/client.log",
    data      = loader.home .. "/client.data",
    locale    = (os.getenv "LANG" or "en"):match "[^%.]+":gsub ("_", "-"),
  }

end
