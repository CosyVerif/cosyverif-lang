return function (loader)

  local Default = loader.load "cosy.configuration.layers".default

  Default.library = {
    timeout  = 2, -- seconds
    password = 6, -- at least 6 characters
  }

end
