return function (--[[loader]])

  return {
    ["client:server"] = {
      en = "using '{{{server}}}' server",
    },
    ["client:identified"] = {
      en = "identified as user '{{{user}}}'",
    },
    ["client:command"] = {
      en = "cosy command-line interface",
    },
    ["server:not-url"] = {
      en = "server {{{server}}} is not a valid HTTP(s) URL",
    },
    ["server:not-cosy"] = {
      en = "server {{{server}}} does not seem to be a Cosy server. Please use the --server option to set a running server.",
    },
    ["error:unexpected"] = {
      en = "an unepected error happened, please retry",
    },
    ["file:not-found"] = {
      en = "file not found: {{{filename}}} ({{{reason}}})",
    },
    ["url:not-found"] = {
      en = "URL not found: {{{url}}} (status {{{status}}})",
    },
    ["success"] = {
      en = "success",
    },
    ["failure"] = {
      en = "failure",
    },
    ["upload:failure"] = {
      en = "failed to upload content (error {{{status}}})",
    },
    ["server:already-running"] = {
      en = "server is already running",
    },
    ["option:locale"] = {
      en = "locale for messages",
    },
    ["option:server"]= {
      en = "server URL"
    },
    ["flag:captcha"] = {
      en = "answer to captcha in web browser",
    },
    ["flag:debug"] = {
      en = "show debug information",
    },
    ["flag:force"] = {
      en = "force action",
    },
    ["flag:password"] = {
      en = "update password",
    },
    ["argument:password1"] = {
      en = "please type your password",
    },
    ["argument:password2"] = {
      en = "please type the same password again",
    },
    ["argument:password:nomatch"] = {
      en = "passwords are not the same",
    },
  }

end
