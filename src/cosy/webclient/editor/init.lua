return function (loader)

  local Webclient = loader.load "cosy.webclient"
  local I18n      = loader.load "cosy.i18n"
  local Layer     = loader.require "layeredata"
  local i18n      = I18n.load {}

  local Editor    = {}
  Editor.__index  = Editor
  Editor.template = Webclient.template "cosy.webclient.editor"

  function Editor.init ()
    local css = Webclient.jQuery ("<link>", Webclient.tojs {
      rel  = "stylesheet",
      type = "text/css",
      href = "/editor.css"
    });
    css:appendTo "head"
    local d3     = Webclient.window.d3
    local height = Webclient.jQuery (Webclient.window):height ()
    local width  = Webclient.jQuery (Webclient.window):width  ()
    Editor.model = Layer.new {
      name = "my model",
      data = {},
    }
    Editor.svg    = d3:select "#editor"
                  : append "svg:svg"
                  : attr ("class", "cosy-editor")
                  : attr ("width" , width )
                  : attr ("height", height)
                  : style ("pointer-events", "all")
    Editor.outer  = Editor.svg
                  : append "g"
                  : attr ("class", "cosy-editor-outer")
    Editor.inner  = Editor.outer
                  : append "g"
                  : attr ("class", "cosy-editor-inner")
    Editor.zoom   = d3.behavior
                  : zoom ()
    Editor.layout = d3.layout
                  : force ()
                  : size (Webclient.tojs { width, height })
                  : nodes (Webclient.tojs {})
                  : links (Webclient.tojs {})
    Editor.inner  : append "svg:rect"
                  : attr  ("class", "click-capture")
                  : attr  ("width" , width )
                  : attr  ("height", height)
                  : attr  ("visibility", "hidden")
    Webclient.jQuery (Webclient.window):resize (function ()
      d3 : select "#editor"
         : attr ("width" , width )
         : attr ("height", height)
    end)
  end

  function Editor.update ()

  end

  function Editor.__call ()
    Webclient (function ()
      Webclient.show {
        where    = "main",
        template = Editor.template,
        data     = {},
        i18n     = i18n,
      }
      -- See http://bl.ocks.org/GerHobbelt/3637711 for pinning
      Editor.init ()
    end)
  end

  return setmetatable ({}, Editor)

end
