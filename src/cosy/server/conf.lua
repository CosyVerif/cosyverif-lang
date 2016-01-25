return function (loader)

  local Default = loader.load "cosy.configuration.layers".default

  Default.server = {
    interface = "127.0.0.1",
    port      = 0, -- random port
    retry     = 5,
    name      = nil,
    locale    = (os.getenv "LANG" or "en"):match "[^%.]+":gsub ("_", "-"),
    log       = loader.home .. "/server.log",
    data      = loader.home .. "/server.data",
  }

  Default.recaptcha = {
    public_key  = nil,
    private_key = nil,
  }

  Default.geodb = {
    position = {
      longitude      = 4.6,
      latitude	     = 44.735833,
      continent_code = "EU",
      region         = "B9",
      metro_code     = 0,
      dma_code       = 0,
      country_code   = "FR",
      country_name   = "France",
      area_code      = 0,
      postal_code    = "07000",
      charset        = 1,
      city           = "Privas",
      country_code3  = "FRA",
    },
  }

end
