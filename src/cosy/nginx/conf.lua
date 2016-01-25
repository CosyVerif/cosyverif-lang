return function (loader)

  local Lfs     = loader.require "lfs"
  local Default = loader.load "cosy.configuration.layers".default

  -- Compute www path:
  local main = loader.hotswap.searchpath ("cosy.nginx", package.path)
  if main:sub (1, 1) == "." then
    main = Lfs.currentdir () .. "/" .. main
  end

  Default.http = {
    nginx         = loader.prefix .. "/nginx",
    hostname      = nil,
    interface     = "*",
    port          = 8080,
    timeout       = 5,
    pid           = loader.home .. "/nginx.pid",
    configuration = loader.home .. "/nginx.conf",
    directory     = loader.home .. "/nginx",
    uploads       = loader.home .. "/nginx/uploads",
    www           = main:gsub ("cosy/nginx.*", "cosy/www"),
  }

  Default.upload = {
    timeout = 5 * 60, -- 5 minutes
  }

  Default.dependencies = {
    expiration = 24 * 3600, -- 1 day
    ["/js/lua.vm.js"] = "https://kripken.github.io/lua.vm.js/lua.vm.js",
    ["/js/sjcl.js"  ] = "http://bitwiseshiftleft.github.io/sjcl/sjcl.js",
    ["/js/jquery.js"] = "http://code.jquery.com/jquery-2.1.4.min.js",
    ["/js/map.js"] = "https://maps.googleapis.com/maps/api/js?v=3&sensor=false",
    ["/js/mapcluster.js"] = "http://google-maps-utility-library-v3.googlecode.com/svn/trunk/markerclusterer/src/markerclusterer_compiled.js",
    ["/js/recaptcha/api.js"] = "https://www.google.com/recaptcha/api.js",
    ["/js/bootstrap.min.js"] = "https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js",
    ["/css/bootstrap.min.css"] = "https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css",
    ["/css/font-awesome.min.css"] = "https://maxcdn.bootstrapcdn.com/font-awesome/4.3.0/css/font-awesome.min.css",
    ["/fonts/fontawesome-webfont.woff2"] = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.3.0/fonts/fontawesome-webfont.woff2",
    ["/fonts/fontawesome-webfont.woff"] = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.3.0/fonts/fontawesome-webfont.woff",
    ["/fonts/fontawesome-webfont.ttf"] = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.3.0/fonts/fontawesome-webfont.ttf",
    ["/fonts/glyphicons-halflings-regular.woff2"] = "https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.3.4/fonts/glyphicons-halflings-regular.woff2",
    ["/fonts/glyphicons-halflings-regular.woff"] = "https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.3.4/fonts/glyphicons-halflings-regular.woff",
    ["/fonts/glyphicons-halflings-regular.ttf"] = "https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.3.4/fonts/glyphicons-halflings-regular.ttf",
    ["/ext/maps" ] = "http://maps.googleapis.com/maps/api/geocode/json",
  }

end
