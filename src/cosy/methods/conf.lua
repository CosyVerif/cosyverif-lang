return function (loader)

  local Default = loader.load "cosy.configuration.layers".default
  local ref     = loader.require "layeredata".reference (false)

  Default.filter = {
    timeout = 2, -- seconds
  }

  Default.reputation = {
    initial = 10,
    suspend = 50,
    release = 50,
  }

  Default.resource = {
    ["/"] = {
      email = ref.resource.email,
      token = ref.resource.token,
      tag   = ref.resource.tag,
      data  = ref.resource.data,
      info  = ref.resource.info,
    },
    info = {},
    email = {
      ["/"] = {},
    },
    token = {
      ["/"] = {},
    },
    tag = {
      ["/"] = {},
    },
    data = {
      ["/"] = {
        user = ref.resource.user,
      },
    },
    user = {
      ["/"] = {
        project = ref.resource.project,
      },
    },
    project = {
      ["/"] = {
        formalism = ref.resource.formalism,
        model     = ref.resource.model,
        service   = ref.resource.service,
        execution = ref.resource.execution,
        scenario  = ref.resource.scenario,
      },
    },
    formalism = {
      ["/"] = {},
    },
    model = {
      ["/"] = {},
    },
    service  = {
      ["/"] = {},
    },
    execution = {
      ["/"] = {},
    },
    scenario = {
      ["/"] = {},
    },
  }

end
