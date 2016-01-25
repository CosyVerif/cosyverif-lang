_G._TEST = true

-- These lines are required to correctly run tests:
require "busted.runner" ()
local loader = require "cosy.loader.lua" {
  logto = false,
  alias = "__busted__", -- server alias
}
local Configuration = loader.load "cosy.configuration"
local File          = loader.load "cosy.file"
local Cli           = loader.require "cosy.client.cli"

Configuration.load {
  "cosy.client",
  "cosy.server",
}
Configuration.library = {
  timeout = 1,
}

local data = assert (File.decode (Configuration.server.data))
local server_url = "http://127.0.0.1:{{{port}}}" % {
  port = data.http.port,
}
Cli.default_server = server_url
Cli.default_locale = "en"

describe ("Module cosy.client", function ()

  before_each (function ()
    os.remove (Configuration.cli.data)
  end)

  describe ("parsing options by method configure", function ()

    it ("should set the alias if the --alias option is set", function ()
      local cli = Cli.new ()
      cli:configure {
        "--alias=" .. loader.alias,
      }
      assert.are.equal (cli.alias, loader.alias)
    end)

    it ("should set the locale if the --locale option is set", function ()
      local cli = Cli.new ()
      cli:configure {
        "--alias=" .. loader.alias,
        "--locale=zz",
      }
      assert.are.equal (cli.locale, "zz")
    end)

    it ("should use a default locale if the --locale option is missing", function ()
      local cli = Cli.new ()
      cli:configure {
        "--alias=" .. loader.alias,
      }
      assert.are.equal (cli.locale, Cli.default_locale)
    end)

    it ("should set the server if the --server option is set", function ()
      local cli = Cli.new ()
      cli:configure {
        "--alias=" .. loader.alias,
        "--server=" .. server_url,
      }
      assert.are.equal (cli.server, server_url)
    end)

    it ("should use a default server if the --server option is missing", function ()
      local cli = Cli.new ()
      cli:configure {
        "--alias=" .. loader.alias,
      }
      assert.are.equal (cli.server, Cli.default_server)
    end)

    it ("should pick the last one if several --server options are set", function ()
      local cli = Cli.new ()
      cli:configure {
        "--alias=" .. loader.alias,
        "--server=http://127.0.0.1:0",
        "--server=" .. server_url,
      }
      assert.are.equal (cli.server, server_url)
    end)

    it ("should fail if the --server option is not a cosy server", function ()
      local cli = Cli.new ()
      assert.has.errors (function ()
        cli:configure {
          "--alias=" .. loader.alias,
          "--server=http://www.microsoft.com/",
        }
      end)
    end)

    it ("should fail if the --server option is not a HTTP(s) URL", function ()
      local cli = Cli.new ()
      assert.has.errors (function ()
        cli:configure {
          "--alias=" .. loader.alias,
          "--server=some.server.org",
        }
      end)
    end)

  end)

  describe ("saving options by method configure", function ()

    it ("should detect the --server", function ()
      do
        local cli = Cli.new ()
        cli:configure {
          "--alias=" .. loader.alias,
          "--server=" .. server_url,
        }
        -- assert server was found and set
        assert.are.equal (cli.server, server_url)
      end
      do
        local cli = Cli.new ()
        cli:configure {
          "--alias=" .. loader.alias,
        }
        -- assert config was saved to config file
        assert.are.equal (cli.server, server_url)
      end
    end)

  end)

end)
