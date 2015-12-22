local loader    = require "cosy.loader.lua" {
  logto = false,
}
local Lfs       = loader.require "lfs"
local Lustache  = loader.require "lustache"
local Colors    = loader.require 'ansicolors'
local Reporter  = loader.require "luacov.reporter"
local Arguments = loader.require "argparse"

local prefix = os.getenv "COSY_PREFIX"
local name   = prefix .. "/bin/cosy-check"
name         = name:gsub (os.getenv "HOME", "~")

local parser = Arguments () {
  name        = name,
  description = "Perform various checks on the cosy sources",
}
parser:option "--test-format" {
  description = "format for the test results (supported by busted)",
  default     = "TAP",
}

local arguments = parser:parse ()

local string_mt = getmetatable ""

function string_mt.__mod (pattern, variables)
  return Lustache:render (pattern, variables)
end

function _G.string.split (s, delimiter)
  local result = {}
  for part in s:gmatch ("[^" .. delimiter .. "]+") do
    result [#result+1] = part
  end
  return result
end

-- Compute path:
local main = package.searchpath ("cosy.check", package.path)
if main:sub (1, 2) == "./" then
  main = Lfs.currentdir () .. "/" .. main:sub (3)
end
main = main:gsub ("/check/init.lua", "")

local status = true

-- luacheck
-- ========

do
  status = os.execute ([[
    cd {{{path}}}/..
    {{{luacheck}}} --std max --std +busted cosy/*/*.lua
  ]] % {
    luacheck = prefix .. "/local/cosy/5.1/bin/luacheck",
    path     = main,
  }) and status
end

-- busted
-- ======

do
  Lfs.mkdir "test"
  local test_id = 1
  for module in Lfs.dir (main) do
    local path = main .. "/" .. module
    if  module ~= "." and module ~= ".."
    and Lfs.attributes (path, "mode") == "directory" then
      if Lfs.attributes (path .. "/test.lua", "mode") == "file" then
        print ("Testing {{{module}}} module:" % {
          module = module,
        })
        print ("luapath", package.path)
        print ("luacpath", package.cpath)
        status = os.execute ([[{{{lua}}} {{{path}}}/test.lua --verbose]] % {
          lua  = prefix .. "/local/cosy/5.1/bin/luajit",
          path = path,
        }) and status
        for _, version in ipairs {
          "5.2",
        } do
          print ("luapath", package.path :gsub ("5%.1", version))
          print ("luacpath", package.cpath:gsub ("5%.1", version))
          status = os.execute ([[
            export LUA_PATH="{{{luapath}}}"
            export LUA_CPATH="{{{luacpath}}}"
            {{{lua}}} {{{path}}}/test.lua --verbose --coverage --output={{{format}}} >> {{{output}}}
          ]] % {
            lua      = "lua" .. version,
            path     = path:gsub ("5%.1", version),
            format   = arguments.test_format,
            output   = "test/" .. tostring (test_id),
            luapath  = package.path :gsub ("5%.1", version),
            luacpath = package.cpath:gsub ("5%.1", version),
          }) and status
          test_id = test_id + 1
        end
        print ()
      end
    end
  end
  print ()
end

-- luacov
-- ======

do
  Reporter.report ()

  local report = {}
  Lfs.mkdir "coverage"

  local file      = "luacov.report.out"
  local output    = nil
  local in_header = false
  local current
  for line in io.lines (file) do
    if     not in_header
    and    line:find ("==============================================================================") == 1
    then
      in_header = true
      if output then
        output:close ()
        output = nil
      end
    elseif in_header
    and    line:find ("==============================================================================") == 1
    then
      in_header = false
    elseif in_header
    then
      current = line
      if current ~= "Summary" then
        local filename = line:match (prefix .. "/local/cosy/[^/]+/share/lua/[^/]+/(.*)")
        if filename and filename:match "^cosy" then
          local parts = {}
          for part in filename:gmatch "[^/]+" do
            parts [#parts+1] = part
            if not part:match ".lua$" then
              Lfs.mkdir ("coverage/" .. table.concat (parts, "/"))
            end
          end
          output = io.open ("coverage/" .. table.concat (parts, "/"), "w")
        end
      end
    elseif output then
      output:write (line .. "\n")
    else
      local filename = line:match (prefix .. "/local/cosy/[^/]+/share/lua/[^/]+/(.*)")
      if filename and filename:match "^cosy" then
        line = line:gsub ("\t", " ")
        local parts = line:split " "
        if #parts == 4 and parts [4] ~= "" then
          report [filename] = tonumber (parts [3]:match "([0-9%.]+)%%")
        end
      end
    end
  end
  if output then
    output:close ()
  end

  local max_size = 0
  for k, _ in pairs (report) do
    max_size = math.max (max_size, #k)
  end
  max_size = max_size + 3

  local keys = {}
  for k, _ in pairs (report) do
    keys [#keys + 1] = k
  end
  table.sort (keys)

  for i = 1, #keys do
    local k = keys   [i]
    local v = report [k]
    local color
    if v == 100 then
      color = "%{bright green}"
    elseif v < 100 and v >= 90 then
      color = "%{green}"
    elseif v < 90 and v >= 80 then
      color = "%{yellow}"
    elseif v < 80 and v >= 50 then
      color = "%{red}"
    else
      color = "%{bright red}"
    end
    local line = k
    for _ = #k, max_size do
      line = line .. " "
    end
    print ("Coverage " .. line .. Colors (color .. string.format ("%3d", v) .. "%"))
  end
end

print ()

-- i18n
-- ====

do
  local messages = {}
  local problems = 0

  for module in Lfs.dir (main) do
    local path = main .. "/" .. module
    if  module ~= "." and module ~= ".."
    and Lfs.attributes (path, "mode") == "directory" then
      if Lfs.attributes (path .. "/i18n.lua", "mode") == "file" then
        local translations = loader.load ("cosy.{{{module}}}.i18n" % {
          module = module,
        })
        for key, t in pairs (translations) do
          if not messages [key] then
            messages [key] = {
              defined = {},
              used    = {},
            }
          end
          messages [key].defined [module] = true
          if not t.en then
            print (Colors ("Translation key %{red}{{{key}}}%{reset} defined in %{blue}{{{module}}}%{reset} does not have an 'en' translation." % {
              key    = key,
              module = "cosy." .. module,
            }))
            problems = problems + 1
          end
          local linen = 1
          local times = 0
          local lines = {}
          for line in io.lines (path .. "/i18n.lua") do
            if line:match ('%["{{{key}}}"%]' % {
              key = key,
            }) then
              lines [#lines+1] = "%{blue}{{{line}}}%{reset}" % {
                line = linen,
              }
              times = times + 1
            end
            linen = linen + 1
          end
          if times > 1 then
            print (Colors ("Translation key %{red}{{{key}}}%{reset} is defined several times in %{blue}{{{module}}}%{reset}, lines {{{lines}}}." % {
              key    = key,
              module = module,
              lines  = table.concat (lines, ", "),
            }))
            problems = problems + 1
          end
        end
      end
    end
  end

  for module in Lfs.dir (main) do
    local path = main .. "/" .. module
    if  module ~= "." and module ~= ".."
    and Lfs.attributes (path, "mode") == "directory" then
      for submodule in Lfs.dir (path) do
        submodule = submodule:sub (1, #submodule-4)
        local subpath = path .. "/" .. submodule .. ".lua"
        if  submodule ~= "." and submodule ~= ".."
        and Lfs.attributes (subpath, "mode") == "file" then
          for line in io.lines (subpath) do
            local key = line:match 'i18n%s*%[%s*"([%w%:%-%_]+)"%s*%]'
                     or line:match "i18n%s*%[%s*'([%w%:%-%_]+)'%s*%]"
                     or line:match 'methods%s*%[%s*"([%w%:%-%_]+)"%s*%]'
                     or line:match "methods%s*%[%s*'([%w%:%-%_]+)'%s*%]"
            if key and key:find "_" ~= 1 then
              if messages [key] then
                messages [key].used [module .. "." .. submodule] = true
              else
                print (Colors ("Translation key %{red}{{{key}}}%{reset} is used in %{blue}{{{module}}}%{reset}, but never defined." % {
                  key    = key,
                  module = "cosy." .. module .. "." .. submodule,
                }))
                problems = problems + 1
              end
            end
          end
        end
      end
    end
  end

  for key, t in pairs (messages) do
    do
      local times   = 0
      local modules = {}
      for module in pairs (t.defined) do
        times = times + 1
        modules [#modules+1] = "%{blue}{{{module}}}%{reset}" % {
          module = module,
        }
      end
      if times > 1 then
        print (Colors ("Translation key %{red}{{{key}}}%{reset} is defined {{{n}}} times in modules {{{modules}}}." % {
          key     = key,
          modules = table.concat (modules, ", "),
          n       = times,
        }))
        problems = problems + 1
      end
    end
    local uses = 0
    for _ in pairs (t.used) do
      uses = uses + 1
    end
    if uses == 0 then
      local modules = {}
      for m in pairs (t.defined) do
        local module_name = "cosy." .. m
        -- the modules below define translations for the user only,
        -- so we do not want to take them into account.
        if  module_name ~= "cosy.methods"
        and module_name ~= "cosy.parameters" then
          modules [#modules+1] = Colors ("%{blue}" .. module_name .. "%{reset}")
        end
      end
      if #modules ~= 0 then
        print (Colors ("Translation key %{red}{{{key}}}%{reset} is defined in {{{module}}}, but never used." % {
          key    = key,
          module = table.concat (modules, ", "),
        }))
        problems = problems + 1
      end
    end
  end

  if problems == 0 then
    print (Colors ("Translations checks detect %{bright green}no problems%{reset}."))
    status = status and true
  else
    print (Colors ("Translations checks detect %{bright red}{{{problems}}} problems%{reset}.") % {
      problems = problems,
    })
  status = status and false
  end

end

print ()

-- shellcheck
-- ==========

do
  -- We know that we are in developper mode. Thus, there is a link to the user
  -- sources of cosy library.
  if os.execute "command -v shellcheck > /dev/null 2>&1" then
    local script = [[
#! /bin/bash

sourcedirectory=$(readlink "{{{prefix}}}/local/cosy/5.1/share/lua/5.1/cosy")
shellcheck --exclude=SC2024 "${sourcedirectory}/../../bin/"*
    ]] % {
      prefix = os.getenv "COSY_PREFIX",
    }
    local file = io.open ("sc-script", "w")
    file:write (script)
    file:close ()
    status = (os.execute [[bash sc-script]]) and status
  end
end

os.exit (status and 0 or 1)
