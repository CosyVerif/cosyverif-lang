return function (loader)

  local Value = loader.load "cosy.value"

  local File = {}

  function File.encode (filname, data)
    local file, err = io.open (filname, "w")
    if not file then
      return nil, err
    end
    file:write (Value.expression (data) .. "\n")
    file:close ()
    return true
  end

  function File.decode (filename)
    local file, err = io.open (filename, "r")
    if not file then
      return nil, err
    end
    local data = file:read "*all"
    file:close ()
    return Value.decode (data)
  end

  return File

end
