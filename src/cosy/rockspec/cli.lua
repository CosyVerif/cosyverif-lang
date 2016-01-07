local Arguments = require "argparse"
local Lfs       = require "lfs"
local Serpent   = require "serpent"

local parser = Arguments () {
  name        = "cosy-rockspec",
  description = "cosy rockspec generator",
}
parser:option "-s" "--source" {
  description = "path to cosy source",
  default     = (os.getenv "PWD") .. "/src",
}
parser:option "-t" "--target" {
  description = "path to rockspec directory",
  default     = (os.getenv "PWD") .. "/rockspec",
}
local arguments = parser:parse ()

local rockspec = {
  package = "cosyverif",
  version = "master-1",

  source = {
    url = "git://github.com/cosyverif/library",
  },

  description = {
    summary     = "CosyVerif",
    detailed    = [[]],
    homepage    = "http://www.cosyverif.org/",
    license     = "MIT/X11",
    maintainer  = "Alban Linard <alban@linard.fr>",
  },

  dependencies = {
    "lua >= 5.2",
    "ansicolors",
    "argparse",
    "bcrypt",
    "copas-ev",
    "coronest",
    "dkjson",
    "hotswap",
    "hotswap-ev",
    "hotswap-http",
    "i18n",
    "jwt",
    "layeredata",
    "lua-cjson-ol", -- needed by jwt, instead of lua-cjson
    "lua-ev",
    "lua-resty-http",
    "lua-websockets",
    "luacrypto",
    "luafilesystem",
    "lualogging",
    "luaposix",
    "luasec",
    "luasocket",
    "lustache",
    "md5",
    "serpent",
  },

  build = {
    type    = "builtin",
    modules = {},
    install = {
      bin = {
        ["cosy"         ] = "src/cosy/client/bin.lua",
        ["cosy-server"  ] = "src/cosy/server/bin.lua",
        ["cosy-check"   ] = "src/cosy/check/bin.lua",
        ["cosy-rockspec"] = "src/cosy/rockspec/bin.lua",
      },
      conf = {},
    },
  },
}

local source  = arguments.source .. "/cosy"
local ssource = "src/cosy"

local function resource (path)
  for content in Lfs.dir (path) do
    local subpath = path .. "/" .. content
    if      Lfs.attributes (subpath, "mode") == "file"
    and     not subpath:match "%.lua$"
    then    rockspec.build.install.conf [#rockspec.build.install.conf+1] = ssource .. "/" .. subpath:sub (#source+2)
    elseif  content ~= "." and content ~= ".."
    and     Lfs.attributes (subpath, "mode") == "directory"
    then    resource (subpath)
    end
  end
end

for module in Lfs.dir (source) do
  local path = source .. "/" .. module
  if  module ~= "." and module ~= ".."
  and Lfs.attributes (path, "mode") == "directory" then
    if Lfs.attributes (path .. "/init.lua", "mode") == "file" then
      rockspec.build.modules ["cosy." .. module] = ssource .. "/" .. module .. "/init.lua"
    end
    for submodule in Lfs.dir (path) do
      if  submodule ~= "." and submodule ~= ".."
      and Lfs.attributes (path .. "/" .. submodule, "mode") == "file"
      and submodule:find "%.lua$"
      and not submodule:find "init%.lua$"
      and not submodule:find "bin%.lua$"
      then
        submodule = submodule:sub (1, #submodule-4)
        rockspec.build.modules ["cosy." .. module .. "." .. submodule] = ssource .. "/" .. module .. "/" .. submodule .. ".lua"
      end
    end
    resource (path)
  end
end

local options = {
  indent   = "  ",
  comment  = false,
  sortkeys = true,
  compact  = false,
  fatal    = true,
  nocode   = true,
  nohuge   = true,
}

Lfs.mkdir (arguments.target)
local file = io.open (arguments.target .. "/cosyverif-master-1.rockspec", "w")
for _, key in ipairs {
  "package",
  "version",
  "source",
  "description",
  "dependencies",
  "build",
} do
  local output = Serpent.block (rockspec [key], options)
  file:write (key .. " = " .. output .. "\n")
end
file:close ()