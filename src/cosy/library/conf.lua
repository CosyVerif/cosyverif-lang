return function (loader)

  local Default = loader.load "cosy.configuration.layers".default

  Default.library = {
    timeout = 5, -- seconds
  }

end
