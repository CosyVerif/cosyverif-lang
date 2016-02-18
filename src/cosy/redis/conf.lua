return function (loader)

  local Default = loader.load "cosy.configuration.layers".default

  Default.redis = {
    configuration = loader.home .. "/redis.conf",
    data          = loader.home .. "/redis.data",
    interface     = "127.0.0.1",
    database      = 0,
    pid           = loader.home .. "/redis.pid",
    log           = loader.home .. "/redis.log",
    db            = "redis.db",
    append        = "redis.append",
    port          = 0,
  }

end
