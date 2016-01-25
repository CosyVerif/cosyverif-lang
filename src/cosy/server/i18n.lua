return function (--[[loader]])

  return {
    ["message:invalid"] = {
      en = "rpc message is invalid",
    },
    ["server:command"] = {
      en = "Control the server",
    },
    ["server:start"] = {
      en = "Start the server",
    },
    ["server:stop"] = {
      en = "Stop the server",
    },
    ["server:version"] = {
      en = "Show the server version",
    },
    ["flag:clean"] = {
      en = "Clean database",
    },
    ["server:no-operation"] = {
      en = "operation {{{operation}}} does not exist",
    },
    ["server:exception"] = {
      en = "error: {{{reason}}}",
    },
    ["server:request"] = {
      en = "> server: {{{request}}}",
    },
    ["server:response"] = {
      en = "< server: {{{request}}} {{{response}}}",
    },
    ["websocket:listen"] = {
      en = "server websocket listening on {{{host}}}:{{{port}}}",
    },
    ["error:internal"] = {
      en = "internal server error",
    },
  }

end
