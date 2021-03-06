local Lfs       = require "lfs"
local Lustache  = require "lustache"
local Colors    = require 'ansicolors'
local Arguments = require "argparse"

local parser = Arguments () {
  name        = "cosy-fixpath",
  description = "Fix PATH, CPATH, *LIBRARY_PATH in cosy binaries",
}
parser:argument "prefix" {
  description = "cosy prefix directory",
}
parser:flag "-q" "--quiet" {
  description = "do not output anything",
}

local arguments = parser:parse ()

local string_mt = getmetatable ""

function string_mt.__mod (pattern, variables)
  return Lustache:render (pattern, variables)
end

if Lfs.attributes (arguments.prefix, "mode") ~= "directory" then
  if not arguments.quiet then
    print (Colors ("%{bright red blackbg}failure%{reset}"))
  end
  os.exit (1)
end

for filename in Lfs.dir (arguments.prefix .. "/bin") do
  if filename:match "^cosy" then
    local lines = {}
    for line in io.lines (arguments.prefix .. "/bin/" .. filename) do
      lines [#lines+1] = line
    end
    table.insert (lines, 3, [[export CPATH="{{{prefix}}}/include:${CPATH}"]] % { prefix = arguments.prefix })
    table.insert (lines, 4, [[export LIBRARY_PATH="{{{prefix}}}/lib:${LIBRARY_PATH}"]] % { prefix = arguments.prefix })
    table.insert (lines, 5, [[export LD_LIBRARY_PATH="{{{prefix}}}/lib:${LD_LIBRARY_PATH}"]] % { prefix = arguments.prefix })
    table.insert (lines, 6, [[export DYLD_LIBRARY_PATH="{{{prefix}}}/lib:${DYLD_LIBRARY_PATH}"]] % { prefix = arguments.prefix })
    table.insert (lines, 7, "")
    local file = io.open (arguments.prefix .. "/bin/" .. filename, "w")
    file:write (table.concat (lines, "\n") .. "\n")
    file:close ()
  end
end

if not arguments.quiet then
  print (Colors ("%{bright green blackbg}success%{reset}"))
end

os.exit (0)
