return function (loader)

  local Configuration = loader.load "cosy.configuration"
  local Default       = loader.load "cosy.configuration.layers".default
  local I18n          = loader.load "cosy.i18n"
  local Logger        = loader.load "cosy.logger"
  local Lfs           = loader.require "lfs"
  local Posix         = loader.require "posix"

  Configuration.load {
    "cosy.nginx",
    "cosy.redis",
  }

  local i18n   = I18n.load "cosy.nginx"
  i18n._locale = Configuration.locale

  local Nginx = {}

  local configuration_template = [[
error_log   error.log;
pid         {{{pid}}};
{{{user}}}

worker_processes 1;
events {
  worker_connections 1024;
}

http {
  tcp_nopush            on;
  tcp_nodelay           on;
  keepalive_timeout     65;
  types_hash_max_size   2048;

  proxy_temp_path       proxy;
  proxy_cache_path      cache   keys_zone=foreign:10m;
  lua_package_path      "{{{path}}}";
  lua_package_cpath     "{{{cpath}}}";

  gzip              on;
  gzip_min_length   0;
  gzip_types        *;
  gzip_proxied      no-store no-cache private expired auth;

  server {
    listen        {{{host}}}:{{{port}}};
    charset       utf-8;
    index         index.html;
    include       {{{nginx}}}/conf/mime.types;
    default_type  application/octet-stream;
    access_log    access.log;
    open_file_cache off;

    location / {
      add_header  Access-Control-Allow-Origin *;
      root        {{{www}}};
      index       index.html;
    }

    location = /setup {
      content_by_lua '
        local setup = require "cosy.nginx.setup"
        setup       = setup:gsub ("ROOT_URI", "http://" .. ngx.var.http_host)
        ngx.say (setup)
      ';
    }

    location /upload {
      limit_except                POST { deny all; }
      client_body_in_file_only    on;
      client_body_temp_path       {{{uploads}}};
      client_body_buffer_size     128K;
      client_max_body_size        10240K;
      proxy_pass_request_headers  on;
      proxy_set_header            X-File $request_body_file;
      proxy_set_body              off;
      proxy_redirect              off;
      proxy_pass                  http://localhost:{{{port}}}/uploaded;
    }

    location /uploaded {
      content_by_lua '
        local md5      = require "md5"
        local filename = ngx.var.http_x_file
        local file     = assert (io.open (filename))
        local contents = file:read "*all"
        file:close ()
        local sum      = md5.sumhexa (contents)
        ngx.log (ngx.ERR, filename)
        ngx.log (ngx.ERR, filename:gsub ("([^/]+)$", sum))
        os.rename (filename, filename:gsub ("([^/]+)$", sum))
        ngx.say (sum)
      ';
    }

    location /lua {
      default_type  application/lua;
      root          /;
      set           $target   "";
      access_by_lua '
        local name = ngx.var.uri:match "/lua/(.*)"
        local filename = package.searchpath (name, "{{{path}}}")
        if filename then
          ngx.var.target = filename
        else
          ngx.log (ngx.ERR, "failed to locate lua module: " .. name)
          return ngx.exit (404)
        end
      ';
      try_files     $target =404;
    }

    location /luaset {
      default_type  application/json;
      access_by_lua '
        ngx.req.read_body ()
        local body    = ngx.req.get_body_data ()
        local json    = require "cjson"
        local http    = require "resty.http"
        local data    = json.decode (body)
        local result  = {}
        for k, t in pairs (data) do
          local hc  = http:new ()
          local url = "http://127.0.0.1:{{{port}}}/lua/" .. k
          local res, err = hc:request_uri (url, {
            method = "GET",
            headers = {
              ["If-None-Match"] = type (t) == "table" and t.etag,
            },
          })
          if not res then
            ngx.log (ngx.ERR, "failed to request: " .. err)
            return
          end
          if res.status == 200 then
            local etag = res.headers.etag:match [=[^"([^"]+)"$]=]
            result [k] = {
              etag = etag,
            }
            if t == true
            or (type (t) == "table" and t.etag ~= etag)
            then
              result [k].lua = res.body
            end
          elseif res.status == 304 then
            result [k] = {}
          elseif res.status == 404 then
            result [k] = nil
          end
        end
        ngx.say (json.encode (result))
      ';
    }

    location /ws {
      proxy_pass          http://{{{wshost}}}:{{{wsport}}};
      proxy_http_version  1.1;
      proxy_set_header    Upgrade $http_upgrade;
      proxy_set_header    Connection "upgrade";
    }

    location /hook {
      content_by_lua '
        local temporary = os.tmpname ()
        local file      = io.open (temporary, "w")
        file:write [==[
          git pull --quiet --force
          luarocks install --local --force --only-deps cosyverif
          for rock in $(luarocks list --outdated --porcelain | cut -f 1)
          do
          luarocks install --local --force ${rock}
          done
          rm --force $0
        ]==]
        file:close ()
        os.execute ("bash " .. temporary .. " &")
      ';
    }

{{{redirects}}}
  }
}
]]

  local function sethostname ()
    local handle = io.popen "hostname"
    local result = handle:read "*all"
    handle:close()
    Default.http.hostname = result
    Logger.info {
      _        = i18n ["nginx:hostname"],
      hostname = Configuration.http.hostname,
    }
  end

  function Nginx.configure ()
    local resolver
    do
      local file = io.open "/etc/resolv.conf"
      if not file then
        Logger.error {
          _ = i18n ["nginx:no-resolver"],
        }
        resolver = "8.8.8.8"
      else
        local result = {}
        for line in file:lines () do
          local address = line:match "nameserver%s+(%S+)"
          if address then
            if address:find ":" then
              address = "[{{{address}}}]" % { address = address }
            end
            result [#result+1] = address
          end
        end
        file:close ()
        resolver = table.concat (result, " ")
      end
    end
    if not Lfs.attributes (Configuration.http.directory, "mode") then
      Lfs.mkdir (Configuration.http.directory)
    end
    if not Lfs.attributes (Configuration.http.uploads, "mode") then
      Lfs.mkdir (Configuration.http.uploads)
    end
    local locations = {}
    for url, remote in pairs (Configuration.dependencies) do
      if type (remote) == "string" and remote:match "^http" then
        locations [#locations+1] = [==[
    location {{{url}}} {
      proxy_cache foreign;
      expires     modified  1d;
      resolver    {{{resolver}}};
      set         $target   "{{{remote}}}";
      proxy_pass  $target$is_args$args;
    }
          ]==] % {
            url      = url,
            remote   = remote,
            resolver = resolver,
          }
      end
    end
    if not Configuration.http.hostname then
      sethostname ()
    end
    local configuration = configuration_template % {
      nginx          = Configuration.http.nginx,
      host           = Configuration.http.interface,
      port           = Configuration.http.port,
      www            = Configuration.http.www,
      uploads        = Configuration.http.uploads,
      pid            = Configuration.http.pid,
      wshost         = Configuration.server.interface,
      wsport         = Configuration.server.port,
      redis_host     = Configuration.redis.interface,
      redis_port     = Configuration.redis.port,
      redis_database = Configuration.redis.database,
      user           = Posix.geteuid () == 0 and ("user " .. os.getenv "USER" .. ";") or "",
      path           = package. path:gsub ("5%.2", "5.1") .. ";" .. package. path,
      cpath          = package.cpath:gsub ("5%.2", "5.1") .. ";" .. package.cpath,
      redirects      = table.concat (locations, "\n"),
    }
    local file = assert (io.open (Configuration.http.configuration, "w"))
    file:write (configuration)
    file:close ()
  end

  function Nginx.start ()
    Nginx.stop      ()
    Nginx.configure ()
    if Posix.fork () == 0 then
      Posix.execp (Configuration.http.nginx .. "/sbin/nginx", {
        "-q",
        "-p", Configuration.http.directory,
        "-c", Configuration.http.configuration,
      })
    end
    Nginx.stopped = false
  end

  local function getpid ()
    local nginx_file = io.open (Configuration.http.pid, "r")
    if nginx_file then
      local pid = nginx_file:read "*a"
      nginx_file:close ()
      return pid:match "%S+"
    end
  end

  function Nginx.stop ()
    local pid = getpid ()
    if pid then
      Posix.kill (pid, 15) -- term
      Posix.wait (pid)
    end
    os.remove (Configuration.http.configuration)
    Nginx.directory = nil
    Nginx.stopped   = true
  end

  function Nginx.update ()
    Nginx.configure ()
    local pid = getpid ()
    if pid then
      Posix.kill (pid, 1) -- hup
    end
  end

  loader.hotswap.on_change ["cosy:configuration"] = function ()
    Nginx.update ()
  end

  return Nginx

end
