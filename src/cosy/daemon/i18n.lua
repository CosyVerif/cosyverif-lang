return function (--[[loader]])

  return {
    ["daemon:request"] = {
      en = "> daemon: {{{request}}}",
    },
    ["daemon:response"] = {
      en = "< daemon: {{{request}}} {{{response}}}",
    },
    ["server:unreachable"] = {
      en = "cosy server is unreachable",
      fr = "le serveur cosy est injoignable",
    },
    ["websocket:listen"] = {
      en = "daemon websocket listening on {{{host}}}:{{{port}}}",
    },
  }

end
