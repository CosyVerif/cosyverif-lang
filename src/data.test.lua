               require "busted"
local assert = require "luassert"
local Layer  = require "data"

local Platform = require "cosy.platform"

describe ("c3 linearization", function ()

  it ("works as expected", function ()
    -- See: [C3 Linearization](http://en.wikipedia.org/wiki/C3_linearization)
    local o = {
      name = "o",
    }
    local a = {
      name = "a",
      [Layer.DEPENDS] = { o },
    }
    local b = {
      name = "b",
      [Layer.DEPENDS] = { o },
    }
    local c = {
      name = "c",
      [Layer.DEPENDS] = { o },
    }
    local d = {
      name = "d",
      [Layer.DEPENDS] = { o },
    }
    local e = {
      name = "e",
      [Layer.DEPENDS] = { o },
    }
    local i = {
      name = "i",
      [Layer.DEPENDS] = { c, b, a },
    }
    local j = {
      name = "j",
      [Layer.DEPENDS] = { e, b, d },
    }
    local k = {
      name = "k",
      [Layer.DEPENDS] = { a, d },
    }
    local z = {
      name = "z",
      [Layer.DEPENDS] = { k, j, i },
    }
    assert.are.same (Layer.linearize (o), {
      o
    })
    assert.are.same (Layer.linearize (a), {
      o, a,
    })
    assert.are.same (Layer.linearize (b), {
      o, b,
    })
    assert.are.same (Layer.linearize (c), {
      o, c,
    })
    assert.are.same (Layer.linearize (d), {
      o, d,
    })
    assert.are.same (Layer.linearize (e), {
      o, e,
    })
    assert.are.same (Layer.linearize (i), {
      o, c, b, a, i
    })
    assert.are.same (Layer.linearize (j), {
      o, e, b, d, j
    })
    assert.are.same (Layer.linearize (k), {
      o, a, d, k
    })
    assert.are.same (Layer.linearize (z), {
      o, e, c, b, a, d, k, j, i , z
    })
  end)

end)

describe ("a layer", function ()

  it ("allows to read values", function ()
    local c1 = Layer.new {
      a = 1,
    }
    assert.are.equal (c1.a._, 1)
    assert.is_nil (c1.b._)
  end)

  it ("handles proxies in depends", function ()
    local c1 = Layer.new {
      a = 1,
    }
    local c2 = Layer.new {
      [Layer.DEPENDS] = { c1 },
    }
    assert.are.equal (c2.a._, 1)
  end)

  it ("exposes the nearest value", function ()
    local c1 = Layer.new {
      a = 1,
    }
    local c2 = Layer.new {
      a = 2,
      [Layer.DEPENDS] = { c1 },
    }
    assert.are.equal (c1.a._, 1)
    assert.are.equal (c2.a._, 2)
  end)

  it ("uses its dependencies from last to first", function ()
    local c1 = Layer.new {
      a = 1,
    }
    local c2 = Layer.new {
      a = 2,
    }
    local c3 = Layer.new {
      [Layer.DEPENDS] = { c1, c2 },
    }
    assert.are.equal (c3.a._, 2)
  end)

  it ("allows diamond in dependencies", function ()
    local c1 = Layer.new {
      a = 1,
      b = 1,
    }
    local c2 = Layer.new {
      b = 2,
      [Layer.DEPENDS] = { c1 },
    }
    local c3 = Layer.new {
      b = 3,
      [Layer.DEPENDS] = { c1 },
    }
    local c4 = Layer.new {
      [Layer.DEPENDS] = { c2, c3 },
    }
    assert.are.equal (c4.a._, 1)
    assert.are.equal (c4.b._, 3)
  end)

  it ("merges layers in all the data tree", function ()
    local c1 = Layer.new {
      a = {
        x = 1,
        y = 1,
      },
    }
    local c2 = Layer.new {
      a = {
        y = 2,
      },
      [Layer.DEPENDS] = { c1 },
    }
    assert.are.equal (c2.a.x._, 1)
    assert.are.equal (c2.a.y._, 2)
  end)

end)

describe ("a reference", function ()

  local _ = Layer.placeholder

  it ("handles proxies without layer", function ()
    local c1 = Layer.new {
      a = 1,
      b = _.a,
    }
    assert.are.equal (c1.b()._, 1)
  end)

  it ("can follow multiple redirects", function ()
    local c1 = Layer.new {
      a = 1,
      b = _.a,
      c = _.b,
    }
    assert.are.equal (c1.c()()._, 1)
    assert.are.equal (c1.c(2)._ , 1)
    assert.is_nil    (c1.c(3)._)
  end)

  it ("is followed from the top layer", function ()
    local c1 = Layer.new {
      b = _.a,
    }
    local c2 = Layer.new {
      c = _.b,
    }
    local c3 = Layer.new {
      a = 1,
      [Layer.DEPENDS] = { c1, c2 },
    }
    assert.are.equal (c3.c()()._, 1)
    assert.are.equal (c3.c(2)._ , 1)
  end)

  it ("can also have a value", function ()
    local c1 = Layer.new {
      a = 1,
      b = _.a,
      c = _.b,
    }
    local c2 = Layer.new {
      b = 2,
      [Layer.DEPENDS] = { c1 },
    }
    assert.are.equal (c2.c()._, 2)
  end)

end)